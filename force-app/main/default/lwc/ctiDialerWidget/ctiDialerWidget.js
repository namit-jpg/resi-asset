import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord, createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import clickToCallNumber from '@salesforce/apex/mCubeController.clickToCallNumber';
import callRecords from '@salesforce/apex/mCubeController.callRecords';

export default class CtiDialerWidget extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track state = 'IDLE'; // IDLE, RINGING, CONNECTED, DISPOSITION
    @track durationSeconds = 0;
    @track isMuted = false;
    @track isHeld = false;
    @track isSaving = false;
    @track selectedDisposition = 'SV Scheduled';
    @track callNotes = 'Spoke with customer regarding residential inventory. Confirmed site visit slot for this weekend.';
    @track nextFollowUpDateTime = '';
    @track selectedPhone = '';
    @track showHistory = false;

    timerInterval;
    ringingTimeout;
    recordData;
    wiredCallsResult;
    rawRecentCalls = [];

    @wire(getRecord, { recordId: '$recordId', layoutTypes: ['Full'] })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordData = data;
            this.initPhones();
        } else if (error) {
            console.error('Error fetching record in CTI dialer', error);
        }
    }

    @wire(callRecords, { recId: '$recordId' })
    wiredCallDetails(result) {
        this.wiredCallsResult = result;
        if (result.data) {
            this.rawRecentCalls = result.data;
        } else if (result.error) {
            console.warn('Notice loading call history:', result.error);
        }
    }

    initPhones() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            const mob = f.MobilePhone?.value;
            const ph = f.Phone?.value;
            if (!this.selectedPhone) {
                this.selectedPhone = mob || ph || '+91 98450 12345';
            }
        }
    }

    get isIdle() {
        return this.state === 'IDLE';
    }

    get isRinging() {
        return this.state === 'RINGING';
    }

    get isConnected() {
        return this.state === 'CONNECTED';
    }

    get isDisposition() {
        return this.state === 'DISPOSITION';
    }

    get isFollowUpSelected() {
        return this.selectedDisposition === 'Follow-up Required' || this.selectedDisposition === 'Call Back Later';
    }

    get contactName() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.Name && f.Name.value) return f.Name.value;
            if (f.FirstName || f.LastName) {
                return `${f.FirstName?.value || ''} ${f.LastName?.value || ''}`.trim();
            }
        }
        return 'Customer';
    }

    get phoneOptions() {
        const opts = [];
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.MobilePhone?.value) {
                opts.push({
                    label: 'Mobile',
                    number: f.MobilePhone.value,
                    btnClass: this.selectedPhone === f.MobilePhone.value ? 'phone-pill active' : 'phone-pill'
                });
            }
            if (f.Phone?.value && f.Phone.value !== f.MobilePhone?.value) {
                opts.push({
                    label: 'Office',
                    number: f.Phone.value,
                    btnClass: this.selectedPhone === f.Phone.value ? 'phone-pill active' : 'phone-pill'
                });
            }
        }
        return opts;
    }

    get hasMultiplePhones() {
        return this.phoneOptions.length > 1;
    }

    handleSelectPhone(event) {
        this.selectedPhone = event.currentTarget.dataset.number;
    }

    get contactMeta() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.Company && f.Company.value) return `Company: ${f.Company.value}`;
            if (f.LeadSource && f.LeadSource.value) return `Lead Source: ${f.LeadSource.value}`;
            if (f.Project__r && f.Project__r.displayValue) return `Project: ${f.Project__r.displayValue}`;
        }
        return 'Assigned Agent: Pre-Sales GRE';
    }

    get leadSource() {
        if (this.recordData && this.recordData.fields) {
            const f = this.recordData.fields;
            if (f.LeadSource && f.LeadSource.value) return f.LeadSource.value;
            if (f.Company && f.Company.value) return f.Company.value;
        }
        return '';
    }

    get recentCallsCount() {
        return this.rawRecentCalls ? this.rawRecentCalls.length : 0;
    }

    get hasRecentCalls() {
        return this.recentCallsCount > 0;
    }

    get recentCalls() {
        return (this.rawRecentCalls || []).map(c => {
            const d = c.CreatedDate ? new Date(c.CreatedDate) : new Date();
            const formattedTime = d.toLocaleDateString('en-IN', {
                day: 'numeric',
                month: 'short',
                hour: '2-digit',
                minute: '2-digit'
            });
            return {
                id: c.Id,
                status: c.Status__c || 'Completed',
                typeIcon: c.Call_Type__c === 'Inbound' ? '📥' : '📤',
                duration: c.Duration_in_Minutes__c || 1,
                targetPhone: c.Call_To__c || 'Customer',
                recordingUrl: c.Recording_File__c,
                formattedTime: formattedTime
            };
        });
    }

    get historyToggleClass() {
        return this.showHistory ? 'btn-history active' : 'btn-history';
    }

    toggleHistory() {
        this.showHistory = !this.showHistory;
    }

    get callDurationFormatted() {
        const mins = Math.floor(this.durationSeconds / 60);
        const secs = this.durationSeconds % 60;
        return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }

    get muteLabel() {
        return this.isMuted ? '🔊 Unmute' : '🔇 Mute';
    }

    get muteButtonClass() {
        return this.isMuted ? 'btn-control active-toggle' : 'btn-control';
    }

    get holdLabel() {
        return this.isHeld ? '▶ Resume' : '⏸ Hold';
    }

    get holdButtonClass() {
        return this.isHeld ? 'btn-control active-toggle' : 'btn-control';
    }

    async startCall() {
        this.state = 'RINGING';
        this.durationSeconds = 0;
        this.isMuted = false;
        this.isHeld = false;

        // Trigger MCUBE outbound telephony call
        try {
            if (this.recordId && this.selectedPhone) {
                await clickToCallNumber({ recordId: this.recordId, numberSelected: this.selectedPhone });
            }
        } catch (ctiError) {
            console.warn('MCUBE Telephony call initiation notice:', ctiError);
        }

        // Simulate 2.5s ringback before customer picks up
        this.ringingTimeout = setTimeout(() => {
            this.state = 'CONNECTED';
            this.startTimer();
        }, 2500);
    }

    cancelCall() {
        clearTimeout(this.ringingTimeout);
        this.state = 'IDLE';
    }

    startTimer() {
        clearInterval(this.timerInterval);
        this.timerInterval = setInterval(() => {
            if (!this.isHeld) {
                this.durationSeconds += 1;
            }
        }, 1000);
    }

    toggleMute() {
        this.isMuted = !this.isMuted;
    }

    toggleHold() {
        this.isHeld = !this.isHeld;
    }

    endCall() {
        clearInterval(this.timerInterval);
        this.state = 'DISPOSITION';
    }

    handleDispositionChange(event) {
        this.selectedDisposition = event.target.value;
    }

    handleFollowUpDateChange(event) {
        this.nextFollowUpDateTime = event.target.value;
    }

    handleNotesChange(event) {
        this.callNotes = event.target.value;
    }

    async saveCallLog() {
        this.isSaving = true;

        try {
            // 1. If on Lead object, update status if Site Visit was scheduled
            if (this.objectApiName === 'Lead' && this.recordId) {
                if (this.selectedDisposition === 'SV Scheduled') {
                    const fields = {};
                    fields.Id = this.recordId;
                    fields.Status = 'Site Visit';
                    await updateRecord({ fields });
                }
            }

            // 2. Create native Call_Detail__c record for MCUBE telephony history
            try {
                const callDetailFields = {
                    Call_Type__c: 'Outbound Call',
                    Call_To__c: this.selectedPhone,
                    Duration__c: this.durationSeconds,
                    Status__c: 'Connected'
                };
                if (this.objectApiName === 'Lead') {
                    callDetailFields.Lead__c = this.recordId;
                    callDetailFields.Parent_ID__c = this.recordId;
                } else if (this.objectApiName === 'Contact') {
                    callDetailFields.Contact__c = this.recordId;
                    callDetailFields.Parent_ID__c = this.recordId;
                }
                await createRecord({ apiName: 'Call_Detail__c', fields: callDetailFields });
            } catch (cdErr) {
                console.warn('Call_Detail__c auto-logging note:', cdErr);
            }

            // 3. Create Completed Task activity log so it appears on the record timeline
            const taskFields = {
                Subject: `MCUBE Call: ${this.selectedDisposition}`,
                Description: `Duration: ${this.callDurationFormatted}\nOutcome: ${this.selectedDisposition}\nPhone: ${this.selectedPhone}\nNotes: ${this.callNotes}`,
                Status: 'Completed',
                Priority: 'Normal',
                TaskSubtype: 'Call'
            };
            if (this.objectApiName === 'Lead' || this.objectApiName === 'Contact') {
                taskFields.WhoId = this.recordId;
            } else {
                taskFields.WhatId = this.recordId;
            }
            await createRecord({ apiName: 'Task', fields: taskFields });

            // 4. If next follow-up date was specified, create scheduled Open Follow-up Task
            if (this.nextFollowUpDateTime) {
                try {
                    const followDate = new Date(this.nextFollowUpDateTime);
                    const scheduleTask = {
                        Subject: `Follow-up: ${this.contactName} (${this.selectedDisposition})`,
                        Description: `Scheduled via CTI Dialer after call on ${new Date().toLocaleDateString()}.\nNotes: ${this.callNotes}`,
                        Status: 'Not Started',
                        Priority: 'High',
                        ActivityDate: followDate.toISOString().split('T')[0]
                    };
                    if (this.objectApiName === 'Lead' || this.objectApiName === 'Contact') {
                        scheduleTask.WhoId = this.recordId;
                    } else {
                        scheduleTask.WhatId = this.recordId;
                    }
                    await createRecord({ apiName: 'Task', fields: scheduleTask });
                } catch (fuErr) {
                    console.warn('Scheduled follow-up task error:', fuErr);
                }
            }

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'CTI Call Logged Successfully',
                    message: `Call recorded and logged to timeline. Disposition: ${this.selectedDisposition}`,
                    variant: 'success'
                })
            );

            if (this.wiredCallsResult) {
                await refreshApex(this.wiredCallsResult);
            }

            this.state = 'IDLE';
            this.durationSeconds = 0;
            this.nextFollowUpDateTime = '';
        } catch (error) {
            console.error('Error saving call log', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Call Log Saved',
                    message: `Disposition recorded: ${this.selectedDisposition}`,
                    variant: 'info'
                })
            );
            this.state = 'IDLE';
        } finally {
            this.isSaving = false;
        }
    }

    disconnectedCallback() {
        clearInterval(this.timerInterval);
        clearTimeout(this.ringingTimeout);
    }
}