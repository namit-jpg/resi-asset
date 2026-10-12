import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import getActivity from '@salesforce/apex/WdGlassRecordController.getActivity';
import { formatDate, formatRelative } from 'c/wdGlassFormat';

const MAX_ITEMS = 6;
const KIND_LABEL = { task: 'Task', call: 'Call', email: 'Email', event: 'Event' };

export default class WdGlassActivity extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    /** Leads and contacts link activities through WhoId; everything else through WhatId. */
    @api isWho = false;

    items = [];
    loading = true;
    error;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        try {
            this.items = await getActivity({ recordId: this.recordId });
            this.error = undefined;
        } catch (e) {
            this.error = e?.body?.message || 'Could not load activity.';
        } finally {
            this.loading = false;
        }
    }

    decorate(a) {
        const overdue = a.isOpen && a.occursAt && new Date(a.occursAt) < new Date();
        return {
            ...a,
            kindLabel: KIND_LABEL[a.kind] || 'Activity',
            iconClass: `icon icon_${a.kind}`,
            when: a.isOpen ? formatDate(a.occursAt) : formatRelative(a.occursAt),
            meta: [a.owner, a.status].filter(Boolean).join(' · '),
            whenClass: overdue ? 'when when_overdue' : 'when'
        };
    }

    get upcoming() {
        return this.items.filter((a) => a.isOpen).slice(0, MAX_ITEMS).map((a) => this.decorate(a));
    }

    get past() {
        return this.items.filter((a) => !a.isOpen).slice(0, MAX_ITEMS).map((a) => this.decorate(a));
    }

    get hasUpcoming() {
        return this.upcoming.length > 0;
    }

    get hasPast() {
        return this.past.length > 0;
    }

    get isEmpty() {
        return !this.loading && !this.error && this.items.length === 0;
    }

    get linkField() {
        return this.isWho ? 'WhoId' : 'WhatId';
    }

    create(objectApiName, defaults) {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName, actionName: 'new' },
            state: {
                defaultFieldValues: encodeDefaultFieldValues({ [this.linkField]: this.recordId, ...defaults }),
                navigationLocation: 'RELATED_LIST'
            }
        });
    }

    handleNewTask() {
        this.create('Task', { Status: 'Not Started' });
    }

    handleLogCall() {
        const today = new Date();
        const iso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
        this.create('Task', { Subject: 'Call', Status: 'Completed', ActivityDate: iso });
    }

    handleNewEvent() {
        this.create('Event', {});
    }

    handleOpen(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }

    handleRefresh() {
        this.load();
    }
}