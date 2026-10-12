global class RoundRobinAsyncUtils {

    private static final String COMPONENT = 'RoundRobinAsyncUtils';
    private static final String DOMAIN = 'Assignment';
    private static final String INTEGRATION = 'Internal';

    @future
    public static void createMissingAssignees(List<Id> userIds) {
        final String METHOD = 'createMissingAssignees';
        try {
            Set<Id> userIdSet = new Set<Id>(userIds);

            Set<Id> existing = new Set<Id>();
            for (Round_Robin_Assignee__c rra : [
                SELECT UserId__c FROM Round_Robin_Assignee__c WHERE UserId__c IN :userIdSet ]) { existing.add(rra.UserId__c); }

            List<Round_Robin_Assignee__c> toInsert = new List<Round_Robin_Assignee__c>();
            for (Id uid : userIdSet) {
                if (!existing.contains(uid)) {
                    toInsert.add(new Round_Robin_Assignee__c(
                        UserId__c = uid,
                        Is_Active__c = true,
                        Weight__c = 1,
                        Max_Leads_Per_Day__c = 10,
                        Assigned_Today__c = 0,
                        Last_Assigned_Count__c = 0
                    ));
                }
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withRequestBody('userIds=' + String.valueOf(userIds)).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withException(ex)
            );
        }
    }

    global class RoundRobinResetScheduler implements Schedulable {
        global void execute(SchedulableContext sc) {
            final String METHOD = 'RoundRobinResetScheduler.execute';
            try {
                Date today = Date.today();

                List<Round_Robin_Assignee__c> toReset = [
                    SELECT Id, Assigned_Today__c, Last_Assignment_Date__c
                    FROM Round_Robin_Assignee__c
                    WHERE Last_Assignment_Date__c != :today
                ];

                for (Round_Robin_Assignee__c a : toReset) {
                    a.Assigned_Today__c = 0;
                    a.Last_Assignment_Date__c = today;
                }

                if (!toReset.isEmpty()) {
                    update toReset;
                }

                System.debug('Round Robin assignee counts reset for ' + toReset.size() + ' users.');
            } catch (Exception ex) {
                ExceptionLogger.logException(
                    new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withException(ex)
                );
            }
        }
    }

    global class RoundRobinInactiveLeadReassignmentJob implements Schedulable {
        Id leadId;

        public RoundRobinInactiveLeadReassignmentJob() {}

        public RoundRobinInactiveLeadReassignmentJob(Id leadId) {
            this.leadId = leadId;
        }

        global void execute(SchedulableContext ctx) {
            execute(ctx, false);
        }

        @TestVisible
        global void execute(SchedulableContext ctx, Boolean ignoreLastModified) {
            final String METHOD = 'RoundRobinInactiveLeadReassignmentJob.execute';
            Lead l = [SELECT Id, LastModifiedDate, Status, OwnerId FROM Lead WHERE Id = :leadId LIMIT 1];
            if (l.Status == 'Converted' || (!ignoreLastModified && l.LastModifiedDate > DateTime.now().addDays(-1))) return;
            RoundRobinAssignHelper.assignLead(l, null);
        }
    }
}