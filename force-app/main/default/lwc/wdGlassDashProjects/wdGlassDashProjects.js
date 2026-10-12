import { LightningElement, api } from 'lwc';
import { inrShort, count, percent } from 'c/wdGlassDashUtils';

/** One row per project: enquiries to bookings in the period, money booked and collected, stock left. */
export default class WdGlassDashProjects extends LightningElement {
    @api projects = [];
    @api periodLabel;

    get hasRows() {
        return (this.projects || []).length > 0;
    }

    get kicker() {
        const rows = this.projects || [];
        const booked = rows.reduce((a, p) => a + (Number(p.booked) || 0), 0);
        return `${inrShort(booked)} booked across ${rows.length} ${rows.length === 1 ? 'project' : 'projects'} in ${this.periodLabel}`;
    }

    get rows() {
        const max = Math.max(1, ...(this.projects || []).map((p) => Number(p.booked) || 0));
        return (this.projects || []).map((p) => ({
            key: p.id,
            name: p.name,
            city: p.city || '',
            leads: count(p.leads),
            visits: count(p.visits),
            bookings: count(p.bookings),
            conversion: p.leads ? `${percent(p.bookings, p.leads)}%` : '—',
            booked: inrShort(p.booked),
            collected: inrShort(p.collected),
            stock: p.units ? `${count(p.available)} of ${count(p.units)}` : '—',
            style: `width:${Math.max(p.booked ? 3 : 0, ((Number(p.booked) || 0) / max) * 100)}%`
        }));
    }
}