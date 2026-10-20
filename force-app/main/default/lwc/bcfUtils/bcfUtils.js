// Shared rules for the customer booking form: steps, choice sets, document rules, validation, formatting.

export const STEPS = [
    { id: 'details', label: 'Your details' },
    { id: 'applicants', label: 'Co-applicants' },
    { id: 'kyc', label: 'KYC' },
    { id: 'payment', label: 'Token advance' },
    { id: 'sign', label: 'Sign' }
];

export const MAX_CO_APPLICANTS = 3;
export const MAX_FILE_BYTES = 3 * 1024 * 1024;

export const SALUTATIONS = ['Mr', 'Mrs', 'Ms', 'Dr'];
export const GENDERS = ['Male', 'Female', 'Other', 'Prefer not to say'];
export const MARITAL = ['Single', 'Married', 'Divorced', 'Widowed'];
export const OCCUPATIONS = ['Salaried', 'Self-employed', 'Business owner', 'Professional', 'Retired', 'Homemaker', 'Student'];
export const COUNTRIES = ['India', 'Singapore', 'United Arab Emirates', 'United States', 'United Kingdom', 'Canada', 'Australia'];
export const RESIDENTIAL = ['Resident Indian', 'Non-resident Indian (NRI)', 'OCI cardholder', 'PIO', 'Foreign national'];
export const NON_RESIDENT = new Set(['Non-resident Indian (NRI)', 'OCI cardholder', 'PIO', 'Foreign national']);
export const CO_RELATIONSHIPS = ['Spouse', 'Parent', 'Child', 'Sibling', 'Other'];
export const NOMINEE_RELATIONSHIPS = ['Spouse', 'Parent', 'Child', 'Sibling', 'Grandchild', 'Other'];
export const STATES = [
    'Telangana', 'Andhra Pradesh', 'Karnataka', 'Maharashtra', 'Tamil Nadu', 'Delhi', 'Haryana',
    'Uttar Pradesh', 'Kerala', 'West Bengal', 'Gujarat', 'Rajasthan', 'Punjab'
];

export const PAY_METHODS = [
    { id: 'UPI', label: 'UPI' },
    { id: 'NETBANKING', label: 'Net banking' },
    { id: 'CARD', label: 'Card' },
    { id: 'WALLET', label: 'Wallet' }
];

export const DECLARATIONS = [
    { id: 'accurate', label: 'The information I have provided is accurate.' },
    { id: 'bookingTerms', label: 'I accept the booking terms and conditions.' },
    { id: 'paymentTerms', label: 'I accept the payment schedule and the charges payable.' },
    { id: 'cancellation', label: 'I have read and accept the cancellation and refund policy.' },
    { id: 'privacy', label: 'I consent to my personal data being processed for this booking and for KYC verification.' },
    { id: 'electronic', label: 'I agree to receive documents and updates electronically.' }
];

const STD = 'PDF, JPG or PNG, up to 3 MB.';
export const DOC_RULES = [
    { id: 'PAN', label: 'PAN card', required: true, sub: `Required. ${STD}`, captures: ['number'] },
    { id: 'ID_PROOF', label: 'Identity proof (Aadhaar)', required: true, sub: `Required. ${STD}`, captures: ['number'] },
    { id: 'ADDRESS_PROOF', label: 'Address proof', required: false, sub: `Optional for this project. ${STD}` },
    { id: 'PHOTOGRAPH', label: 'Photograph', required: false, sub: 'Optional. JPG or PNG, up to 3 MB.' },
    { id: 'SIGNATURE', label: 'Specimen signature', required: false, sub: 'Optional at booking; required before registration. JPG or PNG, up to 3 MB.' },
    { id: 'PASSPORT', label: 'Passport / OCI card', required: true, nonResident: true, sub: `Required for non-resident buyers. ${STD}`, captures: ['number', 'authority', 'issueDate', 'expiryDate'] },
    { id: 'VISA', label: 'Visa / residency permit', required: true, nonResident: true, sub: `Required for non-resident buyers. ${STD}` },
    { id: 'NRI_POA', label: 'Power of Attorney / affidavit', required: false, nonResident: true, sub: 'Required when the booking is executed through a POA holder. PDF, up to 3 MB.' },
    { id: 'CANCELLED_CHEQUE', label: 'Cancelled cheque / bank proof', required: false, sub: `Optional. Used for refunds and auto-debit mandates. ${STD}` }
];

export const CAPTURE_LABELS = {
    number: 'Document number',
    authority: 'Issuing authority',
    issueDate: 'Issue date',
    expiryDate: 'Expiry date'
};

export function docsFor(applicant) {
    const nonResident = NON_RESIDENT.has(applicant?.residentialStatus);
    return DOC_RULES.filter((r) => !r.nonResident || nonResident);
}

// ---------- paths ----------

export function getPath(obj, path) {
    return path.split('.').reduce((node, key) => (node === undefined || node === null ? undefined : node[key]), obj);
}

