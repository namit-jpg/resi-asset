import { LightningElement, api } from 'lwc';
import { percent, plural, showTip, hideTip } from 'c/wdGlassDashUtils';

const SEGMENTS = [
    { key: 'available', label: 'Available', color: '#16a34a' },
    { key: 'held', label: 'On hold (blocked, reserved, management hold)', color: '#eb6834' },
    { key: 'booked', label: 'Booked or sold', color: 'rgba(20,48,90,0.2)' }
];

/** 100% stacked bar per configuration: what share of each unit type is still open to sell. */
export default class WdGlassDashInventory extends LightningElement {
    @api inventory = [];

    get hasRows() {
        return (this.inventory || []).length > 0;
    }

    get availableTotal() {
        return (this.inventory || []).reduce((a, r) => a + r.available, 0);
    }

    get configCount() {
        return (this.inventory || []).length;
    }

    get rows() {
        return (this.inventory || []).map((r, index) => ({
            label: r.label,
            index,
            available: r.available,
            total: r.total,
            segments: SEGMENTS.filter((s) => r[s.key] > 0).map((s) => ({
                key: s.key,
                segClass: `hit seg seg_${s.key}`,
                style: `flex-grow:${r[s.key]}`
            }))
        }));
    }

    handleEnter(event) {
        const { row, key } = event.currentTarget.dataset;
        const r = this.inventory[Number(row)];
        const seg = SEGMENTS.find((s) => s.key === key);
        showTip(this, event.currentTarget, r.label, [
            { label: seg.label, value: `${plural(r[key], 'unit')} · ${percent(r[key], r.total)}%`, color: seg.color }
        ]);
    }

    handleLeave() {
        hideTip(this);
    }
}