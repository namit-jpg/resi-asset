/**
 * Internal side of the customer booking form: the "Booking Form" action on the Opportunity.
 * Generates the opportunity's unique link, shares it, shows what the customer has filled in
 * and reopens a submitted form for corrections.
 */
public with sharing class BookingFormLinkController {

    public class LinkStatus {
        @AuraEnabled public String url;
        @AuraEnabled public String status;
        @AuraEnabled public String step;
        @AuraEnabled public Datetime generatedAt;
        @AuraEnabled public Date expiresOn;
        @AuraEnabled public Boolean expired = false;
        @AuraEnabled public Datetime lastSavedAt;
        @AuraEnabled public Datetime submittedAt;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerEmail;
        @AuraEnabled public String customerMobile;
        @AuraEnabled public String unit;
        @AuraEnabled public String project;
        @AuraEnabled public Decimal tokenAmount;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public String paymentReference;
        @AuraEnabled public List<Map<String, Object>> applicants = new List<Map<String, Object>>();
        @AuraEnabled public Integer documentsUploaded = 0;
        @AuraEnabled public String nominee;
        @AuraEnabled public String siteError;
    }

    @AuraEnabled
    public static LinkStatus getStatus(Id opportunityId) {
        try {
            Opportunity o = load(opportunityId);
            LinkStatus s = new LinkStatus();
            s.url = o.Booking_Form_URL__c;
            s.status = o.Booking_Form_Status__c;
            s.step = o.Booking_Form_Step__c;
            s.generatedAt = o.Booking_Form_Generated_At__c;
            s.expiresOn = o.Booking_Form_Expires_On__c;
            s.expired = o.Booking_Form_Expires_On__c != null && o.Booking_Form_Expires_On__c < Date.today()
                && o.Booking_Form_Status__c != BookingFormService.STATUS_SUBMITTED;
            s.lastSavedAt = o.Booking_Form_Last_Saved_At__c;
            s.submittedAt = o.Booking_Form_Submitted_At__c;
            s.customerName = o.Account?.Name;
            s.customerEmail = o.Account?.PersonEmail;
            s.customerMobile = String.isNotBlank(o.Account?.PersonMobilePhone) ? o.Account.PersonMobilePhone : o.Account?.Phone;
            s.unit = o.Interested_Unit__r?.Name;
            s.project = o.Interested_Unit__r?.Property__r?.Name;
            s.tokenAmount = o.Token_Amount__c;
            s.paymentStatus = String.isBlank(o.Token_Payment_Status__c) ? 'Pending' : o.Token_Payment_Status__c;
            s.paymentReference = o.Token_Payment_Reference__c;
            if (String.isNotBlank(o.Booking_Form_Data__c)) {
                summarise(s, (Map<String, Object>) JSON.deserializeUntyped(o.Booking_Form_Data__c));
            }
            if (siteBaseUrl() == null) {
                s.siteError = 'The "' + BookingFormService.SITE_NAME + '" site is not live, so links cannot be generated yet.';
            }
            return s;
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    /** Creates the opportunity's link, or replaces it (the old link stops working). */
    @AuraEnabled
    public static LinkStatus generateLink(Id opportunityId) {
        try {
            Opportunity o = load(opportunityId);
            if (o.Booking_Form_Status__c == BookingFormService.STATUS_SUBMITTED) {
                throw new BookingFormService.BookingFormException('The customer has already submitted this form. Reopen it to let them make changes.');
            }
            if (o.Interested_Unit__c == null) {
                throw new BookingFormService.BookingFormException('Tag a unit on this opportunity before generating the booking form link.');
            }
            String base = siteBaseUrl();
            if (base == null) {
                throw new BookingFormService.BookingFormException('The "' + BookingFormService.SITE_NAME + '" site is not live yet.');
            }
            String token = BookingFormService.newToken();
            saveWithRetry(new Opportunity(
                Id = o.Id,
                Booking_Form_Token__c = token,
                Booking_Form_URL__c = base + '/?t=' + token,
                Booking_Form_Status__c = String.isBlank(o.Booking_Form_Data__c)
                    ? BookingFormService.STATUS_GENERATED
                    : (o.Booking_Form_Status__c == BookingFormService.STATUS_REOPENED ? BookingFormService.STATUS_REOPENED : BookingFormService.STATUS_IN_PROGRESS),
                Booking_Form_Generated_At__c = Datetime.now(),
                Booking_Form_Expires_On__c = Date.today().addDays(BookingFormService.LINK_VALIDITY_DAYS)
            ));
            return getStatus(opportunityId);
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    /** Lets the customer (or sales, through the same link) correct a submitted form. */
    @AuraEnabled
    public static LinkStatus reopen(Id opportunityId) {
        try {
            Opportunity o = load(opportunityId);
            if (o.Booking_Form_Status__c != BookingFormService.STATUS_SUBMITTED) {
                throw new BookingFormService.BookingFormException('Only a submitted form can be reopened.');
            }
            Opportunity upd = new Opportunity(Id = o.Id, Booking_Form_Status__c = BookingFormService.STATUS_REOPENED);
            if (o.Booking_Form_Expires_On__c == null || o.Booking_Form_Expires_On__c < Date.today()) {
                upd.Booking_Form_Expires_On__c = Date.today().addDays(BookingFormService.LINK_VALIDITY_DAYS);
            }
            if (String.isNotBlank(o.Booking_Form_Data__c)) {
                // Send the customer back to the signing step; signatures must be given again on the corrected form.
                Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(o.Booking_Form_Data__c);
                data.put('step', 'details');
                for (Object item : (List<Object>) data.get('applicants')) {
                    ((Map<String, Object>) item).remove('signature');
                }
                upd.Booking_Form_Data__c = JSON.serialize(data);
                upd.Booking_Form_Step__c = 'details';
            }
            saveWithRetry(upd);
            return getStatus(opportunityId);
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    @AuraEnabled
    public static String emailLink(Id opportunityId) {
        try {
            Opportunity o = load(opportunityId);
            if (String.isBlank(o.Booking_Form_URL__c)) {
                throw new BookingFormService.BookingFormException('Generate the link first.');
            }
            if (String.isBlank(o.Account?.PersonEmail)) {
                throw new BookingFormService.BookingFormException('The customer has no email address on their account.');
            }
            Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
            m.setToAddresses(new List<String>{ o.Account.PersonEmail });
            if (o.Account.PersonContactId != null) {
                m.setTargetObjectId(o.Account.PersonContactId);
                m.setTreatTargetObjectAsRecipient(false);
                m.setWhatId(o.Id);
                m.setSaveAsActivity(true);
            }
            m.setSubject('Complete your booking for ' + o.Interested_Unit__r?.Name + ', ' + o.Interested_Unit__r?.Property__r?.Name);
            m.setPlainTextBody(shareMessage(o) + '\n\nRegards,\n' + UserInfo.getName() + '\n' + BookingFormService.DEVELOPER);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ m });
            return o.Account.PersonEmail;
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    /** Text for WhatsApp and email. */
    @AuraEnabled
    public static String getShareMessage(Id opportunityId) {
        try {
            return shareMessage(load(opportunityId));
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    private static String shareMessage(Opportunity o) {
        String first = String.isNotBlank(o.Account?.FirstName) ? o.Account.FirstName : o.Account?.Name;
        return 'Dear ' + first + ',\n\nPlease complete the booking form for unit ' + o.Interested_Unit__r?.Name
            + ' at ' + o.Interested_Unit__r?.Property__r?.Name + ' using this secure link:\n' + o.Booking_Form_URL__c
            + '\n\nThe link is personal to you and is valid until '
            + (o.Booking_Form_Expires_On__c == null ? '' : Datetime.newInstance(o.Booking_Form_Expires_On__c, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy'))
            + '. You can save and come back to it at any time.';
    }

    private static void summarise(LinkStatus s, Map<String, Object> data) {
        List<Object> applicants = (List<Object>) data.get('applicants');
        if (applicants != null) {
            for (Object item : applicants) {
                Map<String, Object> ap = (Map<String, Object>) item;
                Map<String, Object> sig = (Map<String, Object>) ap.get('signature');
                Map<String, Object> docs = (Map<String, Object>) ap.get('documents');
                Integer uploaded = 0;
                if (docs != null) {
                    for (Object d : docs.values()) {
                        if (BookingFormService.str((Map<String, Object>) d, 'contentVersionId') != null) {
                            uploaded++;
                        }
                    }
                }
                s.documentsUploaded += uploaded;
                s.applicants.add(new Map<String, Object>{
                    'name' => BookingFormService.str(ap, 'fullLegalName'),
                    'role' => BookingFormService.str(ap, 'role') == 'PRIMARY' ? 'Primary applicant' : 'Co-applicant',
                    'pan' => BookingFormService.str(ap, 'pan'),
                    'mobile' => BookingFormService.str(ap, 'mobile'),
                    'documents' => uploaded,
                    'signed' => sig != null && sig.get('signedAt') != null
                });
            }
        }
        Map<String, Object> nominee = (Map<String, Object>) data.get('nominee');
        if (nominee != null && nominee.get('provided') == true) {
            s.nominee = BookingFormService.str(nominee, 'fullName') + ' · ' + BookingFormService.str(nominee, 'relationship')
                + ' · ' + BookingFormService.str(nominee, 'sharePct') + '%';
        }
    }

    /**
     * Saving the opportunity locks the customer's account, which a unit change or SAP sync on the
     * same customer can hold for a few seconds. Retry, then explain instead of showing UNABLE_TO_LOCK_ROW.
     */
    private static void saveWithRetry(Opportunity record) {
        for (Integer attempt = 1; ; attempt++) {
            try {
                update record;
                return;
            } catch (DmlException ex) {
                if (ex.getDmlType(0) != StatusCode.UNABLE_TO_LOCK_ROW) {
                    throw ex;
                }
                if (attempt == 3) {
                    throw new BookingFormService.BookingFormException(
                        'This customer\'s records are being updated by another process (for example the SAP sync). Wait a few seconds and try again.'
                    );
                }
            }
        }
    }

    private static Opportunity load(Id opportunityId) {
        return [
            SELECT Id, Name, AccountId, Account.Name, Account.FirstName, Account.PersonEmail, Account.PersonMobilePhone,
                Account.Phone, Account.PersonContactId, Interested_Unit__c, Interested_Unit__r.Name,
                Interested_Unit__r.Property__r.Name, Token_Amount__c,
                Booking_Form_URL__c, Booking_Form_Status__c, Booking_Form_Step__c, Booking_Form_Data__c,
                Booking_Form_Generated_At__c, Booking_Form_Expires_On__c, Booking_Form_Last_Saved_At__c,
                Booking_Form_Submitted_At__c, Token_Payment_Status__c, Token_Payment_Reference__c
            FROM Opportunity WHERE Id = :opportunityId
        ];
    }

    @TestVisible
    private static String testBaseUrl;

    /** https://<domain>/booking for the live booking site. */
    @TestVisible
    private static String siteBaseUrl() {
        if (Test.isRunningTest() && testBaseUrl != null) {
            return testBaseUrl;
        }
        List<Network> sites = [SELECT Id FROM Network WHERE Name = :BookingFormService.SITE_NAME AND Status = 'Live' LIMIT 1];
        if (sites.isEmpty()) {
            return null;
        }
        String login = Network.getLoginUrl(sites[0].Id);
        return login == null ? null : login.removeEnd('/').removeEnd('/login').removeEnd('/s');
    }
}