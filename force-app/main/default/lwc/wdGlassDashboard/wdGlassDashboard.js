import { LightningElement, api, wire } from 'lwc';
import getSalesDashboard from '@salesforce/apex/WdGlassDashboardController.getSalesDashboard';
import getFilterOptions from '@salesforce/apex/WdGlassDashboardController.getFilterOptions';
import { formatDate, formatTime } from 'c/wdGlassFormat';
import { inrShort, percent, plural } from 'c/wdGlassDashUtils';

const PERIODS = [
    { value: 'month', label: 'Month' },
    { value: 'quarter', label: 'Quarter' },
    { value: 'fy', label: 'FY' },
    { value: 'custom', label: 'Dates' }
];
// Dimension filters, in the order they sit in the filter bar.
const FILTERS = [
    { name: 'projectId', label: 'Project', all: 'All projects', source: 'projects' },
    { name: 'city', label: 'Location', all: 'All locations', source: 'cities' },
    { name: 'ownerId', label: 'Sales executive', all: 'Whole team', source: 'owners' },
    { name: 'leadSource', label: 'Lead source', all: 'All sources', source: 'sources' },
    { name: 'configuration', label: 'Unit configuration', all: 'All configurations', source: 'configurations' },
    { name: 'channel', label: 'Channel / campaign', all: 'All channels', source: 'channels' }
];
const TIP_EDGE = 110;

function options(list, selected) {
    return list.map((o) => ({
        ...o,
        pressed: String(o.value === selected),
        cls: o.value === selected ? 'seg seg_on' : 'seg'
    }));
}

