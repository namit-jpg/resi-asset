@IsTest
private class EoiBookingAdjustmentTest {

    @TestSetup
    static void setup() {
        Property__c project = new Property__c(Name = 'Varthur Vista');
        insert project;
        Tower__c tower = new Tower__c(Name = 'Tower 1', Property__c = project.Id);
        insert tower;
        Floor__c floor = new Floor__c(Name = '3rd', Tower__c = tower.Id);
        insert floor;
        Unit__c unit = new Unit__c(Name = 'VV-T1-301', Property__c = project.Id, Tower__c = tower.Id, Floor__c = floor.Id,
            BHK_Configuration__c = '3 BHK Classic', Status__c = 'Available', Saleable_Area__c = 1500);
        insert unit;

        Account a = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            FirstName = 'Kavya', LastName = 'Rao', PersonEmail = 'kavya.rao@example.com', PersonMobilePhone = '9876500011'
        );
        insert a;
        Opportunity o = new Opportunity(Name = 'Kavya : VV-T1-301', AccountId = a.Id, StageName = 'Negotiation',
            CloseDate = Date.today().addDays(30), Interested_Unit__c = unit.Id, Token_Amount__c = 100000);
        Schema.RecordTypeInfo rt = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Residential_Sales_Opportunity');
        if (rt != null) {
            o.RecordTypeId = rt.getRecordTypeId();
        }
        insert o;

