@IsTest
private class EoiVoucherControllerTest {

    @TestSetup
    static void setup() {
        Property__c project = new Property__c(Name = 'Varthur Vista');
        insert project;
        Tower__c tower = new Tower__c(Name = 'Tower 1', Property__c = project.Id);
        insert tower;
        Floor__c floor = new Floor__c(Name = '1st', Tower__c = tower.Id);
        insert floor;
        insert new List<Unit__c>{
            new Unit__c(Name = 'VV-T1-101', Property__c = project.Id, Tower__c = tower.Id, Floor__c = floor.Id, BHK_Configuration__c = '3 BHK Classic', Status__c = 'Available'),
            new Unit__c(Name = 'VV-T1-102', Property__c = project.Id, Tower__c = tower.Id, Floor__c = floor.Id, BHK_Configuration__c = '2 BHK + Family', Status__c = 'Available')
        };

        Lead l = new Lead(LastName = 'Rao', FirstName = 'Kavya', Company = 'Individual', Status = 'New',
            MobilePhone = '9876500011', Email = 'kavya.rao@example.com', Projects__c = 'Varthur Vista', Type_of_Units__c = '3BHK');
        Id rt = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Standard_Lead_Residential')?.getRecordTypeId();
        if (rt != null) {
            l.RecordTypeId = rt;
        }
        insert l;
    }

    static Lead lead() {
        return [SELECT Id FROM Lead WHERE LastName = 'Rao' LIMIT 1];
    }

    static Id generate() {
        return EoiVoucherController.generateVoucher(lead().Id, 'Standard EOI', 100000, null, Date.today().addDays(30), 'Walk-in');
    }

    @IsTest
    static void leadContextPrefillsFromLead() {
        EoiVoucherController.LeadContext ctx = EoiVoucherController.getLeadContext(lead().Id);
        Assert.isNull(ctx.blockReason);
        Assert.isTrue(ctx.canGenerate);
        Assert.areEqual('Varthur Vista', ctx.project);
        Assert.isNotNull(ctx.projectId);
        Assert.areEqual('3BHK', ctx.configuration);
        Assert.areEqual(100000, ctx.amounts.get('Standard EOI'));
    }

