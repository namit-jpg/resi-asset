import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, deleteRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getActions from '@salesforce/apex/WdGlassRecordController.getActions';
import submitForApproval from '@salesforce/apex/WdGlassRecordController.submitForApproval';
import processWorkitem from '@salesforce/apex/WdGlassRecordController.processWorkitem';
import { refreshApex } from '@salesforce/apex';
import getOrCreateHandoverForBooking from '@salesforce/apex/HandoverWorkspaceController.getOrCreateHandoverForBooking';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import convertLeadDirect from '@salesforce/apex/SiteVisitController.convertLeadDirect';
import getLeadConversionSummary from '@salesforce/apex/WdGlassRecordController.getLeadConversionSummary';
import getOpportunityJourney from '@salesforce/apex/WdGlassRecordController.getOpportunityJourney';
import createBookingAndSyncSap from '@salesforce/apex/WdGlassRecordController.createBookingAndSyncSap';
import getApprovalHistory from '@salesforce/apex/WdGlassRecordController.getApprovalHistory';
import getAvailablePaymentPlans from '@salesforce/apex/UnitSelectionQuoteController.getAvailablePaymentPlans';
import assignPaymentPlanToOpp from '@salesforce/apex/UnitSelectionQuoteController.assignPaymentPlanToOpp';
import evaluateAndSubmitDiscountApproval from '@salesforce/apex/UnitSelectionQuoteController.evaluateAndSubmitDiscountApproval';
import shareWelcomeLetterAndConfirmBooking from '@salesforce/apex/UnitSelectionQuoteController.shareWelcomeLetterAndConfirmBooking';
import { SECTIONS, RECORD_CONFIG } from 'c/wdGlassLayouts';
import { formatDate, formatTime, formatInr, inrParts } from 'c/wdGlassFormat';

