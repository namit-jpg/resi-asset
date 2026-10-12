import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import load from '@salesforce/apex/BookingFormSiteController.load';
import saveDraft from '@salesforce/apex/BookingFormSiteController.saveDraft';
import submit from '@salesforce/apex/BookingFormSiteController.submit';
import { STEPS, validateStep, setPath, getPath, checkValue, clone, blankApplicant, MAX_CO_APPLICANTS } from 'c/bcfUtils';

const AUTOSAVE_MS = 1500;
const TOAST_MS = 4200;

/**
 * Customer booking form, served on the public "Nikoo Homes Booking" site.
 * The link carries ?t=<token>; every server call is scoped by that token.
 */
export default class BookingCustomerForm extends LightningElement {
    /** Lets the form run outside the site (for example in a test page); the URL's ?t= wins. */
    @api token;

    linkToken;
    context;
    data;
    payment;
    locked = false;
    submittedAt;
    errors = {};
    loading = true;
    loadError;
    saving = false;
    submitting = false;
    savedAt;
    toasts = [];
    showSavedModal = false;
    _autosave;
    _toastId = 0;

    @wire(CurrentPageReference)
    pageRef(ref) {
        // Public site links carry ?t=; inside Salesforce the parameter must be namespaced (c__t).
        const fromUrl = ref?.state?.t || ref?.state?.c__t;
        const next = fromUrl || this.token;
        if (next && next !== this.linkToken) {
            this.linkToken = next;
            this.load();
        } else if (!next && this.loading && ref) {
            this.loading = false;
            this.loadError = 'This booking link is not valid. Please use the link shared by your relationship manager.';
        }
    }

    connectedCallback() {
        // Outside LWR the wire may not fire with a token; fall back to the URL directly.
        if (!this.linkToken) {
            const t = new URLSearchParams(window.location.search).get('t') || this.token;
            if (t) {
                this.linkToken = t;
                this.load();
            }
        }
    }

    disconnectedCallback() {
        clearTimeout(this._autosave);
    }

    async load() {
        this.loading = true;
        this.loadError = undefined;
        try {
            const res = await load({ token: this.linkToken });
            this.context = res.context;
            this.payment = res.payment;
            this.locked = res.locked;
            this.submittedAt = res.submittedAt;
            const data = res.data || {};
            if (this.locked) {
                data.step = 'confirmation';
            } else if (!STEPS.some((s) => s.id === data.step)) {
                data.step = 'details';
            }
            if (!data.applicants?.length) {
                data.applicants = [blankApplicant('A1', 'PRIMARY')];
            }
            data.activeApplicant = data.activeApplicant || data.applicants[0].key;
            this.data = data;
        } catch (e) {
            this.loadError = message(e);
        } finally {
            this.loading = false;
        }
    }

    // ---------- view state ----------

    get ready() {
        return !this.loading && !this.loadError && this.data;
    }

    get step() {
        return this.data?.step;
    }

    get isDetails() {
        return this.step === 'details';
    }
    get isApplicants() {
        return this.step === 'applicants';
    }
    get isKyc() {
        return this.step === 'kyc';
    }
    get isPayment() {
        return this.step === 'payment';
    }
    get isSign() {
        return this.step === 'sign';
    }
    get isConfirmation() {
        return this.step === 'confirmation';
    }

    get stepIndex() {
        return STEPS.findIndex((s) => s.id === this.step);
    }

    get headerRef() {
        const c = this.context || {};
        return [c.project, c.unit].filter(Boolean).join(' · ');
    }

    get stepper() {
        const current = this.stepIndex;
        let reachable = true;
        return STEPS.map((s, i) => {
            const complete = Object.keys(validateStep(s.id, this.data, this.payment)).length === 0;
            const canGo = i <= current || reachable;
            const item = {
                ...s,
                number: i + 1,
                disabled: !canGo,
                done: i < current && complete,
                current: i === current,
                className: ['step', i === current ? 'step_active' : '', i < current && complete ? 'step_done' : '', !canGo ? 'step_locked' : '']
                    .filter(Boolean)
                    .join(' '),
                ariaCurrent: i === current ? 'step' : null
            };
            reachable = reachable && complete;
            return item;
        });
    }

    get showBack() {
        return this.stepIndex > 0;
    }

    get isLastStep() {
        return this.stepIndex === STEPS.length - 1;
    }

    get continueLabel() {
        return this.isLastStep ? (this.submitting ? 'Submitting…' : 'Submit booking') : 'Save and continue';
    }

    get continueDisabled() {
        return this.submitting || (this.isLastStep && Object.keys(validateStep('sign', this.data, this.payment)).length > 0);
    }

