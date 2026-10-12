@IsTest
private class WdGlassCustomerControllerTest {

    @IsTest
    static void prospectWithOpenDeal() {
        Id rt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business_Account').getRecordTypeId();
        Account a = new Account(Name = 'Glass Buyer', Phone = '9999999999', RecordTypeId = rt);
        insert a;
        insert new Opportunity(Name = 'Glass deal', AccountId = a.Id, StageName = 'Negotiation', CloseDate = Date.today().addDays(10));
        // No Case here: the org's "SDO Service - Case - On Create" flow fails in test context.

        WdGlassCustomerController.Customer c = WdGlassCustomerController.getCustomer(a.Id);

        Assert.areEqual('Glass Buyer', c.profile.name);
        Assert.isFalse(c.isBuyer);
        Assert.areEqual(1, c.openOpportunities);
        Assert.isTrue(c.holdings.isEmpty());
        Assert.areEqual(0, c.overdueCount);
        Assert.areEqual(0, c.openCases);
        Assert.isTrue(c.invoices.isEmpty());
        Assert.isTrue(c.payments.isEmpty());
    }

    @IsTest
    static void unknownAccountThrows() {
        try {
            WdGlassCustomerController.getCustomer('001000000000000AAA');
            Assert.fail('expected an exception');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
    }
}