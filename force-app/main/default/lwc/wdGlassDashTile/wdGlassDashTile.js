import { LightningElement, api } from 'lwc';
import { inrParts } from 'c/wdGlassFormat';
import { count, inrShort, percent, showTip, hideTip } from 'c/wdGlassDashUtils';

const UP = 'M5 1 9 7H1Z';
const DOWN = 'M5 9 1 3H9Z';

export default class WdGlassDashTile extends LightningElement {
    @api tile = {};
    @api months = [];
    @api previousLabel = 'last period';

    get isInr() {
        return this.tile.format === 'inr';
    }

    get value() {
        return this.isInr ? inrParts(this.tile.value).value : count(this.tile.value);
    }

    get unit() {
        return this.isInr ? inrParts(this.tile.value).unit : '';
    }

    /** Percentage change vs the same point last period, or 'new' / 'flat' when there is no base. */
    get change() {
        const { value = 0, previous = 0 } = this.tile;
        if (!previous) {
            return value ? 'new' : 'flat';
        }
        return percent(value - previous, previous);
    }

    get deltaText() {
        const c = this.change;
        if (c === 'new') {
            return `New vs ${this.previousLabel}`;
        }
        if (c === 'flat' || c === 0) {
            return `Level with ${this.previousLabel}`;
        }
        return `${Math.abs(c)}% vs ${this.previousLabel}`;
    }

    get deltaTitle() {
        const prev = this.isInr ? inrShort(this.tile.previous) : count(this.tile.previous);
        return `Same point in ${this.previousLabel}: ${prev}`;
    }

    get deltaArrow() {
        const c = this.change;
        if (c === 'new' || c > 0) {
            return UP;
        }
        return c < 0 ? DOWN : null;
    }

    get deltaClass() {
        const c = this.change;
        let tone = 'delta_flat';
        if (c === 'new' || c > 0) {
            tone = 'delta_up';
        } else if (c < 0) {
            tone = 'delta_down';
        }
        return `delta ${tone}`;
    }

    get spark() {
        const values = (this.tile.spark || []).map(Number);
        const n = values.length;
        const max = Math.max(...values, 0) || 1;
        const x = (i) => (n > 1 ? (i / (n - 1)) * 120 : 60);
        const y = (v) => 36 - (v / max) * 32;
        const coords = values.map((v, i) => [x(i), y(v)]);
        const line = coords.map(([cx, cy], i) => `${i ? 'L' : 'M'}${cx.toFixed(1)} ${cy.toFixed(1)}`).join(' ');
        const last = coords[n - 1] || [120, 36];
        return {
            line,
            area: n ? `${line} L120 40 L0 40 Z` : '',
            dotStyle: `left:${(last[0] / 120) * 100}%;top:${(last[1] / 40) * 100}%`,
            points: values.map((v, i) => ({ key: `p${i}`, index: i }))
        };
    }

    get sparkLabel() {
        const total = (this.tile.spark || []).reduce((a, b) => a + Number(b), 0);
        return `${this.tile.label}, last 12 months: ${this.isInr ? inrShort(total) : count(total)} in total`;
    }

    handleEnter(event) {
        const i = Number(event.currentTarget.dataset.index);
        const v = (this.tile.spark || [])[i];
        const month = (this.months || [])[i];
        showTip(this, event.currentTarget, month ? month.longLabel : '', [
            { label: this.tile.label, value: this.isInr ? inrShort(v) : count(v), color: '#16a34a' }
        ]);
    }

    handleLeave() {
        hideTip(this);
    }
}