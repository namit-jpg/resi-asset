/**
 * Agent action "Escalate To CRM Team" – the residential equivalent of v10's Handle Fraud Escalation.
 * Marks the email case COMPLEX, opens a child case in the Nikoo CRM Escalations queue and returns the
 * only reply the agent may send: a neutral acknowledgement with the reference number.
 */
// Runs as the Einstein agent user; access is scoped by matching the case sender to the customer, not by sharing.
public without sharing class ResiAgentEscalateCase {

    public class Request {
        @InvocableVariable(required=true label='Case Id' description='Id of the email Case (emailCaseId).')
        public Id caseId;
        @InvocableVariable(label='Reason' description='One of: Legal or RERA complaint, Cancellation or refund, Possession delay or compensation, Payment dispute, Fraud or unauthorised transaction, Construction quality, Ownership transfer, Other.')
        public String reason;
        @InvocableVariable(label='Summary' description='Two or three sentences summarising what the customer wants, for the CRM executive.')
        public String summary;
    }

    public class Result {
        @InvocableVariable(label='Escalation Case Number' description='Case number of the escalation assigned to the CRM team.')
        public String escalationCaseNumber;
        @InvocableVariable(label='Acknowledgement' description='The exact reply to send the customer. Send it as-is and nothing else.')
        public String acknowledgement;
    }

    private static final Set<String> REASONS = new Set<String>{
        'Legal or RERA complaint', 'Cancellation or refund', 'Possession delay or compensation', 'Payment dispute',
        'Fraud or unauthorised transaction', 'Construction quality', 'Ownership transfer', 'Other'
    };

    @InvocableMethod(label='Escalate To CRM Team' description='Hands the email case to the human CRM team: marks it COMPLEX, creates an escalation case in the Nikoo CRM Escalations queue and returns the acknowledgement to send the customer.' category='Nikoo Homes Agent')
    public static List<Result> run(List<Request> requests) {
        Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :ResiAgentService.ESCALATION_QUEUE LIMIT 1];
        List<Result> results = new List<Result>();
        for (Request r : requests) {
            ResiAgentService.CustomerContext ctx = ResiAgentService.resolveCustomer(r.caseId);
            Case parent = ctx.caseRecord;
            String reason = REASONS.contains(r.reason) ? r.reason
                : (String.isNotBlank(parent.Escalation_Reason__c) ? parent.Escalation_Reason__c : 'Other');
            String subject = String.isBlank(parent.Subject) ? 'customer email' : parent.Subject;

            Case child = new Case(
                ParentId = parent.Id,
                Subject = ('Escalated: ' + reason + ' – ' + subject).abbreviate(255),
                Description = (String.isBlank(r.summary) ? '' : 'Agent summary: ' + r.summary + '\n\n')
                    + 'Original email (case ' + parent.CaseNumber + ') from ' + parent.SuppliedEmail + ':\n' + parent.Description,
                Case_Classification__c = ResiAgentService.COMPLEX,
                Escalation_Reason__c = reason,
                Origin = parent.Origin,
                Priority = reason == 'Legal or RERA complaint' || reason == 'Fraud or unauthorised transaction' ? 'High' : 'Medium',
                OwnerId = queue.Id,
                AccountId = ctx.found ? ctx.account.Id : parent.AccountId,
                ContactId = ctx.found && ctx.account.PersonContactId != null ? ctx.account.PersonContactId : parent.ContactId
            );
            insert child;
            update new Case(Id = parent.Id, Case_Classification__c = ResiAgentService.COMPLEX, Escalation_Reason__c = reason,
                AccountId = child.AccountId, Status = ResiAgentService.STATUS_ESCALATED);

            String caseNo = [SELECT CaseNumber FROM Case WHERE Id = :child.Id].CaseNumber;
            String name = ctx.found ? (String.isNotBlank(ctx.account.FirstName) ? ctx.account.FirstName : ctx.account.Name) : null;
            Result res = new Result();
            res.escalationCaseNumber = caseNo;
            res.acknowledgement = 'Dear ' + (name == null ? 'Customer' : name) + ',\n\n'
                + 'Thank you for writing to us. Your request has been passed to our CRM team under reference ' + caseNo
                + '. A CRM executive will contact you within 2 working days.\n\n'
                + 'Warm regards,\nCRM Team, Nikoo Homes';
            results.add(res);
        }
        return results;
    }
}