integer UPDATE = 10001;

default
{
    state_entry()
    {
        llMessageLinked(LINK_ALL_OTHERS, UPDATE, "cleanup prim", "");
        llRemoveInventory(llGetScriptName());
    }

}
