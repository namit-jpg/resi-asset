public class leadAssignmentHelper {
    @InvocableMethod(label='Run Lead Assignment Rules' category='Lead')
    public static void runAssignmentRules(List<Id> leadIds) {
        // Define DML options to use the default assignment rule
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.assignmentRuleHeader.useDefaultRule = true;
        
        // Fetch the leads created by the flow
        List<Lead> leadsToAssign = [SELECT Id FROM Lead WHERE Id IN :leadIds];
        
        // Apply the assignment options to each lead
        for (Lead l : leadsToAssign) {
            l.setOptions(dmo);
        }
        
        // Update leads to trigger the assignment
        update leadsToAssign;
    }
}