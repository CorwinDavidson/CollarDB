//CollarDB - lock - 3.529
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.

list g_lOwners;

string g_sParentMenu = "Main";

string g_sRequestType; //may be "owner" or "secowner" or "rem secowner"
key g_kHTTPID;

integer g_iListenChan = 802930;//just something i randomly chose
integer g_iListener;

integer g_iLocked = FALSE;

string g_sLockPrimName="Lock"; // Description for lock elements to recognize them //EB //SA: to be removed eventually (kept for compatibility)
string g_sOpenLockPrimName="OpenLock"; // Prim description of elements that should be shown when unlocked
string g_sClosedLockPrimName="ClosedLock"; // Prim description of elements that should be shown when locked
list g_lClosedLockElements; //to store the locks prim to hide or show //EB
list g_lOpenLockElements; //to store the locks prim to hide or show //EB

string LOCK = "*Lock*";
string UNLOCK = "*Unlock*";

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;  // new for safeword

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer LOCALSETTING_SAVE = 2500;
integer LOCALSETTING_REQUEST = 2501;
integer LOCALSETTING_RESPONSE = 2502;
integer LOCALSETTING_DELETE = 2503;
integer LOCALSETTING_EMPTY = 2504;

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer g_iRemenu=FALSE;

//added to prevent altime attach messages
integer g_bDetached = FALSE;

key g_kWearer;

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
        // Cleo: Stop IMs going wild
        if (g_kWearer != llGetOwner())
        {
            llResetScript();
            return;
        }
        else
            Notify((key)llList2String(g_lOwners, n), sMsg, FALSE);
    }
}

string GetPSTDate()
{ //Convert the date from UTC to PST if GMT time is less than 8 hours after midnight (and therefore tomorow's date).
    string DateUTC = llGetDate();
    if (llGetGMTclock() < 28800) // that's 28800 seconds, a.k.a. 8 hours.
    {
        list DateList = llParseString2List(DateUTC, ["-", "-"], []);
        integer year = llList2Integer(DateList, 0);
        integer month = llList2Integer(DateList, 1);
        integer day = llList2Integer(DateList, 2);
        day = day - 1;
        return (string)year + "-" + (string)month + "-" + (string)day;
    }
    return llGetDate();
}

string GetTimestamp() // Return a string of the date and time
{
    integer t = (integer)llGetWallclock(); // seconds since midnight

    return GetPSTDate() + " " + (string)(t / 3600) + ":" + PadNum((t % 3600) / 60) + ":" + PadNum(t % 60);
}

string PadNum(integer value)
{
    if(value < 10)
    {
        return "0" + (string)value;
    }
    return (string)value;
}

BuildLockElementList()//EB
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    list lParams;

    // clear list just in case
    g_lOpenLockElements = [];
    g_lClosedLockElements = [];

    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++)
    {
        // read description
        lParams=llParseString2List((string)llGetObjectDetails(llGetLinkKey(n), [OBJECT_DESC]), ["~"], []);
        // check inf name is lock name
        if (llList2String(lParams, 0)==g_sLockPrimName || llList2String(lParams, 0)==g_sClosedLockPrimName)
        {
            // if so store the number of the prim
            g_lClosedLockElements += [n];
            //llOwnerSay("added " + (string)n + " to celements:  "+ llList2String(llGetObjectDetails(llGetLinkKey(n), [OBJECT_NAME]),0));
        }
        else if (llList2String(lParams, 0)==g_sOpenLockPrimName) 
        {
            // if so store the number of the prim
            g_lOpenLockElements += [n];
            //llOwnerSay("added " + (string)n + " to oelements: "+ llList2String(llGetObjectDetails(llGetLinkKey(n), [OBJECT_NAME]),0));
        }
    }
}

SetLockElementAlpha() //EB
{
    //loop through stored links, setting alpha if element type is lock
    integer n;
    float fAlpha;
    if (g_iLocked) fAlpha = 1.0; else fAlpha = 0.0;
    integer iLinkElements = llGetListLength(g_lOpenLockElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lOpenLockElements,n), 1.0 - fAlpha, ALL_SIDES);
    }
    iLinkElements = llGetListLength(g_lClosedLockElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lClosedLockElements,n), fAlpha, ALL_SIDES);
    }
}

Lock()
{
    g_iLocked = TRUE;
    llMessageLinked(LINK_SET, HTTPDB_SAVE, "locked=1", NULL_KEY);
    llMessageLinked(LINK_SET, RLV_CMD, "detach=n", NULL_KEY);
    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + UNLOCK, NULL_KEY);
    llPlaySound("abdb1eaa-6160-b056-96d8-94f548a14dda", 1.0);
    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + LOCK, NULL_KEY);
    SetLockElementAlpha();//EB
}

Unlock()
{
    g_iLocked = FALSE;
    llMessageLinked(LINK_SET, HTTPDB_DELETE, "locked", NULL_KEY);
    llMessageLinked(LINK_SET, RLV_CMD, "detach=y", NULL_KEY);
    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + LOCK, NULL_KEY);
    llPlaySound("ee94315e-f69b-c753-629c-97bd865b7094", 1.0);
    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + UNLOCK, NULL_KEY);
    SetLockElementAlpha(); //EB
}



