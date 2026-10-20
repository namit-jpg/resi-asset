import { LightningElement, api } from 'lwc';
import recordPayment from '@salesforce/apex/BookingFormSiteController.recordPayment';
import { PAY_METHODS, formatInr, formatDateTime } from 'c/bcfUtils';

const BANKS = ['HDFC Bank', 'ICICI Bank', 'State Bank of India', 'Axis Bank', 'Kotak Mahindra Bank'];
const WALLETS = ['Paytm', 'PhonePe', 'Amazon Pay', 'Mobikwik'];

/** Step 4: token advance through the payment gateway (test checkout until the real gateway is connected). */
export default class BcfPayment extends LightningElement {
    @api context;
    @api payment;
    @api errors;
    @api token;

    method = 'UPI';
    checkoutOpen = false;
    processing = false;
    failure;

    get payable() {
        return formatInr(this.payment?.payable ?? this.context?.tokenAmount);
    }

    get hasAmount() {
        return Number(this.payment?.payable ?? this.context?.tokenAmount) > 0;
    }

    get noAmount() {
        return !this.hasAmount;
    }

    get isPaid() {
        return this.payment?.status === 'Paid';
    }

    get statusBadge() {
        if (this.isPaid) return { label: 'Received', className: 'badge badge_ok' };
        if (this.processing) return { label: 'Processing', className: 'badge badge_warn' };
        if (this.payment?.status === 'Failed' || this.failure) return { label: 'Failed', className: 'badge badge_bad' };
        return { label: 'Pending', className: 'badge badge_warn' };
    }

    get methods() {
        return PAY_METHODS.map((m) => ({
            ...m,
            className: `seg${m.id === this.method ? ' seg_active' : ''}`,
            pressed: m.id === this.method ? 'true' : 'false'
        }));
    }

    get methodLabel() {
        return PAY_METHODS.find((m) => m.id === this.method)?.label;
    }

    get paidMethodLabel() {
        return PAY_METHODS.find((m) => m.id === this.payment?.method)?.label || this.payment?.method;
    }

    get paidAt() {
        return formatDateTime(this.payment?.paidAt);
    }

    get paidAmount() {
        return formatInr(this.payment?.amount);
    }

    get stepError() {
        return this.errors?.['payment.status'];
    }

    get isUpi() {
        return this.method === 'UPI';
    }
    get isCard() {
        return this.method === 'CARD';
    }
    get isNetbanking() {
        return this.method === 'NETBANKING';
    }
    get isWallet() {
        return this.method === 'WALLET';
    }

    get bankOptions() {
        return BANKS;
    }

    get walletOptions() {
        return WALLETS;
    }

    get payDisabled() {
        return this.processing || !this.hasAmount;
    }

    get payLabel() {
        return this.processing ? 'Processing…' : 'Pay booking amount →';
    }

    handleMethod(event) {
        this.method = event.currentTarget.dataset.id;
    }

    openCheckout() {
        this.failure = undefined;
        this.checkoutOpen = true;
    }

    closeCheckout() {
        if (!this.processing) this.checkoutOpen = false;
    }

    stop(event) {
        event.stopPropagation();
    }

    pay() {
        this.complete('success');
    }

    cancel() {
        this.complete('cancelled');
    }

    simulateFailure() {
        this.complete('failed');
    }

    async complete(outcome) {
        this.processing = true;
        try {
            const payment = await recordPayment({ token: this.token, method: this.method, outcome });
            this.dispatchEvent(new CustomEvent('formaction', { bubbles: true, composed: true, detail: { name: 'payment', detail: { payment } } }));
            this.checkoutOpen = false;
            if (outcome === 'success') {
                this.toast('Payment successful', `${formatInr(payment.amount)} received. Payment ID ${payment.paymentId}.`, 'ok');
            } else if (outcome === 'failed') {
                this.failure = 'The bank declined the payment. No money was taken. Try again or choose another method.';
            } else {
                this.failure = 'Payment cancelled. Your booking is still pending.';
            }
        } catch (e) {
            this.failure = e?.body?.message || e?.message || 'The payment could not be completed.';
            this.checkoutOpen = false;
        } finally {
            this.processing = false;
        }
    }

    toast(title, message, kind) {
        this.dispatchEvent(new CustomEvent('formaction', { bubbles: true, composed: true, detail: { name: 'toast', detail: { title, message, kind } } }));
    }
}