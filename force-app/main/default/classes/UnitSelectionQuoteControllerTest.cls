@IsTest
private class UnitSelectionQuoteControllerTest {

    @TestSetup
    static void setupTestData() {
        Property__c prop = new Property__c(
            Name = 'Grand Residency Towers'
        );
        insert prop;

        Tower__c tow = new Tower__c(
            Name = 'Tower Apex',
            Property__c = prop.Id
        );
        insert tow;

        Floor__c flr = new Floor__c(
            Name = 'Floor 8',
            Tower__c = tow.Id
        );
        insert flr;

        Unit__c u = new Unit__c(
            Name = 'Unit 802',
            Floor__c = flr.Id,
            Tower__c = tow.Id,
            Property__c = prop.Id,
            BHK_Configuration__c = '3 BHK',
            Status__c = 'Available',
            Base_Price__c = 4800,
            Built_Up_Area_SBA__c = 1420,
            Carpet_Area__c = 1100
        );
        insert u;

        Account cust = new Account(
            Name = 'Rajesh Verma',
            Phone = '9876543210'
        );
        insert cust;

        Opportunity opp = new Opportunity(
            Name = 'Rajesh Verma - 3 BHK Deal',
            AccountId = cust.Id,
            Interested_Unit__c = u.Id,
            StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Payment_Plan__c plan = new Payment_Plan__c(
            Name = 'Grand Residency CLP'
        );
        insert plan;

        insert new List<Payment_Schedule__c>{
            new Payment_Schedule__c(
                Payment_Plan_Id__c = plan.Id,
                Installment_Number__c = 1,
                Payment_Percentage__c = 10,
                Milestone_Code__c = 'Booking Token (10%)',
                Due_In_Days__c = 0
            ),
            new Payment_Schedule__c(
                Payment_Plan_Id__c = plan.Id,
                Installment_Number__c = 2,
                Payment_Percentage__c = 10,
                Milestone_Code__c = 'Agreement Execution (10%)',
                Due_In_Days__c = 30
            )
        };
    }

    @IsTest
    static void testOpportunityContextAndInventory() {
        Opportunity opp = [SELECT Id, Interested_Unit__r.Property__c FROM Opportunity LIMIT 1];
        Tower__c tow = [SELECT Id FROM Tower__c LIMIT 1];

        Test.startTest();
        UnitSelectionQuoteController.OpportunityContextWrapper ctx = UnitSelectionQuoteController.getOpportunityContext(opp.Id);
        List<UnitSelectionQuoteController.TowerItemWrapper> towers = UnitSelectionQuoteController.getTowersForProject(opp.Interested_Unit__r.Property__c);
        List<UnitSelectionQuoteController.UnitItemWrapper> units = UnitSelectionQuoteController.getUnitsForTower(tow.Id);
        Test.stopTest();

        System.assertNotEquals(null, ctx);
        System.assertEquals('Rajesh Verma', ctx.customerName);
        System.assertEquals(1, towers.size());
        System.assert(String.isNotBlank(towers[0].highlights));
        System.assertEquals(1, units.size());
        System.assertEquals('Unit 802', units[0].unitName);
        System.assertEquals(1420, units[0].sbaSqFt);
    }

    @IsTest
    static void testSaveQuotationAndAgreement() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];

        Test.startTest();
        // 1. Generate Quotation with locked SBA and commercial options
        UnitSelectionQuoteController.QuoteResultWrapper quoteRes = UnitSelectionQuoteController.saveQuotation(
            opp.Id,
            u.Id,
            100, // discount
            1,   // parking bay
            150, // PLC
            'Premium Italian Marble',
            'Customer requested fast-track paperwork.'
        );
        System.assert(quoteRes.success);
        System.assertNotEquals(null, quoteRes.quoteId);

