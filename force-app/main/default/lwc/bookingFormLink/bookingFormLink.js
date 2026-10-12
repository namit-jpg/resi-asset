import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getStatus from '@salesforce/apex/BookingFormLinkController.getStatus';
import generateLink from '@salesforce/apex/BookingFormLinkController.generateLink';
import reopen from '@salesforce/apex/BookingFormLinkController.reopen';
import emailLink from '@salesforce/apex/BookingFormLinkController.emailLink';
import getShareMessage from '@salesforce/apex/BookingFormLinkController.getShareMessage';
import { formatInr, formatDate, formatDateTime } from 'c/bcfUtils';

const STEP_LABELS = {
    details: 'Your details',
    applicants: 'Co-applicants',
    kyc: 'KYC',
    payment: 'Token advance',
    sign: 'Sign',
    confirmation: 'Submitted'
};

/** Opportunity quick action: the customer's unique booking form link and its progress. */
export default class BookingFormLink extends NavigationMixin(LightningElement) {
    _recordId;
    s;
    error;
    loading = true;
    busy = false;
    confirmRegenerate = false;

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
            this.s = await getStatus({ opportunityId: this._recordId });
        } catch (e) {
            this.error = message(e);
        } finally {
            this.loading = false;
        }
    }

    get hasLink() {
        return !!this.s?.url;
    }

    get noLink() {
        return this.s && !this.s.url;
    }

    get isSubmitted() {
        return this.s?.status === 'Submitted';
    }

    get canGenerate() {
        return this.s && !this.isSubmitted && !this.s.siteError;
    }

    get generateLabel() {
        return this.hasLink ? 'Replace link' : 'Generate link';
    }

    get statusLabel() {
        if (this.s?.expired) return 'Link expired';
        return this.s?.status || 'Not generated';
    }

    get statusClass() {
        const st = this.s?.status;
        if (this.s?.expired) return 'badge badge_bad';
        if (st === 'Submitted') return 'badge badge_ok';
        if (st === 'In Progress' || st === 'Reopened') return 'badge badge_warn';
        return 'badge';
    }

    get facts() {
        const s = this.s || {};
        const rows = [
            { key: 'customer', label: 'Customer', value: s.customerName || '—' },
            { key: 'unit', label: 'Unit', value: [s.unit, s.project].filter(Boolean).join(' · ') || '—' },
            { key: 'token', label: 'Token advance', value: `${formatInr(s.tokenAmount)} · ${s.paymentStatus}` }
        ];
        if (s.generatedAt) rows.push({ key: 'gen', label: 'Link generated', value: formatDateTime(s.generatedAt) });
        if (s.expiresOn) rows.push({ key: 'exp', label: 'Valid until', value: formatDate(s.expiresOn) });
        if (s.step && !this.isSubmitted) rows.push({ key: 'step', label: 'Customer is on', value: STEP_LABELS[s.step] || s.step });
        if (s.lastSavedAt) rows.push({ key: 'saved', label: 'Last saved', value: formatDateTime(s.lastSavedAt) });
        if (s.submittedAt) rows.push({ key: 'sub', label: 'Submitted', value: formatDateTime(s.submittedAt) });
        if (s.paymentReference) rows.push({ key: 'pay', label: 'Payment ID', value: s.paymentReference });
        if (s.nominee) rows.push({ key: 'nom', label: 'Nominee', value: s.nominee });
        return rows;
    }

    get applicants() {
        return (this.s?.applicants || []).map((a, i) => ({
            ...a,
            key: `${i}`,
            line: [a.role, a.pan, a.mobile].filter(Boolean).join(' · '),
            docs: `${a.documents} document${a.documents === 1 ? '' : 's'}`,
            signLabel: a.signed ? 'Signed' : 'Not signed',
            signClass: a.signed ? 'badge badge_ok' : 'badge'
        }));
    }

    get hasApplicants() {
        return this.applicants.length > 0;
    }

    get whatsappDisabled() {
        return !this.hasLink || !this.s?.customerMobile;
    }

    get emailDisabled() {
        return !this.hasLink || !this.s?.customerEmail || this.busy;
    }

    async handleGenerate() {
        if (this.hasLink && !this.confirmRegenerate) {
            this.confirmRegenerate = true;
            return;
        }
        this.confirmRegenerate = false;
        await this.run(async () => {
            this.s = await generateLink({ opportunityId: this._recordId });
            this.toast('Booking form link ready', 'Copy it or send it to the customer.', 'success');
        });
    }

    cancelRegenerate() {
        this.confirmRegenerate = false;
    }

    async handleReopen() {
        await this.run(async () => {
            this.s = await reopen({ opportunityId: this._recordId });
            this.toast('Form reopened', 'The customer can edit and sign again using the same link.', 'success');
        });
    }

    async handleCopy() {
        try {
            await navigator.clipboard.writeText(this.s.url);
            this.toast('Link copied', '', 'success');
        } catch (e) {
            // Clipboard access can be blocked; select the text so the user can copy it.
            const input = this.template.querySelector('.link-input');
            input?.select();
            this.toast('Copy the selected link', 'Press Ctrl+C to copy.', 'info');
        }
    }

    handleOpen() {
        window.open(this.s.url, '_blank', 'noopener');
    }

    /** Opens the customer's form inside Salesforce, for demos and internal testing without the public site. */
    handleOpenInternal() {
        const token = new URL(this.s.url).searchParams.get('t');
        this.dispatchEvent(new CloseActionScreenEvent());
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__bookingCustomerForm' },
            state: { c__t: token }
        });
    }

    async handleWhatsApp() {
        await this.run(async () => {
            const text = await getShareMessage({ opportunityId: this._recordId });
            const digits = (this.s.customerMobile || '').replace(/\D/g, '');
            const phone = digits.length === 10 ? `91${digits}` : digits;
            window.open(`https://wa.me/${phone}?text=${encodeURIComponent(text)}`, '_blank', 'noopener');
        });
    }

    async handleEmail() {
        await this.run(async () => {
            const to = await emailLink({ opportunityId: this._recordId });
            this.toast('Email sent', `The link was emailed to ${to}.`, 'success');
        });
    }

    async run(fn) {
        this.busy = true;
        this.error = undefined;
        try {
            await fn();
            notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
        } catch (e) {
            this.error = message(e);
        } finally {
            this.busy = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
    }
}

function message(e) {
    return e?.body?.message || e?.message || 'Something went wrong.';
}