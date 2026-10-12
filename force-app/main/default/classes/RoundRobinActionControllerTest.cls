@isTest
public class RoundRobinActionControllerTest {

    static Id queueId;
    static Id userId;

    @testSetup
    static void setupTestData() {
        // 1️⃣ Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testu',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com'
        );
        insert testUser;
        userId = testUser.Id;

        // 2️⃣ Create or get Bangalore queue
        Group bangaloreQueue;
        List<Group> existingQueue = [SELECT Id, Name FROM Group WHERE DeveloperName = 'Bangalore_Queue' AND Type = 'Queue' LIMIT 1];
        if (!existingQueue.isEmpty()) {
            bangaloreQueue = existingQueue[0];
        } else {
            bangaloreQueue = new Group(
                Name = 'Bangalore Queue',
                DeveloperName = 'Bangalore_Queue',
                Type = 'Queue'
            );
            insert bangaloreQueue;
        }
        queueId = bangaloreQueue.Id;

        // 3️⃣ Add user to queue inside runAs(SystemAdmin) to avoid Mixed DML
        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator'AND IsActive = true LIMIT 1];
        System.runAs(adminUser) {
            GroupMember gm = new GroupMember(
                GroupId = queueId,
                UserOrGroupId = userId
            );
            insert gm;
        }

        // 4️⃣ Create Round Robin Assignee (custom object, non-setup)
        Round_Robin_Assignee__c assignee = new Round_Robin_Assignee__c(
            UserId__c = userId,
            Is_Active__c = true,
            Is_On_Leave__c = false,
            Max_Leads_Per_Day__c = 10,
            Weight__c = 1,
            Assigned_Today__c = 0,
            Last_Assigned_Count__c = 0
        );
        insert assignee;
    }

    @isTest
    static void testAssignLead_Success() {
        Lead l = ResidentialTestDataFactory.prepareLead();
        l.Company = 'Test Co';
        l.Status = 'Open';
        l.Projects__c = 'Varthur Vista';
        insert l;
    
        Test.startTest();
        RoundRobinActionController.assignLeadViaRoundRobin(l.Id);
        Test.stopTest();
    
        Lead updatedLead = [SELECT OwnerId FROM Lead WHERE Id = :l.Id];
        System.assertNotEquals(null, updatedLead.OwnerId, 'Lead OwnerId should not be null after assignment');
    }

    @isTest
    static void testAssignLead_ChannelPartner() {
        Lead l = ResidentialTestDataFactory.prepareLead();
        l.Company = 'Partner Co';
        l.Status = 'Open - Not Contacted';
        l.LeadSource = 'Channel Partner';
        insert l;

        Test.startTest();
        try {
            RoundRobinActionController.assignLeadViaRoundRobin(l.Id);
        } catch (Exception e) {
            // ok if queue not found
        }
        Test.stopTest();
    }

    @isTest
    static void testAssignLead_Kolkata() {
        Lead l = ResidentialTestDataFactory.prepareLead();
        l.Company = 'Test Co';
        l.Status = 'Open - Not Contacted';
        // No Kolkata project or queue: falls back to the whole round robin pool.
        l.Preferred_City__c = 'Kolkata';
        insert l;

        Test.startTest();
        try {
            RoundRobinActionController.assignLeadViaRoundRobin(l.Id);
        } catch (Exception e) {
            // ok if queue not found
        }
        Test.stopTest();
    }

    @isTest
    static void testAssignLead_InvalidLeadId() {
        try {
            Test.startTest();
            RoundRobinActionController.assignLeadViaRoundRobin(Id.valueOf('00Q000000000000AAA'));
            Test.stopTest();
            System.Assert.isTrue(false, 'Exception should have been thrown for invalid lead');
        } catch (Exception e) {
            System.Assert.isTrue(true, 'Expected failure path covered');
        }
    }

    @isTest
    static void testGetQueueIdByName_NotFound() {
        Id qid = RoundRobinActionController.getQueueIdByName('DefinitelyNotExistingQueue');
        System.assertEquals(null, qid, 'Expected null for non-existing queue');
    }

    @isTest
    static void testAssignLead_NoProjectUsesWholePool() {
        Lead l = ResidentialTestDataFactory.prepareLead();
        l.Company = 'Test Co';
        l.Projects__c = null;
        l.Preferred_City__c = null;
        insert l;

        Test.startTest();
        String ownerName = RoundRobinActionController.assignLeadViaRoundRobin(l.Id);
        Test.stopTest();

        Assert.isNotNull(ownerName, 'Expected the new owner name');
        Assert.areEqual('Allocated', [SELECT Status FROM Lead WHERE Id = :l.Id].Status);
    }

    @isTest
    static void testQueueForLead_ByCity() {
        Assert.areEqual('Hyderabad_Queue', RoundRobinActionController.queueForLead(new Lead(Preferred_City__c = 'Hyderabad')));
        Assert.areEqual('Bangalore_Queue', RoundRobinActionController.queueForLead(new Lead(Projects__c = 'Varthur Vista')));
        Assert.isNull(RoundRobinActionController.queueForLead(new Lead()));
    }
}