    get savedLabel() {
        if (this.saving) return 'Saving…';
        if (!this.savedAt) return '';
        const d = new Date(this.savedAt);
        return `Saved ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }

    // ---------- changes from steps ----------

    handleFieldChange(event) {
        const { path, value, commit, kind, label, required } = event.detail;
        this.data = setPath(this.data, path, value);
        const errors = { ...this.errors };
        if (commit) {
            const msg = checkValue(kind, value, label, required);
            if (msg) {
                errors[path] = msg;
            } else {
                delete errors[path];
            }
            this.queueAutosave();
        } else {
            delete errors[path];
        }
        this.errors = errors;
    }

    handleFormAction(event) {
        const { name, detail } = event.detail;
        switch (name) {
            case 'addCoApplicant':
                this.addCoApplicant();
                break;
            case 'removeApplicant':
                this.removeApplicant(detail.key);
                break;
            case 'setActive':
                this.data = { ...clone(this.data), activeApplicant: detail.key };
                break;
            case 'set':
                // Several paths at once (uploads, identity checks, signatures); saved straight away.
                this.data = Object.entries(detail.values).reduce((d, [p, v]) => setPath(d, p, v), this.data);
                this.clearErrors(Object.keys(detail.values));
                this.save(true);
                break;
            case 'payment':
                this.payment = detail.payment;
                this.clearErrors(['payment.status']);
                break;
            case 'toast':
                this.toast(detail.title, detail.message, detail.kind);
                break;
            default:
        }
    }

    addCoApplicant() {
        const count = this.data.applicants.length - 1;
        if (count >= MAX_CO_APPLICANTS) return;
        const used = new Set(this.data.applicants.map((a) => a.key));
        let n = this.data.applicants.length + 1;
        while (used.has(`A${n}`)) n++;
        const ap = blankApplicant(`A${n}`, 'CO_APPLICANT');
        const primary = this.data.applicants[0];
        ap.address = clone(primary.address) || { country: 'India' };
        const data = clone(this.data);
        data.applicants.push(ap);
        this.data = data;
    }

    removeApplicant(key) {
        const data = clone(this.data);
        data.applicants = data.applicants.filter((a) => a.key !== key || a.role === 'PRIMARY');
        if (data.activeApplicant === key) data.activeApplicant = data.applicants[0].key;
        this.data = data;
        // Errors are keyed by index, so recompute rather than shift them.
        this.errors = {};
        this.save(true);
    }

    clearErrors(paths) {
        const errors = { ...this.errors };
        Object.keys(errors).forEach((p) => {
            if (paths.some((x) => p === x || p.startsWith(`${x}.`) || x.startsWith(`${p}.`))) delete errors[p];
        });
        this.errors = errors;
    }

    // ---------- navigation ----------

    handleStepClick(event) {
        const target = event.currentTarget.dataset.id;
        const item = this.stepper.find((s) => s.id === target);
        if (item && !item.disabled) this.goTo(target);
    }

    handleBack() {
        if (this.stepIndex > 0) this.goTo(STEPS[this.stepIndex - 1].id);
    }

    async handleContinue() {
        const errors = validateStep(this.step, this.data, this.payment);
        if (Object.keys(errors).length) {
            this.errors = { ...this.errors, ...errors };
            this.toast('Check the highlighted fields', this.firstError(errors), 'bad');
            this.focusFirstError();
            return;
        }
        if (this.isLastStep) {
            await this.submit();
            return;
        }
        await this.goTo(STEPS[this.stepIndex + 1].id);
    }

    async goTo(stepId) {
        const previous = this.data;
        this.data = { ...clone(this.data), step: stepId };
        this.errors = {};
        if (!(await this.save(true))) {
            // Stay put so the customer does not lose work they think is saved.
            this.data = previous;
            return;
        }
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    firstError(errors) {
        return Object.values(errors)[0];
    }

    focusFirstError() {
        // Let the steps render the messages, then move focus to the first invalid control.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const host = this.template.querySelector('.step-body');
            host?.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }, 0);
    }

    // ---------- saving ----------

    queueAutosave() {
        clearTimeout(this._autosave);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._autosave = setTimeout(() => this.save(true), AUTOSAVE_MS);
    }

    /** Returns true when the draft reached the server. */
    async save(silent) {
        if (this.locked || !this.data) return false;
        clearTimeout(this._autosave);
        this.saving = true;
        try {
            this.savedAt = await saveDraft({ token: this.linkToken, payload: JSON.stringify(this.data) });
            if (!silent) this.toast('Saved', 'Your progress is saved. You can close this and resume later.', 'ok');
            return true;
        } catch (e) {
            this.toast('Could not save', message(e), 'bad');
            return false;
        } finally {
            this.saving = false;
        }
    }

    async handleSaveExit() {
        if (await this.save(true)) {
            this.showSavedModal = true;
        }
    }

    closeSavedModal() {
        this.showSavedModal = false;
    }

    stopClick(event) {
        event.stopPropagation();
    }

    async submit() {
        this.submitting = true;
        try {
            const res = await submit({ token: this.linkToken, payload: JSON.stringify({ ...this.data, step: 'sign' }) });
            this.submittedAt = res.submittedAt;
            this.locked = true;
            this.data = { ...clone(this.data), step: 'confirmation', submittedAt: res.submittedAt };
            this.toast('Booking submitted', 'Thank you. Your relationship manager has been notified.', 'ok');
            window.scrollTo({ top: 0, behavior: 'smooth' });
        } catch (e) {
            this.toast('Could not submit', message(e), 'bad');
        } finally {
            this.submitting = false;
        }
    }

    // ---------- toasts ----------

    toast(title, body, kind = 'info') {
        const id = ++this._toastId;
        this.toasts = [...this.toasts, { id, title, body, className: `toast toast_${kind}` }];
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.toasts = this.toasts.filter((t) => t.id !== id);
        }, TOAST_MS);
    }

    dismissToast(event) {
        const id = Number(event.currentTarget.dataset.id);
        this.toasts = this.toasts.filter((t) => t.id !== id);
    }

    get hasToasts() {
        return this.toasts.length > 0;
    }

    get primaryEmail() {
        return getPath(this.data, 'applicants.0.email');
    }
}

function message(e) {
    return e?.body?.message || e?.message || 'Something went wrong. Please try again.';
}