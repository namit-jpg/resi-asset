public with sharing class RoundRobinAssignHelper {

    // ======================
    // Main Assignment Method
    // ======================
    public static void assignLead(Lead leadRecord, Set<Id> limitToUserIds, Boolean isScheduledJob) {
        final String COMPONENT = 'RoundRobinAssignHelper';
        final String CLASS_NAME = 'RoundRobinAssignHelper';
        final String METHOD_NAME = 'assignLead';

        try {
            if (leadRecord == null || leadRecord.Id == null) { throw new AuraHandledException('Lead record not found.'); }

            // 1️⃣ Check if queue members list is provided but empty
            if (limitToUserIds != null && limitToUserIds.isEmpty()) { throw new AuraHandledException('No users found in the selected queue.'); }

            Round_Robin_Settings__mdt settings = Round_Robin_Settings__mdt.getInstance('Default_Settings');
            Boolean useRegion = settings != null && settings.Enable_Region_Filter__c;
            Boolean useThrottling = settings != null && settings.Enable_Throttling__c;
            Boolean useWeighted = settings != null && settings.Enable_Weighted__c;
            Id fallbackOwnerId = settings != null ? (Id)settings.Fallback_Owner_Id__c : null;
            Date today = Date.today();

            // Step 1: Get eligible assignees
            List<Round_Robin_Assignee__c> assignees;
            if (limitToUserIds != null && !limitToUserIds.isEmpty()) {
                assignees = [
                    SELECT Id, UserId__c, Is_Active__c, Is_On_Leave__c, Region__c,
                           Last_Assigned_Count__c, Assigned_Today__c, Last_Assignment_Date__c,
                           Max_Leads_Per_Day__c, Weight__c
                    FROM Round_Robin_Assignee__c
                    WHERE Is_Active__c = TRUE AND Is_On_Leave__c = FALSE AND UserId__c != NULL AND UserId__c IN :limitToUserIds
                ];
            } else {
                assignees = [
                    SELECT Id, UserId__c, Is_Active__c, Is_On_Leave__c, Region__c,
                           Last_Assigned_Count__c, Assigned_Today__c, Last_Assignment_Date__c,
                           Max_Leads_Per_Day__c, Weight__c
                    FROM Round_Robin_Assignee__c
                    WHERE Is_Active__c = TRUE
                      AND Is_On_Leave__c = FALSE
                      AND UserId__c != NULL
                ];
            }

            // Step 2: Filter active users and skip last owner
            Set<Id> userIds = new Set<Id>();
            for (Round_Robin_Assignee__c a : assignees) userIds.add(a.UserId__c);

            Map<Id, User> activeUsers = new Map<Id, User>(
                [SELECT Id FROM User WHERE Id IN :userIds AND IsActive = TRUE]
            );

            Id oldOwnerId = leadRecord.OwnerId;
            List<Round_Robin_Assignee__c> eligibleAssignees = new List<Round_Robin_Assignee__c>();
            for (Round_Robin_Assignee__c a : assignees) {
                if (activeUsers.containsKey(a.UserId__c) && a.UserId__c != oldOwnerId) {
                    eligibleAssignees.add(a);
                }
            }

            // 2️⃣ Throw if no active users remain
            if (eligibleAssignees.isEmpty()) { throw new AuraHandledException('No eligible active users available for assignment.'); }

            // Step 3: Sort & build weighted pool
            eligibleAssignees.sort(new AssigneeComparator());
            List<Round_Robin_Assignee__c> pool = new List<Round_Robin_Assignee__c>();
            for (Round_Robin_Assignee__c a : eligibleAssignees) {
                Integer w = (a.Weight__c == null || a.Weight__c < 1) ? 1 : (useWeighted ? (Integer)Math.floor(a.Weight__c) : 1);
                for (Integer i = 0; i < w; i++) pool.add(a);
            }

            // Step 4: Try assignment
            Integer index = 0, total = pool.size(), attempts = 0;
            Boolean assigned = false;
            Map<Id, Round_Robin_Assignee__c> updates = new Map<Id, Round_Robin_Assignee__c>();
            String leadRegion = useRegion ? leadRecord.Region__c : null;
            Id newOwnerId;

            while (!assigned && attempts < total) {
                Round_Robin_Assignee__c assignee = pool[index];

                if (useRegion && leadRegion != null && assignee.Region__c != null && assignee.Region__c != leadRegion) { index = Math.mod(index + 1, total); attempts++; continue; }

                if (assignee.Last_Assignment_Date__c != today) {
                    assignee.Assigned_Today__c = 0;
                    assignee.Last_Assignment_Date__c = today;
                }

                Decimal defaultMax = (settings != null && settings.Default_Max_Lead_Per_Day__c != null) 
                    ? settings.Default_Max_Lead_Per_Day__c : 10;
                Decimal max = (assignee.Max_Leads_Per_Day__c == null || assignee.Max_Leads_Per_Day__c == 0) ? defaultMax : assignee.Max_Leads_Per_Day__c;

                Decimal todayCount = assignee.Assigned_Today__c != null ? assignee.Assigned_Today__c : 0;
                Decimal lastAssignedCount = assignee.Last_Assigned_Count__c != null ? assignee.Last_Assigned_Count__c : 0;

                if (!useThrottling || todayCount < max) {
                    leadRecord.OwnerId = assignee.UserId__c;
                    newOwnerId = assignee.UserId__c;
                    assignee.Assigned_Today__c = todayCount + 1;
                    assignee.Last_Assigned_Count__c = lastAssignedCount + 1;
                    updates.put(assignee.Id, assignee);
                    assigned = true;
                }

                index = Math.mod(index + 1, total);
                attempts++;
            }

            if (!assigned) {
                if (fallbackOwnerId != null) {
                    leadRecord.OwnerId = fallbackOwnerId;
                    newOwnerId = fallbackOwnerId;
                    leadRecord.Status = 'Allocated';
                } else {
                    throw new AuraHandledException('All eligible users have reached their daily assignment limit.');
                }
            }
            
            if (assigned) { leadRecord.Status = 'Allocated'; }
            update leadRecord;
            if (!updates.isEmpty()) update updates.values();

            // ✅ Schedule or replace inactivity job
            if (assigned) {
                scheduleInactivityCheck(leadRecord.Id);
                if(isScheduledJob) {
					createAssignmentTask(leadRecord.Id, oldOwnerId, newOwnerId, isScheduledJob);
                }
                sendCustomNotification(newOwnerId, leadRecord.Id);
            }

        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName(COMPONENT).withClassName(CLASS_NAME).withMethodName(METHOD_NAME).withRequestBody('LeadId: ' + (leadRecord != null ? leadRecord.Id : null) + ', LimitToUserIds: ' + limitToUserIds).withDomain('Assignment').withIntegrationType('Internal').withErrorType('Unhandled Exception').withException(ex)
            );

            if (ex instanceof AuraHandledException) throw ex;
            else throw new AuraHandledException(ex.getMessage());
        }
    }

    // ======================
    // Overload for backward compatibility
    // ======================
    public static void assignLead(Lead leadRecord, Set<Id> limitToUserIds) {
        assignLead(leadRecord, limitToUserIds, false);
    }

    // ======================
    // Create Task
    // ======================
    @TestVisible
    private static void createAssignmentTask(Id leadId, Id oldOwnerId, Id newOwnerId, Boolean isScheduledJob) {
        try {
            // Fetch Lead, Old Owner (if not Queue), New Owner
            Lead lead = [SELECT Id, LeadSource FROM Lead WHERE Id = :leadId];
            
            // Check if newOwnerId is a Queue
            Boolean isNewOwnerQueue = String.valueOf(newOwnerId).startsWith('00G');
            if (isNewOwnerQueue) return; // Condition 5: Owner is a queue → skip
            
            // Get new and old owner users (only if they're not queues)
            User newOwner = [SELECT Id, Name, UserRole.DeveloperName FROM User WHERE Id = :newOwnerId];
            User oldOwner = oldOwnerId != null && !String.valueOf(oldOwnerId).startsWith('00G') ?
                [SELECT Id, Name, UserRole.DeveloperName FROM User WHERE Id = :oldOwnerId] :
            null;
            
            Boolean isOwnerChanged = oldOwnerId != newOwnerId; // Condition 1
            Boolean newIsSales = newOwner.UserRole != null && newOwner.UserRole.DeveloperName == 'Sales_Team_Member'; // Condition 2
            Boolean oldIsPresales = oldOwner != null && oldOwner.UserRole != null && oldOwner.UserRole.DeveloperName == 'Presales_Member'; // Condition 4
            Boolean isChannelPartner = lead.LeadSource == 'Channel Partner'; // Condition 3
            
            // Apply Flow Logic in Apex
            if (
                isOwnerChanged &&
                (
                    (newIsSales && oldIsPresales) || isChannelPartner
                )
            ) {
                // Proceed to create task
                String subject;
                String description;
                
                if (isScheduledJob) {
                    subject = 'Automatic Reassignment: Lead reassigned due to inactivity';
                    description = 'This Lead was automatically reassigned from ' + oldOwner.Name + ' to ' + newOwner.Name + ' because it remained inactive beyond the configured threshold.';
                }
                
                Task t = new Task();
                t.WhoId = leadId;
                t.Subject = subject;
                t.Description = description;
                t.Status = 'Completed';
                t.Priority = 'Normal';
                t.OwnerId = newOwnerId;
                t.ActivityDate = Date.today();
                insert t;
            }
            
        } catch (Exception ex) {
            System.debug('Task creation failed: ' + ex.getMessage());
        }
    }


    // ======================
    // Send Custom Notification
    // ======================
    private static void sendCustomNotification(Id recipientId, Id leadId) {
        try {
            CustomNotificationType notifType = [
                SELECT Id 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'General_Custom_Notification' 
                LIMIT 1
            ];

            if (notifType != null) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('New Lead Assigned');
                notification.setBody('You have been assigned a new Lead: ' + leadId);
                notification.setNotificationTypeId(notifType.Id);
                notification.setTargetId(leadId);
                notification.setSenderId(UserInfo.getUserId());
                notification.send(new Set<String>{ recipientId });
            }
        } catch (Exception ex) {
            ExceptionLogger.logException(
                new ExceptionLogger.ExceptionLogPayload().withComponentName('RoundRobinAssignHelper').withClassName('RoundRobinAssignHelper').withMethodName('sendCustomNotification').withRequestBody('LeadId: ' + leadId + ', RecipientId: ' + recipientId).withDomain('Notification').withIntegrationType('Internal').withErrorType('Unhandled Exception').withException(ex)
            );
        }
    }

    // ======================
    // Schedule Inactivity Check
    // ======================
    private static void scheduleInactivityCheck(Id leadId) {
        try {
            Round_Robin_Settings__mdt settings = Round_Robin_Settings__mdt.getInstance('Default_Settings');
            Integer delayDays = (settings != null && settings.Inactivity_Reassign_Days__c != null)
                ? Integer.valueOf(settings.Inactivity_Reassign_Days__c) : 3;

            Datetime now = Datetime.now().addDays(delayDays);
            Datetime runAt = Datetime.newInstance(now.date(), Time.newInstance(now.hour(), 0, 0, 0)).addMinutes(1);
            String cron = cronExpression(runAt);
            String jobName = 'LeadInactivityJob_' + String.valueOf(leadId).substring(0, 12);

            List<CronTrigger> existingJobs = [
                SELECT Id, State FROM CronTrigger WHERE CronJobDetail.Name = :jobName
            ];
            for (CronTrigger ct : existingJobs) { if (ct.State == 'WAITING') System.abortJob(ct.Id); }
            System.schedule(jobName, cron, new RoundRobinAsyncUtils.RoundRobinInactiveLeadReassignmentJob(leadId));
        } catch (Exception ex) {
            System.debug('Job scheduling failed: ' + ex.getMessage());
        }
    }

    private static String cronExpression(Datetime dt) {
        return String.format('{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month()),
                String.valueOf(dt.year())
            }
        );
    }

    // ======================
    // Comparator for sorting
    // ======================
    public class AssigneeComparator implements System.Comparator<Round_Robin_Assignee__c> {
        public Integer compare(Round_Robin_Assignee__c a, Round_Robin_Assignee__c b) {
            Integer countA = a.Last_Assigned_Count__c != null ? a.Last_Assigned_Count__c.intValue() : 0;
            Integer countB = b.Last_Assigned_Count__c != null ? b.Last_Assigned_Count__c.intValue() : 0;
            return countA - countB;
        }
    }
}