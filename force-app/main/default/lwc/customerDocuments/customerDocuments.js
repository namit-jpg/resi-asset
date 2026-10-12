import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getOverview from '@salesforce/apex/CustomerDocumentController.getOverview';
import saveToFiles from '@salesforce/apex/CustomerDocumentController.saveToFiles';

/** Booking quick action: preview the Welcome, Allotment and Car Parking letters, open them as PDF or file them on the booking. */
export default class CustomerDocuments extends LightningElement {
    _recordId;
    overview;
    error;
    loading = true;
    saving = false;
    selected = 'welcome';

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
            this.load();
        }
    }

    async load() {
        this.loading = true;
        this.error = undefined;
        try {
            this.overview = await getOverview({ bookingId: this._recordId });
        } catch (e) {
            this.error = message(e);
        } finally {
            this.loading = false;
        }
    }

    get docs() {
        return (this.overview?.documents || []).map((d) => ({
            ...d,
            variant: d.value === this.selected ? 'brand' : 'neutral'
        }));
    }

    get current() {
        return this.overview?.documents.find((d) => d.value === this.selected);
    }

    get subtitle() {
        const o = this.overview;
        return o ? [o.bookingName, o.customerName].filter(Boolean).join(' · ') : '';
    }

    get pdfUrl() {
        return `/apex/CustomerDocumentPdf?id=${this._recordId}&doc=${this.selected}`;
    }

    get actionsDisabled() {
        return this.saving || !this.current?.available;
    }

    handleSelect(event) {
        this.selected = event.currentTarget.dataset.value;
    }

    handleOpen() {
        window.open(this.pdfUrl, '_blank');
    }

    async handleSave() {
        this.saving = true;
        try {
            await saveToFiles({ bookingId: this._recordId, doc: this.selected });
            await notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: `${this.current.label} saved`,
                    message: 'The PDF is in the booking’s Files.',
                    variant: 'success'
                })
            );
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Could not save the document', message: message(e), variant: 'error' }));
        } finally {
            this.saving = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}

function message(e) {
    return e?.body?.message || e?.message || 'Something went wrong.';
}