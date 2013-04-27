//CollarDB - update
//
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.
//on attach and on state_entry, http request for update

key g_kWearer;

integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;

string g_sResetScripts = "resetscripts";

integer HTTPDB_SAVE = 2000;        //scripts send messages on this channel to have settings saved to httpdb
                                //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;    //when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;    //the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;    //delete token from DB
integer HTTPDB_EMPTY = 2004;    //sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer UPDATE = 10001;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

string g_sDBToken = "updatemethod";     //valid values are "replace" and "inplace"
string g_sUpdateMethod = "inplace";

integer g_iUpdateChildPin = 4711;        //not used?

string g_sParentMenu = "Help/Debug";
string g_sSubMenu1 = "Update";
string g_sSubMenu2 = "Get Update";

key g_kMenuID;

integer g_iUpdateChan = -7483214;
integer g_iUpdateHandle;

key g_kConfirmUpdate;
key g_kUpdaterOrb;

string g_sHTTPDB_Url = "http://update.collardb.com/"; //defaul OC url, can be changed in defaultsettings notecard and wil be send by settings script if changed
string g_sUpdatePath = "updater/check?";
key g_kHTTPUpdate;
integer g_iUpdateAvail = FALSE;
integer g_iUpdateMode=FALSE;
integer g_iUpdateBeta = FALSE;

list g_lResetFirst = ["menu", "rlvmain", "anim", "appearance"];

integer g_iChecked = FALSE;        //set this to true after checking version

key g_kUpdater; // key of avi who asked for the update
integer g_iUpdatersNearBy = -1;
integer g_iWillingUpdaters = -1;

//new for checking on resets in other collars:
integer g_iLastReset;

//should the menu pop up again?
integer g_iRemenu = FALSE;

Debug(string sMessage)
{
   // llOwnerSay(llGetScriptName() + ": " + sMessage);
}


key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer)
    {
        llOwnerSay(sMsg);
    }
    else
    {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer)
        {
            llOwnerSay(sMsg);
        }
    }
}

