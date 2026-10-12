import { LightningElement, api } from 'lwc';
import { inrShort, count, niceMax, percent, plural, showTip, hideTip } from 'c/wdGlassDashUtils';

const LABEL_ROW = '1.7rem';

/**
 * One series of monthly columns on a single axis, optionally with a target marker per month
 * (Target vs Actual, cancellation trend). Months: [{ label, longLabel, value, target, units, current, future }].
 */
export default class WdGlassDashColumns extends LightningElement {
    @api heading;
    @api kicker;
    @api months = [];
    /** inr | count */
    @api format = 'inr';
    @api showTarget = false;
    @api valueLabel = 'Booked';
    /** booked | held */
    @api tone = 'booked';
    @api unitLabel = 'unit';
    @api emptyText = 'Nothing to show yet.';

    fmt(v) {
        return this.format === 'count' ? count(v) : inrShort(v);
    }

    get max() {
        const values = (this.months || []).flatMap((m) => [Number(m.value) || 0, this.showTarget ? Number(m.target) || 0 : 0]);
        const top = Math.max(0, ...values);
        // Counts get whole-number gridlines: four steps of at least 1.
        return this.format === 'count' ? Math.max(4, Math.ceil(top / 4) * 4) : niceMax(top);
    }

    get hasData() {
        return (this.months || []).some((m) => Number(m.value) || (this.showTarget && Number(m.target)));
    }

    get ticks() {
        return [0, 0.25, 0.5, 0.75, 1].map((f) => ({
            key: `t${f}`,
            label: f === 0 ? '0' : this.fmt(this.max * f),
            style: `bottom:calc(${LABEL_ROW} + (100% - ${LABEL_ROW}) * ${f})`
        }));
    }

    get swatchClass() {
        return `swatch swatch_${this.tone}`;
    }

    get groups() {
        const max = this.max;
        return (this.months || []).map((m, index) => {
            const v = Number(m.value) || 0;
            const t = Number(m.target) || 0;
            return {
                key: m.longLabel,
                index,
                label: m.label,
                groupClass: `hit group${m.current ? ' group_current' : ''}${m.future ? ' group_future' : ''}`,
                barClass: `bar bar_${this.tone}`,
                barStyle: v ? `height:max(2px, ${(v / max) * 100}%)` : 'height:0',
                hasTarget: this.showTarget && t > 0,
                targetStyle: `bottom:${(t / max) * 100}%`
            };
        });
    }

    get ariaLabel() {
        const total = (this.months || []).reduce((a, m) => a + (Number(m.value) || 0), 0);
        return `${this.heading}: ${this.fmt(total)} across ${(this.months || []).length} months.`;
    }

    handleEnter(event) {
        const m = this.months[Number(event.currentTarget.dataset.index)];
        const v = Number(m.value) || 0;
        const lines = [
            {
                label: m.units !== undefined && m.units !== null ? `${this.valueLabel} · ${plural(m.units, this.unitLabel)}` : this.valueLabel,
                value: this.fmt(v),
                color: this.tone === 'held' ? '#eb6834' : '#16a34a'
            }
        ];
        if (this.showTarget) {
            const t = Number(m.target) || 0;
            lines.push({ label: 'Target', value: t ? this.fmt(t) : 'Not set', color: '#14305a' });
            if (t) {
                lines.push({ label: 'Achieved', value: `${percent(v, t)}%` });
            }
        }
        showTip(this, event.currentTarget, m.longLabel, lines);
    }

    handleLeave() {
        hideTip(this);
    }
}