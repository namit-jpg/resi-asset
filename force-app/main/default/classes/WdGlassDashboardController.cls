/**
 * Data provider for the WarpDrive glass sales dashboard (wdGlassDashboard).
 * One payload per (period, filters) so the page renders every chart without extra round trips.
 *
 * period:  month | quarter | fy | custom   (Indian financial year, April to March)
 * filters: project, location (project city), sales executive, lead source, unit configuration,
 *          channel and campaign. Each record is matched on whatever it carries; a record that
 *          cannot be placed against an active filter is left out.
 *
 * Period figures are compared against the same elapsed point of the previous period,
 * so a half-finished month is never judged against a full one.
 */
public without sharing class WdGlassDashboardController {

    private static final String RESI_LEAD_RT = 'Standard_Lead_Residential';
    private static final Integer FY_START_MONTH = 4;
    private static final String[] MONTHS = new String[]{ 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' };
    private static final Set<String> QUALIFIED_STATUSES = new Set<String>{ 'Qualified', 'Site Visit', 'Allocated', 'Converted' };
    private static final Set<String> VISIT_STATUSES = new Set<String>{ 'Site Visit', 'Allocated' };
    private static final Set<String> OPEN_LEAD_STATUSES = new Set<String>{ 'New', 'Contacted', 'Working', 'Qualified', 'Site Visit', 'Allocated' };
    private static final Set<String> HELD_UNIT_STATUSES = new Set<String>{ 'Blocked', 'Reserved', 'Management Hold' };
    private static final Integer COLD_AFTER_DAYS = 7;
    private static final String RESI_OPP_RT = 'Residential_Sales_Opportunity';
    private static final String CANCELLED = 'Cancelled';
    public static final String CHANNEL_DIRECT = 'Direct sale';
    public static final String CHANNEL_PARTNER = 'Channel partner';
    public static final String CHANNEL_REFERRAL = 'Referral';
    private static final Set<String> PARTNER_SOURCES = new Set<String>{ 'Channel Partner', 'Agent' };
    private static final Set<String> REFERRAL_SOURCES = new Set<String>{ 'Referral', 'Existing Customer', 'Employee' };
    private static final Map<String, String> CITY_ALIASES = new Map<String, String>{
        'bangalore' => 'Bengaluru', 'bengaluru' => 'Bengaluru', 'gurgaon' => 'Gurugram', 'gurugram' => 'Gurugram',
        'hyderabad' => 'Hyderabad', 'delhi' => 'Delhi', 'new delhi' => 'Delhi'
    };

    // Bookings, receipts and demands need a long chain of org records (unit, opportunity,
    // payment schedule) to insert, so tests hand rows in directly.
    @TestVisible private static List<Booking__c> stubBookings;
    @TestVisible private static List<Payment_Receipt__c> stubReceipts;
    @TestVisible private static List<Demand__c> stubDemands;
    @TestVisible private static List<Sales_Target__c> stubTargets;

    public class Tile {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String format; // inr | count
        @AuraEnabled public Decimal value = 0;
        @AuraEnabled public Decimal previous = 0;
        @AuraEnabled public String caption;
        @AuraEnabled public List<Decimal> spark = new List<Decimal>();

        Tile(String key, String label, String format) {
            this.key = key;
            this.label = label;
            this.format = format;
        }
    }

    public class Month {
        @AuraEnabled public String label;
        @AuraEnabled public String longLabel;
        @AuraEnabled public Decimal booked = 0;
        @AuraEnabled public Integer bookings = 0;
        @AuraEnabled public Decimal collected = 0;
        @AuraEnabled public Integer receipts = 0;
        @AuraEnabled public Boolean current = false;
    }

    public class Stage {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count = 0;

        Stage(String label) {
            this.label = label;
        }
    }

    public class Source {
        @AuraEnabled public String label;
        @AuraEnabled public Integer leads = 0;
        @AuraEnabled public Integer converted = 0;
        @AuraEnabled public Integer booked = 0;
        @AuraEnabled public Decimal bookedValue = 0;

        Source(String label) {
            this.label = label;
        }
    }

    public class Bucket {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal amount = 0;
        @AuraEnabled public Integer count = 0;

        Bucket(String label) {
            this.label = label;
        }
    }

    public class Collection {
        @AuraEnabled public Decimal due = 0;
        @AuraEnabled public Decimal received = 0;
        @AuraEnabled public Decimal overdue = 0;
        @AuraEnabled public Decimal upcoming = 0;
        @AuraEnabled public Integer upcomingCount = 0;
        @AuraEnabled public List<Bucket> buckets = new List<Bucket>{
            new Bucket('1–30 d'), new Bucket('31–60 d'), new Bucket('61–90 d'), new Bucket('90+ d')
        };
    }

    public class Day {
        @AuraEnabled public Date day;
        @AuraEnabled public Integer visits = 0;
        @AuraEnabled public Integer completed = 0;
        @AuraEnabled public Boolean future = false;
        @AuraEnabled public Boolean today = false;
    }

    public class Inventory {
        @AuraEnabled public String label;
        @AuraEnabled public Integer available = 0;
        @AuraEnabled public Integer held = 0;
        @AuraEnabled public Integer booked = 0;
        @AuraEnabled public Integer total = 0;

        Inventory(String label) {
            this.label = label;
        }
    }

    public class Leader {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal value = 0;
        @AuraEnabled public Integer bookings = 0;
        @AuraEnabled public Integer leads = 0;
        @AuraEnabled public Integer visits = 0;
        @AuraEnabled public Integer openDeals = 0;
        @AuraEnabled public Decimal target = 0;
        @AuraEnabled public Boolean me = false;
    }

    public class TargetMonth {
        @AuraEnabled public String label;
        @AuraEnabled public String longLabel;
        @AuraEnabled public Decimal target = 0;
        @AuraEnabled public Decimal actual = 0;
        @AuraEnabled public Decimal targetUnits = 0;
        @AuraEnabled public Integer units = 0;
        @AuraEnabled public Boolean current = false;
        @AuraEnabled public Boolean future = false;
    }

    public class ProjectRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String city;
        @AuraEnabled public Integer leads = 0;
        @AuraEnabled public Integer visits = 0;
        @AuraEnabled public Integer bookings = 0;
        @AuraEnabled public Decimal booked = 0;
        @AuraEnabled public Decimal collected = 0;
        @AuraEnabled public Integer available = 0;
        @AuraEnabled public Integer units = 0;
    }

    public class Bar {
        @AuraEnabled public String label;
        @AuraEnabled public Integer count = 0;
        @AuraEnabled public Decimal value = 0;

        Bar(String label) {
            this.label = label;
        }
    }

    public class CancelMonth {
        @AuraEnabled public String label;
        @AuraEnabled public String longLabel;
        @AuraEnabled public Integer count = 0;
        @AuraEnabled public Decimal value = 0;
        @AuraEnabled public Boolean current = false;
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String kind;

        Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class FilterOptions {
        @AuraEnabled public List<Option> projects = new List<Option>();
        @AuraEnabled public List<Option> cities = new List<Option>();
        @AuraEnabled public List<Option> owners = new List<Option>();
        @AuraEnabled public List<Option> sources = new List<Option>();
        @AuraEnabled public List<Option> configurations = new List<Option>();
        @AuraEnabled public List<Option> channels = new List<Option>();
        @AuraEnabled public Id me;
    }

    /** What the dashboard is filtered on. Blank means everything. */
    public class Filters {
        public String period;
        public Date fromDate;
        public Date toDate;
        public String projectId;
        public String city;
        public String ownerId;
        public String leadSource;
        public String configuration;
        // 'ch:<channel>' or 'cp:<campaign id>'
        public String channel;
    }

    public class AgendaItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String subtitle;
        @AuraEnabled public Datetime at;
        @AuraEnabled public Date lastTouched;
        @AuraEnabled public String status;
    }

    public class DashboardData {
        @AuraEnabled public String firstName;
        @AuraEnabled public String period;
        @AuraEnabled public String scope;
        @AuraEnabled public String periodLabel;
        @AuraEnabled public String previousLabel;
        @AuraEnabled public Date periodStart;
        @AuraEnabled public Date periodEnd;
        @AuraEnabled public List<Tile> tiles = new List<Tile>();
        @AuraEnabled public List<Month> months = new List<Month>();
        @AuraEnabled public List<Stage> funnel = new List<Stage>();
        @AuraEnabled public List<Source> sources = new List<Source>();
        @AuraEnabled public Collection collection = new Collection();
        @AuraEnabled public List<Day> days = new List<Day>();
        @AuraEnabled public List<Inventory> inventory = new List<Inventory>();
        @AuraEnabled public List<Leader> leaders = new List<Leader>();
        @AuraEnabled public List<AgendaItem> visits = new List<AgendaItem>();
        @AuraEnabled public List<AgendaItem> coldLeads = new List<AgendaItem>();
        @AuraEnabled public Integer pendingBookings = 0;
        @AuraEnabled public List<TargetMonth> targets = new List<TargetMonth>();
        @AuraEnabled public String targetLabel;
        @AuraEnabled public Boolean hasTargets = false;
        @AuraEnabled public List<ProjectRow> projects = new List<ProjectRow>();
        @AuraEnabled public List<Bar> pipeline = new List<Bar>();
        @AuraEnabled public List<Bar> lostReasons = new List<Bar>();
        @AuraEnabled public List<Bar> dropReasons = new List<Bar>();
        @AuraEnabled public List<CancelMonth> cancellations = new List<CancelMonth>();
        @AuraEnabled public Integer cancelledInPeriod = 0;
        @AuraEnabled public Decimal cancelledValueInPeriod = 0;
        @AuraEnabled public Integer activeFilters = 0;
    }

    public class Window {
        public Date startDate;
        public Date endDate;
        public Date prevStart;
        public Date prevEnd; // same elapsed point in the previous period
        public String label;
        public String previousLabel;
    }

    // ---------- Filter options ----------

    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        try {
            FilterOptions o = new FilterOptions();
            o.me = UserInfo.getUserId();
            Set<String> cities = new Set<String>();
            for (Property__c p : [SELECT Id, Name, Location__City__s FROM Property__c ORDER BY Name LIMIT 200]) {
                o.projects.add(new Option(p.Name, p.Id));
                String city = normalCity(p.Location__City__s);
                if (city != null) {
                    cities.add(city);
                }
            }
            List<String> cityList = new List<String>(cities);
            cityList.sort();
            for (String c : cityList) {
                o.cities.add(new Option(c, c));
            }

            // Anyone who owns residential leads, opportunities or bookings.
            Set<Id> ownerIds = new Set<Id>();
            for (AggregateResult ar : [SELECT OwnerId o FROM Booking__c GROUP BY OwnerId LIMIT 200]) {
                ownerIds.add((Id) ar.get('o'));
            }
            for (AggregateResult ar : [SELECT OwnerId o FROM Opportunity WHERE RecordType.DeveloperName = :RESI_OPP_RT GROUP BY OwnerId LIMIT 200]) {
                ownerIds.add((Id) ar.get('o'));
            }
            for (AggregateResult ar : [SELECT OwnerId o FROM Lead WHERE RecordType.DeveloperName = :RESI_LEAD_RT GROUP BY OwnerId LIMIT 200]) {
                ownerIds.add((Id) ar.get('o'));
            }
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :ownerIds AND IsActive = true ORDER BY Name]) {
                o.owners.add(new Option(u.Id == o.me ? u.Name + ' (me)' : u.Name, u.Id));
            }

            for (Schema.PicklistEntry e : Lead.LeadSource.getDescribe().getPicklistValues()) {
                if (e.isActive()) {
                    o.sources.add(new Option(e.getLabel(), e.getValue()));
                }
            }

            Set<String> configs = new Set<String>();
            for (AggregateResult ar : [SELECT BHK_Configuration__c c FROM Unit__c WHERE BHK_Configuration__c != null GROUP BY BHK_Configuration__c]) {
                configs.add(configBucket((String) ar.get('c')));
            }
            for (Schema.PicklistEntry e : Lead.Type_of_Units__c.getDescribe().getPicklistValues()) {
                if (e.isActive()) {
                    configs.add(configBucket(e.getValue()));
                }
            }
            configs.remove(null);
            List<String> configList = new List<String>(configs);
            configList.sort();
            for (String c : configList) {
                o.configurations.add(new Option(c, c));
            }

            for (String ch : new List<String>{ CHANNEL_DIRECT, CHANNEL_PARTNER, CHANNEL_REFERRAL }) {
                Option opt = new Option(ch, 'ch:' + ch);
                opt.kind = 'Channel';
                o.channels.add(opt);
            }
            Set<Id> campaignIds = new Set<Id>();
            for (AggregateResult ar : [
                SELECT CampaignId c FROM Opportunity
                WHERE RecordType.DeveloperName = :RESI_OPP_RT AND CampaignId != null GROUP BY CampaignId LIMIT 100
            ]) {
                campaignIds.add((Id) ar.get('c'));
            }
            for (AggregateResult ar : [
                SELECT CampaignId c FROM CampaignMember
                WHERE LeadId != null AND Lead.RecordType.DeveloperName = :RESI_LEAD_RT GROUP BY CampaignId LIMIT 100
            ]) {
                campaignIds.add((Id) ar.get('c'));
            }
            for (Campaign c : [SELECT Id, Name FROM Campaign WHERE Id IN :campaignIds ORDER BY Name]) {
                Option opt = new Option(c.Name, 'cp:' + c.Id);
                opt.kind = 'Campaign';
                o.channels.add(opt);
            }
            return o;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ---------- Dashboard ----------

    /** Kept for the original Team / Mine toggle. */
    @AuraEnabled
    public static DashboardData getDashboard(String period, String scope) {
        Filters f = new Filters();
        f.period = period;
        if (scope == 'mine') {
            f.ownerId = UserInfo.getUserId();
        }
        DashboardData d = build(f);
        d.scope = scope == 'mine' ? 'mine' : 'team';
        return d;
    }

    @AuraEnabled
    public static DashboardData getSalesDashboard(String filtersJson) {
        Filters f = String.isBlank(filtersJson) ? new Filters() : (Filters) JSON.deserialize(filtersJson, Filters.class);
        return build(f);
    }

    /** Matches records against the active filters. */
    private class FilterMatch {
        Filters f;
        Id projectId;
        Id ownerId;
        String city;
        String channel;
        Id campaignId;
        Map<Id, String> cityByProject = new Map<Id, String>();
        Map<String, Id> projectByName = new Map<String, Id>();
        Map<Id, String> nameByProject = new Map<Id, String>();

        FilterMatch(Filters f) {
            this.f = f;
            projectId = idOrNull(f.projectId);
            ownerId = idOrNull(f.ownerId);
            city = String.isBlank(f.city) ? null : f.city;
            if (String.isNotBlank(f.channel) && f.channel.startsWith('ch:')) {
                channel = f.channel.substring(3);
            } else if (String.isNotBlank(f.channel) && f.channel.startsWith('cp:')) {
                campaignId = idOrNull(f.channel.substring(3));
            }
            for (Property__c p : [SELECT Id, Name, Location__City__s FROM Property__c LIMIT 500]) {
                cityByProject.put(p.Id, normalCity(p.Location__City__s));
                projectByName.put(p.Name, p.Id);
                nameByProject.put(p.Id, p.Name);
            }
        }

        Boolean anyRecordFilter() {
            return projectId != null || ownerId != null || city != null || String.isNotBlank(f.leadSource)
                || String.isNotBlank(f.configuration) || channel != null || campaignId != null;
        }

        Integer count() {
            Integer n = 0;
            for (Object v : new List<Object>{ projectId, ownerId, city, blankToNull(f.leadSource), blankToNull(f.configuration), channel, campaignId }) {
                if (v != null) {
                    n++;
                }
            }
            return n;
        }

        /** Units carry only project and configuration. */
        Boolean unit(Id unitProject, String config) {
            return place(unitProject, null) && sameConfig(config);
        }

        Boolean place(Id recProject, String fallbackCity) {
            if (projectId != null && recProject != projectId) {
                return false;
            }
            if (city != null) {
                String c = recProject != null ? cityByProject.get(recProject) : normalCity(fallbackCity);
                if (c != city) {
                    return false;
                }
            }
            return true;
        }

        Boolean sameConfig(String config) {
            return String.isBlank(f.configuration) || configBucket(config) == f.configuration;
        }

        Boolean all(Id recProject, String fallbackCity, Id recOwner, String source, String config, String recChannel, Id recCampaign, Boolean ignoreOwner) {
            if (!place(recProject, fallbackCity)) {
                return false;
            }
            if (!ignoreOwner && ownerId != null && recOwner != ownerId) {
                return false;
            }
            if (String.isNotBlank(f.leadSource) && source != f.leadSource) {
                return false;
            }
            if (!sameConfig(config)) {
                return false;
            }
            if (channel != null && recChannel != channel) {
                return false;
            }
            if (campaignId != null && recCampaign != campaignId) {
                return false;
            }
            return true;
        }
    }

    private static DashboardData build(Filters f) {
        try {
            DashboardData d = new DashboardData();
            d.firstName = UserInfo.getFirstName();
            Date today = Date.today();
            Window w;
            if (f.period == 'custom' && f.fromDate != null && f.toDate != null && f.fromDate <= f.toDate) {
                w = customWindow(f.fromDate, f.toDate);
                d.period = 'custom';
            } else {
                d.period = f.period == 'month' || f.period == 'quarter' ? f.period : 'fy';
                w = window(d.period, today);
            }
            FilterMatch mt = new FilterMatch(f);
            Id me = UserInfo.getUserId();
            d.scope = mt.ownerId == null ? 'team' : (mt.ownerId == me ? 'mine' : 'owner');
            d.activeFilters = mt.count();
            d.periodLabel = w.label;
            d.previousLabel = w.previousLabel;
            d.periodStart = w.startDate;
            d.periodEnd = w.endDate;

            // The 12-month charts end at the period end (today for running periods).
            Date anchor = w.endDate < today ? w.endDate : today;
            Date sparkStart = anchor.toStartOfMonth().addMonths(-11);
            Date earliest = sparkStart < w.prevStart ? sparkStart : w.prevStart;

            Map<String, Month> monthByKey = new Map<String, Month>();
            Map<String, CancelMonth> cancelByKey = new Map<String, CancelMonth>();
            for (Integer i = 0; i < 12; i++) {
                Date m = sparkStart.addMonths(i);
                Month mo = new Month();
                mo.label = MONTHS[m.month() - 1];
                mo.longLabel = MONTHS[m.month() - 1] + ' ' + m.year();
                mo.current = i == 11;
                monthByKey.put(monthKey(m), mo);
                d.months.add(mo);
                CancelMonth cm = new CancelMonth();
                cm.label = mo.label;
                cm.longLabel = mo.longLabel;
                cm.current = mo.current;
                cancelByKey.put(monthKey(m), cm);
                d.cancellations.add(cm);
            }

            // Target vs actual runs over the financial year that holds the period end.
            Integer fyYear = anchor.month() >= FY_START_MONTH ? anchor.year() : anchor.year() - 1;
            Date fyStart = Date.newInstance(fyYear, FY_START_MONTH, 1);
            d.targetLabel = 'FY ' + fyYear + '–' + String.valueOf(fyYear + 1).right(2);
            Map<String, TargetMonth> targetByKey = new Map<String, TargetMonth>();
            for (Integer i = 0; i < 12; i++) {
                Date m = fyStart.addMonths(i);
                TargetMonth tm = new TargetMonth();
                tm.label = MONTHS[m.month() - 1];
                tm.longLabel = MONTHS[m.month() - 1] + ' ' + m.year();
                tm.current = m == today.toStartOfMonth();
                tm.future = m > today;
                targetByKey.put(monthKey(m), tm);
                d.targets.add(tm);
            }

            Tile booked = new Tile('booked', 'Booked value', 'inr');
            Tile units = new Tile('units', 'Units booked', 'count');
            Tile collected = new Tile('collected', 'Collections', 'inr');
            Tile visits = new Tile('visits', 'Site visits done', 'count');
            Integer[] visitSpark = new Integer[]{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

            Map<Id, ProjectRow> projectRows = new Map<Id, ProjectRow>();
            for (Id pid : mt.nameByProject.keySet()) {
                if (mt.place(pid, null)) {
                    ProjectRow pr = new ProjectRow();
                    pr.id = pid;
                    pr.name = mt.nameByProject.get(pid);
                    pr.city = mt.cityByProject.get(pid);
                    projectRows.put(pid, pr);
                }
            }

            // ---------- Bookings ----------
            Map<Id, Leader> leaderByOwner = new Map<Id, Leader>();
            Set<Id> bookedOpportunityIds = new Set<Id>();
            Map<Id, Decimal> bookedValueByOpp = new Map<Id, Decimal>();
            // Booking id -> passes every filter (owner included); used by receipts and demands.
            Map<Id, Boolean> bookingPasses = new Map<Id, Boolean>();
            Map<Id, Id> bookingProject = new Map<Id, Id>();
            Map<Id, Id> bookingByAccount = new Map<Id, Id>();
            List<Booking__c> bookings = stubBookings != null ? stubBookings : [
                SELECT Id, OwnerId, Owner.Name, Final_Amount__c, Status__c, Booking_Date__c, CreatedDate, LastModifiedDate,
                       Opportunity_Id__c, Account_Id__c, Project__c, Unit_Id__r.BHK_Configuration__c, Distribution_channel__c,
                       Booking_Cancellation_Date__c, Approved_Channel_Partner__c,
                       Opportunity_Id__r.LeadSource, Opportunity_Id__r.CampaignId, Opportunity_Id__r.Approved_Channel_Partner__c
                FROM Booking__c
                LIMIT 5000
            ];
            for (Booking__c b : bookings) {
                Opportunity o = b.Opportunity_Id__r;
                String source = o?.LeadSource;
                String ch = channelOf(b.Distribution_channel__c, b.Approved_Channel_Partner__c != null || o?.Approved_Channel_Partner__c != null, source);
                String config = b.Unit_Id__r?.BHK_Configuration__c;
                Id campaign = o?.CampaignId;
                Boolean passes = mt.all(b.Project__c, null, b.OwnerId, source, config, ch, campaign, false);
                Boolean passesTeam = mt.all(b.Project__c, null, b.OwnerId, source, config, ch, campaign, true);
                if (b.Id != null) {
                    bookingPasses.put(b.Id, passes);
                    bookingProject.put(b.Id, b.Project__c);
                    if (b.Account_Id__c != null && !bookingByAccount.containsKey(b.Account_Id__c)) {
                        bookingByAccount.put(b.Account_Id__c, b.Id);
                    }
                }
                Decimal amount = b.Final_Amount__c == null ? 0 : b.Final_Amount__c;

                if (b.Status__c == CANCELLED) {
                    if (!passes) {
                        continue;
                    }
                    Date cancelledOn = b.Booking_Cancellation_Date__c != null ? b.Booking_Cancellation_Date__c
                        : (b.LastModifiedDate != null ? b.LastModifiedDate.date() : b.CreatedDate.date());
                    CancelMonth cm = cancelByKey.get(monthKey(cancelledOn));
                    if (cm != null) {
                        cm.count++;
                        cm.value += amount;
                    }
                    if (inRange(cancelledOn, w.startDate, w.endDate)) {
                        d.cancelledInPeriod++;
                        d.cancelledValueInPeriod += amount;
                    }
                    continue;
                }

                Date onDate = b.Booking_Date__c != null ? b.Booking_Date__c : b.CreatedDate.date();
                if (passesTeam && inRange(onDate, w.startDate, w.endDate)) {
                    Leader l = leaderFor(leaderByOwner, b.OwnerId, b.Owner?.Name, me);
                    l.value += amount;
                    l.bookings++;
                }
                if (!passes) {
                    continue;
                }
                if (b.Opportunity_Id__c != null) {
                    bookedOpportunityIds.add(b.Opportunity_Id__c);
                    bookedValueByOpp.put(b.Opportunity_Id__c, amount);
                }
                if (b.Status__c == 'Pending Confirmation') {
                    d.pendingBookings++;
                }
                TargetMonth tm = targetByKey.get(monthKey(onDate));
                if (tm != null) {
                    tm.actual += amount;
                    tm.units++;
                }
                if (inRange(onDate, w.startDate, w.endDate)) {
                    ProjectRow pr = projectRows.get(b.Project__c);
                    if (pr != null) {
                        pr.bookings++;
                        pr.booked += amount;
                    }
                }
                if (onDate < earliest) {
                    continue;
                }
                if (inRange(onDate, w.startDate, w.endDate)) {
                    booked.value += amount;
                    units.value++;
                } else if (inRange(onDate, w.prevStart, w.prevEnd)) {
                    booked.previous += amount;
                    units.previous++;
                }
                Month mo = monthByKey.get(monthKey(onDate));
                if (mo != null) {
                    mo.booked += amount;
                    mo.bookings++;
                }
            }

            // ---------- Collections ----------
            List<Payment_Receipt__c> receipts = stubReceipts != null ? stubReceipts : [
                SELECT Account__c, Amount_Paid__c, Date_Of_Payment__c, CreatedDate,
                       Booking_Payment_Schedule__r.Booking__c, Demand__r.Booking_Id__c
                FROM Payment_Receipt__c
                WHERE Approval_Status__c = 'Approved'
                LIMIT 5000
            ];
            Boolean filtered = mt.anyRecordFilter();
            for (Payment_Receipt__c r : receipts) {
                Id bookingId = r.Booking_Payment_Schedule__r?.Booking__c;
                if (bookingId == null) {
                    bookingId = r.Demand__r?.Booking_Id__c;
                }
                if (bookingId == null && r.Account__c != null) {
                    bookingId = bookingByAccount.get(r.Account__c);
                }
                if (filtered && (bookingId == null || bookingPasses.get(bookingId) != true)) {
                    continue;
                }
                Date onDate = r.Date_Of_Payment__c != null ? r.Date_Of_Payment__c : r.CreatedDate.date();
                Decimal amount = r.Amount_Paid__c == null ? 0 : r.Amount_Paid__c;
                if (inRange(onDate, w.startDate, w.endDate)) {
                    collected.value += amount;
                    ProjectRow pr = bookingId == null ? null : projectRows.get(bookingProject.get(bookingId));
                    if (pr != null) {
                        pr.collected += amount;
                    }
                } else if (inRange(onDate, w.prevStart, w.prevEnd)) {
                    collected.previous += amount;
                }
                Month mo = monthByKey.get(monthKey(onDate));
                if (mo != null) {
                    mo.collected += amount;
                    mo.receipts++;
                }
            }

            // ---------- Demands: collection efficiency and overdue ageing ----------
            Collection c = d.collection;
            List<Demand__c> demands = stubDemands != null ? stubDemands : [
                SELECT Demand_Amount__c, Total_Value__c, Total_Amount_Recieved__c, Due_Date__c, Booking_Id__c
                FROM Demand__c
                WHERE Due_Date__c != null AND Due_Date__c <= :today.addDays(30)
                LIMIT 5000
            ];
            for (Demand__c dm : demands) {
                if (filtered && (dm.Booking_Id__c == null || bookingPasses.get(dm.Booking_Id__c) != true)) {
                    continue;
                }
                Decimal amount = dm.Demand_Amount__c != null ? dm.Demand_Amount__c : (dm.Total_Value__c == null ? 0 : dm.Total_Value__c);
                Decimal paid = dm.Total_Amount_Recieved__c == null ? 0 : dm.Total_Amount_Recieved__c;
                Decimal open = Math.max(0, amount - paid);
                if (dm.Due_Date__c > today) {
                    if (open > 0) {
                        c.upcoming += open;
                        c.upcomingCount++;
                    }
                    continue;
                }
                c.due += amount;
                c.received += Math.min(paid, amount);
                if (open > 0) {
                    c.overdue += open;
                    Integer late = dm.Due_Date__c.daysBetween(today);
                    Bucket bucket = c.buckets[late <= 30 ? 0 : late <= 60 ? 1 : late <= 90 ? 2 : 3];
                    bucket.amount += open;
                    bucket.count++;
                }
            }

            // ---------- Site visits: tile, heatmap, agenda ----------
            Date heatStart = anchor.toStartOfWeek().addDays(-7 * 12);
            // toStartOfWeek is locale dependent; pin the grid to Monday.
            while (Math.mod(Date.newInstance(1900, 1, 1).daysBetween(heatStart), 7) != 0) {
                heatStart = heatStart.addDays(-1);
            }
            Map<Date, Day> dayByDate = new Map<Date, Day>();
            for (Integer i = 0; i < 91; i++) {
                Day dy = new Day();
                dy.day = heatStart.addDays(i);
                dy.future = dy.day > today;
                dy.today = dy.day == today;
                dayByDate.put(dy.day, dy);
                d.days.add(dy);
            }
            Datetime horizon = Datetime.newInstance(today.addDays(15), Time.newInstance(0, 0, 0, 0));
            Set<Id> visitedLeads = new Set<Id>();
            for (Site_Visit__c v : [
                SELECT Id, Name, OwnerId, Owner.Name, Status__c, Visit_DateTime__c, Visit_Date__c, CreatedDate,
                       Project__c, Project__r.Name, Lead__c, Lead__r.Name, Opportunity__r.Name, Interest_Level__c,
                       Unit__r.BHK_Configuration__c, Lead__r.LeadSource, Lead__r.Type_of_Units__c, Lead__r.Approved_Channel_Partner__c,
                       Opportunity__r.LeadSource, Opportunity__r.CampaignId, Opportunity__r.Approved_Channel_Partner__c
                FROM Site_Visit__c
                LIMIT 5000
            ]) {
                if (v.Lead__c != null) {
                    visitedLeads.add(v.Lead__c);
                }
                String source = v.Opportunity__r?.LeadSource != null ? v.Opportunity__r.LeadSource : v.Lead__r?.LeadSource;
                String config = v.Unit__r?.BHK_Configuration__c != null ? v.Unit__r.BHK_Configuration__c : v.Lead__r?.Type_of_Units__c;
                Boolean partner = v.Lead__r?.Approved_Channel_Partner__c != null || v.Opportunity__r?.Approved_Channel_Partner__c != null;
                String ch = channelOf(null, partner, source);
                Id campaign = v.Opportunity__r?.CampaignId;
                Boolean passesTeam = mt.all(v.Project__c, null, v.OwnerId, source, config, ch, campaign, true);
                if (!passesTeam) {
                    continue;
                }
                Datetime at = v.Visit_DateTime__c != null ? v.Visit_DateTime__c
                    : v.Visit_Date__c != null ? Datetime.newInstance(v.Visit_Date__c, Time.newInstance(10, 0, 0, 0))
                    : v.CreatedDate;
                Date onDate = at.date();
                Boolean done = v.Status__c == 'Completed';
                if (done && inRange(onDate, w.startDate, w.endDate) && String.valueOf(v.OwnerId).startsWith('005')) {
                    leaderFor(leaderByOwner, v.OwnerId, v.Owner?.Name, me).visits++;
                }
                if (mt.ownerId != null && v.OwnerId != mt.ownerId) {
                    continue;
                }
                Day dy = dayByDate.get(onDate);
                if (dy != null) {
                    dy.visits++;
                    if (done) {
                        dy.completed++;
                    }
                }
                if (done) {
                    if (inRange(onDate, w.startDate, w.endDate)) {
                        visits.value++;
                        ProjectRow pr = projectRows.get(v.Project__c);
                        if (pr != null) {
                            pr.visits++;
                        }
                    } else if (inRange(onDate, w.prevStart, w.prevEnd)) {
                        visits.previous++;
                    }
                    Integer idx = sparkStart.monthsBetween(onDate);
                    if (onDate >= sparkStart && idx >= 0 && idx < 12) {
                        visitSpark[idx]++;
                    }
                }
                if (v.Status__c == 'Scheduled' && at >= Datetime.now().addHours(-2) && at < horizon) {
                    AgendaItem a = new AgendaItem();
                    a.id = v.Id;
                    a.title = v.Lead__r?.Name != null ? v.Lead__r.Name : v.Opportunity__r?.Name != null ? v.Opportunity__r.Name : v.Name;
                    a.subtitle = v.Project__r?.Name;
                    a.at = at;
                    a.status = v.Interest_Level__c;
                    d.visits.add(a);
                }
            }
            sortAgenda(d.visits);
            while (d.visits.size() > 5) {
                d.visits.remove(d.visits.size() - 1);
            }

            // ---------- Leads: funnel, sources, going cold, drop reasons ----------
            Stage[] stages = new Stage[]{
                new Stage('Enquiries'), new Stage('Qualified'), new Stage('Site visit'),
                new Stage('Opportunity'), new Stage('Booked')
            };
            Map<String, Source> sourceByName = new Map<String, Source>();
            Map<String, Bar> dropByReason = new Map<String, Bar>();
            Set<Id> campaignLeads = new Set<Id>();
            if (mt.campaignId != null) {
                for (CampaignMember cmb : [SELECT LeadId FROM CampaignMember WHERE CampaignId = :mt.campaignId AND LeadId != null LIMIT 10000]) {
                    campaignLeads.add(cmb.LeadId);
                }
            }
            List<Lead> leads = Database.queryWithBinds(
                'SELECT Id, Name, Status, IsConverted, ConvertedOpportunityId, LeadSource, Site_Visit_Scheduled__c, '
                    + 'Projects__c, Preferred_City__c, Type_of_Units__c, Approved_Channel_Partner__c, Drop_Reason__c, '
                    + 'LastActivityDate, LastModifiedDate, CreatedDate, OwnerId, Owner.Name FROM Lead '
                    + 'WHERE RecordType.DeveloperName = :rt AND Status != \'Archive\' LIMIT 5000',
                new Map<String, Object>{ 'rt' => RESI_LEAD_RT },
                AccessLevel.SYSTEM_MODE
            );
            Date coldBefore = today.addDays(-COLD_AFTER_DAYS);
            for (Lead l : leads) {
                Id leadProject = String.isBlank(l.Projects__c) ? null : mt.projectByName.get(l.Projects__c);
                String ch = channelOf(null, l.Approved_Channel_Partner__c != null, l.LeadSource);
                Id campaign = campaignLeads.contains(l.Id) ? mt.campaignId : null;
                if (!mt.all(leadProject, l.Preferred_City__c, l.OwnerId, l.LeadSource, l.Type_of_Units__c, ch, campaign, true)) {
                    continue;
                }
                Date created = l.CreatedDate.date();
                Boolean inPeriod = inRange(created, w.startDate, w.endDate);
                if (inPeriod && String.valueOf(l.OwnerId).startsWith('005')) {
                    leaderFor(leaderByOwner, l.OwnerId, l.Owner?.Name, me).leads++;
                }
                if (mt.ownerId != null && l.OwnerId != mt.ownerId) {
                    continue;
                }
                if (inPeriod) {
                    Integer reached = 0;
                    if (l.IsConverted || QUALIFIED_STATUSES.contains(l.Status)) {
                        reached = 1;
                    }
                    if (l.IsConverted || VISIT_STATUSES.contains(l.Status) || l.Site_Visit_Scheduled__c || visitedLeads.contains(l.Id)) {
                        reached = 2;
                    }
                    if (l.IsConverted) {
                        reached = 3;
                    }
                    Boolean wasBooked = l.ConvertedOpportunityId != null && bookedOpportunityIds.contains(l.ConvertedOpportunityId);
                    if (wasBooked) {
                        reached = 4;
                    }
                    for (Integer i = 0; i <= reached; i++) {
                        stages[i].count++;
                    }
                    String src = String.isBlank(l.LeadSource) ? 'Not captured' : l.LeadSource;
                    Source s = sourceByName.get(src);
                    if (s == null) {
                        s = new Source(src);
                        sourceByName.put(src, s);
                    }
                    s.leads++;
                    if (l.IsConverted) {
                        s.converted++;
                    }
                    if (wasBooked) {
                        s.booked++;
                        s.bookedValue += bookedValueByOpp.get(l.ConvertedOpportunityId);
                    }
                    ProjectRow pr = projectRows.get(leadProject);
                    if (pr != null) {
                        pr.leads++;
                    }
                }
                if (l.Status == 'Dropped' && inRange(l.LastModifiedDate.date(), w.startDate, w.endDate)) {
                    String reason = String.isBlank(l.Drop_Reason__c) ? 'Reason not captured' : l.Drop_Reason__c;
                    Bar bar = dropByReason.get(reason);
                    if (bar == null) {
                        bar = new Bar(reason);
                        dropByReason.put(reason, bar);
                    }
                    bar.count++;
                }
                Date touched = l.LastActivityDate != null ? l.LastActivityDate : l.LastModifiedDate.date();
                if (!l.IsConverted && OPEN_LEAD_STATUSES.contains(l.Status) && touched <= coldBefore) {
                    AgendaItem a = new AgendaItem();
                    a.id = l.Id;
                    a.title = l.Name;
                    a.subtitle = l.Projects__c;
                    a.lastTouched = touched;
                    a.status = l.Status;
                    d.coldLeads.add(a);
                }
            }
            d.funnel = stages;
            d.sources = sourceByName.values();
            sortSources(d.sources);
            sortCold(d.coldLeads);
            while (d.coldLeads.size() > 5) {
                d.coldLeads.remove(d.coldLeads.size() - 1);
            }
            d.dropReasons = dropByReason.values();
            sortBars(d.dropReasons);

            // ---------- Residential opportunities: pipeline by stage, lost reasons ----------
            Map<String, Bar> stageBars = new Map<String, Bar>();
            for (Schema.PicklistEntry e : Opportunity.StageName.getDescribe().getPicklistValues()) {
                if (e.isActive()) {
                    stageBars.put(e.getValue(), new Bar(e.getLabel()));
                }
            }
            Map<String, Bar> lostByReason = new Map<String, Bar>();
            for (Opportunity o : [
                SELECT Id, OwnerId, Owner.Name, StageName, IsClosed, IsWon, Total_Amount__c, Amount, CloseDate, LeadSource,
                       CampaignId, Approved_Channel_Partner__c, SDO_Sales_Reason_Lost__c,
                       Interested_Unit__r.Property__c, Interested_Unit__r.BHK_Configuration__c
                FROM Opportunity
                WHERE RecordType.DeveloperName = :RESI_OPP_RT
                LIMIT 5000
            ]) {
                String ch = channelOf(null, o.Approved_Channel_Partner__c != null, o.LeadSource);
                if (!mt.all(o.Interested_Unit__r?.Property__c, null, o.OwnerId, o.LeadSource, o.Interested_Unit__r?.BHK_Configuration__c, ch, o.CampaignId, true)) {
                    continue;
                }
                Decimal value = o.Total_Amount__c != null && o.Total_Amount__c > 0 ? o.Total_Amount__c : (o.Amount == null ? 0 : o.Amount);
                if (!o.IsClosed) {
                    leaderFor(leaderByOwner, o.OwnerId, o.Owner?.Name, me).openDeals++;
                }
                if (mt.ownerId != null && o.OwnerId != mt.ownerId) {
                    continue;
                }
                if (!o.IsClosed) {
                    Bar bar = stageBars.get(o.StageName);
                    if (bar == null) {
                        bar = new Bar(o.StageName);
                        stageBars.put(o.StageName, bar);
                    }
                    bar.count++;
                    bar.value += value;
                } else if (!o.IsWon && inRange(o.CloseDate, w.startDate, w.endDate)) {
                    String reason = String.isBlank(o.SDO_Sales_Reason_Lost__c) ? 'Reason not captured' : o.SDO_Sales_Reason_Lost__c;
                    Bar bar = lostByReason.get(reason);
                    if (bar == null) {
                        bar = new Bar(reason);
                        lostByReason.put(reason, bar);
                    }
                    bar.count++;
                    bar.value += value;
                }
            }
            for (Bar bar : stageBars.values()) {
                if (bar.count > 0) {
                    d.pipeline.add(bar);
                }
            }
            d.lostReasons = lostByReason.values();
            sortBars(d.lostReasons);

            // ---------- Targets ----------
            List<Sales_Target__c> targets = stubTargets != null ? stubTargets : [
                SELECT Month__c, Sales_Executive__c, Project__c, Target_Value__c, Target_Units__c
                FROM Sales_Target__c
                WHERE Month__c >= :fyStart AND Month__c < :fyStart.addMonths(12)
                LIMIT 5000
            ];
            for (Sales_Target__c t : targets) {
                // Team-level targets (no project) drop out once a project or location is picked.
                if (t.Month__c == null || !mt.place(t.Project__c, null)) {
                    continue;
                }
                if (t.Sales_Executive__c != null) {
                    Leader l = leaderByOwner.get(t.Sales_Executive__c);
                    if (l != null && inRange(t.Month__c, w.startDate.toStartOfMonth(), w.endDate)) {
                        l.target += t.Target_Value__c == null ? 0 : t.Target_Value__c;
                    }
                }
                if (mt.ownerId != null && t.Sales_Executive__c != mt.ownerId) {
                    continue;
                }
                TargetMonth tm = targetByKey.get(monthKey(t.Month__c));
                if (tm != null) {
                    tm.target += t.Target_Value__c == null ? 0 : t.Target_Value__c;
                    tm.targetUnits += t.Target_Units__c == null ? 0 : t.Target_Units__c;
                    d.hasTargets = true;
                }
            }

            // ---------- Inventory by configuration and project (always the whole stock) ----------
            Map<String, Inventory> invByConfig = new Map<String, Inventory>();
            for (AggregateResult ar : [
                SELECT Property__c p, BHK_Configuration__c cfg, Status__c s, COUNT(Id) c
                FROM Unit__c
                GROUP BY Property__c, BHK_Configuration__c, Status__c
            ]) {
                Id pid = (Id) ar.get('p');
                String rawCfg = (String) ar.get('cfg');
                if (!mt.unit(pid, rawCfg)) {
                    continue;
                }
                String cfg = rawCfg == null ? 'Other' : rawCfg;
                String s = (String) ar.get('s');
                Integer n = (Integer) ar.get('c');
                Inventory inv = invByConfig.get(cfg);
                if (inv == null) {
                    inv = new Inventory(cfg);
                    invByConfig.put(cfg, inv);
                }
                if (s == 'Available') {
                    inv.available += n;
                } else if (HELD_UNIT_STATUSES.contains(s)) {
                    inv.held += n;
                } else {
                    inv.booked += n;
                }
                inv.total += n;
                ProjectRow pr = projectRows.get(pid);
                if (pr != null) {
                    pr.units += n;
                    if (s == 'Available') {
                        pr.available += n;
                    }
                }
            }
            d.inventory = invByConfig.values();
            sortInventory(d.inventory);

            for (ProjectRow pr : projectRows.values()) {
                if (pr.units > 0 || pr.leads > 0 || pr.bookings > 0 || pr.visits > 0) {
                    d.projects.add(pr);
                }
            }
            sortProjects(d.projects);

            // ---------- Sales executives (always the team) ----------
            for (Id ownerId : new List<Id>(leaderByOwner.keySet())) {
                Leader l = leaderByOwner.get(ownerId);
                if (l.name == null) {
                    leaderByOwner.remove(ownerId);
                }
            }
            d.leaders = leaderByOwner.values();
            sortLeaders(d.leaders);
            while (d.leaders.size() > 8) {
                d.leaders.remove(d.leaders.size() - 1);
            }

            // ---------- Tiles ----------
            for (Integer i = 0; i < 12; i++) {
                Month mo = d.months[i];
                booked.spark.add(mo.booked);
                units.spark.add(mo.bookings);
                collected.spark.add(mo.collected);
                visits.spark.add(visitSpark[i]);
            }
            booked.caption = 'Agreement value, cancellations excluded';
            units.caption = d.pendingBookings + ' awaiting confirmation';
            collected.caption = 'Approved receipts';
            visits.caption = d.visits.size() + ' scheduled in the next 2 weeks';
            d.tiles = new List<Tile>{ booked, units, collected, visits };
            return d;
        } catch (Exception e) {
            AuraHandledException ex = new AuraHandledException(e.getMessage());
            ex.setMessage(e.getMessage());
            throw ex;
        }
    }

    private static Leader leaderFor(Map<Id, Leader> leaders, Id ownerId, String name, Id me) {
        Leader l = leaders.get(ownerId);
        if (l == null) {
            l = new Leader();
            l.id = ownerId;
            l.me = ownerId == me;
            leaders.put(ownerId, l);
        }
        if (l.name == null && name != null) {
            l.name = name;
        }
        return l;
    }

    // ---------- Classification ----------

    /** Booking channel, or the closest read of it from the lead source and channel partner. */
    @TestVisible
    private static String channelOf(String distributionChannel, Boolean hasPartner, String leadSource) {
        if (distributionChannel == 'Channel sale(Broker)') {
            return CHANNEL_PARTNER;
        }
        if (distributionChannel == 'Referral Sale') {
            return CHANNEL_REFERRAL;
        }
        if (distributionChannel == 'Direct Sale') {
            return CHANNEL_DIRECT;
        }
        if (hasPartner == true || PARTNER_SOURCES.contains(leadSource)) {
            return CHANNEL_PARTNER;
        }
        if (REFERRAL_SOURCES.contains(leadSource)) {
            return CHANNEL_REFERRAL;
        }
        return CHANNEL_DIRECT;
    }

    /** "3 BHK Canopy", "3BHK" -> "3 BHK"; units and leads describe configurations differently. */
    @TestVisible
    private static String configBucket(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        if (value.containsIgnoreCase('above')) {
            return value.normalizeSpace().replaceAll('(?i)(\\d)\\s*BHK', '$1 BHK');
        }
        System.Matcher m = Pattern.compile('(?i)(\\d+(?:\\.\\d+)?)\\s*BHK').matcher(value);
        return m.find() ? m.group(1) + ' BHK' : value.trim();
    }

    private static String normalCity(String city) {
        if (String.isBlank(city)) {
            return null;
        }
        String known = CITY_ALIASES.get(city.trim().toLowerCase());
        return known != null ? known : city.trim();
    }

    private static Id idOrNull(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Id.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    private static String blankToNull(String value) {
        return String.isBlank(value) ? null : value;
    }

    @TestVisible
    private static Window customWindow(Date fromDate, Date toDate) {
        Window w = new Window();
        w.startDate = fromDate;
        w.endDate = toDate;
        Integer days = fromDate.daysBetween(toDate) + 1;
        w.prevStart = fromDate.addDays(-days);
        w.prevEnd = fromDate.addDays(-1);
        Date today = Date.today();
        if (toDate > today && fromDate <= today) {
            // Same elapsed point, as for the running periods.
            Date elapsedEnd = w.prevStart.addDays(fromDate.daysBetween(today));
            w.prevEnd = elapsedEnd < w.prevEnd ? elapsedEnd : w.prevEnd;
        }
        w.label = fmt(fromDate) + ' – ' + fmt(toDate);
        w.previousLabel = 'the ' + days + ' days before';
        return w;
    }

    private static String fmt(Date d) {
        return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy');
    }

    // ---------- Period maths ----------

    @TestVisible
    private static Window window(String period, Date today) {
        Window w = new Window();
        Integer span;
        Integer fyYear = today.month() >= FY_START_MONTH ? today.year() : today.year() - 1;
        if (period == 'month') {
            span = 1;
            w.startDate = today.toStartOfMonth();
            w.label = MONTHS[today.month() - 1] + ' ' + today.year();
        } else if (period == 'quarter') {
            span = 3;
            Integer q = Math.mod(today.month() - FY_START_MONTH + 12, 12) / 3;
            w.startDate = Date.newInstance(fyYear, FY_START_MONTH, 1).addMonths(q * 3);
            w.label = 'Q' + (q + 1) + ' FY' + String.valueOf(fyYear + 1).right(2);
        } else {
            span = 12;
            w.startDate = Date.newInstance(fyYear, FY_START_MONTH, 1);
            w.label = 'FY ' + fyYear + '–' + String.valueOf(fyYear + 1).right(2);
        }
        w.endDate = w.startDate.addMonths(span).addDays(-1);
        w.prevStart = w.startDate.addMonths(-span);
        Date elapsedEnd = w.prevStart.addDays(w.startDate.daysBetween(today));
        Date prevFullEnd = w.startDate.addDays(-1);
        w.prevEnd = elapsedEnd < prevFullEnd ? elapsedEnd : prevFullEnd;
        if (period == 'month') {
            w.previousLabel = MONTHS[w.prevStart.month() - 1];
        } else if (period == 'quarter') {
            w.previousLabel = 'last quarter';
        } else {
            w.previousLabel = 'last FY';
        }
        return w;
    }

    private static Boolean inRange(Date d, Date startDate, Date endDate) {
        return d != null && d >= startDate && d <= endDate;
    }

    private static String monthKey(Date d) {
        return d.year() + '-' + d.month();
    }

    // ---------- Sorting ----------

    private static void sortSources(List<Source> rows) {
        for (Integer i = 1; i < rows.size(); i++) {
            Source cur = rows[i];
            Integer j = i - 1;
            while (j >= 0 && rows[j].leads < cur.leads) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = cur;
        }
    }

    private static void sortInventory(List<Inventory> rows) {
        for (Integer i = 1; i < rows.size(); i++) {
            Inventory cur = rows[i];
            Integer j = i - 1;
            while (j >= 0 && rows[j].total < cur.total) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = cur;
        }
    }

    private static void sortLeaders(List<Leader> rows) {
        for (Integer i = 1; i < rows.size(); i++) {
            Leader cur = rows[i];
            Integer j = i - 1;
            while (j >= 0 && (rows[j].value < cur.value || (rows[j].value == cur.value && rows[j].leads < cur.leads))) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = cur;
        }
    }

    private static void sortBars(List<Bar> rows) {
        for (Integer i = 1; i < rows.size(); i++) {
            Bar cur = rows[i];
            Integer j = i - 1;
            while (j >= 0 && rows[j].count < cur.count) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = cur;
        }
    }

    private static void sortProjects(List<ProjectRow> rows) {
        for (Integer i = 1; i < rows.size(); i++) {
            ProjectRow cur = rows[i];
            Integer j = i - 1;
            while (j >= 0 && (rows[j].booked < cur.booked || (rows[j].booked == cur.booked && rows[j].leads < cur.leads))) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = cur;
        }
    }

    private static void sortAgenda(List<AgendaItem> rows) {
        for (Integer i = 1; i < rows.size(); i++) {
            AgendaItem cur = rows[i];
            Integer j = i - 1;
            while (j >= 0 && rows[j].at > cur.at) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = cur;
        }
    }

    private static void sortCold(List<AgendaItem> rows) {
        for (Integer i = 1; i < rows.size(); i++) {
            AgendaItem cur = rows[i];
            Integer j = i - 1;
            while (j >= 0 && rows[j].lastTouched > cur.lastTouched) {
                rows[j + 1] = rows[j];
                j--;
            }
            rows[j + 1] = cur;
        }
    }
}