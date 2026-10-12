import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getVoucher from '@salesforce/apex/EoiVoucherController.getVoucher';
import recordPayment from '@salesforce/apex/EoiVoucherController.recordPayment';
import allotUnit from '@salesforce/apex/EoiVoucherController.allotUnit';
import convertToBooking from '@salesforce/apex/EoiVoucherController.convertToBooking';
import closeVoucher from '@salesforce/apex/EoiVoucherController.closeVoucher';
import saveVoucherPdf from '@salesforce/apex/EoiVoucherController.saveVoucherPdf';
import { formatInr, formatDate } from 'c/wdGlassFormat';

const PAYMENT_MODES = ['UPI', 'Net Banking', 'Credit/Debit Card', 'NEFT/RTGS', 'Cheque', 'Demand Draft'];

// Which statuses each step accepts, and what to say otherwise.
const STEPS = {
    payment: {
        header: 'Record EOI payment',
        submit: 'Record payment',
        allowed: ['Payment Pending'],
        blocked: 'This voucher is not awaiting payment.'
    },
    allot: {
        header: 'Allot unit',
        submit: 'Allot unit',
        allowed: ['Paid', 'Allotted'],
        blocked: 'Record the full EOI payment before allotting a unit.'
    },
    convert: {
        header: 'Adjust against booking',
        submit: 'Adjust EOI',
        allowed: ['Paid', 'Allotted'],
        blocked: 'Only a paid EOI can be adjusted against a booking.'
    },
    close: {
        header: 'Cancel or refund EOI',
        submit: 'Confirm',
        allowed: ['Payment Pending', 'Paid', 'Allotted'],
        blocked: 'This voucher is already closed.'
    }
};

/**
 * One step of the EOI voucher lifecycle, shown inside a quick action.
 * Fires `done` when the step closes; the wrapping action closes its modal.
 */
export default class EoiVoucherStep extends LightningElement {
    @api mode = 'payment';

    _recordId;
    ctx;
    error;
    loading = true;
    saving = false;

