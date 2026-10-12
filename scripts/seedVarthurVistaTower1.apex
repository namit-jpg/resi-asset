// Seeds Varthur Vista / Tower 1 with 12 floors x 6 units (VV-T1U{floor}{00-05}) for the Tower Explorer demo.
// Idempotent: existing floors (matched by name) and units (matched by name) are reused/skipped.
Tower__c tower = [SELECT Id, Property__c FROM Tower__c WHERE Name = 'Tower 1' AND Property__r.Name = 'Varthur Vista' LIMIT 1];
Id floorRt = Schema.SObjectType.Floor__c.getRecordTypeInfosByDeveloperName().get('Residential_Floor').getRecordTypeId();
Id unitRt = Schema.SObjectType.Unit__c.getRecordTypeInfosByDeveloperName().get('Residential_Unit').getRecordTypeId();

List<String> ordinals = new List<String>{ '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th', '11th', '12th' };
Map<String, Floor__c> floors = new Map<String, Floor__c>();
for (Floor__c f : [SELECT Id, Name FROM Floor__c WHERE Tower__c = :tower.Id]) floors.put(f.Name, f);
List<Floor__c> newFloors = new List<Floor__c>();
for (String o : ordinals) {
    if (!floors.containsKey(o)) {
        Floor__c f = new Floor__c(Name = o, Tower__c = tower.Id, Property__c = tower.Property__c, RecordTypeId = floorRt);
        newFloors.add(f);
        floors.put(o, f);
    }
}
insert newFloors;

// column -> BHK, carpet, saleable, SBA, balcony, car parks
List<List<Object>> cols = new List<List<Object>>{
    new List<Object>{ '4 BHK Classic', 2150, 2800, 2600, 140, 2 },
    new List<Object>{ '3 BHK Canopy', 1640, 2150, 2000, 96, 1 },
    new List<Object>{ '2 BHK + Family', 1180, 1550, 1450, 72, 1 },
    new List<Object>{ '2 BHK + Family', 1180, 1550, 1450, 72, 1 },
    new List<Object>{ '3 BHK Canopy', 1640, 2150, 2000, 96, 1 },
    new List<Object>{ '4 BHK Classic', 2150, 2800, 2600, 140, 2 }
};
// deterministic status mix: mostly Available/Booked, some Blocked, Reserved, Management Hold
List<String> pattern = new List<String>{
    'Booked', 'Available', 'Available', 'Booked', 'Available', 'Booked', 'Management Hold', 'Available',
    'Booked', 'Available', 'Blocked', 'Booked', 'Available', 'Reserved', 'Booked', 'Available', 'Booked'
};
Set<String> existing = new Set<String>();
for (Unit__c u : [SELECT Name FROM Unit__c WHERE Tower__c = :tower.Id]) existing.add(u.Name);

List<Unit__c> units = new List<Unit__c>();
Integer i = 0;
for (Integer f = 1; f <= 12; f++) {
    for (Integer c = 0; c < 6; c++) {
        String name = 'VV-T1U' + f + (c < 10 ? '0' : '') + c;
        i++;
        if (existing.contains(name)) continue;
        List<Object> spec = cols[c];
        units.add(new Unit__c(
            Name = name, RecordTypeId = unitRt,
            Property__c = tower.Property__c, Tower__c = tower.Id, Floor__c = floors.get(ordinals[f - 1]).Id,
            Unit_Type__c = 'Residential', Unit_Group__c = 'Residential Sales',
            BHK_Configuration__c = (String) spec[0],
            Carpet_Area__c = (Integer) spec[1], Saleable_Area__c = (Integer) spec[2],
            Built_Up_Area_SBA__c = (Integer) spec[3], Deck_Balcony__c = (Integer) spec[4],
            Number_of_Car_Parkings__c = (Integer) spec[5],
            Status__c = pattern[Math.mod(i * 7 + f, pattern.size())]
        ));
    }
}
insert units;
System.debug('SEED floors=' + newFloors.size() + ' units=' + units.size());
