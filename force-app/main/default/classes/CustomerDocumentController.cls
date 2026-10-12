/**
 * Customer documents (Welcome Letter, Allotment Letter, Car Parking Letter) for a booking,
 * rendered by the CustomerDocumentPdf page in the "Customer Document Generator" design.
 *
 * Values are exposed as `v` keyed by the template's merge-field names (PROJECT_NAME, UNIT_NUMBER, ...),
 * already formatted for print: dates as dd MMM yyyy, money as INR with Indian digit grouping,
 * and blanks as an em dash.
 *
 * Without sharing, like the other Nikoo Homes document and booking classes in this org.
 */
public without sharing class CustomerDocumentController {

    public static final String DASH = '—';

    // Company and signatory details are not stored on any record in this org; edit them here.
    @TestVisible
    static final Map<String, String> COMPANY = new Map<String, String>{
        'COMPANY_NAME' => 'WarpDrive Tech Works',
        'COMPANY_ADDRESS' => '',
        'COMPANY_PHONE' => '',
        'COMPANY_EMAIL' => '',
        'COMPANY_WEBSITE' => '',
        'AUTHORIZED_SIGNATORY_NAME' => '',
        'AUTHORIZED_SIGNATORY_DESIGNATION' => 'Authorised Signatory',
        // Supplied by the developer's legal team. When blank, the clause that cites it is worded without it.
        'REGISTRATION_DETAILS' => '',
        'LEGAL_REFERENCE' => '',
        'AGREEMENT_REFERENCE' => ''
    };

    public static final Map<String, String> DOC_NAMES = new Map<String, String>{
        'welcome' => 'Welcome Letter',
        'allotment' => 'Allotment Letter',
        'parking' => 'Car Parking Letter'
    };

    public static final Map<String, String> FILE_PREFIX = new Map<String, String>{
        'welcome' => 'Welcome-Letter',
        'allotment' => 'Allotment-Letter',
        'parking' => 'Car-Parking-Letter'
    };

    public String doc { get; private set; }
    public Map<String, String> v { get; private set; }
    public Boolean found { get; private set; }
    public Boolean hasCoApplicant { get; private set; }
    public Boolean parkingApplicable { get; private set; }
    public Boolean hasContactLine { get; private set; }

    // Clauses whose wording depends on project / legal content.
    public String clauseGoverning { get; private set; }
    public String clauseProjectTerms { get; private set; }
    public String clauseLaw { get; private set; }
    public String clauseParkingTerms { get; private set; }
    public String clauseParkingLaw { get; private set; }

    public Boolean isWelcome { get { return doc == 'welcome'; } }
    public Boolean isAllotment { get { return doc == 'allotment'; } }
    public Boolean isParking { get { return doc == 'parking'; } }

    public CustomerDocumentController() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        doc = DOC_NAMES.containsKey(params.get('doc')) ? params.get('doc') : 'welcome';
        Id bookingId;
        try {
            bookingId = Id.valueOf(params.get('id'));
        } catch (Exception e) {
            bookingId = null;
        }
        Booking__c b = bookingId == null ? null : loadBooking(bookingId);
        init(b, b == null ? null : loadContext(b));
        if (found) {
            ApexPages.currentPage().getHeaders().put('Content-Disposition',
                'inline; filename="' + FILE_PREFIX.get(doc) + '_' + b.Name + '.pdf"');
        }
    }

    /** Related data the letters read besides the booking itself. */
    public class Context {
        public List<Booking_Payment_Schedule__c> schedules = new List<Booking_Payment_Schedule__c>();
        public List<Payment_Receipt__c> receipts = new List<Payment_Receipt__c>();
        public List<Opportunity_Parking__c> parkings = new List<Opportunity_Parking__c>();
        public User owner;
    }

    @TestVisible
    void init(Booking__c b, Context ctx) {
        v = new Map<String, String>();
        found = b != null;
        hasCoApplicant = false;
        parkingApplicable = false;
        for (String k : COMPANY.keySet()) {
            v.put(k, txt(COMPANY.get(k)));
        }
        hasContactLine = String.isNotBlank(COMPANY.get('COMPANY_PHONE')) || String.isNotBlank(COMPANY.get('COMPANY_EMAIL'));
        if (found) {
            populate(b, ctx);
        }
        buildClauses();
    }

    // ---------- data ----------

    static Booking__c loadBooking(Id bookingId) {
        List<Booking__c> rows = [
            SELECT Id, Name, OwnerId, Booking_Date__c, Token_Amount__c, SFDC_booking_reference_no__c, Opportunity_Id__c,
                   Total_Installment_Amount__c, Payment_Plan_Id__r.Name,
                   Account_Id__r.Name, Account_Id__r.PersonEmail, Account_Id__r.PersonMobilePhone, Account_Id__r.Phone,
                   Account_Id__r.BillingStreet, Account_Id__r.BillingCity, Account_Id__r.BillingState, Account_Id__r.BillingPostalCode,
                   Co_Applicant_1__r.Name, Co_Applicant_2__r.Name,
                   Project__r.Name, Project__r.Address__c,
                   Unit_Id__r.Name, Unit_Id__r.BHK_Configuration__c, Unit_Id__r.Carpet_Area__c, Unit_Id__r.Deck_Balcony__c,
                   Unit_Id__r.Saleable_Area__c, Unit_Id__r.Floor__r.Name, Unit_Id__r.Tower__r.Name, Unit_Id__r.Tower__r.RERA_Number__c,
                   Unit_Id__r.Property__r.Name, Unit_Id__r.Property__r.Address__c,
                   Opportunity_Id__r.Base_Cost__c, Opportunity_Id__r.BaseCostAfterDiscount__c,
                   Opportunity_Id__r.OtherCharges__c, Opportunity_Id__r.Total_Amount__c
            FROM Booking__c
            WHERE Id = :bookingId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    static Context loadContext(Booking__c b) {
        Context ctx = new Context();
        ctx.schedules = [
            SELECT Id, Installment_Number__c, Installment_Amount__c, Payment_Due_Date__c, Outstanding_Principal__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :b.Id
            ORDER BY Payment_Due_Date__c ASC NULLS LAST, Installment_Number__c ASC
        ];
        ctx.receipts = [
            SELECT Id, Amount_Paid__c, Booking_Payment_Schedule__c
            FROM Payment_Receipt__c
            WHERE Booking_Payment_Schedule__r.Booking__c = :b.Id AND Approval_Status__c = 'Approved'
        ];
        Id oppId = b.Opportunity_Id__c;
        ctx.parkings = oppId == null
            ? [SELECT Id, Name, Parking_Type__c, Type__c, Basement_Level__c, Parking_Count__c, Status__c
               FROM Opportunity_Parking__c WHERE Booking__c = :b.Id ORDER BY Name]
            : [SELECT Id, Name, Parking_Type__c, Type__c, Basement_Level__c, Parking_Count__c, Status__c
               FROM Opportunity_Parking__c WHERE Booking__c = :b.Id OR Opportunity__c = :oppId ORDER BY Name];
        if (b.OwnerId != null && b.OwnerId.getSObjectType() == User.SObjectType) {
            List<User> owners = [SELECT Name, Email, Phone, MobilePhone FROM User WHERE Id = :b.OwnerId];
            ctx.owner = owners.isEmpty() ? null : owners[0];
        }
        return ctx;
    }

    void populate(Booking__c b, Context ctx) {
        Account a = b.Account_Id__r;
        Unit__c u = b.Unit_Id__r;
        Opportunity o = b.Opportunity_Id__r;

        // Customer
        String primary = a?.Name;
        List<String> coNames = new List<String>();
        for (Account co : new List<Account>{ b.Co_Applicant_1__r, b.Co_Applicant_2__r }) {
            if (co != null && String.isNotBlank(co.Name)) {
                coNames.add(co.Name);
            }
        }
        hasCoApplicant = !coNames.isEmpty();
        v.put('PRIMARY_APPLICANT_NAME', txt(primary));
        v.put('CO_APPLICANT_NAME', txt(String.join(coNames, ', ')));
        v.put('CUSTOMER_NAME', txt(primary));
        List<String> applicants = new List<String>();
        if (String.isNotBlank(primary)) {
            applicants.add(primary);
        }
        applicants.addAll(coNames);
        v.put('APPLICANTS', applicants.isEmpty() ? 'the Allottee(s)' : joinAnd(applicants));
        v.put('CUSTOMER_PHONE', txt(a == null ? null : firstNonBlank(a.PersonMobilePhone, a.Phone)));
        v.put('CUSTOMER_EMAIL', txt(a?.PersonEmail));
        v.put('CUSTOMER_ADDRESS', a == null ? DASH
            : txt(joinNonBlank(new List<String>{ a.BillingStreet, a.BillingCity, a.BillingState, a.BillingPostalCode }, ', ')));

        // Project and unit
        String projectName = b.Project__r?.Name != null ? b.Project__r.Name : u?.Property__r?.Name;
        String projectAddress = b.Project__r?.Address__c != null ? b.Project__r.Address__c : u?.Property__r?.Address__c;
        v.put('PROJECT_NAME', txt(projectName));
        v.put('PROJECT_ADDRESS', txt(projectAddress));
        v.put('TOWER', txt(u?.Tower__r?.Name));
        v.put('TOWER_BLOCK', txt(u?.Tower__r?.Name));
        v.put('UNIT_NUMBER', txt(u?.Name));
        v.put('FLOOR', txt(u?.Floor__r?.Name));
        v.put('CONFIGURATION', txt(u?.BHK_Configuration__c));
        v.put('CARPET_AREA', area(u?.Carpet_Area__c));
        v.put('BALCONY_AREA', area(u?.Deck_Balcony__c));
        v.put('SALEABLE_AREA', area(u?.Saleable_Area__c));
        v.put('PROJECT_RERA_NUMBER', txt(u?.Tower__r?.RERA_Number__c));

        // Booking
        v.put('LETTER_DATE', fmtDate(Date.today()));
        v.put('BOOKING_ID', b.Name);
        v.put('BOOKING_DATE', fmtDate(b.Booking_Date__c));
        v.put('APPLICATION_NUMBER', txt(b.SFDC_booking_reference_no__c));

        // Financials: the opportunity's pricing formulas; taxes are whatever the total carries on top.
        Decimal total = o?.Total_Amount__c;
        Decimal basic, other, taxes;
        if (total != null && total > 0) {
            basic = nz(o.BaseCostAfterDiscount__c) > 0 ? o.BaseCostAfterDiscount__c : nz(o.Base_Cost__c);
            other = nz(o.OtherCharges__c);
            taxes = total - basic - other;
        } else if (nz(b.Total_Installment_Amount__c) > 0) {
            // No pricing on the opportunity: fall back to the payment schedule total.
            basic = b.Total_Installment_Amount__c;
            total = basic;
        }
        Decimal paid = 0;
        Map<Id, Decimal> paidBySchedule = new Map<Id, Decimal>();
        for (Payment_Receipt__c r : ctx.receipts) {
            Decimal amt = nz(r.Amount_Paid__c);
            paid += amt;
            if (r.Booking_Payment_Schedule__c != null) {
                paidBySchedule.put(r.Booking_Payment_Schedule__c, nz(paidBySchedule.get(r.Booking_Payment_Schedule__c)) + amt);
            }
        }
        Decimal agreement = basic == null ? null : basic + nz(other);
        v.put('BASIC_SALE_CONSIDERATION', inr(basic));
        v.put('OTHER_CHARGES', inr(other));
        v.put('TAXES', inr(taxes));
        v.put('AGREEMENT_VALUE', inr(agreement));
        v.put('TOTAL_CONSIDERATION', inr(total));
        v.put('BOOKING_AMOUNT', inr(b.Token_Amount__c));
        v.put('AMOUNT_PAID', inr(paid));
        v.put('OUTSTANDING_AMOUNT', inr(agreement == null ? null : agreement - paid));
        v.put('BALANCE_AMOUNT', inr(total == null ? null : total - paid));
        v.put('PAYMENT_PLAN', txt(b.Payment_Plan_Id__r?.Name));

        // Next instalment: the earliest one not yet covered by the ledger or by approved receipts tagged to it.
        Booking_Payment_Schedule__c next;
        Decimal nextAmount;
        for (Booking_Payment_Schedule__c s : ctx.schedules) {
            Decimal due = nz(s.Installment_Amount__c);
            Decimal outstanding = due - nz(paidBySchedule.get(s.Id));
            if (s.Outstanding_Principal__c != null) {
                outstanding = Math.min(outstanding, s.Outstanding_Principal__c);
            }
            if (outstanding > 0) {
                next = s;
                nextAmount = outstanding;
                break;
            }
        }
        v.put('NEXT_PAYMENT_DATE', next == null ? DASH : fmtDate(next.Payment_Due_Date__c));
        v.put('NEXT_PAYMENT_AMOUNT', inr(nextAmount));

        // Parking
        parkingApplicable = !ctx.parkings.isEmpty();
        Set<String> types = new Set<String>(), levels = new Set<String>();
        List<String> slots = new List<String>();
        Decimal count = 0;
        for (Opportunity_Parking__c p : ctx.parkings) {
            String t = firstNonBlank(p.Parking_Type__c, p.Type__c);
            if (String.isNotBlank(t)) {
                types.add(t);
            }
            if (String.isNotBlank(p.Basement_Level__c)) {
                levels.add(p.Basement_Level__c);
            }
            slots.add(p.Name);
            count += p.Parking_Count__c != null && p.Parking_Count__c > 0 ? p.Parking_Count__c : 1;
        }
        v.put('PARKING_TYPE', txt(String.join(new List<String>(types), ', ')));
        v.put('PARKING_SLOT_NUMBER', txt(String.join(slots, ', ')));
        v.put('PARKING_LEVEL', txt(String.join(new List<String>(levels), ', ')));
        v.put('PARKING_COUNT', parkingApplicable ? String.valueOf(count.setScale(0)) : DASH);

        // Relationship manager: the booking owner.
        User rm = ctx.owner;
        v.put('RM_NAME', txt(rm?.Name));
        v.put('RM_PHONE', txt(rm == null ? null : firstNonBlank(rm.MobilePhone, rm.Phone)));
        v.put('RM_EMAIL', txt(rm?.Email));
    }

    void buildClauses() {
        String project = v.containsKey('PROJECT_NAME') ? v.get('PROJECT_NAME') : 'the Project';
        String agreementRef = COMPANY.get('AGREEMENT_REFERENCE');
        String registration = COMPANY.get('REGISTRATION_DETAILS');
        String legalRef = COMPANY.get('LEGAL_REFERENCE');

        clauseGoverning = 'The allotment is subject to the booking and application documents'
            + (String.isBlank(agreementRef) ? '' : ' and to ' + agreementRef)
            + '. The Agreement for Sale and any other contractual documentation applicable to the Project will be executed'
            + ' in the form and within the time communicated by the Company.';
        clauseProjectTerms = 'This allotment is subject to the terms applicable to ' + project
            + (String.isBlank(registration) ? '' : ', including those recorded under ' + registration) + '.';
        clauseLaw = 'This letter shall be read in accordance with the laws and regulations applicable to the Project'
            + (String.isBlank(legalRef) ? '' : ', including ' + legalRef) + '. It is not legal advice.';
        clauseParkingTerms = String.isBlank(agreementRef)
            ? 'The parking is subject to the project terms and contractual documentation applicable to ' + project + '.'
            : 'Applicable project terms and contractual documentation include ' + agreementRef + '.';
        clauseParkingLaw = 'This letter shall be read with the laws and regulations applicable to the Project'
            + (String.isBlank(legalRef) ? '' : ', including ' + legalRef) + '.';
    }

    // ---------- quick action ----------

    public class DocOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean available;
        @AuraEnabled public String note;
    }

    public class Overview {
        @AuraEnabled public String bookingName;
        @AuraEnabled public String customerName;
        @AuraEnabled public List<DocOption> documents = new List<DocOption>();
    }

    @AuraEnabled
    public static Overview getOverview(Id bookingId) {
        try {
            Booking__c b = loadBooking(bookingId);
            if (b == null) {
                throw new DocumentException('Booking not found.');
            }
            Integer parkingCount = [
                SELECT COUNT() FROM Opportunity_Parking__c
                WHERE Booking__c = :b.Id OR (Opportunity__c != null AND Opportunity__c = :b.Opportunity_Id__c)
            ];
            Overview o = new Overview();
            o.bookingName = b.Name;
            o.customerName = b.Account_Id__r?.Name;
            for (String key : DOC_NAMES.keySet()) {
                DocOption d = new DocOption();
                d.value = key;
                d.label = DOC_NAMES.get(key);
                d.available = key != 'parking' || parkingCount > 0;
                d.note = d.available ? null : 'No parking is allotted to this booking.';
                o.documents.add(d);
            }
            return o;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    /** Renders the document as a PDF and files it on the booking. Returns the ContentDocumentId. */
    @AuraEnabled
    public static Id saveToFiles(Id bookingId, String doc) {
        try {
            if (!DOC_NAMES.containsKey(doc)) {
                throw new DocumentException('Unknown document: ' + doc);
            }
            Booking__c b = loadBooking(bookingId);
            if (b == null) {
                throw new DocumentException('Booking not found.');
            }
            PageReference pr = Page.CustomerDocumentPdf;
            pr.getParameters().put('id', bookingId);
            pr.getParameters().put('doc', doc);
            Blob pdf = Test.isRunningTest() ? Blob.valueOf('test') : pr.getContentAsPDF();
            String stamp = Datetime.now().format('dd MMM yyyy');
            ContentVersion cv = new ContentVersion(
                Title = DOC_NAMES.get(doc) + ' - ' + b.Name + ' - ' + stamp,
                PathOnClient = FILE_PREFIX.get(doc) + '_' + b.Name + '.pdf',
                VersionData = pdf,
                FirstPublishLocationId = bookingId
            );
            insert cv;
            return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    public class DocumentException extends Exception {}

    static AuraHandledException auraError(Exception e) {
        AuraHandledException ex = new AuraHandledException(e.getMessage());
        ex.setMessage(e.getMessage());
        return ex;
    }

    // ---------- formatting ----------

    @TestVisible
    static String txt(String s) {
        return String.isBlank(s) ? DASH : s.trim();
    }

    static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }

    static String firstNonBlank(String a, String b) {
        return String.isNotBlank(a) ? a : b;
    }

    static String joinNonBlank(List<String> parts, String sep) {
        List<String> keep = new List<String>();
        for (String p : parts) {
            if (String.isNotBlank(p)) {
                keep.add(p.trim());
            }
        }
        return String.join(keep, sep);
    }

    @TestVisible
    static String joinAnd(List<String> names) {
        if (names.size() == 1) {
            return names[0];
        }
        List<String> head = new List<String>(names);
        String last = head.remove(head.size() - 1);
        return String.join(head, ', ') + ' and ' + last;
    }

    @TestVisible
    static String fmtDate(Date d) {
        return d == null ? DASH : Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('dd MMM yyyy');
    }

    @TestVisible
    static String area(Decimal d) {
        return d == null || d == 0 ? DASH : indian(d.setScale(0, RoundingMode.HALF_UP)) + ' sq.ft.';
    }

    /** INR with Indian digit grouping, e.g. INR 1,24,50,000. Paise are shown only when present. */
    @TestVisible
    static String inr(Decimal d) {
        if (d == null) {
            return DASH;
        }
        Decimal r = d.setScale(2, RoundingMode.HALF_UP);
        Boolean neg = r < 0;
        Decimal absVal = r.abs();
        Decimal whole = absVal.setScale(0, RoundingMode.DOWN);
        Integer paise = ((absVal - whole) * 100).intValue();
        String s = indian(whole) + (paise == 0 ? '' : '.' + String.valueOf(paise).leftPad(2, '0'));
        return (neg ? '- ' : '') + 'INR ' + s;
    }

    static String indian(Decimal whole) {
        String digits = String.valueOf(whole.longValue());
        if (digits.length() <= 3) {
            return digits;
        }
        String last3 = digits.right(3);
        String rest = digits.left(digits.length() - 3);
        // Lakh and crore groups of two digits ahead of the last three.
        String grouped = '';
        while (rest.length() > 2) {
            grouped = ',' + rest.right(2) + grouped;
            rest = rest.left(rest.length() - 2);
        }
        return rest + grouped + ',' + last3;
    }
}