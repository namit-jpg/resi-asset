@IsTest
private class CustomerLedgerControllerTest {

    @TestSetup
    static void setupTestData() {
        Property__c prop = new Property__c(
            Name = 'Grand Residency'
        );
        insert prop;

        Tower__c tow = new Tower__c(
            Name = 'Tower X',
            Property__c = prop.Id
        );
        insert tow;

        Floor__c flr = new Floor__c(
            Name = 'Floor 3',
            Tower__c = tow.Id
        );
        insert flr;

        Unit__c u = new Unit__c(
            Name = 'Unit 301',
            Floor__c = flr.Id,
            Tower__c = tow.Id,
            Property__c = prop.Id,
            BHK_Configuration__c = '3 BHK',
            Status__c = 'Sold',
            Base_Price__c = 12000000,
            Built_Up_Area_SBA__c = 1420,
            Carpet_Area__c = 1100
        );
        insert u;

        Account cust = new Account(
            Name = 'Vikas Sharma',
            Phone = '9876543210'
        );
        insert cust;

        Opportunity opp = new Opportunity(
            Name = 'Vikas Sharma Deal',
            AccountId = cust.Id,
            StageName = 'Negotiation',
            CloseDate = Date.today().addDays(30),
            Interested_Unit__c = u.Id
        );
        insert opp;

        Booking__c b = new Booking__c(
            Account_Id__c = cust.Id,
            Unit_Id__c = u.Id,
            Opportunity_Id__c = opp.Id,
            Project__c = prop.Id,
            Status__c = 'Active',
            Final_Amount__c = 12000000,
            Token_Amount__c = 500000,
            Booking_Date__c = Date.today().addDays(-60),
            SFDC_booking_reference_no__c = 'BR-90021'
        );
        insert b;

        Payment_Plan__c plan = new Payment_Plan__c(
            Name = 'CLP Standard'
        );
        insert plan;

        Payment_Schedule__c ps = new Payment_Schedule__c(
            Payment_Plan_Id__c = plan.Id,
            Milestone_Code__c = 'Foundation Slab',
            Payment_Percentage__c = 10,
            Installment_Number__c = 1,
            Due_In_Days__c = 30
        );
        insert ps;

        Booking_Payment_Schedule__c inst = new Booking_Payment_Schedule__c(
            Booking__c = b.Id,
            Opportunity__c = opp.Id,
            Payment_Schedule_Id__c = ps.Id,
            Installment_Amount__c = 1200000,
            Amount_Paid__c = 0,
            Payment_Due_Date__c = Date.today().addDays(-20),
            Payment_Status__c = 'Pending',
            Is_Token_Amount__c = true,
            Description__c = 'Foundation Slab'
        );
        insert inst;

        Demand__c dem = new Demand__c(
            Booking_Id__c = b.Id,
            Booking_Payment_Schedule_Id__c = inst.Id,
            Account__c = cust.Id,
            Base_Amount__c = 500000,
            Status__c = 'Demand Raised'
        );
        insert dem;

        Payment_Receipt__c rcpt = new Payment_Receipt__c(
            Demand__c = dem.Id,
            Booking_Payment_Schedule__c = inst.Id,
            Account__c = cust.Id,
            Amount_Paid__c = 500000,
            Date_Of_Payment__c = Date.today().addDays(-60),
            Mode_Of_Payment__c = 'NEFT/RTGS',
            Receipt_Status__c = 'Approved',
            Approval_Status__c = 'Approved',
            Transaction_Reference__c = 'UTR-INIT-90021'
        );
        insert rcpt;
    }

    @IsTest
    static void testResolveBookingAndOptions() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

        Test.startTest();
        Id bFromAcc = CustomerLedgerController.resolveBookingId(acc.Id);
        Id bFromOpp = CustomerLedgerController.resolveBookingId(opp.Id);
        Id bFromBkg = CustomerLedgerController.resolveBookingId(b.Id);
        List<CustomerLedgerController.BookingOptionWrapper> opts = CustomerLedgerController.getCustomerBookings(acc.Id);
        Test.stopTest();

