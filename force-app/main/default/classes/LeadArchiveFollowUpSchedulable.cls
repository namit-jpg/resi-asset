public with sharing class LeadArchiveFollowUpSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        LeadArchiveService.processDueArchiveFollowUps();
    }
}