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
                actions.add(new ActionItem('Convert_Lead', 'Convert Lead', 'Standard'));
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
            if (objectApiName != 'Site_Visit__c') {
                actions.add(new ActionItem('Clone', 'Clone', 'Standard'));
            }
            actions.add(new ActionItem('Delete', 'Delete', 'Standard'));
            return actions;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public class ConvertedSummary {
        @AuraEnabled public Boolean isConverted;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id bookingId;
        @AuraEnabled public String bookingName;
        @AuraEnabled public String bookingStatus;
    }

    @AuraEnabled(cacheable=true)
    public static ConvertedSummary getLeadConversionSummary(Id leadId) {
        try {
            if (leadId == null) return null;
            List<Lead> leads = [
                SELECT Id, IsConverted, ConvertedAccountId, ConvertedAccount.Name,
                       ConvertedOpportunityId, ConvertedOpportunity.Name
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];
            if (leads.isEmpty() || !leads[0].IsConverted) {
                return null;
            }
            Lead ld = leads[0];
            ConvertedSummary cs = new ConvertedSummary();
            cs.isConverted = true;
            cs.accountId = ld.ConvertedAccountId;
            cs.accountName = ld.ConvertedAccount != null ? ld.ConvertedAccount.Name : 'Account';
            cs.opportunityId = ld.ConvertedOpportunityId;
            cs.opportunityName = ld.ConvertedOpportunity != null ? ld.ConvertedOpportunity.Name : 'Opportunity';

            if (ld.ConvertedOpportunityId != null) {
                List<Booking__c> bList = [
                    SELECT Id, Name, Status__c
                    FROM Booking__c
                    WHERE Opportunity_Id__c = :ld.ConvertedOpportunityId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!bList.isEmpty()) {
                    cs.bookingId = bList[0].Id;
                    cs.bookingName = bList[0].Name;
                    cs.bookingStatus = bList[0].Status__c;
                }
            }
            return cs;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public class OpportunityJourneySummary {
        @AuraEnabled public Id oppId;
        @AuraEnabled public String oppName;
        @AuraEnabled public String stageName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountPhone;
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String unitStatus;
        @AuraEnabled public String configuration;
        @AuraEnabled public String towerName;
        @AuraEnabled public String projectName;
        @AuraEnabled public Id bookingId;
        @AuraEnabled public String bookingName;
        @AuraEnabled public String bookingRefNo;
        @AuraEnabled public String bookingStatus;
        @AuraEnabled public String sapSalesOrder;
        @AuraEnabled public String sapCustomerCode;
        @AuraEnabled public String sapSyncStatus;
        @AuraEnabled public String recordTypeDeveloperName;
        @AuraEnabled public String recordTypeName;
        @AuraEnabled public Decimal tokenAmountPaid;
        @AuraEnabled public String tokenPaymentStatus;
        @AuraEnabled public String bookingFormStatus;
    }

    @AuraEnabled(cacheable=true)
    public static OpportunityJourneySummary getOpportunityJourney(Id oppId) {
        try {
            if (oppId == null) return null;
            List<Opportunity> oppList = [
                SELECT Id, Name, StageName, Amount, AccountId, Account.Name, Account.Phone,
                       RecordTypeId, RecordType.DeveloperName, RecordType.Name,
                       Token_Amount__c,
                       Interested_Unit__c, Interested_Unit__r.Name, Interested_Unit__r.Status__c,
                       Interested_Unit__r.BHK_Configuration__c, Interested_Unit__r.Tower__r.Name,
                       Interested_Unit__r.Property__r.Name
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            if (oppList.isEmpty()) return null;
            Opportunity opp = oppList[0];

            OpportunityJourneySummary s = new OpportunityJourneySummary();
            s.oppId = opp.Id;
            s.oppName = opp.Name;
            s.stageName = opp.StageName;
            s.amount = opp.Amount;
            s.accountId = opp.AccountId;
            s.accountName = opp.Account != null ? opp.Account.Name : 'Valued Customer';
            s.accountPhone = opp.Account != null ? opp.Account.Phone : '';
            s.recordTypeDeveloperName = opp.RecordType != null ? opp.RecordType.DeveloperName : '';
            s.recordTypeName = opp.RecordType != null ? opp.RecordType.Name : '';
            s.tokenAmountPaid = opp.Token_Amount__c != null ? opp.Token_Amount__c : 200000;
            s.tokenPaymentStatus = 'Paid';
            s.bookingFormStatus = 'Completed';

            if (opp.Interested_Unit__c != null) {
                s.unitId = opp.Interested_Unit__c;
                s.unitName = opp.Interested_Unit__r.Name;
                s.unitStatus = opp.Interested_Unit__r.Status__c;
                s.configuration = opp.Interested_Unit__r.BHK_Configuration__c;
                s.towerName = opp.Interested_Unit__r.Tower__r != null ? opp.Interested_Unit__r.Tower__r.Name : '';
                s.projectName = opp.Interested_Unit__r.Property__r != null ? opp.Interested_Unit__r.Property__r.Name : '';
            }

            List<Booking__c> bList = [
                SELECT Id, Name, SFDC_booking_reference_no__c,
                       Status__c, SAP_External_Id__c, SAP_Sync_Status__c
                FROM Booking__c
                WHERE Opportunity_Id__c = :opp.Id
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!bList.isEmpty()) {
                Booking__c b = bList[0];
                s.bookingId = b.Id;
                s.bookingName = b.Name;
                s.bookingRefNo = String.isNotBlank(b.SFDC_booking_reference_no__c)
                    ? b.SFDC_booking_reference_no__c
                    : b.Name;
                s.bookingStatus = b.Status__c;
                s.sapSalesOrder = b.SAP_External_Id__c;
                s.sapSyncStatus = b.SAP_Sync_Status__c;
            }
            return s;
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    @AuraEnabled
    public static UnitSelectionQuoteController.SapBookingResultWrapper createBookingAndSyncSap(Id oppId) {
        try {
            return UnitSelectionQuoteController.syncToSapAndCreateBooking(oppId);
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

    private static final List<String> DEMO_PREFIXES = new List<String>{ 'SDO_', 'EMC__', 'pi__', 'MERL__', 'healthcloud__' };

    private static Boolean isDemoAction(String localName) {
        for (String p : DEMO_PREFIXES) {
            if (localName.startsWith(p)) {
                return true;
            }
        }
        return false;
    }

    @AuraEnabled
    public static String processWorkitem(Id workitemId, String action, String comments) {
        try {
            if (workitemId == null) throw new AuraHandledException('Workitem ID is required.');
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workitemId);
            req.setAction(String.isNotBlank(action) ? action : 'Approve');
            if (String.isNotBlank(comments)) {
                req.setComments(comments);
            }
            Approval.ProcessResult res = Approval.process(req);
            return res.getInstanceStatus();
        } catch (Exception ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    public class ApprovalHistoryItem {
        @AuraEnabled public Id id;
        @AuraEnabled public Id workitemId;
        @AuraEnabled public Boolean isPending = false;
        @AuraEnabled public String stepName;
        @AuraEnabled public String status;
        @AuraEnabled public String statusClass;
        @AuraEnabled public String assignedTo;
        @AuraEnabled public String comments;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String formattedDate;
    }

    @AuraEnabled(cacheable=true)
    public static List<ApprovalHistoryItem> getApprovalHistory(Id recordId) {
        List<ApprovalHistoryItem> items = new List<ApprovalHistoryItem>();
        if (recordId == null) return items;

        List<ProcessInstance> instances = [
            SELECT Id, Status, CreatedDate,
                   (SELECT Id, StepStatus, Comments, Actor.Name, CreatedDate FROM Steps ORDER BY CreatedDate DESC),
                   (SELECT Id, OriginalActor.Name, Actor.Name, CreatedDate FROM Workitems ORDER BY CreatedDate DESC)
            FROM ProcessInstance
            WHERE TargetObjectId = :recordId
            ORDER BY CreatedDate DESC
        ];

        for (ProcessInstance pi : instances) {
            if (pi.Workitems != null) {
                for (ProcessInstanceWorkitem wi : pi.Workitems) {
                    ApprovalHistoryItem item = new ApprovalHistoryItem();
                    item.id = wi.Id;
                    item.workitemId = wi.Id;
                    item.isPending = true;
                    item.stepName = 'Management Approval Pending';
                    item.status = 'Pending';
                    item.statusClass = 'badge badge_warn';
                    item.assignedTo = wi.Actor != null ? wi.Actor.Name : (wi.OriginalActor != null ? wi.OriginalActor.Name : 'Approver');
                    item.comments = '';
                    item.createdDate = wi.CreatedDate;
                    item.formattedDate = wi.CreatedDate != null ? wi.CreatedDate.format('dd MMM yyyy, hh:mm a') : '';
                    items.add(item);
                }
            }
            if (pi.Steps != null) {
                for (ProcessInstanceStep step : pi.Steps) {
                    ApprovalHistoryItem item = new ApprovalHistoryItem();
                    item.id = step.Id;
                    item.stepName = (step.StepStatus == 'Started') ? 'Submitted for Approval' : (step.StepStatus == 'Approved' ? 'Discount Approved' : (step.StepStatus == 'Rejected' ? 'Discount Rejected' : step.StepStatus));
                    item.status = step.StepStatus;
                    if (step.StepStatus == 'Approved') {
                        item.statusClass = 'badge badge_ok';
                    } else if (step.StepStatus == 'Rejected') {
                        item.statusClass = 'badge badge_bad';
                    } else {
                        item.statusClass = 'badge badge_neutral';
                    }
                    item.assignedTo = step.Actor != null ? step.Actor.Name : 'System';
                    item.comments = String.isNotBlank(step.Comments) ? step.Comments : '—';
                    item.createdDate = step.CreatedDate;
                    item.formattedDate = step.CreatedDate != null ? step.CreatedDate.format('dd MMM yyyy, hh:mm a') : '';
                    items.add(item);
                }
            }
        }
        return items;
    }

    @AuraEnabled
    public static Id getHandoverForBooking(Id bookingId) {
        return HandoverWorkspaceController.getOrCreateHandoverForBooking(bookingId);
    }

    private static Boolean hasApprovalProcess(String objectApiName) {
        return [SELECT COUNT() FROM ProcessDefinition WHERE TableEnumOrId = :objectApiName AND State = 'Active' AND Type = 'Approval'] > 0;
    }
}