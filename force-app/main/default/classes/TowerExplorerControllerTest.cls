@IsTest
private class TowerExplorerControllerTest {
    @TestSetup
    static void setup() {
        Property__c project = new Property__c(Name = 'Test Project');
        insert project;
        Tower__c tower = new Tower__c(Name = 'T1', Property__c = project.Id, Chargeable_Area_Type__c = 'Carpet Area');
        insert tower;
        insert new BusinessPlanPrice__c(
            Tower__c = tower.Id, PricePerSqFt__c = 1000,
            EffectiveFrom__c = Date.today().addDays(-10), EffectiveTo__c = Date.today().addDays(300)
        );
        Floor__c floor = new Floor__c(Name = '7th', Tower__c = tower.Id, Property__c = project.Id);
        insert floor;
        insert new List<Unit__c>{
            new Unit__c(Name = 'T1-701', Property__c = project.Id, Tower__c = tower.Id, Floor__c = floor.Id,
                Status__c = 'Available', Carpet_Area__c = 1000, Saleable_Area__c = 1300, Built_Up_Area_SBA__c = 1200),
            new Unit__c(Name = 'T1-702', Property__c = project.Id, Tower__c = tower.Id, Floor__c = floor.Id,
                Status__c = 'Available', Carpet_Area__c = 1200, Saleable_Area__c = 1500, Built_Up_Area_SBA__c = 1400)
        };
    }

    @IsTest
    static void loadsProjectsAndUnits() {
        Tower__c tower = [SELECT Id FROM Tower__c LIMIT 1];
        Test.startTest();
        List<TowerExplorerController.ProjectOption> projects = TowerExplorerController.getProjects();
        TowerExplorerController.TowerData data = TowerExplorerController.getTowerUnits(tower.Id);
        Test.stopTest();

        Assert.areEqual(1, projects.size());
        Assert.areEqual(2, data.units.size());
        TowerExplorerController.UnitRow first = data.units[0];
        Assert.areEqual(7, first.floorNumber);
        Assert.areEqual(1, first.position);
        Assert.areEqual(1000000, first.basePrice);
        Assert.isTrue(first.baseFromRate);
    }

    @IsTest
    static void tagsAndSwapsUnits() {
        List<Unit__c> units = [SELECT Id FROM Unit__c ORDER BY Name];
        Opportunity opp = new Opportunity(Name = 'Buyer', StageName = 'Unit Shortlisting', CloseDate = Date.today().addDays(30));
        insert opp;

        Test.startTest();
        TowerExplorerController.tagUnit(opp.Id, units[0].Id);
        TowerExplorerController.tagUnit(opp.Id, units[1].Id);
        Test.stopTest();

        Assert.areEqual(units[1].Id, [SELECT Interested_Unit__c FROM Opportunity WHERE Id = :opp.Id].Interested_Unit__c);
        Assert.areEqual('Available', [SELECT Status__c FROM Unit__c WHERE Id = :units[0].Id].Status__c);
        Assert.areEqual('Reserved', [SELECT Status__c FROM Unit__c WHERE Id = :units[1].Id].Status__c);
        TowerExplorerController.OpportunityContext ctx = TowerExplorerController.getOpportunityContext(opp.Id);
        Assert.areEqual(units[1].Id, ctx.unitId);
    }

    @IsTest
    static void rejectsUnavailableUnit() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        unit.Status__c = 'Booked';
        update unit;
        Opportunity opp = new Opportunity(Name = 'Buyer', StageName = 'Unit Shortlisting', CloseDate = Date.today().addDays(30));
        insert opp;
        try {
            TowerExplorerController.tagUnit(opp.Id, unit.Id);
            Assert.fail('Expected an error for a booked unit');
        } catch (AuraHandledException ex) {
            Assert.isNotNull(ex);
        }
    }

    @IsTest
    static void searchesOpportunitiesAndShowsTags() {
        Tower__c tower = [SELECT Id, Property__c FROM Tower__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c ORDER BY Name LIMIT 1];
        Id residential = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
            .get('Residential_Sales_Opportunity').getRecordTypeId();
        Opportunity opp = new Opportunity(
            Name = 'Stock Tag Buyer', StageName = 'Negotiation', CloseDate = Date.today().addDays(30), RecordTypeId = residential
        );
        insert opp;

        Test.startTest();
        List<TowerExplorerController.OpportunityOption> none = TowerExplorerController.searchOpportunities('S', tower.Property__c);
        List<TowerExplorerController.OpportunityOption> found = TowerExplorerController.searchOpportunities('Stock Tag', tower.Property__c);
        TowerExplorerController.tagUnit(opp.Id, unit.Id);
        TowerExplorerController.TowerData data = TowerExplorerController.getTowerUnitsFresh(tower.Id);
        Test.stopTest();

        Assert.areEqual(0, none.size());
        Assert.areEqual(1, found.size());
        Assert.areEqual(opp.Id, found[0].id);
        Assert.areEqual(1, data.units[0].tags.size());
        Assert.areEqual(opp.Id, data.units[0].tags[0].id);
        Assert.areEqual('Reserved', data.units[0].status);
    }
}
