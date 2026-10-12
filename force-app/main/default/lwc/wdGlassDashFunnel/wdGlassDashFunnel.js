import { LightningElement, api } from 'lwc';
import { count, percent, plural, showTip, hideTip } from 'c/wdGlassDashUtils';

const RAMP = ['#5dbd88', '#36a56a', '#1a8a4e', '#0e6c3a', '#08502a'];

/**
 * Cohort funnel: every enquiry created in the period, counted at the furthest stage it reached.
 * Each stage is a subset of the one above, so the step rates are true conversion rates.
 * Class names avoid `stage`: Lightning's global `.forceStyle.desktop .stage` rule absolutely positions it.
 */
export default class WdGlassDashFunnel extends LightningElement {
    @api funnel = [];
    @api periodLabel;

    get first() {
        return Number(this.funnel?.[0]?.count) || 0;
    }

    get hasLeads() {
        return this.first > 0;
    }

    get overall() {
        const last = this.funnel?.[this.funnel.length - 1];
        return percent(Number(last?.count) || 0, this.first);
    }

    get stages() {
        const first = this.first || 1;
        return (this.funnel || []).map((s, index) => {
            const prev = index ? Number(this.funnel[index - 1].count) || 0 : 0;
            const n = Number(s.count) || 0;
            return {
                label: s.label,
                index,
                count: count(n),
                step: index && prev ? String(percent(n, prev)) : null,
                barClass: `funnel-bar funnel-bar_${index}`,
                style: `width:${n ? Math.max(2.5, (n / first) * 100) : 0}%`
            };
        });
    }

    handleEnter(event) {
        const index = Number(event.currentTarget.dataset.index);
        const s = this.funnel[index];
        const n = Number(s.count) || 0;
        const lines = [{ label: plural(n, 'enquiry', 'enquiries'), value: `${percent(n, this.first)}% of all`, color: RAMP[index] }];
        if (index) {
            const prev = Number(this.funnel[index - 1].count) || 0;
            lines.push({ label: `From ${this.funnel[index - 1].label.toLowerCase()}`, value: `${percent(n, prev)}%` });
        }
        showTip(this, event.currentTarget, s.label, lines);
    }

    handleLeave() {
        hideTip(this);
    }
}