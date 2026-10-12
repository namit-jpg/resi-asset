/**
 * Sends the Nikoo Homes Email Support Agent's reply to the customer who emailed in, and logs it on the case.
 * Called by the Nikoo_Email_Agent_Reply flow after "Invoke AI Agent" returns the reply text.
 */
// Runs in the flow's async context; access is scoped to the single case passed in.
public without sharing class ResiAgentSendReply {

    /** Customer-facing sender. Used when it is set up (and verified) as an organisation-wide email address. */
    public static final String REPLY_FROM = '03namit@gmail.com';

    public class Request {
        @InvocableVariable(required=true label='Case Id')
        public Id caseId;
        @InvocableVariable(required=true label='Reply Body' description='Reply text returned by the agent.')
        public String replyBody;
    }

    public class Result {
        @InvocableVariable(label='Sent')
        public Boolean sent;
        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(label='Send Agent Email Reply' description='Emails the agent reply to the case sender and records it on the case.' category='Nikoo Homes Agent')
    public static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        List<OrgWideEmailAddress> fromAddress = [
            SELECT Id FROM OrgWideEmailAddress WHERE Address = :REPLY_FROM LIMIT 1
        ];
        for (Request r : requests) {
            results.add(send(r, fromAddress.isEmpty() ? null : fromAddress[0].Id));
        }
        return results;
    }

    /** "Invoke AI Agent" returns {"type":"Text","value":"..."}; keep just the text. */
    @TestVisible
    private static String unwrap(String raw) {
        String text = raw == null ? '' : raw.trim();
        if (text.startsWith('{')) {
            try {
                Object value = ((Map<String, Object>) JSON.deserializeUntyped(text)).get('value');
                if (value instanceof String) {
                    text = ((String) value).trim();
                }
            } catch (Exception e) {
                // Not JSON after all; send as-is.
            }
        }
        return text;
    }

    private static Result send(Request r, Id orgWideId) {
        Result res = new Result();
        res.sent = false;
        String body = unwrap(r.replyBody);
        if (String.isBlank(body)) {
            res.message = 'Agent returned an empty reply; nothing sent.';
            return res;
        }
        Case c = [SELECT Id, CaseNumber, Subject, Status, SuppliedEmail, ContactId, Contact.Email FROM Case WHERE Id = :r.caseId];
        String recipient = String.isNotBlank(c.SuppliedEmail) ? c.SuppliedEmail : c.Contact?.Email;
        if (String.isBlank(recipient) || recipient.equalsIgnoreCase(REPLY_FROM)) {
            res.message = 'No customer address to reply to (or it is the routing address itself).';
            return res;
        }
        String subject = 'Re: ' + (String.isBlank(c.Subject) ? 'Your email to Nikoo Homes' : c.Subject) + ' [Case ' + c.CaseNumber + ']';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ recipient });
        if (c.ContactId != null) {
            // Lets Salesforce log the reply as an Email Message on the case (direct EmailMessage inserts are blocked here).
            mail.setTargetObjectId(c.ContactId);
            mail.setTreatTargetObjectAsRecipient(false);
            mail.setWhatId(c.Id);
            mail.setSaveAsActivity(true);
        }
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        if (orgWideId != null) {
            mail.setOrgWideEmailAddressId(orgWideId);
        }
        try {
            if (!Test.isRunningTest()) {
                try {
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
                } catch (EmailException e) {
                    // Until the org-wide address is verified, send from the running user's address instead.
                    if (orgWideId == null || !e.getMessage().contains('UNVERIFIED_SENDER_ADDRESS')) {
                        throw e;
                    }
                    mail.setOrgWideEmailAddressId(null);
                    mail.setSenderDisplayName('Nikoo Homes Customer Care');
                    mail.setReplyTo(REPLY_FROM);
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
                }
            }
            res.sent = true;
            res.message = 'Reply sent to ' + recipient + '.';
        } catch (Exception e) {
            res.message = 'Reply could not be sent: ' + e.getMessage();
        }
        // Without a contact the email is not auto-logged, and on failure nothing is; keep the reply on the case for the CRM team.
        if (c.ContactId == null || !res.sent) {
            insert new CaseComment(ParentId = c.Id, IsPublished = false,
                CommentBody = ('Agent reply ' + (res.sent ? 'sent to ' + recipient : 'NOT sent: ' + res.message) + '\n\n' + body).abbreviate(4000));
        }
        // The agent answered on its own; an escalated case stays with the CRM team.
        if (res.sent && c.Status != ResiAgentService.STATUS_ESCALATED) {
            update new Case(Id = c.Id, Status = ResiAgentService.STATUS_RESOLVED);
        }
        return res;
    }
}