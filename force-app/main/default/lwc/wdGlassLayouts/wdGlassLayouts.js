// Generated from the Nikoo Homes Dynamic Forms record pages (RES_*_Record_Page) on 29 Sep 2026.
// Section order, labels and fields mirror those pages; edit here to change what the glass record page shows.
export const SECTIONS = {
    "Account": [
        {
            "label": "About",
            "columns": 2,
            "fields": [
                "Name",
                "CP_Approval_Status__c",
                "PersonBirthdate",
                "Website",
                "ParentId",
                "CompanyName__c",
                "Language__c",
                "Company_Code__c",
                "RERA_VALID_FROM__c",
                "GST_No__c",
                "RERA_VALID_TO__c",
                "Aadhar_Number__c",
                "RERA_Number__c",
                "PAN_Number__c",
                "Distribution_Channel__c",
                "Sales_Org__c",
                "Division__c"
            ]
        },
        {
            "label": "Contact Details",
            "columns": 2,
            "fields": [
                "Phone",
                "PersonEmail",
                "PersonOtherPhone",
                "Other_Email__c",
                "Other_Phone_2__c",
                "Other_Email_2__c",
                "Other_Phone_3__c",
                "Other_Email_3__c",
                "Other_Phone_4__c",
                "Other_Email_4__c",
                "PersonMailingAddress",
                "BillingAddress",
                "Office_Address__c"
            ]
        },
        {
            "label": "Other Details",
            "columns": 2,
            "fields": [
                "RecordTypeId",
                "OwnerId",
                "Sales_Group__c",
                "Account_Group__c",
                "Type",
                "Search_Term_1__c"
            ]
        },
        {
            "label": "History",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Booking__c": [
        {
            "label": "Information",
            "columns": 2,
            "fields": [
                "Name",
                "OwnerId",
                "Opportunity_Id__c",
                "Account_Id__c",
                "Approval_Status__c",
                "Project__c",
                "Status__c",
                "Tower__c",
                "Tripartite_Agreement_Status__c",
                "Unit_Id__c",
                "Rejection_Reason__c",
                "Opportunity_Id__r.Chargeable_Area__c",
                "Registration__c",
                "OC_Received__c",
                "Reservation_Deposit__c",
                "Payment_Plan_Id__c",
                "Brokerage_Value__c"
            ]
        },
        {
            "label": "Interest Details",
            "columns": 2,
            "fields": [
                "AccruedInterestFromLedger__c",
                "TotalInterestOutstandingFromLedger__c",
                "InterestWaivedFromLedger__c",
                "InterestReceivedFromLedger__c"
            ]
        },
        {
            "label": "BP Pricing",
            "columns": 2,
            "fields": [
                "Opportunity_Id__r.BasePrice__c",
                "Opportunity_Id__r.Base_Cost__c",
                "Opportunity_Id__r.BasePriceDiscount__c",
                "Opportunity_Id__r.BaseCostAfterDiscount__c",
                "Opportunity_Id__r.Actual_Discount_Percentage__c",
                "Opportunity_Id__r.Land_Cost__c",
                "Opportunity_Id__r.Chargeable_Area__c",
                "Opportunity_Id__r.TaxOnLandCostPercentage__c",
                "Opportunity_Id__r.OtherCharges__c",
                "Opportunity_Id__r.Tax_on_Land_Cost__c",
                "Opportunity_Id__r.Tax_on_Other_Charges__c",
                "Opportunity_Id__r.Construction_Cost__c",
                "Opportunity_Id__r.TaxOnOtherCharges__c",
                "Opportunity_Id__r.TaxOnConstructionCostPercentage__c",
                "Opportunity_Id__r.Total_Amount__c",
                "Opportunity_Id__r.TaxOnConstructionCost__c"
            ]
        },
        {
            "label": "Booking Details",
            "columns": 2,
            "fields": [
                "Co_Applicant_1__c",
                "Allotment_Shared__c",
                "Co_Applicant_2__c",
                "Opportunity_Id__r.Token_Amount__c",
                "Co_Applicant_3__c",
                "Is_Token_Recieved__c",
                "Co_Applicant_4__c",
                "Funding_Method__c",
                "Co_Applicant_5__c",
                "HomeLoanBank__c",
                "Is_Agreement_Signed__c",
                "Loan_Sanctioned_Amount__c"
            ]
        },
        {
            "label": "Important Dates",
            "columns": 2,
            "fields": [
                "Booking_Date__c",
                "Sale_Deed_Executed_Date__c",
                "Allotment_Letter_Date__c",
                "Sale_Deed_Registered_Date__c",
                "Agreement_Executed_Date__c",
                "Rectification_Date__c",
                "Agreement_Registered_Date__c",
                "Transfer_Date__c",
                "Possession_Date__c",
                "Pre_Cancellation_Date__c",
                "Final_Reminder_Letter_Date__c",
                "Booking_Cancellation_Date__c"
            ]
        },
        {
            "label": "Other Details",
            "columns": 1,
            "fields": [
                "Remarks__c"
            ]
        },
        {
            "label": "Sales Details",
            "columns": 2,
            "fields": [
                "Sales_Organization__c",
                "Broker_agreement_Value__c",
                "Distribution_channel__c",
                "Document_type__c",
                "Division__c",
                "SFDC_booking_reference_no__c",
                "Broker_agreement_condition__c"
            ]
        },
        {
            "label": "System information",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Lead": [
        {
            "label": "Personal Details",
            "columns": 2,
            "fields": [
                "Name",
                "Email",
                "Age__c",
                "Phone",
                "Occupation__c",
                "MobilePhone",
                "Residential_Status__c",
                "Address",
                "Residential_Address__c"
            ]
        },
        {
            "label": "Lead Information",
            "columns": 2,
            "fields": [
                "Status",
                "LeadSource",
                "Drop_Reason__c",
                "Updated_Source__c",
                "OwnerId",
                "Approved_Channel_Partner__c",
                "RecordTypeId",
                "Agent_s_Name__c",
                "Website",
                "Employee_s_name__c",
                "Interested_in_Site_Visit__c",
                "Event_Name__c",
                "Is_Potential_Duplicate__c",
                "Existing_Customer__c",
                "Reason_for_Duplication_Picklist__c",
                "Lead_Subsource__c",
                "Description",
                "No_Recent_Interaction_90_Days__c"
            ]
        },
        {
            "label": "Property Preferences",
            "columns": 2,
            "fields": [
                "Projects__c",
                "Preferred_City__c",
                "Budget__c",
                "Type_of_Units__c",
                "Source_of_Funding__c",
                "Desired_Status__c"
            ]
        },
        {
            "label": "Current Residency Details",
            "columns": 2,
            "fields": [
                "Current_Residency_Type__c",
                "Typology_of_Current_Residence_3_4_5_BHK__c",
                "Carpet_Area_of_Current_Residence_Sq_ft__c",
                "Competitor_Name__c"
            ]
        },
        {
            "label": "Archival Details",
            "columns": 2,
            "fields": [
                "Archive_Status__c",
                "Archive_For_In_Days__c",
                "Archive_Follow_Up_Date__c",
                "Archive_Populated_Date__c"
            ]
        },
        {
            "label": "History",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Opportunity": [
        {
            "label": "About",
            "columns": 2,
            "fields": [
                "Name",
                "Discount_Approval_Status__c",
                "AccountId",
                "Token_Amount__c",
                "CloseDate",
                "Payment_Plan__c",
                "OwnerId"
            ]
        },
        {
            "label": "Unit Details",
            "columns": 2,
            "fields": [
                "Interested_Unit__r.Property__c",
                "Interested_Unit__r.Floor__c",
                "Interested_Unit__r.Tower__c",
                "Interested_Unit__c"
            ]
        },
        {
            "label": "Source Details",
            "columns": 2,
            "fields": [
                "LeadSource",
                "Updated_Source__c",
                "Agent_s_Name__c",
                "Approved_Channel_Partner__c",
                "Event_Name__c",
                "Existing_Customer_s_Name__c",
                "Employee_s_name__c"
            ]
        },
        {
            "label": "BP Pricing",
            "columns": 2,
            "fields": [
                "BasePrice__c",
                "Base_Cost__c",
                "BasePriceDiscount__c",
                "BaseCostAfterDiscount__c",
                "Actual_Discount_Percentage__c",
                "Land_Cost__c",
                "Chargeable_Area__c",
                "TaxOnLandCostPercentage__c",
                "OtherCharges__c",
                "Tax_on_Land_Cost__c",
                "Tax_on_Other_Charges__c",
                "Construction_Cost__c",
                "TaxOnOtherCharges__c",
                "TaxOnConstructionCostPercentage__c",
                "Total_Amount__c",
                "TaxOnConstructionCost__c"
            ]
        },
        {
            "label": "Status",
            "columns": 2,
            "fields": [
                "StageName",
                "Probability"
            ]
        },
        {
            "label": "History",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Property__c": [
        {
            "label": "Information",
            "columns": 2,
            "fields": [
                "Name",
                "Allocated_User__c",
                "Project_ID__c",
                "GSTIN__c",
                "Address__c",
                "CIN__c",
                "Architect_Certificate_Number__c",
                "PAN__c",
                "OC_Received__c",
                "Construction_Schedule__c",
                "BusinessEntity__c",
                "RecordTypeId",
                "Location__c"
            ]
        },
        {
            "label": "Additional Fields",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Site_Visit__c": [
        {
            "label": "Information",
            "columns": 2,
            "fields": [
                "Name",
                "Lead__c",
                "Visit_DateTime__c",
                "Opportunity__c",
                "Status__c",
                "OwnerId",
                "RecordTypeDeveloperName__c",
                "Reminder_Sent__c"
            ]
        },
        {
            "label": "Site Visit Details",
            "columns": 2,
            "fields": [
                "Did_the_guest_visit_the_show_flat__c",
                "Project__c",
                "Did_the_guest_like_the_project_or_produc__c",
                "Building__c",
                "Has_the_Guest_Visited_with_Family__c",
                "Unit__c",
                "Next_Follow_up_After__c",
                "TL_Team_Leader__c",
                "Rating__c",
                "Closing_Manager_Name__c",
                "Remarks__c"
            ]
        },
        {
            "label": "Details (For Office Use)",
            "columns": 2,
            "fields": [
                "In_Time__c",
                "Out_Time__c",
                "Sales_Manager_Remarks__c",
                "Enquiry_Number__c"
            ]
        },
        {
            "label": "Marketing Office Visit Experience: (filled by customer)",
            "columns": 2,
            "fields": [
                "The_welcome_you_received_when_you_came_i__c",
                "Recommend_project_to_family_friends__c",
                "Waiting_Time_Before_Assistance_minutes__c",
                "Any_reasons_for_the_same__c",
                "Time_Sales_Team_Spent_with_You_minutes__c",
                "Your_Overall_Experience__c",
                "How_was_your_interaction_with_our_sales__c",
                "Suggestions_to_improve_your_experience__c"
            ]
        },
        {
            "label": "System information",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Tower__c": [
        {
            "label": "Information",
            "columns": 2,
            "fields": [
                "Name",
                "BESCOM_BWSSB_Charges__c",
                "Property__c",
                "Maintenance_Deposit_Corpus_Fund__c",
                "ZWBS_Structure__c",
                "Legal_Fees__c",
                "Chargeable_Area_Type__c",
                "Club_Membership_Fees__c",
                "RERA_Number__c",
                "Company_Bank_Account__c",
                "OC_Received__c",
                "RecordTypeId"
            ]
        },
        {
            "label": "System information",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Unit__c": [
        {
            "label": "Information",
            "columns": 2,
            "fields": [
                "Name",
                "Status__c",
                "Property__c",
                "Status_Effective_Date__c",
                "Tower__c",
                "Unit_Availability__c",
                "Floor__c",
                "BHK_Configuration__c",
                "Profit_Center__c",
                "Number_of_Car_Parkings__c",
                "Unit_Type__c",
                "Customer_Account__c",
                "Unit_Group__c",
                "Tripartite_Agreement_Status__c",
                "Control_Code__c",
                "Funding_Method__c"
            ]
        },
        {
            "label": "Area Details",
            "columns": 2,
            "fields": [
                "Built_Up_Area_SBA__c",
                "Deck_Balcony__c",
                "Carpet_Area__c",
                "Terrace_Area__c",
                "Saleable_Area__c",
                "Total_area_of_villa_unit__c",
                "Garden_Area__c",
                "Net_Area_Aggregate__c",
                "Private_Lobby__c"
            ]
        },
        {
            "label": "System information",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Site_Visit__c": [
        {
            "label": "Visit Overview",
            "columns": 2,
            "fields": [
                "Name",
                "Project__c",
                "Building__c",
                "Unit__c",
                "Lead__c",
                "Opportunity__c",
                "Visit_DateTime__c",
                "Status__c",
                "In_Time__c",
                "Out_Time__c",
                "Enquiry_Number__c",
                "OTP_Verified__c"
            ]
        },
        {
            "label": "Customer Feedback & Visitor Experience",
            "columns": 2,
            "fields": [
                "Your_Overall_Experience__c",
                "Did_the_guest_like_the_project_or_produc__c",
                "Did_the_guest_visit_the_show_flat__c",
                "Has_the_Guest_Visited_with_Family__c",
                "The_welcome_you_received_when_you_came_i__c",
                "Waiting_Time_Before_Assistance_minutes__c",
                "Recommend_project_to_family_friends__c",
                "Suggestions_to_improve_your_experience__c",
                "Any_reasons_for_the_same__c"
            ]
        },
        {
            "label": "Executive Feedback & Deal Assessment",
            "columns": 2,
            "fields": [
                "Rating__c",
                "Interest_Level__c",
                "Next_Follow_up_After__c",
                "Time_Sales_Team_Spent_with_You_minutes__c",
                "Closing_Manager_Name__c",
                "TL_Team_Leader__c",
                "How_was_your_interaction_with_our_sales__c",
                "Sales_Manager_Remarks__c",
                "Remarks__c",
                "Comments__c"
            ]
        },
        {
            "label": "System information",
            "columns": 2,
            "fields": [
                "CreatedById",
                "LastModifiedById"
            ]
        }
    ],
    "Handover__c": [
        {
            "label": "Information",
            "columns": 2,
            "fields": [
                "Name",
                "Booking__c",
                "Customer__c",
                "Contact__c",
                "Property__c",
                "Tower__c",
                "Floor__c",
                "Unit__c",
                "Stage__c",
                "Status__c",
                "Target_Handover_Date__c",
                "Handover_Owner__c"
            ]
        },
        {
            "label": "Clearances & Readiness",
            "columns": 2,
            "fields": [
                "Finance_Status__c",
                "OC_Clearance__c",
                "Registration_Status__c",
                "Possession_Readiness__c",
                "Unit_Readiness__c",
                "Blocking_Reason__c"
            ]
        },
        {
            "label": "Appointment & Possession Handover",
            "columns": 2,
            "fields": [
                "Appointment_Date__c",
                "Appointment_Time_Slot__c",
                "Appointment_Location__c",
                "Customer_Instructions__c",
                "Customer_Arrived__c",
                "Customer_Arrival_Time__c",
                "Keys_Handed_Over__c",
                "Keys_Sets_Count__c",
                "Access_Cards_Handed_Over__c",
                "Access_Cards_Count__c",
                "Documents_Handed_Over__c"
            ]
        },
        {
            "label": "Utility Meters & Signoff",
            "columns": 2,
            "fields": [
                "Meter_Readings_Captured__c",
                "Electricity_Meter_Reading__c",
                "Water_Meter_Reading__c",
                "Gas_Meter_Reading__c",
                "Customer_Acknowledgement_Status__c",
                "Customer_Signee_Name__c",
                "Acknowledgement_Date_Time__c",
                "Completed_Date_Time__c",
                "Completed_By__c",
                "Feedback_Rating__c",
                "Final_Remarks__c"
            ]
        },
        {
            "label": "Post-Sale & Warranty",
            "columns": 2,
            "fields": [
                "Post_Sale_Status__c",
                "Post_Sale_Owner__c",
                "Warranty_Start_Date__c",
                "Warranty_End_Date__c"
            ]
        }
    ]
};

// EOI vouchers had no Dynamic Forms page to mirror; sections follow the voucher lifecycle.
SECTIONS.Voucher__c = [
    {
        label: 'Voucher',
        columns: 2,
        fields: ['Name', 'Status__c', 'Voucher_Type__c', 'Project__c', 'Preferred_Configuration__c', 'Priority_Number__c', 'Valid_Until__c', 'Refundable__c']
    },
    {
        label: 'Applicant',
        columns: 2,
        fields: ['Applicant_Name__c', 'Applicant_Mobile__c', 'Applicant_Email__c', 'Lead__c', 'Account__c', 'Opportunity__c', 'Channel_Partner__c', 'Applicable_To__c']
    },
    {
        label: 'Payment',
        columns: 2,
        fields: ['Amount__c', 'Amount_Paid__c', 'Balance_Due__c', 'Payment_Mode__c', 'Payment_Reference__c', 'Payment_Date__c']
    },
    {
        label: 'Allotment & booking',
        columns: 2,
        fields: ['Flat_No__c', 'Booking__c']
    },
    {
        label: 'Cancellation & refund',
        columns: 2,
        fields: ['Cancellation_Reason__c', 'Refund_Amount__c', 'Refund_Reference__c', 'Refund_Date__c']
    },
    {
        label: 'Notes',
        columns: 1,
        fields: ['Remarks__c']
    },
    {
        label: 'History',
        columns: 2,
        fields: ['CreatedById', 'LastModifiedById']
    }
];

// Customer 360 (person accounts). The Account layout above carries channel-partner and SAP fields,
// which stay on partner records only.
export const CUSTOMER_SECTIONS = [
    {
        label: 'Personal details',
        columns: 2,
        fields: ['Name', 'PersonBirthdate', 'PersonGender', 'PersonMaritalStatus', 'PAN_Number__c', 'Aadhar_Number__c', 'Language__c', 'Interested_Projects__c']
    },
    {
        label: 'Contact details',
        columns: 2,
        fields: [
            'PersonMobilePhone',
            'PersonEmail',
            'Phone',
            'Other_Email__c',
            'PersonOtherPhone',
            'Other_Email_2__c',
            'PersonMailingAddress',
            'Office_Address__c'
        ]
    },
    {
        label: 'Relationship',
        columns: 2,
        fields: ['OwnerId', 'PersonLeadSource', 'RecordTypeId', 'Type']
    },
    {
        label: 'Bank & tax',
        columns: 2,
        fields: ['BANK_ACCOUNT_NO__c', 'IFSC_Code__c', 'Beneficiary_Name_Account_Holder_Name__c', 'GST_No__c']
    },
    {
        label: 'History',
        columns: 2,
        fields: ['CreatedById', 'LastModifiedById']
    }
];

// Per-object hero configuration. Objects without an entry fall back to the first
// four fields of their first section and no path. `actions` is a whitelist (in order) of
// what the page layout exposes; without it every object-specific action is offered.
export const RECORD_CONFIG = {
    Lead: {
        eyebrow: 'Residential lead',
        highlights: ['Projects__c', 'Type_of_Units__c', 'LeadSource', 'OwnerId'],
        facts: ['MobilePhone', 'Email', 'Preferred_City__c'],
        pathField: 'Status',
        // Site visits are logged from the sidebar gate and calls from the dialer, so those actions are not repeated here.
        actions: ['Convert', 'Lead.Generate_EOI_Voucher', 'Lead.Assign_using_Round_Robin', 'Lead.Mark_as_Dropped', 'Delete']
    },
    Opportunity: {
        eyebrow: 'Residential opportunity',
        highlights: ['Total_Amount__c', 'Interested_Unit__c', 'CloseDate', 'OwnerId'],
        facts: ['AccountId', 'Payment_Plan__c'],
        pathField: 'StageName',
        // Booking Form shares this opportunity's own customer link; Select Inventory tags a unit from the stack.
        // Ownership transfer and appointments belong on the booking, not the deal.
        actions: ['Opportunity.Booking_Form', 'Opportunity.Select_Inventory', 'Opportunity.Generate_Sales_Offer', 'Opportunity.Site_Visit', 'Submit', 'Clone', 'Delete']
    },
    Account: {
        eyebrow: 'Customer',
        // Top cards, units owned and the sidebar come from wdGlassCustomer (bookings, dues, receipts, deals, visits).
        customer360: true,
        facts: ['PersonMobilePhone', 'PersonEmail', 'OwnerId'],
        // Customers only get Edit; channel partners keep their own action order (see wdGlassRecord.actionItems).
        actions: []
    },
    Booking__c: {
        eyebrow: 'Booking',
        highlights: ['Final_Amount__c', 'Token_Amount__c', 'Unit_Id__c', 'Booking_Date__c'],
        facts: ['Account_Id__c', 'Project__c'],
        pathField: 'Status__c',
        // Shown first; the booking's remaining actions follow in the More menu.
        primaryActions: ['Booking__c.View_Handover', 'Booking__c.Generate_Welcome_Letter', 'Booking__c.View_Payment_Ledger', 'Submit'],
        alerts: [
            {
                field: 'Is_Payment_Plan_Linked__c',
                equals: false,
                message: 'To enable the Submit for Approval button, add a payment plan to this booking.'
            },
            {
                field: 'Ownership_Transfer_In_Progress__c',
                equals: true,
                message: 'This booking is currently under the ownership transfer process.'
            }
        ],
        extras: { interest: true }
    },
    Handover__c: {
        eyebrow: 'Handover & Possession',
        highlights: ['Stage__c', 'Status__c', 'Target_Handover_Date__c', 'Handover_Owner__c'],
        facts: ['Booking__c', 'Unit__c', 'Customer__c'],
        pathField: 'Stage__c'
    },
    Unit__c: {
        eyebrow: 'Unit',
        highlights: ['BHK_Configuration__c', 'Saleable_Area__c', 'Total_Cost__c', 'Tower__c'],
        facts: ['Property__c', 'Floor__c'],
        pathField: 'Status__c'
    },
    Property__c: {
        eyebrow: 'Project',
        facts: ['Project_ID__c']
    },
    Tower__c: {
        eyebrow: 'Building',
        facts: ['Property__c']
    },
    Voucher__c: {
        eyebrow: 'EOI voucher',
        // No clickable path: status moves only through the voucher actions, which enforce the EOI rules.
        highlights: ['Status__c', 'Amount__c', 'Balance_Due__c', 'Valid_Until__c'],
        facts: ['Applicant_Name__c', 'Project__c', 'Voucher_Type__c'],
        // Allotting a unit or adjusting against a booking is premature at lead stage, so only payment is offered.
        actions: ['Voucher__c.Record_EOI_Payment']
    },
    Site_Visit__c: {
        eyebrow: 'Site visit',
        highlights: ['Project__c', 'Unit__c', 'Rating__c', 'Interest_Level__c'],
        facts: ['Lead__c', 'Closing_Manager_Name__c', 'Visit_DateTime__c'],
        pathField: 'Status__c'
    }
};

// Opportunities get Details / Related / Booking Conditions tabs; the condition manager lives in the last one.
RECORD_CONFIG.Opportunity.extras = { conditions: true };

// Dynamic related lists placed directly on the RES_* record pages (beyond the page layout's lists).
// Ids are child relationship names (Site_Visits__r, not Site_Visits); unknown ids are dropped silently.
RECORD_CONFIG.Lead.relatedLists = ['Site_Visits__r'];
RECORD_CONFIG.Opportunity.relatedLists = [
    'Quotes',
    'Bookings__r',
    'Site_Visits__r',
    'Booking_Payment_Schedules__r',
    'OpportunityTeamMembers'
];
// Shown as a card even when empty, so the list is always visible.
RECORD_CONFIG.Lead.pinnedLists = ['Site_Visits__r'];
RECORD_CONFIG.Opportunity.pinnedLists = ['Quotes'];
RECORD_CONFIG.Booking__c.relatedLists = ['Handover__c.Booking__c', 'Handovers__r', 'Handovers', 'Interest_Waiver_Requests'];
RECORD_CONFIG.Handover__c.relatedLists = [
    'Inspections__r',
    'Snags__r',
    'Handover_Event_Logs__r',
    'Rent_Resale_Requests__r'
];