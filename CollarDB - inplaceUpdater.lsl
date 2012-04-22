//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.

//in place updater
list Charset_LeftRight      = ["   ","▏","▎","▍","▌","▋","▊","▉","█"];

string RELESENOTE_URL = "http://www.collardb.com/static/ReleaseNotes"; // ad the version in form of "XYYY" at the end
string ISSUETRACKER_URL = "http://www.collardb.com/static/milestoneRelease"; // add the version in from of x.y at the end

integer updatechannel = -7483214;
integer listenhandle;
float version;
string versionstring;

key g_kCollar;		//for linking to just one collar.

list offering;
integer updatePin;
key myKey;
string hoverText = "PLEASE WAIT\n";

integer line;
key dataid;
string noteCard = "OldItemsToDelete";
list oldItemsToDelete;
integer g_iItemPageSize = 20;

string instructions;

//key particletexture = "41873cb5-cb92-abca-16c4-ac319c9e2067";
key particletexture = "070f1f09-3091-04a6-ca69-bb63c32cef10";

integer debughandle;
string debugMessage;

integer g_nDoubleCheckChannel=-0x10CC011A; // channel for finding multiple updaters

key g_keyWearer; // id of wearer

integer g_iRecentlyTouched = FALSE;
float g_fSecondTouchDelay = 10.0;

integer g_link;
integer g_link2;

debug(string str)
{
    //llOwnerSay(llGetScriptName() + ": " + str);
}

// Find the floattext prim
GetSphereLink()
{
    integer max = llGetNumberOfPrims();
    integer i = 0;
    list desc = [];
    for (;i<=max;i++)
    {
        desc = llGetObjectDetails(llGetLinkKey(i),[OBJECT_DESC]);
        if (llSubStringIndex((string)desc,"partsphere") != -1)
        {
            g_link = i;
        }
        if (llSubStringIndex((string)desc,"dockring") != -1)
        {
            g_link2 = i;
        }    
    }   
}

integer isUpdateManagerScript(string name)
{
    if (name == llGetScriptName())
    {
        return TRUE;
    }
    else
    {
        name = llList2String(llParseString2List(name, [" - ", "- ", " -", "-"], []), 1);		//Should be " - " and we want it to be
        if (name == "updateManager")
        {
            return TRUE;
        }
        else if (name == "")
        {
            return TRUE;
        }
        else
        {
            return FALSE;
        }
    }
}

UpdateParticle(key target, vector color)
{
    integer effectFlags;
    effectFlags = effectFlags|PSYS_PART_INTERP_COLOR_MASK;
    effectFlags = effectFlags|PSYS_PART_INTERP_SCALE_MASK;
   // effectFlags = effectFlags|PSYS_PART_FOLLOW_SRC_MASK;
   // effectFlags = effectFlags|PSYS_PART_FOLLOW_VELOCITY_MASK;
   // effectFlags = effectFlags|PSYS_PART_TARGET_POS_MASK;
    effectFlags = effectFlags|PSYS_PART_EMISSIVE_MASK;
    llLinkParticleSystem(g_link,[
        PSYS_PART_FLAGS,            effectFlags,
        PSYS_SRC_PATTERN,           PSYS_SRC_PATTERN_ANGLE_CONE,
        PSYS_SRC_ANGLE_BEGIN,       0.0, 
        PSYS_SRC_ANGLE_END,         PI, 
        PSYS_PART_START_COLOR,      color,
        PSYS_PART_END_COLOR,        color,
        PSYS_PART_START_ALPHA,      0.75,
        PSYS_PART_END_ALPHA,        0.25,
        PSYS_PART_START_SCALE,      <0.05,0.05,0.0>,
        PSYS_PART_END_SCALE,        <0.01,0.01,0.0>,
        PSYS_PART_MAX_AGE,          2.0,
        PSYS_SRC_TEXTURE,           particletexture,         
        PSYS_SRC_ACCEL,             <0.0,0.0,0.0>,
        PSYS_SRC_BURST_RATE,        0.1,
        PSYS_SRC_BURST_PART_COUNT,  100,
        PSYS_SRC_BURST_RADIUS,      0.08,
        PSYS_SRC_BURST_SPEED_MIN,   0.01,
        PSYS_SRC_BURST_SPEED_MAX,   0.02,
        PSYS_SRC_TARGET_KEY,        target,
        PSYS_SRC_OMEGA,             <0.0, 0.0, 0.0>   ]);       
}

