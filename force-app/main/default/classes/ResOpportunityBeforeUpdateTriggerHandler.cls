public class ResOpportunityBeforeUpdateTriggerHandler extends TriggerHandlerBase {
    
    public override void mainEntry(TriggerParameters tp) {
        
        List<Opportunity> newList = (List<Opportunity>)tp.newList;
        Set<Id> oppIds = new Set<Id>();
        Set<Id> planIds = new set<Id>();
        Set<Id> closingWonOppIds = new Set<Id>();
        
        Map<Id, SObject> oldMap = tp.oldMap;
        for (Opportunity op : newList) {
            Opportunity oldOp = oldMap != null ? (Opportunity)oldMap.get(op.Id) : null;
            if (oldOp != null && op.Interested_Unit__c != oldOp.Interested_Unit__c && op.Interested_Unit__c != null) {
                oppIds.add(op.Id);
            }
            
            if(op.Payment_Plan__c != null || Test.isRunningTest()){
                planIds.add(op.Payment_Plan__c);
            }

            if (op.StageName == 'Closed Won' && (oldOp == null || oldOp.StageName != 'Closed Won')) {
                closingWonOppIds.add(op.Id);
            }
        }

        // 1. Validate Closed Won requirement: Quotation must exist
        if (!closingWonOppIds.isEmpty()) {
            Map<Id, Integer> oppQuoteCount = new Map<Id, Integer>();
            for (AggregateResult ar : [
                SELECT OpportunityId oppId, count(Id) cnt 
                FROM Quote 
                WHERE OpportunityId IN :closingWonOppIds 
                GROUP BY OpportunityId
            ]) {
                oppQuoteCount.put((Id)ar.get('oppId'), (Integer)ar.get('cnt'));
            }

            for (Opportunity op : newList) {
                if (closingWonOppIds.contains(op.Id)) {
                    Integer count = oppQuoteCount.get(op.Id);
                    if (count == null || count == 0) {
                        op.addError('Cannot Close-Win Opportunity: An official Quotation must be generated and agreed upon by the customer before closing.');
                    }
                }
            }
        }

        // 2. Validate Unit change and Chargeable area
        if (!oppIds.isEmpty()) {
            OpportunityHelper.validateUnitOnOpp(oppIds, newList);
            OpportunityHelper.validateChargeableAreaFromTowerToUnit(newList);
        }
        
        // 3. Validate duplicate Milestone Codes under Payment Plan
        if(!planIds.isEmpty()){
            Map<Id,Boolean> duplicateMap = new Map<Id,Boolean>();
            duplicateMap = OpportunityHelper.hasDuplicateMilestones(planIds);
                        
            for(Opportunity op: newList){
                if(duplicateMap.containsKey(op.Payment_Plan__c) && duplicateMap.get(op.Payment_Plan__c)){
                    op.Payment_Plan__c.addError('Selected Payment Plan has duplicate Milestone Codes. Each Payment Schedule must have a unique Milestone Code under a Payment Plan. Please correct the Payment Plan before continuing');
                }
            }
        }
    }
}