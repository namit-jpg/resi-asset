import { LightningElement, api } from 'lwc';
import uploadDocument from '@salesforce/apex/BookingFormSiteController.uploadDocument';
import { field, docsFor, formatSize, formatDate, STATES, COUNTRIES, CAPTURE_LABELS, MAX_FILE_BYTES } from 'c/bcfUtils';

const ACCEPT = '.pdf,.jpg,.jpeg,.png';
const STATUS = {
    uploaded: { label: 'Uploaded', className: 'badge badge_info' },
    under_verification: { label: 'Under verification', className: 'badge badge_warn' },
    verified: { label: 'Verified', className: 'badge badge_ok' },
    rejected: { label: 'Rejected', className: 'badge badge_bad' }
};

/** Step 3: addresses and KYC documents, one tab per applicant. */
export default class BcfKyc extends LightningElement {
    @api data;
    @api errors;
    @api token;

    upload; // { rule, applicantIndex }
    file;
    fileError;
    details = {};
    uploading = false;
    accept = ACCEPT;

    get applicants() {
        return this.data?.applicants || [];
    }

    get activeIndex() {
        const i = this.applicants.findIndex((a) => a.key === this.data?.activeApplicant);
        return i < 0 ? 0 : i;
    }

    get active() {
        return this.applicants[this.activeIndex] || {};
    }

    get showTabs() {
        return this.applicants.length > 1;
    }

    get tabs() {
        return this.applicants.map((ap, i) => {
            const prefix = `applicants.${i}`;
            const hasErrors = Object.keys(this.errors || {}).some((p) => p.startsWith(`${prefix}.`));
            const done = docsFor(ap).every((r) => !r.required || ap.documents?.[r.id]?.contentVersionId) && !!ap.address?.line1 && !!ap.address?.pincode;
            return {
                key: ap.key,
                label: ap.fullLegalName || (i === 0 ? 'Primary applicant' : `Co-applicant ${i}`),
                className: `tab${i === this.activeIndex ? ' tab_active' : ''}${hasErrors ? ' tab_error' : ''}`,
                done,
                selected: i === this.activeIndex ? 'true' : 'false'
            };
        });
    }

    addressFields(kind) {
        const p = `applicants.${this.activeIndex}.${kind}`;
        const d = this.data;
        const e = this.errors;
        return [
            field(d, e, `${p}.line1`, 'Address line 1', { required: true, wide: true, maxlength: 120 }),
            field(d, e, `${p}.line2`, 'Address line 2', { wide: true, maxlength: 120 }),
            field(d, e, `${p}.landmark`, 'Landmark', { wide: true, maxlength: 80 }),
            field(d, e, `${p}.locality`, 'Locality', { required: true, maxlength: 80 }),
            field(d, e, `${p}.city`, 'City', { required: true, maxlength: 60 }),
            field(d, e, `${p}.district`, 'District', { maxlength: 60 }),
            field(d, e, `${p}.state`, 'State', { type: 'select', choices: STATES, required: true }),
            field(d, e, `${p}.pincode`, 'PIN code', { required: true, kind: 'pincode', maxlength: 6 }),
            field(d, e, `${p}.country`, 'Country', { type: 'select', choices: COUNTRIES, required: true })
        ];
    }

    get permanentFields() {
        return this.addressFields('address');
    }

    get correspondenceFields() {
        return this.addressFields('correspondence');
    }

    get sameAsField() {
        return field(this.data, this.errors, `applicants.${this.activeIndex}.sameAsPermanent`, 'Same as permanent address', {
            type: 'checkbox',
            hint: 'Used for correspondence and KYC'
        });
    }

    get differentAddress() {
        return !this.active.sameAsPermanent;
    }

    get activeName() {
        return this.active.fullLegalName || 'Applicant';
    }

    get activeRole() {
        return this.active.role === 'PRIMARY' ? 'Primary applicant' : `Co-applicant · ${this.active.relationship || 'joint buyer'}`;
    }