/** Returns a copy of obj with path set to value. */
export function setPath(obj, path, value) {
    const root = clone(obj);
    const keys = path.split('.');
    let node = root;
    keys.slice(0, -1).forEach((k, i) => {
        if (node[k] === undefined || node[k] === null) {
            node[k] = /^\d+$/.test(keys[i + 1]) ? [] : {};
        }
        node = node[k];
    });
    node[keys[keys.length - 1]] = value;
    return root;
}

export function clone(value) {
    return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

// ---------- validation ----------

const MOBILE = /^[6-9]\d{9}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const PAN = /^[A-Z]{5}[0-9]{4}[A-Z]$/;
const PIN = /^[1-9]\d{5}$/;

export const DETAIL_REQUIRED = {
    fullLegalName: 'Full legal name',
    dob: 'Date of birth',
    mobile: 'Mobile',
    email: 'Email',
    pan: 'PAN',
    occupation: 'Occupation / employment type',
    nationality: 'Nationality',
    residentialStatus: 'Residential status'
};
export const CO_REQUIRED = {
    fullLegalName: 'Full legal name',
    relationship: 'Relationship to primary',
    dob: 'Date of birth',
    pan: 'PAN',
    mobile: 'Mobile'
};
export const ADDRESS_REQUIRED = {
    line1: 'Address line 1',
    locality: 'Locality',
    city: 'City',
    state: 'State',
    pincode: 'PIN code',
    country: 'Country'
};

function age(dob) {
    const d = new Date(`${dob}T00:00:00`);
    if (Number.isNaN(d.getTime())) {
        return null;
    }
    const now = new Date();
    let years = now.getFullYear() - d.getFullYear();
    const m = now.getMonth() - d.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < d.getDate())) {
        years--;
    }
    return years;
}

/** Message for one field, or null. `kind` picks the format rule. */
export function checkValue(kind, value, label, required) {
    const v = typeof value === 'string' ? value.trim() : value;
    if (v === undefined || v === null || v === '') {
        return required ? `${label} is required` : null;
    }
    switch (kind) {
        case 'mobile':
            return MOBILE.test(v) ? null : 'Enter a valid 10-digit mobile number';
        case 'email':
            return EMAIL.test(v) ? null : 'Enter a valid email address';
        case 'pan':
            return PAN.test(v) ? null : 'Enter a valid PAN, for example ABCPM1234K';
        case 'pincode':
            return PIN.test(v) ? null : 'Enter a valid 6-digit PIN code';
        case 'adultDob': {
            const a = age(v);
            if (a === null || a > 110 || a < 0) return 'Enter a valid date of birth';
            return a < 18 ? 'The applicant must be at least 18 years old' : null;
        }
        case 'pastDate': {
            const a = age(v);
            if (a === null) return 'Enter a valid date';
            return new Date(`${v}T00:00:00`) > new Date() ? 'The date cannot be in the future' : null;
        }
        case 'share': {
            const n = Number(v);
            return Number.isInteger(n) && n >= 1 && n <= 100 ? null : 'Enter a percentage between 1 and 100';
        }
        default:
            return null;
    }
}

export const KINDS = {
    mobile: 'mobile',
    email: 'email',
    pan: 'pan',
    pincode: 'pincode',
    dob: 'adultDob'
};

function applicantName(ap, i) {
    return ap.fullLegalName || (i === 0 ? 'the primary applicant' : `Co-applicant ${i}`);
}

function checkFields(errors, prefix, obj, required, optionalKinds = {}) {
    Object.entries(required).forEach(([key, label]) => {
        const msg = checkValue(KINDS[key], obj?.[key], label, true);
        if (msg) errors[`${prefix}.${key}`] = msg;
    });
    Object.entries(optionalKinds).forEach(([key, kind]) => {
        const msg = checkValue(kind, obj?.[key], key, false);
        if (msg) errors[`${prefix}.${key}`] = msg;
    });
}

function checkPanUnique(errors, applicants) {
    const seen = new Map();
    applicants.forEach((ap, i) => {
        const pan = (ap.pan || '').toUpperCase();
        if (!pan) return;
        if (seen.has(pan)) {
            errors[`applicants.${i}.pan`] = `This PAN is already used by ${applicantName(applicants[seen.get(pan)], seen.get(pan))}`;
        } else {
            seen.set(pan, i);
        }
    });
}

