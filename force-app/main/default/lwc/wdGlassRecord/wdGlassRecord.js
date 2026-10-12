import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, deleteRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getActions from '@salesforce/apex/WdGlassRecordController.getActions';
import submitForApproval from '@salesforce/apex/WdGlassRecordController.submitForApproval';
import getHandoverForBooking from '@salesforce/apex/WdGlassRecordController.getHandoverForBooking';
import assignLeadViaRoundRobin from '@salesforce/apex/RoundRobinActionController.assignLeadViaRoundRobin';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { SECTIONS, CUSTOMER_SECTIONS, RECORD_CONFIG } from 'c/wdGlassLayouts';
import { formatDate, formatTime, formatInr, inrParts } from 'c/wdGlassFormat';

const VISIBLE_ACTIONS = 2;
const ADDRESS_ORDER = ['Street', 'City', 'StateCode', 'State', 'PostalCode', 'CountryCode', 'Country'];
const WHO_OBJECTS = new Set(['Lead', 'Contact']);
const LEAD_TABS = [
    { key: 'details', label: 'Details' },
    { key: 'related', label: 'Related' }
];
const OPPORTUNITY_TABS = [
    { key: 'details', label: 'Details' },
    { key: 'related', label: 'Related' },
    { key: 'conditions', label: 'Booking Conditions' }
];
const CUSTOMER_TABS = [
    { key: 'details', label: 'Details' },
    { key: 'cases', label: 'Cases', badge: 'cases', badgeTone: 'bad' },
    { key: 'bookings', label: 'Bookings', badge: 'bookings' },
    { key: 'invoices', label: 'Demand Notes', badge: 'invoices' },
    { key: 'payments', label: 'Demand Receipts', badge: 'payments' }
];

function errorMessage(error) {
    const body = error?.body;
    if (Array.isArray(body)) {
        return body.map((b) => b.message).join(', ');
    }
    return body?.message || body?.output?.errors?.[0]?.message || error?.message || 'Something went wrong.';
}

