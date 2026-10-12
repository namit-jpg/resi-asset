// roundRobinAssignButton.js
import { LightningElement, api } from 'lwc';
import assignLead from '@salesforce/apex/RoundRobinActionController.assignLeadViaRoundRobin';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class RoundRobinAssignButton extends LightningElement {
    @api recordId;

    @api invoke() {
        if (!this.recordId) {
            this.showToast('Error', 'Lead ID not found.', 'error');
            this.dispatchEvent(new CloseActionScreenEvent());
            return;
        }

        assignLead({ leadId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Lead successfully assigned via Round Robin.', 'success');
            })
            .catch(error => {
                let message = 'Unknown error';
                
                // Safely get Apex exception message
                if (error && error.body) {
                    if (typeof error.body.message === 'string' && error.body.message.trim() !== '') {
                        message = error.body.message; // AuraHandledException text
                    } else if (Array.isArray(error.body)) {
                        // Handle multiple error objects
                        message = error.body.map(e => e.message).join(', ');
                    }
                } else if (error && error.message) {
                    message = error.message;
                }

                this.showToast('Error assigning lead', message, 'error');
            })
            .finally(() => {
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}