import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { formatCell, statusTone } from 'c/wdGlassFormat';

const RIGHT_ALIGNED = new Set(['inr', 'area', 'number']);
const PAGE_SIZE = 25;

export default class WdGlassTable extends NavigationMixin(LightningElement) {
    @api columns = [];
    @api emptyMessage = 'No records to show.';

    sortKey;
    sortAsc = true;
    shown = PAGE_SIZE;
    _rows = [];

    @api
    get rows() {
        return this._rows;
    }
    set rows(value) {
        this._rows = value || [];
        this.shown = PAGE_SIZE;
    }

    get headers() {
        return (this.columns || []).map((c) => {
            const active = c.key === this.sortKey;
            let arrow = '';
            let ariaSort = 'none';
            if (active) {
                arrow = this.sortAsc ? '↑' : '↓';
                ariaSort = this.sortAsc ? 'ascending' : 'descending';
            }
            return {
                key: c.key,
                label: c.label,
                className: RIGHT_ALIGNED.has(c.type) ? 'align-right' : '',
                arrow,
                ariaSort
            };
        });
    }

    get sortedRows() {
        if (!this.sortKey) {
            return this._rows;
        }
        const key = this.sortKey;
        const dir = this.sortAsc ? 1 : -1;
        return [...this._rows].sort((a, b) => {
            const x = a[key];
            const y = b[key];
            if (x === y) return 0;
            if (x === null || x === undefined) return 1;
            if (y === null || y === undefined) return -1;
            const cmp = typeof x === 'number' && typeof y === 'number' ? x - y : String(x).localeCompare(String(y));
            return cmp * dir;
        });
    }

    get visibleRows() {
        const cols = this.columns || [];
        return this.sortedRows.slice(0, this.shown).map((row) => ({
            id: row.id,
            cells: cols.map((c) => ({
                key: `${row.id}-${c.key}`,
                display: formatCell(c.type, row[c.key]),
                isLink: c.type === 'link',
                isStatus: c.type === 'status' && !!row[c.key],
                statusClass: c.type === 'status' ? `status status_${statusTone(row[c.key])}` : '',
                className: RIGHT_ALIGNED.has(c.type) ? 'align-right num' : ''
            }))
        }));
    }

    get isEmpty() {
        return this._rows.length === 0;
    }

    get remaining() {
        return this._rows.length - this.shown;
    }

    get hasMore() {
        return this.remaining > 0;
    }

    handleSort(event) {
        const key = event.currentTarget.dataset.key;
        this.sortAsc = this.sortKey === key ? !this.sortAsc : true;
        this.sortKey = key;
    }

    handleMore() {
        this.shown += PAGE_SIZE;
    }

    handleOpen(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }
}