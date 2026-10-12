public class ResLeadTriggerDispatcher extends TriggerDispatcherBase {

    // Cache the Residential Lead RecordType Id (safe even in tests)
    public static Id RT_ID_LEAD_RESIDENTIAL;
    static {
        Map<String, Schema.RecordTypeInfo> recordTypeInfoByDevName = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName();
        if (recordTypeInfoByDevName.containsKey('Standard_Lead_Residential')) {
            RT_ID_LEAD_RESIDENTIAL = recordTypeInfoByDevName.get('Standard_Lead_Residential').getRecordTypeId();
        }
    }

    /**
     * Before insert: automatically calculate archive and follow-up dates
     */
    public override void beforeInsert(TriggerParameters tp) {
        if (tp.newList != null && !tp.newList.isEmpty()) {
            LeadArchiveService.handleBeforeSave((List<Lead>) tp.newList, null);
        }
    }

    /**
     * Before update: automatically adjust archive and follow-up dates when archive days change
     */
    public override void beforeUpdate(TriggerParameters tp) {
        if (tp.newList != null && !tp.newList.isEmpty()) {
            Map<Id, Lead> oldLeadMap = new Map<Id, Lead>();
            if (tp.oldMap != null) {
                for (Id k : tp.oldMap.keySet()) {
                    oldLeadMap.put(k, (Lead) tp.oldMap.get(k));
                }
            }
            LeadArchiveService.handleBeforeSave((List<Lead>) tp.newList, oldLeadMap);

            // QUALIFICATION GATE: Ensure Lead cannot be converted without a verified Site Visit
            Set<Id> convertingLeadIds = new Set<Id>();
            for (Lead ld : (List<Lead>) tp.newList) {
                Lead oldLd = oldLeadMap.get(ld.Id);
                if (ld.IsConverted == true && (oldLd == null || oldLd.IsConverted == false)) {
                    convertingLeadIds.add(ld.Id);
                }
            }

            if (!convertingLeadIds.isEmpty()) {
                Map<Id, Integer> visitCountByLead = new Map<Id, Integer>();
                for (AggregateResult ar : [
                    SELECT Lead__c lId, count(Id) cnt 
                    FROM Site_Visit__c 
                    WHERE Lead__c IN :convertingLeadIds 
                    GROUP BY Lead__c
                ]) {
                    visitCountByLead.put((Id) ar.get('lId'), (Integer) ar.get('cnt'));
                }

                for (Lead ld : (List<Lead>) tp.newList) {
                    if (convertingLeadIds.contains(ld.Id)) {
                        Integer cnt = visitCountByLead.containsKey(ld.Id) ? visitCountByLead.get(ld.Id) : 0;
                        if (cnt == 0 && ld.Has_Site_Visit__c != true) {
                            ld.addError('Qualification Threshold Not Met: A Lead cannot be converted into an Opportunity without at least one verified Site Visit. Please conduct and log an authentic Site Visit with SMS OTP verification first.');
                        }
                    }
                }
            }
        }
    }

    /**
     * After update: when a Lead is just converted, relink its Site Visits to the new Opportunity.
     */
    public override void afterUpdate(TriggerParameters tp) {
        // Build a map of {LeadId -> ConvertedOpportunityId} only for newly-converted leads.
        Map<Id, Id> leadIdToOppId = new Map<Id, Id>();
        Map<Id, SObject> oldMap = tp.oldMap;

        for (SObject sobj : tp.newList) {
            Lead newLead = (Lead) sobj;
            Lead oldLead = oldMap != null ? (Lead) oldMap.get(newLead.Id) : null;
            if (oldLead == null) continue;

            // Converted now (true) but not earlier (false)
            if (newLead.IsConverted == true && oldLead.IsConverted == false) {
                // Optional: limit to Residential lead RT if available
                if (newLead.RecordTypeId == RT_ID_LEAD_RESIDENTIAL) {
                    // Only useful if an Opportunity was created
                    if (newLead.ConvertedOpportunityId != null) {
                        leadIdToOppId.put(newLead.Id, newLead.ConvertedOpportunityId);
                    }
                }
            }
        }

        if (leadIdToOppId.isEmpty()) return;

        // Single SOQL to fetch all Site Visits pointing to those Leads
        List<Site_Visit__c> visits = [
            SELECT Id, Lead__c, Opportunity__c
            FROM Site_Visit__c
            WHERE Lead__c IN :leadIdToOppId.keySet()
        ];

        if (visits.isEmpty()) return;

        for (Site_Visit__c v : visits) {
            v.Opportunity__c = leadIdToOppId.get(v.Lead__c);
            v.Lead__c       = null;
        }

        // Partial success to avoid hard failure on occasional row locks/validation
        Database.Update(visits, /*allOrNone*/ true);
    }
}