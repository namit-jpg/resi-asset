/**
 * EOI (Expression of Interest) voucher management on Voucher__c.
 * Lifecycle: Payment Pending -> Paid -> Allotted -> Converted to Booking.
 * A voucher is Cancelled if it is never paid, and Refunded if the customer walks away after paying.
 * Used by the Lead quick action (eoiGenerateVoucher) and the voucher quick actions (eoiVoucherStep).
 */
public with sharing class EoiVoucherController {

    public static final String PAYMENT_PENDING = 'Payment Pending';
    public static final String PAID = 'Paid';
    public static final String ALLOTTED = 'Allotted';
    public static final String CONVERTED = 'Converted to Booking';
    public static final String CANCELLED = 'Cancelled';
    public static final String REFUNDED = 'Refunded';

    public static final Set<String> OPEN_STATUSES = new Set<String>{ PAYMENT_PENDING, PAID, ALLOTTED };

    // Default EOI amount per voucher type; sales can override it on the form.
    public static final Map<String, Decimal> DEFAULT_AMOUNTS = new Map<String, Decimal>{
        'Standard EOI' => 100000,
        'Priority EOI' => 250000
    };
    public static final Integer DEFAULT_VALIDITY_DAYS = 30;

    private static final Set<String> CLOSED_LEAD_STATUSES = new Set<String>{ 'Dropped', 'Archive' };

    // ---------- Generate (Lead) ----------

    public class LeadContext {
        @AuraEnabled public Id leadId;
        @AuraEnabled public String name;
        @AuraEnabled public String mobile;
        @AuraEnabled public String email;
        @AuraEnabled public String project;
        @AuraEnabled public Id projectId;
        @AuraEnabled public String configuration;
        @AuraEnabled public String channelPartner;
        @AuraEnabled public Date validUntil;
        @AuraEnabled public Map<String, Decimal> amounts;
        @AuraEnabled public Boolean canGenerate = true;
        @AuraEnabled public String blockReason;
        @AuraEnabled public List<VoucherSummary> vouchers = new List<VoucherSummary>();
    }

    public class VoucherSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String project;
        @AuraEnabled public Decimal amount;

        VoucherSummary(Voucher__c v) {
            id = v.Id;
            name = v.Name;
            status = v.Status__c;
            project = v.Project__r?.Name;
            amount = v.Amount__c;
        }
    }

    @AuraEnabled
    public static LeadContext getLeadContext(Id leadId) {
        try {
            Lead l = loadLead(leadId);
            LeadContext ctx = new LeadContext();
            ctx.leadId = l.Id;
            ctx.name = l.Name;
            ctx.mobile = String.isNotBlank(l.MobilePhone) ? l.MobilePhone : l.Phone;
            ctx.email = l.Email;
            ctx.project = l.Projects__c;
            ctx.projectId = projectIdFor(l.Projects__c);
            ctx.configuration = l.Type_of_Units__c;
            ctx.channelPartner = l.Approved_Channel_Partner__r?.Name;
            ctx.validUntil = Date.today().addDays(DEFAULT_VALIDITY_DAYS);
            ctx.amounts = DEFAULT_AMOUNTS;

            for (Voucher__c v : [
                SELECT Id, Name, Status__c, Project__r.Name, Amount__c
                FROM Voucher__c WHERE Lead__c = :leadId ORDER BY CreatedDate DESC
            ]) {
                ctx.vouchers.add(new VoucherSummary(v));
            }

            String reason = generateBlocker(l, ctx.projectId, ctx.vouchers);
            ctx.canGenerate = reason == null;
            ctx.blockReason = reason;
            return ctx;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    @AuraEnabled
    public static Id generateVoucher(Id leadId, String voucherType, Decimal amount, String configuration, Date validUntil, String remarks) {
        try {
            Lead l = loadLead(leadId);
            Id projectId = projectIdFor(l.Projects__c);
            List<VoucherSummary> existing = new List<VoucherSummary>();
            for (Voucher__c v : [SELECT Id, Name, Status__c, Project__r.Name, Amount__c FROM Voucher__c WHERE Lead__c = :leadId]) {
                existing.add(new VoucherSummary(v));
            }
            String reason = generateBlocker(l, projectId, existing);
            if (reason != null) {
                throw new EoiException(reason);
            }
            if (!DEFAULT_AMOUNTS.containsKey(voucherType)) {
                throw new EoiException('Choose a voucher type.');
            }
            if (amount == null || amount <= 0) {
                throw new EoiException('Enter an EOI amount greater than zero.');
            }
            if (validUntil != null && validUntil < Date.today()) {
                throw new EoiException('Valid until can\'t be in the past.');
            }

            Voucher__c v = new Voucher__c(
                Lead__c = l.Id,
                Opportunity__c = l.ConvertedOpportunityId,
                Account__c = l.ConvertedAccountId,
                Project__c = projectId,
                Channel_Partner__c = l.Approved_Channel_Partner__c,
                Applicable_To__c = 'Customer',
                Voucher_Type__c = voucherType,
                Amount__c = amount,
                Amount_Paid__c = 0,
                Preferred_Configuration__c = String.isNotBlank(configuration) ? configuration : l.Type_of_Units__c,
                Applicant_Name__c = l.Name,
                Applicant_Mobile__c = String.isNotBlank(l.MobilePhone) ? l.MobilePhone : l.Phone,
                Applicant_Email__c = l.Email,
                Valid_Until__c = validUntil != null ? validUntil : Date.today().addDays(DEFAULT_VALIDITY_DAYS),
                Status__c = PAYMENT_PENDING,
                Remarks__c = remarks
            );
            insert v;
            return v.Id;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    private static String generateBlocker(Lead l, Id projectId, List<VoucherSummary> vouchers) {
        if (CLOSED_LEAD_STATUSES.contains(l.Status)) {
            return 'This lead is ' + l.Status.toLowerCase() + '. Reopen it before raising an EOI.';
        }
        if (String.isBlank(l.Projects__c)) {
            return 'Set the project on the lead before raising an EOI.';
        }
        if (projectId == null) {
            return 'No project record matches "' + l.Projects__c + '".';
        }
        if (String.isBlank(l.MobilePhone) && String.isBlank(l.Phone)) {
            return 'Add the customer\'s mobile number to the lead first.';
        }
        for (VoucherSummary v : vouchers) {
            if (OPEN_STATUSES.contains(v.status) && v.project == l.Projects__c) {
                return v.name + ' is already open for ' + l.Projects__c + ' (' + v.status + ').';
            }
        }
        return null;
    }

    // ---------- Voucher steps ----------

    public class VoucherContext {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String voucherType;
        @AuraEnabled public String applicant;
        @AuraEnabled public String project;
        @AuraEnabled public Id projectId;
        @AuraEnabled public String configuration;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal amountPaid;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public Decimal priorityNumber;
        @AuraEnabled public Date validUntil;
        @AuraEnabled public Boolean expired;
        @AuraEnabled public Boolean refundable;
        @AuraEnabled public String unit;
        @AuraEnabled public String booking;
        @AuraEnabled public List<Option> units = new List<Option>();
        @AuraEnabled public List<Option> bookings = new List<Option>();
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String detail;

        Option(String label, String value, String detail) {
            this.label = label;
            this.value = value;
            this.detail = detail;
        }
    }

    /** mode: payment | allot | convert | close. Only the options that mode needs are loaded. */
    @AuraEnabled
    public static VoucherContext getVoucher(Id voucherId, String mode) {
        try {
            Voucher__c v = loadVoucher(voucherId);
            VoucherContext ctx = new VoucherContext();
            ctx.id = v.Id;
            ctx.name = v.Name;
            ctx.status = v.Status__c;
            ctx.voucherType = v.Voucher_Type__c;
            ctx.applicant = v.Applicant_Name__c;
            ctx.project = v.Project__r?.Name;
            ctx.projectId = v.Project__c;
            ctx.configuration = v.Preferred_Configuration__c;
            ctx.amount = v.Amount__c;
            ctx.amountPaid = v.Amount_Paid__c == null ? 0 : v.Amount_Paid__c;
            ctx.balance = v.Balance_Due__c;
            ctx.priorityNumber = v.Priority_Number__c;
            ctx.validUntil = v.Valid_Until__c;
            ctx.expired = v.Valid_Until__c != null && v.Valid_Until__c < Date.today();
            ctx.refundable = v.Refundable__c;
            ctx.unit = v.Flat_No__r?.Name;
            ctx.booking = v.Booking__r?.Name;
            if (mode == 'allot' && v.Project__c != null) {
                ctx.units = availableUnits(v);
            } else if (mode == 'convert') {
                ctx.bookings = candidateBookings(v);
            }
            return ctx;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    @AuraEnabled
    public static void recordPayment(Id voucherId, Decimal amount, String mode, String reference, Date paidOn) {
        try {
            Voucher__c v = loadVoucher(voucherId);
            requireStatus(v, new Set<String>{ PAYMENT_PENDING }, 'Payment can only be recorded while the voucher is awaiting payment.');
            if (amount == null || amount <= 0) {
                throw new EoiException('Enter the amount received.');
            }
            if (String.isBlank(mode)) {
                throw new EoiException('Choose how the customer paid.');
            }
            if (String.isBlank(reference)) {
                throw new EoiException('Enter the transaction or cheque reference.');
            }
            if (paidOn != null && paidOn > Date.today()) {
                throw new EoiException('Payment date can\'t be in the future.');
            }
            Decimal totalPaid = (v.Amount_Paid__c == null ? 0 : v.Amount_Paid__c) + amount;
            if (totalPaid > v.Amount__c) {
                throw new EoiException('That is more than the balance due on this voucher.');
            }
            v.Amount_Paid__c = totalPaid;
            v.Payment_Mode__c = mode;
            v.Payment_Reference__c = reference;
            v.Payment_Date__c = paidOn != null ? paidOn : Date.today();
            // Fully paid vouchers join the project queue in the order payment lands.
            if (totalPaid == v.Amount__c) {
                v.Status__c = PAID;
                v.Priority_Number__c = nextPriority(v.Project__c);
            }
            update v;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    @AuraEnabled
    public static void allotUnit(Id voucherId, Id unitId) {
        try {
            Voucher__c v = loadVoucher(voucherId);
            requireStatus(v, new Set<String>{ PAID, ALLOTTED }, 'A unit can be allotted only after the EOI is paid in full.');
            if (unitId == null) {
                throw new EoiException('Choose a unit to allot.');
            }
            Unit__c u = [SELECT Id, Status__c, Property__c FROM Unit__c WHERE Id = :unitId];
            if (u.Property__c != v.Project__c) {
                throw new EoiException('That unit is not in ' + v.Project__r?.Name + '.');
            }
            if (u.Status__c != 'Available' && u.Id != v.Flat_No__c) {
                throw new EoiException('That unit is no longer available.');
            }
            Integer taken = [
                SELECT COUNT() FROM Voucher__c
                WHERE Flat_No__c = :unitId AND Id != :voucherId AND Status__c IN :OPEN_STATUSES
            ];
            if (taken > 0) {
                throw new EoiException('That unit is already allotted to another EOI.');
            }
            v.Flat_No__c = unitId;
            v.Status__c = ALLOTTED;
            update v;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    @AuraEnabled
    public static void convertToBooking(Id voucherId, Id bookingId) {
        try {
            Voucher__c v = loadVoucher(voucherId);
            requireStatus(v, new Set<String>{ PAID, ALLOTTED }, 'Only a paid EOI can be adjusted against a booking.');
            if (bookingId == null) {
                throw new EoiException('Choose the booking to adjust this EOI against.');
            }
            Booking__c b = [SELECT Id, Unit_Id__c, Account_Id__c, Opportunity_Id__c FROM Booking__c WHERE Id = :bookingId];
            Integer used = [SELECT COUNT() FROM Voucher__c WHERE Booking__c = :bookingId AND Id != :voucherId AND Status__c = :CONVERTED];
            if (used > 0) {
                throw new EoiException('Another EOI has already been adjusted against that booking.');
            }
            v.Booking__c = b.Id;
            v.Status__c = CONVERTED;
            if (b.Unit_Id__c != null) {
                v.Flat_No__c = b.Unit_Id__c;
            }
            if (v.Account__c == null) {
                v.Account__c = b.Account_Id__c;
            }
            if (v.Opportunity__c == null) {
                v.Opportunity__c = b.Opportunity_Id__c;
            }
            update v;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    /** Cancels an unpaid voucher, or refunds a paid one. */
    @AuraEnabled
    public static void closeVoucher(Id voucherId, String reason, Decimal refundAmount, String refundReference, Date refundedOn) {
        try {
            Voucher__c v = loadVoucher(voucherId);
            requireStatus(v, OPEN_STATUSES, 'This voucher is already ' + String.valueOf(v.Status__c).toLowerCase() + '.');
            if (String.isBlank(reason)) {
                throw new EoiException('Give a reason.');
            }
            v.Cancellation_Reason__c = reason.left(255);
            Decimal received = v.Amount_Paid__c == null ? 0 : v.Amount_Paid__c;
            if (received == 0) {
                v.Status__c = CANCELLED;
            } else {
                if (refundAmount == null || refundAmount < 0 || refundAmount > received) {
                    throw new EoiException('Refund amount must be between ₹0 and the ₹' + received.format() + ' received.');
                }
                if (String.isBlank(refundReference)) {
                    throw new EoiException('Enter the refund transaction reference.');
                }
                v.Status__c = REFUNDED;
                v.Refund_Amount__c = refundAmount;
                v.Refund_Reference__c = refundReference;
                v.Refund_Date__c = refundedOn != null ? refundedOn : Date.today();
            }
            // Free the unit so the next voucher in the queue can take it.
            v.Flat_No__c = null;
            update v;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    /** Renders the EOI voucher PDF and files it on the voucher. Called after payment, in its own transaction. */
    @AuraEnabled
    public static Id saveVoucherPdf(Id voucherId) {
        try {
            Voucher__c v = loadVoucher(voucherId);
            PageReference page = Page.EoiVoucherPdf;
            page.getParameters().put('id', voucherId);
            Blob pdf = Test.isRunningTest() ? Blob.valueOf('EOI voucher') : page.getContentAsPDF();
            ContentVersion cv = new ContentVersion(
                Title = v.Name + ' - EOI Voucher',
                PathOnClient = v.Name + '.pdf',
                VersionData = pdf,
                FirstPublishLocationId = voucherId
            );
            insert cv;
            return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    // ---------- Lead conversion ----------

    /** Carries open vouchers over to the converted account and opportunity. Called from EoiVoucherLeadTrigger. */
    public static void linkConvertedLeads(List<Lead> leads, Map<Id, Lead> oldMap) {
        Map<Id, Lead> converted = new Map<Id, Lead>();
        for (Lead l : leads) {
            if (l.IsConverted && !oldMap.get(l.Id).IsConverted) {
                converted.put(l.Id, l);
            }
        }
        if (converted.isEmpty()) {
            return;
        }
        List<Voucher__c> toUpdate = new List<Voucher__c>();
        for (Voucher__c v : [SELECT Id, Lead__c, Account__c, Opportunity__c FROM Voucher__c WHERE Lead__c IN :converted.keySet()]) {
            Lead l = converted.get(v.Lead__c);
            v.Account__c = v.Account__c != null ? v.Account__c : l.ConvertedAccountId;
            v.Opportunity__c = v.Opportunity__c != null ? v.Opportunity__c : l.ConvertedOpportunityId;
            toUpdate.add(v);
        }
        update toUpdate;
    }

    // ---------- Helpers ----------

    private static Lead loadLead(Id leadId) {
        return [
            SELECT Id, Name, Status, Phone, MobilePhone, Email, Projects__c, Type_of_Units__c,
                Approved_Channel_Partner__c, Approved_Channel_Partner__r.Name,
                ConvertedAccountId, ConvertedOpportunityId
            FROM Lead WHERE Id = :leadId
        ];
    }

    private static Voucher__c loadVoucher(Id voucherId) {
        return [
            SELECT Id, Name, Status__c, Voucher_Type__c, Applicant_Name__c, Project__c, Project__r.Name,
                Preferred_Configuration__c, Amount__c, Amount_Paid__c, Balance_Due__c, Priority_Number__c,
                Valid_Until__c, Refundable__c, Flat_No__c, Flat_No__r.Name, Booking__c, Booking__r.Name,
                Account__c, Opportunity__c, Lead__c
            FROM Voucher__c WHERE Id = :voucherId
        ];
    }

    private static Id projectIdFor(String projectName) {
        if (String.isBlank(projectName)) {
            return null;
        }
        List<Property__c> projects = [SELECT Id FROM Property__c WHERE Name = :projectName LIMIT 1];
        return projects.isEmpty() ? null : projects[0].Id;
    }

    private static void requireStatus(Voucher__c v, Set<String> allowed, String message) {
        if (!allowed.contains(v.Status__c)) {
            throw new EoiException(message);
        }
    }

    private static Integer nextPriority(Id projectId) {
        AggregateResult ar = [SELECT MAX(Priority_Number__c) n FROM Voucher__c WHERE Project__c = :projectId];
        Decimal top = (Decimal) ar.get('n');
        return top == null ? 1 : top.intValue() + 1;
    }

    private static List<Option> availableUnits(Voucher__c v) {
        Set<Id> held = new Set<Id>();
        for (Voucher__c other : [
            SELECT Flat_No__c FROM Voucher__c
            WHERE Project__c = :v.Project__c AND Flat_No__c != null AND Id != :v.Id AND Status__c IN :OPEN_STATUSES
        ]) {
            held.add(other.Flat_No__c);
        }
        List<Option> matching = new List<Option>();
        List<Option> others = new List<Option>();
        for (Unit__c u : [
            SELECT Id, Name, BHK_Configuration__c, Tower__r.Name, Floor__r.Name, Saleable_Area__c
            FROM Unit__c
            WHERE Property__c = :v.Project__c AND (Status__c = 'Available' OR Id = :v.Flat_No__c)
            ORDER BY Tower__r.Name, Name
            LIMIT 500
        ]) {
            if (held.contains(u.Id)) {
                continue;
            }
            List<String> bits = new List<String>();
            if (u.BHK_Configuration__c != null) bits.add(u.BHK_Configuration__c);
            if (u.Tower__r?.Name != null) bits.add(u.Tower__r.Name);
            if (u.Floor__r?.Name != null) bits.add(u.Floor__r.Name);
            if (u.Saleable_Area__c != null) bits.add(u.Saleable_Area__c.format() + ' sq ft');
            Option o = new Option(u.Name, u.Id, String.join(bits, ' · '));
            if (matchesConfiguration(v.Preferred_Configuration__c, u.BHK_Configuration__c)) {
                matching.add(o);
            } else {
                others.add(o);
            }
        }
        // Units that match the customer's preference come first.
        matching.addAll(others);
        return matching;
    }

    /** Bookings in the voucher's project, the customer's own (same account, opportunity or unit) first. */
    private static List<Option> candidateBookings(Voucher__c v) {
        List<Option> mine = new List<Option>();
        List<Option> others = new List<Option>();
        for (Booking__c b : [
            SELECT Id, Name, Account_Id__c, Account_Id__r.Name, Opportunity_Id__c, Unit_Id__c, Unit_Id__r.Name, Status__c
            FROM Booking__c
            WHERE Project__c = :v.Project__c AND Status__c != 'Cancelled'
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            List<String> bits = new List<String>();
            if (b.Account_Id__r?.Name != null) bits.add(b.Account_Id__r.Name);
            if (b.Unit_Id__r?.Name != null) bits.add(b.Unit_Id__r.Name);
            if (b.Status__c != null) bits.add(b.Status__c);
            Option o = new Option(b.Name, b.Id, String.join(bits, ' · '));
            Boolean isMine = (v.Account__c != null && b.Account_Id__c == v.Account__c)
                || (v.Opportunity__c != null && b.Opportunity_Id__c == v.Opportunity__c)
                || (v.Flat_No__c != null && b.Unit_Id__c == v.Flat_No__c);
            if (isMine) {
                mine.add(o);
            } else {
                others.add(o);
            }
        }
        mine.addAll(others);
        return mine;
    }

    @TestVisible
    private static Boolean matchesConfiguration(String preferred, String unitConfig) {
        if (String.isBlank(preferred) || String.isBlank(unitConfig)) {
            return false;
        }
        String digits = unitConfig.replaceAll('[^0-9.]', '');
        if (String.isBlank(digits) || digits == '.') {
            // Duplex and Penthouse units count as large homes.
            return preferred == 'Above 4BHK';
        }
        Decimal size = Decimal.valueOf(digits.split('\\.')[0]);
        if (preferred == 'Above 4BHK') {
            return size > 4 || unitConfig.startsWith('4.5');
        }
        return String.valueOf(size.intValue()) + 'BHK' == preferred && !unitConfig.startsWith('4.5');
    }

    // setMessage keeps the text readable in tests and in non-Aura callers.
    private static AuraHandledException auraError(Exception e) {
        AuraHandledException ex = new AuraHandledException(e.getMessage());
        ex.setMessage(e.getMessage());
        return ex;
    }

    public class EoiException extends Exception {}
}