import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPage from '@salesforce/apex/WdGlassController.getPage';
import { formatTime } from 'c/wdGlassFormat';

const NOUNS = {
    leads: ['lead', 'leads'],
    inventory: ['unit', 'units'],
    bookings: ['booking', 'bookings']
};

const SEARCH_HINTS = {
    leads: 'Search name, project, source, owner',
    inventory: 'Search unit, project, building, type',
    bookings: 'Search booking, customer, project, unit'
};

export default class WdGlassPage extends NavigationMixin(LightningElement) {
    /** leads | inventory | bookings — set in Lightning App Builder. */
    @api pageKey = 'leads';

    data;
    view;
    searchTerm = '';
    loading = true;
    error;
    refreshedAt;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.data = await getPage({ pageKey: this.pageKey, view: this.view });
            this.view = this.data.view;
            this.refreshedAt = new Date();
        } catch (e) {
            this.error = e?.body?.message || e?.message || 'Could not load records.';
        } finally {
            this.loading = false;
        }
    }

    get eyebrow() {
        return this.data?.eyebrow;
    }

    get title() {
        return this.data?.title;
    }

    get newLabel() {
        return this.data?.newLabel || 'New';
    }

    get subtitle() {
        if (!this.data) {
            return 'Loading…';
        }
        const facts = [...(this.data.facts || [])];
        if (this.refreshedAt) {
            facts.push(`refreshed ${formatTime(this.refreshedAt)}`);
        }
        return facts.join(' · ');
    }

    get kpis() {
        return this.data?.kpis || [];
    }

    get columns() {
        return this.data?.columns || [];
    }

    get viewLabel() {
        return this.data?.viewLabel || '';
    }

    get viewOptions() {
        return (this.data?.views || []).map((v) => ({ ...v, selected: v.value === this.view }));
    }

    get searchPlaceholder() {
        return SEARCH_HINTS[this.pageKey] || 'Search';
    }

    get filteredRows() {
        const rows = this.data?.rows || [];
        const term = this.searchTerm.trim().toLowerCase();
        if (!term) {
            return rows;
        }
        return rows.filter((r) =>
            Object.entries(r).some(([k, v]) => k !== 'id' && v !== null && v !== undefined && String(v).toLowerCase().includes(term))
        );
    }

    get countLabel() {
        const [one, many] = NOUNS[this.pageKey] || ['record', 'records'];
        const n = this.filteredRows.length;
        return `${n} ${n === 1 ? one : many}`;
    }

    get emptyMessage() {
        return this.searchTerm ? 'Nothing matches that search.' : 'No records in this view yet.';
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
    }

    handleView(event) {
        this.view = event.target.value;
        this.load();
    }

    handleRefresh() {
        this.load();
    }

    handleNew() {
        const state = this.data?.recordTypeId ? { recordTypeId: this.data.recordTypeId } : {};
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: this.data?.objectApiName, actionName: 'new' },
            state
        });
    }

    handleListViews() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: this.data?.objectApiName, actionName: 'list' },
            state: { filterName: 'Recent' }
        });
    }
}