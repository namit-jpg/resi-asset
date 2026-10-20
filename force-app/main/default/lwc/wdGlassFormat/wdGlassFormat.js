const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAY_MS = 24 * 60 * 60 * 1000;

const POSITIVE = ['available', 'qualified', 'converted', 'allotment', 'transferred', 'approved', 'closed won', 'allocated', 'registered'];
const NEGATIVE = ['dropped', 'lost', 'unqualified', 'rejected', 'cancel'];
const WARNING = ['pending', 'draft', 'submitted', 'site visit', 'blocked', 'hold'];

const inrGrouping = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });
const oneDecimal = new Intl.NumberFormat('en-IN', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const twoDecimals = new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function isNumber(value) {
    return typeof value === 'number' && !Number.isNaN(value);
}

/** Splits a rupee amount into a headline figure and its Indian unit, e.g. { value: '3.39', unit: 'Cr' }. */
export function inrParts(amount) {
    const n = Number(amount) || 0;
    if (Math.abs(n) >= 1e7) {
        return { value: `₹${twoDecimals.format(n / 1e7)}`, unit: 'Cr' };
    }
    if (Math.abs(n) >= 1e5) {
        return { value: `₹${twoDecimals.format(n / 1e5)}`, unit: 'L' };
    }
    return { value: `₹${inrGrouping.format(n)}`, unit: '' };
}

export function areaParts(sqft) {
    const n = Number(sqft) || 0;
    if (n >= 1000) {
        return { value: oneDecimal.format(n / 1000), unit: 'k SF' };
    }
    return { value: inrGrouping.format(n), unit: 'SF' };
}

export function formatInr(amount) {
    if (!isNumber(amount)) {
        return amount || '—';
    }
    return `₹${inrGrouping.format(amount)}`;
}

export function formatArea(sqft) {
    return isNumber(sqft) ? `${inrGrouping.format(sqft)} SF` : '—';
}

function toDate(value) {
    if (!value) {
        return null;
    }
    // Date-only values arrive as yyyy-mm-dd; parse as local to avoid a timezone day shift.
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
        const [y, m, d] = value.split('-').map(Number);
        return new Date(y, m - 1, d);
    }
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
}

/** dd MMM yyyy, per org standard. */
export function formatDate(value) {
    const date = toDate(value);
    if (!date) {
        return '—';
    }
    return `${String(date.getDate()).padStart(2, '0')} ${MONTHS[date.getMonth()]} ${date.getFullYear()}`;
}

export function formatRelative(value) {
    const date = toDate(value);
    if (!date) {
        return '—';
    }
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const day = new Date(date);
    day.setHours(0, 0, 0, 0);
    const days = Math.round((today - day) / DAY_MS);
    if (days <= 0) {
        return 'Today';
    }
    if (days === 1) {
        return 'Yesterday';
    }
    if (days < 60) {
        return `${days} days ago`;
    }
    return formatDate(value);
}

export function formatTime(date) {
    return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

export function statusTone(status) {
    const s = (status || '').toLowerCase();
    if (NEGATIVE.some((k) => s.includes(k))) {
        return 'negative';
    }
    if (WARNING.some((k) => s.includes(k))) {
        return 'warning';
    }
    if (POSITIVE.some((k) => s.includes(k))) {
        return 'positive';
    }
    return 'neutral';
}

/** Turns an Apex Kpi into display-ready parts for wdGlassKpis. */
export function toKpiCard(kpi, index) {
    let parts;
    switch (kpi.format) {
        case 'inr':
            parts = inrParts(kpi.amount);
            break;
        case 'area':
            parts = areaParts(kpi.amount);
            break;
        case 'count':
            parts = { value: inrGrouping.format(kpi.amount || 0), unit: '' };
            break;
        default:
            parts = { value: kpi.text || '—', unit: '' };
    }
    return {
        key: `${index}-${kpi.label}`,
        label: kpi.label,
        caption: kpi.caption,
        live: kpi.live,
        value: parts.value,
        unit: parts.unit,
        valueClass: kpi.format === 'text' ? 'kpi-value kpi-value_text' : 'kpi-value'
    };
}

export function formatCell(type, value) {
    switch (type) {
        case 'inr':
            return formatInr(value);
        case 'area':
            return formatArea(value);
        case 'number':
            return isNumber(value) ? inrGrouping.format(value) : '—';
        case 'date':
            return formatDate(value);
        case 'relative':
            return formatRelative(value);
        default:
            return value === null || value === undefined || value === '' ? '—' : String(value);
    }
}