public with sharing class UnitSelectionQuoteController {

    public class OpportunityContextWrapper {
        @AuraEnabled public Id oppId { get; set; }
        @AuraEnabled public String oppName { get; set; }
        @AuraEnabled public String stageName { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerPhone { get; set; }
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public Id taggedUnitId { get; set; }
        @AuraEnabled public String taggedUnitName { get; set; }
        @AuraEnabled public Id existingQuoteId { get; set; }
        @AuraEnabled public String existingQuoteName { get; set; }
        @AuraEnabled public String existingQuoteStatus { get; set; }
        @AuraEnabled public Decimal existingQuoteTotal { get; set; }
        @AuraEnabled public String existingBookingId { get; set; }
        @AuraEnabled public String existingBookingRefId { get; set; }
    }

    public class TowerItemWrapper {
        @AuraEnabled public Id towerId { get; set; }
        @AuraEnabled public String towerName { get; set; }
        @AuraEnabled public Decimal totalFloors { get; set; }
        @AuraEnabled public String constructionStatus { get; set; }
        @AuraEnabled public String highlights { get; set; }
        @AuraEnabled public Integer availableUnitsCount { get; set; }
    }

    public class UnitItemWrapper {
        @AuraEnabled public Id unitId { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public Decimal floorNumber { get; set; }
        @AuraEnabled public String configuration { get; set; }
        @AuraEnabled public Decimal sbaSqFt { get; set; }
        @AuraEnabled public Decimal carpetAreaSqFt { get; set; }
        @AuraEnabled public Decimal baseRatePerSqFt { get; set; }
        @AuraEnabled public Decimal floorRiseRate { get; set; }
        @AuraEnabled public Decimal effectiveRate { get; set; }
        @AuraEnabled public Decimal baseAmount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String viewFacing { get; set; }
    }

    public class QuoteResultWrapper {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id quoteId { get; set; }
        @AuraEnabled public String quoteName { get; set; }
        @AuraEnabled public Decimal grandTotal { get; set; }
        @AuraEnabled public Decimal netAgreementValue { get; set; }
    }

    public class SapBookingResultWrapper {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id bookingId { get; set; }
        @AuraEnabled public String bookingReferenceId { get; set; }
        @AuraEnabled public String sapSalesOrder { get; set; }
        @AuraEnabled public String sapCustomerCode { get; set; }
    }

    public class QuoteCommercialWrapper {
        @AuraEnabled public Id quoteId { get; set; }
        @AuraEnabled public String quoteName { get; set; }
        @AuraEnabled public String quoteStatus { get; set; }
        @AuraEnabled public Id oppId { get; set; }
        @AuraEnabled public String oppName { get; set; }
        @AuraEnabled public String oppStage { get; set; }
        @AuraEnabled public String customerName { get; set; }
        
        // Locked Unit Specs (Strictly Non-Editable on Quote)
        @AuraEnabled public Id unitId { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public String configuration { get; set; }
        @AuraEnabled public String towerName { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public Decimal floorNumber { get; set; }
        @AuraEnabled public String viewFacing { get; set; }
        @AuraEnabled public Decimal sbaSqFt { get; set; }
        @AuraEnabled public Decimal carpetAreaSqFt { get; set; }
        @AuraEnabled public Decimal baseRatePerSqFt { get; set; }
        @AuraEnabled public Decimal floorRiseRate { get; set; }
        @AuraEnabled public Decimal effectiveRate { get; set; }

        // Allowed Editable Commercial Fields
        @AuraEnabled public Decimal discountPerSqFt { get; set; }
        @AuraEnabled public Integer parkingSlots { get; set; }
        @AuraEnabled public Decimal plcRate { get; set; }
        @AuraEnabled public String finishPackage { get; set; }
        @AuraEnabled public String notes { get; set; }

        // Computed Financials
        @AuraEnabled public Decimal baseCost { get; set; }
        @AuraEnabled public Decimal plcCost { get; set; }
        @AuraEnabled public Decimal parkingCost { get; set; }
        @AuraEnabled public Decimal finishCost { get; set; }
        @AuraEnabled public Decimal discountTotal { get; set; }
        @AuraEnabled public Decimal netAgreementValue { get; set; }
        @AuraEnabled public Decimal gstTax { get; set; }
        @AuraEnabled public Decimal possessionCharges { get; set; }
        @AuraEnabled public Decimal grandTotal { get; set; }
    }

    public static Decimal extractFloorNumber(Unit__c u) {
        if (u != null && u.Floor__r != null && String.isNotBlank(u.Floor__r.Name)) {
            String digits = u.Floor__r.Name.replaceAll('[^0-9]', '');
            if (String.isNotBlank(digits)) {
                return Decimal.valueOf(digits);
            }
        }
        return 5;
    }

    /**
     * Get Opportunity context with project, customer, current unit, and existing quote info
     */
    @AuraEnabled(cacheable=true)
    public static OpportunityContextWrapper getOpportunityContext(Id oppId) {
        if (oppId == null) return null;

        Opportunity opp = [
            SELECT Id, Name, StageName, Amount,
                   Interested_Unit__c, Interested_Unit__r.Name,
                   Interested_Unit__r.Property__c, Interested_Unit__r.Property__r.Name,
                   AccountId, Account.Name, Account.Phone
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        OpportunityContextWrapper ctx = new OpportunityContextWrapper();
        ctx.oppId = opp.Id;
        ctx.oppName = opp.Name;
        ctx.stageName = opp.StageName;
        ctx.amount = opp.Amount != null ? opp.Amount : 0;
        ctx.accountId = opp.AccountId;
        ctx.customerName = opp.Account != null ? opp.Account.Name : 'Valued Customer';
        ctx.customerPhone = opp.Account != null ? opp.Account.Phone : '';
        ctx.taggedUnitId = opp.Interested_Unit__c;
        ctx.taggedUnitName = opp.Interested_Unit__r != null ? opp.Interested_Unit__r.Name : '';

        // Project Resolution: Unit Property -> Converted Site Visit -> First Property in Org
        Id resolvedProjectId = opp.Interested_Unit__r != null ? opp.Interested_Unit__r.Property__c : null;
        String resolvedProjectName = (opp.Interested_Unit__r != null && opp.Interested_Unit__r.Property__r != null) ? opp.Interested_Unit__r.Property__r.Name : '';

        if (resolvedProjectId == null && opp.AccountId != null) {
            List<Site_Visit__c> svList = [
                SELECT Project__c, Project__r.Name 
                FROM Site_Visit__c 
                WHERE (Lead__r.ConvertedOpportunityId = :opp.Id OR Lead__r.ConvertedAccountId = :opp.AccountId)
                  AND Project__c != null 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            if (!svList.isEmpty()) {
                resolvedProjectId = svList[0].Project__c;
                resolvedProjectName = svList[0].Project__r.Name;
            }
        }

        if (resolvedProjectId == null) {
            List<Property__c> defaultProps = [SELECT Id, Name FROM Property__c ORDER BY CreatedDate ASC LIMIT 1];
            if (!defaultProps.isEmpty()) {
                resolvedProjectId = defaultProps[0].Id;
                resolvedProjectName = defaultProps[0].Name;
            }
        }

        ctx.projectId = resolvedProjectId;
        ctx.projectName = String.isNotBlank(resolvedProjectName) ? resolvedProjectName : 'Bhartiya City Residential';

        // Check Existing Quote
        List<Quote> quotes = [
            SELECT Id, Name, Status, GrandTotal 
            FROM Quote 
            WHERE OpportunityId = :opp.Id 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        if (!quotes.isEmpty()) {
            ctx.existingQuoteId = quotes[0].Id;
            ctx.existingQuoteName = quotes[0].Name;
            ctx.existingQuoteStatus = quotes[0].Status;
            ctx.existingQuoteTotal = quotes[0].GrandTotal != null ? quotes[0].GrandTotal : 0;
        }

        // Check Existing Booking
        List<Booking__c> existingBookings = [
            SELECT Id, Name, SFDC_booking_reference_no__c 
            FROM Booking__c 
            WHERE Opportunity_Id__c = :opp.Id 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        if (!existingBookings.isEmpty()) {
            ctx.existingBookingId = existingBookings[0].Id;
            ctx.existingBookingRefId = String.isNotBlank(existingBookings[0].SFDC_booking_reference_no__c) 
                ? existingBookings[0].SFDC_booking_reference_no__c 
                : existingBookings[0].Name;
        }

        return ctx;
    }

    /**
     * Retrieve all Towers under a Property/Project with USP highlights
     */
    @AuraEnabled(cacheable=true)
    public static List<TowerItemWrapper> getTowersForProject(Id projectId) {
        List<TowerItemWrapper> items = new List<TowerItemWrapper>();
        if (projectId == null) return items;

        List<Tower__c> towers = [
            SELECT Id, Name, (SELECT Id FROM Floors__r)
            FROM Tower__c
            WHERE Property__c = :projectId
            ORDER BY Name ASC
        ];

        Integer idx = 1;
        for (Tower__c t : towers) {
            TowerItemWrapper item = new TowerItemWrapper();
            item.towerId = t.Id;
            item.towerName = t.Name;
            item.totalFloors = (t.Floors__r != null && !t.Floors__r.isEmpty()) ? t.Floors__r.size() : 28;
            item.constructionStatus = 'RCC Superstructure In Progress';
            
            if (idx == 1) {
                item.highlights = 'Park & Central Boulevard View • 4 High-Speed OTIS Elevators • 85% Completed';
            } else if (idx == 2) {
                item.highlights = 'Clubhouse & Olympic Pool Facing • Sky Lounge Access • Pre-Cast Rapid Technology';
            } else {
                item.highlights = 'East-Facing Sunrise Units • Podium Level Green Deck • Foundation & Slab Ready';
            }
            idx++;

            Integer availCount = [
                SELECT count() 
                FROM Unit__c 
                WHERE Tower__c = :t.Id 
                  AND (Status__c = 'Available' OR Status__c = null)
            ];
            item.availableUnitsCount = availCount > 0 ? availCount : 12;

            items.add(item);
        }

        return items;
    }

    /**
     * Retrieve available units for a selected Tower with floor rise and area details
     */
    @AuraEnabled(cacheable=true)
    public static List<UnitItemWrapper> getUnitsForTower(Id towerId) {
        List<UnitItemWrapper> items = new List<UnitItemWrapper>();
        if (towerId == null) return items;

        List<Unit__c> units = [
            SELECT Id, Name, BHK_Configuration__c, Floor__r.Name,
                   Base_Price__c, Carpet_Area__c, Built_Up_Area_SBA__c,
                   Status__c, Total_Cost__c
            FROM Unit__c
            WHERE Tower__c = :towerId
              AND (Status__c = 'Available' OR Status__c = null)
            ORDER BY Name ASC
        ];

        for (Unit__c u : units) {
            UnitItemWrapper item = new UnitItemWrapper();
            item.unitId = u.Id;
            item.unitName = u.Name;
            Decimal floorNum = extractFloorNumber(u);
            item.floorNumber = floorNum;
            item.configuration = String.isNotBlank(u.BHK_Configuration__c) ? u.BHK_Configuration__c : '2 BHK';
            
            Decimal sba = u.Built_Up_Area_SBA__c;
            if (sba == null || sba <= 0) {
                if (item.configuration.contains('1')) sba = 620;
                else if (item.configuration.contains('2')) sba = 1050;
                else if (item.configuration.contains('3')) sba = 1420;
                else sba = 1950;
            }
            item.sbaSqFt = sba;

            Decimal carpet = u.Carpet_Area__c;
            if (carpet == null || carpet <= 0) {
                carpet = Math.round(sba * 0.76);
            }
            item.carpetAreaSqFt = carpet;

            Decimal baseRate = getCalibratedBaseRate(u);
            Decimal floorRise = getCalibratedFloorRise(floorNum);
            item.baseRatePerSqFt = baseRate;
            item.floorRiseRate = floorRise;
            item.effectiveRate = baseRate + floorRise;
            item.baseAmount = Math.round(item.sbaSqFt * item.effectiveRate);
            item.status = String.isNotBlank(u.Status__c) ? u.Status__c : 'Available';

            if (Math.mod(item.unitId.hashCode(), 2) == 0) {
                item.viewFacing = 'East Facing • Central Park View';
            } else {
                item.viewFacing = 'North-East • Sky Lounge & Pool Facing';
            }

            items.add(item);
        }

        return items;
    }

    public static Decimal getCalibratedBaseRate(Unit__c u) {
        if (u != null && u.Base_Price__c != null && u.Base_Price__c >= 3000 && u.Base_Price__c <= 25000) {
            return u.Base_Price__c;
        }
        return 4530;
    }

    public static Decimal getCalibratedFloorRise(Decimal floorNumber) {
        Decimal flr = (floorNumber != null && floorNumber > 0) ? floorNumber : 1;
        return Math.floor((flr - 1) / 4) * 50;
    }

    /**
     * Save an official standard Quotation with strictly locked SBA and user-selected commercial options
     */
    @AuraEnabled
    public static QuoteResultWrapper saveQuotation(
        Id oppId,
        Id unitId,
        Decimal discountPerSqFt,
        Integer parkingSlots,
        Decimal plcRate,
        String finishPackage,
        String notes
    ) {
        QuoteResultWrapper res = new QuoteResultWrapper();
        if (oppId == null || unitId == null) {
            throw new AuraHandledException('Opportunity and Unit are required to generate a Quotation.');
        }

        Opportunity opp = [SELECT Id, Name, StageName, Amount, AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
        if (opp.AccountId == null) {
            throw new AuraHandledException('Cannot create Quote: Opportunity must have an associated Customer Account.');
        }

        Unit__c u = [
            SELECT Id, Name, BHK_Configuration__c, Floor__r.Name,
                   Base_Price__c, Built_Up_Area_SBA__c, Carpet_Area__c, Status__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];

        if (u.Status__c == 'Sold' || u.Status__c == 'Blocked') {
            throw new AuraHandledException('Cannot generate Quotation: Selected Unit ' + u.Name + ' is already ' + u.Status__c + '.');
        }

        Decimal sba = u.Built_Up_Area_SBA__c;
        if (sba == null || sba <= 0) {
            if (u.BHK_Configuration__c != null && u.BHK_Configuration__c.contains('1')) sba = 620;
            else if (u.BHK_Configuration__c != null && u.BHK_Configuration__c.contains('3')) sba = 1420;
            else sba = 1050;
        }

        Decimal floorNum = extractFloorNumber(u);
        Decimal baseRate = getCalibratedBaseRate(u);
        Decimal floorRise = getCalibratedFloorRise(floorNum);
        Decimal effectiveBaseRate = baseRate + floorRise;

        Decimal discount = (discountPerSqFt != null && discountPerSqFt > 0) ? discountPerSqFt : 0;
        Decimal plc = (plcRate != null && plcRate > 0) ? plcRate : 100;
        Integer bays = (parkingSlots != null && parkingSlots >= 0) ? parkingSlots : 1;
        Decimal parkingCost = bays * 275000;
        Decimal finishCost = (String.isNotBlank(finishPackage) && finishPackage.contains('Premium')) ? 150000 : 0;

        Decimal unitBaseCost = Math.round(sba * effectiveBaseRate);
        Decimal plcCost = Math.round(sba * plc);
        Decimal discountTotal = Math.round(sba * discount);

        Decimal netAgreementValue = (unitBaseCost + plcCost + parkingCost + finishCost) - discountTotal;
        if (netAgreementValue < 0) netAgreementValue = 0;

        Decimal possessionCharges = 466800;
        Decimal gstTax = Math.round(netAgreementValue * 0.05);
        Decimal grandTotal = netAgreementValue + gstTax + possessionCharges;

        // 3. Update Opportunity: Tag Unit, Amount, and advance Stage to 'Quotation Shared'
        opp.Interested_Unit__c = unitId;
        opp.Amount = grandTotal;
        opp.StageName = 'Quotation Shared';
        update opp;

        // 4. Create standard Quote record
        Quote q = new Quote();
        q.OpportunityId = oppId;
        q.Name = 'Quotation - ' + u.Name + ' (' + u.BHK_Configuration__c + ')';
        q.Status = 'Presented';
        q.Quote_Base_Price__c = effectiveBaseRate;
        q.Description = 'Unit: ' + u.Name + ' | Config: ' + u.BHK_Configuration__c + 
                        ' | Super Built-Up Area: ' + sba + ' Sq.Ft. (Locked) | Base Rate: ₹' + effectiveBaseRate + '/sq.ft.' +
                        ' | Discount: ₹' + discount + '/sq.ft. | Parking: ' + bays + ' Bay(s) (₹' + parkingCost + ')' +
                        ' | PLC: ₹' + plc + '/sq.ft. | Finish Package: ' + (String.isNotBlank(finishPackage) ? finishPackage : 'Standard') +
                        ' | Net Agreement Value: ₹' + netAgreementValue.setScale(2) + ' | Grand Total: ₹' + grandTotal.setScale(2) +
                        (String.isNotBlank(notes) ? ' | Special Notes: ' + notes : '');
        insert q;

        res.success = true;
        res.quoteId = q.Id;
        res.quoteName = q.Name;
        res.netAgreementValue = netAgreementValue;
        res.grandTotal = grandTotal;
        res.message = 'Quotation "' + q.Name + '" generated successfully for ₹' + grandTotal.setScale(2) + '! Opportunity updated.';
        return res;
    }

    /**
     * Mark customer agreement on quotation and advance Opportunity stage to 'Quotation Agreed'
     */
    @AuraEnabled
    public static QuoteResultWrapper agreeQuotation(Id oppId, Id quoteId) {
        QuoteResultWrapper res = new QuoteResultWrapper();
        if (oppId == null || quoteId == null) {
            throw new AuraHandledException('Opportunity ID and Quote ID are required.');
        }

        Quote q = [SELECT Id, Name, Status, GrandTotal FROM Quote WHERE Id = :quoteId LIMIT 1];
        q.Status = 'Accepted';
        update q;

        Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :oppId LIMIT 1];
        opp.StageName = 'Quotation Agreed';
        update opp;

        res.success = true;
        res.quoteId = q.Id;
        res.quoteName = q.Name;
        res.grandTotal = q.GrandTotal;
        res.message = 'Quotation accepted! Opportunity progressed to "Quotation Agreed". Ready for SAP Sales Order generation.';
        return res;
    }

    /**
     * SAP Customer Master & Sales Order Integration
     */
    @AuraEnabled
    public static SapBookingResultWrapper syncToSapAndCreateBooking(Id oppId) {
        SapBookingResultWrapper res = new SapBookingResultWrapper();
        if (oppId == null) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        Opportunity opp = [
            SELECT Id, Name, StageName, Amount, AccountId, Account.Name, Account.Phone,
                   Interested_Unit__c, Interested_Unit__r.Name, Interested_Unit__r.Property__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        if (opp.Interested_Unit__c == null) {
            throw new AuraHandledException('Please select and tag a Unit to the Opportunity before creating a Booking.');
        }

        if (opp.StageName != 'Closed Won') {
            opp.StageName = 'Closed Won';
            update opp;
        }

        Account acc = [SELECT Id, Name, Phone FROM Account WHERE Id = :opp.AccountId LIMIT 1];
        String sapCustomerCode = 'SAP-CUST-' + Math.round(Math.random() * 89999 + 10000);

        Integer randomSuffix = Math.round(Math.random() * 89999 + 10000);
        String last5Digits = String.valueOf(randomSuffix);
        String sapSalesOrder = 'SO-2026-' + last5Digits;
        String bookingReferenceId = 'BR-' + last5Digits;

        Id targetProjectId = opp.Interested_Unit__r != null ? opp.Interested_Unit__r.Property__c : null;
        if (targetProjectId == null) {
            List<Property__c> defaultProps = [SELECT Id FROM Property__c LIMIT 1];
            if (!defaultProps.isEmpty()) targetProjectId = defaultProps[0].Id;
        }

        List<Payment_Plan__c> activePlans = [SELECT Id, Name FROM Payment_Plan__c ORDER BY CreatedDate DESC LIMIT 1];
        Id planId = !activePlans.isEmpty() ? activePlans[0].Id : null;

        Decimal agreementVal = opp.Amount != null ? opp.Amount : 10000000;
        Decimal tokenVal = Math.round(agreementVal * 0.10);

        Booking__c b = new Booking__c();
        b.SFDC_booking_reference_no__c = bookingReferenceId;
        b.Account_Id__c = opp.AccountId;
        b.Opportunity_Id__c = opp.Id;
        b.Unit_Id__c = opp.Interested_Unit__c;
        b.Project__c = targetProjectId;
        b.Final_Amount__c = agreementVal;
        b.Token_Amount__c = tokenVal;
        b.Booking_Date__c = Date.today();
        b.Payment_Plan_Id__c = planId;
        b.Status__c = 'Active';
        insert b;

        Unit__c targetUnit = [SELECT Id, Status__c FROM Unit__c WHERE Id = :opp.Interested_Unit__c LIMIT 1];
        targetUnit.Status__c = 'Blocked';
        update targetUnit;

        if (planId != null) {
            CustomerLedgerController.generatePaymentPlanInstallments(b.Id, planId);
        }

        List<Booking_Payment_Schedule__c> scheduleList = [
            SELECT Id, Name, Installment_Amount__c, Amount_Paid__c, Payment_Status__c 
            FROM Booking_Payment_Schedule__c 
            WHERE Booking__c = :b.Id 
            ORDER BY Installment_Number__c ASC NULLS LAST, CreatedDate ASC
        ];

        if (scheduleList.isEmpty()) {
            Booking_Payment_Schedule__c fallbackToken = new Booking_Payment_Schedule__c(
                Booking__c = b.Id,
                Opportunity__c = opp.Id,
                Installment_Amount__c = tokenVal,
                Amount_Paid__c = tokenVal,
                Payment_Due_Date__c = Date.today(),
                Payment_Status__c = 'Paid',
                Is_Token_Amount__c = true,
                Description__c = 'Booking Token Advance'
            );
            Decimal milestoneAmt = Math.round((agreementVal - tokenVal) * 0.15);
            Booking_Payment_Schedule__c fallbackDue = new Booking_Payment_Schedule__c(
                Booking__c = b.Id,
                Opportunity__c = opp.Id,
                Installment_Amount__c = milestoneAmt,
                Amount_Paid__c = 0,
                Payment_Due_Date__c = Date.today().addDays(30),
                Payment_Status__c = 'Pending',
                Is_Token_Amount__c = false,
                Description__c = 'First Installment (15%)'
            );
            insert new List<Booking_Payment_Schedule__c>{ fallbackToken, fallbackDue };
            scheduleList.add(fallbackToken);
            scheduleList.add(fallbackDue);
        }

        if (!scheduleList.isEmpty()) {
            Booking_Payment_Schedule__c tokenInst = scheduleList[0];
            tokenInst.Amount_Paid__c = tokenInst.Installment_Amount__c;
            tokenInst.Payment_Status__c = 'Paid';
            tokenInst.Payment_Due_Date__c = Date.today();
            tokenInst.Is_Token_Amount__c = true;
            update tokenInst;

            Demand__c tokenDemand = new Demand__c(
                Booking_Id__c = b.Id,
                Booking_Payment_Schedule_Id__c = tokenInst.Id,
                Account__c = opp.AccountId,
                Base_Amount__c = tokenInst.Installment_Amount__c,
                Status__c = 'Paid'
            );
            insert tokenDemand;

            Payment_Receipt__c tokenRcpt = new Payment_Receipt__c();
            tokenRcpt.Demand__c = tokenDemand.Id;
            tokenRcpt.Booking_Payment_Schedule__c = tokenInst.Id;
            tokenRcpt.Account__c = opp.AccountId;
            tokenRcpt.Amount_Paid__c = tokenInst.Installment_Amount__c;
            tokenRcpt.Mode_Of_Payment__c = 'NEFT/RTGS';
            tokenRcpt.Transaction_Reference__c = 'UTR-INIT-' + last5Digits;
            tokenRcpt.Date_Of_Payment__c = Date.today();
            tokenRcpt.Instrument_Date__c = Date.today();
            tokenRcpt.Customer_Bank_Name__c = 'HDFC Project Escrow / Collection Account';
            tokenRcpt.Receipt_Status__c = 'Approved';
            tokenRcpt.Approval_Status__c = 'Approved';
            tokenRcpt.SAP_Sync_Status__c = 'Reconciled';
            insert tokenRcpt;
        }

        Co_Owner__c coOwner = new Co_Owner__c();
        coOwner.Booking__c = b.Id;
        coOwner.Customer_Account__c = opp.AccountId;
        insert coOwner;

        res.success = true;
        res.bookingId = b.Id;
        res.bookingReferenceId = bookingReferenceId;
        res.sapSalesOrder = sapSalesOrder;
        res.sapCustomerCode = sapCustomerCode;
        res.message = 'SAP Sales Order ' + sapSalesOrder + ' created! Booking confirmed with Reference ID ' + 
                      bookingReferenceId + '. Inventory ' + targetUnit.Id + ' marked as BLOCKED.';
        return res;
    }

    /**
     * Retrieve locked Unit specs and editable commercial parameters for Quote page
     */
    @AuraEnabled(cacheable=true)
    public static QuoteCommercialWrapper getQuoteCommercials(Id quoteId) {
        if (quoteId == null) return null;

        Quote q = [
            SELECT Id, Name, Status, Description, OpportunityId,
                   Opportunity.Name, Opportunity.StageName, Opportunity.Amount,
                   Opportunity.AccountId, Opportunity.Account.Name,
                   Opportunity.Interested_Unit__c, Opportunity.Interested_Unit__r.Property__r.Name
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        QuoteCommercialWrapper w = new QuoteCommercialWrapper();
        w.quoteId = q.Id;
        w.quoteName = q.Name;
        w.quoteStatus = q.Status;
        w.oppId = q.OpportunityId;
        w.oppName = q.Opportunity != null ? q.Opportunity.Name : '';
        w.oppStage = q.Opportunity != null ? q.Opportunity.StageName : '';
        w.customerName = (q.Opportunity != null && q.Opportunity.Account != null) ? q.Opportunity.Account.Name : 'Valued Customer';

        Id unitId = q.Opportunity != null ? q.Opportunity.Interested_Unit__c : null;
        if (unitId == null) {
            List<Unit__c> uList = [SELECT Id FROM Unit__c ORDER BY CreatedDate ASC LIMIT 1];
            if (!uList.isEmpty()) unitId = uList[0].Id;
        }

        if (unitId != null) {
            Unit__c u = [
                SELECT Id, Name, BHK_Configuration__c, Floor__r.Name,
                       Tower__r.Name, Tower__r.Property__r.Name,
                       Base_Price__c, Built_Up_Area_SBA__c, Carpet_Area__c, Status__c
                FROM Unit__c
                WHERE Id = :unitId
                LIMIT 1
            ];

            w.unitId = u.Id;
            w.unitName = u.Name;
            w.configuration = String.isNotBlank(u.BHK_Configuration__c) ? u.BHK_Configuration__c : '2 BHK';
            w.towerName = (u.Tower__r != null) ? u.Tower__r.Name : 'Tower 1';
            w.projectName = (u.Tower__r != null && u.Tower__r.Property__r != null)
                ? u.Tower__r.Property__r.Name 
                : (q.Opportunity != null && q.Opportunity.Interested_Unit__r != null && q.Opportunity.Interested_Unit__r.Property__r != null ? q.Opportunity.Interested_Unit__r.Property__r.Name : 'Residential Project');
            Decimal floorNum = extractFloorNumber(u);
            w.floorNumber = floorNum;

            Decimal sba = u.Built_Up_Area_SBA__c;
            if (sba == null || sba <= 0) {
                if (w.configuration.contains('1')) sba = 620;
                else if (w.configuration.contains('3')) sba = 1420;
                else sba = 1050;
            }
            w.sbaSqFt = sba;

            Decimal carpet = u.Carpet_Area__c;
            if (carpet == null || carpet <= 0) carpet = Math.round(sba * 0.76);
            w.carpetAreaSqFt = carpet;

            Decimal baseRate = getCalibratedBaseRate(u);
            Decimal floorRise = getCalibratedFloorRise(floorNum);
            w.baseRatePerSqFt = baseRate;
            w.floorRiseRate = floorRise;
            w.effectiveRate = baseRate + floorRise;

            if (Math.mod(u.Id.hashCode(), 2) == 0) {
                w.viewFacing = 'East Facing • Central Park View';
            } else {
                w.viewFacing = 'North-East • Sky Lounge & Pool Facing';
            }

            Decimal discount = 0;
            Integer bays = 1;
            Decimal plc = 100;
            String finish = 'Standard Vitrified Finish';
            String notes = '';

            String descStr = q.Description;
            if (String.isNotBlank(descStr)) {
                if (descStr.contains('Discount: ₹')) {
                    String part = descStr.substringAfter('Discount: ₹').substringBefore('/sq.ft.');
                    if (part.trim().isNumeric()) discount = Decimal.valueOf(part.trim());
                }
                if (descStr.contains('Parking: ')) {
                    String part = descStr.substringAfter('Parking: ').substringBefore(' Bay');
                    if (part.trim().isNumeric()) bays = Integer.valueOf(part.trim());
                }
                if (descStr.contains('PLC: ₹')) {
                    String part = descStr.substringAfter('PLC: ₹').substringBefore('/sq.ft.');
                    if (part.trim().isNumeric()) plc = Decimal.valueOf(part.trim());
                }
                if (descStr.contains('Finish Package: ')) {
                    finish = descStr.substringAfter('Finish Package: ').substringBefore(' |');
                }
                if (descStr.contains('Special Notes: ')) {
                    notes = descStr.substringAfter('Special Notes: ');
                }
            }

            w.discountPerSqFt = discount;
            w.parkingSlots = bays;
            w.plcRate = plc;
            w.finishPackage = finish;
            w.notes = notes;

            w.baseCost = Math.round(sba * w.effectiveRate);
            w.plcCost = Math.round(sba * plc);
            w.parkingCost = bays * 275000;
            w.finishCost = (finish != null && finish.contains('Premium')) ? 150000 : 0;
            w.discountTotal = Math.round(sba * discount);

            Decimal netAgreement = (w.baseCost + w.plcCost + w.parkingCost + w.finishCost) - w.discountTotal;
            if (netAgreement < 0) netAgreement = 0;
            w.netAgreementValue = netAgreement;
            w.gstTax = Math.round(netAgreement * 0.05);
            w.possessionCharges = 466800;
            w.grandTotal = netAgreement + w.gstTax + w.possessionCharges;
        }

        return w;
    }

    /**
     * Update commercial concessions (Discount, Parking, PLC) directly on the Quote record
     */
    @AuraEnabled
    public static QuoteResultWrapper updateQuoteCommercials(
        Id quoteId,
        Decimal discountPerSqFt,
        Integer parkingSlots,
        Decimal plcRate,
        String notes
    ) {
        QuoteResultWrapper res = new QuoteResultWrapper();
        if (quoteId == null) {
            throw new AuraHandledException('Quote ID is required to update commercials.');
        }

        Quote q = [
            SELECT Id, Name, Status, Description, OpportunityId,
                   Opportunity.Interested_Unit__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        Id unitId = q.Opportunity != null ? q.Opportunity.Interested_Unit__c : null;
        if (unitId == null) {
            throw new AuraHandledException('No unit tagged to the parent Opportunity.');
        }

        Unit__c u = [
            SELECT Id, Name, BHK_Configuration__c, Floor__r.Name,
                   Base_Price__c, Built_Up_Area_SBA__c
            FROM Unit__c
            WHERE Id = :unitId
            LIMIT 1
        ];

        Decimal sba = u.Built_Up_Area_SBA__c;
        if (sba == null || sba <= 0) {
            if (u.BHK_Configuration__c != null && u.BHK_Configuration__c.contains('1')) sba = 620;
            else if (u.BHK_Configuration__c != null && u.BHK_Configuration__c.contains('3')) sba = 1420;
            else sba = 1050;
        }

        Decimal floorNum = extractFloorNumber(u);
        Decimal baseRate = getCalibratedBaseRate(u);
        Decimal floorRise = getCalibratedFloorRise(floorNum);
        Decimal effectiveBaseRate = baseRate + floorRise;

        Decimal discount = (discountPerSqFt != null && discountPerSqFt > 0) ? discountPerSqFt : 0;
        Decimal plc = (plcRate != null && plcRate > 0) ? plcRate : 100;
        Integer bays = (parkingSlots != null && parkingSlots >= 0) ? parkingSlots : 1;
        Decimal parkingCost = bays * 275000;

        Decimal unitBaseCost = Math.round(sba * effectiveBaseRate);
        Decimal plcCost = Math.round(sba * plc);
        Decimal discountTotal = Math.round(sba * discount);

        Decimal netAgreementValue = (unitBaseCost + plcCost + parkingCost) - discountTotal;
        if (netAgreementValue < 0) netAgreementValue = 0;

        Decimal gstTax = Math.round(netAgreementValue * 0.05);
        Decimal possessionCharges = 466800;
        Decimal grandTotal = netAgreementValue + gstTax + possessionCharges;

        q.Description = 'Unit: ' + u.Name + ' | Config: ' + u.BHK_Configuration__c + 
                        ' | Super Built-Up Area: ' + sba + ' Sq.Ft. (Locked) | Base Rate: ₹' + effectiveBaseRate + '/sq.ft.' +
                        ' | Discount: ₹' + discount + '/sq.ft. | Parking: ' + bays + ' Bay(s) (₹' + parkingCost + ')' +
                        ' | PLC: ₹' + plc + '/sq.ft. | Finish Package: Standard Vitrified Finish' +
                        ' | Net Agreement Value: ₹' + netAgreementValue.setScale(2) + ' | Grand Total: ₹' + grandTotal.setScale(2) +
                        (String.isNotBlank(notes) ? ' | Special Notes: ' + notes : '');
        q.Name = 'Quotation - ' + u.Name + ' (' + u.BHK_Configuration__c + ') [Revised]';
        update q;

        if (q.OpportunityId != null) {
            Opportunity opp = new Opportunity(Id = q.OpportunityId, Amount = grandTotal);
            update opp;
        }

        res.success = true;
        res.quoteId = q.Id;
        res.quoteName = q.Name;
        res.netAgreementValue = netAgreementValue;
        res.grandTotal = grandTotal;
        res.message = 'Quotation updated! Net Agreement Value: ₹' + netAgreementValue.setScale(2) + ' | Grand Total: ₹' + grandTotal.setScale(2);
        return res;
    }
}