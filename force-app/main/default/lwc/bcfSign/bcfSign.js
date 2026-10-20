import { LightningElement, api } from 'lwc';
import { DECLARATIONS, field, formatInr, formatDate, formatDateTime, initials } from 'c/bcfUtils';

/** Step 5: review the booking document, accept the declarations and sign (one signature per applicant). */
export default class BcfSign extends LightningElement {
    @api context;
    @api data;
    @api payment;
    @api errors;

    signing; // applicant index being signed
    typedName = '';
    agreed = false;

    get applicants() {
        return this.data?.applicants || [];
    }

    get signedCount() {
        return this.applicants.filter((a) => a.signature?.signedAt).length;
    }

    get signBadge() {
        const n = this.applicants.length;
        return this.signedCount === n
            ? { label: 'Completed', className: 'badge badge_ok' }
            : { label: `${this.signedCount} of ${n} signed`, className: 'badge badge_warn' };
    }

    get progressStyle() {
        const pct = this.applicants.length ? Math.round((100 * this.signedCount) / this.applicants.length) : 0;
        return `width:${pct}%`;
    }

    get docTitle() {
        const c = this.context || {};
        return `Booking form for unit ${c.unit || ''}${c.tower ? `, ${c.tower}` : ''}`;
    }

    get property() {
        const c = this.context || {};
        return [
            { key: 'project', label: 'Project', value: c.project || '—' },
            { key: 'unit', label: 'Tower / unit', value: [c.tower, c.unit].filter(Boolean).join(' / ') || '—' },
            { key: 'config', label: 'Configuration', value: c.configuration || '—' },
            { key: 'area', label: 'Chargeable area', value: c.chargeableArea ? `${Number(c.chargeableArea).toLocaleString('en-IN')} sq.ft.` : '—' },
            { key: 'floor', label: 'Floor', value: c.floor || '—' }
        ];
    }

    get consideration() {
        const c = this.context || {};
        return [
            { key: 'value', label: 'Booking value', value: formatInr(c.bookingValue) },
            { key: 'token', label: 'Token advance', value: this.payment?.status === 'Paid' ? `${formatInr(this.payment.amount)} (paid)` : formatInr(c.tokenAmount) },
            { key: 'plan', label: 'Payment plan', value: c.paymentPlan || '—' },
            { key: 'date', label: 'Booking date', value: formatDate(c.bookingDate) }
        ];
    }

    get applicantLines() {
        return this.applicants.map((a, i) => ({
            key: a.key,
            line: `${i + 1}. ${a.fullLegalName || '—'}`,
            meta: `${a.role === 'PRIMARY' ? 'Primary applicant' : `Co-applicant (${a.relationship || 'joint buyer'})`} · PAN ${a.pan || '—'}`
        }));
    }

    get nomineeLine() {
        const n = this.data?.nominee;
        return n?.provided ? `${n.fullName} · ${n.relationship} · ${n.sharePct}%` : 'None';
    }

    get declarationLines() {
        return DECLARATIONS.map((d) => ({ ...d, status: this.data?.declarations?.[d.id] ? 'Accepted' : 'Pending' }));
    }

    get signatureLines() {
        return this.applicants.map((a) => ({
            key: a.key,
            name: a.signature?.name || '',
            label: a.fullLegalName || 'Applicant',
            date: a.signature?.signedAt ? formatDate(a.signature.signedAt) : ''
        }));
    }

    get signers() {
        return this.applicants.map((a, i) => {
            const signed = !!a.signature?.signedAt;
            return {
                key: a.key,
                index: i,
                name: a.fullLegalName || 'Applicant',
                initials: initials(a.fullLegalName),
                role: a.role === 'PRIMARY' ? 'Primary applicant' : `Co-applicant · ${a.relationship || 'joint buyer'}`,
                signed,
                unsigned: !signed,
                detail: signed ? `Signed ${formatDateTime(a.signature.signedAt)}` : 'Signs with a typed electronic signature',
                badge: signed ? { label: 'Signed', className: 'badge badge_ok' } : { label: 'Not signed', className: 'badge' },
                error: this.errors?.[`applicants.${i}.signature`]
            };
        });
    }

    get declarationFields() {
        return DECLARATIONS.map((d) => field(this.data, this.errors, `declarations.${d.id}`, d.label, { type: 'checkbox' }));
    }

    get acceptedCount() {
        return DECLARATIONS.filter((d) => this.data?.declarations?.[d.id]).length;
    }

    get declarationBadge() {
        return this.acceptedCount === DECLARATIONS.length
            ? { label: 'Accepted', className: 'badge badge_ok' }
            : { label: `${this.acceptedCount} of ${DECLARATIONS.length} accepted`, className: 'badge badge_warn' };
    }

    get paymentPending() {
        return this.payment?.status !== 'Paid';
    }

    // ---------- signing ----------

    get signingApplicant() {
        return this.signing === undefined ? null : this.applicants[this.signing];
    }

    get adoptDisabled() {
        return this.typedName.trim().length <= 2 || !this.agreed;
    }

    openSign(event) {
        const index = Number(event.currentTarget.dataset.index);
        this.signing = index;
        this.typedName = this.applicants[index].fullLegalName || '';
        this.agreed = false;
    }

    closeSign() {
        this.signing = undefined;
    }

    stop(event) {
        event.stopPropagation();
    }

    handleTyped(event) {
        this.typedName = event.target.value;
    }

    handleAgree(event) {
        this.agreed = event.target.checked;
    }

    adopt() {
        const i = this.signing;
        this.dispatchEvent(
            new CustomEvent('formaction', {
                bubbles: true,
                composed: true,
                detail: {
                    name: 'set',
                    detail: {
                        values: {
                            [`applicants.${i}.signature`]: {
                                name: this.typedName.trim(),
                                signedAt: new Date().toISOString(),
                                method: 'Typed electronic signature',
                                consent: 'I agree to use electronic records and signatures for this booking.',
                                userAgent: navigator.userAgent
                            }
                        }
                    }
                }
            })
        );
        this.signing = undefined;
    }
}