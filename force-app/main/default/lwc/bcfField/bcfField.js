import { LightningElement, api } from 'lwc';

/**
 * One labelled input for the booking form. Renders from a descriptor built by bcfUtils.field()
 * and fires `fieldchange` { path, value, commit } — commit is true on blur/change, when the
 * form should validate the field.
 */
export default class BcfField extends LightningElement {
    @api field;

    get isSelect() {
        return this.field?.type === 'select';
    }

    get isCheckbox() {
        return this.field?.type === 'checkbox';
    }

    get isInput() {
        return !this.isSelect && !this.isCheckbox;
    }

    get inputId() {
        return `f-${(this.field?.path || '').replace(/\./g, '-')}`;
    }

    get errorId() {
        return `${this.inputId}-error`;
    }

    get inputClass() {
        return this.field?.error ? 'inp inp_error' : 'inp';
    }

    get wrapperClass() {
        return this.field?.wide ? 'fld span-2' : 'fld';
    }

    get ariaInvalid() {
        return this.field?.error ? 'true' : 'false';
    }

    get inputMode() {
        switch (this.field?.kind) {
            case 'mobile':
            case 'pincode':
            case 'share':
                return 'numeric';
            default:
                return undefined;
        }
    }

    get hasPlaceholderOption() {
        return !this.field?.value;
    }

    handleInput(event) {
        this.emit(this.normalise(event.target.value), false);
    }

    handleCommit(event) {
        this.emit(this.normalise(event.target.value), true);
    }

    handleCheck(event) {
        this.emit(event.target.checked, true);
    }

    normalise(value) {
        let v = value;
        if (this.field?.uppercase) {
            v = v.toUpperCase();
        }
        if (this.field?.kind === 'mobile' || this.field?.kind === 'pincode' || this.field?.kind === 'share') {
            v = v.replace(/[^0-9]/g, '');
        }
        return v;
    }

    emit(value, commit) {
        this.dispatchEvent(
            new CustomEvent('fieldchange', {
                detail: { path: this.field.path, value, commit, kind: this.field.kind, label: this.field.label, required: this.field.required },
                bubbles: true,
                composed: true
            })
        );
    }
}