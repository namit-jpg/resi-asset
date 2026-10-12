@IsTest
private class WdGlassControllerTest {

    @TestSetup
    static void setup() {
        Id rt = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Standard_Lead_Residential')?.getRecordTypeId();
        Lead l = new Lead(LastName = 'Glass', Company = 'WarpDrive', Status = 'New');
        if (rt != null) {
            l.RecordTypeId = rt;
        }
        insert l;
    }

    @IsTest
    static void everyPageAndViewRenders() {
        Map<String, List<String>> viewsByPage = new Map<String, List<String>>{
            'leads' => new List<String>{ 'recent', 'open', 'mine', 'month', 'all' },
            'inventory' => new List<String>{ 'all', 'available', 'sold', 'recent' },
            'bookings' => new List<String>{ 'all', 'pending', 'recent' },
            'eoi' => new List<String>{ 'all', 'pending', 'paid', 'allotted', 'converted', 'closed' }
        };
        Test.startTest();
        for (String page : viewsByPage.keySet()) {
            for (String view : viewsByPage.get(page)) {
                WdGlassController.PageData data = WdGlassController.getPage(page, view);
                Assert.areEqual(4, data.kpis.size(), page + ' should show four KPI cards');
                Assert.isFalse(data.columns.isEmpty());
                Assert.isNotNull(data.viewLabel, page + '/' + view + ' should resolve a view label');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void leadsCountOpenResidentialLeads() {
        WdGlassController.PageData data = WdGlassController.getPage('leads', 'open');
        Assert.areEqual('Open leads', data.kpis[0].label);
        Assert.areEqual(data.rows.size(), data.totalRecords);
    }

    @IsTest
    static void homeRenders() {
        WdGlassController.HomeData home = WdGlassController.getHome();
        Assert.areEqual(4, home.kpis.size());
        Assert.areEqual(7, home.funnel.size());
        Assert.areEqual(UserInfo.getFirstName(), home.firstName);
    }
}