//enter here the short script name of the script that manages resets/setting run of scripts
string resetScript = "update";

integer g_iItemPageSize = 20;
integer UPDATE = 10001;
integer updateChildPin = 4711;
integer updatechannel = -7483214;
integer updatehandle;
string newversion;
list resetFirst = ["menu", "rlvmain", "anim/pose", "appearance"];
list itemTypes;
key g_kUpdater;		// for linking preventing bad commands.

integer checked = FALSE;		//set this to true after checking version

list childScripts; //3 strided list with format [id(of the prim), pin, (short)scriptname]

debug(string message)
{
   //llOwnerSay("DEBUG " + llGetScriptName() + ": " + message);
}

// Return  1 IF inventory is removed - llInventoryNumber will drop
integer SafeRemoveInventory(string sItem)
{
    if (llGetInventoryType(sItem) != INVENTORY_NONE)
    {
        llRemoveInventory(sItem);
        return 1;
    }
    return 0;
}

SafeResetOther(string scriptname)
{
    if (llGetInventoryType(scriptname) == INVENTORY_SCRIPT)
    {
            llResetOtherScript(scriptname);
            llSetScriptState(scriptname, TRUE);        
    }
}

integer IsCollarDBScript(string name)
{
    name = llList2String(llParseString2List(name, [" - ", "- ", " -", "-"], []), 0);		// we prefer " - "
    if (name == "CollarDB")
    {
        return TRUE;
    }
    return FALSE;
}

StopAllScripts()
{
    // set all scripts in me to NOT RUNNING
    integer n;
    for (n = 0; n < llGetInventoryNumber(INVENTORY_SCRIPT); n++)
    {
        string script = llGetInventoryName(INVENTORY_SCRIPT, n);
        if (script != llGetScriptName())
        {
            if (llGetInventoryType(script) == INVENTORY_SCRIPT)
            {
                if(llGetScriptState(script))
                {
                    llSetScriptState(script, FALSE);
                } 
            }
            else
            { //somehow we got passed a script we can't find.  Wait a sec and try again
                if (llGetInventoryType(script) == INVENTORY_SCRIPT)
                {
                    llSetScriptState(script, FALSE);        
                }        
                else
                {
                    llWhisper(DEBUG_CHANNEL, "Could not set " + script + " to not running.");
                }
            }
        }
    }
}
DeleteOld(list toDelete)
{
    integer i;
    for (i = 0; i < llGetListLength(toDelete); i++)
    {
        string delName = llList2String(toDelete, i);
        integer index = llSubStringIndex(delName, "*");
        if (index == -1)
        {
            SafeRemoveInventory(delName);
        }
        else
        {
            integer n;
            string partName = llGetSubString(delName, 0, index - 1);
            for (n = 0; n < llGetInventoryNumber(INVENTORY_SCRIPT); n++)
            {
                delName = llGetInventoryName(INVENTORY_SCRIPT, n);
                if (llGetSubString(delName, 0, index -1) == partName)
                {
                    n -= SafeRemoveInventory(delName);
                }
            }
        }
    }
}

DeleteItems(list toDelete)
{
    integer iPageType = (integer)llList2String(toDelete, 0);
    integer type = iPageType % 100;
    toDelete = llDeleteSubList(toDelete, 0,0);
    integer i;
    if(type == INVENTORY_SCRIPT)
    {//handle replacing scripts.  These are different from other inventory because they're versioned.
        list oldScripts;
        list newScripts;
        string fullScriptName;
        string shortScriptName;
        
        //make list of scripts that we'll be receiving from updater, w/o version numbers
        integer iStop = llGetListLength(toDelete);
        for(i = 0; i < iStop; i++)
        {
            fullScriptName = llList2String(toDelete, i);
            //shortScriptName = llGetSubString(fullScriptName, 0, llStringLength(fullScriptName) - 6);
            //this will allow scripts with other endings to be removed like - 3.520a and so on.
            shortScriptName = (string) llList2List(llParseString2List(fullScriptName, [],  [" - ", "- ", " -", "-"]), 0, 2);		// We want " - " but just in case of typo
            newScripts += [shortScriptName];
        }
        
        //make strided list of scripts in inventory, in form versioned,nonversioned
        iStop = llGetInventoryNumber(INVENTORY_SCRIPT);
        for(i = 0; i < iStop; i ++)
        {
            fullScriptName = llGetInventoryName(type, i);
            //this will allow scripts with other endings to be removed like - 3.520a and so on.
            shortScriptName = (string) llList2List(llParseString2List(fullScriptName, [],  [" - ", "- ", " -", "-"]), 0, 2);		// We want " - " but just in case of typo
            oldScripts += [fullScriptName, shortScriptName];
        }
        
        //loop through new scripts.  Delete old, superseded ones
        iStop = llGetListLength(newScripts);
        for(i = 0; i < iStop; i++)
        {
            shortScriptName = llList2String(newScripts, i);
            integer foundAt = llListFindList(oldScripts, [shortScriptName]);
            if(foundAt != -1)
            {
                fullScriptName = llList2String(oldScripts, foundAt -1);
                if(fullScriptName != llGetScriptName())
                {
                    debug("deleting " + fullScriptName);
                    SafeRemoveInventory(fullScriptName);
                }
            }
        }
    }
    else
    {
        integer iStop = llGetListLength(toDelete);
        for (i = 0; i < iStop; i++)
        {
            string delName = llList2String(toDelete, i);
            SafeRemoveInventory(delName);		//no need to check twice
        }
    }
    integer index = llListFindList(itemTypes, [(string)iPageType]); // should always be 0
    itemTypes = llDeleteSubList(itemTypes, index, index);
    if(llGetListLength(itemTypes))
    {
        llWhisper(updatechannel, "giveList|" + llList2String(itemTypes, 0));
    }
    else
    {
        debug("ready to receive");
        llWhisper(updatechannel, "ready to receive");
    }
}

