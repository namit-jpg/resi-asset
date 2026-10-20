/**
 * Shared logic for the customer booking form (bookingCustomerForm on the "Nikoo Homes Booking" site).
 *
 * The form is keyed by Opportunity.Booking_Form_Token__c. Answers are kept as JSON in
 * Booking_Form_Data__c while the customer works; submit() maps them onto the Opportunity,
 * the customer's person account, co-applicant person accounts and contact roles.
 *
 * Runs without sharing because the site guest user calls it. Every entry point resolves the
 * opportunity from the token and never accepts a record id from the browser.
 */
public without sharing class BookingFormService {

    public static final Integer LINK_VALIDITY_DAYS = 30;
    public static final String SITE_NAME = 'Nikoo Homes Booking';
    public static final String DEVELOPER = 'Nikoo Homes';

    public static final String STATUS_GENERATED = 'Link Generated';
    public static final String STATUS_IN_PROGRESS = 'In Progress';
    public static final String STATUS_SUBMITTED = 'Submitted';
    public static final String STATUS_REOPENED = 'Reopened';

    private static final Map<String, String> SALUTATIONS = new Map<String, String>{
        'Mr' => 'Mr.', 'Mrs' => 'Mrs.', 'Ms' => 'Ms.', 'Dr' => 'Dr.'
    };

    public class BookingFormException extends Exception {}

    // ---------- Token ----------

    public static String newToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }

    public static Opportunity resolve(String token) {
        if (String.isBlank(token) || token.length() != 64) {
            throw new BookingFormException('This booking link is not valid. Please use the link shared by your relationship manager.');
        }
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, OwnerId, Owner.Name, Owner.Email, Owner.MobilePhone, AccountId, CloseDate,
                Booking_Form_Token__c, Booking_Form_Status__c, Booking_Form_Step__c, Booking_Form_Data__c,
                Booking_Form_Expires_On__c, Booking_Form_Submitted_At__c, Booking_Form_Generated_At__c,
                Token_Amount__c, Total_Amount__c, Chargeable_Area__c, Payment_Plan__r.Name,
                Token_Payment_Status__c, Payment_Mode__c, Transaction_Reference__c, Token_Amount_Paid__c, Token_Payment_Date__c,
                Interested_Unit__c, Interested_Unit__r.Name, Interested_Unit__r.BHK_Configuration__c,
                Interested_Unit__r.Saleable_Area__c, Interested_Unit__r.Carpet_Area__c, Interested_Unit__r.Total_Cost__c,
                Interested_Unit__r.Tower__r.Name, Interested_Unit__r.Floor__r.Name,
                Interested_Unit__r.Property__c, Interested_Unit__r.Property__r.Name, Interested_Unit__r.Property__r.Project_ID__c
            FROM Opportunity
            WHERE Booking_Form_Token__c = :token
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw new BookingFormException('This booking link is no longer valid. Please ask your relationship manager for a new link.');
        }
        Opportunity o = opps[0];
        if (o.Booking_Form_Expires_On__c != null && o.Booking_Form_Expires_On__c < Date.today()
                && o.Booking_Form_Status__c != STATUS_SUBMITTED) {
            throw new BookingFormException('This booking link has expired. Please ask your relationship manager for a new link.');
        }
        return o;
    }

    public static Boolean isLocked(Opportunity o) {
        return o.Booking_Form_Status__c == STATUS_SUBMITTED;
    }

    public static void requireEditable(Opportunity o) {
        if (isLocked(o)) {
            throw new BookingFormException('This booking form has already been submitted. Contact your relationship manager to make changes.');
        }
    }

    // ---------- Context for the form ----------

    public static Map<String, Object> context(Opportunity o) {
        Unit__c u = o.Interested_Unit__r;
        Decimal bookingValue = o.Total_Amount__c != null && o.Total_Amount__c > 0 ? o.Total_Amount__c : u?.Total_Cost__c;
        Decimal area = o.Chargeable_Area__c != null && o.Chargeable_Area__c > 0 ? o.Chargeable_Area__c : u?.Saleable_Area__c;
        Decimal eoiPaid = 0;
        List<String> voucherNames = new List<String>();
        for (Voucher__c v : eoiVouchers(o)) {
            eoiPaid += v.Amount_Paid__c;
            voucherNames.add(v.Name);
        }
        return new Map<String, Object>{
            'eoiPaid' => eoiPaid,
            'eoiVouchers' => String.join(voucherNames, ', '),
            'balancePayable' => bookingValue == null || eoiPaid == 0 ? null : Math.max(0, bookingValue - eoiPaid),
            'developer' => DEVELOPER,
            'opportunityName' => o.Name,
            'project' => u?.Property__r?.Name,
            'tower' => u?.Tower__r?.Name,
            'unit' => u?.Name,
            'floor' => u?.Floor__r?.Name,
            'configuration' => u?.BHK_Configuration__c,
            'chargeableArea' => area,
            'carpetArea' => u?.Carpet_Area__c,
            'bookingValue' => bookingValue,
            'tokenAmount' => o.Token_Amount__c,
            'paymentPlan' => o.Payment_Plan__r?.Name,
            'relationshipManager' => o.Owner?.Name,
            'bookingDate' => Date.today()
        };
    }

    /**
     * Paid EOIs that count towards this deal (see EoiBookingAdjustment): linked to the opportunity,
     * or the customer's unlinked EOIs for the same project.
     */
    private static List<Voucher__c> eoiVouchers(Opportunity o) {
        Set<String> counted = new Set<String>{ EoiVoucherController.PAID, EoiVoucherController.ALLOTTED, EoiVoucherController.CONVERTED };
        Id projectId = o.Interested_Unit__r?.Property__c;
        List<Voucher__c> result = new List<Voucher__c>();
        for (Voucher__c v : [
            SELECT Name, Amount_Paid__c, Opportunity__c, Account__c, Project__c, Booking__c, Status__c
            FROM Voucher__c
            WHERE Amount_Paid__c > 0 AND Status__c IN :counted
              AND (Opportunity__c = :o.Id OR (Opportunity__c = null AND Account__c = :o.AccountId))
            ORDER BY Name
        ]) {
            Boolean sameOpp = v.Opportunity__c == o.Id;
            Boolean sameCustomer = v.Opportunity__c == null && o.AccountId != null && v.Booking__c == null
                && v.Status__c != EoiVoucherController.CONVERTED && projectId != null && v.Project__c == projectId;
            if (sameOpp || sameCustomer) {
                result.add(v);
            }
        }
        return result;
    }

    /** First-visit answers, prefilled from the customer's account. */
    public static Map<String, Object> prefill(Opportunity o) {
        Map<String, Object> primary = blankApplicant('A1', 'PRIMARY');
        if (o.AccountId != null) {
            Account a = [
                SELECT Id, Name, IsPersonAccount, Salutation, PersonBirthdate, PersonEmail, PersonMobilePhone, Phone,
                    PAN_Number__c, Aadhar_Number__c, PersonMailingStreet, PersonMailingCity, PersonMailingState,
                    PersonMailingPostalCode, PersonMailingCountry
                FROM Account WHERE Id = :o.AccountId
            ];
            primary.put('fullLegalName', a.Name);
            primary.put('email', a.PersonEmail);
            primary.put('mobile', digits(String.isNotBlank(a.PersonMobilePhone) ? a.PersonMobilePhone : a.Phone));
            primary.put('pan', a.PAN_Number__c);
            primary.put('dob', a.PersonBirthdate == null ? '' : String.valueOf(a.PersonBirthdate));
            if (String.isNotBlank(a.Salutation)) {
                primary.put('salutation', a.Salutation.removeEnd('.'));
            }
            Map<String, Object> address = (Map<String, Object>) primary.get('address');
            address.put('line1', a.PersonMailingStreet);
            address.put('city', a.PersonMailingCity);
            address.put('state', a.PersonMailingState);
            address.put('pincode', a.PersonMailingPostalCode);
            if (String.isNotBlank(a.PersonMailingCountry)) {
                address.put('country', a.PersonMailingCountry);
            }
        }
        return new Map<String, Object>{
            'step' => 'details',
            'applicants' => new List<Object>{ primary },
            'activeApplicant' => 'A1',
            'nominee' => new Map<String, Object>{ 'provided' => false, 'isMinor' => false, 'sharePct' => '100' },
            'declarations' => new Map<String, Object>(),
            'payment' => new Map<String, Object>{ 'method' => 'UPI', 'status' => 'Pending', 'attempts' => new List<Object>() }
        };
    }

    private static Map<String, Object> blankApplicant(String key, String role) {
        return new Map<String, Object>{
            'key' => key,
            'role' => role,
            'nationality' => 'India',
            'residentialStatus' => 'Resident Indian',
            'address' => new Map<String, Object>{ 'country' => 'India' },
            'sameAsPermanent' => true,
            'correspondence' => new Map<String, Object>{ 'country' => 'India' },
            'documents' => new Map<String, Object>(),
            'identity' => new Map<String, Object>{ 'stage' => 'none' }
        };
    }

    // ---------- Payment (simulated gateway) ----------

    public static Map<String, Object> paymentState(Opportunity o) {
        return new Map<String, Object>{
            'status' => String.isBlank(o.Token_Payment_Status__c) ? 'Pending' : o.Token_Payment_Status__c,
            'method' => o.Payment_Mode__c,
            'paymentId' => o.Transaction_Reference__c,
            'amount' => o.Token_Amount_Paid__c,
            'paidAt' => o.Token_Payment_Date__c,
            'payable' => o.Token_Amount__c
        };
    }

    // ---------- Submit ----------

    /** Maps a submitted form onto Salesforce records. Returns the co-applicant accounts it linked. */
    public static List<Id> apply(Opportunity o, Map<String, Object> data) {
        List<Object> applicants = (List<Object>) data.get('applicants');
        List<Id> coApplicantAccounts = new List<Id>();
        Map<Id, String> contactRoles = new Map<Id, String>();

        for (Object item : applicants) {
            Map<String, Object> ap = (Map<String, Object>) item;
            Boolean isPrimary = str(ap, 'role') == 'PRIMARY';
            Account acc;
            if (isPrimary && o.AccountId != null) {
                acc = [SELECT Id, IsPersonAccount, PersonContactId FROM Account WHERE Id = :o.AccountId];
                if (acc.IsPersonAccount) {
                    updatePerson(acc.Id, ap, false);
                }
            } else {
                acc = findOrCreatePerson(ap, o.OwnerId);
                coApplicantAccounts.add(acc.Id);
            }
            if (acc.PersonContactId != null) {
                contactRoles.put(acc.PersonContactId, isPrimary ? 'Primary Applicant' : 'Co-Applicant');
            }
        }
        syncContactRoles(o.Id, contactRoles);
        linkCoApplicantsToBooking(o.Id, coApplicantAccounts);

        Map<String, Object> nominee = (Map<String, Object>) data.get('nominee');
        Opportunity upd = new Opportunity(Id = o.Id);
        if (nominee != null && nominee.get('provided') == true) {
            upd.Nominee_Name__c = str(nominee, 'fullName');
            upd.Nominee_Relationship__c = str(nominee, 'relationship');
            upd.Nominee_Date_of_Birth__c = toDate(str(nominee, 'dob'));
            upd.Nominee_Share__c = String.isBlank(str(nominee, 'sharePct')) ? null : Decimal.valueOf(str(nominee, 'sharePct'));
            upd.Nominee_Mobile__c = str(nominee, 'mobile');
            upd.Nominee_Guardian__c = nominee.get('isMinor') == true
                ? (str(nominee, 'guardianName') + ' (' + str(nominee, 'guardianRelationship') + ')').left(160)
                : null;
        } else {
            upd.Nominee_Name__c = null;
            upd.Nominee_Relationship__c = null;
            upd.Nominee_Date_of_Birth__c = null;
            upd.Nominee_Share__c = null;
            upd.Nominee_Mobile__c = null;
            upd.Nominee_Guardian__c = null;
        }
        if (o.StageName == 'Booking form' || o.StageName == 'Negotiation') {
            upd.StageName = 'Share welcome letter';
        }
        update upd;
        syncBookingContacts(o, applicants, nominee);
        return coApplicantAccounts;
    }

    // ---------- Co-applicant and nominee contacts ----------

    /**
     * Keeps one Contact per co-applicant and nominee, tagged to the opportunity's account through
     * Customer_Account__c (person accounts cannot hold contacts, so AccountId is only set for business
     * accounts). Re-submitting updates the same contacts; anyone removed from the form is removed here.
     * A failure here never blocks the booking submission.
     */
    @TestVisible
    private static void syncBookingContacts(Opportunity o, List<Object> applicants, Map<String, Object> nominee) {
        Savepoint sp = Database.setSavepoint();
        try {
            Boolean businessAccount = false;
            if (o.AccountId != null) {
                businessAccount = ![SELECT IsPersonAccount FROM Account WHERE Id = :o.AccountId].IsPersonAccount;
            }
            List<Contact> contacts = new List<Contact>();
            for (Object item : applicants) {
                Map<String, Object> ap = (Map<String, Object>) item;
                if (str(ap, 'role') == 'PRIMARY') {
                    continue;
                }
                Contact c = bookingContact(o, businessAccount, 'Co-Applicant', str(ap, 'key'), str(ap, 'fullLegalName'));
                String salutation = SALUTATIONS.get(str(ap, 'salutation'));
                if (salutation != null) c.Salutation = salutation;
                if (String.isNotBlank(str(ap, 'email'))) c.Email = str(ap, 'email');
                c.MobilePhone = str(ap, 'mobile');
                c.Birthdate = toDate(str(ap, 'dob'));
                c.Relationship_to_Applicant__c = left(str(ap, 'relationship'), 80);
                Map<String, Object> addr = (Map<String, Object>) ap.get('address');
                if (addr != null && String.isNotBlank(str(addr, 'line1'))) {
                    List<String> street = new List<String>();
                    for (String k : new List<String>{ 'line1', 'line2', 'landmark', 'locality' }) {
                        if (String.isNotBlank(str(addr, k))) {
                            street.add(str(addr, k));
                        }
                    }
                    c.MailingStreet = String.join(street, ', ');
                    c.MailingCity = str(addr, 'city');
                    c.MailingPostalCode = str(addr, 'pincode');
                    c.MailingState = str(addr, 'state');
                    c.MailingCountry = str(addr, 'country');
                }
                contacts.add(c);
            }
            if (nominee != null && nominee.get('provided') == true && String.isNotBlank(str(nominee, 'fullName'))) {
                Contact c = bookingContact(o, businessAccount, 'Nominee', 'NOMINEE', str(nominee, 'fullName'));
                c.MobilePhone = str(nominee, 'mobile');
                c.Birthdate = toDate(str(nominee, 'dob'));
                c.Relationship_to_Applicant__c = left(str(nominee, 'relationship'), 80);
                List<String> notes = new List<String>();
                if (String.isNotBlank(str(nominee, 'sharePct'))) {
                    notes.add('Nominee share: ' + str(nominee, 'sharePct') + '%');
                }
                if (nominee.get('isMinor') == true) {
                    notes.add('Minor. Guardian: ' + str(nominee, 'guardianName') + ' (' + str(nominee, 'guardianRelationship') + ')');
                }
                c.Description = notes.isEmpty() ? null : String.join(notes, '\n');
                contacts.add(c);
            }

            Set<String> keep = new Set<String>();
            for (Contact c : contacts) {
                keep.add(c.Booking_Form_Key__c);
            }
            try {
                upsert contacts Booking_Form_Key__c;
            } catch (DmlException e) {
                // Retry without the address if the state or country does not match the org's picklists.
                for (Contact c : contacts) {
                    c.MailingStreet = null;
                    c.MailingCity = null;
                    c.MailingPostalCode = null;
                    c.MailingState = null;
                    c.MailingCountry = null;
                }
                upsert contacts Booking_Form_Key__c;
            }
            delete [
                SELECT Id FROM Contact
                WHERE Booking_Opportunity__c = :o.Id AND Booking_Form_Key__c != null AND Booking_Form_Key__c NOT IN :keep
            ];
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.WARN, 'Booking form contacts not synced for ' + o.Id + ': ' + e.getMessage());
        }
    }

    private static Contact bookingContact(Opportunity o, Boolean businessAccount, String role, String slot, String fullName) {
        String name = String.isBlank(fullName) ? role : fullName.trim();
        Integer split = name.lastIndexOf(' ');
        Contact c = new Contact(
            Booking_Form_Key__c = o.Id + ':' + (String.isBlank(slot) ? role : slot),
            FirstName = split > 0 ? name.substring(0, split).left(40) : null,
            LastName = (split > 0 ? name.substring(split + 1) : name).left(80),
            Booking_Role__c = role,
            Customer_Account__c = o.AccountId,
            Booking_Opportunity__c = o.Id,
            OwnerId = o.OwnerId
        );
        if (businessAccount) {
            c.AccountId = o.AccountId;
        }
        return c;
    }

    private static String left(String value, Integer size) {
        return value == null ? null : value.left(size);
    }

    private static Account findOrCreatePerson(Map<String, Object> ap, Id ownerId) {
        String pan = str(ap, 'pan');
        if (String.isNotBlank(pan)) {
            List<Account> found = [
                SELECT Id, IsPersonAccount, PersonContactId FROM Account
                WHERE PAN_Number__c = :pan.toUpperCase() AND IsPersonAccount = true LIMIT 1
            ];
            if (!found.isEmpty()) {
                updatePerson(found[0].Id, ap, false);
                return found[0];
            }
        }
        Account a = new Account(OwnerId = ownerId);
        Schema.RecordTypeInfo rt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount');
        if (rt != null) {
            a.put('RecordTypeId', rt.getRecordTypeId());
        }
        setName(a, str(ap, 'fullLegalName'));
        setPersonFields(a, ap, true);
        try {
            insert a;
        } catch (DmlException e) {
            // Retry without the address if the state or country does not match the org's picklists.
            clearAddress(a);
            insert a;
        }
        return [SELECT Id, IsPersonAccount, PersonContactId FROM Account WHERE Id = :a.Id];
    }

    private static void updatePerson(Id accountId, Map<String, Object> ap, Boolean includeName) {
        Account a = new Account(Id = accountId);
        if (includeName) {
            setName(a, str(ap, 'fullLegalName'));
        }
        setPersonFields(a, ap, true);
        try {
            update a;
        } catch (DmlException e) {
            clearAddress(a);
            update a;
        }
    }

    private static void setName(Account a, String fullName) {
        String name = String.isBlank(fullName) ? 'Applicant' : fullName.trim();
        Integer split = name.lastIndexOf(' ');
        a.put('FirstName', split > 0 ? name.substring(0, split) : null);
        a.put('LastName', split > 0 ? name.substring(split + 1) : name);
    }

    private static void setPersonFields(Account a, Map<String, Object> ap, Boolean withAddress) {
        String salutation = SALUTATIONS.get(str(ap, 'salutation'));
        if (salutation != null) {
            a.put('Salutation', salutation);
        }
        if (String.isNotBlank(str(ap, 'email'))) a.put('PersonEmail', str(ap, 'email'));
        if (String.isNotBlank(str(ap, 'mobile'))) a.put('PersonMobilePhone', str(ap, 'mobile'));
        if (String.isNotBlank(str(ap, 'pan'))) a.PAN_Number__c = str(ap, 'pan').toUpperCase();
        Date dob = toDate(str(ap, 'dob'));
        if (dob != null) a.put('PersonBirthdate', dob);
        Map<String, Object> addr = (Map<String, Object>) ap.get('address');
        if (withAddress && addr != null && String.isNotBlank(str(addr, 'line1'))) {
            List<String> street = new List<String>();
            for (String k : new List<String>{ 'line1', 'line2', 'landmark', 'locality' }) {
                if (String.isNotBlank(str(addr, k))) {
                    street.add(str(addr, k));
                }
            }
            a.put('PersonMailingStreet', String.join(street, ', '));
            a.put('PersonMailingCity', str(addr, 'city'));
            a.put('PersonMailingPostalCode', str(addr, 'pincode'));
            a.put('PersonMailingState', str(addr, 'state'));
            a.put('PersonMailingCountry', str(addr, 'country'));
        }
    }

    private static void clearAddress(Account a) {
        for (String f : new List<String>{ 'PersonMailingStreet', 'PersonMailingCity', 'PersonMailingPostalCode', 'PersonMailingState', 'PersonMailingCountry' }) {
            a.put(f, null);
        }
    }

    private static void syncContactRoles(Id oppId, Map<Id, String> roles) {
        Map<Id, OpportunityContactRole> existing = new Map<Id, OpportunityContactRole>();
        List<OpportunityContactRole> stale = new List<OpportunityContactRole>();
        for (OpportunityContactRole r : [SELECT Id, ContactId, Role FROM OpportunityContactRole WHERE OpportunityId = :oppId]) {
            if (roles.containsKey(r.ContactId)) {
                existing.put(r.ContactId, r);
            } else if (r.Role == 'Co-Applicant') {
                // A co-applicant removed from the form is removed from the deal.
                stale.add(r);
            }
        }
        List<OpportunityContactRole> upserts = new List<OpportunityContactRole>();
        for (Id contactId : roles.keySet()) {
            OpportunityContactRole r = existing.containsKey(contactId)
                ? existing.get(contactId)
                : new OpportunityContactRole(OpportunityId = oppId, ContactId = contactId);
            r.Role = roles.get(contactId);
            r.IsPrimary = r.Role == 'Primary Applicant';
            upserts.add(r);
        }
        upsert upserts;
        delete stale;
    }

    private static void linkCoApplicantsToBooking(Id oppId, List<Id> accountIds) {
        List<Booking__c> bookings = [
            SELECT Id FROM Booking__c WHERE Opportunity_Id__c = :oppId AND Status__c != 'Cancelled'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (bookings.isEmpty()) {
            return;
        }
        Booking__c b = bookings[0];
        for (Integer i = 0; i < 5; i++) {
            b.put('Co_Applicant_' + (i + 1) + '__c', i < accountIds.size() ? accountIds[i] : null);
        }
        update b;
    }

    public static void notifyOwner(Opportunity o, String subject, String body) {
        try {
            insert new Task(
                OwnerId = o.OwnerId,
                WhatId = o.Id,
                Subject = subject,
                Description = body,
                ActivityDate = Date.today().addDays(1),
                Priority = 'High',
                Status = 'Not Started'
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Booking form task not created: ' + e.getMessage());
        }
    }

    // ---------- Helpers ----------

    public static String str(Map<String, Object> m, String key) {
        Object v = m == null ? null : m.get(key);
        return v == null ? null : String.valueOf(v);
    }

    public static Date toDate(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Date.valueOf(value.left(10));
        } catch (Exception e) {
            return null;
        }
    }

    private static String digits(String phone) {
        if (String.isBlank(phone)) {
            return null;
        }
        String d = phone.replaceAll('[^0-9]', '');
        return d.length() > 10 ? d.right(10) : d;
    }

    public static AuraHandledException auraError(Exception e) {
        AuraHandledException ex = new AuraHandledException(e.getMessage());
        ex.setMessage(e.getMessage());
        return ex;
    }
}