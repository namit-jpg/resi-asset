@IsTest
private class BookingFormControllerTest {

    @TestSetup
    static void setup() {
        Property__c project = new Property__c(Name = 'Miyapur Manor');
        insert project;
        Tower__c tower = new Tower__c(Name = 'Block 2', Property__c = project.Id);
        insert tower;
        Floor__c floor = new Floor__c(Name = '6th', Tower__c = tower.Id);
        insert floor;
        Unit__c unit = new Unit__c(Name = 'MM-B2-600', Property__c = project.Id, Tower__c = tower.Id, Floor__c = floor.Id,
            BHK_Configuration__c = '4.5 BHK', Status__c = 'Available', Saleable_Area__c = 2000);
        insert unit;

        Account a = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            FirstName = 'Ayan', LastName = 'Mukherjee', PersonEmail = 'ayan@example.com', PersonMobilePhone = '9876543210'
        );
        insert a;

        Opportunity o = new Opportunity(Name = 'Ayan : MM-B2-600', AccountId = a.Id, StageName = 'Negotiation',
            CloseDate = Date.today().addDays(30), Interested_Unit__c = unit.Id, Token_Amount__c = 1000000);
        Schema.RecordTypeInfo rt = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Residential_Sales_Opportunity');
        if (rt != null) {
            o.RecordTypeId = rt.getRecordTypeId();
        }
        insert o;
    }

    static Opportunity opp() {
        return [SELECT Id, Booking_Form_Token__c, Booking_Form_URL__c, Booking_Form_Status__c FROM Opportunity LIMIT 1];
    }

    static String token() {
        BookingFormLinkController.testBaseUrl = 'https://example.my.site.com/booking';
        BookingFormLinkController.generateLink(opp().Id);
        return opp().Booking_Form_Token__c;
    }

    static Map<String, Object> applicant(String key, String role, String name, String pan, Boolean signed) {
        Map<String, Object> ap = new Map<String, Object>{
            'key' => key, 'role' => role, 'fullLegalName' => name, 'pan' => pan, 'mobile' => '9876500001',
            'email' => key.toLowerCase() + '@example.com', 'dob' => '1988-04-12', 'salutation' => 'Mr', 'relationship' => 'Spouse',
            'address' => new Map<String, Object>{ 'line1' => 'Flat 402, Sai Residency', 'locality' => 'Banjara Hills', 'city' => 'Hyderabad',
                'state' => 'Telangana', 'pincode' => '500034', 'country' => 'India' },
            'documents' => new Map<String, Object>()
        };
        if (signed) {
            ap.put('signature', new Map<String, Object>{ 'name' => name, 'signedAt' => '2026-10-01T10:00:00Z' });
        }
        return ap;
    }

    static String payload(Boolean signed) {
        Map<String, Object> declarations = new Map<String, Object>();
        for (String d : new List<String>{ 'accurate', 'bookingTerms', 'paymentTerms', 'cancellation', 'privacy', 'electronic' }) {
            declarations.put(d, true);
        }
        return JSON.serialize(new Map<String, Object>{
            'step' => 'sign',
            'applicants' => new List<Object>{
                applicant('A1', 'PRIMARY', 'Ayan Mukherjee', 'ABCPM1234K', signed),
                applicant('A2', 'CO_APPLICANT', 'Riya Mukherjee', 'ABCPM5678L', signed)
            },
            'nominee' => new Map<String, Object>{ 'provided' => true, 'fullName' => 'Arya Mukherjee', 'relationship' => 'Child',
                'dob' => '2015-06-01', 'sharePct' => '100', 'isMinor' => true, 'guardianName' => 'Riya Mukherjee', 'guardianRelationship' => 'Parent' },
            'declarations' => declarations
        });
    }

    @IsTest
    static void generateLinkStoresTokenAndUrl() {
        String t = token();
        Opportunity o = opp();
        Assert.areEqual(64, t.length());
        Assert.areEqual('https://example.my.site.com/booking/?t=' + t, o.Booking_Form_URL__c);
        Assert.areEqual(BookingFormService.STATUS_GENERATED, o.Booking_Form_Status__c);

        BookingFormLinkController.LinkStatus s = BookingFormLinkController.getStatus(o.Id);
        Assert.areEqual('Ayan Mukherjee', s.customerName);
        Assert.areEqual('MM-B2-600', s.unit);
        Assert.isTrue(BookingFormLinkController.getShareMessage(o.Id).contains(t));

        // Replacing the link disables the old token.
        BookingFormLinkController.generateLink(o.Id);
        try {
            BookingFormSiteController.load(t);
            Assert.fail('The replaced token should no longer open the form');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('no longer valid'), e.getMessage());
        }
    }

    @IsTest
    static void loadPrefillsFromOpportunityAndAccount() {
        Map<String, Object> res = BookingFormSiteController.load(token());
        Map<String, Object> ctx = (Map<String, Object>) res.get('context');
        Assert.areEqual('Miyapur Manor', ctx.get('project'));
        Assert.areEqual('MM-B2-600', ctx.get('unit'));
        Assert.areEqual('Block 2', ctx.get('tower'));
        Assert.areEqual(1000000, (Decimal) ctx.get('tokenAmount'));
        Map<String, Object> data = (Map<String, Object>) res.get('data');
        Map<String, Object> primary = (Map<String, Object>) ((List<Object>) data.get('applicants'))[0];
        Assert.areEqual('Ayan Mukherjee', primary.get('fullLegalName'));
        Assert.areEqual('9876543210', primary.get('mobile'));
        Assert.isFalse((Boolean) res.get('locked'));
    }

    @IsTest
    static void invalidTokenIsRefused() {
        try {
            BookingFormSiteController.load('nope');
            Assert.fail('A malformed token should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('not valid'), e.getMessage());
        }
    }

    @IsTest
    static void draftUploadPaymentAndSubmitMapBack() {
        String t = token();
        BookingFormSiteController.saveDraft(t, payload(false));
        Assert.areEqual(BookingFormService.STATUS_IN_PROGRESS, opp().Booking_Form_Status__c);

        Map<String, Object> doc = BookingFormSiteController.uploadDocument(t, 'Ayan Mukherjee', 'PAN card', 'pan.pdf',
            EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 test')));
        Assert.isNotNull(doc.get('contentVersionId'));
        Id oppId = opp().Id;
        Assert.areEqual(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :oppId]);

        try {
            BookingFormSiteController.submit(t, payload(true));
            Assert.fail('Submission before payment should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('token advance'), e.getMessage());
        }

        Map<String, Object> failed = BookingFormSiteController.recordPayment(t, 'UPI', 'failed');
        Assert.areEqual('Failed', failed.get('status'));
        Map<String, Object> paid = BookingFormSiteController.recordPayment(t, 'UPI', 'success');
        Assert.areEqual('Paid', paid.get('status'));
        Assert.areEqual(1000000, (Decimal) paid.get('amount'));

        try {
            BookingFormSiteController.submit(t, payload(false));
            Assert.fail('Unsigned submission should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('has not signed'), e.getMessage());
        }

        Test.startTest();
        BookingFormSiteController.submit(t, payload(true));
        Test.stopTest();

        Opportunity o = [SELECT Booking_Form_Status__c, Booking_Form_Submitted_At__c, Nominee_Name__c, Nominee_Guardian__c, Nominee_Share__c,
            Token_Payment_Status__c, AccountId FROM Opportunity WHERE Id = :oppId];
        Assert.areEqual(BookingFormService.STATUS_SUBMITTED, o.Booking_Form_Status__c);
        Assert.areEqual('Arya Mukherjee', o.Nominee_Name__c);
        Assert.areEqual('Riya Mukherjee (Parent)', o.Nominee_Guardian__c);
        Assert.areEqual(100, o.Nominee_Share__c);

        Account primary = [SELECT PAN_Number__c, PersonBirthdate FROM Account WHERE Id = :o.AccountId];
        Assert.areEqual('ABCPM1234K', primary.PAN_Number__c);
        Assert.areEqual(Date.newInstance(1988, 4, 12), primary.PersonBirthdate);

        Account co = [SELECT Id, PersonContactId, LastName FROM Account WHERE PAN_Number__c = 'ABCPM5678L'];
        Assert.areEqual('Mukherjee', co.LastName);
        Map<String, String> roles = new Map<String, String>();
        for (OpportunityContactRole r : [SELECT ContactId, Role FROM OpportunityContactRole WHERE OpportunityId = :oppId]) {
            roles.put(r.ContactId, r.Role);
        }
        Assert.areEqual('Co-Applicant', roles.get(co.PersonContactId));
        Assert.isTrue(roles.values().contains('Primary Applicant'));

        // A submitted form is read-only until sales reopens it.
        Assert.isTrue((Boolean) BookingFormSiteController.load(t).get('locked'));
        try {
            BookingFormSiteController.saveDraft(t, payload(true));
            Assert.fail('Saving a submitted form should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('already been submitted'), e.getMessage());
        }

        BookingFormLinkController.LinkStatus s = BookingFormLinkController.reopen(oppId);
        Assert.areEqual(BookingFormService.STATUS_REOPENED, s.status);
        Assert.areEqual(2, s.applicants.size());
        Assert.isFalse((Boolean) s.applicants[0].get('signed'), 'Reopening clears signatures');
        Assert.isFalse((Boolean) BookingFormSiteController.load(t).get('locked'));
    }

    @IsTest
    static void siteGuestCanSaveUploadAndPay() {
        List<User> guests = [
            SELECT Id FROM User
            WHERE UserType = 'Guest' AND Profile.Name = :BookingFormService.SITE_NAME + ' Profile' AND IsActive = true
            LIMIT 1
        ];
        if (guests.isEmpty()) {
            return;
        }
        String t = token();
        System.runAs(guests[0]) {
            BookingFormSiteController.load(t);
            BookingFormSiteController.saveDraft(t, payload(false));
            Map<String, Object> doc = BookingFormSiteController.uploadDocument(t, 'Ayan Mukherjee', 'PAN card', 'pan.pdf',
                EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 test')));
            Assert.isNotNull(doc.get('contentVersionId'));
            Assert.areEqual('Paid', BookingFormSiteController.recordPayment(t, 'UPI', 'success').get('status'));
            BookingFormSiteController.submit(t, payload(true));
        }
        Assert.areEqual(BookingFormService.STATUS_SUBMITTED, opp().Booking_Form_Status__c);
        Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE PAN_Number__c = 'ABCPM5678L']);
    }

    @IsTest
    static void uploadRejectsUnsupportedFiles() {
        String t = token();
        try {
            BookingFormSiteController.uploadDocument(t, 'Ayan', 'PAN card', 'pan.exe', EncodingUtil.base64Encode(Blob.valueOf('x')));
            Assert.fail('Executables should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('PDF, JPG or PNG'), e.getMessage());
        }
    }

    @IsTest
    static void emailNeedsALink() {
        try {
            BookingFormLinkController.emailLink(opp().Id);
            Assert.fail('Email without a link should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Generate the link'), e.getMessage());
        }
    }
}