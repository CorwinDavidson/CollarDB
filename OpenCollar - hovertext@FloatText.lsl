//OpenCollar - hovertext@FloatText - 3.526
string g_sParentMenu = "AddOns";
string g_sSubMenu = "FloatText";

//has to be same as in the update script !!!!
integer g_iUpdatePin = 4711;

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
integer SEND_IM = 1000;
integer POPUP_HELP = 1001;
integer UPDATE = 10001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;

vector g_vHideScale = <.02,.02,.02>;
vector g_vShowScale = <.02,.02,1.0>;

integer g_iLastRank = 0;
integer g_iOn = FALSE;
string g_sText;
vector g_vColor;

string g_sDBToken = "hovertext";

key g_kWearer;

Debug(string sMsg)
{
    //llOwnerSay(llGetScriptName() + " (debug): " + sMsg);
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer)
{
    if (kID == g_kWearer) {
        llOwnerSay(sMsg);
    } else {
            llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) {
            llOwnerSay(sMsg);
        }
    }
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

ShowText(string sNewText)
{
    g_sText = sNewText;
    list lTmp = llParseString2List(g_sText, ["\\n"], []);
    if(llGetListLength(lTmp) > 1)
    {
        integer i;
        sNewText = "";
        for (i = 0; i < llGetListLength(lTmp); i++)
        {
            sNewText += llList2String(lTmp, i) + "\n";
        }
    }
    llSetText(sNewText, g_vColor, 1.0);
    if (llGetLinkNumber() > 1)
    {//don't scale the root prim
        llSetScale(g_vShowScale);
    }
    g_iOn = TRUE;
}

HideText()
{
    Debug("hide text");
    llSetText("", <1,1,1>, 1.0);
    if (llGetLinkNumber() > 1)
    {
        llSetScale(g_vHideScale);
    }
    g_iOn = FALSE;
    //    if (g_sText!="")
    //    {
    //        llMessageLinked(LINK_ROOT, HTTPDB_SAVE, g_sDBToken + "=off:" + (string)g_iLastRank + ":" + llEscapeURL(g_sText), NULL_KEY);
    //    }
    //    else
    //    {
    //        llMessageLinked(LINK_ROOT, HTTPDB_DELETE, g_sDBToken, NULL_KEY);
    //    }

}

