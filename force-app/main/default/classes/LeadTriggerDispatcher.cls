/**
 * @description Trigger dispatcher for the Lead object. This class contains the logic
 * to handle events related to Lead records.
 */
public with sharing class LeadTriggerDispatcher extends TriggerDispatcherBase {
    
    // --- Configure Record Type DeveloperNames per project ---
    private static final Set<String> RESIDENTIAL_RT = new Set<String>{
        'Standard_Lead_Residential'
    };
    private static final Set<String> COMMERCIAL_RETAIL_RT = new Set<String>{
        'Standard_Lead_Commercial'
    };


    // ---------------- Trigger Events ----------------
  
    public override void beforeInsert(TriggerParameters tp)  { route(tp, TriggerParameters.TriggerEvent.beforeInsert); }
    public override void afterInsert(TriggerParameters tp)   { route(tp, TriggerParameters.TriggerEvent.afterInsert);  }
    public override void beforeUpdate(TriggerParameters tp)  { route(tp, TriggerParameters.TriggerEvent.beforeUpdate); }
    public override void afterUpdate(TriggerParameters tp)   { route(tp, TriggerParameters.TriggerEvent.afterUpdate);  }
    public override void beforeDelete(TriggerParameters tp)  { route(tp, TriggerParameters.TriggerEvent.beforeDelete); }

    // ---------------- Core Router ----------------
    private void route(TriggerParameters tp, TriggerParameters.TriggerEvent ev) {
        // Determine the active working list for this phase
        List<Lead> work = (tp.isDelete)
            ? (List<Lead>) tp.oldList
            : (List<Lead>) tp.newList;

        if (work == null || work.isEmpty()) return;
		
        ensureRtCache(work, 'Lead');

        // Partition by project
        List<Lead> resList = new List<Lead>();
        List<Lead> comList = new List<Lead>();

        for (Lead o : work) {
            if (o.RecordTypeId == null) {
                resList.add(o);
                continue;
            }
            String dev = rtDevById.get(o.RecordTypeId);
            if (dev == null) {
                resList.add(o);
                continue;
            }

            if (RESIDENTIAL_RT.contains(dev))             resList.add(o);
            else if (COMMERCIAL_RETAIL_RT.contains(dev))  comList.add(o);
            else                                          resList.add(o);
        }
        // Dispatch to appropriate project handlers with FILTERED TriggerParameters
        if (!resList.isEmpty()) {
            TriggerParameters tpr = filteredByRecords(tp, resList);
            
            Type obType = Type.forName('ResLeadTriggerDispatcher');
            ITriggerDispatcher dispatcher = (ITriggerDispatcher)obType.newInstance();
            TriggerFactory.execute(tpr, dispatcher);
        }
        if (!comList.isEmpty()) {
            TriggerParameters tpc = filteredByRecords(tp, comList);
            Type obType = Type.forName('ComLeadTriggerDispatcher');
            ITriggerDispatcher dispatcher = (ITriggerDispatcher)obType.newInstance();
            TriggerFactory.execute(tpc, dispatcher);
        }
    }
    
    
}