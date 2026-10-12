import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { loadStyle } from 'lightning/platformResourceLoader';
import getOpportunityContext from '@salesforce/apex/TowerExplorerController.getOpportunityContext';
import tagUnit from '@salesforce/apex/TowerExplorerController.tagUnit';
import MODAL_STYLES from '@salesforce/resourceUrl/TowerExplorerModal';

function errorMessage(error) {
    return error?.body?.message || error?.message || 'Something went wrong.';
}

export default class SelectInventory extends LightningElement {
    _recordId;
    context;
    selectedUnitId;
    selectedUnitName;
    saving = false;
    error;

    // Quick actions set recordId after construction, so load the context from the setter.
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
            this.loadContext();
        }
    }

    connectedCallback() {
        // Widens the standard quick-action modal, scoped with :has() to this component only.
        loadStyle(this, MODAL_STYLES).catch(() => {});
    }

    async loadContext() {
        try {
            this.context = await getOpportunityContext({ opportunityId: this._recordId });
            this.selectedUnitId = this.context.unitId;
            this.selectedUnitName = this.context.unitName;
        } catch (e) {
            this.error = errorMessage(e);
        }
    }

    get ready() {
        return !!this.context;
    }

    get subtitle() {
        if (!this.context) {
            return '';
        }
        return this.context.unitName
            ? `${this.context.opportunityName} · currently ${this.context.unitName}`
            : `${this.context.opportunityName} · no unit tagged yet`;
    }

    get selectionText() {
        if (!this.selectedUnitId) {
            return 'Pick an available unit from the stack.';
        }
        if (this.lockedReason) {
            return 'Unit changes are closed for this opportunity.';
        }
        if (this.selectedUnitId === this.context?.unitId) {
            return `${this.selectedUnitName} is already tagged.`;
        }
        return `${this.selectedUnitName} will be tagged and marked Reserved.`;
    }

    get lockedReason() {
        return this.context?.lockedReason;
    }

    get saveDisabled() {
        return this.saving || !!this.lockedReason || !this.selectedUnitId || this.selectedUnitId === this.context?.unitId;
    }

    handleUnitSelect(event) {
        this.selectedUnitId = event.detail.unitId;
        this.selectedUnitName = event.detail.unitName;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {
        this.saving = true;
        this.error = undefined;
        try {
            await tagUnit({ opportunityId: this._recordId, unitId: this.selectedUnitId });
            await notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unit tagged',
                    message: `${this.selectedUnitName} is now tagged to this opportunity and reserved.`,
                    variant: 'success'
                })
            );
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            this.error = errorMessage(e);
            // The unit may have been taken meanwhile; show the latest statuses.
            this.template.querySelector('c-tower-explorer')?.refresh();
        } finally {
            this.saving = false;
        }
    }
}