function isoDate(d) {
    const pad = (n) => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/**
 * Glass sales dashboard: KPI tiles, target vs actual, money trend, collections, pipeline, funnel,
 * lead sources, project-wise performance, sales executives, lost reasons, stock, cancellations,
 * site-visit rhythm and agenda. Every panel follows the filter bar. Charts raise `tip` events
 * and this component draws the single shared tooltip.
 */
export default class WdGlassDashboard extends LightningElement {
    @api eyebrow = 'Nikoo Homes · Residential sales';
    @api defaultPeriod = 'fy';

    period;
    fromDate;
    toDate;
    filters = {};
    filterOptions;
    data;
    loading = true;
    error;
    refreshedAt;
    tip;
    tipLeft = 0;
    tipTop = 0;
    requestId = 0;
    // filters JSON -> pending or settled request, so switching back is instant.
    cache = new Map();
    ready = new Set();

    @wire(getFilterOptions)
    wiredOptions({ data }) {
        if (data) {
            this.filterOptions = data;
        }
    }

    connectedCallback() {
        this.period = PERIODS.some((p) => p.value === this.defaultPeriod) ? this.defaultPeriod : 'fy';
        const today = new Date();
        this.toDate = isoDate(today);
        this.fromDate = isoDate(new Date(today.getFullYear(), today.getMonth(), 1));
        this.load();
    }

    payload(period) {
        const p = { period, ...this.filters };
        if (period === 'custom') {
            p.fromDate = this.fromDate;
            p.toDate = this.toDate;
        }
        Object.keys(p).forEach((k) => {
            if (p[k] === '' || p[k] === undefined) {
                delete p[k];
            }
        });
        return JSON.stringify(p);
    }

    fetch(key) {
        if (!this.cache.has(key)) {
            const request = getSalesDashboard({ filtersJson: key });
            request.then(
                () => this.ready.add(key),
                () => this.cache.delete(key)
            );
            this.cache.set(key, request);
        }
        return this.cache.get(key);
    }

    /** Warms the cache for the other period buttons under the same filters. */
    prefetch() {
        PERIODS.filter((p) => p.value !== 'custom').forEach((p) => this.fetch(this.payload(p.value)));
    }

    async load() {
        const id = ++this.requestId;
        const key = this.payload(this.period);
        // Cached answers swap in without dimming the page.
        this.loading = !this.ready.has(key);
        this.error = undefined;
        try {
            const result = await this.fetch(key);
            // Ignore a slower earlier response that lands after a newer filter change.
            if (id === this.requestId) {
                this.data = result;
                this.refreshedAt = this.refreshedAt || new Date();
            }
        } catch (e) {
            if (id === this.requestId) {
                this.error = e?.body?.message || e?.message || 'Could not load the dashboard.';
            }
        } finally {
            if (id === this.requestId) {
                this.loading = false;
                this.prefetch();
            }
        }
    }

    // ---------- filter bar ----------

    get periodOptions() {
        return options(PERIODS, this.period);
    }

    get isCustom() {
        return this.period === 'custom';
    }

    get filterControls() {
        const o = this.filterOptions || {};
        return FILTERS.map((f) => {
            const list = (o[f.source] || []).map((x) => ({
                label: x.kind && f.name === 'channel' ? `${x.kind}: ${x.label}` : x.label,
                value: x.value
            }));
            return {
                name: f.name,
                label: f.label,
                value: this.filters[f.name] || '',
                options: [{ label: f.all, value: '' }, ...list]
            };
        });
    }

    get activeFilterCount() {
        return Object.values(this.filters).filter(Boolean).length;
    }

    get hasActiveFilters() {
        return this.activeFilterCount > 0;
    }

    handlePeriod(event) {
        const value = event.currentTarget.dataset.value;
        if (value !== this.period) {
            this.period = value;
            this.load();
        }
    }

    handleDate(event) {
        const { name, value } = event.target;
        if (!value) {
            return;
        }
        this[name] = value;
        if (this.fromDate && this.toDate && this.fromDate <= this.toDate) {
            this.load();
        }
    }

    handleFilter(event) {
        this.filters = { ...this.filters, [event.target.name]: event.detail.value };
        this.load();
    }

    handleClearFilters() {
        this.filters = {};
        this.load();
    }

    handleRefresh() {
        this.cache.clear();
        this.ready.clear();
        this.refreshedAt = undefined;
        this.load();
    }

    // ---------- panel inputs ----------

    get subtitle() {
        if (!this.data) {
            return 'Loading…';
        }
        const d = this.data;
        const owner = this.filters.ownerId
            ? (this.filterOptions?.owners || []).find((o) => o.value === this.filters.ownerId)?.label || 'one executive'
            : 'whole team';
        const parts = [
            d.period === 'custom' ? d.periodLabel : `${d.periodLabel} · ${formatDate(d.periodStart)} – ${formatDate(d.periodEnd)}`,
            owner
        ];
        if (d.activeFilters) {
            parts.push(plural(d.activeFilters, 'filter'));
        }
        parts.push(`changes compared with ${d.period === 'month' ? `the same point in ${d.previousLabel}` : d.period === 'custom' ? d.previousLabel : `the same point ${d.previousLabel}`}`);
        if (this.refreshedAt) {
            parts.push(`refreshed ${formatTime(this.refreshedAt)}`);
        }
        return parts.join(' · ');
    }

    get targetMonths() {
        return (this.data?.targets || []).map((t) => ({ ...t, value: t.actual }));
    }

    get targetKicker() {
        const rows = this.data?.targets || [];
        const actual = rows.reduce((a, t) => a + (Number(t.actual) || 0), 0);
        const target = rows.reduce((a, t) => a + (Number(t.target) || 0), 0);
        if (!this.data?.hasTargets) {
            return `${inrShort(actual)} booked in ${this.data?.targetLabel || 'this FY'} · no targets set yet`;
        }
        return `${inrShort(actual)} booked of ${inrShort(target)} target in ${this.data.targetLabel} · ${percent(actual, target)}% achieved`;
    }

    get targetEmptyText() {
        return 'No bookings or targets this financial year. Add monthly targets in the Sales Targets tab.';
    }

    get pipelineKicker() {
        const rows = this.data?.pipeline || [];
        const n = rows.reduce((a, r) => a + r.count, 0);
        const value = rows.reduce((a, r) => a + (Number(r.value) || 0), 0);
        return n ? `${plural(n, 'open deal')} worth ${inrShort(value)}, as of today` : 'Open residential deals, as of today';
    }

    get lostGroups() {
        return [
            { title: 'Opportunities lost', rows: this.data?.lostReasons || [], noun: 'opportunity', emptyText: 'No opportunity was lost in this period.' },
            { title: 'Leads dropped', rows: this.data?.dropReasons || [], noun: 'lead', emptyText: 'No lead was dropped in this period.' }
        ];
    }

    get lostKicker() {
        const lost = (this.data?.lostReasons || []).reduce((a, r) => a + r.count, 0);
        const dropped = (this.data?.dropReasons || []).reduce((a, r) => a + r.count, 0);
        return `${plural(lost, 'opportunity', 'opportunities')} lost and ${plural(dropped, 'lead')} dropped in ${this.data?.periodLabel}`;
    }

    get lostEmptyText() {
        return `Nothing was lost or dropped in ${this.data?.periodLabel}.`;
    }

    get cancelMonths() {
        return (this.data?.cancellations || []).map((c) => ({ ...c, value: c.count }));
    }

    get cancelKicker() {
        const d = this.data;
        if (!d) {
            return '';
        }
        const total = (d.cancellations || []).reduce((a, c) => a + c.count, 0);
        const booked = Number(d.tiles?.[1]?.value) || 0;
        const rate = d.cancelledInPeriod ? ` · ${percent(d.cancelledInPeriod, booked + d.cancelledInPeriod)}% of bookings` : '';
        return `${plural(d.cancelledInPeriod, 'cancellation')} worth ${inrShort(d.cancelledValueInPeriod)} in ${d.periodLabel}${rate} · ${total} in 12 months`;
    }

    get bodyClass() {
        return this.loading ? 'body body_loading' : 'body';
    }

    // ---------- tooltip ----------

    get tipClass() {
        return this.tip ? 'tip tip_on' : 'tip';
    }

    get tipStyle() {
        return `left:${this.tipLeft}px;top:${this.tipTop}px`;
    }

    handleTip(event) {
        const detail = event.detail;
        if (!detail) {
            this.tip = undefined;
            return;
        }
        const wrap = this.template.querySelector('.dash');
        if (!wrap) {
            return;
        }
        const box = wrap.getBoundingClientRect();
        const centre = detail.rect.left + detail.rect.width / 2 - box.left;
        this.tipLeft = Math.min(Math.max(centre, TIP_EDGE), box.width - TIP_EDGE);
        this.tipTop = detail.rect.top - box.top;
        this.tip = {
            title: detail.title,
            lines: (detail.lines || []).map((l) => ({ ...l, swatchStyle: `background:${l.color}` }))
        };
    }
}