/** Errors that block leaving `step`, as { path: message }. */
export function validateStep(step, data, payment) {
    const errors = {};
    const applicants = data.applicants || [];
    if (step === 'details') {
        checkFields(errors, 'applicants.0', applicants[0], DETAIL_REQUIRED);
        checkPanUnique(errors, applicants);
    } else if (step === 'applicants') {
        applicants.forEach((ap, i) => {
            if (i > 0) checkFields(errors, `applicants.${i}`, ap, CO_REQUIRED);
        });
        checkPanUnique(errors, applicants);
        const n = data.nominee || {};
        if (n.provided) {
            checkFields(errors, 'nominee', n, { fullName: 'Nominee full name', relationship: 'Relationship to applicant' });
            const dobMsg = checkValue('pastDate', n.dob, 'Nominee date of birth', true);
            if (dobMsg) errors['nominee.dob'] = dobMsg;
            const shareMsg = checkValue('share', n.sharePct, 'Nominee share (%)', true);
            if (shareMsg) errors['nominee.sharePct'] = shareMsg;
            const mobMsg = checkValue('mobile', n.mobile, 'Nominee mobile', false);
            if (mobMsg) errors['nominee.mobile'] = mobMsg;
            if (n.isMinor) {
                checkFields(errors, 'nominee', n, { guardianName: 'Guardian name', guardianRelationship: 'Guardian relationship' });
            }
        }
    } else if (step === 'kyc') {
        applicants.forEach((ap, i) => {
            checkFields(errors, `applicants.${i}.address`, ap.address, ADDRESS_REQUIRED);
            if (!ap.sameAsPermanent) {
                checkFields(errors, `applicants.${i}.correspondence`, ap.correspondence, ADDRESS_REQUIRED);
            }
            docsFor(ap).forEach((rule) => {
                if (rule.required && !ap.documents?.[rule.id]?.contentVersionId) {
                    errors[`applicants.${i}.documents.${rule.id}`] = `${rule.label} must be uploaded before continuing`;
                }
            });
        });
    } else if (step === 'payment') {
        if (payment?.status !== 'Paid') {
            errors['payment.status'] = 'Pay the token advance to continue';
        }
    } else if (step === 'sign') {
        applicants.forEach((ap, i) => {
            if (!ap.signature?.signedAt) errors[`applicants.${i}.signature`] = `${applicantName(ap, i)} has not signed yet`;
        });
        DECLARATIONS.forEach((d) => {
            if (!data.declarations?.[d.id]) errors[`declarations.${d.id}`] = 'This must be accepted before continuing';
        });
    }
    return errors;
}

/** Errors from `all` that sit under any of the given path prefixes. */
export function errorsUnder(all, prefixes) {
    const out = {};
    Object.entries(all || {}).forEach(([path, msg]) => {
        if (prefixes.some((p) => path === p || path.startsWith(`${p}.`))) {
            out[path] = msg;
        }
    });
    return out;
}

// ---------- field descriptors for c-bcf-field ----------

export function options(values, selected) {
    return values.map((v) => ({ value: v, label: v, selected: v === selected }));
}

/** Builds a descriptor c-bcf-field renders. */
export function field(data, errors, path, label, config = {}) {
    const value = getPath(data, path);
    return {
        key: path,
        path,
        label,
        type: config.type || 'text',
        value: value === undefined || value === null ? '' : value,
        checked: value === true,
        required: !!config.required,
        options: config.choices ? options(config.choices, value) : null,
        placeholder: config.placeholder || '',
        maxlength: config.maxlength,
        uppercase: !!config.uppercase,
        kind: config.kind,
        wide: !!config.wide,
        hint: config.hint,
        error: errors?.[path] || null
    };
}

// ---------- formatting ----------

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const inr = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });

export function formatInr(amount) {
    const n = Number(amount);
    return amount === null || amount === undefined || Number.isNaN(n) ? '—' : `₹${inr.format(n)}`;
}

/** Summary rows for a paid EOI, which is deducted from the amount the customer still owes. */
export function eoiLines(c) {
    if (!(Number(c?.eoiPaid) > 0)) return [];
    return [
        { key: 'eoi', label: `Less EOI paid${c.eoiVouchers ? ` (${c.eoiVouchers})` : ''}`, value: `− ${formatInr(c.eoiPaid)}` },
        { key: 'balance', label: 'Balance payable', value: formatInr(c.balancePayable) }
    ];
}

function toDate(value) {
    if (!value) return null;
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) {
        const [y, m, d] = value.split('-').map(Number);
        return new Date(y, m - 1, d);
    }
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
}

/** dd MMM yyyy */
export function formatDate(value) {
    const d = toDate(value);
    return d ? `${String(d.getDate()).padStart(2, '0')} ${MONTHS[d.getMonth()]} ${d.getFullYear()}` : '—';
}

export function formatDateTime(value) {
    const d = toDate(value);
    if (!d) return '—';
    const h = d.getHours();
    const time = `${((h + 11) % 12) + 1}:${String(d.getMinutes()).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`;
    return `${formatDate(d)}, ${time}`;
}

export function formatSize(bytes) {
    if (!bytes && bytes !== 0) return '';
    return bytes >= 1024 * 1024 ? `${(bytes / (1024 * 1024)).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

export function initials(name) {
    return (name || '?')
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((p) => p[0].toUpperCase())
        .join('');
}

export function blankApplicant(key, role) {
    return {
        key,
        role,
        nationality: 'India',
        residentialStatus: 'Resident Indian',
        address: { country: 'India' },
        sameAsPermanent: true,
        correspondence: { country: 'India' },
        documents: {},
        identity: { stage: 'none' }
    };
}