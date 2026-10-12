@IsTest
private class WdGlassDashboardControllerTest {

    @TestSetup
    static void setup() {
        Id rt = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName().get('Standard_Lead_Residential')?.getRecordTypeId();
        List<Lead> leads = new List<Lead>{
            new Lead(LastName = 'Dash One', Company = 'WarpDrive', Status = 'New', LeadSource = 'Referral'),
            new Lead(LastName = 'Dash Two', Company = 'WarpDrive', Status = 'New', LeadSource = 'Referral', Site_Visit_Scheduled__c = true),
            new Lead(LastName = 'Dash Three', Company = 'WarpDrive', Status = 'New')
        };
        for (Lead l : leads) {
            if (rt != null) {
                l.RecordTypeId = rt;
            }
        }
        insert leads;
        insert new List<Site_Visit__c>{
            new Site_Visit__c(Lead__c = leads[1].Id, Status__c = 'Scheduled', Visit_DateTime__c = Datetime.now().addDays(2)),
            new Site_Visit__c(Lead__c = leads[1].Id, Status__c = 'Completed', Visit_DateTime__c = Datetime.now().addMinutes(5))
        };
    }

    private static SObject row(String objectName, Map<String, Object> fields) {
        Map<String, Object> raw = new Map<String, Object>(fields);
        raw.put('attributes', new Map<String, Object>{ 'type' => objectName });
        return (SObject) JSON.deserialize(JSON.serialize(raw), Type.forName(objectName));
    }

