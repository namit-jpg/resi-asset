/**
 * Called by bookingCustomerForm on the public "Nikoo Homes Booking" site (guest user).
 * Access is scoped by the link token: every method resolves the opportunity from it.
 */
public without sharing class BookingFormSiteController {

    private static final Integer MAX_FILE_BYTES = 3 * 1024 * 1024;
    private static final Set<String> FILE_TYPES = new Set<String>{ 'pdf', 'jpg', 'jpeg', 'png' };

    @AuraEnabled
    public static Map<String, Object> load(String token) {
        try {
            Opportunity o = BookingFormService.resolve(token);
            Map<String, Object> data = String.isBlank(o.Booking_Form_Data__c)
                ? BookingFormService.prefill(o)
                : (Map<String, Object>) JSON.deserializeUntyped(o.Booking_Form_Data__c);
            return new Map<String, Object>{
                'context' => BookingFormService.context(o),
                'data' => data,
                'payment' => BookingFormService.paymentState(o),
                'status' => o.Booking_Form_Status__c,
                'locked' => BookingFormService.isLocked(o),
                'submittedAt' => o.Booking_Form_Submitted_At__c,
                'expiresOn' => o.Booking_Form_Expires_On__c
            };
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    @AuraEnabled
    public static Datetime saveDraft(String token, String payload) {
        try {
            Opportunity o = BookingFormService.resolve(token);
            BookingFormService.requireEditable(o);
            Map<String, Object> data = parse(payload);
            Datetime now = Datetime.now();
            update new Opportunity(
                Id = o.Id,
                Booking_Form_Data__c = payload,
                Booking_Form_Step__c = BookingFormService.str(data, 'step'),
                Booking_Form_Status__c = o.Booking_Form_Status__c == BookingFormService.STATUS_REOPENED
                    ? BookingFormService.STATUS_REOPENED
                    : BookingFormService.STATUS_IN_PROGRESS,
                Booking_Form_Last_Saved_At__c = now
            );
            return now;
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    /** Files a KYC document on the opportunity. The browser sends the file as base64. */
    @AuraEnabled
    public static Map<String, Object> uploadDocument(String token, String applicantName, String documentLabel, String fileName, String base64Data) {
        try {
            Opportunity o = BookingFormService.resolve(token);
            BookingFormService.requireEditable(o);
            if (String.isBlank(fileName) || String.isBlank(base64Data)) {
                throw new BookingFormService.BookingFormException('Choose a file to upload.');
            }
            String ext = fileName.contains('.') ? fileName.substringAfterLast('.').toLowerCase() : '';
            if (!FILE_TYPES.contains(ext)) {
                throw new BookingFormService.BookingFormException('Upload a PDF, JPG or PNG file.');
            }
            Blob body = EncodingUtil.base64Decode(base64Data);
            if (body.size() > MAX_FILE_BYTES) {
                throw new BookingFormService.BookingFormException('Choose a file smaller than 3 MB.');
            }
            String title = (String.isBlank(applicantName) ? 'Applicant' : applicantName) + ' · ' + documentLabel;
            ContentVersion cv = new ContentVersion(
                Title = title.left(255),
                PathOnClient = fileName,
                VersionData = body,
                FirstPublishLocationId = o.Id,
                OwnerId = o.OwnerId,
                Description = 'Uploaded by the customer through the booking form.'
            );
            insert cv;
            return new Map<String, Object>{
                'contentVersionId' => cv.Id,
                'fileName' => fileName,
                'size' => body.size(),
                'uploadedAt' => Datetime.now()
            };
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    /**
     * Simulated payment gateway. outcome is success | failed | cancelled, chosen in the test checkout.
     * Replace with the real gateway's order + signature verification before go-live.
     */
    @AuraEnabled
    public static Map<String, Object> recordPayment(String token, String method, String outcome) {
        try {
            Opportunity o = BookingFormService.resolve(token);
            BookingFormService.requireEditable(o);
            if (o.Token_Payment_Status__c == 'Paid') {
                return BookingFormService.paymentState(o);
            }
            if (o.Token_Amount__c == null || o.Token_Amount__c <= 0) {
                throw new BookingFormService.BookingFormException('The booking amount has not been set yet. Please contact your relationship manager.');
            }
            Opportunity upd = new Opportunity(Id = o.Id, Token_Payment_Mode__c = method);
            if (outcome == 'success') {
                upd.Token_Payment_Status__c = 'Paid';
                upd.Token_Amount_Paid__c = o.Token_Amount__c;
                upd.Token_Payment_Reference__c = 'pay_' + BookingFormService.newToken().left(14);
                upd.Token_Paid_At__c = Datetime.now();
            } else if (outcome == 'failed') {
                upd.Token_Payment_Status__c = 'Failed';
            }
            update upd;
            if (outcome == 'success') {
                BookingFormService.notifyOwner(o, 'Token advance received: ' + o.Name,
                    'The customer paid the token advance through the booking form. Payment ID ' + upd.Token_Payment_Reference__c + '.');
            }
            return BookingFormService.paymentState(BookingFormService.resolve(token));
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    @AuraEnabled
    public static Map<String, Object> submit(String token, String payload) {
        try {
            Opportunity o = BookingFormService.resolve(token);
            BookingFormService.requireEditable(o);
            Map<String, Object> data = parse(payload);
            validateForSubmit(o, data);

            Datetime now = Datetime.now();
            data.put('step', 'confirmation');
            data.put('submittedAt', now);
            update new Opportunity(
                Id = o.Id,
                Booking_Form_Data__c = JSON.serialize(data),
                Booking_Form_Step__c = 'confirmation',
                Booking_Form_Status__c = BookingFormService.STATUS_SUBMITTED,
                Booking_Form_Submitted_At__c = now,
                Booking_Form_Last_Saved_At__c = now
            );
            BookingFormService.apply(o, data);
            BookingFormService.notifyOwner(o, 'Review submitted booking form: ' + o.Name,
                'The customer submitted the booking form. Check the applicant details and KYC documents on the opportunity, '
                + 'then reopen the form from the Booking Form action if anything needs correcting.');
            return new Map<String, Object>{ 'submittedAt' => now, 'status' => BookingFormService.STATUS_SUBMITTED };
        } catch (Exception e) {
            throw BookingFormService.auraError(e);
        }
    }

    private static void validateForSubmit(Opportunity o, Map<String, Object> data) {
        List<Object> applicants = (List<Object>) data.get('applicants');
        if (applicants == null || applicants.isEmpty()) {
            throw new BookingFormService.BookingFormException('Add the applicant details before submitting.');
        }
        for (Object item : applicants) {
            Map<String, Object> ap = (Map<String, Object>) item;
            if (String.isBlank(BookingFormService.str(ap, 'fullLegalName')) || String.isBlank(BookingFormService.str(ap, 'pan'))) {
                throw new BookingFormService.BookingFormException('Every applicant needs a name and PAN before submitting.');
            }
            Map<String, Object> sig = (Map<String, Object>) ap.get('signature');
            if (sig == null || String.isBlank(BookingFormService.str(sig, 'signedAt'))) {
                throw new BookingFormService.BookingFormException(BookingFormService.str(ap, 'fullLegalName') + ' has not signed yet.');
            }
        }
        Map<String, Object> declarations = (Map<String, Object>) data.get('declarations');
        for (String d : new List<String>{ 'accurate', 'bookingTerms', 'paymentTerms', 'cancellation', 'privacy', 'electronic' }) {
            if (declarations == null || declarations.get(d) != true) {
                throw new BookingFormService.BookingFormException('Accept every declaration before submitting.');
            }
        }
        if (o.Token_Payment_Status__c != 'Paid') {
            throw new BookingFormService.BookingFormException('Pay the token advance before submitting.');
        }
    }

    private static Map<String, Object> parse(String payload) {
        if (String.isBlank(payload)) {
            throw new BookingFormService.BookingFormException('There is nothing to save yet.');
        }
        if (payload.length() > 131072) {
            throw new BookingFormService.BookingFormException('The form is too large to save. Remove a co-applicant or contact your relationship manager.');
        }
        return (Map<String, Object>) JSON.deserializeUntyped(payload);
    }
}