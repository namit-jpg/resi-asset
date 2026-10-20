import { LightningElement, api } from 'lwc';
import { field, CO_RELATIONSHIPS, NOMINEE_RELATIONSHIPS, MAX_CO_APPLICANTS } from 'c/bcfUtils';

/** Step 2: co-applicants (joint buyers) and the optional nominee. */
export default class BcfApplicants extends LightningElement {
    @api data;
    @api errors;

    get coApplicants() {
        const d = this.data;
        const e = this.errors;
        return (d?.applicants || [])
            .map((ap, index) => ({ ap, index }))
            .filter(({ ap }) => ap.role !== 'PRIMARY')
            .map(({ ap, index }, n) => {
                const p = `applicants.${index}`;
                return {
                    key: ap.key,
                    title: `Co-applicant ${n + 1}`,
                    name: ap.fullLegalName || `co-applicant ${n + 1}`,
                    fields: [
                        field(d, e, `${p}.fullLegalName`, 'Full legal name (as on PAN)', { required: true, wide: true, maxlength: 120 }),
                        field(d, e, `${p}.relationship`, 'Relationship to primary', { type: 'select', choices: CO_RELATIONSHIPS, required: true }),
                        field(d, e, `${p}.dob`, 'Date of birth', { type: 'date', required: true, kind: 'adultDob' }),
                        field(d, e, `${p}.pan`, 'PAN', { required: true, kind: 'pan', uppercase: true, maxlength: 10, placeholder: 'ABCPM1234K' }),
                        field(d, e, `${p}.mobile`, 'Mobile', { type: 'tel', required: true, kind: 'mobile', maxlength: 10 }),
                        field(d, e, `${p}.email`, 'Email', { type: 'email', kind: 'email', maxlength: 80 })
                    ]
                };
            });
    }

    get noCoApplicants() {
        return this.coApplicants.length === 0;
    }

    get canAdd() {
        return this.coApplicants.length < MAX_CO_APPLICANTS;
    }

    get nominee() {
        return this.data?.nominee || {};
    }

    get nomineeBadge() {
        return this.nominee.provided ? { label: 'Added', className: 'badge badge_info' } : { label: 'Not added', className: 'badge' };
    }

    get nomineeToggle() {
        return field(this.data, this.errors, 'nominee.provided', 'I want to nominate someone', { type: 'checkbox' });
    }

    get nomineeFields() {
        const d = this.data;
        const e = this.errors;
        return [
            field(d, e, 'nominee.fullName', 'Nominee full name', { required: true, wide: true, maxlength: 120 }),
            field(d, e, 'nominee.relationship', 'Relationship to applicant', { type: 'select', choices: NOMINEE_RELATIONSHIPS, required: true }),
            field(d, e, 'nominee.dob', 'Nominee date of birth', { type: 'date', required: true, kind: 'pastDate' }),
            field(d, e, 'nominee.sharePct', 'Nominee share (%)', { required: true, kind: 'share', maxlength: 3 }),
            field(d, e, 'nominee.mobile', 'Nominee mobile', { type: 'tel', kind: 'mobile', maxlength: 10 })
        ];
    }

    get minorToggle() {
        return field(this.data, this.errors, 'nominee.isMinor', 'The nominee is a minor, so a guardian must be named', { type: 'checkbox' });
    }

    get guardianFields() {
        const d = this.data;
        const e = this.errors;
        return [
            field(d, e, 'nominee.guardianName', 'Guardian name', { required: true, maxlength: 120 }),
            field(d, e, 'nominee.guardianRelationship', 'Guardian relationship', { type: 'select', choices: CO_RELATIONSHIPS, required: true })
        ];
    }

    action(name, detail = {}) {
        this.dispatchEvent(new CustomEvent('formaction', { bubbles: true, composed: true, detail: { name, detail } }));
    }

    handleAdd() {
        this.action('addCoApplicant');
    }

    handleRemove(event) {
        const { key, name } = event.currentTarget.dataset;
        // eslint-disable-next-line no-alert
        if (window.confirm(`Remove ${name} from the booking?`)) {
            this.action('removeApplicant', { key });
        }
    }

    // Unticking "minor" clears the guardian so stale values are not submitted.
    handleNomineeChange(event) {
        if (event.detail.path === 'nominee.isMinor' && event.detail.value === false) {
            this.action('set', { values: { 'nominee.guardianName': '', 'nominee.guardianRelationship': '' } });
        }
    }
}