/** Deducts a paid EOI from the customer's balance once their booking is created (see EoiBookingAdjustment). */
trigger EoiBookingTrigger on Booking__c (after insert) {
    if (!UtilityClass.isTriggerGloballyDisabled()) {
        EoiBookingAdjustment.enqueueFor(Trigger.new);
    }
}
