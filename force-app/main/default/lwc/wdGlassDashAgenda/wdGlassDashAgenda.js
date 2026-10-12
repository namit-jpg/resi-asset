import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { formatTime } from 'c/wdGlassFormat';
import { localDate, weekday } from 'c/wdGlassDashUtils';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAY_MS = 24 * 60 * 60 * 1000;

function startOfDay(date) {
    const d = new Date(date);
    d.setHours(0, 0, 0, 0);
    return d;
}

/** Upcoming site visits and open leads nobody has touched for a week; each row opens the record. */
export default class WdGlassDashAgenda extends NavigationMixin(LightningElement) {
    @api visits = [];
    @api coldLeads = [];

    get hasVisits() {
        return (this.visits || []).length > 0;
    }

    get hasCold() {
        return (this.coldLeads || []).length > 0;
    }

    get visitsView() {
        const today = startOfDay(new Date());
        return (this.visits || []).map((v) => {
            const at = new Date(v.at);
            const days = Math.round((startOfDay(at) - today) / DAY_MS);
            let chip = `${weekday(at)} ${formatTime(at)}`;
            if (days === 0) {
                chip = `Today ${formatTime(at)}`;
            } else if (days === 1) {
                chip = `Tomorrow ${formatTime(at)}`;
            }
            const hot = (v.status || '').toLowerCase() === 'high';
            return {
                id: v.id,
                day: String(at.getDate()).padStart(2, '0'),
                month: MONTHS[at.getMonth()],
                title: v.title,
                meta: [v.subtitle, hot ? 'High interest' : null].filter(Boolean).join(' · ') || 'Site visit',
                chip,
                chipClass: days <= 1 ? 'chip chip_soon' : 'chip'
            };
        });
    }

    get coldView() {
        const today = startOfDay(new Date());
        return (this.coldLeads || []).map((l) => {
            const quiet = l.lastTouched ? Math.round((today - localDate(l.lastTouched)) / DAY_MS) : null;
            return {
                id: l.id,
                initials: (l.title || '?')
                    .split(/\s+/)
                    .slice(0, 2)
                    .map((p) => p.charAt(0))
                    .join('')
                    .toUpperCase(),
                title: l.title,
                meta: [l.status, l.subtitle].filter(Boolean).join(' · '),
                chip: quiet === null ? 'Never touched' : `${quiet} days quiet`,
                chipClass: quiet === null || quiet > 30 ? 'chip chip_cold' : 'chip chip_warm'
            };
        });
    }

    handleOpen(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }
}