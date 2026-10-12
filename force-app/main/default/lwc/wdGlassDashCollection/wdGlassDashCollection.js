import { LightningElement, api } from 'lwc';
import { inrShort, percent, plural, showTip, hideTip } from 'c/wdGlassDashUtils';

const CIRCUMFERENCE = 2 * Math.PI * 50;
const AGE_COLORS = ['#e3a008', '#e07a1f', '#d4502a', '#b42d2a'];

/** Ring gauge of money collected against demands due, plus overdue amounts by age. */
export default class WdGlassDashCollection extends LightningElement {
    @api collection = {};

    get hasDemands() {
        return Number(this.collection?.due) > 0;
    }

    get collectedPct() {
        return percent(Number(this.collection.received) || 0, Number(this.collection.due) || 0);
    }

    get ringStyle() {
        const filled = (Math.min(100, this.collectedPct) / 100) * CIRCUMFERENCE;
        return `stroke-dasharray:${filled} ${CIRCUMFERENCE}`;
    }

    get due() {
        return inrShort(this.collection.due);
    }

    get overdue() {
        return inrShort(this.collection.overdue);
    }

    get gaugeLabel() {
        return `${this.collectedPct}% collected of ${this.due} due. ${this.overdue} overdue.`;
    }

    get buckets() {
        const rows = this.collection?.buckets || [];
        const max = Math.max(1, ...rows.map((b) => Number(b.amount) || 0));
        return rows.map((b, index) => {
            const amount = Number(b.amount) || 0;
            return {
                label: b.label,
                index,
                value: amount ? inrShort(amount) : '—',
                fillClass: `bucket-fill bucket-fill_${index}`,
                style: `width:${amount ? Math.max(3, (amount / max) * 100) : 0}%`
            };
        });
    }

    get upcoming() {
        const c = this.collection || {};
        if (!c.upcomingCount) {
            return 'Nothing else falls due in the next 30 days';
        }
        return `${inrShort(c.upcoming)} falls due in the next 30 days across ${plural(c.upcomingCount, 'demand')}`;
    }

    handleEnter(event) {
        const b = this.collection.buckets[Number(event.currentTarget.dataset.index)];
        showTip(this, event.currentTarget, `Overdue ${b.label.replace(' d', ' days')}`, [
            { label: plural(b.count, 'demand'), value: inrShort(b.amount), color: AGE_COLORS[Number(event.currentTarget.dataset.index)] }
        ]);
    }

    handleLeave() {
        hideTip(this);
    }
}