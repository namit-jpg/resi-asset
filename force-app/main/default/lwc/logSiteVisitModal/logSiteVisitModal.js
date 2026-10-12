import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import Id from '@salesforce/user/Id';

import getLeadDetails from '@salesforce/apex/SiteVisitController.getLeadDetails';
import getProjects from '@salesforce/apex/SiteVisitController.getProjects';
import getUnitsForProject from '@salesforce/apex/SiteVisitController.getUnitsForProject';
import generateOtp from '@salesforce/apex/SiteVisitController.generateOtp';
import logSiteVisit from '@salesforce/apex/SiteVisitController.logSiteVisit';
import logSiteVisitWithDetails from '@salesforce/apex/SiteVisitController.logSiteVisitWithDetails';

export default class LogSiteVisitModal extends NavigationMixin(LightningElement) {
    @api recordId;

    // View state
    @track isLoading = true;
    @track isModalOpen = false;
    @track isSubmitting = false;
    @track currentStep = 1;

    // Lead data
    @track leadData = null;
    @track hasSiteVisit = false;
    @track siteVisitCount = 0;
    @track leadName = '';
    @track leadCompany = '';
    @track recentVisits = [];

    // Step 1: Project & Unit Selection
    @track projectOptions = [];
    @track selectedProjectId = '';
    @track unitOptions = [];
    @track allUnits = [];
    @track selectedUnitId = '';
    @track selectedUnitInfo = null;
    @track visitDateTime = '';
    @track currentUserId = Id;
    @track currentUserName = 'Current Sales Executive';

    // Step 2: OTP Verification
    @track visitorMobile = '';
    @track generatedOtpCode = '';
    @track enteredOtp = '';
    @track otpSent = false;
    @track otpMessage = '';
    @track isSendingOtp = false;

    // Step 3: Customer Feedback
    @track visitedShowFlat = 'Yes';
    @track likedProduct = 'Project';
    @track visitedWithFamily = 'Yes';
    @track overallExperience = 'Superior';
    @track customerQuestions = '';

    // Step 3: Executive Feedback
    @track selectedRating = 'Hot';
    @track selectedInterestLevel = 'High';
    @track selectedNextFollowUp = 'Week';
    @track salesManagerRemarks = '';
    @track feedbackNotes = '';
    quickTags = [
        'Loved Balcony View',
        'Ready for Booking Form',
        'Negotiating on Floor Rise',
        'Prefers East Facing',
        'Family Approved',
        'Home Loan Sanctioned'
    ];

    connectedCallback() {
        // Default visit time to current local time in ISO format
        const now = new Date();
        now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
        this.visitDateTime = now.toISOString().slice(0, 16);
        this.loadLeadData();
        this.loadProjectsList();
    }

    // Support Quick Action invocation
    @api invoke() {
        this.handleOpenModal();
    }

    // Refresh lead data whenever recordId changes
    async loadLeadData() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            const data = await getLeadDetails({ leadId: this.recordId });
            this.leadData = data;
            this.hasSiteVisit = data.hasSiteVisit;
            this.siteVisitCount = data.siteVisitCount || 0;
            this.leadName = data.name || 'Valued Visitor';
            this.leadCompany = data.company || 'Prospective Buyer';
            this.visitorMobile = data.mobilePhone || data.phone || '';

            // Pre-select project if enquired
            if (data.projectEnquiredId && !this.selectedProjectId) {
                this.selectedProjectId = data.projectEnquiredId;
                this.loadUnitsForProject(this.selectedProjectId);
            }

