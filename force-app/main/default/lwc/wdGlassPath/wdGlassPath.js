import { LightningElement, api, wire } from 'lwc';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { statusTone } from 'c/wdGlassFormat';

export default class WdGlassPath extends LightningElement {
    @api recordId;
    /** Qualified field, e.g. Lead.Status */
    @api fieldRef;
    @api recordTypeId;
    @api value;

    values = [];
    selected;
    saving = false;

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: '$fieldRef' })
    wiredValues({ data }) {
        if (data) {
            this.values = data.values || [];
        }
    }

    get fieldApiName() {
        return (this.fieldRef || '').split('.').pop();
    }

    get currentIndex() {
        return this.values.findIndex((v) => v.value === this.value);
    }

    get isLost() {
        return statusTone(this.value) === 'negative';
    }

    get steps() {
        const current = this.currentIndex;
        return this.values.map((v, i) => {
            const classes = ['step'];
            if (i < current) classes.push('step_done');
            if (i === current) classes.push(this.isLost ? 'step_current step_lost' : 'step_current');
            if (v.value === this.selected) classes.push('step_selected');
            return {
                key: v.value,
                value: v.value,
                label: v.label,
                className: classes.join(' '),
                ariaCurrent: i === current ? 'step' : null,
                isDone: i < current
            };
        });
    }

    get hasSteps() {
        return this.values.length > 0;
    }

    get target() {
        if (this.selected && this.selected !== this.value) {
            return this.selected;
        }
        const next = this.values[this.currentIndex + 1];
        return next ? next.value : null;
    }

    get buttonLabel() {
        if (this.selected && this.selected !== this.value) {
            return 'Mark as current';
        }
        return 'Mark complete';
    }

    get buttonDisabled() {
        return !this.target || this.saving;
    }

    get currentLabel() {
        const v = this.values[this.currentIndex];
        return v ? v.label : 'Not set';
    }

    handleSelect(event) {
        const value = event.currentTarget.dataset.value;
        this.selected = this.selected === value ? null : value;
    }

    async handleMark() {
        const target = this.target;
        if (!target) {
            return;
        }
        this.saving = true;
        try {
            await updateRecord({ fields: { Id: this.recordId, [this.fieldApiName]: target } });
            this.selected = null;
            this.dispatchEvent(new ShowToastEvent({ title: 'Status updated', message: `Moved to ${target}.`, variant: 'success' }));
        } catch (e) {
            const message = e?.body?.output?.errors?.[0]?.message || e?.body?.message || 'Could not update the status.';
            this.dispatchEvent(new ShowToastEvent({ title: 'Update failed', message, variant: 'error' }));
        } finally {
            this.saving = false;
        }
    }
}