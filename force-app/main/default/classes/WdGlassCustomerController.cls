/**
 * Customer 360 for the WarpDrive glass Account page (wdGlassCustomer).
 * Everything a residential sales person needs before calling a buyer: what they own, what they
 * owe and when, what they are still considering, and anything open with the CRM/service team.
 */
public with sharing class WdGlassCustomerController {

    private static final Integer MAX_ROWS = 6;
    // Rows for the Cases / Invoices / Payments tabs.
    private static final Integer TAB_ROWS = 200;

    public class Profile {
        @AuraEnabled public String name;
        @AuraEnabled public String mobile;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public String city;
        @AuraEnabled public String owner;
        @AuraEnabled public Date customerSince;
        @AuraEnabled public String source;
        @AuraEnabled public String channelPartner;
    }

    public class Holding {
        @AuraEnabled public Id bookingId;
        @AuraEnabled public String bookingName;
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String configuration;
        @AuraEnabled public Decimal area;
        @AuraEnabled public String project;
        @AuraEnabled public String tower;
        @AuraEnabled public String status;
        @AuraEnabled public String role; // Primary applicant | Co-applicant
        @AuraEnabled public Decimal value;
        @AuraEnabled public Decimal paid;
        @AuraEnabled public Decimal outstanding;
        @AuraEnabled public Date bookingDate;
        @AuraEnabled public Date possessionDate;
        @AuraEnabled public String paymentPlan;
        @AuraEnabled public Boolean agreementSigned;
        @AuraEnabled public Boolean transferInProgress;
    }

    public class Instalment {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String booking;
        @AuraEnabled public String unit;
        @AuraEnabled public String milestone;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal outstanding;
        @AuraEnabled public Decimal interest;
        @AuraEnabled public Boolean overdue;
    }

    public class Item {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date onDate;
        @AuraEnabled public Datetime at;
    }

    public class CaseRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String type;
        @AuraEnabled public String priority;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean closed;
        @AuraEnabled public Date opened;
        @AuraEnabled public Date closedOn;
    }

    public class Invoice {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String unit;
        @AuraEnabled public String milestone;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Date sentOn;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal received;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean overdue;
    }

    public class Payment {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Date paidOn;
        @AuraEnabled public String unit;
        @AuraEnabled public String invoice;
        @AuraEnabled public String mode;
        @AuraEnabled public String reference;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String approval;
        @AuraEnabled public String receiptStatus;
    }

    public class Alert {
        @AuraEnabled public String tone; // negative | warning | info
        @AuraEnabled public String message;

        Alert(String tone, String message) {
            this.tone = tone;
            this.message = message;
        }
    }

    public class Customer {
        @AuraEnabled public Profile profile = new Profile();
        @AuraEnabled public Boolean isBuyer = false;
        @AuraEnabled public List<Holding> holdings = new List<Holding>();
        @AuraEnabled public List<Instalment> dues = new List<Instalment>();
        @AuraEnabled public List<Item> receipts = new List<Item>();
        @AuraEnabled public List<Item> opportunities = new List<Item>();
        @AuraEnabled public List<Item> siteVisits = new List<Item>();
        @AuraEnabled public List<Item> enquiries = new List<Item>();
        @AuraEnabled public List<Item> cases = new List<Item>();
        @AuraEnabled public List<Alert> alerts = new List<Alert>();
        // Full lists for the Customer 360 tabs.
        @AuraEnabled public List<CaseRow> allCases = new List<CaseRow>();
        @AuraEnabled public List<Invoice> invoices = new List<Invoice>();
        @AuraEnabled public List<Payment> payments = new List<Payment>();
        @AuraEnabled public List<Instalment> allDues = new List<Instalment>();
        @AuraEnabled public Integer openCases = 0;
        @AuraEnabled public Decimal invoicedTotal = 0;
        @AuraEnabled public Decimal invoiceBalance = 0;
        @AuraEnabled public Integer overdueInvoices = 0;

        // Summary numbers for the top cards.
        @AuraEnabled public Decimal portfolioValue = 0;
        @AuraEnabled public Decimal paidToDate = 0;
        @AuraEnabled public Decimal pendingReceipts = 0;
        @AuraEnabled public Decimal overdueAmount = 0;
        @AuraEnabled public Integer overdueCount = 0;
        @AuraEnabled public Date oldestOverdue;
        @AuraEnabled public Instalment nextDue;
        @AuraEnabled public Decimal pipelineValue = 0;
        @AuraEnabled public Integer openOpportunities = 0;
        @AuraEnabled public Item lastSiteVisit;
        @AuraEnabled public Item lastReceipt;
    }

    @AuraEnabled(cacheable=true)
    public static Customer getCustomer(Id accountId) {
        try {
            Customer c = new Customer();
            loadProfile(c, accountId);
            Set<Id> bookingIds = loadHoldings(c, accountId);
            loadDues(c, bookingIds);
            loadReceipts(c, accountId);
            Set<Id> opportunityIds = loadOpportunities(c, accountId);
            Set<Id> leadIds = loadEnquiries(c, accountId);
            loadSiteVisits(c, opportunityIds, leadIds);
            loadCases(c, accountId);
            loadInvoices(c, accountId, bookingIds);
            loadAlerts(c, accountId, bookingIds);
            return c;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void loadProfile(Customer c, Id accountId) {
        Account a = [
            SELECT Name, Phone, PersonMobilePhone, PersonEmail, PersonMailingCity, BillingCity,
                   Owner.Name, CreatedDate, IsPersonAccount
            FROM Account WHERE Id = :accountId
        ];
        c.profile.name = a.Name;
        c.profile.mobile = a.PersonMobilePhone;
        c.profile.phone = a.Phone;
        c.profile.email = a.PersonEmail;
        c.profile.city = String.isNotBlank(a.PersonMailingCity) ? a.PersonMailingCity : a.BillingCity;
        c.profile.owner = a.Owner.Name;
        c.profile.customerSince = a.CreatedDate.date();
    }

    private static Set<Id> loadHoldings(Customer c, Id accountId) {
        Set<Id> ids = new Set<Id>();
        Map<Id, Holding> byBooking = new Map<Id, Holding>();
        for (Booking__c b : [
            SELECT Id, Name, Account_Id__c, Unit_Id__c, Unit_Id__r.Name, Unit_Id__r.BHK_Configuration__c,
                   Unit_Id__r.Saleable_Area__c, Project__r.Name, Unit_Id__r.Tower__r.Name, Status__c,
                   Final_Amount__c, Booking_Date__c, Possession_Date__c, Payment_Plan_Id__r.Name,
                   Is_Agreement_Signed__c, Ownership_Transfer_In_Progress__c, CreatedDate
            FROM Booking__c
            WHERE Account_Id__c = :accountId
               OR Co_Applicant_1__c = :accountId OR Co_Applicant_2__c = :accountId
               OR Co_Applicant_3__c = :accountId OR Co_Applicant_4__c = :accountId
               OR Co_Applicant_5__c = :accountId
            ORDER BY CreatedDate DESC
        ]) {
            Holding h = new Holding();
            h.bookingId = b.Id;
            h.bookingName = b.Name;
            h.unitId = b.Unit_Id__c;
            h.unitName = b.Unit_Id__r?.Name;
            h.configuration = b.Unit_Id__r?.BHK_Configuration__c;
            h.area = b.Unit_Id__r?.Saleable_Area__c;
            h.project = b.Project__r?.Name;
            h.tower = b.Unit_Id__r?.Tower__r?.Name;
            h.status = b.Status__c;
            h.role = b.Account_Id__c == accountId ? 'Primary applicant' : 'Co-applicant';
            h.value = nz(b.Final_Amount__c);
            h.paid = 0;
            h.outstanding = 0;
            h.bookingDate = b.Booking_Date__c != null ? b.Booking_Date__c : b.CreatedDate.date();
            h.possessionDate = b.Possession_Date__c;
            h.paymentPlan = b.Payment_Plan_Id__r?.Name;
            h.agreementSigned = b.Is_Agreement_Signed__c;
            h.transferInProgress = b.Ownership_Transfer_In_Progress__c;
            c.holdings.add(h);
            byBooking.put(b.Id, h);
            ids.add(b.Id);
            c.portfolioValue += h.value;
        }
        c.isBuyer = !c.holdings.isEmpty();
        holdingsByBooking = byBooking;
        return ids;
    }

    // Shared between loaders within one request.
    private static Map<Id, Holding> holdingsByBooking = new Map<Id, Holding>();

    private static void loadDues(Customer c, Set<Id> bookingIds) {
        if (bookingIds.isEmpty()) {
            return;
        }
        Date today = Date.today();
        // Approved receipts tagged to an instalment count as paid even if the ledger hasn't allocated them yet.
        Map<Id, Decimal> receiptedBySchedule = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Booking_Payment_Schedule__c s, SUM(Amount_Paid__c) amt
            FROM Payment_Receipt__c
            WHERE Booking_Payment_Schedule__r.Booking__c IN :bookingIds AND Approval_Status__c = 'Approved'
            GROUP BY Booking_Payment_Schedule__c
        ]) {
            receiptedBySchedule.put((Id) ar.get('s'), nz((Decimal) ar.get('amt')));
        }
        for (Booking_Payment_Schedule__c s : [
            SELECT Id, Name, Booking__c, Booking__r.Name, Booking__r.Unit_Id__r.Name, Milestone_Code__c,
                   Installment_Number__c, Payment_Due_Date__c, Installment_Amount__c, Outstanding_Principal__c,
                   TotalPrincipalReceived__c, TotalInterestOutstandingnet__c
            FROM Booking_Payment_Schedule__c
            WHERE Booking__c IN :bookingIds
            ORDER BY Payment_Due_Date__c ASC NULLS LAST
        ]) {
            Decimal amount = nz(s.Installment_Amount__c);
            Decimal ledgerOutstanding = s.Outstanding_Principal__c != null
                ? s.Outstanding_Principal__c
                : amount - nz(s.TotalPrincipalReceived__c);
            Decimal receiptOutstanding = amount - (receiptedBySchedule.containsKey(s.Id) ? receiptedBySchedule.get(s.Id) : 0);
            Decimal outstanding = Math.max(0, Math.min(ledgerOutstanding, receiptOutstanding));
            Holding h = holdingsByBooking.get(s.Booking__c);
            if (h != null) {
                h.outstanding += outstanding;
                h.paid += amount - outstanding;
            }
            if (outstanding <= 0) {
                continue;
            }
            Instalment i = new Instalment();
            i.id = s.Id;
            i.name = s.Name;
            i.booking = s.Booking__r.Name;
            i.unit = s.Booking__r.Unit_Id__r?.Name;
            i.milestone = String.isNotBlank(s.Milestone_Code__c)
                ? s.Milestone_Code__c
                : (s.Installment_Number__c != null ? 'Instalment ' + s.Installment_Number__c.intValue() : s.Name);
            i.dueDate = s.Payment_Due_Date__c;
            i.amount = amount;
            i.outstanding = outstanding;
            i.interest = nz(s.TotalInterestOutstandingnet__c);
            i.overdue = s.Payment_Due_Date__c != null && s.Payment_Due_Date__c < today;
            if (i.overdue) {
                c.overdueAmount += outstanding;
                c.overdueCount++;
                if (c.oldestOverdue == null) {
                    c.oldestOverdue = i.dueDate;
                }
            } else if (c.nextDue == null) {
                c.nextDue = i;
            }
            if (c.dues.size() < MAX_ROWS) {
                c.dues.add(i);
            }
            if (c.allDues.size() < TAB_ROWS) {
                c.allDues.add(i);
            }
        }
    }

    private static void loadReceipts(Customer c, Id accountId) {
        for (Payment_Receipt__c r : [
            SELECT Id, Name, Amount_Paid__c, Date_Of_Payment__c, Mode_Of_Payment__c, Approval_Status__c,
                   Receipt_Status__c, CreatedDate, Transaction_Reference__c, ChequeNumber__c, Demand__r.Name,
                   Demand__r.Unit__r.Name, Booking_Payment_Schedule__r.Booking__r.Unit_Id__r.Name
            FROM Payment_Receipt__c
            WHERE Account__c = :accountId
            ORDER BY Date_Of_Payment__c DESC NULLS LAST, CreatedDate DESC
            LIMIT :TAB_ROWS
        ]) {
            Decimal amount = nz(r.Amount_Paid__c);
            if (r.Approval_Status__c == 'Approved') {
                c.paidToDate += amount;
            } else if (r.Approval_Status__c != 'Rejected') {
                c.pendingReceipts += amount;
            }
            Payment p = new Payment();
            p.id = r.Id;
            p.name = r.Name;
            p.paidOn = r.Date_Of_Payment__c != null ? r.Date_Of_Payment__c : r.CreatedDate.date();
            p.unit = r.Booking_Payment_Schedule__r?.Booking__r?.Unit_Id__r?.Name;
            if (p.unit == null) {
                p.unit = r.Demand__r?.Unit__r?.Name;
            }
            p.invoice = r.Demand__r?.Name;
            p.mode = r.Mode_Of_Payment__c;
            p.reference = String.isNotBlank(r.Transaction_Reference__c) ? r.Transaction_Reference__c : r.ChequeNumber__c;
            p.amount = amount;
            p.approval = r.Approval_Status__c;
            p.receiptStatus = r.Receipt_Status__c;
            c.payments.add(p);
            if (c.receipts.size() < MAX_ROWS) {
                Item i = new Item();
                i.id = r.Id;
                i.title = r.Name;
                i.subtitle = r.Mode_Of_Payment__c;
                i.status = r.Approval_Status__c;
                i.amount = amount;
                i.onDate = r.Date_Of_Payment__c != null ? r.Date_Of_Payment__c : r.CreatedDate.date();
                c.receipts.add(i);
            }
        }
        c.lastReceipt = c.receipts.isEmpty() ? null : c.receipts[0];
    }

    private static Set<Id> loadOpportunities(Customer c, Id accountId) {
        Set<Id> ids = new Set<Id>();
        for (Opportunity o : [
            SELECT Id, Name, StageName, IsClosed, IsWon, Total_Amount__c, Amount, CloseDate,
                   Interested_Unit__r.Name, Interested_Unit__r.BHK_Configuration__c, Discount_Approval_Status__c
            FROM Opportunity
            WHERE AccountId = :accountId
            ORDER BY IsClosed ASC, CloseDate DESC
            LIMIT 50
        ]) {
            ids.add(o.Id);
            if (o.IsClosed) {
                continue;
            }
            Decimal value = o.Total_Amount__c != null ? o.Total_Amount__c : nz(o.Amount);
            c.openOpportunities++;
            c.pipelineValue += value;
            if (c.opportunities.size() < MAX_ROWS) {
                Item i = new Item();
                i.id = o.Id;
                i.title = o.Interested_Unit__r != null
                    ? o.Interested_Unit__r.Name + (o.Interested_Unit__r.BHK_Configuration__c != null ? ' · ' + o.Interested_Unit__r.BHK_Configuration__c : '')
                    : o.Name;
                i.subtitle = o.Discount_Approval_Status__c != null && o.Discount_Approval_Status__c != 'Approval Not Required'
                    ? 'Discount ' + o.Discount_Approval_Status__c.toLowerCase()
                    : null;
                i.status = o.StageName;
                i.amount = value;
                i.onDate = o.CloseDate;
                c.opportunities.add(i);
            }
        }
        return ids;
    }

    private static Set<Id> loadEnquiries(Customer c, Id accountId) {
        Set<Id> ids = new Set<Id>();
        for (Lead l : [
            SELECT Id, Name, Projects__c, Type_of_Units__c, LeadSource, Lead_Subsource__c, Status, CreatedDate,
                   Approved_Channel_Partner__r.Name
            FROM Lead
            WHERE ConvertedAccountId = :accountId OR Existing_Customer__c = :accountId
            ORDER BY CreatedDate ASC
            LIMIT 20
        ]) {
            ids.add(l.Id);
            if (c.profile.source == null) {
                c.profile.source = l.LeadSource + (String.isNotBlank(l.Lead_Subsource__c) ? ' · ' + l.Lead_Subsource__c : '');
                c.profile.channelPartner = l.Approved_Channel_Partner__r?.Name;
            }
            if (c.enquiries.size() < MAX_ROWS) {
                Item i = new Item();
                i.id = l.Id;
                i.title = String.isNotBlank(l.Projects__c) ? l.Projects__c : l.Name;
                i.subtitle = joinParts(new List<String>{ l.Type_of_Units__c, l.LeadSource });
                i.status = l.Status;
                i.onDate = l.CreatedDate.date();
                c.enquiries.add(i);
            }
        }
        if (c.profile.source != null && c.profile.source.startsWith('null')) {
            c.profile.source = null;
        }
        return ids;
    }

    private static void loadSiteVisits(Customer c, Set<Id> opportunityIds, Set<Id> leadIds) {
        if (opportunityIds.isEmpty() && leadIds.isEmpty()) {
            return;
        }
        for (Site_Visit__c v : [
            SELECT Id, Name, Project__r.Name, Unit__r.Name, Status__c, Interest_Level__c, Visit_DateTime__c,
                   Visit_Date__c, Closing_Manager_Name__r.Name, CreatedDate
            FROM Site_Visit__c
            WHERE Opportunity__c IN :opportunityIds OR Lead__c IN :leadIds
            ORDER BY Visit_DateTime__c DESC NULLS LAST
            LIMIT :MAX_ROWS
        ]) {
            Item i = new Item();
            i.id = v.Id;
            i.title = joinParts(new List<String>{ v.Project__r?.Name, v.Unit__r?.Name });
            if (String.isBlank(i.title)) {
                i.title = 'Site visit';
            }
            i.subtitle = joinParts(new List<String>{
                v.Interest_Level__c == null ? null : v.Interest_Level__c + ' interest',
                v.Closing_Manager_Name__r?.Name
            });
            i.status = v.Status__c;
            i.at = v.Visit_DateTime__c;
            i.onDate = v.Visit_DateTime__c != null ? v.Visit_DateTime__c.date() : v.Visit_Date__c;
            c.siteVisits.add(i);
        }
        c.lastSiteVisit = c.siteVisits.isEmpty() ? null : c.siteVisits[0];
    }

    private static void loadCases(Customer c, Id accountId) {
        for (Case k : [
            SELECT Id, CaseNumber, Subject, Status, Priority, Type, IsClosed, CreatedDate, ClosedDate
            FROM Case
            WHERE AccountId = :accountId
            ORDER BY IsClosed ASC, CreatedDate DESC
            LIMIT :TAB_ROWS
        ]) {
            CaseRow row = new CaseRow();
            row.id = k.Id;
            row.caseNumber = k.CaseNumber;
            row.subject = String.isNotBlank(k.Subject) ? k.Subject : 'Case ' + k.CaseNumber;
            row.type = k.Type;
            row.priority = k.Priority;
            row.status = k.Status;
            row.closed = k.IsClosed;
            row.opened = k.CreatedDate.date();
            row.closedOn = k.ClosedDate?.date();
            c.allCases.add(row);
            if (k.IsClosed) {
                continue;
            }
            c.openCases++;
            if (c.cases.size() < MAX_ROWS) {
                Item i = new Item();
                i.id = k.Id;
                i.title = row.subject;
                i.subtitle = joinParts(new List<String>{ k.CaseNumber, k.Priority == null ? null : k.Priority + ' priority' });
                i.status = k.Status;
                i.onDate = row.opened;
                c.cases.add(i);
            }
        }
    }

    /** Demands raised on the customer's bookings: the customer's invoices. */
    private static void loadInvoices(Customer c, Id accountId, Set<Id> bookingIds) {
        Date today = Date.today();
        for (Demand__c d : [
            SELECT Id, Name, Unit__r.Name, Booking_Id__r.Unit_Id__r.Name, Milestone_Description__c, Due_Date__c,
                   DemandLetterSentDate__c, Demand_Amount__c, Total_Value__c, Invoice_Value__c,
                   Total_Amount_Recieved__c, Status__c, CreatedDate
            FROM Demand__c
            WHERE Account__c = :accountId OR Booking_Id__c IN :bookingIds
            ORDER BY Due_Date__c DESC NULLS LAST, CreatedDate DESC
            LIMIT :TAB_ROWS
        ]) {
            Invoice i = new Invoice();
            i.id = d.Id;
            i.name = d.Name;
            i.unit = d.Unit__r != null ? d.Unit__r.Name : d.Booking_Id__r?.Unit_Id__r?.Name;
            i.milestone = d.Milestone_Description__c;
            i.dueDate = d.Due_Date__c;
            i.sentOn = d.DemandLetterSentDate__c;
            i.amount = d.Total_Value__c != null ? d.Total_Value__c
                : d.Demand_Amount__c != null ? d.Demand_Amount__c : nz(d.Invoice_Value__c);
            i.received = nz(d.Total_Amount_Recieved__c);
            i.balance = Math.max(0, i.amount - i.received);
            i.status = d.Status__c;
            i.overdue = i.balance > 0 && d.Due_Date__c != null && d.Due_Date__c < today;
            c.invoicedTotal += i.amount;
            c.invoiceBalance += i.balance;
            if (i.overdue) {
                c.overdueInvoices++;
            }
            c.invoices.add(i);
        }
    }

    private static void loadAlerts(Customer c, Id accountId, Set<Id> bookingIds) {
        if (c.overdueCount > 0) {
            c.alerts.add(new Alert('negative', c.overdueCount + (c.overdueCount == 1 ? ' instalment' : ' instalments')
                + ' overdue since ' + Datetime.newInstance(c.oldestOverdue, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy')));
        }
        if (c.pendingReceipts > 0) {
            c.alerts.add(new Alert('warning', '₹' + c.pendingReceipts.setScale(0).format() + ' receipts awaiting approval'));
        }
        for (Holding h : c.holdings) {
            if (h.transferInProgress == true) {
                c.alerts.add(new Alert('info', h.unitName + ' transfer in progress'));
            }
        }
        if (c.openCases > 0) {
            c.alerts.add(new Alert('warning', c.openCases + ' open ' + (c.openCases == 1 ? 'case' : 'cases')));
        }
        if (!bookingIds.isEmpty()) {
            Integer waivers = [
                SELECT COUNT() FROM Interest_Waiver_Request__c
                WHERE Booking__c IN :bookingIds AND Status__c NOT IN ('Approved', 'Rejected')
            ];
            if (waivers > 0) {
                c.alerts.add(new Alert('info', waivers + ' interest waiver' + (waivers == 1 ? '' : 's') + ' pending'));
            }
        }
    }

    private static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }

    private static String joinParts(List<String> parts) {
        List<String> kept = new List<String>();
        for (String p : parts) {
            if (String.isNotBlank(p)) {
                kept.add(p);
            }
        }
        return String.join(kept, ' · ');
    }
}