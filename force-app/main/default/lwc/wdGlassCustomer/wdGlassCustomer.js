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
    /** summary (alerts + KPI cards) | holdings (units owned) | sidebar (context stack) */
    @api mode = 'summary';

    data;
    error;

    @wire(getCustomer, { accountId: '$recordId' })
    wired({ data, error }) {
        if (data) {
            this.data = data;
            this.error = undefined;
            this.dispatchEvent(
                new CustomEvent('customerloaded', {
                    bubbles: true,
                    composed: true,
                    detail: {
                        holdingsCount: data.holdings?.length || 0,
                        duesCount: data.dues?.length || 0,
                        overdueCount: data.overdueCount || 0,
                        receiptsCount: data.receipts?.length || 0,
                        opportunitiesCount: data.opportunities?.length || 0,
                        siteVisitsCount: data.siteVisits?.length || 0,
                        casesCount: data.cases?.length || 0,
                        isBuyer: data.isBuyer
                    }
                })
            );
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

    get isFinancials() {
        return this.mode === 'financials';
    }

    get isPipeline() {
        return this.mode === 'pipeline';
    }

    get isSidebar() {
        return this.mode === 'sidebar';
    }

    get isSidebarProfile() {
        return this.mode === 'sidebar-profile' || this.mode === 'sidebar';
    }

    get isSidebarSupport() {
        return this.mode === 'sidebar-support' || this.mode === 'sidebar';
    }

    get loaded() {
        return !!this.data;
    }

    // ---------- summary ----------

    get alerts() {
        return (this.data?.alerts || []).map((a, i) => ({
            key: `a${i}`,
            message: a.message,
            className: `wd-glass alert alert_${a.tone}`
        }));
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

    get dues() {
        return (this.data?.dues || []).map((i) => {
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

    get receipts() {
        return this.listOf(this.data?.receipts, { amount: true });
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

    get cases() {
        return this.listOf(this.data?.cases, { relative: true });
    }

    get bookingContacts() {
        return this.listOf(this.data?.bookingContacts);
    }

    get hasBookingContacts() {
        return this.bookingContacts.length > 0;
    }

    get hasDues() {
        return this.dues.length > 0;
    }

    get hasReceipts() {
        return this.receipts.length > 0;
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

    get hasCases() {
        return this.cases.length > 0;
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

    handleNewSiteVisit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Site_Visit__c', actionName: 'new' }
        });
    }
}