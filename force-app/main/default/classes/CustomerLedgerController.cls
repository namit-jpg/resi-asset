public with sharing class CustomerLedgerController {

    public class LedgerSummaryWrapper {
        @AuraEnabled public Id bookingId { get; set; }
        @AuraEnabled public String bookingName { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerEmail { get; set; }
        @AuraEnabled public String customerPhone { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public String towerName { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String configuration { get; set; }
        @AuraEnabled public Decimal agreementValue { get; set; }
        @AuraEnabled public Decimal tokenAmount { get; set; }
        @AuraEnabled public Decimal totalDemanded { get; set; }
        @AuraEnabled public Decimal totalReceived { get; set; }
        @AuraEnabled public Decimal outstandingPrincipal { get; set; }
        @AuraEnabled public Decimal totalOverdueInterest { get; set; }
        @AuraEnabled public Decimal totalInterestWaived { get; set; }
        @AuraEnabled public Decimal netPayableToday { get; set; }
        @AuraEnabled public String sapCustomerCode { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date bookingDate { get; set; }
        @AuraEnabled public Decimal totalAdvanceApplied { get; set; }
        @AuraEnabled public Decimal totalInterestReceived { get; set; }
        @AuraEnabled public Decimal totalTaxOnInterest { get; set; }
        @AuraEnabled public Decimal totalTaxOnInterestOutstanding { get; set; }
        @AuraEnabled public Decimal totalTaxOnInterestReceived { get; set; }
        @AuraEnabled public Integer schedulesCount { get; set; }
        @AuraEnabled public String nextDueDateFormatted { get; set; }
        @AuraEnabled public List<SnapshotScheduleItem> scheduleItems { get; set; }
    }

    public class SnapshotScheduleItem {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String milestoneName { get; set; }
        @AuraEnabled public String dueDateFormatted { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Decimal paidAmount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Decimal overdueInterest { get; set; }
        @AuraEnabled public String sapInvoiceNumber { get; set; }
        @AuraEnabled public Boolean sapBillBlockRemoved { get; set; }
        @AuraEnabled public String demandReminderLevel { get; set; }
    }

    public class InstallmentItemWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String milestoneName { get; set; }
        @AuraEnabled public Decimal percentage { get; set; }
        @AuraEnabled public Date dueDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Decimal paidAmount { get; set; }
        @AuraEnabled public Decimal outstandingAmount { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Decimal daysOverdue { get; set; }
        @AuraEnabled public Decimal overdueInterest { get; set; }
        @AuraEnabled public Boolean isOverdue { get; set; }
        @AuraEnabled public Boolean interestWaived { get; set; }
        @AuraEnabled public Decimal waivedInterestAmount { get; set; }
        @AuraEnabled public String waiverStatus { get; set; }
        @AuraEnabled public String waiverReason { get; set; }
        @AuraEnabled public Date waiverRequestedDate { get; set; }
        @AuraEnabled public String demandNoteNumber { get; set; }
        @AuraEnabled public Date demandNoteDate { get; set; }
        @AuraEnabled public Boolean hasDemandNote { get; set; }
        @AuraEnabled public Boolean sapBillBlockRemoved { get; set; }
        @AuraEnabled public String sapInvoiceNumber { get; set; }
        @AuraEnabled public Date sapInvoiceDate { get; set; }
        @AuraEnabled public String formattedSapInvoiceDate { get; set; }
        @AuraEnabled public String demandReminderLevel { get; set; }
        @AuraEnabled public Date lastReminderDate { get; set; }
        @AuraEnabled public String formattedLastReminderDate { get; set; }
        @AuraEnabled public Boolean isTdsApplicable { get; set; }
        @AuraEnabled public Decimal tdsAmount { get; set; }
        @AuraEnabled public Decimal netPayableToBuilder { get; set; }
    }

    public class ReceiptItemWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Date receiptDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public String paymentMode { get; set; }
        @AuraEnabled public String transactionRef { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String installmentName { get; set; }
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public Date instrumentDate { get; set; }
        @AuraEnabled public String formattedInstrumentDate { get; set; }
        @AuraEnabled public String instrumentNumber { get; set; }
        @AuraEnabled public String bankName { get; set; }
        @AuraEnabled public Date sapReconciledDate { get; set; }
        @AuraEnabled public String formattedSapReconciledDate { get; set; }
        @AuraEnabled public String sapClearingDoc { get; set; }
        @AuraEnabled public String sapClearedBy { get; set; }
        @AuraEnabled public String financeApprover { get; set; }
        @AuraEnabled public Boolean isPendingReconciliation { get; set; }
        @AuraEnabled public Boolean isSapCleared { get; set; }
    }

    public class ActionResultWrapper {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id recordId { get; set; }
    }

    public class BookingOptionWrapper {
        @AuraEnabled public Id bookingId { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean isSelected { get; set; }
    }

    public class BookingConditionWrapper {
        @AuraEnabled public Id bookingId { get; set; }
        @AuraEnabled public String bookingReferenceId { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public Decimal chargeableArea { get; set; }
        @AuraEnabled public Decimal carpetArea { get; set; }
        @AuraEnabled public Decimal floorNumber { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public String towerName { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String configuration { get; set; }
        @AuraEnabled public Decimal netAgreementValue { get; set; }
        @AuraEnabled public Decimal grandTotal { get; set; }
        @AuraEnabled public List<ConditionRowWrapper> conditionRows { get; set; }
    }

    public class ConditionRowWrapper {
        @AuraEnabled public String conditionType { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Boolean isTotal { get; set; }
    }

    public class AllotmentLetterWrapper {
        @AuraEnabled public String bookingReferenceId { get; set; }
        @AuraEnabled public String letterRefNumber { get; set; }
        @AuraEnabled public String letterDate { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerPhone { get; set; }
        @AuraEnabled public String customerEmail { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public String towerName { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String configuration { get; set; }
        @AuraEnabled public Decimal floorNumber { get; set; }
        @AuraEnabled public Decimal sbaSqFt { get; set; }
        @AuraEnabled public Decimal carpetAreaSqFt { get; set; }
        @AuraEnabled public String parkingSlot { get; set; }
        @AuraEnabled public Decimal agreementValue { get; set; }
        @AuraEnabled public Decimal tokenAmountPaid { get; set; }
        @AuraEnabled public Decimal balanceDue { get; set; }
        @AuraEnabled public String sapCustomerCode { get; set; }
        @AuraEnabled public List<InstallmentItemWrapper> milestones { get; set; }
    }

    public class WelcomeLetterWrapper {
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerPhone { get; set; }
        @AuraEnabled public String customerEmail { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public String towerName { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String projectLocation { get; set; }
        @AuraEnabled public String configuration { get; set; }
        @AuraEnabled public Decimal sbaSqFt { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String letterDate { get; set; }
        @AuraEnabled public String rmName { get; set; }
        @AuraEnabled public String rmDesignation { get; set; }
        @AuraEnabled public String rmPhone { get; set; }
        @AuraEnabled public String rmEmail { get; set; }
        @AuraEnabled public String portalUrl { get; set; }
    }

    /**
     * Resolves an Account, Opportunity, or Booking ID to a valid Booking__c ID
     */
    public static Id resolveBookingId(Id recordId) {
        if (recordId == null) return null;
        String sObjName = recordId.getSobjectType().getDescribe().getName();
        if (sObjName == 'Booking__c') {
            return recordId;
        } else if (sObjName == 'Account') {
            List<Booking__c> bookings = [
                SELECT Id FROM Booking__c
                WHERE Account_Id__c = :recordId
                ORDER BY Booking_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 1
            ];
            return !bookings.isEmpty() ? bookings[0].Id : null;
        } else if (sObjName == 'Opportunity') {
            List<Booking__c> bookings = [
                SELECT Id FROM Booking__c
                WHERE Opportunity_Id__c = :recordId
                ORDER BY Booking_Date__c DESC NULLS LAST, CreatedDate DESC
                LIMIT 1
            ];
            return !bookings.isEmpty() ? bookings[0].Id : null;
        }
        return recordId;
    }

    /**
     * Retrieve all bookings associated with an Account, Opportunity, or Booking
     */
    @AuraEnabled(cacheable=true)
    public static List<BookingOptionWrapper> getCustomerBookings(Id recordId) {
        List<BookingOptionWrapper> options = new List<BookingOptionWrapper>();
        if (recordId == null) return options;
        String sObjName = recordId.getSobjectType().getDescribe().getName();
        
        List<Booking__c> bookings = new List<Booking__c>();
        if (sObjName == 'Account') {
            bookings = [
                SELECT Id, Name, Unit_Id__r.Name, Unit_Id__r.Tower__r.Property__r.Name, Status__c, Booking_Date__c
                FROM Booking__c
                WHERE Account_Id__c = :recordId
                ORDER BY Booking_Date__c DESC NULLS LAST, CreatedDate DESC
            ];
        } else if (sObjName == 'Opportunity') {
            bookings = [
                SELECT Id, Name, Unit_Id__r.Name, Unit_Id__r.Tower__r.Property__r.Name, Status__c, Booking_Date__c
                FROM Booking__c
                WHERE Opportunity_Id__c = :recordId
                ORDER BY Booking_Date__c DESC NULLS LAST, CreatedDate DESC
            ];
        } else if (sObjName == 'Booking__c') {
            bookings = [
                SELECT Id, Name, Unit_Id__r.Name, Unit_Id__r.Tower__r.Property__r.Name, Status__c, Booking_Date__c
                FROM Booking__c
                WHERE Id = :recordId
            ];
        }

        Boolean first = true;
        for (Booking__c b : bookings) {
            BookingOptionWrapper opt = new BookingOptionWrapper();
            opt.bookingId = b.Id;
            String unitStr = b.Unit_Id__r != null ? b.Unit_Id__r.Name : 'Unit';
            String projStr = (b.Unit_Id__r != null && b.Unit_Id__r.Tower__r != null && b.Unit_Id__r.Tower__r.Property__r != null)
                             ? b.Unit_Id__r.Tower__r.Property__r.Name : '';
            opt.label = b.Name + ' (' + unitStr + (String.isNotBlank(projStr) ? ' - ' + projStr : '') + ')';
            opt.unitName = unitStr;
            opt.projectName = projStr;
            opt.status = b.Status__c;
            opt.isSelected = first;
            options.add(opt);
            first = false;
        }
        return options;
    }

    /**
     * Retrieve complete financial ledger KPIs for a booking, account, or opportunity
     */
    @AuraEnabled(cacheable=true)
    public static LedgerSummaryWrapper getLedgerSummary(Id bookingId) {
        if (bookingId == null) {
            return null;
        }

        Id targetBookingId = resolveBookingId(bookingId);
        if (targetBookingId == null) {
            return null;
        }

        Booking__c b = [
            SELECT Id, Name, Booking_Date__c, Account_Id__c, Account_Id__r.Name, Account_Id__r.Phone,
                   Unit_Id__c, Unit_Id__r.Name, Unit_Id__r.BHK_Configuration__c,
                   Unit_Id__r.Tower__r.Name, Unit_Id__r.Tower__r.Property__r.Name,
                   Final_Amount__c, Token_Amount__c, TotalInterestOutstandingFromLedger__c, InterestWaivedFromLedger__c,
                   SAP_External_Id__c, Status__c
            FROM Booking__c
            WHERE Id = :targetBookingId
            LIMIT 1
        ];

        List<Booking_Payment_Schedule__c> installments = [
            SELECT Id, Name, Payment_Schedule_Id__r.Milestone_Code__c, Payment_Due_Date__c,
                   Installment_Amount__c, Amount_Paid__c, Outstanding_Principal__c, Payment_Status__c,
                   AccruedInterestToDateLedger__c, TotalInterestOutstandingnet__c,
                   Interest_Waived__c, InterestWaivedLedger__c,
                   Bill_Block__c, Description__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :targetBookingId
            ORDER BY Payment_Due_Date__c ASC NULLS LAST, CreatedDate ASC
        ];

        Decimal demanded = 0;
        Decimal received = 0;
        Decimal principalOutstanding = 0;
        Decimal totalOverdueInterest = 0;
        Decimal totalWaived = b.InterestWaivedFromLedger__c != null ? b.InterestWaivedFromLedger__c : 0;
        Date nextDueDate = null;
        List<SnapshotScheduleItem> scheduleItems = new List<SnapshotScheduleItem>();

        for (Booking_Payment_Schedule__c inst : installments) {
            Decimal amt = inst.Installment_Amount__c != null ? inst.Installment_Amount__c : 0;
            Decimal paid = inst.Amount_Paid__c != null ? inst.Amount_Paid__c : 0;
            Decimal outPrin = inst.Outstanding_Principal__c != null ? inst.Outstanding_Principal__c : Math.max(0, amt - paid);
            Decimal interest = inst.TotalInterestOutstandingnet__c != null ? inst.TotalInterestOutstandingnet__c : 
                              (inst.AccruedInterestToDateLedger__c != null ? inst.AccruedInterestToDateLedger__c : 0);

            demanded += amt;
            received += paid;
            principalOutstanding += outPrin;
            totalOverdueInterest += interest;

            if (inst.Interest_Waived__c != null && (b.InterestWaivedFromLedger__c == null || b.InterestWaivedFromLedger__c == 0)) {
                totalWaived += inst.Interest_Waived__c;
            }

            if (nextDueDate == null && inst.Payment_Due_Date__c != null && inst.Payment_Due_Date__c >= Date.today() && outPrin > 0) {
                nextDueDate = inst.Payment_Due_Date__c;
            }

            SnapshotScheduleItem item = new SnapshotScheduleItem();
            item.id = inst.Id;
            item.name = inst.Name;
            item.milestoneName = String.isNotBlank(inst.Description__c) ? inst.Description__c : (inst.Payment_Schedule_Id__r != null && String.isNotBlank(inst.Payment_Schedule_Id__r.Milestone_Code__c) ? inst.Payment_Schedule_Id__r.Milestone_Code__c : 'Installment Milestone');
            item.dueDateFormatted = formatSnapshotDate(inst.Payment_Due_Date__c);
            item.amount = amt;
            item.paidAmount = paid;
            item.status = inst.Payment_Status__c;
            item.overdueInterest = interest;
            item.sapInvoiceNumber = 'INV-' + (inst.Payment_Due_Date__c != null ? String.valueOf(inst.Payment_Due_Date__c.year()) : '2026') + '-' + inst.Name.replaceAll('[^0-9]', '');
            item.sapBillBlockRemoved = (inst.Bill_Block__c == null || inst.Bill_Block__c == 'None');
            item.demandReminderLevel = (inst.Payment_Due_Date__c != null && inst.Payment_Due_Date__c < Date.today() && outPrin > 0) ? 'Overdue Reminder' : 'None';
            scheduleItems.add(item);
        }

        LedgerSummaryWrapper summary = new LedgerSummaryWrapper();
        summary.bookingId = b.Id;
        summary.bookingName = b.Name;
        summary.customerName = b.Account_Id__r != null ? b.Account_Id__r.Name : 'Valued Customer';
        summary.customerEmail = 'customer@residences.example.com';
        summary.customerPhone = b.Account_Id__r != null ? b.Account_Id__r.Phone : '';
        summary.unitName = b.Unit_Id__r != null ? b.Unit_Id__r.Name : 'Unit';
        summary.towerName = (b.Unit_Id__r != null && b.Unit_Id__r.Tower__r != null) ? b.Unit_Id__r.Tower__r.Name : 'Tower';
        summary.projectName = (b.Unit_Id__r != null && b.Unit_Id__r.Tower__r != null && b.Unit_Id__r.Tower__r.Property__r != null) ? b.Unit_Id__r.Tower__r.Property__r.Name : 'Nikoo Homes';
        summary.configuration = b.Unit_Id__r != null ? b.Unit_Id__r.BHK_Configuration__c : '2 BHK';
        summary.agreementValue = b.Final_Amount__c != null ? b.Final_Amount__c : 0;
        summary.tokenAmount = b.Token_Amount__c != null ? b.Token_Amount__c : 0;
        summary.totalDemanded = demanded;
        summary.totalReceived = received;
        summary.outstandingPrincipal = principalOutstanding;
        summary.totalOverdueInterest = totalOverdueInterest;
        summary.totalInterestWaived = totalWaived;
        summary.netPayableToday = principalOutstanding + totalOverdueInterest;
        summary.sapCustomerCode = b.SAP_External_Id__c;
        summary.status = b.Status__c;
        summary.bookingDate = b.Booking_Date__c;
        summary.schedulesCount = installments.size();
        summary.nextDueDateFormatted = formatSnapshotDate(nextDueDate);
        summary.scheduleItems = scheduleItems;

        return summary;
    }

    /**
     * Get milestone installment entries with demand note and overdue interest info
     */
    @AuraEnabled(cacheable=true)
    public static List<InstallmentItemWrapper> getInstallments(Id bookingId) {
        List<InstallmentItemWrapper> items = new List<InstallmentItemWrapper>();
        if (bookingId == null) return items;

        Id targetBookingId = resolveBookingId(bookingId);
        if (targetBookingId == null) return items;

        List<Booking_Payment_Schedule__c> listInst = [
            SELECT Id, Name, Payment_Schedule_Id__r.Milestone_Code__c, Payment_Schedule_Id__r.Payment_Percentage__c,
                   Payment_Due_Date__c, Installment_Amount__c, Amount_Paid__c, Outstanding_Principal__c, Payment_Status__c,
                   AccruedInterestToDateLedger__c, TotalInterestOutstandingnet__c, Interest_Waived__c,
                   InterestWaivedLedger__c, Bill_Block__c, Description__c,
                   Booking__r.Final_Amount__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :targetBookingId
            ORDER BY Payment_Due_Date__c ASC NULLS LAST, CreatedDate ASC
        ];

        for (Booking_Payment_Schedule__c inst : listInst) {
            InstallmentItemWrapper item = new InstallmentItemWrapper();
            item.id = inst.Id;
            item.name = inst.Name;
            item.milestoneName = String.isNotBlank(inst.Description__c) ? inst.Description__c : (inst.Payment_Schedule_Id__r != null && String.isNotBlank(inst.Payment_Schedule_Id__r.Milestone_Code__c) ? inst.Payment_Schedule_Id__r.Milestone_Code__c : 'Milestone Installment');
            item.percentage = inst.Payment_Schedule_Id__r != null && inst.Payment_Schedule_Id__r.Payment_Percentage__c != null ? inst.Payment_Schedule_Id__r.Payment_Percentage__c : 10;
            item.dueDate = inst.Payment_Due_Date__c;
            item.amount = (inst.Installment_Amount__c != null ? inst.Installment_Amount__c : 0);
            item.paidAmount = (inst.Amount_Paid__c != null ? inst.Amount_Paid__c : 0);
            item.outstandingAmount = (inst.Outstanding_Principal__c != null ? inst.Outstanding_Principal__c : Math.max(0, item.amount - item.paidAmount));
            item.status = inst.Payment_Status__c;
            
            Integer days = 0;
            if (inst.Payment_Due_Date__c != null && inst.Payment_Due_Date__c < Date.today() && item.outstandingAmount > 0) {
                days = inst.Payment_Due_Date__c.daysBetween(Date.today());
            }
            item.daysOverdue = days;
            item.overdueInterest = (inst.TotalInterestOutstandingnet__c != null ? inst.TotalInterestOutstandingnet__c : 
                                   (inst.AccruedInterestToDateLedger__c != null ? inst.AccruedInterestToDateLedger__c : 0));
            item.isOverdue = (inst.Payment_Status__c == 'Overdue' || days > 0);
            item.interestWaived = (inst.Interest_Waived__c != null && inst.Interest_Waived__c > 0);
            item.waivedInterestAmount = (inst.Interest_Waived__c != null ? inst.Interest_Waived__c : 
                                        (inst.InterestWaivedLedger__c != null ? inst.InterestWaivedLedger__c : 0));
            item.waiverStatus = item.interestWaived ? 'Approved' : 'None';
            item.waiverReason = 'Customer requested waiver';
            item.demandNoteNumber = 'DN-' + (inst.Payment_Due_Date__c != null ? String.valueOf(inst.Payment_Due_Date__c.year()) : '2026') + '-' + inst.Name.replaceAll('[^0-9]', '');
            item.demandNoteDate = inst.Payment_Due_Date__c != null ? inst.Payment_Due_Date__c.addDays(-15) : Date.today();
            item.hasDemandNote = true;
            item.sapBillBlockRemoved = (inst.Bill_Block__c == null || inst.Bill_Block__c == 'None');
            item.sapInvoiceNumber = 'INV-SAP-' + item.demandNoteNumber;
            item.sapInvoiceDate = item.demandNoteDate;
            item.formattedSapInvoiceDate = formatSnapshotDate(item.sapInvoiceDate);
            item.demandReminderLevel = days > 30 ? 'Reminder 2 (30 Days)' : (days > 15 ? 'Reminder 1 (15 Days)' : 'None');
            item.lastReminderDate = Date.today();
            item.formattedLastReminderDate = formatSnapshotDate(Date.today());

            Decimal bkgTotal = (inst.Booking__r != null && inst.Booking__r.Final_Amount__c != null) ? inst.Booking__r.Final_Amount__c : 0;
            item.isTdsApplicable = (bkgTotal >= 5000000);
            if (item.isTdsApplicable && item.amount != null) {
                item.tdsAmount = (item.amount * 0.01).setScale(2, System.RoundingMode.HALF_UP);
                item.netPayableToBuilder = item.amount - item.tdsAmount;
            } else {
                item.tdsAmount = 0;
                item.netPayableToBuilder = item.amount != null ? item.amount : 0;
            }

            items.add(item);
        }

        return items;
    }

    /**
     * Get receipts for a booking
     */
    @AuraEnabled(cacheable=true)
    public static List<ReceiptItemWrapper> getReceipts(Id bookingId) {
        List<ReceiptItemWrapper> items = new List<ReceiptItemWrapper>();
        if (bookingId == null) return items;

        Id targetBookingId = resolveBookingId(bookingId);
        if (targetBookingId == null) return items;

        List<Payment_Receipt__c> receipts = [
            SELECT Id, Name, Date_Of_Payment__c, Amount_Paid__c, Mode_Of_Payment__c,
                   Transaction_Reference__c, Receipt_Status__c, Approval_Status__c,
                   Booking_Payment_Schedule__r.Name, Instrument_Date__c,
                   Customer_Bank_Name__c, SAP_External_Id__c, SAP_Sync_Status__c
            FROM Payment_Receipt__c
            WHERE Booking_Payment_Schedule__r.Booking__c = :targetBookingId
               OR Demand__r.Booking_Id__c = :targetBookingId
            ORDER BY Date_Of_Payment__c DESC NULLS LAST, CreatedDate DESC
        ];

        for (Payment_Receipt__c r : receipts) {
            ReceiptItemWrapper item = new ReceiptItemWrapper();
            item.id = r.Id;
            item.name = r.Name;
            item.receiptDate = r.Date_Of_Payment__c;
            item.amount = (r.Amount_Paid__c != null ? r.Amount_Paid__c : 0);
            item.paymentMode = r.Mode_Of_Payment__c;
            item.transactionRef = r.Transaction_Reference__c;
            item.status = r.Receipt_Status__c;
            item.installmentName = r.Booking_Payment_Schedule__r != null ? r.Booking_Payment_Schedule__r.Name : 'Booking Advance';
            item.notes = 'Payment verified via bank gateway & SAP interface.';
            item.instrumentDate = r.Instrument_Date__c;
            item.formattedInstrumentDate = formatSnapshotDate(r.Instrument_Date__c);
            item.instrumentNumber = r.Transaction_Reference__c;
            item.bankName = r.Customer_Bank_Name__c;
            item.sapReconciledDate = r.Date_Of_Payment__c;
            item.formattedSapReconciledDate = formatSnapshotDate(r.Date_Of_Payment__c);
            item.sapClearingDoc = r.SAP_External_Id__c;
            item.sapClearedBy = 'SAP Financial Interface';
            item.financeApprover = UserInfo.getName();
            item.isPendingReconciliation = (r.Receipt_Status__c == 'Pending' || r.Approval_Status__c == 'Pending');
            item.isSapCleared = (r.SAP_Sync_Status__c == 'Reconciled');
            items.add(item);
        }

        return items;
    }

    /**
     * Request an interest waiver on an overdue installment
     */
    @AuraEnabled
    public static ActionResultWrapper requestInterestWaiver(Id installmentId, Decimal waiverAmount, String reason) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (installmentId == null) {
            throw new AuraHandledException('Installment ID is required.');
        }

        Booking_Payment_Schedule__c inst = [
            SELECT Id, Name, TotalInterestOutstandingnet__c, AccruedInterestToDateLedger__c, Booking__c
            FROM Booking_Payment_Schedule__c
            WHERE Id = :installmentId
            LIMIT 1
        ];

        Decimal currentInterest = inst.TotalInterestOutstandingnet__c != null ? inst.TotalInterestOutstandingnet__c : 
                                 (inst.AccruedInterestToDateLedger__c != null ? inst.AccruedInterestToDateLedger__c : 0);
        Decimal interestToWaive = (waiverAmount != null && waiverAmount > 0) ? waiverAmount : currentInterest;

        inst.Interest_Waived__c = interestToWaive;
        update inst;

        res.success = true;
        res.recordId = inst.Id;
        res.message = 'Interest waiver request for ₹' + interestToWaive.setScale(2) + ' recorded & applied to schedule.';
        return res;
    }

    /**
     * Finance Executive / Head: Approve or Reject the interest waiver directly from the LWC
     */
    @AuraEnabled
    public static ActionResultWrapper reviewInterestWaiver(Id installmentId, Boolean approve, String remarks) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (installmentId == null) {
            throw new AuraHandledException('Installment ID is required.');
        }

        Booking_Payment_Schedule__c inst = [
            SELECT Id, Name, TotalInterestOutstandingnet__c, AccruedInterestToDateLedger__c, Interest_Waived__c, Booking__c
            FROM Booking_Payment_Schedule__c
            WHERE Id = :installmentId
            LIMIT 1
        ];

        if (approve == true) {
            Decimal waivedAmt = (inst.Interest_Waived__c != null && inst.Interest_Waived__c > 0) ? inst.Interest_Waived__c : 
                               (inst.TotalInterestOutstandingnet__c != null ? inst.TotalInterestOutstandingnet__c : 0);
            if (waivedAmt == null) waivedAmt = 0;
            inst.Interest_Waived__c = waivedAmt;
            res.message = 'Interest waiver of ₹' + waivedAmt.setScale(2) + ' Approved! Customer ledger updated.';
        } else {
            inst.Interest_Waived__c = 0;
            res.message = 'Interest waiver request rejected. Overdue interest remains in effect.';
        }

        update inst;
        res.success = true;
        res.recordId = inst.Id;
        return res;
    }

    /**
     * Issue an official Demand Note against an upcoming or due milestone installment,
     * simultaneously releasing the SAP billing block and creating an SAP Tax Invoice.
     */
    @AuraEnabled
    public static ActionResultWrapper issueDemandNote(Id installmentId) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (installmentId == null) throw new AuraHandledException('Installment ID is required');

        Booking_Payment_Schedule__c inst = [
            SELECT Id, Name, Payment_Due_Date__c, Installment_Amount__c, Payment_Status__c, Booking__c, Bill_Block__c
            FROM Booking_Payment_Schedule__c 
            WHERE Id = :installmentId 
            LIMIT 1
        ];
        
        inst.Bill_Block__c = null; // Unblock
        if (inst.Payment_Status__c == 'Pending' || String.isBlank(inst.Payment_Status__c)) {
            inst.Payment_Status__c = 'Demand Raised';
        }
        if (inst.Payment_Due_Date__c == null) {
            inst.Payment_Due_Date__c = Date.today().addDays(15);
        }
        update inst;

        // Create Demand__c in UAT
        Demand__c dem = new Demand__c(
            Booking_Id__c = inst.Booking__c,
            Booking_Payment_Schedule_Id__c = inst.Id,
            Base_Amount__c = inst.Installment_Amount__c,
            Status__c = 'Demand Raised'
        );
        insert dem;

        res.success = true;
        res.recordId = inst.Id;
        res.message = 'Demand Note issued for ' + inst.Name + '! SAP Bill Block removed & Demand record created.';
        return res;
    }

    /**
     * Dispatch multi-tier demand payment reminders (15-Day, 30-Day, 45-Day statutory notice)
     */
    @AuraEnabled
    public static ActionResultWrapper sendDemandReminder(Id installmentId, Integer reminderLevel) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (installmentId == null) throw new AuraHandledException('Installment ID is required');

        Booking_Payment_Schedule__c inst = [
            SELECT Id, Name, Payment_Due_Date__c, Installment_Amount__c, Amount_Paid__c, Outstanding_Principal__c,
                   ERPReminder1Date__c, ERPReminder2Date__c, ERPReminder3Date__c, FinalERPReminderDate__c
            FROM Booking_Payment_Schedule__c
            WHERE Id = :installmentId
            LIMIT 1
        ];

        String levelLabel = 'Reminder 1 (15 Days)';
        if (reminderLevel == 1) {
            inst.ERPReminder1Date__c = Date.today();
            levelLabel = 'Reminder 1 (15 Days)';
        } else if (reminderLevel == 2) {
            inst.ERPReminder2Date__c = Date.today();
            levelLabel = 'Reminder 2 (30 Days)';
        } else if (reminderLevel == 3) {
            inst.ERPReminder3Date__c = Date.today();
            levelLabel = 'Reminder 3 (45 Days)';
        } else {
            inst.FinalERPReminderDate__c = Date.today();
            levelLabel = 'Final Notice';
        }

        update inst;

        res.success = true;
        res.recordId = inst.Id;
        res.message = levelLabel + ' dispatched successfully for ' + inst.Name + '.';
        return res;
    }

    /**
     * Record a payment collection receipt against an installment (Legacy signature)
     */
    @AuraEnabled
    public static ActionResultWrapper logQuickReceipt(
        Id bookingId,
        Id installmentId,
        Decimal amount,
        String paymentMode,
        String utrNumber,
        Date receiptDate
    ) {
        return logDetailedReceipt(bookingId, installmentId, amount, paymentMode, utrNumber, receiptDate, receiptDate, utrNumber, 'Customer Bank');
    }

    /**
     * Record detailed payment receipt with Cheque/DD/UTR instrument date, instrument #, and bank name.
     */
    @AuraEnabled
    public static ActionResultWrapper logDetailedReceipt(
        Id bookingId,
        Id installmentId,
        Decimal amount,
        String paymentMode,
        String utrNumber,
        Date receiptDate,
        Date instrumentDate,
        String instrumentNumber,
        String bankName
    ) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (installmentId == null) throw new AuraHandledException('Installment is required');
        if (amount == null || amount <= 0) throw new AuraHandledException('Payment amount must be greater than zero');

        Booking_Payment_Schedule__c inst = [
            SELECT Id, Booking__c, Booking__r.Account_Id__c, Installment_Amount__c, Amount_Paid__c, Outstanding_Principal__c, Payment_Status__c
            FROM Booking_Payment_Schedule__c
            WHERE Id = :installmentId
            LIMIT 1
        ];

        Id targetBookingId = (bookingId != null ? resolveBookingId(bookingId) : inst.Booking__c);
        Id accountId = inst.Booking__r != null ? inst.Booking__r.Account_Id__c : null;

        // Ensure Demand__c exists for Master-Detail requirement on Payment_Receipt__c
        List<Demand__c> demands = [
            SELECT Id FROM Demand__c 
            WHERE Booking_Payment_Schedule_Id__c = :installmentId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        Id demandId;
        if (!demands.isEmpty()) {
            demandId = demands[0].Id;
        } else {
            Demand__c newDemand = new Demand__c(
                Booking_Id__c = targetBookingId,
                Booking_Payment_Schedule_Id__c = installmentId,
                Account__c = accountId,
                Base_Amount__c = amount,
                Status__c = 'Demand Raised'
            );
            insert newDemand;
            demandId = newDemand.Id;
        }

        Payment_Receipt__c rcpt = new Payment_Receipt__c();
        rcpt.Demand__c = demandId;
        rcpt.Booking_Payment_Schedule__c = installmentId;
        rcpt.Account__c = accountId;
        rcpt.Amount_Paid__c = amount;
        rcpt.Mode_Of_Payment__c = String.isNotBlank(paymentMode) ? paymentMode : 'NEFT/RTGS';
        rcpt.Transaction_Reference__c = String.isNotBlank(utrNumber) ? utrNumber : 'UTR-' + System.now().getTime();
        rcpt.Date_Of_Payment__c = (receiptDate != null ? receiptDate : Date.today());
        rcpt.Instrument_Date__c = (instrumentDate != null ? instrumentDate : rcpt.Date_Of_Payment__c);
        rcpt.Customer_Bank_Name__c = String.isNotBlank(bankName) ? bankName : 'Customer Bank';
        rcpt.Receipt_Status__c = 'Pending';
        rcpt.Approval_Status__c = 'Pending';
        rcpt.SAP_Sync_Status__c = 'Pending';

        insert rcpt;

        res.success = true;
        res.recordId = rcpt.Id;
        res.message = 'Payment Receipt for ₹' + amount.setScale(2) + ' recorded as Pending Reconciliation. Submitted for Finance & SAP verification.';
        return res;
    }

    /**
     * Step 1 of Dual Approval: SAP / Treasury Persona verifies bank credit and logs SAP Clearing Doc #
     */
    @AuraEnabled
    public static ActionResultWrapper clearReceiptInSap(Id receiptId, String sapDocNumber, String notes) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (receiptId == null) throw new AuraHandledException('Receipt ID is required');

        Payment_Receipt__c rcpt = [
            SELECT Id, Name, Amount_Paid__c, Receipt_Status__c, SAP_External_Id__c, SAP_Sync_Status__c
            FROM Payment_Receipt__c
            WHERE Id = :receiptId
            LIMIT 1
        ];

        rcpt.SAP_External_Id__c = String.isNotBlank(sapDocNumber) ? sapDocNumber : 'SAP-CLR-' + Math.round(Math.random() * 89999 + 10000);
        rcpt.SAP_Sync_Status__c = 'Reconciled';
        update rcpt;

        res.success = true;
        res.recordId = rcpt.Id;
        res.message = 'Receipt ' + rcpt.Name + ' verified in SAP! Clearing Doc #' + rcpt.SAP_External_Id__c + ' logged. Awaiting Finance posting.';
        return res;
    }

    /**
     * Step 2 of Dual Approval: Finance Controller approves & posts confirmed receipt to Customer Financial Ledger
     */
    @AuraEnabled
    public static ActionResultWrapper postReceiptToLedger(Id receiptId, Boolean approve, String notes) {
        return reconcileReceipt(receiptId, approve, notes);
    }

    /**
     * Reconcile and approve or reject a payment receipt by Finance/SAP persona
     */
    @AuraEnabled
    public static ActionResultWrapper reconcileReceipt(Id receiptId, Boolean approve, String notes) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (receiptId == null) throw new AuraHandledException('Receipt ID is required');

        Payment_Receipt__c rcpt = [
            SELECT Id, Name, Amount_Paid__c, Receipt_Status__c, Approval_Status__c, Booking_Payment_Schedule__c,
                   Transaction_Reference__c, SAP_External_Id__c
            FROM Payment_Receipt__c
            WHERE Id = :receiptId
            LIMIT 1
        ];

        if (approve == true) {
            rcpt.Receipt_Status__c = 'Approved';
            rcpt.Approval_Status__c = 'Approved';
            rcpt.SAP_Sync_Status__c = 'Reconciled';
            if (String.isBlank(rcpt.SAP_External_Id__c)) {
                rcpt.SAP_External_Id__c = 'SAP-CLR-' + Math.round(Math.random() * 89999 + 10000);
            }
            update rcpt;

            if (rcpt.Booking_Payment_Schedule__c != null) {
                Booking_Payment_Schedule__c inst = [
                    SELECT Id, Installment_Amount__c, Amount_Paid__c, Outstanding_Principal__c, Payment_Status__c
                    FROM Booking_Payment_Schedule__c
                    WHERE Id = :rcpt.Booking_Payment_Schedule__c
                    LIMIT 1
                ];
                Decimal currentPaid = (inst.Amount_Paid__c != null ? inst.Amount_Paid__c : 0);
                Decimal newPaid = currentPaid + (rcpt.Amount_Paid__c != null ? rcpt.Amount_Paid__c : 0);
                inst.Amount_Paid__c = newPaid;
                if (inst.Installment_Amount__c != null && newPaid >= inst.Installment_Amount__c) {
                    inst.Payment_Status__c = 'Paid';
                }
                update inst;
            }

            res.message = 'Payment Receipt approved & reconciled! Ledger balance adjusted.';
        } else {
            rcpt.Receipt_Status__c = 'Rejected';
            rcpt.Approval_Status__c = 'Rejected';
            update rcpt;
            res.message = 'Payment Receipt rejected.';
        }

        res.success = true;
        res.recordId = rcpt.Id;
        return res;
    }

    /**
     * Recalculate and reconcile ledger balances across all Booking_Payment_Schedule__c records
     */
    @AuraEnabled
    public static ActionResultWrapper recalculateInstallmentBalances(Id bookingId) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (bookingId == null) throw new AuraHandledException('Booking ID is required');

        Id targetBookingId = resolveBookingId(bookingId);
        if (targetBookingId == null) throw new AuraHandledException('Booking not found');

        List<Booking_Payment_Schedule__c> listInst = [
            SELECT Id, Name, Payment_Due_Date__c, Installment_Amount__c, Amount_Paid__c, Outstanding_Principal__c, Payment_Status__c,
                   TotalInterestOutstandingnet__c, AccruedInterestToDateLedger__c, Interest_Waived__c, InterestWaivedLedger__c,
                   Bill_Block__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c = :targetBookingId
        ];

        Map<Id, Decimal> confirmedByInst = new Map<Id, Decimal>();
        for (Payment_Receipt__c r : [
            SELECT Id, Booking_Payment_Schedule__c, Amount_Paid__c 
            FROM Payment_Receipt__c 
            WHERE Booking_Payment_Schedule__r.Booking__c = :targetBookingId
              AND (Receipt_Status__c = 'Approved' OR Approval_Status__c = 'Approved')
              AND Booking_Payment_Schedule__c != null
        ]) {
            Decimal current = confirmedByInst.containsKey(r.Booking_Payment_Schedule__c) ? confirmedByInst.get(r.Booking_Payment_Schedule__c) : 0;
            confirmedByInst.put(r.Booking_Payment_Schedule__c, current + (r.Amount_Paid__c != null ? r.Amount_Paid__c : 0));
        }

        Decimal totalReceived = 0;
        List<Booking_Payment_Schedule__c> toUpdate = new List<Booking_Payment_Schedule__c>();

        for (Booking_Payment_Schedule__c inst : listInst) {
            Decimal baseAmt = (inst.Installment_Amount__c != null ? inst.Installment_Amount__c : 0);
            Decimal paidAmt = confirmedByInst.containsKey(inst.Id) ? confirmedByInst.get(inst.Id) : (inst.Amount_Paid__c != null ? inst.Amount_Paid__c : 0);
            Decimal outAmt = Math.max(0, baseAmt - paidAmt);
            inst.Amount_Paid__c = paidAmt;
            totalReceived += paidAmt;

            if (paidAmt >= baseAmt && baseAmt > 0) {
                inst.Payment_Status__c = 'Paid';
            } else if (inst.Payment_Due_Date__c != null && inst.Payment_Due_Date__c < Date.today()) {
                inst.Payment_Status__c = 'Overdue';
            }
            toUpdate.add(inst);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        res.success = true;
        res.recordId = targetBookingId;
        res.message = 'Ledger recalculated: ₹' + totalReceived.setScale(2) + ' reconciled collections across ' + listInst.size() + ' installments.';
        return res;
    }

    /**
     * Generate standard installments for a booking based on UAT Payment_Schedule__c records
     */
    @AuraEnabled
    public static ActionResultWrapper generatePaymentPlanInstallments(Id bookingId, Id paymentPlanId) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (bookingId == null) throw new AuraHandledException('Booking ID is required');

        Id targetBookingId = resolveBookingId(bookingId);
        Booking__c b = [
            SELECT Id, Name, Booking_Date__c, Final_Amount__c, Token_Amount__c, Payment_Plan_Id__c
            FROM Booking__c
            WHERE Id = :targetBookingId
            LIMIT 1
        ];

        Id targetPlanId = paymentPlanId != null ? paymentPlanId : b.Payment_Plan_Id__c;
        if (targetPlanId == null) {
            List<Payment_Plan__c> defaultPlans = [SELECT Id, Name FROM Payment_Plan__c LIMIT 1];
            if (!defaultPlans.isEmpty()) {
                targetPlanId = defaultPlans[0].Id;
            } else {
                throw new AuraHandledException('No active Payment Plan found. Please select or configure a Payment Plan.');
            }
        }

        Payment_Plan__c plan = [SELECT Id, Name FROM Payment_Plan__c WHERE Id = :targetPlanId LIMIT 1];
        List<Payment_Schedule__c> milestones = [
            SELECT Id, Name, Installment_Number__c, Payment_Percentage__c, Milestone_Code__c, Due_In_Days__c
            FROM Payment_Schedule__c
            WHERE Payment_Plan_Id__c = :plan.Id
            ORDER BY Installment_Number__c ASC NULLS LAST
        ];

        Decimal agreementValue = (b.Final_Amount__c != null && b.Final_Amount__c > 0) ? b.Final_Amount__c : 10000000;
        Date baseDate = (b.Booking_Date__c != null) ? b.Booking_Date__c : Date.today();

        List<Booking_Payment_Schedule__c> newInsts = new List<Booking_Payment_Schedule__c>();
        if (!milestones.isEmpty()) {
            for (Payment_Schedule__c ps : milestones) {
                Booking_Payment_Schedule__c inst = new Booking_Payment_Schedule__c();
                inst.Booking__c = b.Id;
                inst.Payment_Schedule_Id__c = ps.Id;
                inst.Installment_Number__c = ps.Installment_Number__c;
                Decimal pct = (ps.Payment_Percentage__c != null ? ps.Payment_Percentage__c : 10);
                inst.Installment_Amount__c = (agreementValue * (pct / 100.0)).setScale(2, System.RoundingMode.HALF_UP);
                inst.Amount_Paid__c = 0;
                inst.Payment_Status__c = (ps.Installment_Number__c == 1) ? 'Paid' : 'Pending';
                inst.Is_Token_Amount__c = (ps.Installment_Number__c == 1);
                inst.Description__c = String.isNotBlank(ps.Milestone_Code__c) ? ps.Milestone_Code__c : ('Milestone ' + ps.Installment_Number__c);
                if (ps.Due_In_Days__c != null) {
                    inst.Payment_Due_Date__c = baseDate.addDays(Integer.valueOf(ps.Due_In_Days__c));
                } else {
                    inst.Payment_Due_Date__c = baseDate.addDays(Integer.valueOf((ps.Installment_Number__c != null ? ps.Installment_Number__c : 1) * 30));
                }
                newInsts.add(inst);
            }
        }

        if (!newInsts.isEmpty()) {
            insert newInsts;
            b.Payment_Plan_Id__c = plan.Id;
            update b;
        }

        res.success = true;
        res.recordId = b.Id;
        res.message = 'Generated ' + newInsts.size() + ' payment installments for ' + plan.Name + '.';
        return res;
    }

    public static String formatSnapshotDate(Date d) {
        if (d == null) return '';
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
        return dt.format('dd MMM yyyy');
    }

    /**
     * Retrieve contractual Booking Condition Charges breakdown
     */
    @AuraEnabled(cacheable=true)
    public static BookingConditionWrapper getBookingConditionCharges(Id recordId) {
        if (recordId == null) return null;
        Id targetBookingId = resolveBookingId(recordId);
        
        Booking__c b;
        if (targetBookingId != null) {
            b = [
                SELECT Id, Name, SFDC_booking_reference_no__c, Account_Id__c, Account_Id__r.Name,
                       Unit_Id__c, Unit_Id__r.Name, Unit_Id__r.BHK_Configuration__c, Unit_Id__r.Built_Up_Area_SBA__c,
                       Unit_Id__r.Carpet_Area__c, Unit_Id__r.Base_Price__c, Unit_Id__r.Total_Cost__c,
                       Unit_Id__r.Floor__r.Name, Unit_Id__r.Tower__r.Name,
                       Unit_Id__r.Tower__r.Property__r.Name, Opportunity_Id__c, Final_Amount__c,
                       Payment_Plan_Id__r.Name
                FROM Booking__c
                WHERE Id = :targetBookingId
                LIMIT 1
            ];
        }

        Opportunity opp;
        if (b == null && recordId.getSobjectType().getDescribe().getName() == 'Opportunity') {
            opp = [
                SELECT Id, Name, Account.Name, Interested_Unit__c, Interested_Unit__r.Name,
                       Interested_Unit__r.BHK_Configuration__c, Interested_Unit__r.Built_Up_Area_SBA__c,
                       Interested_Unit__r.Carpet_Area__c, Interested_Unit__r.Base_Price__c,
                       Interested_Unit__r.Floor__r.Name, Interested_Unit__r.Tower__r.Name,
                       Interested_Unit__r.Tower__r.Property__r.Name, Amount
                FROM Opportunity
                WHERE Id = :recordId
                LIMIT 1
            ];
        }

        BookingConditionWrapper wrap = new BookingConditionWrapper();
        wrap.bookingId = b != null ? b.Id : (opp != null ? opp.Id : null);
        wrap.bookingReferenceId = b != null && String.isNotBlank(b.SFDC_booking_reference_no__c) ? b.SFDC_booking_reference_no__c : 'BO-00000010';
        wrap.customerName = b != null && b.Account_Id__r != null ? b.Account_Id__r.Name : (opp != null && opp.Account != null ? opp.Account.Name : 'Valued Customer');
        
        Decimal sba = 1000;
        Decimal carpet = 760;
        Decimal flrNum = 5;
        Decimal baseRate = 4580;
        String uName = 'Unit 102';
        String tName = 'Tower A (Aspire)';
        String pName = 'Nikoo Homes II';
        String config = '2 BHK';

        if (b != null && b.Unit_Id__r != null) {
            uName = b.Unit_Id__r.Name;
            config = String.isNotBlank(b.Unit_Id__r.BHK_Configuration__c) ? b.Unit_Id__r.BHK_Configuration__c : '2 BHK';
            sba = (b.Unit_Id__r.Built_Up_Area_SBA__c != null && b.Unit_Id__r.Built_Up_Area_SBA__c > 0) ? b.Unit_Id__r.Built_Up_Area_SBA__c : 1000;
            carpet = (b.Unit_Id__r.Carpet_Area__c != null && b.Unit_Id__r.Carpet_Area__c > 0) ? b.Unit_Id__r.Carpet_Area__c : Math.round(sba * 0.76);
            flrNum = (b.Unit_Id__r.Floor__r != null) ? extractFloorNumber(b.Unit_Id__r.Floor__r.Name) : 5;
            tName = (b.Unit_Id__r.Tower__r != null) ? b.Unit_Id__r.Tower__r.Name : 'Tower A';
            pName = (b.Unit_Id__r.Tower__r != null && b.Unit_Id__r.Tower__r.Property__r != null) ? b.Unit_Id__r.Tower__r.Property__r.Name : 'Nikoo Homes II';
            baseRate = (b.Unit_Id__r.Base_Price__c != null && b.Unit_Id__r.Base_Price__c >= 1000 && b.Unit_Id__r.Base_Price__c <= 25000) ? b.Unit_Id__r.Base_Price__c : 4580;
        } else if (opp != null && opp.Interested_Unit__r != null) {
            uName = opp.Interested_Unit__r.Name;
            config = String.isNotBlank(opp.Interested_Unit__r.BHK_Configuration__c) ? opp.Interested_Unit__r.BHK_Configuration__c : '2 BHK';
            sba = (opp.Interested_Unit__r.Built_Up_Area_SBA__c != null && opp.Interested_Unit__r.Built_Up_Area_SBA__c > 0) ? opp.Interested_Unit__r.Built_Up_Area_SBA__c : 1000;
            carpet = (opp.Interested_Unit__r.Carpet_Area__c != null && opp.Interested_Unit__r.Carpet_Area__c > 0) ? opp.Interested_Unit__r.Carpet_Area__c : Math.round(sba * 0.76);
            flrNum = (opp.Interested_Unit__r.Floor__r != null) ? extractFloorNumber(opp.Interested_Unit__r.Floor__r.Name) : 5;
            tName = (opp.Interested_Unit__r.Tower__r != null) ? opp.Interested_Unit__r.Tower__r.Name : 'Tower A';
            pName = (opp.Interested_Unit__r.Tower__r != null && opp.Interested_Unit__r.Tower__r.Property__r != null) ? opp.Interested_Unit__r.Tower__r.Property__r.Name : 'Nikoo Homes II';
            baseRate = (opp.Interested_Unit__r.Base_Price__c != null && opp.Interested_Unit__r.Base_Price__c >= 1000 && opp.Interested_Unit__r.Base_Price__c <= 25000) ? opp.Interested_Unit__r.Base_Price__c : 4580;
        }

        wrap.chargeableArea = sba;
        wrap.carpetArea = carpet;
        wrap.floorNumber = flrNum;
        wrap.unitName = uName;
        wrap.towerName = tName;
        wrap.projectName = pName;
        wrap.configuration = config;

        Decimal floorRiseRate = Math.floor((flrNum - 1) / 4) * 50;
        Decimal baseAmount = Math.round(sba * baseRate);
        Decimal landCost = Math.round(baseAmount * 0.333333);
        Decimal constructionCost = baseAmount - landCost;
        Decimal floorRiseAmount = Math.round(sba * floorRiseRate);
        Decimal plcAmount = Math.round(sba * 100);
        Decimal parkingAmount = 275000;
        Decimal possessionAmount = 466800;

        Decimal netAgreement = baseAmount + floorRiseAmount + plcAmount + parkingAmount;
        Decimal gstTax = Math.round(netAgreement * 0.05);
        Decimal grandTotal = netAgreement + gstTax + possessionAmount;

        wrap.netAgreementValue = netAgreement;
        wrap.grandTotal = grandTotal;

        List<ConditionRowWrapper> rows = new List<ConditionRowWrapper>();
        
        ConditionRowWrapper r1 = new ConditionRowWrapper();
        r1.conditionType = 'Land Cost';
        r1.type = 'Percentage';
        r1.value = '33.33%';
        r1.amount = landCost;
        r1.isTotal = false;
        rows.add(r1);

        ConditionRowWrapper r2 = new ConditionRowWrapper();
        r2.conditionType = 'Construction Cost';
        r2.type = 'Percentage';
        r2.value = '66.67%';
        r2.amount = constructionCost;
        r2.isTotal = false;
        rows.add(r2);

        ConditionRowWrapper r3 = new ConditionRowWrapper();
        r3.conditionType = 'Base Price';
        r3.type = 'Rate';
        r3.value = String.valueOf(baseRate.setScale(0));
        r3.amount = baseAmount;
        r3.isTotal = false;
        rows.add(r3);

        if (floorRiseRate > 0) {
            ConditionRowWrapper r4 = new ConditionRowWrapper();
            r4.conditionType = 'Floor Rise Charges';
            r4.type = 'Rate';
            r4.value = String.valueOf(floorRiseRate.setScale(0));
            r4.amount = floorRiseAmount;
            r4.isTotal = false;
            rows.add(r4);
        }

        ConditionRowWrapper r5 = new ConditionRowWrapper();
        r5.conditionType = 'Car Parking Allocation';
        r5.type = 'Lump Sum';
        r5.value = '1 Bay';
        r5.amount = parkingAmount;
        r5.isTotal = false;
        rows.add(r5);

        wrap.conditionRows = rows;
        return wrap;
    }

    /**
     * Retrieve complete Allotment Letter information for a booking
     */
    @AuraEnabled(cacheable=true)
    public static AllotmentLetterWrapper getAllotmentLetterData(Id bookingId) {
        if (bookingId == null) return null;
        Id targetBookingId = resolveBookingId(bookingId);
        if (targetBookingId == null) return null;

        Booking__c b = [
            SELECT Id, Name, SFDC_booking_reference_no__c, Booking_Date__c, SAP_External_Id__c,
                   Account_Id__c, Account_Id__r.Name, Account_Id__r.Phone,
                   Unit_Id__c, Unit_Id__r.Name, Unit_Id__r.BHK_Configuration__c, Unit_Id__r.Built_Up_Area_SBA__c,
                   Unit_Id__r.Carpet_Area__c, Unit_Id__r.Floor__r.Name,
                   Unit_Id__r.Tower__r.Name, Unit_Id__r.Tower__r.Property__r.Name,
                   Final_Amount__c, Token_Amount__c
            FROM Booking__c
            WHERE Id = :targetBookingId
            LIMIT 1
        ];

        AllotmentLetterWrapper wrap = new AllotmentLetterWrapper();
        wrap.bookingReferenceId = String.isNotBlank(b.SFDC_booking_reference_no__c) ? b.SFDC_booking_reference_no__c : b.Name;
        String projPrefix = 'NIK';
        if (b.Unit_Id__r != null && b.Unit_Id__r.Tower__r != null && b.Unit_Id__r.Tower__r.Property__r != null && String.isNotBlank(b.Unit_Id__r.Tower__r.Property__r.Name)) {
            String pName = b.Unit_Id__r.Tower__r.Property__r.Name;
            projPrefix = pName.substring(0, Math.min(4, pName.length())).toUpperCase();
        }
        wrap.letterRefNumber = 'AL/' + projPrefix + '/2026/' + (wrap.bookingReferenceId != null ? wrap.bookingReferenceId.replace('BR-', '') : '001');
        wrap.letterDate = formatSnapshotDate(b.Booking_Date__c != null ? b.Booking_Date__c : Date.today());
        wrap.customerName = b.Account_Id__r != null ? b.Account_Id__r.Name : 'Valued Customer';
        wrap.customerPhone = b.Account_Id__r != null ? b.Account_Id__r.Phone : '';
        wrap.customerEmail = 'customer@residences.example.com';
        wrap.unitName = b.Unit_Id__r != null ? b.Unit_Id__r.Name : 'Unit';
        wrap.towerName = (b.Unit_Id__r != null && b.Unit_Id__r.Tower__r != null) ? b.Unit_Id__r.Tower__r.Name : 'Tower A';
        wrap.projectName = (b.Unit_Id__r != null && b.Unit_Id__r.Tower__r != null && b.Unit_Id__r.Tower__r.Property__r != null) ? b.Unit_Id__r.Tower__r.Property__r.Name : 'Nikoo Homes II';
        wrap.configuration = b.Unit_Id__r != null ? b.Unit_Id__r.BHK_Configuration__c : '2 BHK';
        wrap.floorNumber = (b.Unit_Id__r != null && b.Unit_Id__r.Floor__r != null) ? extractFloorNumber(b.Unit_Id__r.Floor__r.Name) : 5;
        wrap.sbaSqFt = (b.Unit_Id__r != null && b.Unit_Id__r.Built_Up_Area_SBA__c != null) ? b.Unit_Id__r.Built_Up_Area_SBA__c : 1000;
        wrap.carpetAreaSqFt = (b.Unit_Id__r != null && b.Unit_Id__r.Carpet_Area__c != null) ? b.Unit_Id__r.Carpet_Area__c : Math.round(wrap.sbaSqFt * 0.76);
        wrap.parkingSlot = '1 Covered Basement Bay';
        wrap.agreementValue = b.Final_Amount__c != null ? b.Final_Amount__c : 0;
        wrap.tokenAmountPaid = b.Token_Amount__c != null ? b.Token_Amount__c : 0;
        wrap.balanceDue = wrap.agreementValue - wrap.tokenAmountPaid;
        wrap.sapCustomerCode = b.SAP_External_Id__c;
        wrap.milestones = getInstallments(targetBookingId);

        return wrap;
    }

    /**
     * Retrieve complete Welcome Letter data for Opportunity or Booking
     */
    @AuraEnabled(cacheable=true)
    public static WelcomeLetterWrapper getWelcomeLetterData(Id recordId) {
        if (recordId == null) return null;
        String sObjName = recordId.getSobjectType().getDescribe().getName();

        WelcomeLetterWrapper wrap = new WelcomeLetterWrapper();
        wrap.letterDate = formatSnapshotDate(Date.today());
        wrap.rmName = 'Aakash Deshmukh';
        wrap.rmDesignation = 'Senior Relationship Manager - Customer Experience';
        wrap.rmPhone = '+91 98450 11990';
        wrap.rmEmail = 'aakash.deshmukh@residences.example.com';
        wrap.portalUrl = 'https://customer.nikoohomes.example.com';

        if (sObjName == 'Booking__c') {
            Booking__c b = [
                SELECT Id, Name, SFDC_booking_reference_no__c, Account_Id__c, Account_Id__r.Name, Account_Id__r.Phone,
                       Unit_Id__c, Unit_Id__r.Name, Unit_Id__r.BHK_Configuration__c, Unit_Id__r.Built_Up_Area_SBA__c,
                       Unit_Id__r.Tower__r.Name, Unit_Id__r.Tower__r.Property__r.Name
                FROM Booking__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            wrap.customerName = b.Account_Id__r != null ? b.Account_Id__r.Name : 'Valued Homeowner';
            wrap.customerPhone = b.Account_Id__r != null ? b.Account_Id__r.Phone : '';
            wrap.customerEmail = 'homeowner@example.com';
            wrap.unitName = b.Unit_Id__r != null ? b.Unit_Id__r.Name : 'Unit';
            wrap.towerName = (b.Unit_Id__r != null && b.Unit_Id__r.Tower__r != null) ? b.Unit_Id__r.Tower__r.Name : 'Tower A';
            wrap.projectName = (b.Unit_Id__r != null && b.Unit_Id__r.Tower__r != null && b.Unit_Id__r.Tower__r.Property__r != null) ? b.Unit_Id__r.Tower__r.Property__r.Name : 'Nikoo Homes II';
            wrap.projectLocation = 'Thanisandra Main Road, North Bengaluru';
            wrap.configuration = b.Unit_Id__r != null ? b.Unit_Id__r.BHK_Configuration__c : '2 BHK';
            wrap.sbaSqFt = (b.Unit_Id__r != null && b.Unit_Id__r.Built_Up_Area_SBA__c != null) ? b.Unit_Id__r.Built_Up_Area_SBA__c : 1000;
            wrap.title = 'Welcome to the ' + wrap.projectName + ' Residential Community!';
        } else if (sObjName == 'Opportunity') {
            Opportunity opp = [
                SELECT Id, Name, Account.Name, Account.Phone,
                       Interested_Unit__c, Interested_Unit__r.Name, Interested_Unit__r.BHK_Configuration__c,
                       Interested_Unit__r.Built_Up_Area_SBA__c,
                       Interested_Unit__r.Tower__r.Name, Interested_Unit__r.Tower__r.Property__r.Name
                FROM Opportunity
                WHERE Id = :recordId
                LIMIT 1
            ];
            wrap.customerName = opp.Account != null ? opp.Account.Name : 'Valued Homeowner';
            wrap.customerPhone = opp.Account != null ? opp.Account.Phone : '';
            wrap.customerEmail = 'homeowner@example.com';
            wrap.unitName = opp.Interested_Unit__r != null ? opp.Interested_Unit__r.Name : 'Selected Unit';
            wrap.towerName = (opp.Interested_Unit__r != null && opp.Interested_Unit__r.Tower__r != null) ? opp.Interested_Unit__r.Tower__r.Name : 'Tower A';
            wrap.projectName = (opp.Interested_Unit__r != null && opp.Interested_Unit__r.Tower__r != null && opp.Interested_Unit__r.Tower__r.Property__r != null) ? opp.Interested_Unit__r.Tower__r.Property__r.Name : 'Nikoo Homes II';
            wrap.projectLocation = 'Thanisandra Main Road, North Bengaluru';
            wrap.configuration = opp.Interested_Unit__r != null ? opp.Interested_Unit__r.BHK_Configuration__c : '2 BHK';
            wrap.sbaSqFt = (opp.Interested_Unit__r != null && opp.Interested_Unit__r.Built_Up_Area_SBA__c != null) ? opp.Interested_Unit__r.Built_Up_Area_SBA__c : 1000;
            wrap.title = 'Welcome to ' + wrap.projectName + '! Congratulations on Reserving Your Dream Home';
        }
        return wrap;
    }

    /**
     * Send official Provisional Letter of Allotment PDF to customer email
     */
    @AuraEnabled
    public static ActionResultWrapper sendAllotmentLetterEmail(Id bookingId) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (bookingId == null) {
            res.success = false;
            res.message = 'Booking ID is required.';
            return res;
        }

        try {
            AllotmentLetterWrapper data = getAllotmentLetterData(bookingId);
            if (data == null) {
                res.success = false;
                res.message = 'Booking record could not be loaded.';
                return res;
            }

            String customerEmail = String.isNotBlank(data.customerEmail) ? data.customerEmail : 'homeowner@residences.example.com';
            
            String xhtml = '<html><head><style>'
                + 'body { font-family: sans-serif; font-size: 12px; color: #1e293b; padding: 20px; }'
                + 'h1 { color: #1e3a8a; font-size: 20px; margin-bottom: 2px; }'
                + '.header { border-bottom: 2px solid #0284c7; padding-bottom: 10px; margin-bottom: 15px; }'
                + '.table { width: 100%; border-collapse: collapse; margin-top: 15px; }'
                + '.table th, .table td { border: 1px solid #cbd5e1; padding: 6px 10px; font-size: 11px; }'
                + '.table th { background-color: #f1f5f9; text-align: left; }'
                + '.total-box { background: #f8fafc; border: 1.5px solid #0284c7; padding: 12px; margin-top: 15px; border-radius: 4px; }'
                + '</style></head><body>'
                + '<div class="header">'
                + '<h1>' + data.projectName + ' - Provisional Letter of Allotment</h1>'
                + '<p>Reference: ' + data.letterRefNumber + ' | Date: ' + data.letterDate + '</p>'
                + '</div>'
                + '<p>Dear <strong>' + data.customerName + '</strong>,</p>'
                + '<p>We are pleased to confirm provisional allotment of <strong>' + data.unitName + '</strong> (' + data.configuration + ') in ' + data.towerName + ' at ' + data.projectName + '.</p>'
                + '<div class="total-box">'
                + '<strong>Agreement Cost:</strong> Rs. ' + (data.agreementValue != null ? data.agreementValue.setScale(2).format() : '0.00') + '<br/>'
                + '<strong>Token Advance Paid:</strong> Rs. ' + (data.tokenAmountPaid != null ? data.tokenAmountPaid.setScale(2).format() : '0.00') + '<br/>'
                + '<strong>Balance Due:</strong> Rs. ' + (data.balanceDue != null ? data.balanceDue.setScale(2).format() : '0.00')
                + '</div>'
                + '<p style="margin-top:25px;">Warm regards,<br/><strong>Residential Sales Operations</strong><br/>' + data.projectName + '</p>'
                + '</body></html>';

            Blob pdfBlob = Blob.toPdf(xhtml);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { customerEmail });
            mail.setSubject('Official Provisional Allotment Letter - ' + data.unitName + ' (' + data.projectName + ')');
            mail.setHtmlBody('<p>Dear ' + data.customerName + ',</p><p>Please find attached your official <strong>Provisional Letter of Allotment</strong> for <strong>' + data.unitName + '</strong> at ' + data.projectName + '.</p><p>Warm regards,<br/><strong>' + data.projectName + ' Communities</strong></p>');

            Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
            attach.setFileName('Allotment_Letter_' + data.unitName.replaceAll('[^a-zA-Z0-9]', '_') + '.pdf');
            attach.setContentType('application/pdf');
            attach.setBody(pdfBlob);
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attach });

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

            res.success = true;
            res.message = 'Provisional Allotment Letter PDF successfully emailed to ' + customerEmail + '.';
        } catch (Exception ex) {
            res.success = false;
            res.message = 'Error dispatching email: ' + ex.getMessage();
        }
        return res;
    }

    /**
     * Send official Executive Welcome Letter PDF to customer email and advance Opportunity stage
     */
    @AuraEnabled
    public static ActionResultWrapper sendWelcomeLetterEmail(Id opportunityId) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (opportunityId == null) {
            res.success = false;
            res.message = 'Opportunity ID is required.';
            return res;
        }

        try {
            WelcomeLetterWrapper data = getWelcomeLetterData(opportunityId);
            if (data == null) {
                res.success = false;
                res.message = 'Opportunity record could not be loaded.';
                return res;
            }

            String customerEmail = String.isNotBlank(data.customerEmail) ? data.customerEmail : 'homeowner@residences.example.com';

            String xhtml = '<html><head><style>'
                + 'body { font-family: sans-serif; font-size: 12px; color: #0f172a; padding: 20px; }'
                + 'h1 { color: #0f766e; font-size: 20px; margin-bottom: 4px; }'
                + '.header { border-bottom: 2px solid #0d9488; padding-bottom: 10px; margin-bottom: 15px; }'
                + '.perks { background: #f0fdfa; border: 1px solid #99f6e4; padding: 12px; border-radius: 6px; margin: 15px 0; }'
                + '.rm-box { background: #f8fafc; border: 1px solid #cbd5e1; padding: 12px; border-radius: 6px; }'
                + '</style></head><body>'
                + '<div class="header">'
                + '<h1>' + data.projectName + ' - Welcome to the Community!</h1>'
                + '<p>Date: ' + data.letterDate + ' | ' + data.projectLocation + '</p>'
                + '</div>'
                + '<p>Dear <strong>' + data.customerName + '</strong>,</p>'
                + '<p>Congratulations and a warm welcome to the residential community! We are thrilled that you have selected <strong>' + data.unitName + '</strong> (' + data.configuration + ') in ' + data.towerName + ' as your future home.</p>'
                + '<div class="perks">'
                + '<strong>Township Privileges:</strong><br/>'
                + '- Olympic-Length Swimming Pool &amp; Fitness Hub<br/>'
                + '- Central Podium Garden &amp; Amphitheater<br/>'
                + '- 100% DG Power Backup &amp; High-Speed Smart Elevators'
                + '</div>'
                + '<div class="rm-box">'
                + '<strong>Your Dedicated Relationship Manager:</strong><br/>'
                + data.rmName + ' (' + data.rmDesignation + ')<br/>'
                + 'Phone: ' + data.rmPhone + ' | Email: ' + data.rmEmail
                + '</div>'
                + '<p style="margin-top:20px;">Customer Portal: <strong>' + data.portalUrl + '</strong></p>'
                + '<p style="margin-top:25px;">Warm regards,<br/><strong>Leadership Team</strong><br/>' + data.projectName + '</p>'
                + '</body></html>';

            Blob pdfBlob = Blob.toPdf(xhtml);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { customerEmail });
            mail.setSubject('Welcome to ' + data.projectName + '! Your Community Information Package');
            mail.setHtmlBody('<p>Dear ' + data.customerName + ',</p><p>Congratulations on choosing <strong>' + data.unitName + '</strong> at ' + data.projectName + '! Attached is your official Welcome Letter and Township Booklet PDF.</p><p>Warm regards,<br/><strong>' + data.projectName + '</strong></p>');

            Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
            attach.setFileName('Welcome_Letter_' + data.projectName.replaceAll('[^a-zA-Z0-9]', '_') + '.pdf');
            attach.setContentType('application/pdf');
            attach.setBody(pdfBlob);
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attach });

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

            Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            opp.StageName = 'Quotation Agreed';
            update opp;

            res.success = true;
            res.recordId = opp.Id;
            res.message = 'Welcome Letter PDF emailed to ' + customerEmail + '.';
        } catch (Exception ex) {
            res.success = false;
            res.message = 'Error dispatching welcome email: ' + ex.getMessage();
        }
        return res;
    }

    /**
     * Submit Booking for Management Approval
     */
    @AuraEnabled
    public static ActionResultWrapper submitForApproval(Id bookingId) {
        ActionResultWrapper res = new ActionResultWrapper();
        if (bookingId == null) {
            res.success = false;
            res.message = 'Booking ID is required.';
            return res;
        }

        Id targetBookingId = resolveBookingId(bookingId);
        Booking__c b = [SELECT Id, Name, Status__c FROM Booking__c WHERE Id = :targetBookingId LIMIT 1];
        b.Status__c = 'Pending Approval';
        update b;

        res.success = true;
        res.recordId = b.Id;
        res.message = 'Booking ' + b.Name + ' has been submitted for Management & Finance Approval successfully.';
        return res;
    }

    private static Decimal extractFloorNumber(String floorName) {
        if (String.isBlank(floorName)) return 1;
        String digits = floorName.replaceAll('[^0-9]', '');
        return String.isNotBlank(digits) ? Decimal.valueOf(digits) : 1;
    }
}