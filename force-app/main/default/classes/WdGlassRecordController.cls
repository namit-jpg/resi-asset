/**
 * Activity feed for the WarpDrive glass record page (wdGlassRecord).
 * Returns open and recent tasks/events for any record, whether it is linked by WhoId or WhatId.
 */
public with sharing class WdGlassRecordController {

    public class ActivityItem implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public String kind; // task | call | email | event
        @AuraEnabled public String status;
        @AuraEnabled public Boolean isOpen;
        @AuraEnabled public Datetime occursAt;
        @AuraEnabled public String owner;

        public Integer compareTo(Object other) {
            ActivityItem o = (ActivityItem) other;
            if (occursAt == o.occursAt) {
                return 0;
            }
            if (occursAt == null) {
                return 1;
            }
            if (o.occursAt == null) {
                return -1;
            }
            return occursAt > o.occursAt ? -1 : 1;
        }
    }

    @AuraEnabled
    public static List<ActivityItem> getActivity(Id recordId) {
        try {
            List<ActivityItem> items = new List<ActivityItem>();
            for (Task t : [
                SELECT Id, Subject, Status, IsClosed, ActivityDate, CompletedDateTime, CreatedDate, TaskSubtype, Owner.Name
                FROM Task
                WHERE WhoId = :recordId OR WhatId = :recordId
                ORDER BY CreatedDate DESC
                LIMIT 25
            ]) {
                ActivityItem a = new ActivityItem();
                a.id = t.Id;
                a.subject = String.isBlank(t.Subject) ? 'Task' : t.Subject;
                a.kind = t.TaskSubtype == 'Call' ? 'call' : (t.TaskSubtype == 'Email' ? 'email' : 'task');
                a.status = t.Status;
                a.isOpen = !t.IsClosed;
                a.occursAt = t.ActivityDate != null
                    ? Datetime.newInstance(t.ActivityDate, Time.newInstance(9, 0, 0, 0))
                    : (t.CompletedDateTime != null ? t.CompletedDateTime : t.CreatedDate);
                a.owner = t.Owner.Name;
                items.add(a);
            }
            for (Event e : [
                SELECT Id, Subject, StartDateTime, EndDateTime, Owner.Name
                FROM Event
                WHERE WhoId = :recordId OR WhatId = :recordId
                ORDER BY StartDateTime DESC
                LIMIT 25
            ]) {
                ActivityItem a = new ActivityItem();
                a.id = e.Id;
                a.subject = String.isBlank(e.Subject) ? 'Event' : e.Subject;
                a.kind = 'event';
                a.isOpen = e.EndDateTime != null && e.EndDateTime > Datetime.now();
                a.status = a.isOpen ? 'Upcoming' : 'Done';
                a.occursAt = e.StartDateTime;
                a.owner = e.Owner.Name;
                items.add(a);
            }
            items.sort();
            return items;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public class ActionItem {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;

        ActionItem(String apiName, String label, String type) {
            this.apiName = apiName;
            this.label = label;
            this.type = type;
        }
    }

    /** Quick actions from the object's layout, followed by the standard record actions the page handles itself. */
    @AuraEnabled(cacheable=true)
    public static List<ActionItem> getActions(String objectApiName) {
        try {
            List<ActionItem> actions = new List<ActionItem>();
            if (objectApiName == 'Lead') {
                actions.add(new ActionItem('Convert', 'Convert', 'Standard'));
            }
            // Global actions and demo-package tooling are left out; the page's own activity card covers tasks and calls.
            String prefix = objectApiName + '.';
            for (QuickAction.DescribeAvailableQuickActionResult qa : QuickAction.describeAvailableQuickActions(objectApiName)) {
                String name = qa.getName();
                if (name.startsWith(prefix) && !isDemoAction(name.removeStart(prefix))) {
                    actions.add(new ActionItem(name, qa.getLabel(), 'QuickAction'));
                }
            }
            if (hasApprovalProcess(objectApiName)) {
                actions.add(new ActionItem('Submit', 'Submit for Approval', 'Standard'));
            }
            actions.add(new ActionItem('Clone', 'Clone', 'Standard'));
            actions.add(new ActionItem('Delete', 'Delete', 'Standard'));
            return actions;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static String submitForApproval(Id recordId, String comments) {
        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(recordId);
            req.setSubmitterId(UserInfo.getUserId());
            if (String.isNotBlank(comments)) {
                req.setComments(comments);
            }
            Approval.ProcessResult result = Approval.process(req);
            return result.getInstanceStatus();
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /** The booking's handover, created on first use. Backs the booking page's View Handover button. */
    @AuraEnabled
    public static Id getHandoverForBooking(Id bookingId) {
        try {
            List<Handover__c> existing = [SELECT Id FROM Handover__c WHERE Booking__c = :bookingId ORDER BY CreatedDate DESC LIMIT 1];
            if (existing.isEmpty()) {
                BookingHandoverHandler.initializeHandovers(new Set<Id>{ bookingId });
                existing = [SELECT Id FROM Handover__c WHERE Booking__c = :bookingId ORDER BY CreatedDate DESC LIMIT 1];
            }
            return existing.isEmpty() ? null : existing[0].Id;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static final List<String> DEMO_PREFIXES = new List<String>{ 'SDO_', 'EMC__', 'pi__', 'MERL__', 'healthcloud__' };

    private static Boolean isDemoAction(String localName) {
        for (String p : DEMO_PREFIXES) {
            if (localName.startsWith(p)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean hasApprovalProcess(String objectApiName) {
        return [SELECT COUNT() FROM ProcessDefinition WHERE TableEnumOrId = :objectApiName AND State = 'Active' AND Type = 'Approval'] > 0;
    }
}