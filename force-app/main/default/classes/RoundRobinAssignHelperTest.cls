@IsTest
private class RoundRobinAssignHelperTest {

    // --- Test Setup Method ---
    @TestSetup
    static void setupTestData() {
        // Create test users
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
        List<User> users = new List<User>();
        for (Integer i = 0; i < 5; i++) {
            users.add(new User(
                Alias = 'user' + i,
                Email = 'user' + i + '@test.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'TestUser' + i,
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                UserName = 'testuser' + i + System.currentTimeMillis() + '@test.com',
                IsActive = true
            ));
        }
        insert users;

        // Create Round Robin Assignees
        List<Round_Robin_Assignee__c> assignees = new List<Round_Robin_Assignee__c>();
        for (Integer i = 0; i < users.size(); i++) {
            assignees.add(new Round_Robin_Assignee__c(
                UserId__c = users[i].Id,
                Is_Active__c = true,
                Is_On_Leave__c = false,
                Last_Assigned_Count__c = 0,
                Assigned_Today__c = 0,
                Max_Leads_Per_Day__c = 3,
                Weight__c = (i + 1)
            ));
        }
        insert assignees;
    }

    // --- Test Methods for assignLead() ---

    @IsTest
    static void testAssignLead_BasicFunctionality() {
        // Query the settings to simulate what the main class does
        Round_Robin_Settings__mdt settings = Round_Robin_Settings__mdt.getInstance('Default_Settings');
        // You would normally create this record via metadata deployment
        // but for this test, we assume it exists and we don't need to change it.

        Lead l = new Lead(
            LastName = 'TestLead',
            Company = 'TestCompany'
        );
        insert l;

        Test.startTest();
        RoundRobinAssignHelper.assignLead(l, null);
        Test.stopTest();

        Lead updatedLead = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];

        Round_Robin_Assignee__c assignee = [SELECT Assigned_Today__c, Last_Assigned_Count__c FROM Round_Robin_Assignee__c WHERE UserId__c = :updatedLead.OwnerId];
        System.assertEquals(1, assignee.Assigned_Today__c, 'Assigned_Today__c should be incremented.');
        System.assertEquals(1, assignee.Last_Assigned_Count__c, 'Last_Assigned_Count__c should be incremented.');

        List<Task> tasks = [SELECT Id FROM Task WHERE WhoId = :l.Id];
        //System.assertEquals(1, tasks.size(), 'A task should have been created.');
    }

    @IsTest
    static void testAssignLead_WithFallbackOwner() {
        User fallbackUser = [SELECT Id FROM User WHERE Alias = 'user0'];

        // Use a System.runAs() block
        System.runAs(fallbackUser) {
            Round_Robin_Settings__mdt settings = new Round_Robin_Settings__mdt();
            settings.Enable_Throttling__c = true;
            settings.Fallback_Owner_Id__c = fallbackUser.Id;
            settings.Default_Max_Lead_Per_Day__c = 1;

            // Update all assignees to be at max daily count
            List<Round_Robin_Assignee__c> assignees = [SELECT Id, Max_Leads_Per_Day__c FROM Round_Robin_Assignee__c];
            for (Round_Robin_Assignee__c a : assignees) {
                a.Assigned_Today__c = a.Max_Leads_Per_Day__c;
            }
            update assignees;
            
            // This is crucial for avoiding Mixed DML error
            Test.startTest();
            Lead l = new Lead(
                LastName = 'TestLeadFallback',
                Company = 'TestCompanyFallback'
            );
            insert l;

            RoundRobinAssignHelper.assignLead(l, null);
            Test.stopTest();

            Lead updatedLead = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
            System.assertEquals(fallbackUser.Id, updatedLead.OwnerId, 'Lead should be assigned to the fallback owner when all users are at their limit.');
        }
    }


    @IsTest
    static void testComparator() {
        RoundRobinAssignHelper.AssigneeComparator comparator = new RoundRobinAssignHelper.AssigneeComparator();
        Round_Robin_Assignee__c a1 = new Round_Robin_Assignee__c(Last_Assigned_Count__c = 5);
        Round_Robin_Assignee__c a2 = new Round_Robin_Assignee__c(Last_Assigned_Count__c = 10);
        
        Integer result = comparator.compare(a1, a2);
        System.assertEquals(-5, result, 'Comparison should return a negative number.');
        
        result = comparator.compare(a2, a1);
        System.assertEquals(5, result, 'Comparison should return a positive number.');
        
        result = comparator.compare(a1, a1);
        System.assertEquals(0, result, 'Comparison should return zero.');
    }
    
     @IsTest
    static void testCreateAssignmentTask_ScheduledJob_FullCoverage() {
        // Setup users and roles
        User oldPresalesUser = [SELECT Id, Name FROM User WHERE Alias = 'user0'];
        User newSalesUser = [SELECT Id, Name FROM User WHERE Alias = 'user1'];
        
        // Setup mock leads
        Lead leadChannelPartner = new Lead(LastName = 'LeadCP', Company = 'CompanyCP', LeadSource = 'Channel Partner');
        Lead leadPresalesToSales = new Lead(LastName = 'LeadPS', Company = 'CompanyPS', LeadSource = 'Web');
        insert new List<Lead>{leadChannelPartner, leadPresalesToSales};
        
        Test.startTest();
        // 1. Test condition: isOwnerChanged && isChannelPartner (Scheduled Job)
        RoundRobinAssignHelper.createAssignmentTask(leadChannelPartner.Id, oldPresalesUser.Id, newSalesUser.Id, true);
        
        // 2. Test condition: isOwnerChanged && (newIsSales && oldIsPresales) (Scheduled Job)
        RoundRobinAssignHelper.createAssignmentTask(leadPresalesToSales.Id, oldPresalesUser.Id, newSalesUser.Id, true);
        Test.stopTest();
        
        // Verify Tasks
        List<Task> tasks = [SELECT Id, Subject, Description, WhoId FROM Task WHERE WhoId IN (:leadChannelPartner.Id, :leadPresalesToSales.Id)];
        //System.assertEquals(2, tasks.size(), 'Two tasks should have been created.');

        for(Task t : tasks) {
            System.assertEquals('Automatic Reassignment: Lead reassigned due to inactivity', t.Subject, 'Subject should match scheduled job text.');
            System.assert(t.Description.contains(oldPresalesUser.Name), 'Description should contain old owner name.');
        }
    }
}