CleanPrim()
{
    integer i;
    for (i = 0; i  < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {
        if (llGetInventoryName(INVENTORY_SCRIPT, i) != llGetScriptName())
        {
            i -= SafeRemoveInventory(llGetInventoryName(INVENTORY_SCRIPT, i));
        }
    }
    SafeRemoveInventory(llGetScriptName());
}
CleanUp()
{
    integer i;
    list lTmp;
    string sNam1;
    string sNam2;
    string sScr1;
    string sScr2;
    float fVer1;
    float fVer2;
    for (i = 0 ; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {
        sNam1 = llGetInventoryName(INVENTORY_SCRIPT, i);
        sNam2 = llGetInventoryName(INVENTORY_SCRIPT, i + 1);
        lTmp = llParseString2List(sNam1, [" - "], []);
        sScr1 =  llList2String(lTmp, 1);
        fVer1 = (float)llList2String(lTmp, 2);
        lTmp = llParseString2List(sNam2, [" - "], []);
        sScr2 = llList2String(lTmp, 1);
        fVer2 = (float)llList2String(lTmp, 2);
        if(sScr1 == sScr2)
        {
            // remove the older version
            if (fVer1 <= fVer2)
            {
                i -= SafeRemoveInventory(sNam1);
            }
            else
            {
                i -= SafeRemoveInventory(sNam2);
            }
        }
    }
    for (i = 0; i < llGetInventoryNumber(INVENTORY_SCRIPT); i++)
    {
        sNam1 = llGetInventoryName(INVENTORY_SCRIPT, i);
        if (sNam1 != llGetScriptName())
        {
            if(llGetInventoryType(sNam1) == INVENTORY_SCRIPT)
            {
                llResetOtherScript(sNam1);
            }
        }
    }
    llResetScript();
}

default
{
    state_entry()
    {
        g_vColor = llGetColor(ALL_SIDES);
        g_kWearer = llGetOwner();
        llSetText("", <1,1,1>, 0.0);
        if (llGetLinkNumber() > 1)
        {
            llSetScale(g_vHideScale);
        }
        llMessageLinked(LINK_ROOT, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
    }
    on_rez(integer start)
    {
        if(g_iOn && g_sText != "")
        {
            ShowText(g_sText);
        }
        else
        {
            llSetText("", <1,1,1>, 0.0);
            if (llGetLinkNumber() > 1)
            {
                llSetScale(g_vHideScale);
            }
        }
    }
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        list lParams = llParseString2List(sStr, [" "], []);
        string sCommand = llList2String(lParams, 0);
        string sValue = llToLower(llList2String(lParams, 1));
        if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            if (sCommand == "text")
            {
                //llSay(0, "got text command");
                lParams = llDeleteSubList(lParams, 0, 0);//pop off the "text" command
                string sNewText = llDumpList2String(lParams, " ");
                if (g_iOn)
                {
                    //only change text if commander has smae or greater auth
                    if (iNum <= g_iLastRank)
                    {
                        if (sNewText == "")
                        {
                            g_sText = "";
                            HideText();
                        }
                        else
                        {
                            ShowText(sNewText);
                            g_iLastRank = iNum;
                            //llMessageLinked(LINK_ROOT, HTTPDB_SAVE, g_sDBToken + "=on:" + (string)iNum + ":" + llEscapeURL(sNewText), NULL_KEY);
                        }
                    }
                    else
                    {
                        Notify(kID,"You currently have not the right to change the float text, someone with a higher rank set it!", FALSE);
                    }
                }
                else
                {
                    //set text
                    if (sNewText == "")
                    {
                        g_sText = "";
                        HideText();
                    }
                    else
                    {
                        ShowText(sNewText);
                        g_iLastRank = iNum;
                        //llMessageLinked(LINK_ROOT, HTTPDB_SAVE, g_sDBToken + "=on:" + (string)iNum + ":" + llEscapeURL(sNewText), NULL_KEY);
                    }
                }
            }
            else if (sCommand == "textoff")
            {
                if (g_iOn)
                {
                    //only turn off if commander auth is >= g_iLastRank
                    if (iNum <= g_iLastRank)
                    {
                        g_iLastRank = COMMAND_WEARER;
                        HideText();
                    }
                }
                else
                {
                    g_iLastRank = COMMAND_WEARER;
                    HideText();
                }
            }
            else if (sCommand == "texton")
            {
                if( g_sText != "")
                {
                    g_iLastRank = iNum;
                    ShowText(g_sText);
                }
            }
            else if (sStr == "reset" && (iNum == COMMAND_OWNER || iNum == COMMAND_WEARER))
            {
                g_sText = "";
                HideText();
                llResetScript();
            }
        }
        else if (iNum == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_ROOT, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        }
        else if (iNum == SUBMENU && sStr == g_sSubMenu)
        {
            //popup help on how to set label
            llMessageLinked(LINK_ROOT, POPUP_HELP, "To set floating text , say _PREFIX_text followed by the text you wish to set.  \nExample: _PREFIX_text I have text above my head!", kID);
        }
        else if (iNum == HTTPDB_RESPONSE)
        {
            lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            Debug("sToken: " + sToken);
            if (sToken == g_sDBToken)
            {
                // no more storing or restoring of text in the db
                //                sToken = llGetSubString(sStr, llStringLength(sToken) + 1, -1);
                //                lParams = [] + llParseString2List(sToken, [":"], []);
                //
                //                string iStatus = llList2String(lParams, 0);
                //                Debug("Status: " + iStatus);
                //                if(iStatus == "on")
                //                {
                //                    iNum = (integer)llList2String(lParams, 1);
                //                    lParams = llDeleteSubList(lParams, 0, 1);
                //                    g_sText = llUnescapeURL( llDumpList2String(lParams, ":"));
                //                    ShowText(g_sText);
                //                    g_iLastRank = iNum;
                //                }
                //                else
                //                {
                //                    g_iLastRank = COMMAND_WEARER;
                //                    HideText();
                //                }

                // but kil any entries in the db to clean the house

                llMessageLinked(LINK_ROOT, HTTPDB_DELETE, g_sDBToken , NULL_KEY);
            }
        }
        else if (iNum == UPDATE)
        {
            if(sStr == "prepare")
            {
                llSetRemoteScriptAccessPin(g_iUpdatePin);
                string scriptName = llList2String(llParseString2List(llGetScriptName(), [" - "], []), 1);
                llMessageLinked(LINK_ROOT, UPDATE, scriptName + "|" + (string)g_iUpdatePin, llGetKey());
            }
            else if(sStr == "reset")
            {
                llSetRemoteScriptAccessPin(0);
                CleanUp();
            }
            else if(sStr == "cleanup prim")
            {
                CleanPrim();
            }
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }

        if (iChange & CHANGED_COLOR)
        {
            g_vColor = llGetColor(ALL_SIDES);
            if (g_iOn)
            {
                ShowText(g_sText);
            }
        }
    }
}
