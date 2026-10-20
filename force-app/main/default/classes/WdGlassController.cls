/**
 * Data provider for the WarpDrive frosted-glass pages (wdGlassPage, wdGlassHome).
 * Each page key returns hero facts, KPI cards, table columns and rows in one payload
 * so the LWC can render without extra round trips.
 */
public with sharing class WdGlassController {

    private static final String RESI_LEAD_RT = 'Standard_Lead_Residential';
    private static final Set<String> CLOSED_LEAD_STATUSES = new Set<String>{
        'Converted', 'Dropped', 'Unqualified', 'Rejected', 'Lost'
    };
    private static final Integer ROW_LIMIT = 200;

    public class Kpi {
        @AuraEnabled public String label;
        @AuraEnabled public String format; // count | inr | area | text
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String text;
        @AuraEnabled public String caption;
        @AuraEnabled public Boolean live = false;

        Kpi(String label, String format, Decimal amount, String text, String caption) {
            this.label = label;
            this.format = format;
            this.amount = amount;
            this.text = text;
            this.caption = caption;
        }
    }

    public class Column {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String type; // link | text | number | area | inr | status | relative | date

        Column(String key, String label, String type) {
            this.key = key;
            this.label = label;
            this.type = type;
        }
    }

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class Bar {
        @AuraEnabled public String label;
        @AuraEnabled public Integer primary;
        @AuraEnabled public Integer secondary;
        @AuraEnabled public Integer total;

        Bar(String label, Integer primary, Integer secondary) {
            this.label = label;
            this.primary = primary;
            this.secondary = secondary;
            this.total = primary + secondary;
        }
    }

    public class PageData {
        @AuraEnabled public String eyebrow;
        @AuraEnabled public String title;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public Id recordTypeId;
        @AuraEnabled public String newLabel;
        @AuraEnabled public List<String> facts = new List<String>();
        @AuraEnabled public List<Kpi> kpis = new List<Kpi>();
        @AuraEnabled public List<Column> columns = new List<Column>();
        @AuraEnabled public List<Map<String, Object>> rows = new List<Map<String, Object>>();
        @AuraEnabled public List<Option> views = new List<Option>();
        @AuraEnabled public String view;
        @AuraEnabled public String viewLabel;
        @AuraEnabled public Integer totalRecords;
    }

    public class HomeData {
        @AuraEnabled public String firstName;
        @AuraEnabled public List<String> facts = new List<String>();
        @AuraEnabled public List<Kpi> kpis = new List<Kpi>();
        @AuraEnabled public List<Bar> inventory = new List<Bar>();
        @AuraEnabled public List<Bar> funnel = new List<Bar>();
        @AuraEnabled public List<Column> columns = new List<Column>();
        @AuraEnabled public List<Map<String, Object>> rows = new List<Map<String, Object>>();
        @AuraEnabled public Id leadRecordTypeId;
    }

    @AuraEnabled
    public static PageData getPage(String pageKey, String view) {
        try {
            switch on pageKey {
                when 'inventory' { return inventoryPage(view); }
                when 'bookings' { return bookingsPage(view); }
                when else { return leadsPage(view); }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static HomeData getHome() {
        try {
            HomeData h = new HomeData();
            h.firstName = UserInfo.getFirstName();
            h.leadRecordTypeId = leadRecordTypeId();

            LeadStats ls = new LeadStats();
            UnitStats us = new UnitStats();
            BookingStats bs = new BookingStats();

            h.facts.add(ls.open + ' open leads');
            h.facts.add(us.available + ' units available');
            h.facts.add(bs.count + ' bookings');

            Kpi openLeads = new Kpi('Open leads', 'count', ls.open, null,
                ls.fresh + ' new · ' + ls.qualified + ' qualified · ' + ls.siteVisits + ' site visits');
            openLeads.live = true;
            h.kpis.add(openLeads);
            h.kpis.add(new Kpi('Units available', 'count', us.available, null,
                'of ' + us.total + ' units across ' + us.byProject.size() + ' projects'));
            h.kpis.add(new Kpi('Booked value', 'inr', bs.value, null,
                'Final agreement value of ' + bs.count + ' bookings'));
            h.kpis.add(new Kpi('Token collected', 'inr', bs.token, null,
                'Token money received against bookings'));

            for (String project : us.byProject.keySet()) {
                Integer[] counts = us.byProject.get(project);
                h.inventory.add(new Bar(project, counts[0], counts[1]));
            }
            for (String status : new List<String>{ 'New', 'Contacted', 'Working', 'Qualified', 'Site Visit', 'Allocated', 'Converted' }) {
                Integer c = ls.byStatus.containsKey(status) ? ls.byStatus.get(status) : 0;
                h.funnel.add(new Bar(status, c, 0));
            }

            h.columns = new List<Column>{
                new Column('name', 'Booking', 'link'),
                new Column('customer', 'Customer', 'text'),
                new Column('project', 'Project', 'text'),
                new Column('unit', 'Unit', 'text'),
                new Column('amount', 'Final amount', 'inr'),
                new Column('status', 'Status', 'status'),
                new Column('bookingDate', 'Booking date', 'date')
            };
            for (Booking__c b : [
                SELECT Id, Name, Account_Id__r.Name, Project__r.Name, Unit_Id__r.Name, Final_Amount__c,
                       Status__c, Booking_Date__c, CreatedDate
                FROM Booking__c ORDER BY CreatedDate DESC LIMIT 5
            ]) {
                h.rows.add(bookingRow(b));
            }
            return h;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ---------- Leads ----------

    private static PageData leadsPage(String view) {
        PageData p = new PageData();
        p.eyebrow = 'Residential pipeline';
        p.title = 'Leads';
        p.objectApiName = 'Lead';
        p.newLabel = 'New lead';
        p.recordTypeId = leadRecordTypeId();
        p.views = new List<Option>{
            new Option('Recently Viewed', 'recent'),
            new Option('All open leads', 'open'),
            new Option('My open leads', 'mine'),
            new Option('Created this month', 'month'),
            new Option('All leads', 'all')
        };

        LeadStats ls = new LeadStats();
        UnitStats us = new UnitStats();
        BookingStats bs = new BookingStats();

        p.facts.add(ls.open + ' open leads');
        p.facts.add(ls.byProject.size() + ' projects');
        p.facts.add(us.available + ' units available');

        Kpi open = new Kpi('Open leads', 'count', ls.open, null,
            ls.fresh + ' new · ' + ls.qualified + ' qualified · ' + ls.siteVisits + ' site visits');
        open.live = true;
        p.kpis.add(open);
        String topProject = topKey(ls.byProject);
        p.kpis.add(new Kpi('Top project by demand', 'text', null,
            topProject == null ? '—' : topProject,
            topProject == null ? 'No project interest captured yet'
                : ls.byProject.get(topProject) + ' open leads interested'));
        p.kpis.add(new Kpi('Units available', 'count', us.available, null,
            'Across ' + us.byProject.size() + ' projects ready to offer'));
        p.kpis.add(new Kpi('Booked value', 'inr', bs.value, null,
            'Final agreement value across ' + bs.count + ' bookings'));

        p.columns = new List<Column>{
            new Column('name', 'Name', 'link'),
            new Column('project', 'Project', 'text'),
            new Column('unitType', 'Unit type', 'text'),
            new Column('budget', 'Budget', 'inr'),
            new Column('source', 'Source', 'text'),
            new Column('owner', 'Owner', 'text'),
            new Column('status', 'Status', 'status'),
            new Column('lastActivity', 'Last activity', 'relative'),
            new Column('created', 'Created date', 'date')
        };

        String base = 'SELECT Id, Name, Company, Projects__c, Type_of_Units__c, Budget__c, Project_Budget_Amount__c, '
            + 'LeadSource, Owner.Name, Status, LastActivityDate, LastModifiedDate, CreatedDate FROM Lead '
            + 'WHERE RecordType.DeveloperName = :rt ';
        Map<String, Object> binds = new Map<String, Object>{
            'rt' => RESI_LEAD_RT,
            'closed' => CLOSED_LEAD_STATUSES,
            'me' => UserInfo.getUserId(),
            'lim' => ROW_LIMIT
        };
        String effective = String.isBlank(view) ? 'recent' : view;
        List<Lead> leads = Database.queryWithBinds(base + leadFilter(effective), binds, AccessLevel.SYSTEM_MODE);
        if (leads.isEmpty() && effective == 'recent') {
            effective = 'open';
            leads = Database.queryWithBinds(base + leadFilter(effective), binds, AccessLevel.SYSTEM_MODE);
        }
        setView(p, effective);

        for (Lead l : leads) {
            Map<String, Object> r = new Map<String, Object>{
                'id' => l.Id,
                'name' => l.Name,
                'project' => l.Projects__c,
                'unitType' => l.Type_of_Units__c,
                'budget' => l.Budget__c != null ? (Object) l.Budget__c : (Object) l.Project_Budget_Amount__c,
                'source' => l.LeadSource,
                'owner' => l.Owner.Name,
                'status' => l.Status,
                'lastActivity' => l.LastActivityDate != null ? (Object) l.LastActivityDate : (Object) l.LastModifiedDate,
                'created' => l.CreatedDate
            };
            p.rows.add(r);
        }
        p.totalRecords = p.rows.size();
        return p;
    }

    private static String leadFilter(String view) {
        switch on view {
            when 'open' { return 'AND IsConverted = false AND Status NOT IN :closed ORDER BY CreatedDate DESC LIMIT :lim'; }
            when 'mine' { return 'AND IsConverted = false AND Status NOT IN :closed AND OwnerId = :me ORDER BY CreatedDate DESC LIMIT :lim'; }
            when 'month' { return 'AND CreatedDate = THIS_MONTH ORDER BY CreatedDate DESC LIMIT :lim'; }
            when 'all' { return 'ORDER BY CreatedDate DESC LIMIT :lim'; }
            when else { return 'AND LastViewedDate != null ORDER BY LastViewedDate DESC LIMIT :lim'; }
        }
    }

    // ---------- Inventory ----------

    private static PageData inventoryPage(String view) {
        PageData p = new PageData();
        p.eyebrow = 'Residential inventory';
        p.title = 'Inventory';
        p.objectApiName = 'Unit__c';
        p.newLabel = 'New unit';
        p.views = new List<Option>{
            new Option('All units', 'all'),
            new Option('Available', 'available'),
            new Option('Booked / blocked', 'sold'),
            new Option('Recently Viewed', 'recent')
        };

        UnitStats us = new UnitStats();
        p.facts.add(us.total + ' units');
        p.facts.add(us.byProject.size() + ' projects');
        p.facts.add(us.towers + ' buildings');

        p.kpis.add(new Kpi('Total units', 'count', us.total, null,
            us.towers + ' buildings across ' + us.byProject.size() + ' projects'));
        Kpi avail = new Kpi('Available for sale', 'count', us.available, null,
            (us.total == 0 ? 0 : Math.round(us.available * 100.0 / us.total)) + '% of inventory is open');
        avail.live = true;
        p.kpis.add(avail);
        Map<String, Integer> availableByProject = new Map<String, Integer>();
        for (String k : us.byProject.keySet()) {
            availableByProject.put(k, us.byProject.get(k)[0]);
        }
        String top = topKey(availableByProject);
        p.kpis.add(new Kpi('Most available project', 'text', null, top == null ? '—' : top,
            top == null ? 'No available units' : availableByProject.get(top) + ' units ready to offer'));
        p.kpis.add(new Kpi('Saleable area open', 'area', us.availableArea, null,
            'Saleable area of available units'));

        p.columns = new List<Column>{
            new Column('name', 'Unit', 'link'),
            new Column('project', 'Project', 'text'),
            new Column('tower', 'Building', 'text'),
            new Column('config', 'Configuration', 'text'),
            new Column('saleable', 'Saleable area', 'area'),
            new Column('carpet', 'Carpet area', 'area'),
            new Column('price', 'Total cost', 'inr'),
            new Column('status', 'Status', 'status'),
            new Column('statusDate', 'Status since', 'date')
        };

        String base = 'SELECT Id, Name, Property__r.Name, Tower__r.Name, BHK_Configuration__c, Unit_Type__c, '
            + 'Saleable_Area__c, Carpet_Area__c, Total_Cost__c, Status__c, Status_Effective_Date__c, LastModifiedDate '
            + 'FROM Unit__c ';
        String filter;
        switch on (String.isBlank(view) ? 'all' : view) {
            when 'available' { filter = 'WHERE Status__c = \'Available\' ORDER BY Property__r.Name, Name LIMIT :lim'; }
            when 'sold' { filter = 'WHERE Status__c != \'Available\' ORDER BY Property__r.Name, Name LIMIT :lim'; }
            when 'recent' { filter = 'WHERE LastViewedDate != null ORDER BY LastViewedDate DESC LIMIT :lim'; }
            when else { filter = 'ORDER BY Property__r.Name, Name LIMIT :lim'; }
        }
        setView(p, String.isBlank(view) ? 'all' : view);

        for (Unit__c u : (List<Unit__c>) Database.queryWithBinds(base + filter, new Map<String, Object>{ 'lim' => ROW_LIMIT }, AccessLevel.SYSTEM_MODE)) {
            p.rows.add(new Map<String, Object>{
                'id' => u.Id,
                'name' => u.Name,
                'project' => u.Property__r?.Name,
                'tower' => u.Tower__r?.Name,
                'config' => u.BHK_Configuration__c != null ? u.BHK_Configuration__c : u.Unit_Type__c,
                'saleable' => u.Saleable_Area__c,
                'carpet' => u.Carpet_Area__c,
                'price' => (u.Total_Cost__c == null || u.Total_Cost__c == 0) ? null : u.Total_Cost__c,
                'status' => u.Status__c,
                'statusDate' => u.Status_Effective_Date__c
            });
        }
        p.totalRecords = p.rows.size();
        return p;
    }

    // ---------- Bookings ----------

    private static PageData bookingsPage(String view) {
        PageData p = new PageData();
        p.eyebrow = 'Sales & collections';
        p.title = 'Bookings';
        p.objectApiName = 'Booking__c';
        p.newLabel = 'New booking';
        p.views = new List<Option>{
            new Option('All bookings', 'all'),
            new Option('Pending confirmation', 'pending'),
            new Option('Recently Viewed', 'recent')
        };

        BookingStats bs = new BookingStats();
        p.facts.add(bs.count + ' bookings');
        p.facts.add(bs.byProject.size() + ' projects');
        p.facts.add(bs.pending + ' pending confirmation');

        Kpi count = new Kpi('Bookings', 'count', bs.count, null, bs.pending + ' pending confirmation');
        count.live = true;
        p.kpis.add(count);
        p.kpis.add(new Kpi('Booked value', 'inr', bs.value, null, 'Final agreement value'));
        p.kpis.add(new Kpi('Token collected', 'inr', bs.token, null, 'Token money received so far'));
        String top = topKey(bs.byProject);
        p.kpis.add(new Kpi('Top project by bookings', 'text', null, top == null ? '—' : top,
            top == null ? 'No bookings yet' : bs.byProject.get(top) + ' bookings'));

        p.columns = new List<Column>{
            new Column('name', 'Booking', 'link'),
            new Column('customer', 'Customer', 'text'),
            new Column('project', 'Project', 'text'),
            new Column('unit', 'Unit', 'text'),
            new Column('amount', 'Final amount', 'inr'),
            new Column('token', 'Token amount', 'inr'),
            new Column('status', 'Status', 'status'),
            new Column('bookingDate', 'Booking date', 'date')
        };

        String base = 'SELECT Id, Name, Account_Id__r.Name, Project__r.Name, Unit_Id__r.Name, Final_Amount__c, '
            + 'Token_Amount__c, Status__c, Booking_Date__c, CreatedDate FROM Booking__c ';
        String filter;
        switch on (String.isBlank(view) ? 'all' : view) {
            when 'pending' { filter = 'WHERE Status__c = \'Pending Confirmation\' ORDER BY CreatedDate DESC LIMIT :lim'; }
            when 'recent' { filter = 'WHERE LastViewedDate != null ORDER BY LastViewedDate DESC LIMIT :lim'; }
            when else { filter = 'ORDER BY CreatedDate DESC LIMIT :lim'; }
        }
        setView(p, String.isBlank(view) ? 'all' : view);

        for (Booking__c b : (List<Booking__c>) Database.queryWithBinds(base + filter, new Map<String, Object>{ 'lim' => ROW_LIMIT }, AccessLevel.SYSTEM_MODE)) {
            Map<String, Object> r = bookingRow(b);
            r.put('token', b.Token_Amount__c);
            p.rows.add(r);
        }
        p.totalRecords = p.rows.size();
        return p;
    }

    private static Map<String, Object> bookingRow(Booking__c b) {
        return new Map<String, Object>{
            'id' => b.Id,
            'name' => b.Name,
            'customer' => b.Account_Id__r?.Name,
            'project' => b.Project__r?.Name,
            'unit' => b.Unit_Id__r?.Name,
            'amount' => b.Final_Amount__c,
            'status' => b.Status__c,
            'bookingDate' => b.Booking_Date__c != null ? (Object) b.Booking_Date__c : (Object) b.CreatedDate
        };
    }

    // ---------- Aggregates ----------

    private class LeadStats {
        Integer open = 0;
        Integer qualified = 0;
        Integer fresh = 0;
        Integer siteVisits = 0;
        Map<String, Integer> byProject = new Map<String, Integer>();
        Map<String, Integer> byStatus = new Map<String, Integer>();

        LeadStats() {
            for (AggregateResult ar : [
                SELECT Status s, Projects__c p, IsConverted v, COUNT(Id) c
                FROM Lead
                WHERE RecordType.DeveloperName = :RESI_LEAD_RT
                GROUP BY Status, Projects__c, IsConverted
            ]) {
                // Converted leads keep their last status (often Qualified), so bucket them explicitly.
                String status = (Boolean) ar.get('v') ? 'Converted' : (String) ar.get('s');
                String project = (String) ar.get('p');
                Integer c = (Integer) ar.get('c');
                byStatus.put(status, (byStatus.containsKey(status) ? byStatus.get(status) : 0) + c);
                if (CLOSED_LEAD_STATUSES.contains(status)) {
                    continue;
                }
                open += c;
                if (status == 'Qualified') {
                    qualified += c;
                } else if (status == 'New') {
                    fresh += c;
                }
                if (project != null) {
                    byProject.put(project, (byProject.containsKey(project) ? byProject.get(project) : 0) + c);
                }
            }
            siteVisits = [
                SELECT COUNT() FROM Lead
                WHERE RecordType.DeveloperName = :RESI_LEAD_RT AND IsConverted = false
                AND (Site_Visit_Scheduled__c = true OR Status = 'Site Visit')
            ];
        }
    }

    private class UnitStats {
        Integer total = 0;
        Integer available = 0;
        Integer towers = 0;
        Decimal availableArea = 0;
        // project name -> [available, not available]
        Map<String, Integer[]> byProject = new Map<String, Integer[]>();

        UnitStats() {
            Set<Id> towerIds = new Set<Id>();
            for (AggregateResult ar : [
                SELECT Property__r.Name p, Tower__c t, Status__c s, COUNT(Id) c, SUM(Saleable_Area__c) a
                FROM Unit__c
                GROUP BY Property__r.Name, Tower__c, Status__c
            ]) {
                String project = ar.get('p') == null ? 'Unassigned' : (String) ar.get('p');
                Integer c = (Integer) ar.get('c');
                Boolean isAvailable = (String) ar.get('s') == 'Available';
                if (ar.get('t') != null) {
                    towerIds.add((Id) ar.get('t'));
                }
                if (!byProject.containsKey(project)) {
                    byProject.put(project, new Integer[]{ 0, 0 });
                }
                total += c;
                if (isAvailable) {
                    available += c;
                    availableArea += ar.get('a') == null ? 0 : (Decimal) ar.get('a');
                    byProject.get(project)[0] += c;
                } else {
                    byProject.get(project)[1] += c;
                }
            }
            towers = towerIds.size();
        }
    }

    private class BookingStats {
        Integer count = 0;
        Integer pending = 0;
        Decimal value = 0;
        Decimal token = 0;
        Map<String, Integer> byProject = new Map<String, Integer>();

        BookingStats() {
            for (AggregateResult ar : [
                SELECT Project__r.Name p, Status__c s, COUNT(Id) c, SUM(Final_Amount__c) v, SUM(Token_Amount__c) t
                FROM Booking__c
                GROUP BY Project__r.Name, Status__c
            ]) {
                Integer c = (Integer) ar.get('c');
                String project = (String) ar.get('p');
                count += c;
                value += ar.get('v') == null ? 0 : (Decimal) ar.get('v');
                token += ar.get('t') == null ? 0 : (Decimal) ar.get('t');
                if ((String) ar.get('s') == 'Pending Confirmation') {
                    pending += c;
                }
                if (project != null) {
                    byProject.put(project, (byProject.containsKey(project) ? byProject.get(project) : 0) + c);
                }
            }
        }
    }

    // ---------- Helpers ----------

    private static void setView(PageData p, String view) {
        p.view = view;
        for (Option o : p.views) {
            if (o.value == view) {
                p.viewLabel = o.label;
            }
        }
    }

    private static String topKey(Map<String, Integer> counts) {
        String top;
        for (String k : counts.keySet()) {
            if (top == null || counts.get(k) > counts.get(top)) {
                top = k;
            }
        }
        return top;
    }

    private static Id leadRecordTypeId() {
        Schema.RecordTypeInfo info = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get(RESI_LEAD_RT);
        return info == null ? null : info.getRecordTypeId();
    }
}