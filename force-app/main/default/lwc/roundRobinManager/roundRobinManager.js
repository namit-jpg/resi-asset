import { LightningElement, track } from 'lwc';
import getQueues from '@salesforce/apex/RoundRobinManagerController.getQueues';
import getAllUsers from '@salesforce/apex/RoundRobinManagerController.getAllUsers';
import getUsersInQueue from '@salesforce/apex/RoundRobinManagerController.getUsersInQueue';
import getAssigneeRecords from '@salesforce/apex/RoundRobinManagerController.getAssigneeRecords';
import updateQueueMembers from '@salesforce/apex/RoundRobinManagerController.updateQueueMembers';
import updateAssigneeRecords from '@salesforce/apex/RoundRobinManagerController.updateAssigneeRecords';
import ensureAssigneesExistForUsers from '@salesforce/apex/RoundRobinManagerController.ensureAssigneesExistForUsers';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RoundRobinManager extends LightningElement {
    // === Truth State ===
    isAlwaysTrue = true;
    @track isUserListLoading = false;

    // === Navigation Control ===
    @track selectedNav = 'team';
    get isTeamManagement() { return this.selectedNav === 'team'; }
    get isUserManagement() { return this.selectedNav === 'user'; }

    handleNavSelect(event) {
        this.selectedNav = event.detail.name;
    }

    // === Queue Selection State ===
    @track queueOptions = [];
    @track selectedQueueId;
    @track userOptions = [];
    @track userSearchOptions = [];
    @track selectedUserIds = [];
    @track isSaveDisabled = true;

    // === User Management State ===
    @track selectedUserId = '';
    @track selectedUserName = '';
    @track selectedAssigneeId = '';
    @track isUserSaveDisabled = true;

    @track assignees = [];
    @track filteredUsers = [];

    // === Initial Load ===
    connectedCallback() {
        this.initializeData();
    }

    async initializeData() {
        try {
            await ensureAssigneesExistForUsers(); // ensures all active users have an assignee
            await Promise.all([
                this.loadQueues(),
                this.loadAllUsers(),
                this.loadAssigneeRecords()
            ]);
        } catch (e) {
            this.showError('Initialization failed', e);
        }
    }
    // === Data Loaders ===
    async loadQueues() {
        try {
            const data = await getQueues();
            this.queueOptions = data.map(q => ({ label: q.label, value: q.value }));
        } catch (e) {
            this.showError('Error loading queues', e);
        }
    }

    async loadAllUsers() {
        try {
            const users = await getAllUsers();
            this.userOptions = users.map(u => ({ label: u.label, value: u.value }));
            this.userSearchOptions = [...this.userOptions];
        } catch (e) {
            this.showError('Error loading users', e);
        }
    }

    async loadAssigneeRecords() {
        try {
            this.assignees = await getAssigneeRecords();
        } catch (e) {
            this.showError('Error loading assignee records', e);
        }
    }

    // === Team Management ===
    async handleQueueChange(event) {
        this.selectedQueueId = event.detail.value;
        try {
            this.selectedUserIds = await getUsersInQueue({ queueId: this.selectedQueueId });
            this.isSaveDisabled = true;
        } catch (e) {
            this.showError('Error loading queue members', e);
        }
    }

    get isDualListDisabled() {
        return !this.selectedQueueId || this.userOptions.length === 0;
    }

    handleSelectionChange(event) {
        this.selectedUserIds = event.detail.value;
        this.isSaveDisabled = false;
    }

    async saveQueueChanges() {
        try {
            await updateQueueMembers({ queueId: this.selectedQueueId, userIds: this.selectedUserIds });
            this.showSuccess('Queue members updated.');
            await this.loadAssigneeRecords();
            this.isSaveDisabled = true;
        } catch (e) {
            this.showError('Failed to update queue members', e);
        }
    }

    // === User Management ===
    handleUserSearchChange(event) {
        this.selectedUserId = event.detail.value;

        // Don't reset label unless valid option is selected
        const selected = this.userSearchOptions.find(u => u.value === this.selectedUserId);
        if (selected) {
            this.selectedUserName = selected.label;

            const assignee = this.assignees.find(a =>
                a.User__c === this.selectedUserId || a.userId === this.selectedUserId
            );

            if (assignee) {
                this.selectedAssigneeId = assignee.Id;
                this.filteredUsers = [assignee];
            } else {
                this.selectedAssigneeId = '';
                this.filteredUsers = [];
            }
        }

        this.isUserSaveDisabled = true;
    }

    handleUserFieldChange(event) {
        const field = event.target.dataset.field;
        const recordId = event.target.dataset.id;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        let hasChanged = false;

        this.filteredUsers = this.filteredUsers.map(user => {
            if (user.Id === recordId) {
                const original = user[field];
                if (original !== value) {
                    hasChanged = true;
                }
                return { ...user, [field]: value };
            }
            return user;
        });

        if (hasChanged) {
            this.isUserSaveDisabled = false;
        }
    }

    async saveUserUpdates() {
        try {
            await updateAssigneeRecords({ assignees: this.filteredUsers });
            this.showSuccess('User record updated.');

            await this.loadAssigneeRecords();
            this.filteredUsers = this.assignees.filter(a =>
                a.User__c === this.selectedUserId || a.userId === this.selectedUserId
            );
            this.isUserSaveDisabled = true;
        } catch (e) {
            this.showError('Error saving user changes', e);
        }
    }

    handleRecordSave() {
        this.showSuccess('Record saved successfully.');
        this.isUserSaveDisabled = true;
        this.loadAssigneeRecords();
        this.filteredUsers = [];
    }

    handleFormChange() {
        this.isUserSaveDisabled = false;
    }

    // === Toasts ===
    showSuccess(msg) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: msg,
            variant: 'success'
        }));
    }

    showError(title, error) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message: error?.body?.message || error?.message || 'Unknown error',
            variant: 'error'
        }));
    }
}