        System.assertEquals(b.Id, bFromAcc);
        System.assertEquals(b.Id, bFromOpp);
        System.assertEquals(b.Id, bFromBkg);
        System.assert(opts.size() > 0);
    }

    @IsTest
    static void testLedgerSummaryAndInstallments() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

        Test.startTest();
        CustomerLedgerController.LedgerSummaryWrapper summary = CustomerLedgerController.getLedgerSummary(b.Id);
        List<CustomerLedgerController.InstallmentItemWrapper> items = CustomerLedgerController.getInstallments(b.Id);
        List<CustomerLedgerController.ReceiptItemWrapper> receipts = CustomerLedgerController.getReceipts(b.Id);
        Test.stopTest();

        System.assertNotEquals(null, summary);
        System.assertEquals('Vikas Sharma', summary.customerName);
        System.assert(items.size() > 0);
        System.assert(receipts.size() > 0);
    }

    @IsTest
    static void testInterestWaiverAndDemandNotes() {
        Booking_Payment_Schedule__c inst = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];

        Test.startTest();
        CustomerLedgerController.ActionResultWrapper waiverReq = CustomerLedgerController.requestInterestWaiver(inst.Id, 5000, 'Bank loan processing delay');
        CustomerLedgerController.ActionResultWrapper waiverRev = CustomerLedgerController.reviewInterestWaiver(inst.Id, true, 'Approved by Finance Head');
        CustomerLedgerController.ActionResultWrapper demandRes = CustomerLedgerController.issueDemandNote(inst.Id);
        CustomerLedgerController.ActionResultWrapper reminderRes = CustomerLedgerController.sendDemandReminder(inst.Id, 1);
        Test.stopTest();

        System.assert(waiverReq.success);
        System.assert(waiverRev.success);
        System.assert(demandRes.success);
        System.assert(reminderRes.success);
    }

    @IsTest
    static void testReceiptLoggingAndReconciliation() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Booking_Payment_Schedule__c inst = [SELECT Id FROM Booking_Payment_Schedule__c LIMIT 1];

        Test.startTest();
        CustomerLedgerController.ActionResultWrapper logRes = CustomerLedgerController.logDetailedReceipt(
            b.Id,
            inst.Id,
            250000,
            'Cheque',
            'CHQ-882910',
            Date.today(),
            Date.today(),
            'CHQ-882910',
            'HDFC Bank'
        );
        System.assert(logRes.success);

        Payment_Receipt__c r = [SELECT Id FROM Payment_Receipt__c WHERE Id = :logRes.recordId];
        CustomerLedgerController.ActionResultWrapper sapRes = CustomerLedgerController.clearReceiptInSap(r.Id, 'SAP-CLR-88192', 'Cleared in SAP');
        CustomerLedgerController.ActionResultWrapper recRes = CustomerLedgerController.reconcileReceipt(r.Id, true, 'Reconciled');
        CustomerLedgerController.ActionResultWrapper recalcRes = CustomerLedgerController.recalculateInstallmentBalances(b.Id);
        Test.stopTest();

        System.assert(sapRes.success);
        System.assert(recRes.success);
        System.assert(recalcRes.success);
    }

    @IsTest
    static void testLettersAndApproval() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        CustomerLedgerController.BookingConditionWrapper conds = CustomerLedgerController.getBookingConditionCharges(b.Id);
        CustomerLedgerController.AllotmentLetterWrapper allotData = CustomerLedgerController.getAllotmentLetterData(b.Id);
        CustomerLedgerController.WelcomeLetterWrapper welcomeData = CustomerLedgerController.getWelcomeLetterData(opp.Id);
        CustomerLedgerController.ActionResultWrapper allotEmail = CustomerLedgerController.sendAllotmentLetterEmail(b.Id);
        CustomerLedgerController.ActionResultWrapper welcomeEmail = CustomerLedgerController.sendWelcomeLetterEmail(opp.Id);
        CustomerLedgerController.ActionResultWrapper approvalRes = CustomerLedgerController.submitForApproval(b.Id);
        Test.stopTest();

        System.assertNotEquals(null, conds);
        System.assertNotEquals(null, allotData);
        System.assertNotEquals(null, welcomeData);
        System.assert(approvalRes.success);
    }
}