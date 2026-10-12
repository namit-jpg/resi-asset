import { formatDate } from 'c/wdGlassFormat';

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const WEEKDAYS_LONG = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const oneDecimal = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 1 });
const grouping = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });

/** Compact rupee label for axes and captions: ₹2.9 Cr, ₹56 L, ₹9,800. */
export function inrShort(amount) {
    const n = Number(amount) || 0;
    if (Math.abs(n) >= 1e7) {
        return `₹${oneDecimal.format(n / 1e7)} Cr`;
    }
    if (Math.abs(n) >= 1e5) {
        return `₹${oneDecimal.format(n / 1e5)} L`;
    }
    return `₹${grouping.format(n)}`;
}

export function count(n) {
    return grouping.format(Number(n) || 0);
}

export function plural(n, one, many) {
    return `${count(n)} ${n === 1 ? one : many || `${one}s`}`;
}

export function percent(part, whole) {
    return whole ? Math.round((100 * part) / whole) : 0;
}

/** Rounds an axis maximum up to 1, 2, 2.5 or 5 times a power of ten so gridlines land on clean values. */
export function niceMax(max) {
    if (!max || max <= 0) {
        return 1;
    }
    const pow = 10 ** Math.floor(Math.log10(max));
    const step = [1, 2, 2.5, 5, 10].find((s) => s * pow >= max);
    return step * pow;
}

/** Parses an Apex Date (yyyy-mm-dd) as a local date. */
export function localDate(value) {
    const [y, m, d] = String(value).split('-').map(Number);
    return new Date(y, m - 1, d);
}

export function weekday(date, long) {
    return (long ? WEEKDAYS_LONG : WEEKDAYS)[date.getDay()];
}

export function longDate(value) {
    const date = value instanceof Date ? value : localDate(value);
    return `${weekday(date)}, ${formatDate(date)}`;
}

/**
 * Fires the dashboard tooltip event from a chart component.
 * The dashboard owns a single tooltip and positions it over the hovered mark.
 */
export function showTip(component, target, title, lines) {
    const rect = target.getBoundingClientRect();
    component.dispatchEvent(
        new CustomEvent('tip', {
            detail: { rect: { left: rect.left, top: rect.top, width: rect.width }, title, lines }
        })
    );
}

export function hideTip(component) {
    component.dispatchEvent(new CustomEvent('tip', { detail: null }));
}