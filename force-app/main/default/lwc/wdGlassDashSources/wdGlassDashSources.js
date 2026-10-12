import { LightningElement, api } from 'lwc';
import { inrShort, percent, showTip, hideTip } from 'c/wdGlassDashUtils';

const MAX_ROWS = 6;

/** Enquiries per lead source, with the converted share drawn inside each bar and bookings beside it. */
export default class WdGlassDashSources extends LightningElement {
    @api sources = [];
    @api periodLabel;

    get folded() {
        const rows = this.sources || [];
        if (rows.length <= MAX_ROWS) {
            return rows;
        }
        const tail = rows.slice(MAX_ROWS - 1);
        return [
            ...rows.slice(0, MAX_ROWS - 1),
            {
                label: 'Other',
                leads: tail.reduce((a, r) => a + r.leads, 0),
                converted: tail.reduce((a, r) => a + r.converted, 0),
                booked: tail.reduce((a, r) => a + (r.booked || 0), 0),
                bookedValue: tail.reduce((a, r) => a + (Number(r.bookedValue) || 0), 0)
            }
        ];
    }

    get hasRows() {
        return this.folded.length > 0;
    }

    get best() {
        // Best converter among sources with enough volume to mean something.
        return this.folded
            .filter((r) => r.leads >= 3 && r.label !== 'Not captured' && r.label !== 'Other')
            .sort((a, b) => b.converted / b.leads - a.converted / a.leads)[0];
    }

    get kicker() {
        const best = this.best;
        if (!best || !best.converted) {
            return `Enquiries received in ${this.periodLabel}`;
        }
        return `${best.label} converts best at ${percent(best.converted, best.leads)}%`;
    }

    get rows() {
        const max = Math.max(1, ...this.folded.map((r) => r.leads));
        const best = this.best;
        return this.folded.map((r, index) => ({
            label: r.label,
            index,
            leads: r.leads,
            rate: `${percent(r.converted, r.leads)}%`,
            rateClass: best && r.label === best.label && r.converted ? 'rate rate_best' : 'rate',
            booked: `${r.booked || 0} bkd`,
            leadsStyle: `width:${(r.leads / max) * 100}%`,
            convertedStyle: `width:${percent(r.converted, r.leads)}%`
        }));
    }

    handleEnter(event) {
        const r = this.folded[Number(event.currentTarget.dataset.index)];
        showTip(this, event.currentTarget, r.label, [
            { label: 'Enquiries', value: String(r.leads), color: '#a6dcbc' },
            { label: 'Converted', value: `${r.converted} · ${percent(r.converted, r.leads)}%`, color: '#0e6c3a' },
            { label: 'Booked', value: `${r.booked || 0} · ${percent(r.booked || 0, r.leads)}%` },
            { label: 'Booked value', value: inrShort(r.bookedValue) }
        ]);
    }

    handleLeave() {
        hideTip(this);
    }
}