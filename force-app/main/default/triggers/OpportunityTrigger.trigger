trigger OpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete) {
    System.debug('Inside opportunity trigger');
    if (!UtilityClass.isTriggerGloballyDisabled()) {
         TriggerFactory.createTriggerDispatcher(Opportunity.SObjectType);
    }
}