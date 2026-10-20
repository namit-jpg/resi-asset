import { LightningElement, api } from 'lwc';
import { formatInr, formatDate, formatDateTime, eoiLines } from 'c/bcfUtils';

/** Shown after submission, and whenever a submitted link is reopened by the customer. */
export default class BcfConfirmation extends LightningElement {
    @api context;
    @api data;
    @api payment;
    @api submittedAt;

    get unitLabel() {
        const c = this.context || {};
        return [c.unit, c.tower].filter(Boolean).join(', ');
    }

    get email() {
        return this.data?.applicants?.[0]?.email;
    }

    get submittedOn() {
        return formatDateTime(this.submittedAt || this.data?.submittedAt);
    }

    get timeline() {
        const paid = this.payment?.status === 'Paid';
        return [
            { key: 'form', title: 'Booking form submitted', detail: this.submittedOn, done: true },
            { key: 'pay', title: 'Token advance received', detail: paid ? formatInr(this.payment.amount) : 'Pending', done: paid },
            { key: 'sign', title: 'Signatures complete', detail: `${(this.data?.applicants || []).length} of ${(this.data?.applicants || []).length} signed`, done: true },
            { key: 'review', title: 'Sales and CRM review', detail: 'Usually within 1 working day', done: false },
            { key: 'allot', title: 'Booking approval and allotment letter', detail: 'After review', done: false }
        ].map((t) => ({ ...t, className: t.done ? 'tl tl_done' : 'tl', mark: t.done ? '✓' : '' }));
    }

    get glance() {
        const c = this.context || {};
        const docs = (this.data?.applicants || []).reduce((n, a) => n + Object.values(a.documents || {}).filter((d) => d.contentVersionId).length, 0);
        return [
            { key: 'applicants', label: 'Applicants', value: (this.data?.applicants || []).map((a) => a.fullLegalName).join(', ') },
            { key: 'project', label: 'Project', value: c.project },
            { key: 'value', label: 'Total booking value', value: formatInr(c.bookingValue) },
            ...eoiLines(c),
            { key: 'paid', label: 'Paid today', value: this.payment?.status === 'Paid' ? formatInr(this.payment.amount) : '—' },
            { key: 'plan', label: 'Payment plan', value: c.paymentPlan || '—' },
            { key: 'docs', label: 'Documents', value: `${docs} uploaded` },
            { key: 'date', label: 'Booking date', value: formatDate(c.bookingDate) }
        ];
    }

    get rm() {
        return this.context?.relationshipManager;
    }
}