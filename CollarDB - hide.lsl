//CollarDB - hide - 3.530
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.
//on getting menu request, give element menu
//on getting element type, give Hide and Show buttons
//on hearing "hide" or "Show", do that for the current element type

string g_sParentMenu = "Appearance";
string g_sSubMenu = "Hide/Show";

list g_lElements;

key g_kWearer;

key g_kDialogID;

string g_sDBToken = "elementalpha";
list g_lAlphaSettings;
string g_sIgnore = "nohide";
string g_sCurrentElement;
list g_lButtons;

integer g_iAppLock = FALSE;
string g_sAppLockToken = "AppLock";


//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer CHAT = 505;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent when a token has no value in the httpdb

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

//5000 block is reserved for IM slaves

string HIDE = "Hide ";
string SHOW = "Show ";
string UPMENU = "^";
string SHOWN = "Shown";
string HIDDEN = "Hidden";
string ALL = "All";

Notify(key keyID, string sMsg, integer nAlsoNotifyWearer)
{
    if (keyID == g_kWearer)
    {
        llOwnerSay(sMsg);
    }
    else
    {
        llInstantMessage(keyID,sMsg);
        if (nAlsoNotifyWearer)
        {
            llOwnerSay(sMsg);
        }
    }
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}


SetAllElementsAlpha(float fAlpha)
{
    //loop through element list, setting all alphas
    //integer n;
    //integer stop = llGetListLength(g_lElements);
    //for (n = 0; n < stop; n++)
    //{
    //    string element = llList2String(g_lElements, n);
    //    SetElementAlpha(element, fAlpha);
    //}

    llSetLinkAlpha(LINK_SET, fAlpha, ALL_SIDES);
    //set alphasettings of all elements to fAlpha (either 1.0 or 0.0 here)
    g_lAlphaSettings = [];
    integer n;
    integer iStop = llGetListLength(g_lElements);
    for (n = 0; n < iStop; n++)
    {
        string sElement = llList2String(g_lElements, n);
        g_lAlphaSettings += [sElement, fAlpha];
    }
}

SetElementAlpha(string element_to_set, float fAlpha)
{
    //loop through links, setting color if element type matches what we're changing
    //root prim is 1, so start at 2
    integer n;
    integer iLinkCount = llGetNumberOfPrims();
    for (n = 2; n <= iLinkCount; n++)
    {
        string sElement = ElementType(n);
        if (sElement == element_to_set)
        {
            //set link to new color
            //llSetLinkPrimitiveParams(n, [PRIM_COLOR, ALL_SIDES, color, 1.0]);
            llSetLinkAlpha(n, fAlpha, ALL_SIDES);

            //update element in list of settings
            integer iIndex = llListFindList(g_lAlphaSettings, [sElement]);
            if (iIndex == -1)
            {
                g_lAlphaSettings += [sElement, fAlpha];
            }
            else
            {
                g_lAlphaSettings = llListReplaceList(g_lAlphaSettings, [fAlpha], iIndex + 1, iIndex + 1);
            }
        }
    }
}

SaveAlphaSettings()
{
    if (llGetListLength(g_lAlphaSettings)>0)
    {
        //dump list to string and do httpdb save
        llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sDBToken + "=" + llDumpList2String(g_lAlphaSettings, ","), NULL_KEY);
    }
    else
    {
        //dump list to string and do httpdb save
        llMessageLinked(LINK_SET, HTTPDB_DELETE, g_sDBToken, NULL_KEY);
    }

}

ElementMenu(key kAv)
{
    g_sCurrentElement = "";
    string sPrompt = "Pick which part of the collar you would like to hide or show";
    g_lButtons = [];
    //loop through elements, show appropriate buttons and prompts if hidden or shown

    integer n;
    integer iStop = llGetListLength(g_lElements);
    for (n = 0; n < iStop; n++)
    {
        string sElement = llList2String(g_lElements, n);
        integer iIndex = llListFindList(g_lAlphaSettings, [sElement]);
        if (iIndex == -1)
        {
            //element not found in settings list.  Assume it's currently shown
            //sPrompt += "\n" + element + " (" + SHOWN + ")";
            g_lButtons += HIDE + sElement;
        }
        else
        {
            float fAlpha = (float)llList2String(g_lAlphaSettings, iIndex + 1);
            if (fAlpha)
            {
                //currently shown
                //sPrompt += "\n" + element + " (" + SHOWN + ")";
                g_lButtons += HIDE + sElement;
            }
            else
            {
                //not currently shown
                //sPrompt += "\n" + sElement + " (" + HIDDEN + ")";
                g_lButtons += SHOW + sElement;
            }
        }
    }
    g_lButtons += [SHOW + ALL, HIDE + ALL];
    g_kDialogID=Dialog(kAv, sPrompt, g_lButtons, [UPMENU],0);
}