FinalizeUpdate()
{
    debug("finalize started");
    llWhisper(updatechannel, "copying child scripts");
    llSetRemoteScriptAccessPin(0);
    integer i;
    string fullScriptName;
    string scriptName;
    string scriptToPrim;
    integer scriptNumber = llGetInventoryNumber(INVENTORY_SCRIPT);
        // new way to update childprim scripts the part before can be deleted in the next coming update cycle tp prevent the annoying script error when the script tries to load a script into a non-prepared child prim
    list newChildScripts;
    string shortScriptName;
    //make strided list of scripts in inventory, in form versioned,nonversioned
    for(i = 0; i < scriptNumber; i ++)
    {
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        shortScriptName = llList2String(llParseString2List(fullScriptName, [" - ", "- ", " -", "-"],[]), 1);		//We want " - "
        //we are only interested in script that are meant to be copied into a child prim so has an @ in its name
        if (llSubStringIndex(fullScriptName, "@") != -1) 
        {
            newChildScripts += [fullScriptName, shortScriptName];
        }
    }
    integer childPrims = llGetListLength(childScripts);
    for( i = 2; i < childPrims; i = i + 3)
    {
        shortScriptName = llList2String(childScripts, i);
        integer pin = (integer)llList2String(childScripts, i - 1);
        key destPrim = llList2String(childScripts, i - 2);
        integer index = llListFindList(newChildScripts, [shortScriptName]);
        if(index != -1)
        {
            if (llGetListLength(childScripts))
            {
                fullScriptName = llList2String(newChildScripts, index - 1);
                llRemoteLoadScriptPin(destPrim, fullScriptName, pin, TRUE, 41);
                SafeRemoveInventory(fullScriptName);
                newChildScripts = llDeleteSubList(newChildScripts, index - 1, index);
                if (llGetListLength(newChildScripts))
                {
                    i = childPrims;
                }
            }
        }
    }
    debug("new child script copy done child scripts left: " + llDumpList2String(newChildScripts, ","));
    //only if there are scripts left to copy do this
    if(llGetListLength(newChildScripts))
    {
        debug("using old childscript copy as new didnt get all");
        for( i = 0; i < llGetListLength(newChildScripts); i = i + 2)
        {
            shortScriptName = llList2String(newChildScripts, i + 1);
            fullScriptName = llList2String(newChildScripts, i);
            childPrims = llGetNumberOfPrims();
            integer n;
            for (n = 2; n < childPrims; n++)
            {   //load script (hovertext, and possibly relay) into the hovertext prim
                key kDest = llGetLinkKey(n);
                string primDesc = (string)llGetObjectDetails(kDest, [OBJECT_DESC]);
                primDesc = llList2String(llParseString2List(primDesc, ["~"], []), 0);
                if(primDesc != "")
                {
                    scriptToPrim = llList2String(llParseString2List(fullScriptName, [" - ", "- ", " -", "-"], []) , 1);		//We want " - "
                    scriptToPrim = llList2String(llParseString2List(scriptToPrim, ["@"], []), 1);
                    if ((llToLower(primDesc) == llToLower(scriptToPrim)) && (scriptToPrim != ""))
                    {
                        llRemoteLoadScriptPin(kDest, fullScriptName, updateChildPin, TRUE, 41);
                        newChildScripts = llDeleteSubList(newChildScripts, i, i + 1);
                        if (SafeRemoveInventory(fullScriptName))
                        {
                            i -= 2;
                        }
                        n = childPrims;
                        /* -- what's this about?
                        if (llGetListLength(newChildScripts))
                        {
                            i = llGetListLength(newChildScripts);
                            debug("childscript copy finally done");
                        }
                        */
                    }
                }
            }
        }
    }
    
    //lets check if a script that was meant to be in a child prim is still here and if... delete it
    /*
    scriptNumber = llGetInventoryNumber(INVENTORY_SCRIPT);
    //shouldnt be neccessary at all
    for (i = 0; i < scriptNumber; i++)
    {
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        if (llSubStringIndex(fullScriptName, "@") != -1)
        {
            i -= SafeRemoveInventory(fullScriptName);
        }
    }
    //clean up doublicate notecards
    for (i = 0; i < llGetInventoryNumber(INVENTORY_NOTECARD); i++)
    {
        string noteCard = llGetInventoryName(INVENTORY_NOTECARD, i);
        if (llGetSubString(noteCard, llStringLength(noteCard) - 2, -1) == " 1")
        {
            i -= SafeRemoveInventory(noteCard);
        }
    }
    */
    llWhisper(updatechannel, "restarting collar scripts");
    //rename the collar and its description to the new version
    string collarName = llGetObjectName();
    string collarDesc = llGetObjectDesc();
    list lname = llParseString2List(collarName, [" "],[]);
    list ldesc = llParseString2List(collarDesc, ["~"], []);  
    for (i = 0; i < llGetListLength(lname); i++)
    {
        if (llList2String(ldesc, 1) == llList2String(lname, i))
        {
            lname = llListReplaceList(lname, [newversion], i, i);
            string newname = llDumpList2String(lname, " ");
            llSetObjectName(newname);
        }
    }
    ldesc = llListReplaceList(ldesc, [newversion], 1, 1);
    llSetObjectDesc(llDumpList2String(ldesc, "~"));  
    llSetTexture("bd7d7770-39c2-d4c8-e371-0342ecf20921", ALL_SIDES);

    //start the script that shall start and reset all other scripts to finish and delete myself
    integer iStop = llGetInventoryNumber(INVENTORY_SCRIPT);
    for (i = 0; i < iStop; i++)
    {
        fullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        shortScriptName = llList2String(llParseString2List(fullScriptName, [" - ", "- ", " -", "-"],[]), 1);		//We want " - "
        if (shortScriptName == resetScript )
        {
            SafeResetOther(fullScriptName);
        }
    }
    llMessageLinked(LINK_THIS, UPDATE, "resetscripts", NULL_KEY);
    
}
default 
{
    state_entry() 
    {
        if( llGetStartParameter() == 42)
        {
            debug("started with startParam 42.");
            updatehandle = llListen(updatechannel, "", "", "");
            llSetTimerEvent(60);		// die 
        }
    }
    link_message(integer sender, integer auth, string str, key id)
    {
        if (auth == UPDATE)
        {
            // do not think this should ever happen
            

        }
    }
    listen(integer channel, string name, key id, string message) 
    {
        debug(llList2CSV([channel,name,id,message]));
        if (llGetOwnerKey(id) == llGetOwner())
        {
            list temp = llParseString2List(message, ["|"], []);
            string sCommand0 = llList2String(temp,0);
            string sCommand1 = llList2String(temp,1);
            if (sCommand0 == "link")
            {
                if (llGetKey() == (key) sCommand1)
                {
                    g_kUpdater = id;
                    state linked;
                }
            }
        }
    }
    timer()
    {
        llOwnerSay("Update did not link. No changes have been made. Please try again.");
        llRemoveInventory(llGetScriptName());
    }
}

