/**
 * Tests for the Nikoo Homes Email Support Agent actions and classifier.
 * Case-creating tests use SeeAllData=true: this org's "SDO Service - Case - On Create" flow needs
 * configuration that is only visible with org data.
 */
@IsTest
private class ResiAgentActionsTest {

    @IsTest
    static void classifierFlagsComplexTopics() {
        Assert.areEqual('Legal or RERA complaint', ResiCaseClassifier.detect('I will file a complaint with RERA'));
        Assert.areEqual('Cancellation or refund', ResiCaseClassifier.detect('Please cancel my booking and refund'));
        Assert.areEqual('Fraud or unauthorised transaction', ResiCaseClassifier.detect('This looks like a fraud'));
        Assert.areEqual('Possession delay or compensation', ResiCaseClassifier.detect('We want compensation for the delay'));
        Assert.isNull(ResiCaseClassifier.detect('Please share my statement of account'));
        Assert.isNull(ResiCaseClassifier.detect(null));

        Case simple = new Case(Origin = 'Email', Subject = 'Next instalment date?', Description = 'When is my next payment due?');
        Case complex = new Case(Origin = 'Email', Subject = 'Legal notice', Description = 'My lawyer will contact you');
        ResiCaseClassifier.classify(new List<Case>{ simple, complex });
        Assert.areEqual('SIMPLE', simple.Case_Classification__c);
        Assert.areEqual('COMPLEX', complex.Case_Classification__c);
        Assert.areEqual('Legal or RERA complaint', complex.Escalation_Reason__c);
    }

    @IsTest
    static void formattingFollowsIndianConventions() {
        Assert.areEqual('₹42,75,000', ResiAgentService.inr(4275000));
        Assert.areEqual('₹999', ResiAgentService.inr(999));
        Assert.areEqual('₹0', ResiAgentService.inr(null));
        Assert.areEqual('05 Jan 2027', ResiAgentService.fmt(Date.newInstance(2027, 1, 5)));
        Assert.areEqual('not scheduled', ResiAgentService.fmt(null));
    }

    @IsTest(SeeAllData=true)
    static void unknownSenderGetsNoCustomerData() {
        Case c = new Case(Origin = 'Email', SuppliedEmail = 'nobody.' + Crypto.getRandomInteger() + '@example.com',
            Subject = 'Payment status', Description = 'What is my balance?');
        insert c;

        ResiAgentIdentifyCustomer.Request idReq = new ResiAgentIdentifyCustomer.Request();
        idReq.caseId = c.Id;
        Assert.isFalse(ResiAgentIdentifyCustomer.run(new List<ResiAgentIdentifyCustomer.Request>{ idReq })[0].customerFound);

        ResiAgentPaymentStatus.Request payReq = new ResiAgentPaymentStatus.Request();
        payReq.caseId = c.Id;
        Assert.isFalse(ResiAgentPaymentStatus.run(new List<ResiAgentPaymentStatus.Request>{ payReq })[0].found);

        ResiAgentSendDocument.Request docReq = new ResiAgentSendDocument.Request();
        docReq.caseId = c.Id;
        docReq.documentType = 'Statement of Account';
        Assert.isFalse(ResiAgentSendDocument.run(new List<ResiAgentSendDocument.Request>{ docReq })[0].sent);

        ResiAgentCheckClassification.Request clsReq = new ResiAgentCheckClassification.Request();
        clsReq.caseId = c.Id;
        Assert.isFalse(ResiAgentCheckClassification.run(new List<ResiAgentCheckClassification.Request>{ clsReq })[0].isComplexCase);
    }

