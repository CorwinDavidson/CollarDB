integer UPDATE = 10001;

default
{
    state_entry()
    {
        //check if we're in an updater.  if so, don't do regular startup routine.
        if (llSubStringIndex(llGetObjectName(), "CollarDBUpdater") == 0)
        {
            //we're in an updater. go to sleep
            llSetScriptState(llGetScriptName(), FALSE);
        }
        else
        {        
            llMessageLinked(LINK_ALL_OTHERS, UPDATE, "cleanup prim", "");
            llRemoveInventory(llGetScriptName());
        }
    }

}
