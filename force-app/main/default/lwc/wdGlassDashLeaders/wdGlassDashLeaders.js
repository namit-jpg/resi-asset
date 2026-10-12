import { LightningElement, api } from 'lwc';
import { inrShort, percent, plural, showTip, hideTip } from 'c/wdGlassDashUtils';

/**
 * Salespeople ranked by booked value in the period, with the work behind it (leads, site visits,
 * conversion, open deals) and target achievement. The viewer's own row is marked.
 */
export default class WdGlassDashLeaders extends LightningElement {
    @api leaders = [];
    @api periodLabel;

    get hasRows() {
        return (this.leaders || []).length > 0;
    }

    get total() {
        return (this.leaders || []).reduce((a, l) => a + (Number(l.value) || 0), 0);
    }

    get rows() {
        const max = Math.max(1, ...(this.leaders || []).map((l) => Number(l.value) || 0));
        return (this.leaders || []).map((l, index) => ({
            key: `${index}-${l.name}`,
            index,
            rank: index + 1,
            name: l.name,
            me: l.me,
            initials: (l.name || '?')
                .split(/\s+/)
                .slice(0, 2)
                .map((p) => p.charAt(0))
                .join('')
                .toUpperCase(),
            value: inrShort(l.value),
            bookings: l.target ? `${plural(l.bookings, 'booking')} · ${percent(Number(l.value) || 0, l.target)}% of target` : plural(l.bookings, 'booking'),
            stats: [
                plural(l.leads || 0, 'lead'),
                plural(l.visits || 0, 'visit'),
                l.leads ? `${percent(l.bookings, l.leads)}% conversion` : null,
                plural(l.openDeals || 0, 'open deal')
            ]
                .filter(Boolean)
                .join(' · '),
            rowClass: `hit row${l.me ? ' row_me' : ''}${index === 0 ? ' row_top' : ''}`,
            style: `width:${Math.max(2, ((Number(l.value) || 0) / max) * 100)}%`
        }));
    }

    handleEnter(event) {
        const l = this.leaders[Number(event.currentTarget.dataset.index)];
        showTip(this, event.currentTarget, l.name, [
            { label: plural(l.bookings, 'booking'), value: inrShort(l.value), color: '#16a34a' },
            { label: 'Share of team', value: `${percent(Number(l.value) || 0, this.total)}%` },
            { label: 'Leads assigned', value: String(l.leads || 0) },
            { label: 'Site visits done', value: String(l.visits || 0) },
            { label: 'Lead to booking', value: l.leads ? `${percent(l.bookings, l.leads)}%` : '—' },
            { label: 'Target', value: l.target ? `${inrShort(l.target)} · ${percent(Number(l.value) || 0, l.target)}%` : 'Not set' }
        ]);
    }

    handleLeave() {
        hideTip(this);
    }
}