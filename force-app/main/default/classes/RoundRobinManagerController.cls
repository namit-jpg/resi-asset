public with sharing class RoundRobinManagerController {

    private static final String COMPONENT = 'RoundRobinManagerController';
    private static final String DOMAIN = 'Assignment';
    private static final String INTEGRATION = 'Internal'; 

    @AuraEnabled
    public static List<IdLabelWrapper> getQueues() {
        final String METHOD = 'getQueues';
        try {
            List<Group> queues = [
                SELECT Id, Name
                FROM Group
                WHERE Id IN (
                    SELECT QueueId FROM QueueSobject WHERE SObjectType = 'Lead'
                )
            ];

            List<IdLabelWrapper> results = new List<IdLabelWrapper>();
            for (Group g : queues) {
                results.add(new IdLabelWrapper(g.Id, g.Name.replace('_', ' ')));
            }
            return results;

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withDescription('Failed to fetch Lead queues').withException(ex)
            );
            return new List<IdLabelWrapper>();
        }
    }

    @AuraEnabled
    public static List<IdLabelWrapper> getAllUsers() {
        final String METHOD = 'getAllUsers';
        try {
            List<User> users = [SELECT Id, Name FROM User WHERE IsActive = TRUE];
            List<IdLabelWrapper> result = new List<IdLabelWrapper>();
            for (User u : users) {
                result.add(new IdLabelWrapper(u.Id, u.Name));
            }
            return result;

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withDescription('Failed to fetch active users').withException(ex)
            );
            return new List<IdLabelWrapper>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Id> getUsersInQueue(Id queueId) {
        final String METHOD = 'getUsersInQueue';
        try {
            List<GroupMember> members = [
                SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :queueId
            ];
            Set<Id> userIds = new Set<Id>();
            for (GroupMember gm : members) {
                if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                    userIds.add(gm.UserOrGroupId);
                }
            }
            return new List<Id>(userIds);

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withRequestBody('queueId=' + String.valueOf(queueId)).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withDescription('Failed to fetch users in queue').withException(ex)
            );
            return new List<Id>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<AssigneeWrapper> getAssigneeRecords() {
        final String METHOD = 'getAssigneeRecords';
        try {
            List<Round_Robin_Assignee__c> records = [
                SELECT Id, UserId__c, UserId__r.Name, Is_Active__c, Is_On_Leave__c, Max_Leads_Per_Day__c,
                       Last_Assigned_Count__c, Last_Assignment_Date__c, Assigned_Today__c,
                       Region__c, Weight__c, Notes__c
                FROM Round_Robin_Assignee__c
            ];

            List<AssigneeWrapper> output = new List<AssigneeWrapper>();
            for (Round_Robin_Assignee__c rra : records) {
                output.add(new AssigneeWrapper(rra));
            }
            return output;

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withDescription('Failed to fetch Round Robin Assignees').withException(ex)
            );
            return new List<AssigneeWrapper>();
        }
    }

    @AuraEnabled
    public static void updateQueueMembers(Id queueId, List<Id> userIds) {
        final String METHOD = 'updateQueueMembers';
        try {
            if (queueId == null || userIds == null) return;

            List<GroupMember> currentMembers = [SELECT Id FROM GroupMember WHERE GroupId = :queueId];
            delete currentMembers;

            List<GroupMember> newMembers = new List<GroupMember>();
            for (Id userId : userIds) {
                newMembers.add(new GroupMember(GroupId = queueId, UserOrGroupId = userId));
            }
            insert newMembers;

            RoundRobinAsyncUtils.createMissingAssignees(userIds);

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withRequestBody('queueId=' + queueId + ', userIds=' + String.valueOf(userIds)).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withDescription('Failed to update queue members').withException(ex)
            );
        }
    }

    @AuraEnabled
    public static void updateAssigneeRecords(List<AssigneeWrapper> assignees) {
        final String METHOD = 'updateAssigneeRecords';
        try {
            List<Round_Robin_Assignee__c> toUpdate = new List<Round_Robin_Assignee__c>();
            for (AssigneeWrapper wrap : assignees) {
                toUpdate.add(new Round_Robin_Assignee__c(
                    Id = wrap.Id,
                    Is_Active__c = wrap.isActive,
                    Is_On_Leave__c = wrap.isOnLeave,
                    Max_Leads_Per_Day__c = wrap.maxLeadsPerDay,
                    Region__c = wrap.region,
                    Weight__c = wrap.weight,
                    Notes__c = wrap.notes
                ));
            }
            update toUpdate;

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withDescription('Failed to update Assignee records').withRequestBody('assignees=' + String.valueOf(assignees)).withException(ex)
            );
        }
    }

    @AuraEnabled
    public static void ensureAssigneesExistForUsers() {
        final String METHOD = 'ensureAssigneesExistForUsers';
        try {
            List<User> users = [SELECT Id FROM User WHERE IsActive = TRUE];
            Set<Id> allUserIds = new Set<Id>();
            for (User u : users) {
                allUserIds.add(u.Id);
            }

            Set<Id> existingAssigneeUserIds = new Set<Id>();
            for (Round_Robin_Assignee__c rra : [
                SELECT UserId__c FROM Round_Robin_Assignee__c WHERE UserId__c IN :allUserIds
            ]) {
                existingAssigneeUserIds.add(rra.UserId__c);
            }

            Set<Id> usersInQueues = new Set<Id>();
            List<Group> leadQueues = [
                SELECT Id FROM Group WHERE Id IN (
                    SELECT QueueId FROM QueueSobject WHERE SObjectType = 'Lead'
                )
            ];
            List<GroupMember> members = [
                SELECT UserOrGroupId FROM GroupMember WHERE GroupId IN :leadQueues
            ];
            for (GroupMember gm : members) {
                if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                    usersInQueues.add(gm.UserOrGroupId);
                }
            }

            allUserIds.removeAll(existingAssigneeUserIds);
            if (allUserIds.isEmpty()) return;

            List<Round_Robin_Assignee__c> newAssignees = new List<Round_Robin_Assignee__c>();
            for (Id userId : allUserIds) {
                Boolean isActive = usersInQueues.contains(userId);
                newAssignees.add(new Round_Robin_Assignee__c(
                    UserId__c = userId,
                    Is_Active__c = isActive,
                    Is_On_Leave__c = false,
                    Max_Leads_Per_Day__c = 0,
                    Weight__c = 1,
                    Assigned_Today__c = 0,
                    Last_Assigned_Count__c = 0
                ));
            }
            insert newAssignees;

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(COMPONENT).withMethodName(METHOD).withDomain(DOMAIN).withIntegrationType(INTEGRATION).withErrorType('Unhandled Exception').withDescription('Failed to ensure assignees exist for users').withException(ex)
            );
        }
    }

    // === Wrappers ===
    public class IdLabelWrapper {
        @AuraEnabled public Id value;
        @AuraEnabled public String label;

        public IdLabelWrapper(Id id, String label) {
            this.value = id;
            this.label = label;
        }
    }

    public class AssigneeWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String userId;
        @AuraEnabled public String userName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Boolean isOnLeave;
        @AuraEnabled public Decimal maxLeadsPerDay;
        @AuraEnabled public Decimal weight;
        @AuraEnabled public String region;
        @AuraEnabled public String notes;
        @AuraEnabled public Decimal lastAssignedCount;
        @AuraEnabled public Date lastAssignmentDate;
        @AuraEnabled public Decimal assignedToday;

        public AssigneeWrapper(Round_Robin_Assignee__c rra) {
            this.Id = rra.Id;
            this.userId = rra.UserId__c;
            this.userName = rra.UserId__r != null ? rra.UserId__r.Name : null;
            this.isActive = rra.Is_Active__c;
            this.isOnLeave = rra.Is_On_Leave__c;
            this.maxLeadsPerDay = rra.Max_Leads_Per_Day__c;
            this.weight = rra.Weight__c;
            this.region = rra.Region__c;
            this.notes = rra.Notes__c;
            this.lastAssignedCount = rra.Last_Assigned_Count__c;
            this.lastAssignmentDate = rra.Last_Assignment_Date__c;
            this.assignedToday = rra.Assigned_Today__c;
        }
    }
}