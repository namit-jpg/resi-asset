import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRelatedListsInfo, getRelatedListInfoBatch, getRelatedListRecordsBatch } from 'lightning/uiRelatedListApi';
import { formatDate } from 'c/wdGlassFormat';

// Activity has its own card; these lists aren't served by the related-list records API.
const SKIP = new Set([
    'OpenActivities',
    'ActivityHistories',
    'CombinedAttachments',
    'AttachedContentDocuments',
    'AttachedContentNotes',
    'ProcessSteps',
    'ProcessInstances',
    'Histories',
    'Feeds',
    'RecordActionHistories',
    'RecordActions'
]);
const MAX_LISTS = 12;
const PAGE_SIZE = 5;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}/;

function readPath(record, path) {
    const parts = path.split('.');
    let node = record;
    for (let i = 0; i < parts.length; i++) {
        const field = node?.fields?.[parts[i]];
        if (!field) {
            return null;
        }
        if (i === parts.length - 1) {
            if (typeof field.value === 'string' && ISO_DATE.test(field.value)) {
                return formatDate(field.value);
            }
            return field.displayValue ?? field.value;
        }
        node = field.value;
    }
    return null;
}

export default class WdGlassRelated extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @api recordTypeId;
    /** Related lists the old record page placed directly (Dynamic Related Lists), shown before layout lists. */
    @api extraLists = [];
    /** Lists that always get their own card, even with no records. */
    @api pinnedLists = [];

    listIds;
    listInfos = [];
    params;
    results = [];

    @wire(getRelatedListsInfo, { parentObjectApiName: '$objectApiName', recordTypeId: '$recordTypeId' })
    wiredLists({ data }) {
        if (data) {
            const layoutIds = (data.relatedLists || []).map((l) => l.relatedListId);
            const ids = [...new Set([...(this.extraLists || []), ...layoutIds])].filter((id) => !SKIP.has(id));
            this.listIds = ids.slice(0, MAX_LISTS);
        }
    }

    @wire(getRelatedListInfoBatch, { parentObjectApiName: '$objectApiName', relatedListNames: '$listIds' })
    wiredInfos({ data }) {
        if (!data) {
            return;
        }
        this.listInfos = (data.results || [])
            .filter((r) => r.statusCode === 200 && r.result)
            .map((r) => {
                const info = r.result;
                const childObject = info.objectApiNames?.[0] || info.listReference?.objectApiName;
                const columns = (info.displayColumns || []).slice(0, 3);
                return {
                    relatedListId: info.listReference?.relatedListId,
                    label: info.label,
                    childObject,
                    columns
                };
            })
            .filter((i) => i.relatedListId && i.childObject && i.columns.length);
        this.params = this.listInfos.map((i) => ({
            relatedListId: i.relatedListId,
            optionalFields: i.columns.map((c) => `${i.childObject}.${c.fieldApiName}`),
            pageSize: PAGE_SIZE
        }));
    }

    @wire(getRelatedListRecordsBatch, { parentRecordId: '$recordId', relatedListParameters: '$params' })
    wiredRecords({ data }) {
        if (data) {
            this.results = data.results || [];
        }
    }

    get lists() {
        return this.listInfos.map((info, index) => {
            const res = this.results[index];
            const ok = res && res.statusCode === 200;
            const records = ok ? res.result.records || [] : [];
            const more = ok && !!res.result.nextPageToken;
            const [primary, ...rest] = info.columns;
            return {
                key: info.relatedListId,
                relatedListId: info.relatedListId,
                label: info.label,
                loaded: !!res,
                failed: !!res && !ok,
                count: more ? `${records.length}+` : `${records.length}`,
                hasRecords: records.length > 0,
                pinned: (this.pinnedLists || []).includes(info.relatedListId),
                emptyText: `No ${(info.label || 'records').toLowerCase()} yet.`,
                rows: records.map((rec) => ({
                    id: rec.id || rec.fields?.Id?.value,
                    title: (primary ? readPath(rec, primary.fieldApiName) : null) || rec.fields?.Name?.value || rec.id,
                    meta: rest
                        .map((c) => readPath(rec, c.fieldApiName))
                        .filter((v) => v !== null && v !== undefined && v !== '')
                        .join(' · ')
                }))
            };
        });
    }

    get populated() {
        return this.lists.filter((l) => l.hasRecords || (l.pinned && l.loaded && !l.failed));
    }

    get emptyLists() {
        return this.lists.filter((l) => l.loaded && !l.failed && !l.hasRecords && !l.pinned);
    }

    get hasEmpty() {
        return this.emptyLists.length > 0;
    }

    handleOpen(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }

    handleViewAll(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: this.objectApiName,
                relationshipApiName: event.currentTarget.dataset.list,
                actionName: 'view'
            }
        });
    }
}