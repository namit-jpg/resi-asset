@IsTest
private class WdGlassRecordControllerTest {

    @IsTest
    static void returnsTasksAndEventsNewestFirst() {
        Lead l = new Lead(LastName = 'Glass', Company = 'WarpDrive', Status = 'New');
        insert l;
        insert new Task(WhoId = l.Id, Subject = 'Call back', Status = 'Not Started', ActivityDate = Date.today().addDays(2), TaskSubtype = 'Call');
        insert new Event(WhoId = l.Id, Subject = 'Site visit', StartDateTime = Datetime.now().addDays(-3), EndDateTime = Datetime.now().addDays(-3).addHours(1));

        List<WdGlassRecordController.ActivityItem> items = WdGlassRecordController.getActivity(l.Id);

        Assert.areEqual(2, items.size());
        Assert.areEqual('call', items[0].kind, 'future call should sort first');
        Assert.isTrue(items[0].isOpen);
        Assert.areEqual('event', items[1].kind);
        Assert.isFalse(items[1].isOpen);
    }

    @IsTest
    static void leadActionsIncludeConvertAndStandardActions() {
        List<WdGlassRecordController.ActionItem> actions = WdGlassRecordController.getActions('Lead');
        Set<String> names = new Set<String>();
        for (WdGlassRecordController.ActionItem a : actions) {
            names.add(a.apiName);
        }
        Assert.isTrue(names.containsAll(new Set<String>{ 'Convert', 'Clone', 'Delete' }));
    }

    @IsTest
    static void submitWithoutApprovalProcessReportsError() {
        Lead l = new Lead(LastName = 'Glass', Company = 'WarpDrive', Status = 'New');
        insert l;
        try {
            WdGlassRecordController.submitForApproval(l.Id, 'please');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void handoverLookupReturnsNullWithoutBooking() {
        Id missingBooking = Booking__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001AAA';
        Assert.isNull(WdGlassRecordController.getHandoverForBooking(missingBooking));
    }
}