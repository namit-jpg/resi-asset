import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeadContext from '@salesforce/apex/EoiVoucherController.getLeadContext';
import generateVoucher from '@salesforce/apex/EoiVoucherController.generateVoucher';
import { formatInr } from 'c/wdGlassFormat';

const CONFIGURATIONS = ['2BHK', '3BHK', '4BHK', 'Above 4BHK'];

export default class EoiGenerateVoucher extends NavigationMixin(LightningElement) {
    _recordId;
    ctx;
    error;
    loading = true;
    saving = false;

    voucherType = 'Standard EOI';
    amount;
    configuration;
    validUntil;
    remarks = '';

    // Quick actions set recordId after construction, so load once it arrives.
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
            this.load();
        }
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            const ctx = await getLeadContext({ leadId: this._recordId });
            this.ctx = ctx;
            this.amount = ctx.amounts?.[this.voucherType];
            this.configuration = ctx.configuration;
            this.validUntil = ctx.validUntil;
        } catch (e) {
            this.error = message(e);
        } finally {
            this.loading = false;
        }
    }

    get blocked() {
        return this.ctx && !this.ctx.canGenerate;
    }

    get showForm() {
        return this.ctx && this.ctx.canGenerate;
    }

    get typeOptions() {
        return Object.keys(this.ctx?.amounts || {}).map((t) => ({
            label: `${t} · ${formatInr(this.ctx.amounts[t])}`,
            value: t
        }));
    }

    get configurationOptions() {
        return CONFIGURATIONS.map((c) => ({ label: c, value: c }));
    }

    get applicantFacts() {
        const c = this.ctx || {};
        return [
            { key: 'name', label: 'Applicant', value: c.name },
            { key: 'mobile', label: 'Mobile', value: c.mobile || '—' },
            { key: 'email', label: 'Email', value: c.email || '—' },
            { key: 'project', label: 'Project', value: c.project || '—' },
            { key: 'partner', label: 'Channel partner', value: c.channelPartner || 'Direct' }
        ];
    }

    get existingVouchers() {
        return (this.ctx?.vouchers || []).map((v) => ({ ...v, amountLabel: formatInr(v.amount) }));
    }

    get hasExisting() {
        return this.existingVouchers.length > 0;
    }

    get submitDisabled() {
        return this.saving || !this.showForm;
    }

    handleType(event) {
        this.voucherType = event.detail.value;
        this.amount = this.ctx.amounts[this.voucherType];
    }

    handleChange(event) {
        this[event.target.dataset.field] = event.detail.value;
    }

    handleOpenVoucher(event) {
        event.preventDefault();
        this.openRecord(event.currentTarget.dataset.id);
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSubmit() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
        if (!inputs.every((i) => i.reportValidity())) {
            return;
        }
        this.saving = true;
        this.error = undefined;
        try {
            const voucherId = await generateVoucher({
                leadId: this._recordId,
                voucherType: this.voucherType,
                amount: Number(this.amount),
                configuration: this.configuration,
                validUntil: this.validUntil,
                remarks: this.remarks
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'EOI voucher generated',
                    message: `Awaiting payment of ${formatInr(Number(this.amount))}.`,
                    variant: 'success'
                })
            );
            this.dispatchEvent(new CloseActionScreenEvent());
            this.openRecord(voucherId);
        } catch (e) {
            this.error = message(e);
        } finally {
            this.saving = false;
        }
    }

    openRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'Voucher__c', actionName: 'view' }
        });
    }
}

function message(e) {
    return e?.body?.message || e?.message || 'Something went wrong.';
}