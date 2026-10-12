public class QuoteBeforeInsertTriggerhandler extends TriggerHandlerBase {

    public override void mainEntry(TriggerParameters tp) {
        List<Quote> newList = (List<Quote>) tp.newList;
        
        validateQuotes(newList);
        ResQuoteTriggerHelper.markPrimaryQuote(newList);
    }

    private static void validateQuotes(List<Quote> newList) {
        Set<Id> oppIds = new Set<Id>();
        for (Quote q : newList) {
            if (q.OpportunityId != null) {
                oppIds.add(q.OpportunityId);
            } else {
                q.addError('Cannot create Quote: Quotation must be associated with an Opportunity.');
            }
        }

        if (!oppIds.isEmpty()) {
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
                SELECT Id, Interested_Unit__c, Interested_Unit__r.Name, Interested_Unit__r.Status__c,
                       AccountId, Interested_Unit__r.Property__c
                FROM Opportunity
                WHERE Id IN :oppIds
            ]);

            Set<Id> unitIds = new Set<Id>();
            for (Opportunity opp : oppMap.values()) {
                if (opp.Interested_Unit__c != null) {
                    unitIds.add(opp.Interested_Unit__c);
                }
            }

            Map<Id, Booking__c> activeBookingByUnit = new Map<Id, Booking__c>();
            if (!unitIds.isEmpty()) {
                for (Booking__c b : [
                    SELECT Id, Unit_Id__c, Opportunity_Id__c 
                    FROM Booking__c 
                    WHERE Unit_Id__c IN :unitIds AND Status__c != 'Cancelled'
                ]) {
                    activeBookingByUnit.put(b.Unit_Id__c, b);
                }
            }

            for (Quote q : newList) {
                if (q.OpportunityId != null) {
                    Opportunity opp = oppMap.get(q.OpportunityId);
                    if (opp != null) {
                        if (opp.Interested_Unit__c == null) {
                            q.addError('Cannot create Quotation: A Unit must be selected and tagged to the Opportunity (Interested Unit) before generating a Quote.');
                        } else if (opp.Interested_Unit__r != null && opp.Interested_Unit__r.Status__c == 'Sold') {
                            q.addError('Cannot create Quotation: Selected Unit ' + opp.Interested_Unit__r.Name + ' is already Sold.');
                        } else if (opp.Interested_Unit__r != null && opp.Interested_Unit__r.Status__c == 'Blocked') {
                            Booking__c existingBkg = activeBookingByUnit.get(opp.Interested_Unit__c);
                            if (existingBkg != null && existingBkg.Opportunity_Id__c != opp.Id) {
                                q.addError('Cannot create Quotation: Selected Unit ' + opp.Interested_Unit__r.Name + ' is already blocked under another active Booking.');
                            }
                        }

                        if (opp.AccountId == null) {
                            q.addError('Cannot create Quotation: The Opportunity must have an associated Customer Account.');
                        }
                    }
                }
            }
        }
    }
}