ConfirmUpdate(key kUpdater)
{
    string sPrompt = "Do you want to update with " + llKey2Name(kUpdater) + " with object key:" + (string)kUpdater +"\n"
    + "Do not rez any items till the update has started.";
    g_kConfirmUpdate = Dialog(g_kWearer, sPrompt, ["Yes", "No"], [], 0);
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

SafeResetOther(string sName)
{
    Debug("safely resetting: " + sName);
    if (llGetInventoryType(sName) == INVENTORY_SCRIPT)
    {
        if (IsCollarDBScript(sName))
        {
            llResetOtherScript(sName);
        }
        llSetScriptState(sName, TRUE);
    }
}

integer IsCollarDBScript(string name)
{
    name = llList2String(llParseString2List(name, [" - ", "- ", " -", "-"], []), 0);// we prefer " - "
    if (name == "CollarDB")
    {
        return TRUE;
    }
    return FALSE;
}

CheckForUpdate(integer iUpdateMode)
{
    Debug("Checking for update");
    list lParams = llParseString2List(llGetObjectDesc(), ["~"], []);
    string sObjectName = llList2String(lParams, 0);
    string sObjectVersion = llList2String(lParams, 1);

    //handle in-place updates.
    if (g_sUpdateMethod == "inplace")
    {
        sObjectName = "CollarDBUpdater";
    }

    if (sObjectName == "" || sObjectVersion == "")
    {
        llOwnerSay("You have changed my description.  Automatic updates are disabled.");
    }
    else if ((float)sObjectVersion)
    {
        string sUrl = g_sHTTPDB_Url + g_sUpdatePath;
        sUrl += "object=" + llEscapeURL(sObjectName);
        sUrl += "&version=" + llEscapeURL(sObjectVersion);

        if (!iUpdateMode)
        {
            sUrl += "&update=no";
        }
        g_iUpdateMode = iUpdateMode;
        g_iUpdateBeta = FALSE;

        g_kHTTPUpdate = llHTTPRequest(sUrl, [HTTP_METHOD, "GET"], "");
    }
}

ReadyToUpdate(integer iDel)
{
    integer pin = (integer)llFrand(99999998.0) + 1; //set a random pin
    llSetRemoteScriptAccessPin(pin);
    llWhisper(g_iUpdateChan, "ready|" + (string)pin ); //give the ok to send update sripts etc...
}

OrderlyReset(integer iFullReset, integer iIsUpdateReset)
{
    integer i;
    llOwnerSay("CollarDB scripts initializing...");

    //put in here the full name of each script named in g_lResetFirst.  Then loop through and reset
    //we initialize the list by setting equal to g_lResetFirst to ensure that indices will line up
    Debug("Resetting menu-hosting scripts");
    list lResetFirstFullNames = g_lResetFirst;
    for (i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {
        string sFullName = llGetInventoryName(INVENTORY_SCRIPT, i);
        string sPartialName = llList2String(llParseString2List(sFullName, [" - "], []) , 1);
        Debug("Checking Script: " + sFullName);
        if(IsCollarDBScript(sFullName))
        {
            integer iScriptPos = llListFindList(g_lResetFirst, [sPartialName]);
            Debug("CS: " + sPartialName + " }{ " + (string)iScriptPos);
            if (iScriptPos != -1)
            {
                //add to lResetFirstFullNames in same position as iScriptPos
                lResetFirstFullNames = llListReplaceList(lResetFirstFullNames, [sFullName], iScriptPos, iScriptPos);
            }
            else if(sFullName != llGetScriptName() && sPartialName != "settings" && sPartialName != "updateManager")
            {
                lResetFirstFullNames += [sFullName];
            }
        }
        else
        {
            lResetFirstFullNames += [sFullName];
        }
    }
    //now loop through lResetFirstFullNames and reset
    integer iStop = llGetListLength(lResetFirstFullNames);
    for (i = 0; i < iStop; i++)
    {
        //do not reset rlvmain on rez, only on a full reset (since it maintains its own local settings)
        string sFullName = llList2String(lResetFirstFullNames, i);
        string sPartialName = llList2String(llParseString2List(sFullName, [" - "], []) , 1);
        Debug("CHECKING: " + sFullName );
        if ((iFullReset) || (sPartialName != "rlvmain" && sPartialName != "settings" && sPartialName != "updateManager"))
        {
            if (llSubStringIndex(sFullName, "@") != -1)
            { //just check once more if some childprim script remained and delete if
                SafeRemoveInventory(sFullName);
            }
            else
            {
                SafeResetOther(sFullName);
            }
        }
    }
    //send a message to childprim scripts to reset themselves
    llMessageLinked(LINK_ALL_OTHERS, UPDATE, "reset", NULL_KEY);
    for (i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {   //last before myself reset the settings script
        string sFullScriptName = llGetInventoryName(INVENTORY_SCRIPT, i);
        string sScriptName = llList2String(llParseString2List(sFullScriptName, [" - "], []) , 1);
        if(IsCollarDBScript(sFullScriptName) && sScriptName == "settings")
        {
            Debug("Restting settings script");
            SafeResetOther(sFullScriptName);
        }
    }
    llSleep(1.5);
    llMessageLinked(LINK_SET, COMMAND_OWNER, "refreshmenu", NULL_KEY);
    if (iIsUpdateReset)
    {
        llMessageLinked(LINK_SET, UPDATE, "Reset Done", NULL_KEY);
    }
}

RestedInit()
{
    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu1, NULL_KEY);

    if (g_iUpdateAvail)
    {
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu2, NULL_KEY);
        llOwnerSay("There is an updated version of the collar available. To receive the updater, click the 'Get Update' button below, or click '"+g_sParentMenu+"' in the menu, then '"+g_sSubMenu2+"' if you wish to get it later on.");
        g_kMenuID = Dialog(g_kWearer, "\nThere is an updated version of the collar available.\nTo receive the updater, click the 'Get Update' button below, or click '"+g_sParentMenu+"' in the menu, then '"+g_sSubMenu2+"' if you wish to get it later on. ", ["Get Update"], ["Cancel"], 0);
    }

    llSetTimerEvent(10.0);
}

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
            //we're in something else.  Thunderbirds Go!

            g_iUpdateMode = FALSE;
            g_iUpdateAvail = FALSE;

            g_kWearer = llGetOwner();
            Debug("state default");
            //set our g_iLastReset to the time of our startup
            g_iLastReset = llGetUnixTime();
            OrderlyReset(TRUE, TRUE);
            llSleep(1.5);
            llMessageLinked(LINK_SET, COMMAND_OWNER, "refreshmenu", NULL_KEY);
            state reseted;
        }
    }
}