    @IsTest(SeeAllData=true)
    static void knownBuyerGetsBookingsPaymentsAndDocuments() {
        List<Account> buyers = [
            SELECT PersonEmail FROM Account
            WHERE IsPersonAccount = true AND PersonEmail != null AND Id IN (SELECT Account_Id__c FROM Booking__c)
            LIMIT 1
        ];
        if (buyers.isEmpty()) {
            return; // no buyer data in this org
        }
        Case c = new Case(Origin = 'Email', SuppliedEmail = buyers[0].PersonEmail, Subject = 'Balance and statement',
            Description = 'Please share my outstanding amount and statement of account.');
        insert c;

        ResiAgentIdentifyCustomer.Request idReq = new ResiAgentIdentifyCustomer.Request();
        idReq.caseId = c.Id;
        ResiAgentIdentifyCustomer.Result who = ResiAgentIdentifyCustomer.run(new List<ResiAgentIdentifyCustomer.Request>{ idReq })[0];
        Assert.isTrue(who.customerFound);
        Assert.isTrue(who.bookingCount > 0);

        ResiAgentListBookings.Request listReq = new ResiAgentListBookings.Request();
        listReq.caseId = c.Id;
        ResiAgentListBookings.Result listed = ResiAgentListBookings.run(new List<ResiAgentListBookings.Request>{ listReq })[0];
        Assert.isTrue(listed.bookings.contains('BO-'));

        Booking__c first = [SELECT Name FROM Booking__c WHERE Account_Id__c = :buyers[0].Id ORDER BY CreatedDate DESC LIMIT 1];
        ResiAgentBookingDetails.Request detReq = new ResiAgentBookingDetails.Request();
        detReq.caseId = c.Id;
        detReq.bookingReference = first.Name;
        Assert.isTrue(ResiAgentBookingDetails.run(new List<ResiAgentBookingDetails.Request>{ detReq })[0].found);

        ResiAgentPaymentStatus.Request payReq = new ResiAgentPaymentStatus.Request();
        payReq.caseId = c.Id;
        Assert.isTrue(ResiAgentPaymentStatus.run(new List<ResiAgentPaymentStatus.Request>{ payReq })[0].found);

        ResiAgentSendDocument.Request docReq = new ResiAgentSendDocument.Request();
        docReq.caseId = c.Id;
        docReq.documentType = 'Payment Ledger';
        docReq.bookingReference = first.Name;
        Assert.isTrue(ResiAgentSendDocument.run(new List<ResiAgentSendDocument.Request>{ docReq })[0].sent);

        ResiAgentEscalateCase.Request escReq = new ResiAgentEscalateCase.Request();
        escReq.caseId = c.Id;
        escReq.reason = 'Payment dispute';
        escReq.summary = 'Customer disputes interest on a delayed instalment.';
        ResiAgentEscalateCase.Result esc = ResiAgentEscalateCase.run(new List<ResiAgentEscalateCase.Request>{ escReq })[0];
        Assert.isNotNull(esc.escalationCaseNumber);
        Assert.isTrue(esc.acknowledgement.contains(esc.escalationCaseNumber));
        Case escalated = [SELECT Case_Classification__c, Status FROM Case WHERE Id = :c.Id];
        Assert.areEqual('COMPLEX', escalated.Case_Classification__c);
        Assert.areEqual(ResiAgentService.STATUS_ESCALATED, escalated.Status);

        // A reply after escalation must not close the case.
        ResiAgentSendReply.Request replyReq = new ResiAgentSendReply.Request();
        replyReq.caseId = c.Id;
        replyReq.replyBody = esc.acknowledgement;
        ResiAgentSendReply.run(new List<ResiAgentSendReply.Request>{ replyReq });
        Assert.areEqual(ResiAgentService.STATUS_ESCALATED, [SELECT Status FROM Case WHERE Id = :c.Id].Status);
    }

    @IsTest(SeeAllData=true)
    static void agentReplyResolvesCase() {
        Case c = new Case(Origin = 'Email', SuppliedEmail = 'buyer.resolve@example.com', Subject = 'Site office timings',
            Description = 'What are the site office timings?');
        insert c;
        ResiAgentSendReply.Request r = new ResiAgentSendReply.Request();
        r.caseId = c.Id;
        r.replyBody = '{"type":"Text","value":"Our site office is open 10 am to 6 pm."}';
        Assert.isTrue(ResiAgentSendReply.run(new List<ResiAgentSendReply.Request>{ r })[0].sent);
        Assert.areEqual(ResiAgentService.STATUS_RESOLVED, [SELECT Status FROM Case WHERE Id = :c.Id].Status);
    }
}