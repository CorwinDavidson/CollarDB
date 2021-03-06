// CollarDB - Touch Monitor Plugin
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.
// 
// Version: 3.583
// Date: 2011/10/19
// By: Corwin Davidson

// Description:
//
//  Uses OC Auth system to see if the person touching the collar is an Owner (Primary or Secondary) or if it is the wearer.
//  If it is not, the owners are sent an IM stating who touched the collar and who's collar it was that was touched.
//
//  There are currently no Menu Configurable items.


list g_lOwners;

string g_sSubmenu = "Touch";
string g_sParentmenu = "AddOns";
string g_sChatCommand = "touchmon";


key g_kMenuID;  // menu handler
integer g_iDebugMode=FALSE; // set to TRUE to enable Debug messages

key g_kWearer; // key of the current wearer to reset only on owner changes

integer g_iReshowMenu=FALSE; 


list g_lLocalbuttons = []; 

list g_lButtons;

//OpenCollar MESSAGE MAP
integer JSON_REQUEST = 201;
integer JSON_RESPONSE = 202;

// messages for authenticating users
integer COMMAND_NOAUTH = 0;
integer COMMAND_COLLAR = 499; //added for collar or cuff commands to put ao to pause or standOff
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;
integer COMMAND_RELAY_SAFEWORD = 511;
integer COMMAND_BLACKLIST = 520;
// added for timer so when the sub is locked out they can use postions
integer COMMAND_WEARERLOCKEDOUT = 521;

// messages for storing and retrieving values from http db
integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db
integer HTTPDB_REQUEST_NOCACHE = 2005;

// same as HTTPDB_*, but for storing settings locally in the settings script
integer LOCALSETTING_SAVE = 2500;
integer LOCALSETTING_REQUEST = 2501;
integer LOCALSETTING_RESPONSE = 2502;
integer LOCALSETTING_DELETE = 2503;
integer LOCALSETTING_EMPTY = 2504;


// messages for creating OC menu structure
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

// messages to the dialog helper
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

integer TIMER_EVENT = -10000; // str = "start" or "end". For start, either "online" or "realtime".

integer UPDATE = 10001;//for hovertext to get ready?

// For other things that want to manage showing/hiding keys.
integer KEY_VISIBLE = -10100;
integer KEY_INVISIBLE = -10100;


string UPMENU = "^";


Debug(string sMsg)
{
    if (!g_iDebugMode) return;
    llOwnerSay(llGetScriptName() + ": " + sMsg);
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

NotifyOwners(string sMsg)
{
    integer n;
    integer stop = llGetListLength(g_lOwners);
    for (n = 0; n < stop; n += 2)
    {
        if (g_kWearer != llGetOwner())
        {
            llResetScript();
            return;
        }
        else
            Notify((key)llList2String(g_lOwners, n), sMsg, FALSE);
    }
}


key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

integer nStartsWith(string sHaystack, string sNeedle)
{
    return (llDeleteSubString(sHaystack, llStringLength(sNeedle), -1) == sNeedle);
}


DoMenu(key keyID)
{
    string sPrompt = "Touch Monitor 3.582\n\nUnauthorized touch's will be sent to all Primary and Secondary Owners\n\n";
    list lMyButtons = g_lLocalbuttons + g_lButtons;

    lMyButtons = llListSort(lMyButtons, 1, TRUE); 

    g_kMenuID = Dialog(keyID, sPrompt, lMyButtons, [UPMENU], 0);
}


string GetDBPrefix()
{
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}



default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
        llSleep(1.0);
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, g_sSubmenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentmenu + "|" + g_sSubmenu, NULL_KEY);
    }

    on_rez(integer iParam)
    {
        if (llGetOwner()!=g_kWearer)
        {
            llResetScript();
        }
    }

    touch_start(integer total_number)
    {
        integer i = 0;
        string touchers;
        for (i=0;i < total_number; i++)
        {
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "touch", llDetectedKey(i));
        }
    }


    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == SUBMENU && sStr == g_sSubmenu)
        {
            DoMenu(kID);
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentmenu)
        {

            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, g_sParentmenu + "|" + g_sSubmenu, NULL_KEY);
        }
        else if (iNum == MENUNAME_RESPONSE)
        {
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubmenu)
            {
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1)
                {
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iNum == HTTPDB_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "owner")
            {
                g_lOwners = llParseString2List(sValue, [","], []);
            }
        }
        else if (iNum == HTTPDB_SAVE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "owner")
            {
                g_lOwners = llParseString2List(sValue, [","], []);
            }
        }        
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER && iNum != COMMAND_GROUP)
        {
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));

            if (sStr == g_sChatCommand)
            {
                DoMenu(kID);
            }
        }
        else if (iNum == COMMAND_EVERYONE || iNum == COMMAND_GROUP)
        {
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
 
            if (sStr == "touch")
            {           
                NotifyOwners(llKey2Name(kID) + " touched " + llKey2Name(llGetOwner()) + "'s Collar");
                Notify(g_kWearer, (string)llKey2Name(kID) + " touched your Collar.",FALSE);
            }

        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == g_kMenuID)
            {
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_THIS, SUBMENU, g_sParentmenu, kAv);
                }
                else if (~llListFindList(g_lLocalbuttons, [sMessage]))
                {
                }
                else if (~llListFindList(g_lButtons, [sMessage]))
                {
                    llMessageLinked(LINK_THIS, SUBMENU, sMessage, kAv);
                }
            }
        }
        else if (iNum == DIALOG_TIMEOUT)
        {
            if (kID == g_kMenuID)
            {
                Debug("The user was to slow or lazy, we got a timeout!");
            }
        }
    }

}