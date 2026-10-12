/**
 * Shared data access for the Nikoo Homes Email Support Agent actions (ResiAgent* invocables).
 * Every action starts from the email Case, resolves the customer from the sender's address and only
 * ever returns data for bookings that belong to that customer.
 */
// Runs as the Einstein agent user; access is scoped by matching the case sender to the customer, not by sharing.
public without sharing class ResiAgentService {

    public static final String COMPLEX = 'COMPLEX';
    public static final String SIMPLE = 'SIMPLE';
    public static final String ESCALATION_QUEUE = 'Nikoo_CRM_Escalations';

    // Case stages the agent moves an email case through: New -> Agent Working -> Resolved | Escalated to Human.
    public static final String STATUS_AGENT_WORKING = 'Agent Working';
    public static final String STATUS_RESOLVED = 'Resolved';
    public static final String STATUS_ESCALATED = 'Escalated to Human';

    public class CustomerContext {
        public Case caseRecord;
        public Account account;
        public String email;
        public Boolean found = false;
    }

    public static Case getCase(Id caseId) {
        return [
            SELECT Id, CaseNumber, Subject, Description, SuppliedEmail, SuppliedName, AccountId, ContactId, OwnerId,
                   Case_Classification__c, Escalation_Reason__c, Origin
            FROM Case WHERE Id = :caseId
        ];
    }

    /** Finds the buyer by the case's sender address (person account email, then contact email) and links the case. */
    public static CustomerContext resolveCustomer(Id caseId) {
        CustomerContext ctx = new CustomerContext();
        ctx.caseRecord = getCase(caseId);
        ctx.email = ctx.caseRecord.SuppliedEmail;

        if (ctx.caseRecord.AccountId != null) {
            ctx.account = loadAccount(ctx.caseRecord.AccountId);
        } else if (String.isNotBlank(ctx.email)) {
            List<Account> byPersonEmail = [
                SELECT Id FROM Account WHERE IsPersonAccount = true AND PersonEmail = :ctx.email ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (!byPersonEmail.isEmpty()) {
                ctx.account = loadAccount(byPersonEmail[0].Id);
            } else {
                List<Contact> byContactEmail = [
                    SELECT AccountId FROM Contact WHERE Email = :ctx.email AND AccountId != null ORDER BY CreatedDate DESC LIMIT 1
                ];
                if (!byContactEmail.isEmpty()) {
                    ctx.account = loadAccount(byContactEmail[0].AccountId);
                }
            }
        }
        ctx.found = ctx.account != null;
        return ctx;
    }

    /** Links the case to the customer so the CRM team sees it on the account. */
    public static void linkCase(CustomerContext ctx) {
        if (!ctx.found || ctx.caseRecord.AccountId == ctx.account.Id) {
            return;
        }
        Case c = new Case(Id = ctx.caseRecord.Id, AccountId = ctx.account.Id);
        if (ctx.account.PersonContactId != null) {
            c.ContactId = ctx.account.PersonContactId;
        }
        update c;
    }

    private static Account loadAccount(Id accountId) {
        return [
            SELECT Id, Name, FirstName, PersonEmail, PersonMobilePhone, Phone, PersonContactId, IsPersonAccount, Owner.Name, Owner.Email
            FROM Account WHERE Id = :accountId
        ];
    }

    public static List<Booking__c> bookingsFor(Id accountId) {
        return [
            SELECT Id, Name, Status__c, Final_Amount__c, Token_Amount__c, Booking_Date__c, CreatedDate, Possession_Date__c,
                   Agreement_Executed_Date__c, Agreement_Registered_Date__c, Allotment_Letter_Date__c, Is_Agreement_Signed__c,
                   Allotment_Shared__c, Ownership_Transfer_In_Progress__c, Funding_Method__c, HomeLoanBank__c,
                   Loan_Sanctioned_Amount__c, Payment_Plan_Id__r.Name, Project__r.Name,
                   Unit_Id__c, Unit_Id__r.Name, Unit_Id__r.BHK_Configuration__c, Unit_Id__r.Saleable_Area__c,
                   Unit_Id__r.Carpet_Area__c, Unit_Id__r.Tower__r.Name, Unit_Id__r.Floor__r.Name, Account_Id__c
            FROM Booking__c
            WHERE Account_Id__c = :accountId
               OR Co_Applicant_1__c = :accountId OR Co_Applicant_2__c = :accountId OR Co_Applicant_3__c = :accountId
               OR Co_Applicant_4__c = :accountId OR Co_Applicant_5__c = :accountId
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * Picks the booking the customer is asking about. Accepts a booking number (BO-00000013) or unit number
     * (SS-SK1-700); with a single booking on file the reference is optional. Returns null when ambiguous or not theirs.
     */
    public static Booking__c pickBooking(List<Booking__c> bookings, String reference) {
        if (String.isBlank(reference)) {
            return bookings.size() == 1 ? bookings[0] : null;
        }
        String ref = reference.trim().toUpperCase();
        for (Booking__c b : bookings) {
            if (b.Name.toUpperCase() == ref || (b.Unit_Id__r != null && b.Unit_Id__r.Name.toUpperCase() == ref)) {
                return b;
            }
        }
        for (Booking__c b : bookings) {
            if (ref.contains(b.Name.toUpperCase()) || (b.Unit_Id__r != null && ref.contains(b.Unit_Id__r.Name.toUpperCase()))) {
                return b;
            }
        }
        return null;
    }

    public static String bookingLine(Booking__c b) {
        return b.Name + ' – Unit ' + b.Unit_Id__r?.Name + ' (' + join(new List<String>{
            b.Unit_Id__r?.BHK_Configuration__c, b.Project__r?.Name, b.Unit_Id__r?.Tower__r?.Name
        }, ', ') + '), status: ' + b.Status__c;
    }

    // ---------- formatting ----------

    /** Indian grouping, e.g. 4275000 -> ₹42,75,000. */
    public static String inr(Decimal amount) {
        if (amount == null) {
            return '₹0';
        }
        Long rupees = amount.setScale(0, RoundingMode.HALF_UP).longValue();
        Boolean negative = rupees < 0;
        String digits = String.valueOf(Math.abs(rupees));
        String result;
        if (digits.length() <= 3) {
            result = digits;
        } else {
            String last3 = digits.substring(digits.length() - 3);
            String rest = digits.substring(0, digits.length() - 3);
            // Lakh/crore grouping: pairs of digits from the right, before the last three.
            List<String> groups = new List<String>();
            if (Math.mod(rest.length(), 2) == 1) {
                groups.add(rest.substring(0, 1));
                rest = rest.substring(1);
            }
            for (Integer i = 0; i < rest.length(); i += 2) {
                groups.add(rest.substring(i, i + 2));
            }
            result = String.join(groups, ',') + ',' + last3;
        }
        return (negative ? '-₹' : '₹') + result;
    }

    /** dd MMM yyyy, per org standard. */
    public static String fmt(Date d) {
        return d == null ? 'not scheduled' : Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('dd MMM yyyy');
    }

    public static String join(List<String> parts, String sep) {
        List<String> kept = new List<String>();
        for (String p : parts) {
            if (String.isNotBlank(p)) {
                kept.add(p);
            }
        }
        return String.join(kept, sep);
    }

    public static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }
}