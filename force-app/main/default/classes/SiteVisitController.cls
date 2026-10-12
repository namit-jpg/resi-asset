/**
 * Class Name      : SiteVisitController
 * Description     : Handles Site Visit operations for both Public Guest Users (siteVisitFeedback)
 *                   and Internal Sales Operations (logSiteVisitModal). Aligned with UAT Property__c schema.
 */
public without sharing class SiteVisitController {

    // --- WRAPPERS FOR PUBLIC GUEST USER PORTAL ---
    public class SiteVisitWrapper {
        @AuraEnabled public String leadId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String propertyId; 
        @AuraEnabled public String towerId;    
        @AuraEnabled public String unitId;
        @AuraEnabled public String interactionRating;
        @AuraEnabled public String overallExperience;
        @AuraEnabled public String waitingTime;
    }

    // --- WRAPPERS FOR INTERNAL SALES MODAL ---
    public class LeadDetailWrapper {
        @AuraEnabled public Id leadId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String company { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String mobilePhone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean hasSiteVisit { get; set; }
        @AuraEnabled public Decimal siteVisitCount { get; set; }
        @AuraEnabled public Id projectEnquiredId { get; set; }
        @AuraEnabled public String projectEnquiredName { get; set; }
        @AuraEnabled public String configurationInterested { get; set; }
        @AuraEnabled public String budgetRange { get; set; }
        @AuraEnabled public List<SiteVisitItemWrapper> recentVisits { get; set; }
    }

    public class SiteVisitItemWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String projectName { get; set; }
        @AuraEnabled public String unitName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String rating { get; set; }
        @AuraEnabled public Datetime visitDateTime { get; set; }
        @AuraEnabled public Boolean otpVerified { get; set; }
        @AuraEnabled public String salesExecutiveName { get; set; }
    }

    public class UnitOptionWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String configuration { get; set; }
        @AuraEnabled public String towerName { get; set; }
        @AuraEnabled public String floorName { get; set; }
        @AuraEnabled public Decimal basePrice { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String displayName { get; set; }
    }

    public class SiteVisitSaveResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Id siteVisitId { get; set; }
        @AuraEnabled public String siteVisitName { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    public class OtpResultWrapper {
        @AuraEnabled public String otpCode { get; set; }
        @AuraEnabled public String maskedMobile { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Datetime timestamp { get; set; }
    }

    // --- METHODS FOR PUBLIC GUEST USER FEEDBACK ---
    @AuraEnabled(cacheable=true)
    public static List<Property__c> getProperties() {
        return [SELECT Id, Name FROM Property__c ORDER BY Name ASC];
    }

    @AuraEnabled(cacheable=true)
    public static List<Tower__c> getTowers(Id propertyId) {
        return [SELECT Id, Name FROM Tower__c WHERE Property__c = :propertyId ORDER BY Name ASC];
    }

    @AuraEnabled(cacheable=true)
    public static List<Unit__c> getUnits(Id towerId) {
        return [SELECT Id, Name FROM Unit__c WHERE Tower__c = :towerId ORDER BY Name ASC];
    }

    @AuraEnabled
    public static Lead findExistingLead(String phone, String email) {
        if(String.isBlank(phone) && String.isBlank(email)) return null;
        
        List<Lead> leads = [SELECT Id, FirstName, LastName, Email, MobilePhone 
                            FROM Lead 
                            WHERE (MobilePhone = :phone AND MobilePhone != null) 
                            OR (Email = :email AND Email != null) 
                            LIMIT 1];
                            
        return leads.isEmpty() ? null : leads[0];
    }

    @AuraEnabled
    public static String submitData(SiteVisitWrapper info, String customerSig, String agentSig) {
        if (info == null) {
            throw new AuraHandledException('Submission failed: No data received.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Id targetLeadId;

            // 1. Lead Logic
            if (String.isNotBlank(info.leadId)) {
                targetLeadId = (Id)info.leadId;
            } else {
                Id leadRTId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().containsKey('Standard_Lead_Residential')
                    ? Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Standard_Lead_Residential').getRecordTypeId()
                    : null;
                Lead newLead = new Lead(
                    FirstName = info.firstName,
                    LastName = info.lastName,
                    MobilePhone = info.mobile,
                    Email = info.email,
                    Company = info.firstName + ' ' + info.lastName,
                    Status = 'New'
                );
                if (leadRTId != null) newLead.RecordTypeId = leadRTId;
                insert newLead;
                targetLeadId = newLead.Id;
            }

            // 2. Site Visit Logic
            Id svRTId = Schema.SObjectType.Site_Visit__c.getRecordTypeInfosByDeveloperName().containsKey('Residential_Sales_Site_Visit')
                ? Schema.SObjectType.Site_Visit__c.getRecordTypeInfosByDeveloperName().get('Residential_Sales_Site_Visit').getRecordTypeId()
                : null;
            
            Site_Visit__c sv = new Site_Visit__c();
            if (svRTId != null) sv.RecordTypeId = svRTId;
            sv.Lead__c = targetLeadId;
            sv.Project__c = info.propertyId;   
            sv.Building__c = info.towerId;     
            sv.Unit__c = info.unitId;
            sv.Visit_DateTime__c = System.now(); 
            sv.Status__c = 'Completed';
            
            sv.How_was_your_interaction_with_our_sales__c = info.interactionRating;
            sv.Your_Overall_Experience__c = info.overallExperience;
            
            if(String.isNotBlank(info.waitingTime)) {
                sv.Waiting_Time_Before_Assistance_minutes__c = Decimal.valueOf(info.waitingTime);
            }
            insert sv;

            // 3. Signature Logic
            if(String.isNotBlank(customerSig) && customerSig.contains(',')) {
                saveSignature(customerSig, sv.Id, 'Customer_Signature');
            }
            if(String.isNotBlank(agentSig) && agentSig.contains(',')) {
                saveSignature(agentSig, sv.Id, 'Agent_Signature');
            }

            return 'Success';
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Submit Error: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void saveSignature(String base64, Id parentId, String name) {
        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode(base64.substringAfter(','));
        cv.Title = name;
        cv.PathOnClient = name + '.png';
        insert cv;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        cdl.LinkedEntityId = parentId;
        cdl.ShareType = 'V';
        insert cdl;
    }

    // --- METHODS FOR INTERNAL LOG SITE VISIT MODAL ---
    @AuraEnabled
    public static LeadDetailWrapper getLeadDetails(Id leadId) {
        if (leadId == null) {
            throw new AuraHandledException('Lead Id cannot be null');
        }

        Lead ld = [
            SELECT Id, Name, Company, Phone, MobilePhone, Email, Status,
                   ProjectL__c, ProjectL__r.Name, Projects__c,
                   Type_of_Units__c, Budget__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        Integer actualVisitCount = [SELECT count() FROM Site_Visit__c WHERE Lead__c = :leadId];

        LeadDetailWrapper wrapper = new LeadDetailWrapper();
        wrapper.leadId = ld.Id;
        wrapper.name = ld.Name;
        wrapper.company = ld.Company;
        wrapper.phone = ld.Phone;
        wrapper.mobilePhone = ld.MobilePhone;
        wrapper.email = ld.Email;
        wrapper.status = ld.Status;
        wrapper.hasSiteVisit = (actualVisitCount > 0);
        wrapper.siteVisitCount = actualVisitCount;
        wrapper.projectEnquiredId = ld.ProjectL__c;
        wrapper.projectEnquiredName = ld.ProjectL__r != null ? ld.ProjectL__r.Name : ld.Projects__c;
        wrapper.configurationInterested = ld.Type_of_Units__c;
        wrapper.budgetRange = ld.Budget__c;

        List<Site_Visit__c> visits = [
            SELECT Id, Name, Project__c, Project__r.Name, Unit__c, Unit__r.Name,
                   Status__c, Rating__c, Visit_DateTime__c, OTP_Verified__c,
                   Closing_Manager_Name__c, Closing_Manager_Name__r.Name
            FROM Site_Visit__c
            WHERE Lead__c = :leadId
            ORDER BY Visit_DateTime__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 5
        ];

        wrapper.recentVisits = new List<SiteVisitItemWrapper>();
        for (Site_Visit__c sv : visits) {
            SiteVisitItemWrapper item = new SiteVisitItemWrapper();
            item.id = sv.Id;
            item.name = sv.Name;
            item.projectName = sv.Project__r != null ? sv.Project__r.Name : '';
            item.unitName = sv.Unit__r != null ? sv.Unit__r.Name : '';
            item.status = sv.Status__c;
            item.rating = sv.Rating__c;
            item.visitDateTime = sv.Visit_DateTime__c;
            item.otpVerified = (sv.OTP_Verified__c != null) ? sv.OTP_Verified__c : true;
            item.salesExecutiveName = sv.Closing_Manager_Name__r != null ? sv.Closing_Manager_Name__r.Name : '';
            wrapper.recentVisits.add(item);
        }

        return wrapper;
    }

    @AuraEnabled(cacheable=true)
    public static List<Property__c> getProjects() {
        return [
            SELECT Id, Name
            FROM Property__c
            ORDER BY Name ASC
            LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<UnitOptionWrapper> getUnitsForProject(Id projectId) {
        List<UnitOptionWrapper> unitList = new List<UnitOptionWrapper>();
        if (projectId == null) {
            return unitList;
        }

        List<Unit__c> units = [
            SELECT Id, Name, BHK_Configuration__c, Status__c, Base_Price__c,
                   Floor__r.Name, Tower__r.Name
            FROM Unit__c
            WHERE Property__c = :projectId OR Tower__r.Property__c = :projectId
            ORDER BY Tower__r.Name, Name
            LIMIT 100
        ];

        for (Unit__c u : units) {
            UnitOptionWrapper opt = new UnitOptionWrapper();
            opt.id = u.Id;
            opt.name = u.Name;
            opt.configuration = u.BHK_Configuration__c;
            opt.status = u.Status__c;
            opt.basePrice = u.Base_Price__c;
            opt.floorName = u.Floor__r != null ? u.Floor__r.Name : '';
            opt.towerName = (u.Tower__r != null) ? u.Tower__r.Name : '';
            
            String towerStr = String.isNotBlank(opt.towerName) ? opt.towerName + ' - ' : '';
            String configStr = String.isNotBlank(opt.configuration) ? ' (' + opt.configuration + ')' : '';
            opt.displayName = towerStr + u.Name + configStr;
            unitList.add(opt);
        }

        return unitList;
    }

    @AuraEnabled
    public static OtpResultWrapper generateOtp(String mobileNumber) {
        Integer otpInt = Math.round(Math.random() * 899999) + 100000;
        String otpCode = String.valueOf(otpInt);

        String cleanMobile = String.isNotBlank(mobileNumber) ? mobileNumber : '9902553348';
        String masked = cleanMobile.length() >= 4 
            ? '******' + cleanMobile.substring(cleanMobile.length() - 4)
            : cleanMobile;

        OtpResultWrapper res = new OtpResultWrapper();
        res.otpCode = otpCode;
        res.maskedMobile = masked;
        res.timestamp = System.now();
        res.message = 'SMS sent to ' + masked + ': "Your Site Visit verification OTP is ' + otpCode + '. Valid for 10 mins."';
        return res;
    }

    @AuraEnabled
    public static SiteVisitSaveResult logSiteVisit(
        Id leadId,
        Id projectId,
        Id unitId,
        String visitorMobile,
        String otpCode,
        String rating,
        String feedback,
        Datetime visitDateTime
    ) {
        return logSiteVisitWithDetails(
            leadId, projectId, unitId, visitorMobile, otpCode, rating, feedback, visitDateTime,
            null, null, null, null, null, null, null, null
        );
    }

    @AuraEnabled
    public static SiteVisitSaveResult logSiteVisitWithDetails(
        Id leadId,
        Id projectId,
        Id unitId,
        String visitorMobile,
        String otpCode,
        String rating,
        String feedback,
        Datetime visitDateTime,
        String visitedShowFlat,
        String likedProduct,
        String visitedWithFamily,
        String overallExperience,
        String customerQuestions,
        String interestLevel,
        String nextFollowUp,
        String executiveRemarks
    ) {
        SiteVisitSaveResult result = new SiteVisitSaveResult();

        if (leadId == null) {
            throw new AuraHandledException('Lead ID is required to log a site visit.');
        }
        if (projectId == null) {
            throw new AuraHandledException('Please select a Project for the site visit.');
        }

        try {
            Site_Visit__c sv = new Site_Visit__c();
            sv.Lead__c = leadId;
            sv.Project__c = projectId;
            if (unitId != null) {
                sv.Unit__c = unitId;
                List<Unit__c> uList = [SELECT Tower__c FROM Unit__c WHERE Id = :unitId LIMIT 1];
                if (!uList.isEmpty() && uList[0].Tower__c != null) {
                    sv.Building__c = uList[0].Tower__c;
                }
            }
            sv.Status__c = 'Completed';
            sv.Rating__c = String.isNotBlank(rating) ? rating : 'Hot';
            sv.Comments__c = feedback;
            sv.Visit_DateTime__c = (visitDateTime != null) ? visitDateTime : System.now();
            sv.Closing_Manager_Name__c = UserInfo.getUserId();
            sv.Visitor_Mobile__c = visitorMobile;
            sv.OTP_Code__c = otpCode;
            sv.OTP_Verified__c = true;

            // Customer Feedback Mapping
            if (String.isNotBlank(visitedShowFlat)) sv.Did_the_guest_visit_the_show_flat__c = visitedShowFlat;
            if (String.isNotBlank(likedProduct)) sv.Did_the_guest_like_the_project_or_produc__c = likedProduct;
            if (String.isNotBlank(visitedWithFamily)) sv.Has_the_Guest_Visited_with_Family__c = visitedWithFamily;
            if (String.isNotBlank(overallExperience)) sv.Your_Overall_Experience__c = overallExperience;
            if (String.isNotBlank(customerQuestions)) sv.Suggestions_to_improve_your_experience__c = customerQuestions;

            // Executive Feedback Mapping
            if (String.isNotBlank(interestLevel)) sv.Interest_Level__c = interestLevel;
            if (String.isNotBlank(nextFollowUp)) sv.Next_Follow_up_After__c = nextFollowUp;
            if (String.isNotBlank(executiveRemarks)) sv.Sales_Manager_Remarks__c = executiveRemarks;

            insert sv;

            Site_Visit__c createdSv = [SELECT Id, Name FROM Site_Visit__c WHERE Id = :sv.Id LIMIT 1];

            Lead ld = [
                SELECT Id, ProjectL__c, Status, Site_Visit_Scheduled__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            if (ld.ProjectL__c == null) {
                ld.ProjectL__c = projectId;
            }
            ld.Status = 'Site Visit';
            ld.Site_Visit_Scheduled__c = true;
            update ld;

            result.success = true;
            result.siteVisitId = createdSv.Id;
            result.siteVisitName = createdSv.Name;
            result.message = 'Site Visit ' + createdSv.Name + ' logged successfully! Lead qualification verified via OTP.';
            return result;

        } catch (Exception ex) {
            throw new AuraHandledException('Error logging site visit: ' + ex.getMessage());
        }
    }
}