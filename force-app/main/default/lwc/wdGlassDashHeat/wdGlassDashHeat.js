import { LightningElement, api } from 'lwc';
import { localDate, longDate, weekday, showTip, hideTip } from 'c/wdGlassDashUtils';

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const LEVEL_COLORS = ['rgba(20,48,90,0.07)', '#bfe6cf', '#7fcca0', '#36a56a', '#0e6c3a'];

function level(visits) {
    return Math.min(4, visits);
}

/** Thirteen-week calendar of site visits (Monday-first), with this week's bookings ahead shown as outlines. */
export default class WdGlassDashHeat extends LightningElement {
    @api days = [];

    get cells() {
        return (this.days || []).map((d, index) => {
            const classes = ['hit', 'cell', `cell_${level(d.visits)}`];
            if (d.future) {
                classes.push('cell_future');
            }
            if (d.today) {
                classes.push('cell_today');
            }
            return { key: d.day, index, cellClass: classes.join(' ') };
        });
    }

    get monthLabels() {
        const labels = [];
        let last = -1;
        for (let w = 0; w * 7 < (this.days || []).length; w++) {
            const month = localDate(this.days[w * 7].day).getMonth();
            labels.push({ key: `w${w}`, label: month !== last ? MONTHS[month] : '' });
            last = month;
        }
        return labels;
    }

    get past() {
        return (this.days || []).filter((d) => !d.future);
    }

    get busiestDay() {
        const totals = [0, 0, 0, 0, 0, 0, 0];
        this.past.forEach((d) => {
            totals[localDate(d.day).getDay()] += d.visits;
        });
        const max = Math.max(...totals);
        if (!max) {
            return null;
        }
        return weekday(new Date(2026, 0, 4 + totals.indexOf(max)), true);
    }

    get kicker() {
        const busiest = this.busiestDay;
        return busiest ? `${busiest}s draw the most visits` : 'No site visits in the last 13 weeks';
    }

    get stats() {
        const past = this.past;
        const visits = past.reduce((a, d) => a + d.visits, 0);
        const completed = past.reduce((a, d) => a + d.completed, 0);
        const ahead = (this.days || []).filter((d) => d.future).reduce((a, d) => a + d.visits, 0);
        const activeDays = past.filter((d) => d.visits).length;
        return [
            { label: 'visits in 13 weeks', value: visits },
            { label: 'completed', value: completed },
            { label: 'days with a visit', value: activeDays },
            { label: 'still ahead this week', value: ahead }
        ];
    }

    get ariaLabel() {
        const s = this.stats;
        return `Site visits per day for the last 13 weeks: ${s[0].value} visits, ${s[1].value} completed. ${this.kicker}.`;
    }

    handleEnter(event) {
        const d = this.days[Number(event.currentTarget.dataset.index)];
        const lines = [{ label: d.future ? 'Scheduled' : 'Visits', value: String(d.visits), color: LEVEL_COLORS[level(d.visits)] }];
        if (!d.future && d.visits) {
            lines.push({ label: 'Completed', value: String(d.completed) });
        }
        showTip(this, event.currentTarget, `${d.today ? 'Today · ' : ''}${longDate(d.day)}`, lines);
    }

    handleLeave() {
        hideTip(this);
    }
}