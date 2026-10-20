/**
 * Deducts a paid EOI from the amount the customer still owes once their booking exists.
 *
 * The EOI is recorded the way the booking flow records the token (UnitSelectionQuoteController /
 * CustomerLedgerController): one approved Payment_Receipt__c per unpaid instalment, each under a
 * Demand__c, with the instalment's Amount_Paid__c raised by the same amount. The agreement value is
 * not changed. The token instalment is skipped, so the token is still collected in full.
 *
 * EOI receipts are approved straight away: the money was already verified when the voucher payment
 * was recorded. Approval sends the receipt to SAP like any other approved receipt.
 *
 * Runs as a Queueable from EoiBookingTrigger, because the booking flow creates the instalments
 * after the booking row is inserted. Also used by EoiVoucherController.convertToBooking.
 */
public without sharing class EoiBookingAdjustment implements Queueable {

    public static final Set<String> ADJUSTABLE = new Set<String>{ EoiVoucherController.PAID, EoiVoucherController.ALLOTTED };

    // Voucher payment modes mapped onto the receipt's restricted Mode_Of_Payment__c picklist.
    private static final Map<String, String> RECEIPT_MODES = new Map<String, String>{
        'UPI' => 'Net Banking',
        'Net Banking' => 'Net Banking',
        'Credit/Debit Card' => 'Net Banking',
        'NEFT/RTGS' => 'RTGS',
        'Cheque' => 'Cheque',
        'Demand Draft' => 'Demand Draft'
    };

    private final Set<Id> bookingIds;

    public EoiBookingAdjustment(Set<Id> bookingIds) {
        this.bookingIds = bookingIds;
    }

    public void execute(QueueableContext ctx) {
        for (Booking__c b : loadBookings(bookingIds)) {
            for (Voucher__c v : adjustableVouchers(b)) {
                try {
                    apply(v, b);
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'EOI ' + v.Name + ' not adjusted against ' + b.Name + ': ' + e.getMessage());
                }
            }
        }
    }

    /** Called from EoiBookingTrigger (after insert). Queues the adjustment only when a paid EOI could apply. */
    public static void enqueueFor(List<Booking__c> bookings) {
        Set<Id> opps = new Set<Id>();
        Set<Id> accounts = new Set<Id>();
        Set<Id> ids = new Set<Id>();
        for (Booking__c b : bookings) {
            if (b.Status__c == 'Cancelled') {
                continue;
            }
            if (b.Opportunity_Id__c != null) opps.add(b.Opportunity_Id__c);
            if (b.Account_Id__c != null) accounts.add(b.Account_Id__c);
            ids.add(b.Id);
        }
        if (ids.isEmpty()) {
            return;
        }
        Integer candidates = [
            SELECT COUNT() FROM Voucher__c
            WHERE Status__c IN :ADJUSTABLE AND Booking__c = null AND Amount_Paid__c > 0
              AND (Opportunity__c IN :opps OR (Opportunity__c = null AND Account__c IN :accounts))
        ];
        if (candidates == 0 || Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            return;
        }
        System.enqueueJob(new EoiBookingAdjustment(ids));
    }

    /** Paid EOIs that belong to this booking: same opportunity, or same customer and project if never linked to one. */
    public static List<Voucher__c> adjustableVouchers(Booking__c b) {
        List<Voucher__c> result = new List<Voucher__c>();
        for (Voucher__c v : [
            SELECT Id, Name, Status__c, Amount_Paid__c, Payment_Mode__c, Payment_Reference__c, Payment_Date__c,
                Opportunity__c, Account__c, Project__c, Flat_No__c, Remarks__c
            FROM Voucher__c
            WHERE Status__c IN :ADJUSTABLE AND Booking__c = null AND Amount_Paid__c > 0
              AND (Opportunity__c = :b.Opportunity_Id__c OR (Opportunity__c = null AND Account__c = :b.Account_Id__c))
            ORDER BY Payment_Date__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            Boolean sameOpp = b.Opportunity_Id__c != null && v.Opportunity__c == b.Opportunity_Id__c;
            Boolean sameCustomer = v.Opportunity__c == null && b.Account_Id__c != null && v.Account__c == b.Account_Id__c
                && v.Project__c != null && v.Project__c == b.Project__c;
            if (sameOpp || sameCustomer) {
                result.add(v);
            }
        }
        return result;
    }

    /**
     * Records the voucher's paid amount against the booking's unpaid instalments and marks the voucher
     * Converted to Booking. Returns the receipts created; empty (and the voucher left as it was) when the
     * booking has no unpaid instalment yet.
     */
    public static List<Payment_Receipt__c> apply(Voucher__c v, Booking__c b) {
        List<Payment_Receipt__c> receipts = new List<Payment_Receipt__c>();
        Decimal left = nz(v.Amount_Paid__c);
        if (left <= 0) {
            return receipts;
        }

        List<Booking_Payment_Schedule__c> open = new List<Booking_Payment_Schedule__c>();
        for (Booking_Payment_Schedule__c s : [
            SELECT Id, Installment_Amount__c, Amount_Paid__c, Payment_Status__c, Is_Token_Amount__c, Mode_Of_Payment__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :b.Id
            ORDER BY Payment_Due_Date__c ASC NULLS LAST, Installment_Number__c ASC NULLS LAST, CreatedDate ASC
        ]) {
            if (s.Is_Token_Amount__c != true && s.Payment_Status__c != 'Paid' && nz(s.Installment_Amount__c) - nz(s.Amount_Paid__c) > 0) {
                open.add(s);
            }
        }
        if (open.isEmpty()) {
            return receipts;
        }

        Map<Id, Decimal> allocation = new Map<Id, Decimal>();
        for (Booking_Payment_Schedule__c s : open) {
            if (left <= 0) {
                break;
            }
            Decimal take = Math.min(left, nz(s.Installment_Amount__c) - nz(s.Amount_Paid__c));
            allocation.put(s.Id, take);
            left -= take;
        }

        Map<Id, Id> demandBySchedule = new Map<Id, Id>();
        for (Demand__c d : [
            SELECT Id, Booking_Payment_Schedule_Id__c FROM Demand__c
            WHERE Booking_Payment_Schedule_Id__c IN :allocation.keySet() ORDER BY CreatedDate DESC
        ]) {
            if (!demandBySchedule.containsKey(d.Booking_Payment_Schedule_Id__c)) {
                demandBySchedule.put(d.Booking_Payment_Schedule_Id__c, d.Id);
            }
        }
        Id accountId = b.Account_Id__c != null ? b.Account_Id__c : v.Account__c;
        List<Demand__c> newDemands = new List<Demand__c>();
        for (Booking_Payment_Schedule__c s : open) {
            if (allocation.containsKey(s.Id) && !demandBySchedule.containsKey(s.Id)) {
                Boolean covers = nz(s.Amount_Paid__c) + allocation.get(s.Id) >= nz(s.Installment_Amount__c);
                newDemands.add(new Demand__c(
                    Booking_Id__c = b.Id,
                    Booking_Payment_Schedule_Id__c = s.Id,
                    Account__c = accountId,
                    Unit__c = b.Unit_Id__c,
                    Base_Amount__c = s.Installment_Amount__c,
                    Status__c = covers ? 'Paid' : 'Partially Paid'
                ));
            }
        }
        insert newDemands;
        for (Demand__c d : newDemands) {
            demandBySchedule.put(d.Booking_Payment_Schedule_Id__c, d.Id);
        }

        Date paidOn = v.Payment_Date__c != null && v.Payment_Date__c <= Date.today() ? v.Payment_Date__c : Date.today();
        String mode = RECEIPT_MODES.containsKey(v.Payment_Mode__c) ? RECEIPT_MODES.get(v.Payment_Mode__c) : 'Net Banking';
        String reference = ('EOI ' + v.Name + (String.isNotBlank(v.Payment_Reference__c) ? ' ' + v.Payment_Reference__c : '')).left(30);
        for (Booking_Payment_Schedule__c s : open) {
            if (!allocation.containsKey(s.Id)) {
                continue;
            }
            // Principal stays 0 like the booking flow's token receipt; the instalment is settled through Amount_Paid__c.
            receipts.add(new Payment_Receipt__c(
                Demand__c = demandBySchedule.get(s.Id),
                Booking_Payment_Schedule__c = s.Id,
                Account__c = accountId,
                Amount_Paid__c = allocation.get(s.Id),
                Principal_Applied__c = 0,
                Interest_Applied__c = 0,
                Tax_on_Interest__c = 0,
                Mode_Of_Payment__c = mode,
                Transaction_Reference__c = reference,
                Date_Of_Payment__c = paidOn,
                Instrument_Date__c = paidOn,
                Type__c = 'Installment',
                Approval_Status__c = 'Pending Approval'
            ));
        }
        insert receipts;

        // Receipts can't be inserted as Approved (validation rule), so approve them in a second step.
        List<Payment_Receipt__c> approvals = new List<Payment_Receipt__c>();
        for (Payment_Receipt__c r : receipts) {
            approvals.add(new Payment_Receipt__c(Id = r.Id, Approval_Status__c = 'Approved'));
        }
        update approvals;

        List<Booking_Payment_Schedule__c> paid = new List<Booking_Payment_Schedule__c>();
        for (Booking_Payment_Schedule__c s : open) {
            if (!allocation.containsKey(s.Id)) {
                continue;
            }
            Decimal newPaid = nz(s.Amount_Paid__c) + allocation.get(s.Id);
            Booking_Payment_Schedule__c upd = new Booking_Payment_Schedule__c(Id = s.Id, Amount_Paid__c = newPaid);
            if (newPaid >= nz(s.Installment_Amount__c)) {
                upd.Payment_Status__c = 'Paid';
                // A Paid instalment needs a mode (Cheque / RTGS / Net Banking); a cheque also needs its number.
                if (String.isBlank(s.Mode_Of_Payment__c)) {
                    if (mode == 'Cheque' && String.isNotBlank(v.Payment_Reference__c)) {
                        upd.Mode_Of_Payment__c = 'Cheque';
                        upd.Cheque_No__c = v.Payment_Reference__c.left(20);
                    } else {
                        upd.Mode_Of_Payment__c = mode == 'RTGS' ? 'RTGS' : 'Net Banking';
                    }
                }
            }
            paid.add(upd);
        }
        update paid;

        List<String> names = new List<String>();
        for (Payment_Receipt__c r : [SELECT Name FROM Payment_Receipt__c WHERE Id IN :receipts ORDER BY Name]) {
            names.add(r.Name);
        }
        Decimal applied = nz(v.Amount_Paid__c) - left;
        String note = Datetime.now().format('dd MMM yyyy') + ': ₹' + applied.setScale(0).format() + ' adjusted against '
            + b.Name + ' (' + String.join(names, ', ') + ').';
        if (left > 0) {
            note += ' ₹' + left.setScale(0).format() + ' could not be applied: no unpaid instalment left.';
        }
        v.Booking__c = b.Id;
        v.Status__c = EoiVoucherController.CONVERTED;
        if (b.Unit_Id__c != null) v.Flat_No__c = b.Unit_Id__c;
        if (v.Opportunity__c == null) v.Opportunity__c = b.Opportunity_Id__c;
        if (v.Account__c == null) v.Account__c = b.Account_Id__c;
        v.Remarks__c = String.isBlank(v.Remarks__c) ? note : v.Remarks__c + '\n' + note;
        update v;
        return receipts;
    }

    public static List<Booking__c> loadBookings(Set<Id> ids) {
        return [
            SELECT Id, Name, Status__c, Account_Id__c, Opportunity_Id__c, Unit_Id__c, Project__c
            FROM Booking__c WHERE Id IN :ids AND Status__c != 'Cancelled'
        ];
    }

    private static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }
}
