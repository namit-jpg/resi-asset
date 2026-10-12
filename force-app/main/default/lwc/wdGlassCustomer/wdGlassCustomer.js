import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCustomer from '@salesforce/apex/WdGlassCustomerController.getCustomer';
import { inrParts, formatInr, formatDate, formatRelative, statusTone } from 'c/wdGlassFormat';

function money(amount) {
    const p = inrParts(amount);
    return { value: p.value, unit: p.unit };
}

function daysUntil(date) {
    if (!date) {
        return null;
    }
    const [y, m, d] = date.split('-').map(Number);
    const target = new Date(y, m - 1, d);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return Math.round((target - today) / 86400000);
}

export default class WdGlassCustomer extends NavigationMixin(LightningElement) {
    @api recordId;
    /**
     * summary (alerts + KPI cards) | holdings | cases | invoices | payments (Customer 360 tabs)
     * | sidebar-profile | sidebar-pipeline (side column)
     */
    @api mode = 'summary';

    data;
    error;

    @wire(getCustomer, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.data = data;
            this.error = undefined;
            if (this.isSummary) {
                // Tab badges on the record page.
                this.dispatchEvent(
                    new CustomEvent('customerloaded', {
                        detail: {
                            openCases: data.openCases,
                            bookings: data.holdings.length,
                            invoices: data.invoices.length,
                            payments: data.payments.length
                        }
                    })
                );
            }
        } else if (error) {
            this.error = error?.body?.message || 'Could not load the customer summary.';
        }
    }

    get isSummary() {
        return this.mode === 'summary';
    }

    get isHoldings() {
        return this.mode === 'holdings';
    }

    get isCases() {
        return this.mode === 'cases';
    }

    get isInvoices() {
        return this.mode === 'invoices';
    }

    get isPayments() {
        return this.mode === 'payments';
    }

    get isSidebarProfile() {
        return this.mode === 'sidebar-profile';
    }

    get isSidebarPipeline() {
        return this.mode === 'sidebar-pipeline';
    }

    get loaded() {
        return !!this.data;
    }

    // ---------- summary ----------

    get alerts() {
        return (this.data?.alerts || []).map((a, i) => ({
            key: `a${i}`,
            message: a.message,
            className: `alert alert_${a.tone}`
        }));
    }

    get hasAlerts() {
        return this.alerts.length > 0;
    }

    get cards() {
        const d = this.data;
        if (!d) {
            return [];
        }
        return d.isBuyer ? this.buyerCards(d) : this.prospectCards(d);
    }

    buyerCards(d) {
        const projects = [...new Set(d.holdings.map((h) => h.project).filter(Boolean))];
        const paidPct = d.portfolioValue ? Math.round((d.paidToDate / d.portfolioValue) * 100) : 0;
        const next = d.nextDue;
        const nextIn = next ? daysUntil(next.dueDate) : null;
        const cards = [
            {
                label: 'Portfolio',
                ...money(d.portfolioValue),
                caption: `${d.holdings.length} ${d.holdings.length === 1 ? 'unit' : 'units'}${projects.length ? ' · ' + projects.join(', ') : ''}`
            },
            {
                label: 'Paid to date',
                ...money(d.paidToDate),
                caption: d.pendingReceipts
                    ? `${paidPct}% of booked value · ${formatInr(d.pendingReceipts)} awaiting approval`
                    : `${paidPct}% of booked value`,
                progress: Math.min(100, paidPct)
            },
            d.overdueCount
                ? {
                      label: 'Overdue',
                      ...money(d.overdueAmount),
                      caption: `${d.overdueCount} ${d.overdueCount === 1 ? 'instalment' : 'instalments'} · oldest due ${formatDate(d.oldestOverdue)}`,
                      tone: 'negative'
                  }
                : { label: 'Overdue', value: 'Nil', unit: '', caption: 'All dues so far are cleared', tone: 'positive' },
            next
                ? {
                      label: 'Next instalment',
                      ...money(next.outstanding),
                      caption: `${nextIn === 0 ? 'Due today' : `Due in ${nextIn} days`} · ${formatDate(next.dueDate)} · ${next.milestone}`,
                      tone: nextIn !== null && nextIn <= 15 ? 'warning' : null
                  }
                : { label: 'Next instalment', value: '—', unit: '', caption: 'No upcoming dues on the schedule' }
        ];
        if (d.openOpportunities) {
            cards.push({
                label: 'Also considering',
                ...money(d.pipelineValue),
                caption: `${d.openOpportunities} open ${d.openOpportunities === 1 ? 'opportunity' : 'opportunities'} · upsell / second home`
            });
        }
        return this.decorate(cards);
    }

    prospectCards(d) {
        const top = d.opportunities[0];
        const visit = d.lastSiteVisit;
        return this.decorate([
            {
                label: 'Open opportunities',
                value: String(d.openOpportunities),
                unit: '',
                caption: d.openOpportunities ? `${formatInr(d.pipelineValue)} in pipeline` : 'No active deal yet'
            },
            {
                label: 'Interested in',
                value: top ? top.title : '—',
                unit: '',
                text: true,
                caption: top ? `${top.status}${top.onDate ? ' · closing ' + formatDate(top.onDate) : ''}` : 'Capture a unit preference'
            },
            {
                label: 'Last site visit',
                value: visit ? formatRelative(visit.onDate) : 'None yet',
                unit: '',
                text: true,
                caption: visit ? [visit.title, visit.subtitle].filter(Boolean).join(' · ') : 'Schedule a site visit to move the deal'
            },
            {
                label: 'Customer since',
                value: formatDate(d.profile.customerSince),
                unit: '',
                text: true,
                caption: d.profile.source ? `Came in via ${d.profile.source}` : `Owned by ${d.profile.owner}`
            }
        ]);
    }

    decorate(cards) {
        return cards.map((c, i) => ({
            ...c,
            key: `k${i}`,
            className: `wd-glass kpi${c.tone ? ' kpi_' + c.tone : ''}`,
            valueClass: c.text || String(c.value).length > 12 ? 'kpi-value kpi-value_text' : 'kpi-value',
            hasProgress: typeof c.progress === 'number',
            progressStyle: `width:${c.progress || 0}%`
        }));
    }

    get gridClass() {
        return this.cards.length > 4 ? 'kpis kpis_five' : 'kpis';
    }

    // ---------- holdings ----------

    get holdings() {
        return (this.data?.holdings || []).map((h) => {
            const paidPct = h.value ? Math.min(100, Math.round((h.paid / h.value) * 100)) : 0;
            const possessionIn = daysUntil(h.possessionDate);
            return {
                ...h,
                key: h.bookingId,
                spec: [h.configuration, h.area ? `${h.area.toLocaleString('en-IN')} SF` : null].filter(Boolean).join(' · '),
                location: [h.project, h.tower].filter(Boolean).join(' · '),
                valueText: formatInr(h.value),
                paidText: formatInr(h.paid),
                outstandingText: formatInr(h.outstanding),
                paidPct,
                progressStyle: `width:${paidPct}%`,
                statusClass: `chip chip_${statusTone(h.status)}`,
                facts: [
                    { key: 'booked', label: 'Booked', value: formatDate(h.bookingDate) },
                    {
                        key: 'possession',
                        label: 'Possession',
                        value: h.possessionDate
                            ? `${formatDate(h.possessionDate)}${possessionIn > 0 ? ` (${possessionIn} days)` : ''}`
                            : 'Not scheduled'
                    },
                    { key: 'plan', label: 'Payment plan', value: h.paymentPlan || '—' },
                    { key: 'agreement', label: 'Agreement', value: h.agreementSigned ? 'Signed' : 'Not signed yet' }
                ]
            };
        });
    }

    get hasHoldings() {
        return this.holdings.length > 0;
    }

    get showHoldingsEmpty() {
        return this.loaded && !this.hasHoldings;
    }

    // ---------- cases / invoices / payments tabs ----------

    get caseColumns() {
        return [
            { key: 'caseNumber', label: 'Case', type: 'link' },
            { key: 'subject', label: 'Subject' },
            { key: 'type', label: 'Type' },
            { key: 'priority', label: 'Priority' },
            { key: 'status', label: 'Status', type: 'status' },
            { key: 'opened', label: 'Opened', type: 'date' },
            { key: 'closedOn', label: 'Closed', type: 'date' }
        ];
    }

    get caseRows() {
        return this.data?.allCases || [];
    }

    get casesSummary() {
        const all = this.caseRows.length;
        const open = this.data?.openCases || 0;
        return all ? `${open} open · ${all - open} closed` : 'No cases yet';
    }

    get invoiceColumns() {
        return [
            { key: 'name', label: 'Demand note', type: 'link' },
            { key: 'unit', label: 'Unit' },
            { key: 'milestone', label: 'Milestone' },
            { key: 'dueDate', label: 'Due', type: 'date' },
            { key: 'amount', label: 'Demand value', type: 'inr' },
            { key: 'received', label: 'Received', type: 'inr' },
            { key: 'balance', label: 'Balance', type: 'inr' },
            { key: 'state', label: 'Status', type: 'status' }
        ];
    }

    get invoiceRows() {
        return (this.data?.invoices || []).map((i) => ({
            ...i,
            state: i.overdue ? 'Overdue' : i.balance > 0 ? i.status || 'Open' : 'Paid'
        }));
    }

    get invoicesSummary() {
        const d = this.data;
        if (!d?.invoices.length) {
            return 'No demands yet';
        }
        const parts = [`${formatInr(d.invoicedTotal)} demanded`, `${formatInr(d.invoiceBalance)} outstanding`];
        if (d.overdueInvoices) {
            parts.push(`${d.overdueInvoices} overdue`);
        }
        return parts.join(' · ');
    }

    get paymentColumns() {
        return [
            { key: 'name', label: 'Receipt', type: 'link' },
            { key: 'paidOn', label: 'Paid on', type: 'date' },
            { key: 'unit', label: 'Unit' },
            { key: 'invoice', label: 'Against' },
            { key: 'mode', label: 'Mode' },
            { key: 'reference', label: 'Reference' },
            { key: 'amount', label: 'Amount', type: 'inr' },
            { key: 'approval', label: 'Approval', type: 'status' }
        ];
    }

    get paymentRows() {
        return this.data?.payments || [];
    }

    get paymentsSummary() {
        const d = this.data;
        if (!d?.payments.length) {
            return 'Nothing received yet';
        }
        return d.pendingReceipts ? `${this.paidSummary} · ${formatInr(d.pendingReceipts)} awaiting approval` : this.paidSummary;
    }

    get allDues() {
        return this.duesFrom(this.data?.allDues);
    }

    get hasAllDues() {
        return this.allDues.length > 0;
    }

    handleNewCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Case', actionName: 'new' },
            state: { defaultFieldValues: `AccountId=${this.recordId}`, navigationLocation: 'RELATED_LIST' }
        });
    }

    // ---------- sidebar ----------

    get profile() {
        const p = this.data?.profile || {};
        const primaryPhone = p.mobile || p.phone;
        return {
            ...p,
            primaryPhone,
            telHref: primaryPhone ? `tel:${primaryPhone}` : null,
            mailHref: p.email ? `mailto:${p.email}` : null,
            waHref: primaryPhone ? `https://wa.me/${primaryPhone.replace(/\D/g, '')}` : null,
            lines: [
                { key: 'city', label: 'City', value: p.city },
                { key: 'owner', label: 'Relationship manager', value: p.owner },
                { key: 'since', label: 'Customer since', value: p.customerSince ? formatDate(p.customerSince) : null },
                { key: 'source', label: 'Source', value: p.source },
                { key: 'cp', label: 'Channel partner', value: p.channelPartner }
            ].filter((l) => l.value)
        };
    }

    duesFrom(list) {
        return (list || []).map((i) => {
            const inDays = daysUntil(i.dueDate);
            let when = formatDate(i.dueDate);
            if (i.overdue) {
                when = `${Math.abs(inDays)} days overdue`;
            } else if (inDays !== null && inDays <= 30) {
                when = inDays === 0 ? 'Due today' : `Due in ${inDays} days`;
            }
            return {
                ...i,
                key: i.id,
                title: i.milestone,
                meta: [i.unit, formatDate(i.dueDate)].filter(Boolean).join(' · '),
                amountText: formatInr(i.outstanding),
                when,
                whenClass: i.overdue ? 'when when_bad' : inDays !== null && inDays <= 15 ? 'when when_warn' : 'when',
                interestText: i.interest > 0 ? `+ ${formatInr(i.interest)} interest` : null
            };
        });
    }

    listOf(items, { amount = false, dateField = 'onDate', relative = false } = {}) {
        return (items || []).map((i) => ({
            ...i,
            key: i.id,
            meta: [i.subtitle, i[dateField] ? (relative ? formatRelative(i[dateField]) : formatDate(i[dateField])) : null]
                .filter(Boolean)
                .join(' · '),
            amountText: amount && i.amount ? formatInr(i.amount) : null,
            statusClass: i.status ? `chip chip_${statusTone(i.status)}` : null
        }));
    }

    get opportunities() {
        return this.listOf(this.data?.opportunities, { amount: true });
    }

    get siteVisits() {
        return this.listOf(this.data?.siteVisits, { relative: true });
    }

    get enquiries() {
        return this.listOf(this.data?.enquiries);
    }

    get hasOpportunities() {
        return this.opportunities.length > 0;
    }

    get hasSiteVisits() {
        return this.siteVisits.length > 0;
    }

    get hasEnquiries() {
        return this.enquiries.length > 0;
    }

    get paidSummary() {
        const d = this.data;
        return d ? `${formatInr(d.paidToDate)} received` : '';
    }

    get dueSummary() {
        const d = this.data;
        if (!d) {
            return '';
        }
        return d.overdueCount ? `${formatInr(d.overdueAmount)} overdue` : 'Nothing overdue';
    }

    // ---------- navigation ----------

    handleOpen(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }

    handleNewOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'new' },
            state: { defaultFieldValues: `AccountId=${this.recordId}`, navigationLocation: 'RELATED_LIST' }
        });
    }
}