        insert new Voucher__c(
            Opportunity__c = o.Id, Account__c = a.Id, Project__c = project.Id, Applicable_To__c = 'Customer',
            Voucher_Type__c = 'Standard EOI', Amount__c = 100000, Amount_Paid__c = 100000, Status__c = EoiVoucherController.PAID,
            Payment_Mode__c = 'UPI', Payment_Reference__c = 'UTR778899', Payment_Date__c = Date.today(), Priority_Number__c = 1,
            Applicant_Name__c = 'Kavya Rao', Valid_Until__c = Date.today().addDays(30)
        );
    }

    static Opportunity opp() {
        return [SELECT Id, AccountId, Interested_Unit__c, Interested_Unit__r.Property__c FROM Opportunity LIMIT 1];
    }

    /** Books the opportunity the way the booking flow does: booking first, then the token and instalments. */
    static Booking__c book(Boolean withInstalments) {
        Opportunity o = opp();
        Booking__c b = new Booking__c(Account_Id__c = o.AccountId, Opportunity_Id__c = o.Id, Unit_Id__c = o.Interested_Unit__c,
            Project__c = o.Interested_Unit__r.Property__c, Final_Amount__c = 1000000, Token_Amount__c = 100000,
            Booking_Date__c = Date.today(), Status__c = 'Pending Confirmation');
        insert b;
        if (withInstalments) {
            insert new List<Booking_Payment_Schedule__c>{
                new Booking_Payment_Schedule__c(Booking__c = b.Id, Installment_Number__c = 1, Installment_Amount__c = 100000,
                    Amount_Paid__c = 100000, Payment_Status__c = 'Paid', Mode_Of_Payment__c = 'RTGS', Is_Token_Amount__c = true, Payment_Due_Date__c = Date.today()),
                new Booking_Payment_Schedule__c(Booking__c = b.Id, Installment_Number__c = 2, Installment_Amount__c = 60000,
                    Amount_Paid__c = 0, Payment_Status__c = 'Pending', Payment_Due_Date__c = Date.today().addDays(30)),
                new Booking_Payment_Schedule__c(Booking__c = b.Id, Installment_Number__c = 3, Installment_Amount__c = 840000,
                    Amount_Paid__c = 0, Payment_Status__c = 'Pending', Payment_Due_Date__c = Date.today().addDays(60))
            };
        }
        return b;
    }

    @IsTest
    static void newBookingDeductsPaidEoiFromInstalments() {
        Test.startTest();
        Booking__c b = book(true);
        Test.stopTest();

        Map<Decimal, Booking_Payment_Schedule__c> byNumber = new Map<Decimal, Booking_Payment_Schedule__c>();
        for (Booking_Payment_Schedule__c s : [SELECT Installment_Number__c, Amount_Paid__c, Payment_Status__c, Mode_Of_Payment__c FROM Booking_Payment_Schedule__c WHERE Booking__c = :b.Id]) {
            byNumber.put(s.Installment_Number__c, s);
        }
        Assert.areEqual(100000, byNumber.get(1).Amount_Paid__c, 'Token is untouched');
        Assert.areEqual(60000, byNumber.get(2).Amount_Paid__c);
        Assert.areEqual('Paid', byNumber.get(2).Payment_Status__c);
        Assert.areEqual('Net Banking', byNumber.get(2).Mode_Of_Payment__c);
        Assert.areEqual(40000, byNumber.get(3).Amount_Paid__c, 'The rest of the EOI moves to the next instalment');
        Assert.areEqual('Pending', byNumber.get(3).Payment_Status__c);

        List<Payment_Receipt__c> receipts = [
            SELECT Amount_Paid__c, Approval_Status__c, Mode_Of_Payment__c, Transaction_Reference__c
            FROM Payment_Receipt__c WHERE Booking_Payment_Schedule__r.Booking__c = :b.Id ORDER BY Amount_Paid__c DESC
        ];
        Assert.areEqual(2, receipts.size());
        Assert.areEqual(60000, receipts[0].Amount_Paid__c);
        Assert.areEqual('Approved', receipts[0].Approval_Status__c);
        Assert.areEqual('Net Banking', receipts[0].Mode_Of_Payment__c);
        Assert.isTrue(receipts[0].Transaction_Reference__c.startsWith('EOI '), receipts[0].Transaction_Reference__c);

        Voucher__c v = [SELECT Status__c, Booking__c, Flat_No__c, Remarks__c FROM Voucher__c LIMIT 1];
        Assert.areEqual(EoiVoucherController.CONVERTED, v.Status__c);
        Assert.areEqual(b.Id, v.Booking__c);
        Assert.areEqual(opp().Interested_Unit__c, v.Flat_No__c);
        Assert.isTrue(v.Remarks__c.contains('adjusted against'), v.Remarks__c);
    }

    @IsTest
    static void bookingWithoutInstalmentsLeavesEoiOpen() {
        Booking__c b = book(false);
        Voucher__c v = [SELECT Id, Name, Status__c, Amount_Paid__c, Payment_Mode__c, Payment_Reference__c, Payment_Date__c,
            Opportunity__c, Account__c, Project__c, Flat_No__c, Remarks__c FROM Voucher__c LIMIT 1];
        Test.startTest();
        List<Payment_Receipt__c> receipts = EoiBookingAdjustment.apply(v, EoiBookingAdjustment.loadBookings(new Set<Id>{ b.Id })[0]);
        Test.stopTest();
        Assert.isTrue(receipts.isEmpty());
        Assert.areEqual(EoiVoucherController.PAID, [SELECT Status__c FROM Voucher__c WHERE Id = :v.Id].Status__c);
    }

    @IsTest
    static void bookingFormShowsEoiAndBalance() {
        BookingFormLinkController.testBaseUrl = 'https://example.my.site.com/booking';
        Id oppId = opp().Id;
        BookingFormLinkController.generateLink(oppId);
        String token = [SELECT Booking_Form_Token__c FROM Opportunity WHERE Id = :oppId].Booking_Form_Token__c;

        Map<String, Object> ctx = BookingFormService.context(BookingFormService.resolve(token));
        Assert.areEqual(100000, (Decimal) ctx.get('eoiPaid'));
        Assert.isTrue(String.valueOf(ctx.get('eoiVouchers')).startsWith('EOI'), String.valueOf(ctx.get('eoiVouchers')));
        Decimal bookingValue = (Decimal) ctx.get('bookingValue');
        if (bookingValue != null) {
            Assert.areEqual(Math.max(0, bookingValue - 100000), (Decimal) ctx.get('balancePayable'));
        }
    }
}
