# Booking process: Production vs UAT

Compared on 26 Oct 2026.
- **Production:** `real.resi@wd.demo`
- **UAT sandbox:** `real.resi@wd.demo.uat`

This was a read-only comparison: metadata was retrieved from both orgs and diffed, and nothing was deployed.

## Headline

**Production's booking metadata has not changed since 09–21 Apr 2026.** Every difference below is UAT work from 29 Sep to 20 Oct 2026.

UAT has a different booking journey:
1. Select Inventory.
2. Quote and discount check.
3. A customer booking form, with KYC, a token payment and a signature.
4. The booking is created and confirmed automatically, with an instalment schedule.
5. EOI amounts are deducted from the instalments.

All of this sits behind the new "WD Glass" pages. In production, the booking is created by a flow at Closed Won and then waits for approval and a real SAP sync.

Three UAT changes would break or regress production if deployed as they are (see [Risks](#deployment-risks)):
1. **The UAT `OpportunityTrigger` bypasses the trigger framework.** All residential and commercial Opportunity automation stops.
2. **`syncToSapAndCreateBooking` is demo code.** It fakes the SAP sync, skips booking approval and auto-approves receipts.
3. **Generate Sales Offer now opens the resale component.** The primary-sale payment-plan offer is gone.

## End-to-end journey

| Step | Production | UAT |
|---|---|---|
| Unit selection | Unit is set by hand on the Opportunity. | **Select Inventory** action and the Stock tab (`selectInventory`, `towerExplorer`). They tag the unit, reserve it, free the previous unit, fill booking conditions from the unit and move the stage to Negotiation. Blocked if the opportunity is closed or already booked. |
| Quote / sales offer | **Generate Sales Offer** opens `paymentPlanSelectionCom`. A quote is created and marked primary. | Generate Sales Offer (Opportunity and Quote) now opens `resaleOppSalesOrder` / `resaleSalesOrderForm`, the **resale** components. New quote rules: one Primary and one Final quote; a quote needs an Opportunity, a unit and an Account; the unit can't be Sold or Blocked; clone names get "(Clone)". |
| Discount | Discount Approval Process. A **Submit** button on the Opportunity page. | Same approval process plus a final field update `Advance_Stage_To_Booking_Form`. `evaluateAndSubmitDiscountApproval` has a hard-coded 7.5% threshold. The Submit button is removed from `RES_Opportunity_Record_Page`. |
| Opportunity stages (Residential) | Unit Shortlisting → Negotiation → Discount Approval → **Payment Plan Finalization** → **Token Amount Confirmation** → Closed Won/Lost | Unit Shortlisting → Negotiation → Discount Approval → **Booking form** → **Share welcome letter** → Closed Won/Lost. "Quotation Shared" and "Quotation Agreed" are also active values. Payment Plan Finalization and Token Amount Confirmation are **inactive**. |
| Customer details | Entered by staff on the Opportunity and Account. | **Booking form** (Opportunity → Booking Form). A 30-day link is sent by email, WhatsApp or copy, or opened via "Open in Salesforce". Steps: Details → Co-applicants (max 3) → KYC uploads → Token → Sign → Confirmation. On submit it updates the primary Person Account, finds or creates co-applicant Person Accounts by PAN, syncs Contact Roles and fills Booking `Co_Applicant_1..5__c`. It also fills the nominee fields on the Opportunity and upserts co-applicant and nominee Contacts. |
| Token payment | Token amount on the Opportunity, with the validation rule. | Form payment step is **simulated** ("Test mode": it sets Token Paid and a fake `pay_…` reference, and creates no receipt). The token defaults to 10% or ₹2L if blank. |
| Booking creation | Flow `RTF_Convert_Opportunity_To_Booking` runs at Closed Won. The Booking is "Pending Confirmation". | The same flow is still active. `UnitSelectionQuoteController.syncToSapAndCreateBooking` sets Closed Won, then sets the new booking to **"Confirmed"**. It writes a random `SO-2026-xxxxx` SAP number with `SAP_Sync_Status__c = Success` and makes **no callout**. It also blocks the unit, generates instalments, and creates the token Demand and an auto-approved Payment Receipt ("HDFC Bank Limited"). |
| Approval and SAP | The real SAP sync (`SAPBookingIntegrationHandler`) runs when `Approval_Status__c` becomes "Booking Approved". | Bypassed by the path above. |
| EOI | `Voucher__c` is a basic object with 8 fields and one type, "Type1". No actions. | A full EOI module: Standard (₹1L) / Priority (₹2.5L) types, 20 new fields, priority numbers and a voucher PDF. Leads get a Generate EOI action; only Record Payment is visible. `EoiVoucherLeadTrigger` links vouchers when a lead converts. When a booking is created, `EoiBookingTrigger` and `EoiBookingAdjustment` deduct paid EOIs from instalments through auto-approved receipts, which **are sent to SAP**. |
| Instalment payments | `Amount_Paid_validation` blocks any save where the amount paid is less than the instalment. | Only blocks when the status is Paid, so partial payments are allowed. Schedule cards link to Demands and Receipts. |
| Booking status | Pending Confirmation, Confirmed, Allotment Letter Shared, and others. | Adds lifecycle values: Booking Confirmed, Allotment & Welcome Kit, Agreement & AFS Registration, Under Construction & Demands, OC Received & Pre-Possession, Final Sale Deed Registration, and Closed Won. The Residential record type **drops "Allotment Letter Generated"**. "Allotment Letter Shared" is inactive. |
| Booking conditions | Reps can edit all conditions except 3 read-only types. | Reps can edit only "Base Price Discount". Conditions are auto-filled from the unit when the page loads. |
| Post-booking | Booking page actions: allotment letter, SOA, ledger, ownership transfer, cancellation. | Adds Customer Documents (Welcome, Allotment and Car Parking letters saved to Files), Initiate Resale/Rental, a Handover link, a commercial cost sheet and an executive cockpit. |

## Opportunity automation

**Production:**
- `OpportunityTrigger` runs on all five events and respects the global kill switch.
- It goes through `TriggerFactory` → `OpportunityTriggerDispatcher`, which routes by record type to the Residential and Commercial dispatchers.
- Those dispatchers validate the unit and tower price and the chargeable area, check for duplicate milestones, upsert booking conditions (base price, tower charges, GST), and run the discount stage logic.

**UAT:**
- `OpportunityTrigger` calls only the new `OpportunityTriggerHandler`, on before insert, before update and after insert.
- That handler covers **resale** only: it creates the buyer account and the initial quote.
- Confirmed: no other Opportunity trigger exists in UAT. In UAT today, **none of the residential or commercial handlers run**, including:
  - the UAT edits to `OpportunityTriggerDispatcher`: auto-create booking at Closed Won, and move to "Booking form" when the discount is approved
  - the UAT edit to `ResOpportunityBeforeUpdateTriggerHandler`: no Closed Won without a Quote

Some of that logic was moved into the new UI controllers instead, for example booking conditions on unit tagging.

**Flow `RTF_Convert_Opportunity_To_Booking`:** when the payment plan changes, production sets the stage to Payment Plan Finalization. UAT sets it to Negotiation, and only if the stage is Unit Shortlisting.

## UI that users see (WD_Residential app)

**App:**
- **Branding:** "Nikoo Homes" (green logo) → "WD Homes" (`WD_Logo`).
- **Tabs:** UAT adds Home, Dashboard, GRE Welcome Desk, EOI, Quote, WD Glass Bookings (replaces Booking), WD Glass Inventory (replaces Unit), Handover, Rent/Resale and Sales Target. It drops Campaign and Unit.

**Desktop record pages** for Opportunity, Account, Unit, Lead, Tower, Site Visit, Voucher and Property switch to the `WD_Glass_*` pages.
- **Unchanged:** Booking and Quote still use `RES_Booking_Record_Page` and `Res_Quote_Record_Page`. Phone still uses the RES pages.
- `WD_Glass_Booking_Record` exists but is **not assigned**.

**`RES_Opportunity_Record_Page`:**
- Removed: Submit (discount approval) and Clone.
- Added: resale actions (KYC, resale payment, transfer, NOC, No Dues, welcome letter).

**`Res_Quote_Record_Page` and the Quote layout** were reworked for resale:
- Removed: Generate Sales Offer, the primary-sale charge fields (Base Price, Maintenance/Corpus, Legal, BESCOM/BWSSB, Club), standard totals and Quote Line Items.
- Added: Resale Commercials and Clone Quote.

**Voucher layout** was rebuilt as an EOI voucher.

**`Opportunity.Site_Visit`:** Unit, Project, Tower and Customer are now prefilled and read-only.

**`Quote.SendEmail`:** the action layout is empty in UAT.

## Customer documents (Visualforce)

All 15 letter and PDF templates were rebranded:
- **Entity name:** "Palladium Constructions / Phoenix Residentials / WDR" → **"WarpDrive Tech Works"**, including the cheque payee name.
- **Logo:** added via the `WDDocLogo` component or the `WD_Doc_Logo` static resource.
- **Address:** the Allotment Letter address changed from Mumbai to Jayanagar, Bengaluru.
- No calculation changes.

**Welcome Letter** changed from a short Word doc to a branded A4 PDF, attached as a PDF:
- It now works from an Opportunity or a Booking.
- **It has hard-coded fallbacks:**
  - a token of ₹2,00,000, always shown as "Paid"
  - RM details +91 99000 12345 / crm@residences.example.com
  - project "Nikoo Homes, Thanisandra Main Road"
- **Branding:** the body says "WarpDrive Residences", while the other documents say "WarpDrive Tech Works".

`StatementOfAccountDOC` and `TransactionReportDoc` also changed in UAT on 10 Oct 2026, but were not diffed.

## Deployment risks

1. **`OpportunityTrigger` (UAT version):** deploying it removes all residential and commercial Opportunity automation and the kill switch in production. It is probably also an unintended regression in UAT itself.
2. **`syncToSapAndCreateBooking`** must not reach production as it is:
   - fake SAP order numbers and sync status
   - booking approval bypassed
   - auto-approved receipts with a hard-coded bank
   - auto-activated payment plans
   - a ₹1 Cr default agreement value
   - the current user auto-assigned as CRM user
3. **Generate Sales Offer and the Quote page:** deploying either loses the primary-sale sales offer flow in production.
4. **Stage and status values:**
   - Production records currently in Payment Plan Finalization or Token Amount Confirmation. The active flow `RTF_Opportunity_Send_notification_on_payment_plan_finalization` can no longer fire in UAT.
   - `AllotmentLetterController` sets "Allotment Letter Generated", which the UAT record type no longer allows.
   - `CustomerLedgerController` uses "Booking Form & Token Confirmation".
   - Known invalid values from the work log: Booking "Active", and Receipt "Approved", "Pending" and "Demand Raised".
5. **New Quote before-insert validation** applies to all record types. Production quote creation without a unit or account will fail.
6. **Booking form:**
   - It needs the "Nikoo Homes Booking" Experience site, which is broken for guests in UAT.
   - It needs a real payment gateway, because the current step is simulated.
   - It needs ~25 Opportunity fields, 5 Contact fields and permissions. The `Nikoo_Booking_Contacts` permission set is assigned to no one.
   - Opening the form in Salesforce moves the stage to "Share welcome letter" before any payment.
7. **EOI:**
   - Auto-approved EOI receipts flow to SAP.
   - Instalments are duplicated on BO-00000356 and BO-00000387.
   - The token receipt has zero principal, so the ledger engine shows the token as unpaid.
8. **Hard-coded values:**
   - approver `real.resi@wd.demo`
   - the 7.5% discount threshold
   - prices: parking ₹2.75L, possession ₹4.668L, GST 5%
   - example.com URLs and emails
   - EOI amounts
9. **Smaller items:**
   - several classes changed to `without sharing`
   - `Token_Amount__c` precision cut from 18 to 16
   - `RES_Quote_After_Approval_Update_Opportunity` has no record-type guard
   - `Opportunity.SimpleOpportunity` is active in UAT
   - branding ("WD Homes" / "WarpDrive") needs a decision before going live

## Production changes not in UAT

None in the booking area. Production's only newer items are unrelated: `ItemOptionService` and the Agent / FSL flows.

## Method

1. Tooling API inventory of both orgs: Apex classes, triggers, Visualforce pages, LWC source, flows, validation rules and approval processes, compared by content hash.
2. Booking-related metadata retrieved from both orgs and diffed: objects, fields, record types, business processes, flows, Apex, LWCs, pages, layouts, flexipages, quick actions and the app.
3. Stage values and trigger lists checked by direct query.
