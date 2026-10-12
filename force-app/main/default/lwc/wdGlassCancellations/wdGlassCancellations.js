import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCancellationApprovals from '@salesforce/apex/WdGlassRecordController.getCancellationApprovals';
import { formatDate, statusTone } from 'c/wdGlassFormat';

/** Booking cancellation approval requests (standard approval history) for a booking, opportunity or account. */
export default class WdGlassCancellations extends NavigationMixin(LightningElement) {
    @api recordId;
    /** Show the booking name as the row title (off on a booking's own page). */
    @api showBooking = false;

    raw = [];
    loaded = false;

    async connectedCallback() {
        try {
            this.raw = (await getCancellationApprovals({ recordId: this.recordId })) || [];
        } catch (e) {
            this.raw = [];
        }
        this.loaded = true;
    }

    get hasItems() {
        return this.raw.length > 0;
    }

    get count() {
        return this.raw.length;
    }

    get items() {
        return this.raw.map((c) => {
            const status = c.status === 'Removed' ? 'Recalled' : c.status;
            const who = c.status === 'Pending' ? `Waiting on ${c.actor || 'approver'}` : c.actor ? `by ${c.actor}` : '';
            return {
                key: c.id,
                bookingId: c.bookingId,
                title: this.showBooking ? c.bookingName : `Requested by ${c.submittedBy || '—'}`,
                meta: [this.showBooking && c.submittedBy ? `Requested by ${c.submittedBy}` : null, who].filter(Boolean).join(' · '),
                comments: c.comments,
                status,
                statusClass: `chip chip_${statusTone(status)}`,
                when: formatDate(c.completedAt || c.submittedAt)
            };
        });
    }

    handleOpen(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, actionName: 'view' }
        });
    }
}