default
{
    state_entry()
    {   //until set otherwise, wearer is owner
        g_kWearer = llGetOwner();
        //        g_lOwnersName = llKey2Name(llGetOwner());   //NEVER used
        g_iListenChan = -1 - llRound(llFrand(9999999.0));
        //no more needed
        //        llSleep(1.0);//giving time for others to reset before populating menu
        //        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + LOCK, NULL_KEY);
        
        BuildLockElementList();//EB
        SetLockElementAlpha(); //EB

    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (sStr == "settings" && iNum >= COMMAND_OWNER && iNum <=COMMAND_WEARER)
        {
            if (g_iLocked) Notify(kID, "Locked.", FALSE);
            else Notify(kID, "Unlocked.", FALSE);
        }
        else if ((sStr == "reset" || sStr == "runaway") && ((iNum == COMMAND_WEARER || iNum == COMMAND_OWNER ) && (kID==g_kWearer)))
        {
                llOwnerSay(llGetScriptName() + " - > UNLOCK");
                g_iRemenu = FALSE;
                Unlock();
                llOwnerSay("Your collar has been unlocked.");
        }
        else if ((sStr == "lock" || sStr == "unlock") && iNum >= COMMAND_OWNER && iNum <=COMMAND_WEARER)
        {
            if (sStr == "lock"){
                if (iNum == COMMAND_OWNER || kID == g_kWearer )
                {   //primary owners and wearer can lock and unlock. no one else
                    Lock();
                    //            owner = kID; //need to store the one who locked (who has to be also owner) here
                    Notify(kID, "Locked.", FALSE);
                    if (kID!=g_kWearer) llOwnerSay("Your collar has been locked.");
                }
                else
                {
                    Notify(kID, "Sorry, only primary owners and wearer can lock the collar.", FALSE);

                }
            }
            else if (sStr == "unlock")
            {
                if (iNum == COMMAND_OWNER)
                {  //primary owners can lock and unlock. no one else
                    Unlock();
                    Notify(kID, "Unlocked.", FALSE);
                    if (kID!=g_kWearer) llOwnerSay("Your collar has been unlocked.");
                }
                else
                {
                    Notify(kID, "Sorry, only primary owners can unlock the collar.", FALSE);
                }
            }
            if (g_iRemenu) {g_iRemenu=FALSE; llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kID);}
        }

        else if (iNum == HTTPDB_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == "locked")
            {
                g_iLocked = (integer)sValue;
                if (g_iLocked)
                {
                    llMessageLinked(LINK_SET, RLV_CMD, "detach=n", NULL_KEY);
                    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + UNLOCK, NULL_KEY);
                    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + LOCK, NULL_KEY);
                }
                else
                {
                    llMessageLinked(LINK_SET, RLV_CMD, "detach=y", NULL_KEY);
                    llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + LOCK, NULL_KEY);
                    llMessageLinked(LINK_SET, MENUNAME_REMOVE, g_sParentMenu + "|" + UNLOCK, NULL_KEY);
                }
                SetLockElementAlpha(); //EB

            }
            else if (sToken == "owner")
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
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            if (g_iLocked)
            {
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + UNLOCK, NULL_KEY);
            }
            else
            {
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + LOCK, NULL_KEY);
            }
        }
        else if (iNum == SUBMENU)
        {
            if (sStr == LOCK)
            {
                g_iRemenu=TRUE;
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "lock", kID);
            }
            else if (sStr == UNLOCK)
            {
                g_iRemenu=TRUE;
                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "unlock", kID);
            }
        }

        else if (iNum == RLV_REFRESH)
        {
            if (g_iLocked)
            {
                llMessageLinked(LINK_SET, RLV_CMD, "detach=n", NULL_KEY);
            }
            else
            {
                llMessageLinked(LINK_SET, RLV_CMD, "detach=y", NULL_KEY);
            }
        }
        else if (iNum == RLV_CLEAR)
        {
            if (g_iLocked)
            {
                llMessageLinked(LINK_SET, RLV_CMD, "detach=n", NULL_KEY);
            }
            else
            {
                llMessageLinked(LINK_SET, RLV_CMD, "detach=y", NULL_KEY);
            }
        }

    }
    attach(key kID)
    {
        if (g_iLocked)
        {
            if(kID == NULL_KEY)
            {
                g_bDetached = TRUE;
                NotifyOwners(llKey2Name(g_kWearer) + " has detached me while locked at " + GetTimestamp() + "!");
            }
            else if(g_bDetached)
            {
                NotifyOwners(llKey2Name(g_kWearer) + " has re-atached me at " + GetTimestamp() + "!");
                g_bDetached = FALSE;
            }
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }

    on_rez(integer start_param)
    {
        // stop IMs going wild
        if (g_kWearer != llGetOwner())
        {
            llResetScript();
        }
    }

}