    @IsTest
    static void generateCopiesApplicantAndBlocksSecondOpenVoucher() {
        Id voucherId = generate();
        Voucher__c v = [SELECT Status__c, Applicant_Name__c, Applicant_Mobile__c, Preferred_Configuration__c, Project__r.Name FROM Voucher__c WHERE Id = :voucherId];
        Assert.areEqual(EoiVoucherController.PAYMENT_PENDING, v.Status__c);
        Assert.areEqual('Kavya Rao', v.Applicant_Name__c);
        Assert.areEqual('3BHK', v.Preferred_Configuration__c);
        Assert.areEqual('Varthur Vista', v.Project__r.Name);

        EoiVoucherController.LeadContext ctx = EoiVoucherController.getLeadContext(lead().Id);
        Assert.isFalse(ctx.canGenerate);
        Assert.areEqual(1, ctx.vouchers.size());
        try {
            generate();
            Assert.fail('A second open voucher for the same project should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('already open'), e.getMessage());
        }
    }

    @IsTest
    static void partPaymentKeepsPendingAndFullPaymentAssignsPriority() {
        Id voucherId = generate();
        EoiVoucherController.recordPayment(voucherId, 40000, 'UPI', 'UTR001', Date.today());
        Voucher__c v = [SELECT Status__c, Priority_Number__c, Balance_Due__c FROM Voucher__c WHERE Id = :voucherId];
        Assert.areEqual(EoiVoucherController.PAYMENT_PENDING, v.Status__c);
        Assert.isNull(v.Priority_Number__c);
        Assert.areEqual(60000, v.Balance_Due__c);

        try {
            EoiVoucherController.recordPayment(voucherId, 70000, 'UPI', 'UTR002', Date.today());
            Assert.fail('Overpayment should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('balance'), e.getMessage());
        }

        EoiVoucherController.recordPayment(voucherId, 60000, 'NEFT/RTGS', 'UTR003', Date.today());
        v = [SELECT Status__c, Priority_Number__c, Amount_Paid__c FROM Voucher__c WHERE Id = :voucherId];
        Assert.areEqual(EoiVoucherController.PAID, v.Status__c);
        Assert.areEqual(1, v.Priority_Number__c);
        Assert.areEqual(100000, v.Amount_Paid__c);
    }

    @IsTest
    static void allotOffersMatchingUnitsFirst() {
        Id voucherId = generate();
        try {
            EoiVoucherController.allotUnit(voucherId, [SELECT Id FROM Unit__c LIMIT 1].Id);
            Assert.fail('Allotment before payment should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('paid'), e.getMessage());
        }
        EoiVoucherController.recordPayment(voucherId, 100000, 'UPI', 'UTR010', null);

        EoiVoucherController.VoucherContext ctx = EoiVoucherController.getVoucher(voucherId, 'allot');
        Assert.areEqual(2, ctx.units.size());
        Assert.areEqual('VV-T1-101', ctx.units[0].label, '3 BHK unit should be listed first');

        EoiVoucherController.allotUnit(voucherId, ctx.units[0].value);
        Voucher__c v = [SELECT Status__c, Flat_No__r.Name FROM Voucher__c WHERE Id = :voucherId];
        Assert.areEqual(EoiVoucherController.ALLOTTED, v.Status__c);
        Assert.areEqual('VV-T1-101', v.Flat_No__r.Name);
    }

    @IsTest
    static void cancelUnpaidAndRefundPaid() {
        Id unpaid = generate();
        EoiVoucherController.closeVoucher(unpaid, 'Customer changed plans', null, null, null);
        Assert.areEqual(EoiVoucherController.CANCELLED, [SELECT Status__c FROM Voucher__c WHERE Id = :unpaid].Status__c);

        Id paid = generate();
        EoiVoucherController.recordPayment(paid, 100000, 'Cheque', 'CHQ123', Date.today());
        try {
            EoiVoucherController.closeVoucher(paid, 'Moved city', 100000, null, null);
            Assert.fail('Refund without a reference should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('reference'), e.getMessage());
        }
        EoiVoucherController.closeVoucher(paid, 'Moved city', 100000, 'RF-001', Date.today());
        Voucher__c v = [SELECT Status__c, Refund_Amount__c, Refund_Reference__c FROM Voucher__c WHERE Id = :paid];
        Assert.areEqual(EoiVoucherController.REFUNDED, v.Status__c);
        Assert.areEqual(100000, v.Refund_Amount__c);

        EoiVoucherController.VoucherContext ctx = EoiVoucherController.getVoucher(paid, 'convert');
        Assert.areEqual(EoiVoucherController.REFUNDED, ctx.status);
    }

    @IsTest
    static void convertRefusedBeforePayment() {
        Id voucherId = generate();
        try {
            EoiVoucherController.convertToBooking(voucherId, null);
            Assert.fail('Conversion before payment should be refused');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('paid'), e.getMessage());
        }
    }

    @IsTest
    static void voucherPdfIsFiled() {
        Id voucherId = generate();
        Id docId = EoiVoucherController.saveVoucherPdf(voucherId);
        Assert.areEqual(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :voucherId AND ContentDocumentId = :docId]);
    }

    @IsTest
    static void convertedLeadCarriesVouchersOver() {
        Id voucherId = generate();
        Account a = new Account(Name = 'Kavya Rao',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Business_Account').getRecordTypeId());
        insert a;
        Opportunity o = new Opportunity(Name = 'Kavya Rao - Varthur Vista', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), AccountId = a.Id);
        insert o;
        Id leadId = lead().Id;
        // Lead conversion needs a completed site visit in this org, so simulate the converted state.
        Lead before = (Lead) JSON.deserialize('{"attributes":{"type":"Lead"},"Id":"' + leadId + '","IsConverted":false}', Lead.class);
        Lead after = (Lead) JSON.deserialize('{"attributes":{"type":"Lead"},"Id":"' + leadId + '","IsConverted":true,'
            + '"ConvertedAccountId":"' + a.Id + '","ConvertedOpportunityId":"' + o.Id + '"}', Lead.class);
        EoiVoucherController.linkConvertedLeads(new List<Lead>{ after }, new Map<Id, Lead>{ leadId => before });
        Voucher__c v = [SELECT Account__c, Opportunity__c FROM Voucher__c WHERE Id = :voucherId];
        Assert.areEqual(a.Id, v.Account__c);
        Assert.areEqual(o.Id, v.Opportunity__c);
    }

    @IsTest
    static void configurationMatching() {
        Assert.isTrue(EoiVoucherController.matchesConfiguration('3BHK', '3 BHK Smart'));
        Assert.isFalse(EoiVoucherController.matchesConfiguration('4BHK', '4.5 BHK'));
        Assert.isTrue(EoiVoucherController.matchesConfiguration('Above 4BHK', '4.5 BHK'));
        Assert.isTrue(EoiVoucherController.matchesConfiguration('Above 4BHK', 'Penthouse'));
        Assert.isFalse(EoiVoucherController.matchesConfiguration('2BHK', null));
    }
}