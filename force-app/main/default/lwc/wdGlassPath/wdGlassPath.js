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
            let list = data.values || [];
            if (this.isLead) {
                // Keep the linear sales pipeline strictly to: New -> Allocated -> Site Visit -> Qualified
                list = list.filter((v) => v.value !== 'Archive' && v.value !== 'Dropped');
            }
            this.values = list;
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

    get isSiteVisit() {
        return this.fieldRef === 'Site_Visit__c.Status__c';
    }

    get isLead() {
        return this.fieldRef === 'Lead.Status';
    }

    get isOffPathLead() {
        return this.isLead && (this.value === 'Archive' || this.value === 'Dropped');
    }

    get offPathStatusTitle() {
        if (this.value === 'Archive') return 'Archived Lead (Cooling-Off Period)';
        if (this.value === 'Dropped') return 'Dropped Lead';
        return this.value;
    }

    get offPathStatusDesc() {
        if (this.value === 'Archive') return 'This lead is currently in cooling-off. Select an active pipeline stage below and click Mark as current to reactivate.';
        if (this.value === 'Dropped') return 'This lead was dropped. Select an active pipeline stage below and click Mark as current to reactivate.';
        return '';
    }

    get steps() {
        const current = this.currentIndex;
        return this.values.map((v, i) => {
            const classes = ['step'];
            let isDone = false;

            if (this.isSiteVisit) {
                // For Site Visit, only Scheduled is a predecessor to Completed/Rescheduled/Cancelled.
                // Rescheduled is an alternative status, not a predecessor to Completed.
                if (this.value === 'Completed') {
                    isDone = (v.value === 'Scheduled');
                } else if (this.value === 'Rescheduled' || this.value === 'Cancelled') {
                    isDone = (v.value === 'Scheduled');
                } else {
                    isDone = false;
                }
            } else {
                isDone = i < current;
            }

            if (isDone) classes.push('step_done');
            if (i === current) classes.push(this.isLost ? 'step_current step_lost' : 'step_current');
            if (v.value === this.selected) classes.push('step_selected');
            return {
                key: v.value,
                value: v.value,
                label: v.label,
                className: classes.join(' '),
                ariaCurrent: i === current ? 'step' : null,
                isDone
            };
        });
    }

    get hasSteps() {
        return this.values.length > 0;
    }

    get selectedStepLabel() {
        if (!this.selected) return null;
        const s = this.values.find((v) => v.value === this.selected);
        return s ? s.label : this.selected;
    }

    get target() {
        if (this.selected && this.selected !== this.value) {
            return this.selected;
        }
        if (this.isOffPathLead) {
            return 'Allocated';
        }
        if (this.isSiteVisit) {
            // For Site Visit: Scheduled and Rescheduled advance to Completed.
            // Completed and Cancelled are terminal - no auto-advance target.
            if (this.value === 'Scheduled' || this.value === 'Rescheduled') {
                return 'Completed';
            }
            return null;
        }
        if (this.currentIndex >= 0 && this.currentIndex + 1 < this.values.length) {
            const next = this.values[this.currentIndex + 1];
            return next ? next.value : null;
        }
        return null;
    }

    get buttonLabel() {
        if (this.selected && this.selected !== this.value) {
            if (this.isOffPathLead) {
                return `Reactivate to ${this.selectedStepLabel}`;
            }
            return 'Mark as current';
        }
        if (this.isOffPathLead) {
            return 'Reactivate to Allocated';
        }
        if (this.isSiteVisit) {
            if (this.value === 'Completed') {
                return 'Completed';
            }
            if (this.value === 'Cancelled') {
                return 'Cancelled';
            }
        }
        if (this.isLead && this.value === 'Qualified') {
            return 'Qualified';
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
        if (this.fieldRef === 'Lead.Status' && target === 'Archive') {
            this.dispatchEvent(new CustomEvent('requestleadarchive', {
                bubbles: true,
                composed: true,
                detail: { target }
            }));
            this.selected = null;
            return;
        }
        if (this.isSiteVisit && target === 'Completed') {
            this.dispatchEvent(new CustomEvent('requestfeedback', {
                bubbles: true,
                composed: true,
                detail: { target, recordId: this.recordId }
            }));
            this.selected = null;
            return;
        }
        this.saving = true;
        try {
            const wasOffPath = this.isOffPathLead;
            await updateRecord({ fields: { Id: this.recordId, [this.fieldApiName]: target } });
            this.selected = null;
            const message = wasOffPath ? `Lead reactivated to ${target}.` : `Moved to ${target}.`;
            this.dispatchEvent(new ShowToastEvent({ title: 'Status updated', message, variant: 'success' }));
        } catch (e) {
            const message = e?.body?.output?.errors?.[0]?.message || e?.body?.message || 'Could not update the status.';
            this.dispatchEvent(new ShowToastEvent({ title: 'Update failed', message, variant: 'error' }));
        } finally {
            this.saving = false;
        }
    }
}