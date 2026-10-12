@IsTest
private class LeadArchiveServiceTest {

    @TestSetup
    static void setupTestData() {
        Id resRtId = ResLeadTriggerDispatcher.RT_ID_LEAD_RESIDENTIAL;
        Lead ld1 = new Lead(
            FirstName = 'Ravi',
            LastName = 'Kumar',
            Company = 'Infosys',
            MobilePhone = '9876500001',
            Status = 'New',
            Archive_For_In_Days__c = 10,
            RecordTypeId = resRtId
        );
        insert ld1;

        Lead ld2 = new Lead(
            FirstName = 'Ananya',
            LastName = 'Sharma',
            Company = 'Wipro',
            MobilePhone = '9876500002',
            Status = 'New',
            RecordTypeId = resRtId
        );
        insert ld2;
    }

    @IsTest
    static void testTriggerDateCalculations() {
        Lead ld = [SELECT Id, Archive_For_In_Days__c, Archive_Follow_Up_Date__c, Archive_Populated_Date__c, Archive_Status__c FROM Lead WHERE LastName = 'Kumar' LIMIT 1];

        System.assertEquals(10, ld.Archive_For_In_Days__c);
        System.assertEquals(Date.today().addDays(10), ld.Archive_Follow_Up_Date__c, 'Follow up date should be today + 10 days');
        System.assertNotEquals(null, ld.Archive_Populated_Date__c, 'Populated date should be set');

        // Test updating days to 30
        Test.startTest();
        ld.Archive_For_In_Days__c = 30;
        update ld;
        Test.stopTest();

        Lead updatedLd = [SELECT Id, Archive_For_In_Days__c, Archive_Follow_Up_Date__c FROM Lead WHERE Id = :ld.Id];
        System.assertEquals(30, updatedLd.Archive_For_In_Days__c);
        System.assertEquals(Date.today().addDays(30), updatedLd.Archive_Follow_Up_Date__c);

        // Test clearing archive days
        updatedLd.Archive_For_In_Days__c = null;
        update updatedLd;
        Lead clearedLd = [SELECT Id, Archive_For_In_Days__c, Archive_Follow_Up_Date__c, Archive_Populated_Date__c FROM Lead WHERE Id = :ld.Id];
        System.assertEquals(null, clearedLd.Archive_Follow_Up_Date__c);
        System.assertEquals(null, clearedLd.Archive_Populated_Date__c);
    }

    @IsTest
    static void testGetArchiveInfoAndComplete() {
        Lead ld = [SELECT Id FROM Lead WHERE LastName = 'Kumar' LIMIT 1];

        Test.startTest();
        LeadArchiveService.LeadArchiveInfo info = LeadArchiveService.getArchiveInfo(ld.Id);
        Test.stopTest();

        System.assertNotEquals(null, info);
        System.assertEquals(10, info.archiveDays);
        System.assertEquals(true, info.isArchived);
        System.assertEquals(false, info.isFollowUpDue);

        // Test complete follow up
        LeadArchiveService.completeFollowUp(ld.Id);
        Lead afterComplete = [SELECT Id, Archive_For_In_Days__c FROM Lead WHERE Id = :ld.Id];
        System.assertEquals(null, afterComplete.Archive_For_In_Days__c);
    }

    @IsTest
    static void testProcessDueArchiveFollowUps() {
        Lead ld = [SELECT Id, Archive_Follow_Up_Date__c FROM Lead WHERE LastName = 'Kumar' LIMIT 1];
        // Set follow up date to yesterday to simulate expired cooling-off
        ld.Archive_Follow_Up_Date__c = Date.today().addDays(-1);
        update ld;

        Test.startTest();
        Integer processedCount = LeadArchiveService.processDueArchiveFollowUps();
        Test.stopTest();

        System.assertEquals(1, processedCount, 'Should process 1 due lead');

        Lead afterProc = [SELECT Id, Archive_Notification_Sent__c FROM Lead WHERE Id = :ld.Id];
        System.assertEquals(true, afterProc.Archive_Notification_Sent__c);

        List<Task> tasks = [SELECT Id, Subject, WhoId, Priority FROM Task WHERE WhoId = :ld.Id];
        System.assert(tasks.size() > 0, 'Follow up task must be created');
        System.assertEquals('Customer might be ready, follow up', tasks[0].Subject);
        System.assertEquals('High', tasks[0].Priority);
    }

    @IsTest
    static void testDirectNotificationAndSchedulable() {
        Lead ld = [SELECT Id FROM Lead WHERE LastName = 'Kumar' LIMIT 1];

        Test.startTest();
        LeadArchiveService.sendFollowUpNotification(ld.Id);
        LeadArchiveService.executeInvocable();

        // Run Schedulable
        LeadArchiveFollowUpSchedulable sched = new LeadArchiveFollowUpSchedulable();
        String cron = '0 0 8 * * ?';
        System.schedule('Test Lead Archive Daily Job', cron, sched);
        Test.stopTest();

        List<Task> tasks = [SELECT Id, Subject FROM Task WHERE WhoId = :ld.Id AND Subject = 'Customer might be ready, follow up'];
        System.assert(tasks.size() > 0);
    }

    @IsTest
    static void testConversionGateValidation() {
        Lead ld = [SELECT Id FROM Lead WHERE LastName = 'Sharma' LIMIT 1];
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);

        Test.startTest();
        Boolean caught = false;
        try {
            Database.LeadConvertResult lcr = Database.convertLead(lc);
            if (!lcr.isSuccess()) {
                caught = true;
            }
        } catch (Exception ex) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Lead conversion must be blocked when no verified Site Visit has been logged');
    }

    @IsTest
    static void testAutoReactivationOnStageChange() {
        Lead ld = [SELECT Id, Status, Archive_For_In_Days__c FROM Lead WHERE LastName = 'Kumar' LIMIT 1];
        ld.Status = 'Archive';
        ld.Archive_For_In_Days__c = 14;
        update ld;

        Lead archivedLd = [SELECT Id, Status, Archive_For_In_Days__c, Archive_Follow_Up_Date__c FROM Lead WHERE Id = :ld.Id];
        System.assertEquals('Archive', archivedLd.Status);
        System.assertEquals(14, archivedLd.Archive_For_In_Days__c);

        // Move stage to Allocated - should auto-reactivate and clear archival fields
        Test.startTest();
        archivedLd.Status = 'Allocated';
        update archivedLd;
        Test.stopTest();

        Lead reactivatedLd = [SELECT Id, Status, Archive_For_In_Days__c, Archive_Follow_Up_Date__c FROM Lead WHERE Id = :ld.Id];
        System.assertEquals('Allocated', reactivatedLd.Status);
        System.assertEquals(null, reactivatedLd.Archive_For_In_Days__c, 'Archival days must be automatically cleared');
        System.assertEquals(null, reactivatedLd.Archive_Follow_Up_Date__c, 'Follow up date must be automatically cleared');
    }
}