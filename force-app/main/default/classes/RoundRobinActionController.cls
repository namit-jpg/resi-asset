public with sharing class RoundRobinActionController {

    // Sales queues by city; a project's queue comes from its Location city.
    private static final Map<String, String> QUEUE_BY_CITY = new Map<String, String>{
        'bengaluru' => 'Bangalore_Queue',
        'bangalore' => 'Bangalore_Queue',
        'hyderabad' => 'Hyderabad_Queue',
        'gurugram' => 'Delhi_Queue',
        'gurgaon' => 'Delhi_Queue',
        'delhi' => 'Delhi_Queue',
        'new delhi' => 'Delhi_Queue'
    };

    /**
     * Assigns the lead to the next sales user in its city's queue and returns the new owner's name.
     * Leads with no project or city go to the whole active round robin pool.
     */
    @AuraEnabled
    public static String assignLeadViaRoundRobin(Id leadId) {
        try {
            if (leadId == null) throw new AuraHandledException('Lead Id is required');

            Lead leadRecord = [
                SELECT Id, OwnerId, Name, Region__c, Projects__c, Preferred_City__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            // 1️⃣ Decide the queue: project -> project city -> preferred city
            String queueName = queueForLead(leadRecord);
            Set<Id> userIdsToUse;
            if (queueName != null) {
                Id targetQueueId = getQueueIdByName(queueName);
                if (targetQueueId == null) { throw new AuraHandledException('Queue ' + queueName + ' was not found.'); }

                // 2️⃣ Get queue members
                userIdsToUse = new Set<Id>();
                for (GroupMember gm : [
                    SELECT UserOrGroupId
                    FROM GroupMember
                    WHERE GroupId = :targetQueueId
                ]) {
                    if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                        userIdsToUse.add(gm.UserOrGroupId);
                    }
                }
                if (userIdsToUse.isEmpty()) { throw new AuraHandledException('The ' + queueName.replace('_', ' ') + ' has no users.'); }
            }

            // 3️⃣ Assign via Round Robin helper (null = every active assignee)
            RoundRobinAssignHelper.assignLead(leadRecord, userIdsToUse);
            return [SELECT Owner.Name FROM Lead WHERE Id = :leadId].Owner.Name;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) { ExceptionLogger.ExceptionLogPayload payload = new ExceptionLogger.ExceptionLogPayload().withComponentName('RoundRobinActionController').withDescription('Failed to assign lead via round robin. ' + e.getMessage()).withClassName('RoundRobinActionController').withMethodName('assignLeadViaRoundRobin').withErrorType('Assignment Logic').withException(e); ExceptionLogger.logException(payload);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @TestVisible
    private static String queueForLead(Lead leadRecord) {
        switch on leadRecord.Projects__c {
            when 'Varthur Vista', 'Yalahanka Yard', 'Nikoo Homes', 'One Bangalore West' {
                return 'Bangalore_Queue';
            }
            when 'Banjara Beam', 'Miyapur Manor' {
                return 'Hyderabad_Queue';
            }
            when 'Saket Square', 'Rohini Rise' {
                return 'Delhi_Queue';
            }
        }
        String city;
        if (String.isNotBlank(leadRecord.Projects__c)) {
            List<Property__c> projects = [SELECT Location__City__s FROM Property__c WHERE Name = :leadRecord.Projects__c LIMIT 1];
            city = projects.isEmpty() ? null : projects[0].Location__City__s;
        }
        if (String.isBlank(city)) {
            city = leadRecord.Preferred_City__c;
        }
        return String.isBlank(city) ? null : QUEUE_BY_CITY.get(city.trim().toLowerCase());
    }

    public static Id getQueueIdByName(String queueName) {
        try {
            Group g = [
                SELECT Id 
                FROM Group 
                WHERE DeveloperName = :queueName 
                AND Type = 'Queue' 
                LIMIT 1
            ];
            return g.Id;
        } catch (Exception e) {
            return null;
        }
    }
}