state reseted
{
    state_entry()
    {
        g_iUpdateAvail = FALSE;
        g_iUpdateMode = FALSE;

        g_kWearer = llGetOwner();
        Debug("state reseted");
        RestedInit();
    }

    on_rez(integer iParam)
    {
        Debug("rezzed");
        if (g_kWearer == llGetOwner())
        {
            Debug("no owner change");
            g_iChecked = FALSE;
            llSleep(1.5);
            RestedInit();
        }
        else
        {
            Debug("owner change");
            llResetScript();
        }
        g_iUpdateMode = FALSE;



    }

    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        if (kID == g_kHTTPUpdate)
        {Debug("test1");
                list l=llParseString2List(sBody, ["|"], []);
                if (llGetListLength(l) == 2)
                {
                    if (g_iUpdateMode)
                    {
                        llOwnerSay("An updater will be delivered to you shortly.");
                    }
                    else
                    {
                        llOwnerSay("There is an updated version of the collar available. To receive '"+llList2String(l,1)+"', click the 'Get Update' button below, or click '"+g_sParentMenu+"' in the menu, then '"+g_sSubMenu2+"' if you wish to get it later on.");
                        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu2, NULL_KEY);
                        g_iUpdateAvail = TRUE;
                        g_kMenuID = Dialog(g_kWearer, "\nThere is an updated version of the collar available.\nTo receive '"+llList2String(l,1)+"', click the 'Get Update' button below, or click '"+g_sParentMenu+"' in the menu, then '"+g_sSubMenu2+"' if you wish to get it later on. ", ["Get Update"], ["Cancel"], 0);
                    }
                }
                if (g_iUpdateBeta == FALSE)
                {
                    llSleep(1.0);
                    list lParams = llParseString2List(llGetObjectDesc(), ["~"], []);
                    string sObjectVersion = llList2String(lParams, 1);
                    list lObjectVersion = llParseString2List(sObjectVersion, ["."], []);
                    if ((integer)llGetSubString(llList2String(lObjectVersion, 1), 1, -1) >= 20)
                    {
                        g_iUpdateBeta = TRUE;
                        string sUrl = g_sHTTPDB_Url + g_sUpdatePath;
                        sUrl += "object=" + llEscapeURL("CollarDBUpdater Dev/Beta/RC");
                        sUrl += "&version=" + llEscapeURL(sObjectVersion);
                        if (!g_iUpdateMode)
                        {
                            sUrl += "&update=no";
                        }
                        g_kHTTPUpdate = llHTTPRequest(sUrl, [HTTP_METHOD, "GET"], "");
                        return;
                    }
                }

                g_iUpdateBeta = FALSE;
                g_iUpdateMode = FALSE;
            }
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {

        if (iNum == SUBMENU)
        {
            if (sStr == g_sSubMenu1)
            {
                g_iRemenu = TRUE;
                llMessageLinked(LINK_THIS, COMMAND_NOAUTH, "update", kID);
            }
            else if (sStr == g_sSubMenu2)
            {
                if (kID == g_kWearer)
                {
                    llOwnerSay("Contacting the servers now to check if a new version is available.");
                    CheckForUpdate(TRUE);
                }
                else
                {
                    Notify(kID,"Only the wearer can request updates for the collar.",FALSE);
                }
            }
        }
        else if (iNum == HTTPDB_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == g_sDBToken)
            {
                g_sUpdateMethod = sValue;
            }
            //#################################################################
            //added to get the script in this collar aware when the last general collar reset happened and if one happened to reset scripts
            else if (sToken = "lastReset")
            {
                if (g_iLastReset < (integer)sValue)
                {
                    g_iLastReset = (integer)sValue;
                    //reset scripts
                    OrderlyReset(TRUE, FALSE);
                    RestedInit();
                }
            }
            else if (sToken == "HTTPDB")
            {
                g_sHTTPDB_Url = sValue;
            }
        }
        else if (iNum == HTTPDB_SAVE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken = "lastReset")
            {
                if (g_iLastReset <= (integer)sValue)
                {
                    g_iLastReset = (integer)sValue;
                }
            }
        }
        //#################################################################
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            if( (kID == g_kWearer || iNum == COMMAND_OWNER)
                && sStr == g_sResetScripts)
                {
                    Debug(sStr + (string)iNum);
                    OrderlyReset(TRUE, FALSE);
                    RestedInit();
                }
            else if (sStr == "update")
            {
                if (kID == g_kWearer)
                {
                    if (llGetAttached())
                    {
                        if (g_iRemenu) llMessageLinked(LINK_ROOT, SUBMENU, g_sParentMenu, kID);
                        g_iRemenu = FALSE;
                        Notify(kID, "Sorry, the collar cannot be updated while attached.  Rez it on the ground and try again.",FALSE);
                    }
                    else
                    {

                        string sVersion = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 1);
                        g_iUpdatersNearBy = 0;
                        g_iWillingUpdaters = 0;
                        g_kUpdater = kID;
                        Notify(kID,"Searching for nearby updater",FALSE);
                        g_iUpdateHandle = llListen(g_iUpdateChan, "", "", "");
                        llWhisper(g_iUpdateChan, "UPDATE|" + sVersion);
                        llSetTimerEvent(10.0); //set a timer to close the g_iListener if no response
                    }
                }
                else
                {
                    if (g_iRemenu) llMessageLinked(LINK_ROOT, SUBMENU, g_sParentMenu, kID);
                    g_iRemenu = FALSE;
                    Notify(kID,"Only the wearer can update the collar.",FALSE);
                }
            }
        }
        else if (iNum == MENUNAME_REQUEST)
        {
            if (sStr == g_sParentMenu)
            {
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu1, NULL_KEY);
                if     (g_iUpdateAvail)
                {
                    // if there is an update, show the button for it
                    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu2, NULL_KEY);
                }
            }
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == g_kMenuID)
            {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);

                if (sMessage=="Get Update")
                {
                    llOwnerSay("Contacting the servers now to check if a new version is available.");
                    CheckForUpdate(TRUE);
                }
            }
            else if (kID == g_kConfirmUpdate)
            {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                if (sMessage == "Yes")
                {
                    ReadyToUpdate(TRUE);//any num will do
                }
            }
        }
    }

    listen(integer iChan, string sName, key kID, string sMessage)
    {   //collar and updater have to have the same Owner else do nothing!
        Debug(sMessage);
        if (llGetOwnerKey(kID) == g_kWearer)
        {
            list lTemp = llParseString2List(sMessage, [","],[]);
            string sCommand = llList2String(lTemp, 0);
            if(sMessage == "nothing to update")
            {
                g_iUpdatersNearBy++;
            }
            else if( sMessage == "get ready")
            {
                g_iUpdatersNearBy++;
                g_iWillingUpdaters++;
                g_kUpdaterOrb = kID;
            }
        }
    }
    timer()
    {
        Debug("timer");
        llSetTimerEvent(0.0);
        llListenRemove(g_iUpdateHandle);
        if (g_iUpdatersNearBy > -1) {
            if (!g_iUpdatersNearBy) {
                Notify(g_kUpdater,"No updaters found.  Please rez an updater within 10m and try again",FALSE);
            } else if (g_iWillingUpdaters > 1) {
                    Notify(g_kUpdater,"Multiple updaters were found within 10m.  Please remove all but one and try again",FALSE);
            } else if (g_iWillingUpdaters) {
                ConfirmUpdate(g_kUpdaterOrb);
            }
            g_iUpdatersNearBy = -1;
            g_iWillingUpdaters = -1;
            g_iUpdateAvail = FALSE;
        }
        if (!g_iChecked)
        {
            if (llGetAttached())
            {
                if (!g_iUpdateAvail)
                {
                    CheckForUpdate(FALSE);
                }
            }
            g_iChecked = TRUE;
        }
    }
}