const VISIBLE_ACTIONS = 2;
const ADDRESS_ORDER = ['Street', 'City', 'StateCode', 'State', 'PostalCode', 'CountryCode', 'Country'];
const WHO_OBJECTS = new Set(['Lead', 'Contact']);

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
    collapsed = {};
    customerTab = 'overview';
    customerBadges = {};
    bookingTab = 'details';
    showSiteVisitFeedbackModal = false;

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

    conversionSummary;

    @wire(getLeadConversionSummary, { leadId: '$recordId' })
    wiredConversionSummary({ data }) {
        if (data) {
            this.conversionSummary = data;
        } else {
            this.conversionSummary = null;
        }
    }

    get isConvertedLead() {
        return this.objectApiName === 'Lead' && !!this.conversionSummary?.isConverted;
    }

    oppJourney;
    _wiredOppJourneyResult;

    @wire(getOpportunityJourney, { oppId: '$recordId' })
    wiredOppJourney(result) {
        this._wiredOppJourneyResult = result;
        if (result.data) {
            this.oppJourney = result.data;
        } else {
            this.oppJourney = null;
        }
    }

    get isOpportunity() {
        return this.objectApiName === 'Opportunity';
    }

    get hasOppBooking() {
        return this.isOpportunity && !!this.oppJourney?.bookingId;
    }

    get canGenerateBookingNow() {
        if (!this.isOpportunity || this.hasOppBooking) return false;
        const stage = this.pathValue || this.oppJourney?.stageName;
        return stage === 'Closed Won' || stage === 'Booking Form & Token Confirmation';
    }

    get oppUnitName() {
        return this.oppJourney?.unitName;
    }

    get oppUnitStatus() {
        return this.oppJourney?.unitStatus;
    }

    get oppTowerName() {
        return this.oppJourney?.towerName;
    }

    get oppAccountId() {
        return this.oppJourney?.accountId;
    }

    get oppAccountName() {
        return this.oppJourney?.accountName || 'Customer Account';
    }

    get oppBookingId() {
        return this.oppJourney?.bookingId;
    }

    get oppBookingRefNo() {
        return this.oppJourney?.bookingRefNo;
    }

    get oppBookingStatus() {
        return this.oppJourney?.bookingStatus;
    }

    get oppSapSalesOrder() {
        return this.oppJourney?.sapSalesOrder;
    }

    get isResidentialSalesOpp() {
        if (!this.isOpportunity) return false;
        const rt = this.oppJourney?.recordTypeDeveloperName;
        if (rt === 'Rental' || rt === 'Resale_Assistance') return false;
        return true;
    }

    get isRentalOpp() {
        return this.isOpportunity && this.oppJourney?.recordTypeDeveloperName === 'Rental';
    }

    get isResaleOpp() {
        return this.isOpportunity && this.oppJourney?.recordTypeDeveloperName === 'Resale_Assistance';
    }

    get oppStage() {
        return this.pathValue || this.oppJourney?.stageName || this.raw('StageName');
    }

    get isUnitSelectionStage() {
        if (!this.isOpportunity) return false;
        const stage = this.oppStage;
        return stage === 'Unit Selection' || (!this.oppUnitName && !this.raw('Interested_Unit__c'));
    }

    get showBookingConditions() {
        if (!this.extras.conditions) {
            return false;
        }
        if (this.isOpportunity && this.isUnitSelectionStage) {
            return false;
        }
        return true;
    }

    get isNegotiationStage() {
        return this.isResidentialSalesOpp && this.oppStage === 'Negotiation';
    }

    get isPaymentPlanStage() {
        return this.isResidentialSalesOpp && this.oppStage === 'Payment Plan Finalization';
    }

    get isDiscountApprovalStage() {
        return this.isResidentialSalesOpp && this.oppStage === 'Discount Approval';
    }

    get isTokenConfirmationStage() {
        return this.isResidentialSalesOpp && (this.oppStage === 'Token Amount Confirmation' || this.oppStage === 'Booking Form & Token Confirmation');
    }

    get isBookingFormStage() {
        return this.isResidentialSalesOpp && (this.oppStage === 'Booking form' || this.oppStage === 'Booking Form & Token Confirmation' || this.oppStage === 'Token Amount Confirmation');
    }

    get isShareWelcomeLetterStage() {
        return this.isResidentialSalesOpp && this.oppStage === 'Share welcome letter';
    }

    get isClosedWonStage() {
        return this.isOpportunity && this.oppStage === 'Closed Won';
    }

    get opportunityDiscountPct() {
        const actual = this.raw('Actual_Discount_Percentage__c');
        if (actual != null && Number(actual) > 0) {
            return Number(actual);
        }
        const base = this.raw('BasePrice__c');
        const disc = this.raw('BasePriceDiscount__c');
        if (base && disc && Number(base) > 0) {
            return (Number(disc) / Number(base)) * 100;
        }
        return 0;
    }

    get formattedDiscountPct() {
        return this.opportunityDiscountPct.toFixed(1);
    }

    get requiresDiscountApproval() {
        return this.opportunityDiscountPct > 7.5;
    }

    get showSidebarDiscountApproval() {
        return false;
    }

    get showNegotiationPaymentPlan() {
        return this.isResidentialSalesOpp && (this.isNegotiationStage || this.isPaymentPlanStage);
    }

    // Approval records in sidebar
    approvalHistoryRaw = [];
    _wiredApprovalHistoryResult;

    @wire(getApprovalHistory, { recordId: '$recordId' })
    wiredApprovalHistory(result) {
        this._wiredApprovalHistoryResult = result;
        if (result.data) {
            this.approvalHistoryRaw = result.data;
        } else {
            this.approvalHistoryRaw = [];
        }
    }

    get approvalHistory() {
        return (this.approvalHistoryRaw || []).map((item) => {
            let badgeClass = 'appr-badge appr-badge_pending';
            if (item.status === 'Approved') {
                badgeClass = 'appr-badge appr-badge_approved';
            } else if (item.status === 'Rejected') {
                badgeClass = 'appr-badge appr-badge_rejected';
            }
            return {
                ...item,
                isPending: item.isPending,
                workitemId: item.workitemId,
                statusBadgeClass: badgeClass
            };
        });
    }

    get hasApprovalHistory() {
        return this.approvalHistory && this.approvalHistory.length > 0;
    }

    // Payment Plans
    paymentPlansData = null;
    submittingDiscount = false;
    discountComments = '';
    tokenAmountInput = 200000;
    tokenPaymentMode = 'RTGS';
    tokenPaymentRef = '';
    sharingWelcomeLetter = false;

    get paymentPlanModeOptions() {
        return [
            { label: 'RTGS / NEFT / IMPS', value: 'RTGS' },
            { label: 'Net Banking', value: 'Net Banking' },
            { label: 'Cheque', value: 'Cheque' }
        ];
    }

    @wire(getAvailablePaymentPlans, { oppId: '$recordId' })
    wiredPaymentPlans({ data, error }) {
        if (data) {
            this.paymentPlansData = data;
        } else {
            this.paymentPlansData = null;
        }
    }

    get hasPaymentPlans() {
        return !!(this.paymentPlansData?.availablePlans && this.paymentPlansData.availablePlans.length > 0);
    }

    get paymentPlansList() {
        if (!this.paymentPlansData?.availablePlans) return [];
        const currentId = this.paymentPlansData.currentPlanId || this.raw('Payment_Plan__c');
        return this.paymentPlansData.availablePlans.map((p) => {
            const isSelected = p.isSelected || (currentId && p.planId === currentId);
            return {
                id: p.planId,
                name: p.planName,
                category: p.planCategory,
                description: p.description || `${p.installmentCount || 0} Installments · Milestone-Based Payment Structure`,
                installmentCount: p.installmentCount,
                isSelected: isSelected,
                cardClass: isSelected ? 'plan-card plan-card_selected' : 'plan-card',
                badgeText: isSelected ? '✓ Active Selection' : (p.planCategory ? p.planCategory : 'Milestone-Based'),
                badgeClass: isSelected ? 'plan-badge plan-badge_active' : 'plan-badge',
                btnClass: isSelected ? 'wd-btn wd-btn_selected' : 'wd-btn wd-btn_secondary',
                btnLabel: isSelected ? '✓ Selected' : 'Select Plan ↗',
                disabled: isSelected
            };
        });
    }

    get currentSelectedPlanName() {
        if (this.paymentPlansData?.currentPlanName) {
            return this.paymentPlansData.currentPlanName;
        }
        const active = this.paymentPlansList.find((p) => p.isSelected);
        return active ? active.name : (this.raw('Payment_Plan__c') ? '40X60' : 'None Selected');
    }

    get hasSelectedPlan() {
        return !!(this.paymentPlansData?.currentPlanId || this.raw('Payment_Plan__c') || this.paymentPlansList.some((p) => p.isSelected));
    }

    get towerOcStatusText() {
        if (!this.paymentPlansData) return '';
        if (this.paymentPlansData.ocReceived) {
            return `🏛️ ${this.paymentPlansData.towerName || 'Tower'} (OC Received) — Time-Linked / Date-Based Plans Activated`;
        }
        return `🏗️ ${this.paymentPlansData.towerName || 'Tower'} (Under Construction) — Construction Milestone / CLP Plans Activated`;
    }

    get towerOcBadgeClass() {
        return this.paymentPlansData?.ocReceived ? 'oc-badge oc-badge_received' : 'oc-badge oc-badge_pending';
    }

    get config() {
        return RECORD_CONFIG[this.objectApiName] || {};
    }

    get sectionDefs() {
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
        this.sectionDefs.forEach((s) => s.fields.forEach((f) => wanted.add(f)));
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
                if (v.api === 'Token_Amount_Paid__c') {
                    const paid = Number(v.raw) || 0;
                    const due = Number(this.raw('Token_Amount__c')) || 0;
                    const status = this.raw('Token_Payment_Status__c');
                    if (paid > 0) {
                        const parts = inrParts(paid);
                        text = `${parts.value} ${parts.unit} · ${status || 'Paid'}`.trim();
                        v.empty = false;
                    } else if (due > 0) {
                        const parts = inrParts(due);
                        text = `${parts.value} ${parts.unit} · Due`.trim();
                        v.empty = false;
                    } else {
                        text = 'Pending';
                    }
                }
                if (v.api === 'Payment_Plan__c' && (v.empty || text === '—') && this.currentSelectedPlanName && this.currentSelectedPlanName !== 'None Selected') {
                    text = this.currentSelectedPlanName;
                    v.empty = false;
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
        return !this.isCustomer && !this.isBooking;
    }

    get extraLists() {
        if (this.isBooking) {
            return ['Handover__c.Booking__c', 'Handovers__r', 'Handovers', ...(this.config.relatedLists || [])];
        }
        return this.config.relatedLists || [];
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

    handleCustomerTabSelect(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab) {
            this.customerTab = tab;
        }
    }

    handleCustomerLoaded(event) {
        const detail = event.detail;
        if (detail) {
            const holdingsText = detail.holdingsCount ? `${detail.holdingsCount} ${detail.holdingsCount === 1 ? 'unit' : 'units'}` : null;
            const overdueText = detail.overdueCount > 0 ? String(detail.overdueCount) : null;
            const pipelineTotal = (detail.opportunitiesCount || 0) + (detail.siteVisitsCount || 0);
            const pipelineText = pipelineTotal > 0 ? `${pipelineTotal}` : null;
            this.customerBadges = {
                holdings: holdingsText,
                overdue: overdueText,
                pipeline: pipelineText
            };
        }
    }

    get isOverviewTab() {
        return this.customerTab === 'overview';
    }

    get isFinancialsTab() {
        return this.customerTab === 'financials';
    }

    get isPipelineTab() {
        return this.customerTab === 'pipeline';
    }

    get overviewTabClass() {
        return `wd-tab-btn ${this.isOverviewTab ? 'wd-tab-btn_active' : ''}`;
    }

    get financialsTabClass() {
        return `wd-tab-btn ${this.isFinancialsTab ? 'wd-tab-btn_active' : ''}`;
    }

    get pipelineTabClass() {
        return `wd-tab-btn ${this.isPipelineTab ? 'wd-tab-btn_active' : ''}`;
    }

    // ---------- sections ----------

    get sections() {
        if (!this.loaded) {
            return [];
        }
        return this.sectionDefs
            .map((s, i) => {
                const fields = s.fields.map((f) => this.fieldView(f)).filter(Boolean);
                const isCollapsed = !!this.collapsed[s.label];
                return {
                    key: `s${i}`,
                    label: s.label,
                    fields,
                    isCollapsed,
                    isOpen: !isCollapsed,
                    ariaExpanded: String(!isCollapsed),
                    chevronClass: isCollapsed ? 'chevron chevron_closed' : 'chevron',
                    gridClass: s.columns === 1 ? 'fields fields_one' : 'fields',
                    filled: `${fields.filter((f) => !f.empty).length}/${fields.length}`
                };
            })
            .filter((s) => s.fields.length);
    }

    handleToggleSection(event) {
        const label = event.currentTarget.dataset.label;
        if (label) {
            this.collapsed = { ...this.collapsed, [label]: !this.collapsed[label] };
        }
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
        } else if (this.isOpportunity) {
            const stage = this.pathValue || this.oppJourney?.stageName;
            const dynamicPrimary = [];

            if (stage === 'Booking form' || stage === 'Booking Form & Token Confirmation' || stage === 'Token Amount Confirmation') {
                const bForm = byName.get('Opportunity.Booking_Form');
                if (bForm) {
                    dynamicPrimary.push({
                        ...bForm,
                        btnClass: 'wd-btn wd-btn_primary'
                    });
                } else {
                    dynamicPrimary.push({
                        key: 'Opportunity.Booking_Form',
                        apiName: 'Opportunity.Booking_Form',
                        label: 'Booking Form',
                        type: 'Custom',
                        btnClass: 'wd-btn wd-btn_primary'
                    });
                }
            } else if (stage === 'Share welcome letter') {
                dynamicPrimary.push({
                    key: 'Generate_Welcome_Letter',
                    apiName: 'Generate_Welcome_Letter',
                    label: '⚡ Generate Welcome Letter ↗',
                    type: 'Custom',
                    btnClass: 'wd-btn wd-btn_primary'
                });
            } else if (stage === 'Unit Shortlisting' || stage === 'Unit Selection' || (!this.oppJourney?.unitId && !this.raw('Interested_Unit__c'))) {
                const selInv = byName.get('Opportunity.Select_Inventory');
                if (selInv) dynamicPrimary.push(selInv);
            } else if (stage === 'Qualification' || stage === 'Site Visit') {
                const sVisit = byName.get('Opportunity.Site_Visit');
                if (sVisit) dynamicPrimary.push(sVisit);
            } else if (stage === 'Discount Approval') {
                dynamicPrimary.push({
                    key: 'Submit',
                    apiName: 'Submit',
                    label: 'Submit for Approval ↗',
                    type: 'Standard',
                    btnClass: 'wd-btn wd-btn_primary'
                });
            }

            if (stage === 'Closed Won') {
                dynamicPrimary.push({
                    key: 'Go_To_Booking',
                    apiName: 'Go_To_Booking',
                    label: 'Go to Booking ↗',
                    type: 'Custom',
                    btnClass: 'wd-btn wd-btn_primary'
                });
            } else if (this.hasOppBooking) {
                dynamicPrimary.push({
                    key: 'Go_To_Booking',
                    apiName: 'Go_To_Booking',
                    label: 'Go to Booking ↗',
                    type: 'Custom',
                    btnClass: 'wd-btn wd-btn_ghost'
                });
            }

            // Standard utilities strictly reserved for More menu
            const standardMenu = [byName.get('Clone'), byName.get('Delete')].filter(Boolean);

            let result = [...dynamicPrimary, ...standardMenu];

            // Strict sanitization: ensure no legacy, resale, or flow actions leak in
            result = result.filter((a) => {
                const name = a.apiName || '';
                if (
                    name.includes('Generate_Sales_Offer') ||
                    name.includes('Generate_Sales_Order') ||
                    name.includes('Mark_Closed_Won') ||
                    name.includes('Transfer') ||
                    name.includes('Builder_NOC') ||
                    name.includes('No_Dues') ||
                    name.includes('Dues_Clearance') ||
                    name.includes('New_Owner') ||
                    name.includes('Initiate_Resale') ||
                    name.includes('Initiate_Rental') ||
                    name.includes('Add_Payment') ||
                    name.includes('KYC') ||
                    name.includes('Resale') ||
                    name.includes('runtime_appointmentbooking') ||
                    name.includes('SDO_') ||
                    name.includes('EMC_') ||
                    name.includes('MERL_')
                ) {
                    return false;
                }
                return true;
            });

            return result.map((a) => {
                const isPrimary = a.btnClass?.includes('wd-btn_primary') ||
                    (a.apiName === 'Generate_Welcome_Letter') ||
                    ((stage === 'Unit Shortlisting' || stage === 'Unit Selection') && a.apiName === 'Opportunity.Select_Inventory') ||
                    ((stage === 'Booking form' || stage === 'Booking Form & Token Confirmation' || stage === 'Token Amount Confirmation') && a.apiName === 'Opportunity.Booking_Form') ||
                    (stage === 'Discount Approval' && a.apiName === 'Submit') ||
                    (stage === 'Closed Won' && a.apiName === 'Go_To_Booking') ||
                    (a.apiName === 'Create_Booking_Sync_Sap');
                return {
                    key: a.apiName,
                    apiName: a.apiName,
                    label: a.label,
                    type: a.type,
                    btnClass: isPrimary ? 'wd-btn wd-btn_primary' : 'wd-btn wd-btn_ghost'
                };
            });
        } else if (this.config.actions) {
            ordered = this.config.actions.map((n) => byName.get(n)).filter(Boolean);
        } else if (this.config.primaryActions) {
            const first = this.config.primaryActions.map((n) => byName.get(n)).filter(Boolean);
            ordered = [...first, ...this.actions.filter((a) => !first.includes(a))];
        }

        // Strict enforcement: Only Channel Partner accounts can have Launch Broker Portal
        if (!this.isChannelPartner) {
            ordered = ordered.filter(
                (a) => a.apiName !== 'Account.Launch_Broker_Portal' && a.apiName !== 'Launch_Broker_Portal'
            );
        }
        return ordered.map((a) => {
            const isPortal = a.apiName === 'Account.Launch_Broker_Portal' || a.apiName === 'Launch_Broker_Portal';
            const isFeedback = a.apiName === 'Site_Visit__c.Add_Feedback' || a.apiName === 'Add_Feedback';
            const isHighlight = isPortal || isFeedback ||
                a.apiName === 'Booking__c.Initiate_Resale' || a.apiName === 'Booking__c.Initiate_Rental' ||
                a.apiName === 'Initiate_Resale' || a.apiName === 'Initiate_Rental';
            return {
                key: a.apiName,
                apiName: a.apiName,
                label: a.label,
                type: a.type,
                btnClass: isHighlight ? 'wd-btn wd-btn_primary' : 'wd-btn wd-btn_ghost'
            };
        });
    }

    get visibleActionsCount() {
        return this.config.visibleActions || VISIBLE_ACTIONS;
    }

    get visibleActions() {
        return this.actionItems.slice(0, this.visibleActionsCount);
    }

    get menuActions() {
        return this.actionItems.slice(this.visibleActionsCount);
    }

    get hasMenu() {
        return this.menuActions.length > 0;
    }

    get editLabel() {
        return this.editing ? 'Cancel' : 'Edit';
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
            case 'Convert_Lead':
            case 'Convert':
                this.handleConvertLead();
                return;
            case 'Go_To_Booking':
                this.handleOpenOppBooking();
                return;
            case 'View_Opp_Account':
                this.handleOpenOppAccount();
                return;
            case 'Create_Booking_Sync_Sap':
                this.handleCreateBookingAndSyncSap();
                return;
            case 'Generate_Welcome_Letter':
                this.handleShareWelcomeLetter();
                return;
            case 'Booking__c.View_Handover':
            case 'View_Handover':
                this.handleViewHandover();
                return;
            case 'Account.Launch_Broker_Portal':
            case 'Launch_Broker_Portal':
                this.openQuickAction('Account.Launch_Broker_Portal');
                return;
            case 'Site_Visit__c.Add_Feedback':
            case 'Add_Feedback':
                this.showSiteVisitFeedbackModal = true;
                return;
            default:
        }
        this.openQuickAction(api);
    }

    async handleConvertLead() {
        if (this.isConvertedLead) {
            this.toast('Already Converted', 'This lead has already been converted to an Opportunity.', 'info');
            return;
        }

        const confirmed = await LightningConfirm.open({
            message: 'Convert this Qualified Lead into a Residential Sales Opportunity and Person Account?',
            variant: 'header',
            label: 'Convert Lead',
            theme: 'default'
        });
        if (!confirmed) return;

        this.saving = true;
        try {
            const res = await convertLeadDirect({ leadId: this.recordId });
            this.toast(
                'Lead Converted Successfully',
                'Residential Sales Opportunity and Person Account created.',
                'success'
            );
            if (res && res.opportunityId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: res.opportunityId,
                        objectApiName: 'Opportunity',
                        actionName: 'view'
                    }
                });
            } else {
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            }
        } catch (error) {
            this.toast('Conversion Blocked', errorMessage(error), 'warning');
        } finally {
            this.saving = false;
        }
    }

    handleOpenConvertedAccount() {
        if (this.conversionSummary?.accountId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.conversionSummary.accountId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        }
    }

    handleOpenConvertedOpportunity() {
        if (this.conversionSummary?.opportunityId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.conversionSummary.opportunityId,
                    objectApiName: 'Opportunity',
                    actionName: 'view'
                }
            });
        }
    }

    handleOpenConvertedBooking() {
        if (this.conversionSummary?.bookingId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.conversionSummary.bookingId,
                    objectApiName: 'Booking__c',
                    actionName: 'view'
                }
            });
        }
    }

    handleOpenOppAccount() {
        const accId = this.oppJourney?.accountId || this.raw('AccountId');
        if (accId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: accId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        }
    }

    async handleOpenOppBooking() {
        if (this.oppJourney?.bookingId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.oppJourney.bookingId,
                    objectApiName: 'Booking__c',
                    actionName: 'view'
                }
            });
            return;
        }
        this.saving = true;
        try {
            const res = await createBookingAndSyncSap({ oppId: this.recordId });
            if (res && res.bookingId) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: res.bookingId,
                        objectApiName: 'Booking__c',
                        actionName: 'view'
                    }
                });
                return;
            }
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (err) {
            this.toast('Opening Booking', errorMessage(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleCreateBookingAndSyncSap() {
        if (this.oppJourney?.bookingId) {
            this.handleOpenOppBooking();
            return;
        }
        this.saving = true;
        try {
            const res = await createBookingAndSyncSap({ oppId: this.recordId });
            this.toast(
                'Booking Confirmed & SAP Synced',
                res?.message || 'SAP Sales Order created and Booking confirmed.',
                'success'
            );
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (err) {
            this.toast('Booking Creation Failed', errorMessage(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    handleOpenFeedbackModal() {
        this.showSiteVisitFeedbackModal = true;
    }

    handleCloseFeedbackModal() {
        this.showSiteVisitFeedbackModal = false;
    }

    handleFeedbackSaved() {
        this.showSiteVisitFeedbackModal = false;
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }

    async handleViewHandover() {
        try {
            const handoverId = await getOrCreateHandoverForBooking({ bookingId: this.recordId });
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
            `/lightning/action/quick/${encodeURIComponent(actionName)}?objectApiName=${encodeURIComponent(this.objectApiName || '')}&context=RECORD_DETAIL` +
            `&recordId=${this.recordId}&backgroundContext=${encodeURIComponent(recordPath)}`;
        this.navigateToUrl(url);
    }

    handleEditToggle() {
        this.editing = !this.editing;
        this.menuOpen = false;
    }

    handleEditRequest() {
        if (!this.editing) {
            this.editing = true;
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

    async handleSelectPlan(event) {
        const planId = event.currentTarget.dataset.id;
        if (!planId) return;
        this.saving = true;
        try {
            const res = await assignPaymentPlanToOpp({ oppId: this.recordId, planId: planId });
            this.toast('Payment Plan Assigned', res?.message || 'Payment plan assigned and stage advanced.', 'success');
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (err) {
            this.toast('Error Assigning Plan', errorMessage(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleProceedFromPaymentPlan() {
        this.saving = true;
        try {
            const res = await evaluateAndSubmitDiscountApproval({ oppId: this.recordId, comments: '' });
            if (res.requiresApproval) {
                this.toast('Submitted for Approval', res.message || 'Submitted for management discount approval.', 'warning');
            } else {
                this.toast('Stage Advanced', res.message || 'Payment plan finalized. Advanced to Booking form.', 'success');
            }
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (err) {
            this.toast('Error Advancing Stage', errorMessage(err), 'error');
        } finally {
            this.saving = false;
        }
    }

    handleDiscountCommentsChange(event) {
        this.discountComments = event.target.value;
    }

    submitApproval() {
        this.handleSubmitDiscountApproval();
    }

    async handleSubmitDiscountApproval() {
        this.submittingDiscount = true;
        try {
            const res = await evaluateAndSubmitDiscountApproval({ oppId: this.recordId, comments: this.discountComments });
            if (res.requiresApproval) {
                this.toast('Approval Submitted', res.message || 'Discount exceeds 7.5% threshold. Submitted to real.resi@wd.demo.', 'warning');
            } else {
                this.toast('Discount Auto-Cleared', res.message || 'Discount is compliant (<=7.5%). Advanced to Booking form.', 'success');
            }
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (err) {
            this.toast('Discount Approval Failed', errorMessage(err), 'error');
        } finally {
            this.submittingDiscount = false;
        }
    }

    get formattedTokenPaid() {
        const amt = this.oppJourney?.tokenAmountPaid || this.tokenAmountInput || 1339300;
        return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(amt);
    }

    handleTokenAmountChange(event) {
        this.tokenAmountInput = parseFloat(event.target.value) || 0;
    }

    handleTokenModeChange(event) {
        this.tokenPaymentMode = event.target.value;
    }

    handleTokenRefChange(event) {
        this.tokenPaymentRef = event.target.value;
    }

    handleShareWelcomeLetter() {
        if (this.recordId) {
            window.open(`/apex/WelcomeLetter?id=${this.recordId}`, '_blank');
        }
    }

    connectedCallback() {
        this._pageShowListener = () => {
            if (this.recordId) {
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                if (this._wiredOppJourneyResult) refreshApex(this._wiredOppJourneyResult);
                if (this._wiredApprovalHistoryResult) refreshApex(this._wiredApprovalHistoryResult);
            }
        };
        window.addEventListener('pageshow', this._pageShowListener);
        window.addEventListener('focus', this._pageShowListener);
    }

    disconnectedCallback() {
        if (this._pageShowListener) {
            window.removeEventListener('pageshow', this._pageShowListener);
            window.removeEventListener('focus', this._pageShowListener);
        }
    }

    async handleApproveStep(event) {
        const workitemId = event.target.dataset.workitemId;
        try {
            await processWorkitem({ workitemId, action: 'Approve', comments: 'Approved by Management' });
            this.toast('Discount Approved', 'Approval granted. Stage advancing to Booking form.', 'success');
            if (this._wiredApprovalHistoryResult) await refreshApex(this._wiredApprovalHistoryResult);
            if (this._wiredOppJourneyResult) await refreshApex(this._wiredOppJourneyResult);
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (e) {
            this.toast('Approval Failed', errorMessage(e), 'error');
        }
    }

    async handleRejectStep(event) {
        const workitemId = event.target.dataset.workitemId;
        try {
            await processWorkitem({ workitemId, action: 'Reject', comments: 'Rejected by Management' });
            this.toast('Discount Rejected', 'Discount approval request rejected.', 'warning');
            if (this._wiredApprovalHistoryResult) await refreshApex(this._wiredApprovalHistoryResult);
            if (this._wiredOppJourneyResult) await refreshApex(this._wiredOppJourneyResult);
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (e) {
            this.toast('Rejection Failed', errorMessage(e), 'error');
        }
    }
}