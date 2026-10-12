public with sharing class LeadArchiveService {

    public class LeadArchiveInfo {
        @AuraEnabled public Boolean isArchived { get; set; }
        @AuraEnabled public Boolean isFollowUpDue { get; set; }
        @AuraEnabled public Decimal archiveDays { get; set; }
        @AuraEnabled public Date followUpDate { get; set; }
        @AuraEnabled public Datetime populatedDate { get; set; }
        @AuraEnabled public String statusText { get; set; }
        @AuraEnabled public String leadName { get; set; }
    }

    /**
     * Trigger Handler: Before Insert / Update
     * Automatically calculates Archive_Populated_Date__c and Archive_Follow_Up_Date__c
     */
    public static void handleBeforeSave(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        for (Lead ld : newLeads) {
            Lead oldLd = (oldMap != null && ld.Id != null) ? oldMap.get(ld.Id) : null;

            // Auto-reactivate: If lead was in Archive status and moved to another active status, clear archival fields
            if (oldLd != null && oldLd.Status == 'Archive' && ld.Status != 'Archive') {
                ld.Archive_For_In_Days__c = null;
                ld.Archive_Populated_Date__c = null;
                ld.Archive_Follow_Up_Date__c = null;
                ld.Archive_Notification_Sent__c = false;
            }

            Boolean isDaysChanged = (oldLd == null) || (oldLd.Archive_For_In_Days__c != ld.Archive_For_In_Days__c);

            if (isDaysChanged) {
                if (ld.Archive_For_In_Days__c != null && ld.Archive_For_In_Days__c > 0) {
                    ld.Archive_Populated_Date__c = DateTime.now();
                    ld.Archive_Follow_Up_Date__c = Date.today().addDays(Integer.valueOf(ld.Archive_For_In_Days__c));
                    ld.Archive_Notification_Sent__c = false;
                } else if (ld.Archive_For_In_Days__c == null || ld.Archive_For_In_Days__c <= 0) {
                    ld.Archive_Populated_Date__c = null;
                    ld.Archive_Follow_Up_Date__c = null;
                    ld.Archive_Notification_Sent__c = false;
                }
            }
        }
    }

    /**
     * Get live archive state for a Lead to render LWC banner
     */
    @AuraEnabled
    public static LeadArchiveInfo getArchiveInfo(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required');
        }

        Lead ld = [
            SELECT Id, Name, Archive_For_In_Days__c, Archive_Follow_Up_Date__c,
                   Archive_Populated_Date__c, Archive_Notification_Sent__c, Archive_Status__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        LeadArchiveInfo info = new LeadArchiveInfo();
        info.leadName = ld.Name;
        info.archiveDays = ld.Archive_For_In_Days__c;
        info.followUpDate = ld.Archive_Follow_Up_Date__c;
        info.populatedDate = ld.Archive_Populated_Date__c;
        info.statusText = ld.Archive_Status__c;

        if (ld.Archive_For_In_Days__c != null && ld.Archive_For_In_Days__c > 0 && ld.Archive_Follow_Up_Date__c != null) {
            if (ld.Archive_Follow_Up_Date__c <= Date.today()) {
                info.isFollowUpDue = true;
                info.isArchived = false;
            } else {
                info.isArchived = true;
                info.isFollowUpDue = false;
            }
        } else {
            info.isArchived = false;
            info.isFollowUpDue = false;
        }

        return info;
    }

    /**
     * Invocable action callable from Flow or Apex
     */
    @InvocableMethod(label='Check & Send Archive Follow-Up Notifications' description='Dispatches follow-up notifications and tasks for due archived leads')
    public static void executeInvocable() {
        processDueArchiveFollowUps();
    }

    /**
     * Process all Leads whose archive cooling-off period has elapsed
     */
    public static Integer processDueArchiveFollowUps() {
        List<Lead> dueLeads = [
            SELECT Id, Name, Company, OwnerId, Archive_For_In_Days__c,
                   Archive_Follow_Up_Date__c, Archive_Notification_Sent__c
            FROM Lead
            WHERE Archive_For_In_Days__c != null
              AND Archive_For_In_Days__c > 0
              AND Archive_Follow_Up_Date__c <= :Date.today()
              AND Archive_Notification_Sent__c = false
              AND IsConverted = false
            LIMIT 200
        ];

        if (dueLeads.isEmpty()) {
            return 0;
        }

        CustomNotificationType notifType = getCustomNotificationType();
        List<Task> followUpTasks = new List<Task>();
        List<Lead> leadsToUpdate = new List<Lead>();

        for (Lead ld : dueLeads) {
            // 1. Send In-App / Mobile Custom Notification if notification type exists
            if (notifType != null && String.valueOf(ld.OwnerId).startsWith('005')) {
                sendCustomNotification(ld, notifType.Id);
            }

            // 2. Create High-Priority Follow-Up Task
            followUpTasks.add(new Task(
                Subject = 'Customer might be ready, follow up',
                WhoId = ld.Id,
                OwnerId = ld.OwnerId,
                ActivityDate = Date.today(),
                Status = 'Not Started',
                Priority = 'High',
                Description = 'Customer ' + ld.Name + 
                              (String.isNotBlank(ld.Company) ? ' (' + ld.Company + ')' : '') + 
                              ' was archived for ' + ld.Archive_For_In_Days__c + 
                              ' days. The archival period has elapsed. Customer might be ready, follow up now!'
            ));

            ld.Archive_Notification_Sent__c = true;
            leadsToUpdate.add(ld);
        }

        if (!followUpTasks.isEmpty()) {
            insert followUpTasks;
        }

        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }

        return dueLeads.size();
    }

    /**
     * Trigger immediate follow-up notification for a specific Lead (e.g. for testing or instant trigger)
     */
    @AuraEnabled
    public static void sendFollowUpNotification(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required');
        }

        Lead ld = [
            SELECT Id, Name, Company, OwnerId, Archive_For_In_Days__c,
                   Archive_Follow_Up_Date__c, Archive_Notification_Sent__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        CustomNotificationType notifType = getCustomNotificationType();
        if (notifType != null && String.valueOf(ld.OwnerId).startsWith('005')) {
            sendCustomNotification(ld, notifType.Id);
        }

        Task t = new Task(
            Subject = 'Customer might be ready, follow up',
            WhoId = ld.Id,
            OwnerId = ld.OwnerId,
            ActivityDate = Date.today(),
            Status = 'Not Started',
            Priority = 'High',
            Description = 'Customer ' + ld.Name + 
                          ' was archived for ' + (ld.Archive_For_In_Days__c != null ? String.valueOf(ld.Archive_For_In_Days__c) : 'several') + 
                          ' days. The archival period has elapsed. Customer might be ready, follow up now!'
        );
        insert t;

        ld.Archive_Notification_Sent__c = true;
        update ld;
    }

    /**
     * Sales executive completes follow-up, restoring lead to active status
     */
    @AuraEnabled
    public static void completeFollowUp(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id is required');
        }

        Lead ld = [
            SELECT Id, Status, Archive_For_In_Days__c, Archive_Populated_Date__c,
                   Archive_Follow_Up_Date__c, Archive_Notification_Sent__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        ld.Archive_For_In_Days__c = null;
        ld.Archive_Populated_Date__c = null;
        ld.Archive_Follow_Up_Date__c = null;
        ld.Archive_Notification_Sent__c = false;
        if (ld.Status == 'Archive') {
            ld.Status = 'Allocated';
        }
        update ld;
    }

    private static CustomNotificationType getCustomNotificationType() {
        try {
            return [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'Lead_Archive_Follow_Up' 
                LIMIT 1
            ];
        } catch (Exception e) {
            return null;
        }
    }

    private static void sendCustomNotification(Lead ld, Id notificationTypeId) {
        try {
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setTitle('Customer might be ready, follow up');
            notif.setBody('Customer ' + ld.Name + 
                          (String.isNotBlank(ld.Company) ? ' (' + ld.Company + ')' : '') + 
                          ' was archived for ' + ld.Archive_For_In_Days__c + 
                          ' days. Customer might be ready, follow up now!');
            notif.setNotificationTypeId(notificationTypeId);
            notif.setTargetId(ld.Id);
            notif.send(new Set<String>{ String.valueOf(ld.OwnerId) });
        } catch (Exception notifEx) {
            System.debug('Custom Notification dispatch notice: ' + notifEx.getMessage());
        }
    }
}