initiate()
{   //create a list of inventory types the updater has to offer the collar, store the updater version and open the listener
    // llSleep(2.0);
    list rPos = llGetLinkPrimitiveParams(g_link2,[PRIM_POSITION]);
    vector p = (llList2Vector(rPos,0) - llGetPos())/llGetRot();
    llSetLinkPrimitiveParamsFast(g_link,[PRIM_POSITION,p] + [PRIM_COLOR,ALL_SIDES,<0,0,.5>,1.0]); 
    line = 0;
    oldItemsToDelete = [];
    dataid = llGetNotecardLine(noteCard, line);
    llLinkParticleSystem(g_link,[]);
    llSetLinkColor(g_link, <0,0,.5>, ALL_SIDES);
    integer n;
    list types = [INVENTORY_SCRIPT, INVENTORY_OBJECT, INVENTORY_NOTECARD, INVENTORY_TEXTURE, INVENTORY_ANIMATION, INVENTORY_SOUND, INVENTORY_LANDMARK];
    integer iStop = llGetListLength(types);
    for (n = 0; n < iStop; n++)
    {
        integer type = llList2Integer(types, n);
        integer iNum = llGetInventoryNumber(type);
        if (iNum > 0)
        {
            if (type == INVENTORY_SCRIPT || type == INVENTORY_NOTECARD)
            {
                if (iNum > 1)
                {
                    offering += [type];
                }
            }
            else
            {
                offering += [type];
            }
            while(iNum/g_iItemPageSize)
            {
                offering += [type+100*(iNum/g_iItemPageSize)];
                iNum -= g_iItemPageSize;
            }
        }
    }

    UnRunScripts();
    versionstring = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 1);
    version = (float)versionstring;
    instructions = "CollarDB Update - " + llGetSubString((string)version, 0, 4) + "\nTo update your collar (version 3.020 or later):\n1 - Rez it next to me.\n2 - Touch the collar and select Help/Debug->Update";
    updatetext(LINK_ROOT,instructions, <1,1,1>, 1);
    myKey = llGetKey();
    listenhandle = llListen(updatechannel, "", "", "");
    instructions = "\nTo update your collar (version 3.020 or later):\n1 - Rez it next to me.\n2 - Touch the collar and select Help/Debug->Update";
    llOwnerSay(instructions);
}

