import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHome from '@salesforce/apex/WdGlassController.getHome';
import { formatTime } from 'c/wdGlassFormat';

export default class WdGlassHome extends NavigationMixin(LightningElement) {
    @api eyebrow = 'Nikoo Homes · Residential sales';

    data;
    loading = true;
    error;
    refreshedAt;

    connectedCallback() {
        this.load();
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.data = await getHome();
            this.refreshedAt = new Date();
        } catch (e) {
            this.error = e?.body?.message || e?.message || 'Could not load the dashboard.';
        } finally {
            this.loading = false;
        }
    }

    get greeting() {
        const hour = new Date().getHours();
        let part = 'evening';
        if (hour < 12) {
            part = 'morning';
        } else if (hour < 17) {
            part = 'afternoon';
        }
        const name = this.data?.firstName;
        return name ? `Good ${part}, ${name}` : `Good ${part}`;
    }

    get subtitle() {
        if (!this.data) {
            return 'Loading…';
        }
        const facts = [...(this.data.facts || [])];
        if (this.refreshedAt) {
            facts.push(`refreshed ${formatTime(this.refreshedAt)}`);
        }
        return facts.join(' · ');
    }

    get kpis() {
        return this.data?.kpis || [];
    }

    get columns() {
        return this.data?.columns || [];
    }

    get rows() {
        return this.data?.rows || [];
    }

    get bookingCount() {
        const n = this.rows.length;
        return `${n} latest`;
    }

    get inventoryBars() {
        const bars = this.data?.inventory || [];
        const max = Math.max(1, ...bars.map((b) => b.total));
        return bars.map((b) => ({
            label: b.label,
            title: `${b.primary} available, ${b.secondary} booked`,
            caption: `${b.primary} of ${b.total} open`,
            primaryStyle: `width:${(b.primary / max) * 100}%`,
            secondaryStyle: `width:${(b.secondary / max) * 100}%`
        }));
    }

    get funnelBars() {
        const bars = this.data?.funnel || [];
        const max = Math.max(1, ...bars.map((b) => b.primary));
        return bars.map((b) => ({
            label: b.label,
            caption: `${b.primary}`,
            primaryStyle: `width:${Math.max(b.primary ? 3 : 0, (b.primary / max) * 100)}%`
        }));
    }

    handleRefresh() {
        this.load();
    }

    handleNewLead() {
        const state = this.data?.leadRecordTypeId ? { recordTypeId: this.data.leadRecordTypeId } : {};
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Lead', actionName: 'new' },
            state
        });
    }

    handleOpenTab(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: event.currentTarget.dataset.tab }
        });
    }
}