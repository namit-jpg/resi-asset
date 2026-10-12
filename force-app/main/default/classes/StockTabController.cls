public with sharing class StockTabController {
    @AuraEnabled(cacheable=true)
    public static List<Unit__c> getUnits(Integer offsetSize, Integer limitSize, String statusFilter, String searchKey) {
        String key = (searchKey != null && searchKey.trim() != '') ? '%' + searchKey.trim() + '%' : null;

        String baseQuery = 
            'SELECT Id, Name, BHK_Configuration__c, Built_Up_Area_SBA__c, Carpet_Area__c, ' +
            'Deck_Balcony__c, Garden_Area__c, Net_Area_Aggregate__c, Private_Lobby__c, ' +
            'Terrace_Area__c, Total_area_of_villa_unit__c, Saleable_Area__c, Control_Code__c, ' +
            'Customer_Account__c, Customer_Account__r.Name, Floor__c, Floor__r.Name, ' +
            'Property__c, Property__r.Name, Tower__c, Tower__r.Name, ' +
            'Profit_Center__c, Profit_Center__r.Name, ' +
            'CreatedById, LastModifiedById, Status__c ' +
            'FROM Unit__c WHERE Id != null ';

        if (statusFilter != null && statusFilter != '' && statusFilter != 'All') {
            baseQuery += 'AND Status__c = :statusFilter ';
        }

        if (key != null) {
            baseQuery += 'AND ( ' +
                'Name LIKE :key ' +
                'OR BHK_Configuration__c LIKE :key ' +
                'OR Control_Code__c LIKE :key ' +
                'OR SAP_External_Id__c LIKE :key ' +
                'OR Customer_Account__r.Name LIKE :key ' +
                'OR Floor__r.Name LIKE :key ' +
                'OR Property__r.Name LIKE :key ' +
                'OR Tower__r.Name LIKE :key ' +
            ') ';
        }

        baseQuery += 'ORDER BY Name ASC LIMIT :limitSize OFFSET :offsetSize';

        return Database.query(baseQuery);
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableStatuses() {
        List<String> statuses = new List<String>();
        for (AggregateResult ar : [
            SELECT Status__c statusVal 
            FROM Unit__c 
            WHERE Status__c != null 
            GROUP BY Status__c 
            ORDER BY Status__c
        ]) {
            statuses.add((String)ar.get('statusVal'));
        }
        return statuses;
    }
}