UnRunScripts()
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
            {
                //somehow we got passed a script we can't find.  Wait a sec and try again
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

OfferUpdate(key id)
{
    UpdateParticle(id, <1,0,0>);
    llSetLinkColor(g_link, <1,0,1>, ALL_SIDES);
    updatetext(LINK_ROOT,hoverText + "Preparing Update", <1,1,0>, 1);
    llDialog(llGetOwner(),"Update started, please wait until it finished completely.\nThis will take 1 to 5 minutes.", ["Ok"],-47114711);
    string message = "toupdate|" + llDumpList2String(offering, "|");
    llWhisper(updatechannel, message);
}

GiveItemList(integer iPageType)
{
    integer type = iPageType % 100;
    integer i = 20*(iPageType/100);
    list items;
    integer iStop = i+20;
    integer iNum = llGetInventoryNumber(type);
    if (iStop > iNum)
    {
        iStop = iNum;
    }
    string sItemName;
    for( ; i < iStop; i++)
    {
        sItemName = llGetInventoryName(type, i);
        if (type == INVENTORY_SCRIPT)
        {
            if (!isUpdateManagerScript(sItemName))
            {
                items += sItemName;
            }
        }
        else if (type == INVENTORY_NOTECARD)
        {
            if (sItemName != noteCard)
            {
                items += sItemName;
            }
        }
        else
        {
            items += sItemName;
        }
    }
    string myItems = llDumpList2String(items, "|");
    llWhisper(updatechannel, "items|" + (string)iPageType + "|" + myItems);
}

CopyUpdateManager(key id, integer updatePin_local)
{
    string name;
    integer n;
    debug("sending updateManager script");
    integer iStop = llGetInventoryNumber(INVENTORY_SCRIPT);
    for (n = 0; n < iStop; n++)
    {
        name = llGetInventoryName(INVENTORY_SCRIPT, n);
        if("updateManager" == llList2String(llParseString2List(name, [" - ", "- ", " -", "-"], []), 1))//Should be " - " and we want it to be
        {
            updatetext(LINK_ROOT,name, <1,0,0>, 1);
            llRemoteLoadScriptPin(id, name, updatePin_local, TRUE, 42);
            n = iStop;		//end the loop
        }
    }
}

StartUpdate(key id, integer update)
{
    UpdateParticle(id, <1,1,1>);
    integer i;
    hoverText += "Updating Collar Items\n";
    llSetLinkColor(g_link, <0,0,1>, ALL_SIDES);
    updatetext(LINK_ROOT,hoverText, <1,0,0>, 1);
    string name;
    debug("sending non script items");
    for (i = 0; i < llGetListLength(offering); i++)
    {
        integer type = llList2Integer(offering, i);
        if (type != INVENTORY_SCRIPT)
        {
            integer n;
            integer iStop = llGetInventoryNumber(type);
            for(n = 0; n < iStop; n++)
            {
                name = llGetInventoryName(type, n);
                if(name != noteCard)
                {
                    float pct = (float)n / (float)iStop;
                    string per = (string)((integer)(pct * 100)) + "%";
                    updatetext(LINK_ROOT,hoverText + "▕"+Bars( pct, 10, Charset_LeftRight )+"▏ " + per + "\n" + name, <1,0,0>, 1);
                    llGiveInventory(id, name);
                }
            }
        }
    }
    debug("sending scripts");
    integer iStop = llGetInventoryNumber(INVENTORY_SCRIPT);
    for (i = 0; i < iStop; i++)
    {
        name = llGetInventoryName(INVENTORY_SCRIPT, i);
        if (!isUpdateManagerScript(name))
        {
            float pct = (float)i / (float)iStop;
            string per = (string)((integer)(pct * 100)) + "%";           
            updatetext(LINK_ROOT,hoverText + "▕"+Bars( pct, 10, Charset_LeftRight )+"▏ " + per + "\n" + name, <1,0,0>, 1);
            llRemoteLoadScriptPin(id, name, update, FALSE, 42);
        }
    }

    debug("done sending scripts, sending version command");
    //added a lil pause to let the update script deal with LMs
    llSleep(2.0);
    llWhisper(updatechannel, "version|" + (string)version);
    UpdateParticle(id, <1,0,0>);
    updatetext(LINK_ROOT,"PLEASE WAIT\nFinalizing Update", <1,0,0>, 1);

}

string Bars( float Cur, integer Bars, list Charset ){
    // Input    = 0.0 to 1.0
    // Bars     = char length of progress bar
    // Charset  = [Blank,<Shades>,Solid];
    integer Shades = llGetListLength(Charset)-1;
            Cur *= Bars;
    integer Solids  = llFloor( Cur );
    integer Shade   = llRound( (Cur-Solids)*Shades );
    integer Blanks  = Bars - Solids - 1;
    string str;
    while( Solids-- >0 ) str += llList2String( Charset, -1 );
    if( Blanks >= 0 ) str += llList2String( Charset, Shade );
    while( Blanks-- >0 ) str += llList2String( Charset, 0 );
    return str; }
    
    
updatetext(integer link, string text, vector color, float alpha)
{
    text = "CollarDB - Updater\n=================\n" + text + "\n=================\n";
    llSetLinkPrimitiveParamsFast(link,[PRIM_TEXT,text,color,alpha]);
}
  

default
    //state to eleminate multiple updaters
{
    state_entry()
    {
        GetSphereLink();
        list rPos = llGetLinkPrimitiveParams(g_link2,[PRIM_POSITION]);
        vector p = (llList2Vector(rPos,0) - llGetPos())/llGetRot();
        llSetLinkPrimitiveParamsFast(g_link,[PRIM_POSITION,p] + [PRIM_COLOR,ALL_SIDES,<0,0,.5>,1.0]);    
        g_keyWearer=llGetOwner();
        // init the double updater search
        updatetext(LINK_ROOT,"Updater is initalizing. Please wait ...",<1,0,0>,1.0);
        // listen on a channel
        llListen(g_nDoubleCheckChannel,"",NULL_KEY,"");
        // and say on the smae channel we are here
        llSay(g_nDoubleCheckChannel,"UpdateCheck:"+(string)llGetKey());
        // doublecheck with a sensor in casse lags eats us, listener i to avoid to many object near
        llSensor("", NULL_KEY, SCRIPTED, 15, PI);
        llSetTimerEvent(2.0);
        hoverText = "";
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }
    changed(integer change)
    {
        if(change & CHANGED_INVENTORY)
        {
            llSleep(2.0);
            llResetScript();
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        if ((channel==g_nDoubleCheckChannel)&&(llGetOwnerKey(id)==llGetOwner()))
        {
            // we received our owner message back
            if (message=="UpdateCheck:"+(string)llGetKey())
            {
                // so we delete ourself
                llOwnerSay("There is more than one CollarDB Collar Updater rezzed from you. Please use only one updater.");
                //Nan: this llDie() is an incredible pain in the ass when I'm trying to compare the contents of two updaters.  A warning is enough.  llDie is overkill.
                //Cleo: It leads to probles if we dotn kil it, we might change the updater method when the new updater is in place, for now we kil the updater again, if it doesnt have "text" in the name
                //Star better just kill the updater part
                state inactive;
                //if (llSubStringIndex(llToLower(llGetObjectName()),"test")==-1)
                //{
                //    llDie();
                //}
            }
            else
            {
                llSay(g_nDoubleCheckChannel,message);
            }
        }
    }

    sensor(integer num_detected)
    {
        // our sensor check, we check all object that are scripted
        integer i;
        for (i = 0; i < num_detected; i++)
        {
            if ((llDetectedKey(i) != llGetKey())&&(llGetOwnerKey(llDetectedKey(i))==llGetOwner()))
                // do they belong to us?
            {
                if (llGetSubString(llDetectedName(i), 0, 16) == "CollarDBUpdater")
                    // now starts it with a name like ours?
                {
                    llOwnerSay("There is more than one CollarDB Collar Updater rezzed from you. Please use only one updater.");
                    //Nan: this llDie() is an incredible pain in the ass when I'm trying to compare the contents of two updaters.  A warning is enough.  llDie is overkill.
                    //Cleo: It leads to probles if we dotn kil it, we might change the updater method when the new updater is in place, for now we kil the updater again, if it doesnt have "text" in the name
                    //Star better just kill the updater part
                    state inactive;
                    //if (llSubStringIndex(llToLower(llGetObjectName()),"test")==-1)
                    //{
                    //    llDie();
                    //}
                }
            }
        }
    }


    timer()
    {
        // now answer from another upder, so all is good, back to normal updating mode
        state updating;
    }

}



state updating
{
    state_entry()
    {
        initiate();
        // we need to listen to the double check channel as long as  we exists
        llListen(g_nDoubleCheckChannel,"",NULL_KEY,"");
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }
    changed(integer change)
    {
        if(change & CHANGED_INVENTORY)
        {
            llSleep(2.0);
            llResetScript();
        }
    }
    dataserver(key id, string data)
    {
        if (id == dataid)
        {
            if(data != EOF)
            {
                oldItemsToDelete += [data];
                line++;
                dataid = llGetNotecardLine(noteCard, line);
            }
            else
            {
                line = 0;
            }
        }
    }
    touch_start(integer num_detected)
    {
        if(llDetectedKey(0) == llGetOwner())
        {
            if (!g_iRecentlyTouched)
            {
                llOwnerSay("Have me close to your CollarDB Version 3.020 or higher and select in the Collar's Help/Debug menu Update.\nIf your version is 3.525 or higher, touch this orb again before "+(string)((integer)g_fSecondTouchDelay)+" seconds to start updating.");
                g_iRecentlyTouched = TRUE;
                llSetTimerEvent(g_fSecondTouchDelay);
            }
            else
            {
                integer iChan = (integer)("0x"+llGetSubString((string)g_keyWearer,2,7)) + 1111;
                if (iChan>0) iChan=iChan*(-1);
                if (iChan > -10000) iChan -= 30000;
                llWhisper(iChan, "update");
            }
        }
    }
    listen(integer channel, string name, key id, string message)
    {
        if (llGetOwnerKey(id) == llGetOwner()) //collar has to have the same owner as the updater!
        {
            if (channel==g_nDoubleCheckChannel)
                // we still check the double updater channel
            {
                // abnd replay if we get a message here
                llSay(g_nDoubleCheckChannel,message);
            }
            else if(channel == DEBUG_CHANNEL)
            {
                debugMessage = message;
            }
            else
            {
                debug(message);
                list temp = llParseString2List(message, ["|"], []);
                string command0 = llList2String(temp,0);
                string command1 = llList2String(temp,1);
                if (command0 == "UPDATE")
                {// Collar responded with update
                    if ((float)command1 > 3.221 && (float)command1 < version)
                    {//Collar version is at least 3.000 and lower than to Update version
                        llWhisper(updatechannel, "get ready");
                    }
                    if (command1 == "X")
                    {//Collar is 3.706 or higher, so replace everything anywat
                        llWhisper(updatechannel, "get ready");
                    }
                    else if ((float)command1 > 3.019 && (float)command1 < version)
                    {//Collar version is at least 3.000 and lower than to Update version
                        llWhisper(updatechannel, "items,0,0");
                    }
                    else if ((float)command1 < 3.000 )
                    {
                        llWhisper(updatechannel, "nothing to update");
                        llOwnerSay("Your CollarDB is previous version 3 and cannot be updated this way, please get an CollarDB Version 3 or higher first.");
                    }
                    else if ((float)command1 >= 20111001.1)
                    {//Collar is 3.706 or higher, so replace everything anywat
                        llWhisper(updatechannel, "get ready");
                    }
                    else if ((float)command1 >= version)
                    {
                        llWhisper(updatechannel, "nothing to update");
                        llOwnerSay("Your CollarDB is the same or newer version, nothing to update.");
                    }
                }
                else if (command0 == "ready")
                {// Collar responed everything is ready, douplicate items were deleted so start to send stuff over
                    list idpos = llGetObjectDetails(id,[OBJECT_POS]);
                    vector movepos = ((vector)llList2String(idpos,0) - llGetPos())/ llGetRot();
                     llSetLinkPrimitiveParamsFast(g_link,[PRIM_POSITION,movepos]  + [PRIM_COLOR,ALL_SIDES,<0,0,.5>,0.25]);
                    updatePin = (integer)command1;
                    CopyUpdateManager(id, updatePin);
                    // StartUpdate(id, (integer)command1, TRUE);
                    //llSleep(2);
                    llWhisper(updatechannel, "link|" + (string)id);
                }
                else if (command0 == "Manager Ready")
                {
                    if ((key)command1 == myKey)
                    {
                        g_kCollar = id;
                        state linked;
                    }
                }
            }
        }
    }

    timer()
    {
        llSetTimerEvent(0);
        g_iRecentlyTouched = FALSE;
    }
}

state linked
{
    state_entry()
    {
        llListenRemove(listenhandle);
        listenhandle = llListen(updatechannel, "", g_kCollar, "");
        debughandle = llListen(DEBUG_CHANNEL, "", g_kCollar, "");
        if (llGetListLength(oldItemsToDelete) > 0 && llToLower(llList2String(oldItemsToDelete, 0)) != "nothing")
        {
            integer iLen = llGetListLength(oldItemsToDelete);
            integer i=0;
            for(;i < iLen-1;i=i+50)
            {
                llWhisper(updatechannel, "delete|" + llDumpList2String(llList2List(oldItemsToDelete,i,i+50), "|"));
            }
            llWhisper(updatechannel, "deleteDone|");            
        }
        else
        {
            OfferUpdate(g_kCollar);
        }
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }
    changed(integer change)
    {
        if(change & CHANGED_INVENTORY)
        {
            llSleep(2.0);
            llResetScript();
        }
    }
    listen(integer channel, string name, key id, string message)
    {
        if (llGetOwnerKey(id) == llGetOwner()) //collar has to have the same owner as the updater!
        {
            if(channel == DEBUG_CHANNEL)
            {
                debugMessage = message;
            }
            else
            {
                debug(message);
                list temp = llParseString2List(message, ["|"], []);
                string command0 = llList2String(temp,0);
                string command1 = llList2String(temp,1);
                if (message == "deletedOld")
                {
                    OfferUpdate(id); // give a list of item types to update
                }
                else if (command0 == "giveList")
                {// Collar requested a list of items of one type, send a list of item that will be copied
                    GiveItemList((integer)command1);
                }
                else if (message == "ready to receive")
                {
                    StartUpdate(id, updatePin);
                }
                else if (message == "copying child scripts")
                {
                    updatetext(LINK_ROOT,"PLEASE WAIT\nFinalizing Update\nCopying Scripts to Childprims", <1,0,0>, 1);
                }
                else if (message == "restarting collar scripts")
                {
                    updatetext(LINK_ROOT,"PLEASE WAIT\nFinalizing Update\nRestarting CollarDB scripts.", <1,0,0>, 1);
                }
                else if (command0 == "finished")
                {// lets be sure also the update script is resetted before showing this
                    llSleep(2.0);
                    llSetLinkColor(g_link, <0,1,0>, ALL_SIDES);
                    updatetext(LINK_ROOT,"Update Finished.\nYour collar has been updated to:\n" + llGetSubString((string)version, 0, 4), <0,1,0>, 1);
                    hoverText = "PLEASE WAIT\n";
                    llLinkParticleSystem(g_link,[]);
                    //get the info about the version and show the user a appropiate wiki page:
                    string sURL;
                    string sInfo;
                    integer iMainVersion = (integer)llGetSubString(versionstring,0,0);
                    integer iMinorVersion = (integer)llGetSubString(versionstring,2,2);
                    integer iSubVersion = (integer)llGetSubString(versionstring,3,4);
                    if (iSubVersion<20)
                    {
                        // normal version
                        if (iSubVersion == 0)
                        {
                            sURL = RELESENOTE_URL + llGetSubString(versionstring,0,0) + llGetSubString(versionstring,2,2);

                        }
                        else
                        {
                            sURL = RELESENOTE_URL + llGetSubString(versionstring,0,0) + llGetSubString(versionstring,2,2) + llGetSubString(versionstring,3,4);
                        }
                        sInfo = "\nYou find the release notes at our Wiki page.";
                    }
                    else
                    {
                        integer iMilestone = (integer)llGetSubString(versionstring,2,2);
                        sURL = ISSUETRACKER_URL + llGetSubString(versionstring,0,0) + "." + (string)(iMilestone + 1);
                        sInfo = "\nAll issue for the upcoming release can be found at our issue tracker.";
                    }
                    llLoadURL(llGetOwner(),"Update finished!\nYour collar has been updated to:\n" + versionstring + sInfo, sURL);

                    if(debugMessage != "")
                    {
                        llOwnerSay("You may have seen an error:\n \"" + debugMessage + "\".\nThis should be nothing to worry. You may point the designer of this collar to it though.");
                    }
                    llResetScript();
                }
            }
        }
    }

    timer()
    {
        llSetTimerEvent(0);
        //dont think this is needed as we do not get here till linked.
    }
}


state inactive
{
    state_entry()
    {
        llSetLinkColor(g_link, <1,1,0>, ALL_SIDES);		//yellow for inactive
        updatetext(LINK_ROOT,"Deactivated due to another updater close by\nRerez to reactiavte", <1,1,0>, 1);
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }
}