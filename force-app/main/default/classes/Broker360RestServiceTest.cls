@isTest
private class Broker360RestServiceTest {

    @testSetup
    static void setupTestData() {
        // Query Channel Partner RecordType
        RecordType cpRt = [
            SELECT Id FROM RecordType 
            WHERE SobjectType = 'Account' AND DeveloperName = 'Channel_Partner_Residential' 
            LIMIT 1
        ];

        Account cpAcc = new Account(
            FirstName = 'Apex',
            LastName = 'Realty Partners',
            RecordTypeId = cpRt.Id,
            Brokerage_Percentage__c = 2.5,
            RERA_Number__c = 'KA/RERA/1251/2026',
            CP_RERA_Number__c = 'PRM/KA/RERA/1251/309/PR/200123',
            Channel_Partner_Status__c = 'Active',
            CP_Approval_Status__c = 'Approved',
            Partner_Program_Level__c = 'Platinum',
            Phone = '+91 98450 11223'
        );
        insert cpAcc;

        Property__c proj = new Property__c(
            Name = 'Nikoo Homes'
        );
        insert proj;

        // 1. Tagged CP Lead
        Lead cpLead = new Lead(
            FirstName = 'Rohan',
            LastName = 'Mehta',
            Company = 'Mehta Household',
            Phone = '9876543210',
            Email = 'rohan@example.com',
            Status = 'Site Visit',
            Approved_Channel_Partner__c = cpAcc.Id,
            ProjectL__c = proj.Id,
            Site_Visit_Scheduled__c = true
        );
        insert cpLead;

        // 2. Direct Lead (Not via CP)
        Lead directLead = new Lead(
            FirstName = 'Direct',
            LastName = 'Walkin',
            Company = 'Walkin Household',
            Phone = '9998887776',
            Email = 'direct@example.com',
            Status = 'New',
            ProjectL__c = proj.Id
        );
        insert directLead;

        // 3. Customer Account & Unit
        Account cust = new Account(FirstName = 'Rohan', LastName = 'Mehta');
        insert cust;

        Tower__c tower = new Tower__c(Name = 'Tower A', Property__c = proj.Id);
        insert tower;

        Floor__c floor = new Floor__c(Name = '1st Floor', Tower__c = tower.Id, Property__c = proj.Id);
        insert floor;

        Unit__c unit = new Unit__c(
            Name = 'Unit 101', 
            Tower__c = tower.Id, 
            Floor__c = floor.Id, 
            Property__c = proj.Id,
            BHK_Configuration__c = '3 BHK', 
            Base_Price__c = 15000000, 
            Status__c = 'Available'
        );
        insert unit;

        Opportunity opp = new Opportunity(
            Name = 'Rohan Opportunity',
            AccountId = cust.Id,
            StageName = 'Quotation Agreed',
            CloseDate = Date.today().addDays(30),
            Interested_Unit__c = unit.Id
        );
        insert opp;

        // 4. Tagged CP Booking
        Booking__c bk = new Booking__c(
            Account_Id__c = cust.Id,
            Opportunity_Id__c = opp.Id,
            Unit_Id__c = unit.Id,
            Approved_Channel_Partner__c = cpAcc.Id,
            Project__c = proj.Id,
            Final_Amount__c = 15000000,
            Is_Token_Recieved__c = true,
            Status__c = 'Confirmed'
        );
        insert bk;
    }

    @isTest
    static void testGetBrokerData() {
        Account cpAcc = [SELECT Id FROM Account WHERE LastName = 'Realty Partners' LIMIT 1];

        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/Broker360';
        req.httpMethod = 'GET';
        req.params.put('brokerId', cpAcc.Id);
        RestResponse res = new RestResponse();

        RestContext.request = req;
        RestContext.response = res;

        Broker360RestService.getBrokerData();
        Test.stopTest();

        System.assertNotEquals(null, res.responseBody, 'Response should not be null');
        String jsonStr = res.responseBody.toString();
        System.assert(jsonStr.contains('Apex Realty Partners'), 'Response should contain CP account name');
        System.assert(jsonStr.contains('Rohan Mehta'), 'Response should contain tagged lead');
        System.assert(!jsonStr.contains('Direct Walkin'), 'Response must NOT contain direct lead');
    }

    @isTest
    static void testRegisterBuyerLead() {
        Account cpAcc = [SELECT Id FROM Account WHERE LastName = 'Realty Partners' LIMIT 1];
        Property__c proj = [SELECT Id FROM Property__c LIMIT 1];

        Test.startTest();
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/Broker360/lead';
        req.httpMethod = 'POST';

        Broker360RestService.LeadRegistrationRequest reg = new Broker360RestService.LeadRegistrationRequest();
        reg.brokerAccountId = cpAcc.Id;
        reg.firstName = 'Priya';
        reg.lastName = 'Sharma';
        reg.phone = '9845098450';
        reg.email = 'priya.s@example.com';
        reg.projectId = proj.Id;
        reg.configuration = '3 BHK';
        reg.budget = '₹ 1.5 - 2 Cr';
        reg.notes = 'Looking for East-facing unit on higher floor';

        req.requestBody = Blob.valueOf(JSON.serialize(reg));
        RestResponse res = new RestResponse();

        RestContext.request = req;
        RestContext.response = res;

        Broker360RestService.registerBuyerLead();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Should return 201 Created');
        Lead createdLd = [SELECT Id, FirstName, LastName, Approved_Channel_Partner__c FROM Lead WHERE LastName = 'Sharma' LIMIT 1];
        System.assertEquals(cpAcc.Id, createdLd.Approved_Channel_Partner__c, 'Lead must be attributed to Channel Partner');
    }
}