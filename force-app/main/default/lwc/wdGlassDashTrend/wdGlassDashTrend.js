import { LightningElement, api } from 'lwc';
import { inrShort, niceMax, plural, showTip, hideTip } from 'c/wdGlassDashUtils';

const LABEL_ROW = '1.7rem';

/** Twelve months of booked agreement value against money collected, on one rupee axis. */
export default class WdGlassDashTrend extends LightningElement {
    @api months = [];

    get max() {
        const values = (this.months || []).flatMap((m) => [Number(m.booked) || 0, Number(m.collected) || 0]);
        return niceMax(Math.max(0, ...values));
    }

    get ticks() {
        return [0, 0.25, 0.5, 0.75, 1].map((f) => ({
            key: `t${f}`,
            label: f === 0 ? '0' : inrShort(this.max * f),
            style: `bottom:calc(${LABEL_ROW} + (100% - ${LABEL_ROW}) * ${f})`
        }));
    }

    get groups() {
        const max = this.max;
        const height = (v) => {
            const n = Number(v) || 0;
            return n ? `height:max(2px, ${(n / max) * 100}%)` : 'height:0';
        };
        return (this.months || []).map((m, index) => ({
            key: m.longLabel,
            index,
            label: m.label,
            groupClass: m.current ? 'hit group group_current' : 'hit group',
            bookedStyle: height(m.booked),
            collectedStyle: height(m.collected)
        }));
    }

    get totals() {
        const sum = (k) => (this.months || []).reduce((a, m) => a + (Number(m[k]) || 0), 0);
        return { booked: inrShort(sum('booked')), collected: inrShort(sum('collected')) };
    }

    get ariaLabel() {
        return `Booked value and collections by month for the last 12 months. ${this.totals.booked} booked, ${this.totals.collected} collected.`;
    }

    handleEnter(event) {
        const m = this.months[Number(event.currentTarget.dataset.index)];
        showTip(this, event.currentTarget, m.longLabel, [
            { label: `Booked · ${plural(m.bookings, 'unit')}`, value: inrShort(m.booked), color: '#16a34a' },
            { label: `Collected · ${plural(m.receipts, 'receipt')}`, value: inrShort(m.collected), color: '#2f5f9e' }
        ]);
    }

    handleLeave() {
        hideTip(this);
    }
}