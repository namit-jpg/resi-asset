import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

/**
 * Field sections of a glass record page. Each section collapses on its header and edits in place:
 * the pencil (or a double-click on the fields) swaps just that section for a record-edit-form.
 */
export default class WdGlassSections extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @api recordTypeId;
    /** [{ key, label, gridClass, filled, fields: [field views from wdGlassRecord] }] */
    @api sections = [];
    @api readOnly = false;

    collapsed = {};
    editing;
    saving = false;

    get rows() {
        return (this.sections || []).map((s) => {
            const isCollapsed = !!this.collapsed[s.label];
            const isEditing = this.editing === s.label;
            return {
                ...s,
                isEditing,
                isOpen: !isCollapsed,
                ariaExpanded: String(!isCollapsed || isEditing),
                chevronClass: isCollapsed && !isEditing ? 'chevron chevron_closed' : 'chevron',
                canEdit: !this.readOnly && !isEditing,
                editTitle: `Edit ${s.label}`
            };
        });
    }

    handleToggle(event) {
        const label = event.currentTarget.dataset.label;
        if (label && label !== this.editing) {
            this.collapsed = { ...this.collapsed, [label]: !this.collapsed[label] };
        }
    }

    handleEdit(event) {
        const label = event.currentTarget.dataset.label;
        if (this.readOnly || !label) {
            return;
        }
        this.collapsed = { ...this.collapsed, [label]: false };
        this.editing = label;
    }

    handleCancel() {
        this.editing = undefined;
    }

    handleSubmit() {
        this.saving = true;
    }

    handleSaved() {
        const label = this.editing;
        this.saving = false;
        this.editing = undefined;
        this.dispatchEvent(new ShowToastEvent({ title: 'Saved', message: `${label} updated.`, variant: 'success' }));
        this.dispatchEvent(new CustomEvent('saved'));
    }

    handleError() {
        this.saving = false;
    }

    handleOpenRecord(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }
}