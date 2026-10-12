import { LightningElement, api } from 'lwc';
import { inrShort, count, percent, plural, showTip, hideTip } from 'c/wdGlassDashUtils';

/**
 * Horizontal bars, one hue, longest first or in a fixed order (pipeline stages).
 * Pass `rows` for one list, or `groups` ([{ title, rows, noun, emptyText }]) for several under one heading.
 * Rows: [{ label, count, value }]. Bars run on count; value, when present, is shown beside it.
 */
export default class WdGlassDashBars extends LightningElement {
    @api heading;
    @api kicker;
    @api rows;
    @api groups;
    @api noun = 'record';
    @api showValue = false;
    /** booked | held | neutral */
    @api tone = 'booked';
    @api emptyText = 'Nothing to show yet.';

    get barClass() {
        return `bar bar_${this.tone}`;
    }

    get source() {
        if (this.groups && this.groups.length) {
            return this.groups;
        }
        return [{ title: null, rows: this.rows || [], noun: this.noun }];
    }

    get sections() {
        return this.source.map((g, gi) => {
            const rows = g.rows || [];
            const max = Math.max(1, ...rows.map((r) => Number(r.count) || 0));
            const total = rows.reduce((a, r) => a + (Number(r.count) || 0), 0);
            return {
                key: `g${gi}`,
                index: gi,
                title: g.title,
                emptyText: g.emptyText || 'None in this period.',
                hasRows: rows.length > 0,
                rows: rows.map((r, index) => ({
                    key: `${gi}-${r.label}`,
                    index,
                    label: r.label,
                    primary: count(r.count),
                    secondary: this.showValue ? inrShort(r.value) : `${percent(Number(r.count) || 0, total)}%`,
                    style: `width:${Math.max(2, ((Number(r.count) || 0) / max) * 100)}%`
                }))
            };
        });
    }

    get hasRows() {
        return this.source.some((g) => (g.rows || []).length > 0);
    }

    handleEnter(event) {
        const g = this.source[Number(event.currentTarget.dataset.group)];
        const r = g.rows[Number(event.currentTarget.dataset.index)];
        const total = g.rows.reduce((a, x) => a + (Number(x.count) || 0), 0);
        const lines = [{ label: plural(r.count, g.noun || this.noun), value: `${percent(r.count, total)}% of total` }];
        if (Number(r.value)) {
            lines.push({ label: 'Value', value: inrShort(r.value) });
        }
        showTip(this, event.currentTarget, r.label, lines);
    }

    handleLeave() {
        hideTip(this);
    }
}