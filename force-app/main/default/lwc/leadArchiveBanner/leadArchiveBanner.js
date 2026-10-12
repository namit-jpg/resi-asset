import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { updateRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import getArchiveInfo from '@salesforce/apex/LeadArchiveService.getArchiveInfo';
import completeFollowUp from '@salesforce/apex/LeadArchiveService.completeFollowUp';
import sendFollowUpNotification from '@salesforce/apex/LeadArchiveService.sendFollowUpNotification';

export default class LeadArchiveBanner extends LightningElement {
    @api recordId;

    @track isLoading = true;
    @track isArchived = false;
    @track isFollowUpDue = false;
    @track archiveDays = null;
    @track followUpDate = null;
    @track statusText = '';
    @track leadName = '';

    @track customDaysInput = '';

    // Modal state
    @track isModalOpen = false;
    @track modalSelectedDays = 14;
    @track modalDaysInput = '';

    connectedCallback() {
        this.loadStatus();
    }

    @api
    async loadStatus() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            const data = await getArchiveInfo({ leadId: this.recordId });
            this.isArchived = data.isArchived;
            this.isFollowUpDue = data.isFollowUpDue;
            this.archiveDays = data.archiveDays;
            this.followUpDate = data.followUpDate;
            this.statusText = data.statusText;
            this.leadName = data.leadName;
        } catch (e) {
            console.error('Error fetching archive info:', e);
        } finally {
            this.isLoading = false;
        }
    }

    @api
    openModal(days = 14) {
        this.modalSelectedDays = Number(days) || 14;
        this.modalDaysInput = '';
        this.isModalOpen = true;
    }

    @api
    closeModal() {
        this.isModalOpen = false;
    }

    get isIdle() {
        return !this.isArchived && !this.isFollowUpDue;
    }

    get formattedFollowUpDate() {
        if (!this.followUpDate) return '';
        const d = new Date(this.followUpDate);
        return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
    }

    get isSaveDisabled() {
        const val = Number(this.customDaysInput);
        return !val || val <= 0 || val > 365;
    }

    get effectiveModalDays() {
        if (this.modalDaysInput) {
            return Number(this.modalDaysInput);
        }
        return this.modalSelectedDays || 14;
    }

    get isModalSaveDisabled() {
        const d = this.effectiveModalDays;
        return !d || d <= 0 || d > 365;
    }

    get modalCalculatedFollowUpDate() {
        const d = new Date();
        d.setDate(d.getDate() + this.effectiveModalDays);
        return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
    }

    get modalPreset7Class() {
        return this.effectiveModalDays === 7 ? 'modal-preset-card active' : 'modal-preset-card';
    }
    get modalPreset14Class() {
        return this.effectiveModalDays === 14 ? 'modal-preset-card active' : 'modal-preset-card';
    }
    get modalPreset30Class() {
        return this.effectiveModalDays === 30 ? 'modal-preset-card active' : 'modal-preset-card';
    }
    get modalPreset60Class() {
        return this.effectiveModalDays === 60 ? 'modal-preset-card active' : 'modal-preset-card';
    }

    handleModalSelectDays(event) {
        this.modalSelectedDays = Number(event.currentTarget.dataset.days);
        this.modalDaysInput = '';
    }

    handleModalDaysInputChange(event) {
        this.modalDaysInput = event.target.value;
    }

    handleDaysInputChange(event) {
        this.customDaysInput = event.target.value;
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !this.isSaveDisabled) {
            this.handleSaveCustomArchive();
        }
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    async handleConfirmModalArchive() {
        const days = this.effectiveModalDays;
        if (!days || days <= 0) return;

        this.isLoading = true;
        this.isModalOpen = false;
        try {
            const fields = {
                Id: this.recordId,
                Status: 'Archive',
                Archive_For_In_Days__c: days
            };
            await updateRecord({ fields });
            this.showToast('Lead Archived', `Follow-up scheduled in ${days} days (${this.modalCalculatedFollowUpDate}).`, 'success');
            await this.loadStatus();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (err) {
                console.warn(err);
            }
        } catch (error) {
            this.showToast('Error Archiving Lead', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    async handleQuickArchive(event) {
        const days = Number(event.target.dataset.days);
        if (days > 0) {
            await this.saveArchiveDays(days);
        }
    }

    async handleSaveCustomArchive() {
        const days = Number(this.customDaysInput);
        if (days > 0) {
            await this.saveArchiveDays(days);
            this.customDaysInput = '';
        }
    }

    async saveArchiveDays(days) {
        this.isLoading = true;
        try {
            const fields = {
                Id: this.recordId,
                Status: 'Archive',
                Archive_For_In_Days__c: days
            };
            await updateRecord({ fields });
            this.showToast('Lead Archived', `Follow-up scheduled in ${days} days. Lead moved to Archive.`, 'success');
            await this.loadStatus();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (err) {
                console.warn(err);
            }
        } catch (error) {
            this.showToast('Error Archiving Lead', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    async handleCompleteFollowUp() {
        this.isLoading = true;
        try {
            await completeFollowUp({ leadId: this.recordId });
            this.showToast('Lead Restored!', 'Follow-up marked completed. Lead returned to active Allocated status.', 'success');
            await this.loadStatus();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (err) {
                console.warn(err);
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    async handleTriggerNow() {
        this.isLoading = true;
        try {
            await sendFollowUpNotification({ leadId: this.recordId });
            this.showToast('Notification Dispatched! 🔔', 'Alert: "Customer might be ready, follow up" sent to owner with high-priority task created.', 'warning');
            await this.loadStatus();
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (err) {
                console.warn(err);
            }
        } catch (error) {
            this.showToast('Error Dispatching Alert', error.body?.message || error.message, 'error');
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}