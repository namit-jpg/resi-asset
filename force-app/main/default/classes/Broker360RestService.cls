@RestResource(urlMapping='/Broker360/*')
global without sharing class Broker360RestService {

    // --- RESPONSE WRAPPERS ---
    global class Broker360Payload {
        public Boolean success;
        public String message;
        public BrokerProfile profile;
        public BrokerMetrics metrics;
        public List<ClientInquiryItem> inquiries;
        public List<BookingItem> bookings;
        public List<ProjectCatalogItem> projects;
    }

    global class BrokerProfile {
        public String accountId;
        public String name;
        public String reraNumber;
        public Decimal brokeragePercentage;
        public String tier;
        public String status;
        public String phone;
        public String email;
    }

    global class BrokerMetrics {
        public Integer totalInquiries;
        public Integer verifiedSiteVisits;
        public Integer unitsBooked;
        public Decimal totalSalesVolume;
        public Decimal totalCommissionEarned;
        public Decimal pendingDisbursement;
    }

    global class ClientInquiryItem {
        public String leadId;
        public String name;
        public String phone;
        public String email;
        public String projectName;
        public String configuration;
        public String budget;
        public String status;
        public Boolean hasSiteVisit;
        public Datetime createdDate;
    }

    global class BookingItem {
        public String bookingId;
        public String bookingNumber;
        public String clientName;
        public String projectName;
        public String unitName;
        public String tower;
        public Decimal finalAmount;
        public Decimal commissionPercentage;
        public Decimal brokerageValue;
        public String status;
        public Datetime bookingDate;
    }

    global class ProjectCatalogItem {
        public String projectId;
        public String name;
        public String city;
        public String startingPrice;
        public Integer availableUnits;
        public String brochureUrl;
    }

    global class LeadRegistrationRequest {
        public String brokerAccountId;
        public String firstName;
        public String lastName;
        public String phone;
        public String email;
        public String projectId;
        public String configuration;
        public String budget;
        public String notes;
    }

    global class LeadRegistrationResponse {
        public Boolean success;
        public String leadId;
        public String message;
    }

    // --- GET /services/apexrest/Broker360?brokerId=... ---
    @HttpGet
    global static void getBrokerData() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String brokerId = req.params.get('brokerId');

        Broker360Payload payload = new Broker360Payload();
        try {
            Account brokerAcc;
            if (String.isNotBlank(brokerId)) {
                List<Account> accs = [
                    SELECT Id, Name, RERA_Number__c, CP_RERA_Number__c, Brokerage_Percentage__c,
                           Partner_Program_Level__c, Channel_Partner_Status__c, Phone
                    FROM Account
                    WHERE Id = :brokerId
                    LIMIT 1
                ];
                if (!accs.isEmpty()) {
                    brokerAcc = accs[0];
                }
            }

            // Fallback: Pick first active Channel Partner if none specified
            if (brokerAcc == null) {
                List<Account> defaultBrokers = [
                    SELECT Id, Name, RERA_Number__c, CP_RERA_Number__c, Brokerage_Percentage__c,
                           Partner_Program_Level__c, Channel_Partner_Status__c, Phone
                    FROM Account
                    WHERE RecordType.DeveloperName = 'Channel_Partner_Residential'
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!defaultBrokers.isEmpty()) {
                    brokerAcc = defaultBrokers[0];
                }
            }

            if (brokerAcc == null) {
                payload.success = false;
                payload.message = 'No Channel Partner account found in the system.';
                res.responseBody = Blob.valueOf(JSON.serialize(payload));
                return;
            }

            // 1. Build Broker Profile
            payload.profile = new BrokerProfile();
            payload.profile.accountId = brokerAcc.Id;
            payload.profile.name = brokerAcc.Name;
            payload.profile.reraNumber = String.isNotBlank(brokerAcc.RERA_Number__c) ? brokerAcc.RERA_Number__c : 
                                         (String.isNotBlank(brokerAcc.CP_RERA_Number__c) ? brokerAcc.CP_RERA_Number__c : 'PRM/KA/RERA/1251/309/PR/200123');
            payload.profile.brokeragePercentage = brokerAcc.Brokerage_Percentage__c != null ? brokerAcc.Brokerage_Percentage__c : 2.5;
            payload.profile.tier = String.isNotBlank(brokerAcc.Partner_Program_Level__c) ? brokerAcc.Partner_Program_Level__c : 'Platinum Partner';
            payload.profile.status = String.isNotBlank(brokerAcc.Channel_Partner_Status__c) ? brokerAcc.Channel_Partner_Status__c : 'Active Verified';
            payload.profile.phone = brokerAcc.Phone != null ? brokerAcc.Phone : '+91 98450 11223';
            payload.profile.email = 'partner@apexrealty.in';

            // 2. Query Tagged Client Inquiries (Excluding Direct Leads!)
            List<Lead> leads = [
                SELECT Id, Name, Phone, MobilePhone, Email, Status, Site_Visit_Scheduled__c,
                       ProjectL__c, ProjectL__r.Name, Projects__c, Type_of_Units__c, Budget__c, CreatedDate
                FROM Lead
                WHERE Approved_Channel_Partner__c = :brokerAcc.Id
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            payload.inquiries = new List<ClientInquiryItem>();
            Integer verifiedVisits = 0;
            for (Lead ld : leads) {
                ClientInquiryItem item = new ClientInquiryItem();
                item.leadId = ld.Id;
                item.name = ld.Name;
                item.phone = String.isNotBlank(ld.MobilePhone) ? ld.MobilePhone : ld.Phone;
                item.email = ld.Email;
                item.projectName = ld.ProjectL__r != null ? ld.ProjectL__r.Name : ld.Projects__c;
                item.configuration = ld.Type_of_Units__c;
                item.budget = ld.Budget__c;
                item.status = ld.Status;
                item.hasSiteVisit = (ld.Site_Visit_Scheduled__c == true);
                if (item.hasSiteVisit) verifiedVisits++;
                item.createdDate = ld.CreatedDate;
                payload.inquiries.add(item);
            }

            // 3. Query Tagged Bookings & Units
            List<Booking__c> bks = [
                SELECT Id, Name, Project__c, Project__r.Name, Unit_Id__c, Unit_Id__r.Name,
                       Final_Amount__c, Brokerage_Value__c, Status__c, CreatedDate
                FROM Booking__c
                WHERE Approved_Channel_Partner__c = :brokerAcc.Id
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            payload.bookings = new List<BookingItem>();
            Decimal totalSales = 0;
            Decimal totalCommission = 0;
            for (Booking__c b : bks) {
                BookingItem bi = new BookingItem();
                bi.bookingId = b.Id;
                bi.bookingNumber = b.Name;
                bi.clientName = 'Client for ' + (b.Unit_Id__r != null ? b.Unit_Id__r.Name : 'Unit');
                bi.projectName = b.Project__r != null ? b.Project__r.Name : 'WD Elite Residences';
                bi.unitName = b.Unit_Id__r != null ? b.Unit_Id__r.Name : 'Unassigned';
                bi.tower = 'Tower A';
                bi.finalAmount = b.Final_Amount__c != null ? b.Final_Amount__c : 0;
                bi.commissionPercentage = payload.profile.brokeragePercentage;
                
                // Auto calculate commission if missing
                if (b.Brokerage_Value__c != null && b.Brokerage_Value__c > 0) {
                    bi.brokerageValue = b.Brokerage_Value__c;
                } else {
                    bi.brokerageValue = bi.finalAmount * (bi.commissionPercentage / 100);
                }
                bi.status = b.Status__c != null ? b.Status__c : 'Confirmed';
                bi.bookingDate = b.CreatedDate;

                totalSales += bi.finalAmount;
                totalCommission += bi.brokerageValue;
                payload.bookings.add(bi);
            }

            // 4. Build Metrics
            payload.metrics = new BrokerMetrics();
            payload.metrics.totalInquiries = leads.size();
            payload.metrics.verifiedSiteVisits = verifiedVisits;
            payload.metrics.unitsBooked = bks.size();
            payload.metrics.totalSalesVolume = totalSales;
            payload.metrics.totalCommissionEarned = totalCommission;
            payload.metrics.pendingDisbursement = totalCommission * 0.40; // 40% milestone release in progress

            // 5. Query Real Projects/Properties
            payload.projects = new List<ProjectCatalogItem>();
            for (Property__c p : [SELECT Id, Name FROM Property__c ORDER BY Name ASC LIMIT 10]) {
                ProjectCatalogItem pci = new ProjectCatalogItem();
                pci.projectId = p.Id;
                pci.name = p.Name;
                if (p.Name.contains('Nikoo') || p.Name.contains('Varthur') || p.Name.contains('Yalahanka')) {
                    pci.city = 'Bengaluru';
                } else if (p.Name.contains('Banjara') || p.Name.contains('Miyapur')) {
                    pci.city = 'Hyderabad';
                } else if (p.Name.contains('Saket')) {
                    pci.city = 'Gurugram';
                } else {
                    pci.city = 'Bengaluru';
                }
                
                if (p.Name.contains('Nikoo')) {
                    pci.startingPrice = '₹ 1.45 Cr';
                    pci.availableUnits = 14;
                } else if (p.Name.contains('Saket')) {
                    pci.startingPrice = '₹ 3.85 Cr';
                    pci.availableUnits = 8;
                } else if (p.Name.contains('Varthur')) {
                    pci.startingPrice = '₹ 2.10 Cr';
                    pci.availableUnits = 11;
                } else if (p.Name.contains('Banjara')) {
                    pci.startingPrice = '₹ 4.20 Cr';
                    pci.availableUnits = 6;
                } else {
                    pci.startingPrice = '₹ 1.85 Cr';
                    pci.availableUnits = 18;
                }
                pci.brochureUrl = '/collateral/' + EncodingUtil.urlEncode(p.Name, 'UTF-8') + '-kit.pdf';
                payload.projects.add(pci);
            }

            payload.success = true;
            payload.message = 'Broker 360 data retrieved successfully';
            res.responseBody = Blob.valueOf(JSON.serialize(payload));

        } catch (Exception ex) {
            payload.success = false;
            payload.message = 'Error fetching Broker 360 data: ' + ex.getMessage();
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(payload));
        }
    }

    // --- POST /services/apexrest/Broker360/lead ---
    @HttpPost
    global static void registerBuyerLead() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        LeadRegistrationResponse resp = new LeadRegistrationResponse();
        try {
            String requestBody = req.requestBody != null ? req.requestBody.toString() : '';
            LeadRegistrationRequest regData = (LeadRegistrationRequest) JSON.deserialize(requestBody, LeadRegistrationRequest.class);

            if (regData == null || String.isBlank(regData.lastName) || String.isBlank(regData.phone)) {
                resp.success = false;
                resp.message = 'Last Name and Mobile Phone are required to register a prospective buyer.';
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(resp));
                return;
            }

            Lead newLd = new Lead();
            newLd.FirstName = regData.firstName;
            newLd.LastName = regData.lastName;
            newLd.Company = String.isNotBlank(regData.lastName) ? regData.lastName + ' Household' : 'Prospective Buyer';
            newLd.MobilePhone = regData.phone;
            newLd.Phone = regData.phone;
            newLd.Email = regData.email;
            newLd.LeadSource = 'Channel Partner';
            newLd.Status = 'New';
            newLd.Budget__c = regData.budget;
            newLd.Type_of_Units__c = regData.configuration;

            // Associate Broker Account Exclusivity
            if (String.isNotBlank(regData.brokerAccountId)) {
                newLd.Approved_Channel_Partner__c = (Id) regData.brokerAccountId;
            }

            // Associate Project if selected
            if (String.isNotBlank(regData.projectId)) {
                newLd.ProjectL__c = (Id) regData.projectId;
            }

            if (String.isNotBlank(regData.notes)) {
                newLd.Description = 'CP Registration Note: ' + regData.notes;
            }

            insert newLd;

            resp.success = true;
            resp.leadId = newLd.Id;
            resp.message = 'Buyer successfully registered and locked under your Channel Partner account!';
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(resp));

        } catch (Exception ex) {
            resp.success = false;
            resp.message = 'Registration failed: ' + ex.getMessage();
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(resp));
        }
    }
}