            // Format recent visits
            if (data.recentVisits && data.recentVisits.length > 0) {
                this.recentVisits = data.recentVisits.map(v => {
                    let ratingClass = 'rating-badge ';
                    if (v.rating === 'Hot') ratingClass += 'badge-hot';
                    else if (v.rating === 'Warm') ratingClass += 'badge-warm';
                    else ratingClass += 'badge-cold';

                    return {
                        ...v,
                        ratingBadgeClass: ratingClass
                    };
                });
            } else {
                this.recentVisits = [];
            }
        } catch (error) {
            console.error('Error loading lead details:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadProjectsList() {
        try {
            const projects = await getProjects();
            this.projectOptions = projects.map(p => ({
                label: p.Name + (p.City__c ? ` (${p.City__c})` : ''),
                value: p.Id
            }));

            // If selectedProjectId already set from lead, load units
            if (this.selectedProjectId) {
                this.loadUnitsForProject(this.selectedProjectId);
            }
        } catch (error) {
            console.error('Error fetching projects:', error);
        }
    }

    async loadUnitsForProject(projectId) {
        if (!projectId) {
            this.unitOptions = [];
            this.allUnits = [];
            return;
        }
        try {
            const units = await getUnitsForProject({ projectId });
            this.allUnits = units;
            this.unitOptions = [
                { label: '-- General Site Visit (No Unit Tagged) --', value: '' },
                ...units.map(u => ({
                    label: u.displayName + (u.basePrice ? ` - ₹${this.formatPriceShort(u.basePrice)}` : ''),
                    value: u.id
                }))
            ];
        } catch (error) {
            console.error('Error fetching units:', error);
            this.unitOptions = [];
        }
    }

    // Modal Visibility Handlers
    handleOpenModal() {
        this.currentStep = 1;
        this.enteredOtp = '';
        this.isModalOpen = true;

        if (this.selectedProjectId) {
            this.loadUnitsForProject(this.selectedProjectId);
        }
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    // Step 1: Project & Unit change handlers
    handleProjectChange(event) {
        this.selectedProjectId = event.detail.value;
        this.selectedUnitId = '';
        this.selectedUnitInfo = null;
        this.loadUnitsForProject(this.selectedProjectId);
    }

    handleUnitChange(event) {
        this.selectedUnitId = event.detail.value;
        if (this.selectedUnitId) {
            this.selectedUnitInfo = this.allUnits.find(u => u.id === this.selectedUnitId) || null;
        } else {
            this.selectedUnitInfo = null;
        }
    }

    handleDateTimeChange(event) {
        this.visitDateTime = event.detail.value;
    }

    // Step 2: OTP Verification Handlers
    handleMobileChange(event) {
        this.visitorMobile = event.detail.value;
    }

    async handleSendOtp() {
        if (!this.visitorMobile) {
            this.showToast('Validation Error', 'Please enter a valid mobile number to receive OTP.', 'warning');
            return;
        }

        this.isSendingOtp = true;
        try {
            const res = await generateOtp({ mobileNumber: this.visitorMobile });
            this.generatedOtpCode = res.otpCode;
            this.otpMessage = res.message;
            this.otpSent = true;
            this.showToast('SMS Dispatched', `Verification OTP sent to ${res.maskedMobile}`, 'info');
        } catch (error) {
            this.showToast('Error', 'Failed to dispatch OTP SMS: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isSendingOtp = false;
        }
    }

    handleAutoFillOtp() {
        if (this.generatedOtpCode) {
            this.enteredOtp = this.generatedOtpCode;
        }
    }

    handleOtpChange(event) {
        this.enteredOtp = event.detail.value;
    }

    // Step 3: Rating & Feedback Handlers
    handleSelectHot() { this.selectedRating = 'Hot'; }
    handleSelectWarm() { this.selectedRating = 'Warm'; }
    handleSelectCold() { this.selectedRating = 'Cold'; }

    handleTagClick(event) {
        const tag = event.target.dataset.tag;
        if (this.feedbackNotes) {
            this.feedbackNotes = `${this.feedbackNotes} • ${tag}`;
        } else {
            this.feedbackNotes = tag;
        }
    }

    handleFeedbackChange(event) {
        this.feedbackNotes = event.detail.value;
    }

    // Multi-Step Navigation
    handleNextStep() {
        if (this.currentStep === 1) {
            if (!this.selectedProjectId) {
                this.showToast('Selection Required', 'Please select a Project before proceeding.', 'warning');
                return;
            }
            this.currentStep = 2;
        } else if (this.currentStep === 2) {
            if (!this.isOtpValid) {
                this.showToast('OTP Required', 'Please enter the valid 6-digit OTP code to verify visitor identity.', 'warning');
                return;
            }
            this.currentStep = 3;
        }
    }

    handlePrevStep() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
        }
    }

    // Feedback event handlers
    handleSetShowFlat(event) { this.visitedShowFlat = event.currentTarget.dataset.val; }
    handleSetLikedProduct(event) { this.likedProduct = event.currentTarget.dataset.val; }
    handleSetFamily(event) { this.visitedWithFamily = event.currentTarget.dataset.val; }
    handleSetExperience(event) { this.overallExperience = event.currentTarget.dataset.val; }
    handleCustomerQuestionsChange(event) { this.customerQuestions = event.target.value; }

    handleSetInterest(event) { this.selectedInterestLevel = event.currentTarget.dataset.val; }
    handleSetFollowUp(event) { this.selectedNextFollowUp = event.currentTarget.dataset.val; }
    handleRemarksChange(event) { this.salesManagerRemarks = event.target.value; }

    // Final Submission
    async handleSubmitVisit() {
        this.isSubmitting = true;
        try {
            const result = await logSiteVisitWithDetails({
                leadId: this.recordId,
                projectId: this.selectedProjectId,
                unitId: this.selectedUnitId ? this.selectedUnitId : null,
                visitorMobile: this.visitorMobile,
                otpCode: this.enteredOtp,
                rating: this.selectedRating,
                feedback: this.feedbackNotes,
                visitDateTime: this.visitDateTime ? new Date(this.visitDateTime).toISOString() : null,
                visitedShowFlat: this.visitedShowFlat,
                likedProduct: this.likedProduct,
                visitedWithFamily: this.visitedWithFamily,
                overallExperience: this.overallExperience,
                customerQuestions: this.customerQuestions,
                interestLevel: this.selectedInterestLevel,
                nextFollowUp: this.selectedNextFollowUp,
                executiveRemarks: this.salesManagerRemarks
            });

            this.showToast('Site Visit Verified!', result.message, 'success');
            this.isModalOpen = false;

            // 1. Immediately refresh local component data & visit count
            await this.loadLeadData();

            // 2. Notify Lightning Data Service to refresh standard Lead record layout & fields
            try {
                await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            } catch (ldsErr) {
                console.warn('LDS notification notice:', ldsErr);
            }

        } catch (error) {
            this.showToast('Error Logging Site Visit', error.body?.message || error.message, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    handleNavigateToSiteVisit(event) {
        event.preventDefault();
        event.stopPropagation();
        const visitId = event.currentTarget.dataset.id;
        if (visitId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: visitId,
                    objectApiName: 'Site_Visit__c',
                    actionName: 'view'
                }
            });
        }
    }

    // Computed Getters
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }

    get step1Class() {
        return `step-item ${this.currentStep >= 1 ? 'step-active' : ''} ${this.currentStep > 1 ? 'step-completed' : ''}`;
    }
    get step2Class() {
        return `step-item ${this.currentStep >= 2 ? 'step-active' : ''} ${this.currentStep > 2 ? 'step-completed' : ''}`;
    }
    get step3Class() {
        return `step-item ${this.currentStep === 3 ? 'step-active' : ''}`;
    }

    get isNextDisabled() {
        if (this.currentStep === 1) return !this.selectedProjectId;
        if (this.currentStep === 2) return !this.isOtpValid;
        return false;
    }

    get isUnitSelectDisabled() {
        return !this.selectedProjectId || this.unitOptions.length === 0;
    }

    get unitPlaceholder() {
        return this.selectedProjectId ? 'Select specific unit (optional)...' : 'Choose a project first...';
    }

    get selectedProjectName() {
        const found = this.projectOptions.find(p => p.value === this.selectedProjectId);
        return found ? found.label : 'None';
    }

    get selectedUnitDisplayName() {
        return this.selectedUnitInfo ? this.selectedUnitInfo.displayName : 'General Visit';
    }

    get selectedUnitFormattedPrice() {
        if (!this.selectedUnitInfo || !this.selectedUnitInfo.basePrice) return '';
        return `₹${this.formatPriceShort(this.selectedUnitInfo.basePrice)}`;
    }

    get sendOtpButtonLabel() {
        return this.otpSent ? 'Resend OTP' : 'Send SMS OTP';
    }

    get isSendOtpDisabled() {
        return !this.visitorMobile || this.isSendingOtp;
    }

    get isOtpValid() {
        return this.otpSent && this.enteredOtp && this.enteredOtp.trim() === this.generatedOtpCode;
    }

    get hotRatingClass() {
        return `rating-card ${this.selectedRating === 'Hot' ? 'rating-selected rating-hot' : ''}`;
    }
    get warmRatingClass() {
        return `rating-card ${this.selectedRating === 'Warm' ? 'rating-selected rating-warm' : ''}`;
    }
    get coldRatingClass() {
        return `rating-card ${this.selectedRating === 'Cold' ? 'rating-selected rating-cold' : ''}`;
    }

    get isShowFlatYes() { return this.visitedShowFlat === 'Yes' ? 'feedback-chip active' : 'feedback-chip'; }
    get isShowFlatNo() { return this.visitedShowFlat === 'No' ? 'feedback-chip active' : 'feedback-chip'; }

    get isLikedProject() { return this.likedProduct === 'Project' ? 'feedback-chip active' : 'feedback-chip'; }
    get isLikedProduct() { return this.likedProduct === 'Product' ? 'feedback-chip active' : 'feedback-chip'; }

    get isFamilyYes() { return this.visitedWithFamily === 'Yes' ? 'feedback-chip active' : 'feedback-chip'; }
    get isFamilyNo() { return this.visitedWithFamily === 'No' ? 'feedback-chip active' : 'feedback-chip'; }

    get isExpSuperior() { return this.overallExperience === 'Superior' ? 'feedback-chip active' : 'feedback-chip'; }
    get isExpGood() { return this.overallExperience === 'Good' ? 'feedback-chip active' : 'feedback-chip'; }
    get isExpAverage() { return this.overallExperience === 'Average' ? 'feedback-chip active' : 'feedback-chip'; }

    get isInterestHigh() { return this.selectedInterestLevel === 'High' ? 'feedback-chip active' : 'feedback-chip'; }
    get isInterestMedium() { return this.selectedInterestLevel === 'Medium' ? 'feedback-chip active' : 'feedback-chip'; }
    get isInterestLow() { return this.selectedInterestLevel === 'Low' ? 'feedback-chip active' : 'feedback-chip'; }

    get isFollowUpWeek() { return this.selectedNextFollowUp === 'Week' ? 'feedback-chip active' : 'feedback-chip'; }
    get isFollowUpFortnight() { return this.selectedNextFollowUp === 'Fortnight' ? 'feedback-chip active' : 'feedback-chip'; }

    get hasRecentVisits() {
        return this.recentVisits && this.recentVisits.length > 0;
    }

    // Helper formatters
    formatPriceShort(val) {
        if (!val) return '0';
        const num = Number(val);
        if (num >= 10000000) {
            return (num / 10000000).toFixed(2) + ' Cr';
        } else if (num >= 100000) {
            return (num / 100000).toFixed(2) + ' L';
        }
        return num.toLocaleString('en-IN');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}