export default class WdGlassRecord extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;

    objectInfo;
    record;
    fieldsToLoad;
    actions = [];
    error;
    editing = false;
    saving = false;
    menuOpen = false;
    activeTab = 'details';
    customerBadges = {};
    bookingTab = 'details';

    // ---------- data ----------

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredInfo({ data, error }) {
        if (data) {
            this.objectInfo = data;
            this.fieldsToLoad = this.buildFieldList(data);
        } else if (error) {
            this.error = errorMessage(error);
        }
    }

    @wire(getRecord, { recordId: '$recordId', optionalFields: '$fieldsToLoad' })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
            this.error = undefined;
        } else if (error) {
            this.error = errorMessage(error);
        }
    }

    @wire(getActions, { objectApiName: '$objectApiName' })
    wiredActions({ data }) {
        if (data) {
            this.actions = data;
        }
    }

    get config() {
        return RECORD_CONFIG[this.objectApiName] || {};
    }

    get sectionDefs() {
        if (this.isCustomer && CUSTOMER_SECTIONS.length) {
            return CUSTOMER_SECTIONS;
        }
        return SECTIONS[this.objectApiName] || [];
    }

    get highlightFields() {
        if (this.isChannelPartner) {
            return ['RERA_Number__c', 'CP_Approval_Status__c', 'Phone', 'OwnerId'];
        }
        if (this.config.highlights) {
            return this.config.highlights;
        }
        const nameFields = new Set(this.objectInfo?.nameFields || []);
        const first = this.sectionDefs[0]?.fields || [];
        return first.filter((f) => !nameFields.has(f)).slice(0, 4);
    }

    buildFieldList(info) {
        const obj = this.objectApiName;
        const wanted = new Set(['CreatedDate', 'LastModifiedDate', ...(info.nameFields || [])]);
        // Accounts load both layouts: whether this is a customer or a channel partner is only known once the record is in.
        const defs = obj === 'Account' ? [...(SECTIONS.Account || []), ...CUSTOMER_SECTIONS] : this.sectionDefs;
        defs.forEach((s) => s.fields.forEach((f) => wanted.add(f)));
        this.highlightFields.forEach((f) => wanted.add(f));
        (this.config.facts || []).forEach((f) => wanted.add(f));
        (this.config.alerts || []).forEach((a) => wanted.add(a.field));
        if (this.config.pathField) {
            wanted.add(this.config.pathField);
        }

        const result = new Set();
        wanted.forEach((api) => {
            const fi = info.fields[api];
            if (!fi) {
                return;
            }
            result.add(`${obj}.${api}`);
            if (fi.dataType === 'Reference' && fi.relationshipName) {
                const nameField = fi.referenceToInfos?.[0]?.nameFields?.[0] || 'Name';
                result.add(`${obj}.${fi.relationshipName}.${nameField}`);
            }
            if (fi.compound) {
                Object.values(info.fields)
                    .filter((c) => c.compoundFieldName === api && c.apiName !== api)
                    .forEach((c) => result.add(`${obj}.${c.apiName}`));
            }
        });
        return [...result];
    }

    // ---------- field display ----------

    raw(api) {
        return this.record?.fields?.[api]?.value;
    }

    fieldView(api) {
        const info = this.objectInfo?.fields?.[api];
        if (!info || !this.record) {
            return null;
        }
        const node = this.record.fields[api];
        const value = node?.value;
        const label = info.dataType === 'Reference' ? info.label.replace(/ ID$/, '') : info.label;
        const view = { api, key: api, label, dataType: info.dataType, raw: value, text: '—', empty: true, isRecordLink: false, href: null };
        const set = (text) => {
            if (text !== null && text !== undefined && text !== '') {
                view.text = String(text);
                view.empty = false;
            }
        };

        switch (info.dataType) {
            case 'Reference': {
                const rel = this.record.fields[info.relationshipName];
                const nameField = info.referenceToInfos?.[0]?.nameFields?.[0] || 'Name';
                set(rel?.displayValue || rel?.value?.fields?.[nameField]?.value || value);
                if (value) {
                    view.isRecordLink = true;
                    view.linkId = value;
                }
                break;
            }
            case 'Boolean':
                view.text = value ? 'Yes' : 'No';
                view.empty = false;
                view.isBoolean = true;
                view.boolClass = value ? 'bool bool_on' : 'bool';
                break;
            case 'Currency':
                set(value === null || value === undefined ? null : formatInr(value));
                break;
            case 'Date':
                set(value ? formatDate(value) : null);
                break;
            case 'DateTime':
                set(value ? `${formatDate(value)}, ${formatTime(new Date(value))}` : null);
                break;
            case 'Address': {
                const parts = Object.values(this.objectInfo.fields)
                    .filter((c) => c.compoundFieldName === api && c.apiName !== api && !/Latitude|Longitude|GeocodeAccuracy/.test(c.apiName))
                    .sort((a, b) => this.addressRank(a.apiName) - this.addressRank(b.apiName))
                    .map((c) => this.record.fields[c.apiName]?.displayValue || this.record.fields[c.apiName]?.value)
                    .filter(Boolean);
                set(parts.join(', '));
                break;
            }
            case 'Email':
                set(value);
                view.href = value ? `mailto:${value}` : null;
                break;
            case 'Phone':
                set(value);
                view.href = value ? `tel:${value}` : null;
                break;
            case 'Url':
                set(value);
                view.href = value && !/^https?:\/\//i.test(value) ? `https://${value}` : value;
                break;
            default:
                set(node?.displayValue ?? value);
        }
        view.isHref = !!view.href && !view.empty;
        view.isPlain = !view.isRecordLink && !view.isHref && !view.isBoolean;
        view.valueClass = view.empty ? 'value value_empty' : 'value';
        return view;
    }

    addressRank(apiName) {
        const idx = ADDRESS_ORDER.findIndex((suffix) => apiName.includes(suffix));
        return idx === -1 ? 99 : idx;
    }

    // ---------- hero ----------

    get loaded() {
        return !!(this.record && this.objectInfo);
    }

    get recordTypeDeveloperName() {
        const rtId = this.recordTypeId;
        if (this.objectInfo?.recordTypeInfos?.[rtId]) {
            return this.objectInfo.recordTypeInfos[rtId].developerName;
        }
        return this.record?.fields?.RecordType?.value?.fields?.DeveloperName?.value || '';
    }

    get recordTypeName() {
        const rtId = this.recordTypeId;
        return this.objectInfo?.recordTypeInfos?.[rtId]?.name || '';
    }

    get isChannelPartner() {
        if (this.objectApiName !== 'Account') {
            return false;
        }
        const devName = this.recordTypeDeveloperName;
        const name = this.recordTypeName;
        const typeVal = this.raw('Type');
        return (
            devName === 'Channel_Partner_Residential' ||
            devName === 'SDO_Account_Partner' ||
            devName === 'Channel_Partner' ||
            devName === 'Partner' ||
            name === 'Channel Partner (Residential)' ||
            name === 'Partner' ||
            name === 'Channel Partner' ||
            typeVal === 'Channel Partner' ||
            typeVal === 'Partner'
        );
    }

    get eyebrow() {
        if (this.isChannelPartner) {
            return 'Channel Partner';
        }
        return this.config.eyebrow || this.objectInfo?.label || '';
    }

    get title() {
        if (!this.record) {
            return '';
        }
        const nameApi = this.record.fields.Name ? 'Name' : this.objectInfo?.nameFields?.[0];
        return this.raw(nameApi) || this.fieldView(nameApi)?.text || '';
    }

    get subtitle() {
        if (!this.loaded) {
            return 'Loading…';
        }
        const facts = (this.config.facts || [])
            .map((f) => this.fieldView(f))
            .filter((v) => v && !v.empty)
            .map((v) => v.text);
        const created = this.raw('CreatedDate');
        if (created) {
            facts.push(`created ${formatDate(created)}`);
        }
        const modified = this.raw('LastModifiedDate');
        if (modified) {
            facts.push(`updated ${formatDate(modified)}`);
        }
        return facts.join(' · ');
    }

    get highlights() {
        if (!this.loaded) {
            return [];
        }
        return this.highlightFields
            .map((f) => this.fieldView(f))
            .filter(Boolean)
            .map((v) => {
                let text = v.text;
                if (v.dataType === 'Currency' && !v.empty) {
                    const parts = inrParts(v.raw);
                    text = `${parts.value} ${parts.unit}`.trim();
                }
                return { ...v, text, valueClass: v.empty ? 'hl-value hl-value_empty' : 'hl-value' };
            });
    }

    get hasHighlights() {
        return this.highlights.length > 0;
    }

    get alerts() {
        if (!this.loaded) {
            return [];
        }
        return (this.config.alerts || [])
            .filter((a) => this.record.fields[a.field] && this.raw(a.field) === a.equals)
            .map((a) => ({ key: a.field, message: a.message }));
    }

    get pathField() {
        const f = this.config.pathField;
        return f && this.objectInfo?.fields?.[f] ? f : null;
    }

    get pathFieldRef() {
        return this.pathField ? `${this.objectApiName}.${this.pathField}` : null;
    }

    get pathValue() {
        return this.pathField ? this.raw(this.pathField) : null;
    }

    get recordTypeId() {
        return this.record?.recordTypeId || this.objectInfo?.defaultRecordTypeId;
    }

    /** Accounts get the customer 360 (wdGlassCustomer) instead of generic highlights and related lists. */
    get isCustomer() {
        if (this.isChannelPartner) {
            return false;
        }
        return !!this.config.customer360;
    }

    get showRelatedLists() {
        return !this.hasTabs && !this.isBooking;
    }

    get extraLists() {
        if (this.isBooking) {
            return ['Handover__c.Booking__c', 'Handovers__r', 'Handovers', ...(this.config.relatedLists || [])];
        }
        return this.config.relatedLists || [];
    }

    get pinnedLists() {
        return this.config.pinnedLists || [];
    }

    get extras() {
        return this.config.extras || {};
    }

    get isWhoRecord() {
        return WHO_OBJECTS.has(this.objectApiName);
    }

    get isLead() {
        return this.objectApiName === 'Lead';
    }

    get isOpportunity() {
        return this.objectApiName === 'Opportunity';
    }

    get isLeadOrContact() {
        return this.objectApiName === 'Lead' || this.objectApiName === 'Contact';
    }

    get isBooking() {
        return (
            this.objectApiName === 'Booking__c' ||
            (typeof this.objectApiName === 'string' && this.objectApiName.toLowerCase() === 'booking__c') ||
            this.record?.apiName === 'Booking__c' ||
            (typeof this.recordId === 'string' && this.recordId.startsWith('a30'))
        );
    }

    get isBookingDetailsTab() {
        return this.bookingTab === 'details';
    }

    get isBookingRelatedTab() {
        return this.bookingTab === 'related';
    }

    get isBookingConditionsTab() {
        return this.bookingTab === 'conditions';
    }

    get isBookingHandoverTab() {
        return this.bookingTab === 'handover';
    }

    get bookingDetailsTabClass() {
        return `wd-tab-btn ${this.isBookingDetailsTab ? 'wd-tab-btn_active' : ''}`;
    }

    get bookingRelatedTabClass() {
        return `wd-tab-btn ${this.isBookingRelatedTab ? 'wd-tab-btn_active' : ''}`;
    }

    get bookingConditionsTabClass() {
        return `wd-tab-btn ${this.isBookingConditionsTab ? 'wd-tab-btn_active' : ''}`;
    }

    get bookingHandoverTabClass() {
        return `wd-tab-btn ${this.isBookingHandoverTab ? 'wd-tab-btn_active' : ''}`;
    }

    handleBookingTabSelect(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab) {
            this.bookingTab = tab;
        }
    }

    handleRequestLeadArchive() {
        const banner = this.template.querySelector('c-lead-archive-banner');
        if (banner && banner.openModal) {
            banner.openModal(14);
        }
    }

    // ---------- tabs (Lead, Opportunity and Customer 360) ----------

    get hasTabs() {
        return this.isLead || this.isOpportunity || this.isCustomer;
    }

    get tabsLabel() {
        return this.isCustomer ? 'Customer 360 tabs' : `${this.objectInfo?.label || 'Record'} tabs`;
    }

    get tabs() {
        const defs = this.isCustomer ? CUSTOMER_TABS : this.isOpportunity ? OPPORTUNITY_TABS : LEAD_TABS;
        return defs.map((t) => {
            const selected = t.key === this.activeTab;
            const badge = t.badge ? this.customerBadges[t.badge] : null;
            return {
                key: t.key,
                label: t.label,
                badge,
                badgeClass: t.badgeTone === 'bad' ? 'tab-badge tab-badge_bad' : 'tab-badge',
                selected: String(selected),
                cls: `wd-tab-btn${selected ? ' wd-tab-btn_active' : ''}`
            };
        });
    }

    handleTabSelect(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab) {
            this.activeTab = tab;
        }
    }

    get isDetailsTab() {
        return this.activeTab === 'details';
    }

    get isRelatedTab() {
        return this.activeTab === 'related';
    }

    get isConditionsTab() {
        return this.activeTab === 'conditions';
    }

    get isCasesTab() {
        return this.activeTab === 'cases';
    }

    get isBookingsTab() {
        return this.activeTab === 'bookings';
    }

    get isInvoicesTab() {
        return this.activeTab === 'invoices';
    }

    get isPaymentsTab() {
        return this.activeTab === 'payments';
    }

    handleCustomerLoaded(event) {
        const d = event.detail || {};
        const count = (n) => (n ? String(n) : null);
        this.customerBadges = {
            cases: count(d.openCases),
            bookings: count(d.bookings),
            invoices: count(d.invoices),
            payments: count(d.payments)
        };
    }

    // ---------- sections ----------

    get sections() {
        if (!this.loaded) {
            return [];
        }
        return this.sectionDefs
            .map((s, i) => {
                const fields = s.fields.map((f) => this.fieldView(f)).filter(Boolean);
                return {
                    key: `s${i}`,
                    label: s.label,
                    fields,
                    gridClass: s.columns === 1 ? 'fields fields_one' : 'fields',
                    filled: `${fields.filter((f) => !f.empty).length}/${fields.length}`
                };
            })
            .filter((s) => s.fields.length);
    }

    // ---------- actions ----------

    get actionItems() {
        const byName = new Map(this.actions.map((a) => [a.apiName, a]));
        let ordered = this.actions;
        if (this.isChannelPartner) {
            const partnerOrder = [
                'Account.Launch_Broker_Portal',
                'Account.Retry_SAP_Sync',
                'Account.runtime_appointmentbooking__Flow',
                'Clone',
                'Delete'
            ];
            const first = partnerOrder.map((n) => byName.get(n)).filter(Boolean);
            ordered = [...first, ...this.actions.filter((a) => !first.includes(a))];
        } else if (this.config.actions) {
            ordered = this.config.actions.map((n) => byName.get(n)).filter(Boolean);
        } else if (this.config.primaryActions) {
            const first = this.config.primaryActions.map((n) => byName.get(n)).filter(Boolean);
            ordered = [...first, ...this.actions.filter((a) => !first.includes(a))];
        }
        return ordered.map((a) => {
            const isPortal = a.apiName === 'Account.Launch_Broker_Portal' || a.apiName === 'Launch_Broker_Portal';
            return {
                key: a.apiName,
                apiName: a.apiName,
                label: a.label,
                type: a.type,
                btnClass: isPortal ? 'wd-btn wd-btn_primary' : 'wd-btn wd-btn_ghost'
            };
        });
    }

    get visibleActions() {
        return this.actionItems.slice(0, VISIBLE_ACTIONS);
    }

    get menuActions() {
        return this.actionItems.slice(VISIBLE_ACTIONS);
    }

    get hasMenu() {
        return this.menuActions.length > 0;
    }

    toggleMenu() {
        this.menuOpen = !this.menuOpen;
    }

    handleMenuFocusOut(event) {
        if (!this.template.querySelector('.menu')?.contains(event.relatedTarget)) {
            this.menuOpen = false;
        }
    }

    handleMenuKey(event) {
        if (event.key === 'Escape') {
            this.menuOpen = false;
        }
    }

    handleAction(event) {
        const { api } = event.currentTarget.dataset;
        this.menuOpen = false;
        switch (api) {
            case 'Delete':
                this.confirmDelete();
                return;
            case 'Clone':
                this.navigateToRecord('clone');
                return;
            case 'Submit':
                this.submitApproval();
                return;
            case 'Convert':
                this.navigateToUrl(`/lightning/cmp/runtime_sales_lead__convertDesktopConsole?leadConvert__leadId=${this.recordId}`);
                return;
            case 'Lead.Assign_using_Round_Robin':
                // Headless LWC actions never run when opened through the quick-action URL, so call the Apex directly.
                this.assignRoundRobin();
                return;
            case 'Booking__c.View_Handover':
            case 'View_Handover':
                this.handleViewHandover();
                return;
            case 'Account.Launch_Broker_Portal':
            case 'Launch_Broker_Portal':
                this.openQuickAction('Account.Launch_Broker_Portal');
                return;
            default:
        }
        this.openQuickAction(api);
    }

    async handleViewHandover() {
        try {
            const handoverId = await getHandoverForBooking({ bookingId: this.recordId });
            if (handoverId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: handoverId,
                        objectApiName: 'Handover__c',
                        actionName: 'view'
                    }
                });
            }
        } catch (error) {
            this.toast('Handover Error', errorMessage(error), 'error');
        }
    }

    // LEX opens a quick action as a modal over the record when routed through /lightning/action/quick.
    openQuickAction(actionName) {
        const recordPath = `/lightning/r/${this.objectApiName}/${this.recordId}/view`;
        const url =
            `/lightning/action/quick/${encodeURIComponent(actionName)}?objectApiName&context=RECORD_DETAIL` +
            `&recordId=${this.recordId}&backgroundContext=${encodeURIComponent(recordPath)}`;
        this.navigateToUrl(url);
    }

    handleEditToggle() {
        this.editing = !this.editing;
        this.menuOpen = false;
    }

    handleSaveAll() {
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            this.saving = true;
            form.submit();
        }
    }

    async assignRoundRobin() {
        try {
            const ownerName = await assignLeadViaRoundRobin({ leadId: this.recordId });
            this.toast('Lead assigned', `${this.title} is now with ${ownerName}.`, 'success');
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (e) {
            this.toast('Could not assign the lead', errorMessage(e), 'error');
        }
    }

    handleSubmit() {
        this.saving = true;
    }

    handleSaved() {
        this.saving = false;
        this.editing = false;
        this.toast('Saved', `${this.title || 'Record'} was updated.`, 'success');
    }

    handleSaveError() {
        this.saving = false;
    }

    async submitApproval() {
        const ok = await LightningConfirm.open({
            message: `Submit ${this.title} for approval?`,
            label: 'Submit for Approval',
            theme: 'info'
        });
        if (!ok) {
            return;
        }
        try {
            const status = await submitForApproval({ recordId: this.recordId, comments: null });
            this.toast('Submitted', `Approval status: ${status}.`, 'success');
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (e) {
            this.toast('Could not submit', errorMessage(e), 'error');
        }
    }

    async confirmDelete() {
        const ok = await LightningConfirm.open({
            message: `Delete ${this.title}? This moves the record to the Recycle Bin.`,
            label: `Delete ${this.objectInfo?.label || 'record'}`,
            theme: 'warning'
        });
        if (!ok) {
            return;
        }
        try {
            await deleteRecord(this.recordId);
            this.toast('Deleted', `${this.title} was deleted.`, 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: this.objectApiName, actionName: 'home' }
            });
        } catch (e) {
            this.toast('Could not delete', errorMessage(e), 'error');
        }
    }

    handleOpenRecord(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }

    navigateToRecord(actionName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: this.objectApiName, actionName }
        });
    }

    navigateToUrl(url) {
        this[NavigationMixin.Navigate]({ type: 'standard__webPage', attributes: { url } });
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}