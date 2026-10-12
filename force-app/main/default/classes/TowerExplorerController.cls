/**
 * Backs the towerExplorer LWC (Stock tab) and the Select Inventory action on Opportunity.
 * Prices follow the Opportunity model: active BusinessPlanPrice__c rate x the tower's chargeable area,
 * plus the unit's charges (falling back to the tower's charges where the unit has none).
 */
public with sharing class TowerExplorerController {
    private static final String STATUS_AVAILABLE = 'Available';
    private static final String STATUS_RESERVED = 'Reserved';
    private static final String OTHER_CHARGES_GROUP = 'Other Charges';
    private static final String RESIDENTIAL_OPPORTUNITY = 'Residential_Sales_Opportunity';
    private static final String STATUS_CANCELLED = 'Cancelled';

    public class TowerOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer unitCount;
    }

    public class ProjectOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public List<TowerOption> towers = new List<TowerOption>();
    }

    public class UnitRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String bhk;
        @AuraEnabled public String unitType;
        @AuraEnabled public Id floorId;
        @AuraEnabled public String floorName;
        @AuraEnabled public Integer floorNumber;
        @AuraEnabled public Integer position;
        @AuraEnabled public Decimal carpetArea;
        @AuraEnabled public Decimal saleableArea;
        @AuraEnabled public Decimal sbaArea;
        @AuraEnabled public Decimal balconyArea;
        @AuraEnabled public Decimal chargeableArea;
        @AuraEnabled public Decimal carParks;
        @AuraEnabled public Decimal rera;
        @AuraEnabled public Decimal basePrice;
        @AuraEnabled public Boolean baseFromRate = false;
        @AuraEnabled public Decimal constructionCharges;
        @AuraEnabled public Decimal landCharges;
        @AuraEnabled public Decimal clubCharges;
        @AuraEnabled public Decimal legalFees;
        @AuraEnabled public Decimal utilityCharges;
        @AuraEnabled public Decimal maintenanceDeposit;
        @AuraEnabled public Decimal allInPrice;
        @AuraEnabled public Decimal allInPerSqft;
        @AuraEnabled public List<OpportunityOption> tags = new List<OpportunityOption>();
    }

    /** An open residential opportunity a unit can be tagged to (or already is). */
    public class OpportunityOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String customer;
        @AuraEnabled public String stage;
        @AuraEnabled public String unitName;

        OpportunityOption(Opportunity o) {
            id = o.Id;
            name = o.Name;
            customer = o.Account?.Name;
            stage = o.StageName;
            unitName = o.Interested_Unit__r?.Name;
        }
    }

    public class TowerData {
        @AuraEnabled public Id towerId;
        @AuraEnabled public String towerName;
        @AuraEnabled public Id projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public String chargeableAreaType;
        @AuraEnabled public Decimal ratePerSqft;
        @AuraEnabled public List<UnitRow> units = new List<UnitRow>();
    }

    public class OpportunityContext {
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public Id towerId;
        @AuraEnabled public Id projectId;
        // Set when the unit can't be changed here (the opportunity is booked or closed).
        @AuraEnabled public String lockedReason;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProjectOption> getProjects() {
        Map<Id, ProjectOption> projects = new Map<Id, ProjectOption>();
        Map<Id, TowerOption> towers = new Map<Id, TowerOption>();
        for (AggregateResult ar : [
            SELECT Tower__c towerId, Tower__r.Name towerName, Tower__r.Property__c projectId,
                   Tower__r.Property__r.Name projectName, COUNT(Id) unitCount
            FROM Unit__c
            WHERE Tower__c != null AND Tower__r.Property__c != null
              AND (Unit_Group__c = null OR Unit_Group__c != :OTHER_CHARGES_GROUP)
            GROUP BY Tower__c, Tower__r.Name, Tower__r.Property__c, Tower__r.Property__r.Name
            ORDER BY Tower__r.Property__r.Name, Tower__r.Name
        ]) {
            Id projectId = (Id) ar.get('projectId');
            ProjectOption project = projects.get(projectId);
            if (project == null) {
                project = new ProjectOption();
                project.id = projectId;
                project.name = (String) ar.get('projectName');
                projects.put(projectId, project);
            }
            TowerOption tower = new TowerOption();
            tower.id = (Id) ar.get('towerId');
            tower.name = (String) ar.get('towerName');
            tower.unitCount = (Integer) ar.get('unitCount');
            project.towers.add(tower);
        }
        return projects.values();
    }

    @AuraEnabled(cacheable=true)
    public static TowerData getTowerUnits(Id towerId) {
        return loadTower(towerId);
    }

    // Not cacheable: the Select Inventory modal refetches after every save.
    @AuraEnabled
    public static TowerData getTowerUnitsFresh(Id towerId) {
        return loadTower(towerId);
    }

    /** Open residential opportunities matching the term, this project's first, for tagging from the Stock tab. */
    @AuraEnabled
    public static List<OpportunityOption> searchOpportunities(String term, Id projectId) {
        if (String.isBlank(term) || term.trim().length() < 2) {
            return new List<OpportunityOption>();
        }
        String likeTerm = '%' + term.trim() + '%';
        List<OpportunityOption> sameProject = new List<OpportunityOption>();
        List<OpportunityOption> others = new List<OpportunityOption>();
        for (Opportunity o : [
            SELECT Id, Name, StageName, Account.Name, Interested_Unit__r.Name, Interested_Unit__r.Property__c
            FROM Opportunity
            WHERE IsClosed = false AND RecordType.DeveloperName = :RESIDENTIAL_OPPORTUNITY
              AND (Name LIKE :likeTerm OR Account.Name LIKE :likeTerm)
              AND Id NOT IN (SELECT Opportunity_Id__c FROM Booking__c WHERE Status__c != :STATUS_CANCELLED)
            ORDER BY LastModifiedDate DESC
            LIMIT 20
        ]) {
            Boolean inProject = projectId != null && o.Interested_Unit__r?.Property__c == projectId;
            (inProject ? sameProject : others).add(new OpportunityOption(o));
        }
        sameProject.addAll(others);
        return sameProject;
    }

    @AuraEnabled
    public static OpportunityContext getOpportunityContext(Id opportunityId) {
        Opportunity opp = [
            SELECT Id, Name, IsClosed, StageName, Interested_Unit__c, Interested_Unit__r.Name,
                   Interested_Unit__r.Tower__c, Interested_Unit__r.Tower__r.Property__c
            FROM Opportunity
            WHERE Id = :opportunityId
        ];
        OpportunityContext ctx = new OpportunityContext();
        ctx.opportunityId = opp.Id;
        ctx.opportunityName = opp.Name;
        ctx.unitId = opp.Interested_Unit__c;
        ctx.unitName = opp.Interested_Unit__r?.Name;
        ctx.towerId = opp.Interested_Unit__r?.Tower__c;
        ctx.projectId = opp.Interested_Unit__r?.Tower__r?.Property__c;
        ctx.lockedReason = lockedReason(opp);
        return ctx;
    }

    /**
     * Tags the unit to the opportunity (Interested_Unit__c) and marks it Reserved. A unit this
     * opportunity previously reserved goes back to Available, unless another opportunity also points to it.
     * Status changes are not pushed to SAP (SAP_Sync_Status__c is left alone).
     */
    @AuraEnabled
    public static void tagUnit(Id opportunityId, Id unitId) {
        try {
            Opportunity opp = [SELECT Id, IsClosed, StageName, Interested_Unit__c FROM Opportunity WHERE Id = :opportunityId FOR UPDATE];
            Unit__c unit = [SELECT Id, Name, Status__c FROM Unit__c WHERE Id = :unitId FOR UPDATE];
            Id previousUnitId = opp.Interested_Unit__c;
            if (previousUnitId == unitId) {
                return;
            }
            String locked = lockedReason(opp);
            if (locked != null) {
                throw new TowerExplorerException(locked);
            }
            if (unit.Status__c != STATUS_AVAILABLE) {
                throw new TowerExplorerException(unit.Name + ' is ' + unit.Status__c + ' and can no longer be selected.');
            }

            opp.Interested_Unit__c = unitId;
            updateWithRetry(opp);

            List<Unit__c> unitUpdates = new List<Unit__c>{ new Unit__c(Id = unitId, Status__c = STATUS_RESERVED) };
            if (previousUnitId != null) {
                Unit__c previous = [SELECT Id, Status__c FROM Unit__c WHERE Id = :previousUnitId FOR UPDATE];
                Integer otherOpps = [
                    SELECT COUNT() FROM Opportunity
                    WHERE Interested_Unit__c = :previousUnitId AND Id != :opportunityId AND IsClosed = false
                ];
                if (previous.Status__c == STATUS_RESERVED && otherOpps == 0) {
                    unitUpdates.add(new Unit__c(Id = previousUnitId, Status__c = STATUS_AVAILABLE));
                }
            }
            update unitUpdates;
        } catch (DmlException ex) {
            throw new AuraHandledException(friendlyDmlMessage(ex));
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /** Why the opportunity's unit can't be changed here, or null if it can. */
    private static String lockedReason(Opportunity opp) {
        if (opp.IsClosed) {
            return 'This opportunity is ' + opp.StageName + ', so its unit can no longer be changed.';
        }
        List<Booking__c> bookings = [
            SELECT Name, Unit_Id__r.Name FROM Booking__c
            WHERE Opportunity_Id__c = :opp.Id AND Status__c != :STATUS_CANCELLED
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (!bookings.isEmpty()) {
            return 'Already booked as ' + bookings[0].Name
                + (bookings[0].Unit_Id__r != null ? ' for ' + bookings[0].Unit_Id__r.Name : '')
                + '. Change the unit through the booking (cancellation or transfer), not here.';
        }
        return null;
    }

    /**
     * Saving an opportunity locks the customer's account, and the unit-change cascade (booking
     * conditions, SAP sync) can hold that lock for a few seconds. Retry before giving up.
     */
    @TestVisible
    private static void updateWithRetry(SObject record) {
        for (Integer attempt = 1; ; attempt++) {
            try {
                update record;
                return;
            } catch (DmlException ex) {
                if (ex.getDmlType(0) != StatusCode.UNABLE_TO_LOCK_ROW || attempt == 3) {
                    throw ex;
                }
            }
        }
    }

    private static String friendlyDmlMessage(DmlException ex) {
        if (ex.getDmlType(0) == StatusCode.UNABLE_TO_LOCK_ROW) {
            return 'This customer\'s records are being updated by another process (for example the SAP sync). Wait a few seconds and save again.';
        }
        return ex.getDmlMessage(0);
    }

    private static TowerData loadTower(Id towerId) {
        Tower__c tower = [
            SELECT Id, Name, Property__c, Property__r.Name, Chargeable_Area_Type__c,
                   Club_Membership_Fees__c, Legal_Fees__c, BESCOM_BWSSB_Charges__c, Maintenance_Deposit_Corpus_Fund__c
            FROM Tower__c
            WHERE Id = :towerId
        ];
        TowerData data = new TowerData();
        data.towerId = tower.Id;
        data.towerName = tower.Name;
        data.projectId = tower.Property__c;
        data.projectName = tower.Property__r?.Name;
        data.chargeableAreaType = tower.Chargeable_Area_Type__c;
        data.ratePerSqft = activeRate(towerId);

        for (Unit__c u : [
            SELECT Id, Name, Status__c, BHK_Configuration__c, Unit_Type__c, Floor__c, Floor__r.Name,
                   Carpet_Area__c, Saleable_Area__c, Built_Up_Area_SBA__c, Deck_Balcony__c,
                   Number_of_Car_Parkings__c, RERA_Number__c, Base_Price__c, Construction_Charges__c,
                   Land_Charges__c, Club_Membership_Fees__c, Legal_Fees__c, BESCOM_BWSSB_Charges__c,
                   Maintenance_Deposit_Corpus_Fund__c
            FROM Unit__c
            WHERE Tower__c = :towerId AND (Unit_Group__c = null OR Unit_Group__c != :OTHER_CHARGES_GROUP)
            ORDER BY Name
        ]) {
            data.units.add(toRow(u, tower, data.ratePerSqft));
        }

        Map<Id, UnitRow> rowById = new Map<Id, UnitRow>();
        for (UnitRow row : data.units) {
            rowById.put(row.id, row);
        }
        for (Opportunity o : [
            SELECT Id, Name, StageName, Account.Name, Interested_Unit__c, Interested_Unit__r.Name
            FROM Opportunity
            WHERE Interested_Unit__c IN :rowById.keySet() AND IsClosed = false
            ORDER BY LastModifiedDate DESC
        ]) {
            rowById.get(o.Interested_Unit__c).tags.add(new OpportunityOption(o));
        }
        return data;
    }

    private static Decimal activeRate(Id towerId) {
        Date today = Date.today();
        List<BusinessPlanPrice__c> prices = [
            SELECT PricePerSqFt__c
            FROM BusinessPlanPrice__c
            WHERE Tower__c = :towerId AND IsActive__c = true
              AND (EffectiveFrom__c = null OR EffectiveFrom__c <= :today)
              AND (EffectiveTo__c = null OR EffectiveTo__c >= :today)
            ORDER BY EffectiveFrom__c DESC NULLS LAST
            LIMIT 1
        ];
        return prices.isEmpty() ? null : prices[0].PricePerSqFt__c;
    }

    private static UnitRow toRow(Unit__c u, Tower__c tower, Decimal rate) {
        UnitRow row = new UnitRow();
        row.id = u.Id;
        row.name = u.Name;
        row.status = u.Status__c;
        row.bhk = u.BHK_Configuration__c;
        row.unitType = u.Unit_Type__c;
        row.floorId = u.Floor__c;
        row.floorName = u.Floor__r?.Name;
        row.carpetArea = u.Carpet_Area__c;
        row.saleableArea = u.Saleable_Area__c;
        row.sbaArea = u.Built_Up_Area_SBA__c;
        row.balconyArea = u.Deck_Balcony__c;
        row.carParks = u.Number_of_Car_Parkings__c;
        row.rera = u.RERA_Number__c;

        Integer unitNumber = trailingNumber(u.Name);
        Integer floorFromName = leadingNumber(u.Floor__r?.Name);
        row.floorNumber = floorFromName != null ? floorFromName : (unitNumber != null && unitNumber >= 100 ? unitNumber / 100 : null);
        row.position = unitNumber != null && unitNumber >= 100 ? Math.mod(unitNumber, 100) : null;

        if (tower.Chargeable_Area_Type__c == 'Super Built up Area') {
            row.chargeableArea = u.Built_Up_Area_SBA__c;
        } else if (tower.Chargeable_Area_Type__c == 'Saleable Area') {
            row.chargeableArea = u.Saleable_Area__c;
        } else {
            row.chargeableArea = u.Carpet_Area__c;
        }

        if (u.Base_Price__c != null && u.Base_Price__c > 0) {
            row.basePrice = u.Base_Price__c;
        } else if (rate != null && row.chargeableArea != null) {
            row.basePrice = rate * row.chargeableArea;
            row.baseFromRate = true;
        }
        row.constructionCharges = u.Construction_Charges__c;
        row.landCharges = u.Land_Charges__c;
        row.clubCharges = firstPositive(u.Club_Membership_Fees__c, tower.Club_Membership_Fees__c);
        row.legalFees = firstPositive(u.Legal_Fees__c, tower.Legal_Fees__c);
        row.utilityCharges = firstPositive(u.BESCOM_BWSSB_Charges__c, tower.BESCOM_BWSSB_Charges__c);
        row.maintenanceDeposit = firstPositive(u.Maintenance_Deposit_Corpus_Fund__c, tower.Maintenance_Deposit_Corpus_Fund__c);

        if (row.basePrice != null) {
            row.allInPrice = row.basePrice + nz(row.constructionCharges) + nz(row.landCharges) + nz(row.clubCharges)
                + nz(row.legalFees) + nz(row.utilityCharges) + nz(row.maintenanceDeposit);
            if (row.chargeableArea != null && row.chargeableArea > 0) {
                row.allInPerSqft = (row.allInPrice / row.chargeableArea).setScale(0);
            }
        }
        return row;
    }

    private static Integer trailingNumber(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        Matcher m = Pattern.compile('(\\d+)\\D*$').matcher(value);
        return m.find() ? Integer.valueOf(m.group(1)) : null;
    }

    private static Integer leadingNumber(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        if (value.trim().toLowerCase().startsWith('ground')) {
            return 0;
        }
        Matcher m = Pattern.compile('(\\d+)').matcher(value);
        return m.find() ? Integer.valueOf(m.group(1)) : null;
    }

    private static Decimal firstPositive(Decimal primary, Decimal fallback) {
        return primary != null && primary > 0 ? primary : fallback;
    }

    private static Decimal nz(Decimal value) {
        return value == null ? 0 : value;
    }

    public class TowerExplorerException extends Exception {}
}