import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class EoiCloseVoucher extends LightningElement {
    @api recordId;

    handleDone() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}