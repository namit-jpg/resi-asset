import { LightningElement, api } from 'lwc';
import { field, formatDateTime, SALUTATIONS, GENDERS, MARITAL, OCCUPATIONS, COUNTRIES, RESIDENTIAL } from 'c/bcfUtils';

const DEMO_OTP = '123456';

/** Step 1: the primary applicant's details and identity check. */
export default class BcfDetails extends LightningElement {
    @api data;
    @api errors;

    verifyOpen = false;
    verifyStage = 'form';
    docType = 'Aadhaar';
    docNumber = '';
    consent = true;
    otp = '';
    verifyError;

    get primary() {
        return this.data?.applicants?.[0] || {};
    }

    get fields() {
        const p = 'applicants.0';
        const d = this.data;
        const e = this.errors;
        return [
            field(d, e, `${p}.salutation`, 'Salutation', { type: 'select', choices: SALUTATIONS }),
            field(d, e, `${p}.fullLegalName`, 'Full legal name (as on PAN)', { required: true, wide: true, maxlength: 120 }),
            field(d, e, `${p}.dob`, 'Date of birth', { type: 'date', required: true, kind: 'adultDob' }),
            field(d, e, `${p}.gender`, 'Gender', { type: 'select', choices: GENDERS }),
            field(d, e, `${p}.maritalStatus`, 'Marital status', { type: 'select', choices: MARITAL }),
            field(d, e, `${p}.mobile`, 'Mobile', { type: 'tel', required: true, kind: 'mobile', maxlength: 10, placeholder: '10-digit mobile' }),
            field(d, e, `${p}.email`, 'Email', { type: 'email', required: true, kind: 'email', maxlength: 80 }),
            field(d, e, `${p}.pan`, 'PAN', { required: true, kind: 'pan', uppercase: true, maxlength: 10, placeholder: 'ABCPM1234K' }),
            field(d, e, `${p}.occupation`, 'Occupation / employment type', { type: 'select', choices: OCCUPATIONS, required: true }),
            field(d, e, `${p}.nationality`, 'Nationality', { type: 'select', choices: COUNTRIES, required: true }),
            field(d, e, `${p}.residentialStatus`, 'Residential status', { type: 'select', choices: RESIDENTIAL, required: true })
        ];
    }

    get identity() {
        return this.primary.identity || { stage: 'none' };
    }

    get isVerified() {
        return this.identity.stage === 'verified';
    }

    get identityBadge() {
        return this.isVerified ? { label: 'Verified', className: 'badge badge_ok' } : { label: 'Not verified', className: 'badge' };
    }

    get applicantName() {
        return this.primary.fullLegalName || 'the applicant';
    }

    get verifiedOn() {
        return formatDateTime(this.identity.verifiedAt);
    }

    get isFormStage() {
        return this.verifyStage === 'form';
    }

    get last4() {
        return this.docNumber.replace(/\D/g, '').slice(-4);
    }

    get docTypeOptions() {
        return ['Aadhaar', 'Passport', 'Voter ID'].map((v) => ({ value: v, label: v, selected: v === this.docType }));
    }

    openVerify() {
        this.verifyOpen = true;
        this.verifyStage = 'form';
        this.otp = '';
        this.verifyError = undefined;
    }

    closeVerify() {
        this.verifyOpen = false;
    }

    stop(event) {
        event.stopPropagation();
    }

    handleDocType(event) {
        this.docType = event.target.value;
    }

    handleDocNumber(event) {
        this.docNumber = event.target.value;
    }

    handleConsent(event) {
        this.consent = event.target.checked;
    }

    handleOtp(event) {
        this.otp = event.target.value.replace(/\D/g, '').slice(0, 6);
        event.target.value = this.otp;
    }

    sendOtp() {
        const digits = this.docNumber.replace(/\D/g, '');
        if (this.docType === 'Aadhaar' && digits.length !== 12) {
            this.verifyError = 'A 12-digit Aadhaar number is required.';
            return;
        }
        if (this.docType !== 'Aadhaar' && this.docNumber.trim().length < 6) {
            this.verifyError = 'Enter the document number.';
            return;
        }
        if (!this.consent) {
            this.verifyError = 'Tick the consent box to continue.';
            return;
        }
        this.verifyError = undefined;
        this.verifyStage = 'otp';
    }

    verifyOtp() {
        if (this.otp.length !== 6) {
            this.verifyError = 'Enter the 6-digit code.';
            return;
        }
        if (this.otp !== DEMO_OTP) {
            this.verifyError = 'Incorrect code. Check the code and try again.';
            return;
        }
        const reference = `UIDAI-${Math.floor(100000 + Math.random() * 900000)}`;
        this.dispatchEvent(
            new CustomEvent('formaction', {
                bubbles: true,
                composed: true,
                detail: {
                    name: 'set',
                    detail: {
                        values: {
                            'applicants.0.identity': {
                                stage: 'verified',
                                method: `${this.docType} OTP`,
                                reference,
                                documentLast4: this.last4,
                                nameMatch: true,
                                verifiedAt: new Date().toISOString()
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
                detail: { name: 'toast', detail: { title: 'Identity verified', message: `${this.applicantName}'s identity is verified.`, kind: 'ok' } }
            })
        );
        this.verifyOpen = false;
    }
}