string ElementType(integer linkiNumber)
{
    string sDesc = (string)llGetObjectDetails(llGetLinkKey(linkiNumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to
    //not appear in the color or texture menus
    list lParams = llParseString2List(sDesc, ["~"], []);
    if ((~(integer)llListFindList(lParams, [g_sIgnore])) || sDesc == "" || sDesc == " " || sDesc == "(No Description)")
    {
        return g_sIgnore;
    }
    else
    {
        return llList2String(lParams, 0);
    }
}

BuildElementList()
{
    integer n;
    integer iLinkCount = llGetNumberOfPrims();

    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++)
    {
        string sElement = ElementType(n);
        if (!((~(integer)llListFindList(g_lElements, [sElement]))) && sElement != g_sIgnore)
        {
            g_lElements += [sElement];
            //llSay(0, "added " + sElement + " to elements");
        }
    }
    g_lElements = llListSort(g_lElements, 1, TRUE);


}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

integer AppLocked(key kID)
{
    if (g_iAppLock)
    {
        Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();
        //get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        string sPrefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (sPrefix != "")
        {
            g_sDBToken = sPrefix + g_sDBToken;
        }

        BuildElementList();

        //register menu button
        llSleep(1.0);
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    }

    on_rez(integer iParam)
    {
        llResetScript();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
            string sElement = llList2String(lParams, 1);

            if (sStr == "hide")
            {
                if (!AppLocked(kID))
                {
                    SetAllElementsAlpha(0.0);
                    SaveAlphaSettings();
                }
            }
            else if (sStr == "show")
            {
                if (!AppLocked(kID))
                {
                    SetAllElementsAlpha(1.0);
                    SaveAlphaSettings();
                }
            }
            else if (sStr == "hidemenu")
            {
                if (!AppLocked(kID))
                {
                    ElementMenu(kID);
                }
            }
            else if (StartsWith(sStr, "setalpha"))
            {
                if (!AppLocked(kID))
                {

                    //                    list lParams = llParseString2List(sStr, [" "], []);
                    //                    string sElement = llList2String(lParams, 1);
                    float fAlpha = (float)llList2String(lParams, 2);
                    SetElementAlpha(sElement, fAlpha);
                    SaveAlphaSettings();
                }
            }
            else if (StartsWith(sStr, "hide"))
            {
                if (!AppLocked(kID))
                {
                    //                    list lParams = llParseString2List(sStr, [" "], []);
                    //                    string sElement = llList2String(lParams, 1);
                    SetElementAlpha(sElement, 0.0);
                    SaveAlphaSettings();
                }
            }
            else if (StartsWith(sStr, "show"))
            {
                if (!AppLocked(kID))
                {
                    //                    list lParams = llParseString2List(sStr, [" "], []);
                    //                    string sElement = llList2String(lParams, 1);
                    SetElementAlpha(sElement, 1.0);
                    SaveAlphaSettings();
                }
            }
            else if (llGetSubString(sStr,0,13) == "lockappearance")
            {
                if (iNum == COMMAND_OWNER)
                {
                    if(llGetSubString(sStr, -1, -1) == "0")
                    {
                        g_iAppLock  = FALSE;
                    }
                    else
                    {
                        g_iAppLock  = TRUE;
                    }
                }
            }
            else if (sStr == "settings")
            {
                if (llGetAlpha(ALL_SIDES) == 0.0)
                {
                    Notify(kID, "Hiden", FALSE);
                }
            }
            else if (iNum == COMMAND_OWNER && sStr == "reset")
            {
                SetAllElementsAlpha(1.0);
                // no more self - resets
                //    llResetScript();
            }
            //else if (iNum == COMMAND_WEARER && (sStr == "reset" || sStr == "runaway"))
            else if ((iNum == COMMAND_WEARER || kID == llGetOwner()) && (sStr == "reset" || sStr == "runaway"))
            {
                SetAllElementsAlpha(1.0);
                // no more self - resets
                //    llResetScript();
            }
        }
        else if (iNum == HTTPDB_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            if (sToken == g_sDBToken)
            {
                //we got the list of alphas for each element
                g_lAlphaSettings = llParseString2List(sValue, [","], []);
                integer n;
                integer iStop = llGetListLength(g_lAlphaSettings);
                for (n = 0; n < iStop; n = n + 2)
                {
                    string sElement = llList2String(g_lAlphaSettings, n);
                    float fAlpha = (float)llList2String(g_lAlphaSettings, n + 1);
                    SetElementAlpha(sElement, fAlpha);
                }
            }
            else if (sToken == g_sAppLockToken)
            {
                g_iAppLock = (integer)sValue;
            }
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        }
        else if (iNum == SUBMENU && sStr == g_sSubMenu)
        {
            //give element menu
            ElementMenu(kID);
        }

        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID==g_kDialogID)
            {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);

                if (sMessage == UPMENU)
                {
                    if (g_sCurrentElement == "")
                    {
                        //main menu
                        llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
                    }
                    else
                    {
                        g_sCurrentElement = "";
                        ElementMenu(kAv);
                    }
                }
                else
                {
                    //get "Hide" or "Show" and element name
                    list lParams = llParseString2List(sMessage, [], [HIDE,SHOW]);
                    string sCmd = llList2String(lParams, 0);
                    string sElement = llList2String(lParams, 1);
                    float fAlpha;
                    if (sCmd == HIDE)
                    {
                        fAlpha = 0.0;
                    }
                    else if (sCmd == SHOW)
                    {
                        fAlpha = 1.0;
                    }

                    if (sElement == ALL)
                    {
                        if (sCmd == SHOW)
                        {
                            SetAllElementsAlpha(1.0);
                        }
                        else if (sCmd == HIDE)
                        {
                            SetAllElementsAlpha(0.0);
                        }
                    }
                    else if (sElement != "")//ignore empty element strings since they won't work anyway
                    {
                        SetElementAlpha(sElement, fAlpha);
                    }
                    SaveAlphaSettings();
                    ElementMenu(kAv);
                }
            }
        }
    }
}