        // Verify Opportunity updated
        Opportunity afterQuoteOpp = [SELECT Id, StageName, Interested_Unit__c, Amount FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Quotation Shared', afterQuoteOpp.StageName);
        System.assertEquals(u.Id, afterQuoteOpp.Interested_Unit__c);
        System.assert(afterQuoteOpp.Amount > 0);

        // 2. Mark Customer Agreement
        UnitSelectionQuoteController.QuoteResultWrapper agreeRes = UnitSelectionQuoteController.agreeQuotation(opp.Id, quoteRes.quoteId);
        System.assert(agreeRes.success);

        Opportunity agreedOpp = [SELECT Id, StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Quotation Agreed', agreedOpp.StageName);

        Quote q = [SELECT Id, Status FROM Quote WHERE Id = :quoteRes.quoteId];
        System.assertEquals('Accepted', q.Status);
        Test.stopTest();
    }

    @IsTest
    static void testOpportunityTriggerCloseWonValidation() {
        Account cust = [SELECT Id FROM Account LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];

        // Create Opp without any Quote
        Opportunity freshOpp = new Opportunity(
            Name = 'Fresh Unquoted Opp',
            AccountId = cust.Id,
            Interested_Unit__c = u.Id,
            StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30)
        );
        insert freshOpp;

        Test.startTest();
        try {
            freshOpp.StageName = 'Closed Won';
            update freshOpp;
            System.assert(false, 'Should have failed Close Won validation');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Cannot Close-Win Opportunity'), 'Should prevent close won without quote');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSyncToSapAndCreateBooking() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];

        // Create quote first
        UnitSelectionQuoteController.QuoteResultWrapper quoteRes = UnitSelectionQuoteController.saveQuotation(
            opp.Id,
            u.Id,
            50,
            1,
            100,
            'Standard',
            ''
        );

        Test.startTest();
        UnitSelectionQuoteController.SapBookingResultWrapper sapRes = UnitSelectionQuoteController.syncToSapAndCreateBooking(opp.Id);
        Test.stopTest();

        System.assert(sapRes.success);
        System.assertNotEquals(null, sapRes.bookingId);
        System.assert(sapRes.bookingReferenceId.startsWith('BR-'), 'Booking Reference ID must start with BR-');

        // Verify Unit is marked Blocked
        Unit__c updatedUnit = [SELECT Id, Status__c FROM Unit__c WHERE Id = :u.Id];
        System.assertEquals('Blocked', updatedUnit.Status__c, 'Unit status must be Blocked upon Booking creation');

        // Verify Booking record
        Booking__c createdBooking = [SELECT Id, SFDC_booking_reference_no__c, Status__c, Token_Amount__c FROM Booking__c WHERE Id = :sapRes.bookingId];
        System.assertEquals(sapRes.bookingReferenceId, createdBooking.SFDC_booking_reference_no__c);
        System.assertEquals('Active', createdBooking.Status__c);

        // Verify default installments & co-owner
        List<Booking_Payment_Schedule__c> installments = [SELECT Id, Payment_Status__c FROM Booking_Payment_Schedule__c WHERE Booking__c = :sapRes.bookingId];
        System.assert(installments.size() >= 2, 'Should create initial milestones');

        List<Co_Owner__c> applicants = [SELECT Id FROM Co_Owner__c WHERE Booking__c = :sapRes.bookingId];
        System.assertEquals(1, applicants.size(), 'Should create Primary Co-Owner');
    }

    @IsTest
    static void testQuoteCommercialsAndRevision() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];

        // Create initial quote
        UnitSelectionQuoteController.QuoteResultWrapper quoteRes = UnitSelectionQuoteController.saveQuotation(
            opp.Id,
            u.Id,
            50,
            1,
            100,
            'Standard Vitrified Finish',
            'Initial discussion'
        );

        Test.startTest();
        UnitSelectionQuoteController.QuoteCommercialWrapper comms = UnitSelectionQuoteController.getQuoteCommercials(quoteRes.quoteId);
        System.assertNotEquals(null, comms);
        System.assertEquals('Unit 802', comms.unitName);
        System.assertEquals(1420, comms.sbaSqFt);

        UnitSelectionQuoteController.QuoteResultWrapper updateRes = UnitSelectionQuoteController.updateQuoteCommercials(
            quoteRes.quoteId,
            150, // Updated discount
            2,   // 2 parking bays
            150, // Updated PLC
            'Customer agreed after higher discount concession'
        );
        Test.stopTest();

        System.assert(updateRes.success);
        System.assert(updateRes.grandTotal > 0);

        Opportunity syncedOpp = [SELECT Amount FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(updateRes.grandTotal, syncedOpp.Amount);
    }
}