    @IsTest
    static void moneyFlowsIntoTilesTrendCollectionsAndLeaderboard() {
        Id me = UserInfo.getUserId();
        Date today = Date.today();
        Map<String, Object> owner = new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'User' }, 'Name' => 'Test Seller' };
        WdGlassDashboardController.stubBookings = new List<Booking__c>{
            (Booking__c) row('Booking__c', new Map<String, Object>{
                'OwnerId' => me, 'Owner' => owner, 'Final_Amount__c' => 5000000, 'Status__c' => 'Pending Confirmation',
                'Booking_Date__c' => today, 'CreatedDate' => Datetime.now()
            }),
            (Booking__c) row('Booking__c', new Map<String, Object>{
                'OwnerId' => me, 'Owner' => owner, 'Final_Amount__c' => 3000000, 'Status__c' => 'Confirmed',
                'CreatedDate' => Datetime.now().addMonths(-1)
            })
        };
        WdGlassDashboardController.stubReceipts = new List<Payment_Receipt__c>{
            (Payment_Receipt__c) row('Payment_Receipt__c', new Map<String, Object>{
                'Amount_Paid__c' => 250000, 'Date_Of_Payment__c' => today, 'CreatedDate' => Datetime.now()
            })
        };
        WdGlassDashboardController.stubDemands = new List<Demand__c>{
            (Demand__c) row('Demand__c', new Map<String, Object>{
                'Demand_Amount__c' => 400000, 'Total_Amount_Recieved__c' => 100000, 'Due_Date__c' => today.addDays(-45)
            }),
            (Demand__c) row('Demand__c', new Map<String, Object>{
                'Total_Value__c' => 200000, 'Due_Date__c' => today.addDays(-100)
            }),
            (Demand__c) row('Demand__c', new Map<String, Object>{
                'Demand_Amount__c' => 150000, 'Due_Date__c' => today.addDays(10)
            })
        };

        WdGlassDashboardController.DashboardData d = WdGlassDashboardController.getDashboard('month', 'team');

        Assert.areEqual(5000000, d.tiles[0].value, 'only the booking dated this month counts');
        Assert.areEqual(1, d.tiles[1].value);
        Assert.areEqual(250000, d.tiles[2].value);
        Assert.areEqual(1, d.pendingBookings);
        Assert.areEqual(5000000, d.months[11].booked);
        Assert.areEqual(3000000, d.months[10].booked);
        Assert.areEqual(1, d.leaders.size());
        Assert.isTrue(d.leaders[0].me);
        Assert.areEqual(600000, d.collection.due);
        Assert.areEqual(100000, d.collection.received);
        Assert.areEqual(500000, d.collection.overdue);
        Assert.areEqual(300000, d.collection.buckets[1].amount, '45 days late');
        Assert.areEqual(200000, d.collection.buckets[3].amount, '100 days late');
        Assert.areEqual(150000, d.collection.upcoming);
        Assert.areEqual(1, d.tiles[3].value, 'one completed site visit');
        Assert.areEqual(1, d.visits.size(), 'one visit coming up');

        WdGlassDashboardController.DashboardData mine = WdGlassDashboardController.getDashboard('fy', 'mine');
        Assert.areEqual(0, mine.tiles[2].value, 'receipts are not tied to my bookings');
    }

    @IsTest
    static void everyPeriodAndScopeRenders() {
        Test.startTest();
        for (String period : new List<String>{ 'month', 'quarter', 'fy', null }) {
            for (String scope : new List<String>{ 'team', 'mine' }) {
                WdGlassDashboardController.DashboardData d = WdGlassDashboardController.getDashboard(period, scope);
                Assert.areEqual(4, d.tiles.size());
                Assert.areEqual(12, d.months.size());
                Assert.areEqual(5, d.funnel.size());
                Assert.areEqual(91, d.days.size(), 'heatmap covers 13 full weeks');
                Assert.areEqual(12, d.tiles[0].spark.size());
                Assert.isNotNull(d.periodLabel);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void funnelCountsTheLeadCohort() {
        WdGlassDashboardController.DashboardData d = WdGlassDashboardController.getDashboard('month', 'team');
        Assert.areEqual(3, d.funnel[0].count, 'all three new leads are enquiries this month');
        Assert.areEqual(1, d.funnel[2].count, 'one lead has a site visit lined up');
        Assert.areEqual(1, d.funnel[1].count, 'a lead at site visit stage has also passed qualification');
        Assert.areEqual(0, d.funnel[3].count);
        Assert.areEqual('Referral', d.sources[0].label);
        Assert.areEqual(2, d.sources[0].leads);
    }

    @IsTest
    static void windowsFollowTheIndianFinancialYear() {
        WdGlassDashboardController.Window q = WdGlassDashboardController.window('quarter', Date.newInstance(2026, 2, 10));
        Assert.areEqual(Date.newInstance(2026, 1, 1), q.startDate);
        Assert.areEqual(Date.newInstance(2026, 3, 31), q.endDate);
        Assert.areEqual('Q4 FY26', q.label);
        Assert.areEqual(Date.newInstance(2025, 10, 1), q.prevStart);
        Assert.areEqual(Date.newInstance(2025, 11, 10), q.prevEnd);

        WdGlassDashboardController.Window fy = WdGlassDashboardController.window('fy', Date.newInstance(2026, 10, 5));
        Assert.areEqual(Date.newInstance(2026, 4, 1), fy.startDate);
        Assert.areEqual('FY 2026–27', fy.label);

        WdGlassDashboardController.Window m = WdGlassDashboardController.window('month', Date.newInstance(2026, 3, 31));
        Assert.areEqual(Date.newInstance(2026, 2, 28), m.prevEnd, 'never runs past the end of a shorter previous month');
    }

    @IsTest
    static void filtersNarrowEveryPanel() {
        Date today = Date.today();
        WdGlassDashboardController.stubTargets = new List<Sales_Target__c>{
            new Sales_Target__c(Month__c = today, Target_Value__c = 1000000, Target_Units__c = 2),
            new Sales_Target__c(Month__c = today, Target_Value__c = 500000, Sales_Executive__c = UserInfo.getUserId())
        };
        Map<String, Object> filters = new Map<String, Object>{
            'period' => 'custom',
            'fromDate' => String.valueOf(today.toStartOfMonth()),
            'toDate' => String.valueOf(today),
            'leadSource' => 'Referral'
        };

        Test.startTest();
        WdGlassDashboardController.DashboardData d = WdGlassDashboardController.getSalesDashboard(JSON.serialize(filters));
        filters.put('ownerId', UserInfo.getUserId());
        WdGlassDashboardController.DashboardData mine = WdGlassDashboardController.getSalesDashboard(JSON.serialize(filters));
        WdGlassDashboardController.FilterOptions options = WdGlassDashboardController.getFilterOptions();
        Test.stopTest();

        Assert.areEqual('custom', d.period);
        Assert.areEqual(1, d.activeFilters);
        Assert.areEqual(2, d.funnel[0].count, 'only the two referral leads');
        Assert.areEqual(1, d.sources.size());
        Assert.isTrue(d.hasTargets);
        Assert.areEqual(12, d.targets.size());
        Assert.areEqual(12, d.cancellations.size());
        Decimal teamTarget = 0;
        Decimal myTarget = 0;
        for (Integer i = 0; i < 12; i++) {
            teamTarget += d.targets[i].target;
            myTarget += mine.targets[i].target;
        }
        Assert.areEqual(1500000, teamTarget);
        Assert.areEqual(500000, myTarget, 'only the target set for me');
        Assert.areEqual('mine', mine.scope);
        Assert.isNotNull(options.me);
        Assert.isFalse(options.channels.isEmpty());
    }

    @IsTest
    static void classifiesChannelsAndConfigurations() {
        Assert.areEqual(WdGlassDashboardController.CHANNEL_PARTNER, WdGlassDashboardController.channelOf('Channel sale(Broker)', false, null));
        Assert.areEqual(WdGlassDashboardController.CHANNEL_PARTNER, WdGlassDashboardController.channelOf(null, true, 'Google'));
        Assert.areEqual(WdGlassDashboardController.CHANNEL_REFERRAL, WdGlassDashboardController.channelOf(null, false, 'Referral'));
        Assert.areEqual(WdGlassDashboardController.CHANNEL_DIRECT, WdGlassDashboardController.channelOf(null, false, 'Chatbot'));
        Assert.areEqual('3 BHK', WdGlassDashboardController.configBucket('3 BHK Canopy'));
        Assert.areEqual('3 BHK', WdGlassDashboardController.configBucket('3BHK'));
        Assert.areEqual('4.5 BHK', WdGlassDashboardController.configBucket('4.5 BHK'));
        Assert.isNull(WdGlassDashboardController.configBucket(null));

        WdGlassDashboardController.Window w = WdGlassDashboardController.customWindow(Date.newInstance(2026, 1, 1), Date.newInstance(2026, 1, 10));
        Assert.areEqual(Date.newInstance(2025, 12, 22), w.prevStart);
        Assert.areEqual(Date.newInstance(2025, 12, 31), w.prevEnd);
    }
}