    get documents() {
        const i = this.activeIndex;
        return docsFor(this.active).map((rule) => {
            const doc = this.active.documents?.[rule.id];
            const has = !!doc?.contentVersionId;
            const status = has ? STATUS[doc.status] || STATUS.uploaded : null;
            return {
                ...rule,
                has,
                fileLine: has ? `${doc.fileName} · ${formatSize(doc.size)} · ${formatDate(doc.uploadedAt)}` : '',
                status,
                buttonLabel: has ? (doc.status === 'rejected' ? 'Re-upload' : 'Replace') : 'Upload',
                canUpload: !has || ['uploaded', 'rejected'].includes(doc.status || 'uploaded'),
                reason: doc?.reason,
                error: this.errors?.[`applicants.${i}.documents.${rule.id}`],
                rowClass: `doc${this.errors?.[`applicants.${i}.documents.${rule.id}`] ? ' doc_error' : ''}`
            };
        });
    }

    get docCount() {
        const docs = this.documents;
        return `${docs.filter((d) => d.has).length} of ${docs.length} uploaded`;
    }

    // ---------- tabs ----------

    handleTab(event) {
        this.dispatchEvent(
            new CustomEvent('formaction', { bubbles: true, composed: true, detail: { name: 'setActive', detail: { key: event.currentTarget.dataset.key } } })
        );
    }

    // ---------- upload ----------

    get uploadRule() {
        return this.upload?.rule;
    }

    get captureFields() {
        return (this.uploadRule?.captures || []).map((c) => ({
            key: c,
            label: CAPTURE_LABELS[c],
            type: c.endsWith('Date') ? 'date' : 'text',
            value: this.details[c] || ''
        }));
    }

    get fileLabel() {
        return this.file ? `${this.file.name} · ${formatSize(this.file.size)}` : '';
    }

    get uploadDisabled() {
        return !this.file || this.uploading;
    }

    get uploadButtonLabel() {
        return this.uploading ? 'Uploading…' : 'Upload';
    }

    openUpload(event) {
        const rule = docsFor(this.active).find((r) => r.id === event.currentTarget.dataset.id);
        const existing = this.active.documents?.[rule.id];
        this.upload = { rule, applicantIndex: this.activeIndex };
        this.file = undefined;
        this.fileError = undefined;
        this.details = { ...(existing?.detail || {}) };
    }

    closeUpload() {
        if (!this.uploading) this.upload = undefined;
    }

    stop(event) {
        event.stopPropagation();
    }

    handleFile(event) {
        const f = event.target.files?.[0];
        this.fileError = undefined;
        if (!f) {
            this.file = undefined;
            return;
        }
        const ext = f.name.split('.').pop().toLowerCase();
        if (!['pdf', 'jpg', 'jpeg', 'png'].includes(ext)) {
            this.fileError = 'Upload a PDF, JPG or PNG file.';
            this.file = undefined;
            return;
        }
        if (f.size > MAX_FILE_BYTES) {
            this.fileError = 'Choose a file smaller than 3 MB.';
            this.file = undefined;
            return;
        }
        this.file = f;
    }

    handleDetail(event) {
        this.details = { ...this.details, [event.target.dataset.key]: event.target.value };
    }

    async doUpload() {
        if (!this.file) return;
        this.uploading = true;
        this.fileError = undefined;
        const { rule, applicantIndex } = this.upload;
        const applicant = this.applicants[applicantIndex];
        try {
            const base64 = await readAsBase64(this.file);
            const res = await uploadDocument({
                token: this.token,
                applicantName: applicant.fullLegalName,
                documentLabel: rule.label,
                fileName: this.file.name,
                base64Data: base64
            });
            const path = `applicants.${applicantIndex}.documents.${rule.id}`;
            this.dispatchEvent(
                new CustomEvent('formaction', {
                    bubbles: true,
                    composed: true,
                    detail: {
                        name: 'set',
                        detail: {
                            values: {
                                [path]: {
                                    status: 'uploaded',
                                    contentVersionId: res.contentVersionId,
                                    fileName: res.fileName,
                                    size: res.size,
                                    uploadedAt: res.uploadedAt,
                                    detail: this.details
                                }
                            }
                        }
                    }
                })
            );
            this.dispatchEvent(
                new CustomEvent('formaction', {
                    bubbles: true,
                    composed: true,
                    detail: { name: 'toast', detail: { title: 'Uploaded', message: `${rule.label} uploaded for ${applicant.fullLegalName || 'the applicant'}.`, kind: 'ok' } }
                })
            );
            this.upload = undefined;
        } catch (e) {
            this.fileError = e?.body?.message || e?.message || 'The upload failed. Please try again.';
        } finally {
            this.uploading = false;
        }
    }
}

function readAsBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result).split(',')[1]);
        reader.onerror = () => reject(new Error('The file could not be read.'));
        reader.readAsDataURL(file);
    });
}