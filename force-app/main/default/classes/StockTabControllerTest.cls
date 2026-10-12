@isTest
private class StockTabControllerTest {

    @testSetup
    static void setupData() {
        // Create project and tower using factory
        Property__c project = ResidentialTestDataFactory.createProject();
        Tower__c tower = ResidentialTestDataFactory.createTower(project.Id);
        Floor__c floor = ResidentialTestDataFactory.createFloor(project.Id, tower.Id);

        // Create 5 units with alternating statuses
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 5; i++) {
            Unit__c unit = ResidentialTestDataFactory.prepareUnit(project.Id, tower.Id, floor.Id);
            unit.Name = 'Test Unit ' + i;
            unit.Status__c = (Math.mod(i, 2) == 0) ? 'Available' : 'Sold';
            units.add(unit);
        }
        insert units;
    }

    @isTest
    static void testGetUnits_BasicLimit() {
        Test.startTest();
        List<Unit__c> results = StockTabController.getUnits(0, 3, null, null);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should return 3 units based on limit');
        System.assert(results[0].Name < results[1].Name, 'Units should be ordered by Name ASC');
    }

    @isTest
    static void testGetUnits_WithOffset() {
        Test.startTest();
        List<Unit__c> results = StockTabController.getUnits(2, 2, null, null);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 units with offset 2 and limit 2');
    }

    @isTest
    static void testGetUnits_WithStatusFilter() {
        Test.startTest();
        List<Unit__c> results = StockTabController.getUnits(0, 10, 'Available', null);
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Results should not be empty for Available status');
        for (Unit__c u : results) {
            System.assertEquals('Available', u.Status__c, 'Status filter should be applied');
        }
    }

    @isTest
    static void testGetUnits_WithSearchKey() {
        Test.startTest();
        List<Unit__c> results = StockTabController.getUnits(0, 10, null, 'Test Unit');
        Test.stopTest();

        System.assert(!results.isEmpty(), 'Search key should return results');
        System.assert(results[0].Name.contains('Test Unit'), 'Returned Name should contain search key');
    }

    @isTest
    static void testGetUnits_ZeroLimit() {
        Test.startTest();
        List<Unit__c> results = StockTabController.getUnits(0, 0, null, null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list when limit = 0');
    }

    @isTest
    static void testGetUnits_NoData() {
        // Delete all units created in setup
        delete [SELECT Id FROM Unit__c];

        Test.startTest();
        List<Unit__c> results = StockTabController.getUnits(0, 5, null, null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should return empty list when no units exist');
    }

    @isTest
    static void testGetAvailableStatuses() {
        Test.startTest();
        List<String> statuses = StockTabController.getAvailableStatuses();
        Test.stopTest();

        System.assert(!statuses.isEmpty(), 'Available statuses should not be empty');
        System.assert(
            statuses.contains('Available') || statuses.contains('Sold'),
            'Statuses should include at least Available or Sold'
        );
    }
}