    amount;
    paymentMode;
    reference = '';
    paidOn = todayIso();
    unitId;
    bookingId;
    reason = '';
    refundAmount;
    refundReference = '';
    refundedOn = todayIso();

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
            const ctx = await getVoucher({ voucherId: this._recordId, mode: this.mode });
            this.ctx = ctx;
            this.amount = ctx.balance;
            this.refundAmount = ctx.refundable ? ctx.amountPaid : 0;
            this.unitId = ctx.units?.[0]?.value;
            this.bookingId = ctx.bookings?.[0]?.value;
        } catch (e) {
            this.error = message(e);
        } finally {
            this.loading = false;
        }
    }

    get step() {
        return STEPS[this.mode] || STEPS.payment;
    }

    get header() {
        if (this.mode === 'close' && this.ctx) {
            return this.isRefund ? 'Refund EOI' : 'Cancel EOI';
        }
        return this.step.header;
    }

    get allowed() {
        return this.ctx && this.step.allowed.includes(this.ctx.status);
    }

    get blockedMessage() {
        return this.ctx && !this.allowed ? this.step.blocked : null;
    }

    get isPayment() {
        return this.allowed && this.mode === 'payment';
    }

    get isAllot() {
        return this.allowed && this.mode === 'allot';
    }

    get isConvert() {
        return this.allowed && this.mode === 'convert';
    }

    get isClose() {
        return this.allowed && this.mode === 'close';
    }

    get isRefund() {
        return (this.ctx?.amountPaid || 0) > 0;
    }

    get summary() {
        const c = this.ctx || {};
        const facts = [
            { key: 'voucher', label: 'Voucher', value: `${c.name} · ${c.voucherType || 'EOI'}` },
            { key: 'applicant', label: 'Applicant', value: c.applicant || '—' },
            { key: 'project', label: 'Project', value: [c.project, c.configuration].filter(Boolean).join(' · ') || '—' },
            { key: 'status', label: 'Status', value: c.status },
            { key: 'amount', label: 'EOI amount', value: formatInr(c.amount) },
            { key: 'paid', label: 'Received', value: formatInr(c.amountPaid) }
        ];
        if (c.priorityNumber) {
            facts.push({ key: 'priority', label: 'Priority', value: `#${c.priorityNumber}` });
        }
        if (c.unit) {
            facts.push({ key: 'unit', label: 'Unit', value: c.unit });
        }
        if (c.validUntil && c.status === 'Payment Pending') {
            facts.push({ key: 'valid', label: 'Pay by', value: formatDate(c.validUntil) + (c.expired ? ' (overdue)' : '') });
        }
        return facts;
    }

    get balanceLabel() {
        return formatInr(this.ctx?.balance);
    }

    get paidLabel() {
        return formatInr(this.ctx?.amountPaid);
    }

    get paymentModeOptions() {
        return PAYMENT_MODES.map((m) => ({ label: m, value: m }));
    }

    get unitOptions() {
        return (this.ctx?.units || []).map((u) => ({ label: u.detail ? `${u.label} — ${u.detail}` : u.label, value: u.value }));
    }

    get hasUnits() {
        return this.unitOptions.length > 0;
    }

    get bookingOptions() {
        return (this.ctx?.bookings || []).map((b) => ({ label: b.detail ? `${b.label} — ${b.detail}` : b.label, value: b.value }));
    }

    get hasBookings() {
        return this.bookingOptions.length > 0;
    }

    get refundHelp() {
        return this.ctx?.refundable ? 'Refundable in full.' : 'Marked non-refundable; enter 0 unless approved otherwise.';
    }

    get submitDisabled() {
        if (this.saving || !this.allowed) {
            return true;
        }
        if (this.isAllot) {
            return !this.unitId;
        }
        if (this.isConvert) {
            return !this.bookingId;
        }
        return false;
    }

    get submitVariant() {
        return this.mode === 'close' ? 'destructive' : 'brand';
    }

    handleChange(event) {
        this[event.target.dataset.field] = event.detail.value;
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('done'));
    }

    async handleSubmit() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')];
        if (!inputs.every((i) => i.reportValidity())) {
            return;
        }
        this.saving = true;
        this.error = undefined;
        try {
            const toast = await this.run();
            await notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
            this.dispatchEvent(new ShowToastEvent({ variant: 'success', ...toast }));
            this.dispatchEvent(new CustomEvent('done'));
        } catch (e) {
            this.error = message(e);
        } finally {
            this.saving = false;
        }
    }

    async run() {
        const voucherId = this._recordId;
        switch (this.mode) {
            case 'payment': {
                await recordPayment({
                    voucherId,
                    amount: Number(this.amount),
                    mode: this.paymentMode,
                    reference: this.reference,
                    paidOn: this.paidOn
                });
                const ctx = await getVoucher({ voucherId, mode: 'payment' });
                if (ctx.status !== 'Paid') {
                    return { title: 'Part payment recorded', message: `${formatInr(ctx.balance)} still due.` };
                }
                // The PDF render runs in its own transaction, after the payment is saved.
                let filed = '';
                try {
                    await saveVoucherPdf({ voucherId });
                    filed = ' The voucher PDF is saved to Files.';
                } catch (e) {
                    filed = ' The voucher PDF could not be generated.';
                }
                return { title: `EOI paid · priority #${ctx.priorityNumber}`, message: `${ctx.name} is in the ${ctx.project} queue.${filed}` };
            }
            case 'allot':
                await allotUnit({ voucherId, unitId: this.unitId });
                return { title: 'Unit allotted', message: this.labelFor(this.unitOptions, this.unitId) };
            case 'convert':
                await convertToBooking({ voucherId, bookingId: this.bookingId });
                return { title: 'EOI adjusted against booking', message: this.labelFor(this.bookingOptions, this.bookingId) };
            default:
                await closeVoucher({
                    voucherId,
                    reason: this.reason,
                    refundAmount: this.isRefund ? Number(this.refundAmount) : null,
                    refundReference: this.refundReference,
                    refundedOn: this.refundedOn
                });
                return this.isRefund
                    ? { title: 'EOI refunded', message: `${formatInr(Number(this.refundAmount))} refunded.` }
                    : { title: 'EOI cancelled', message: this.ctx.name };
        }
    }

    labelFor(options, value) {
        return options.find((o) => o.value === value)?.label || '';
    }
}

function todayIso() {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function message(e) {
    return e?.body?.message || e?.message || 'Something went wrong.';
}