state linked
{
    state_entry() 
    {
        llListenRemove(updatehandle);
        updatehandle = llListen(updatechannel, "", g_kUpdater, "");
        llMessageLinked(LINK_ALL_OTHERS, UPDATE, "prepare", NULL_KEY);
        StopAllScripts();
        llWhisper(updatechannel, "Manager Ready|" + (string)g_kUpdater);
        llSetTimerEvent(0);
    }
    link_message(integer sender, integer auth, string str, key id)
    {
        if (auth == UPDATE)
        {
            if (str == "Reset Done")
            {
                llWhisper(updatechannel, "finished");
                llRemoveInventory(llGetScriptName());
            }    
            else
            {
                list temp = llParseString2List(str, ["|"],[]);
                string scriptName = llList2String(temp, 0);
                string pin = llList2String(temp,1);
                if (llListFindList(childScripts, [(string)id, str]) == -1) 
                {
                    childScripts += [(string)id, pin, scriptName];
                }
            }
        }
    }
    listen(integer channel, string name, key id, string message) 
    {
        debug(llList2CSV([channel,name,id,message]));
        if (llGetOwnerKey(id) == llGetOwner())
        {
            list temp = llParseString2List(message, ["|"], []);
            string command0 = llList2String(temp,0);
            string command1 = llList2String(temp,1);
            if (command0 == "delete")
            {
                list thingstodelete = llDeleteSubList(temp, 0, 0);
                debug("deleting: " + llDumpList2String(thingstodelete, ","));
                DeleteOld(thingstodelete);
                //send a message to child prims
                llMessageLinked(LINK_ALL_OTHERS, UPDATE, "prepare", "");
            }
            else if(command0 == "deleteDone")
            {
                llWhisper(updatechannel, "deletedOld");                    
            }
            else if(command0 == "toupdate")
            {
                itemTypes = llList2List(temp, 1, -1);
                llWhisper(updatechannel, "giveList|" + llList2String(itemTypes, 0));
            }
            else if(command0 == "items")
            {
                DeleteItems(llDeleteSubList(temp, 0, 0));
            }
            else if(command0 == "version")
            {
                newversion = llGetSubString((string)llList2Float(temp, 1), 0, 4);
                llListenRemove(updatehandle);
                FinalizeUpdate();
            }
        }
    }
}
