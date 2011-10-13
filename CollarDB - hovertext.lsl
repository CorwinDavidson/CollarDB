//CollarDB- hovertext - 3.584
string g_sParentMenu = "AddOns";
string g_sSubMenu = "FloatText";

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

integer g_link=0;
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

// Find the floattext prim
GetFloatLink()
{
    integer max = llGetNumberOfPrims();
    integer i = 0;
    list desc = [];
    for (;i<=max;i++)
    {
        desc = llGetObjectDetails(llGetLinkKey(i),[OBJECT_DESC]);
        if (llSubStringIndex((string)desc,"FloatText") != -1)
        {
            g_link = i;
        }
    }   
}

// 
TextDisplay(string sText, integer iVisible)
{
    vector vColor;
    vector vScale;        
    if(iVisible)
    {
        vColor = g_vColor;
        vScale = g_vShowScale;
        g_iOn = TRUE;
    }
    else
    {
        vColor = <1,1,1>;
        vScale = g_vHideScale;
        g_iOn = FALSE;
    }
    llSetLinkPrimitiveParamsFast(g_link,[PRIM_TEXT, sText, vColor, 1.0]);
    if (g_link > 1)
    {//don't scale the root prim
        llSetLinkPrimitiveParamsFast(g_link,[PRIM_SIZE,vScale]);
    }    
    

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
    TextDisplay(sNewText,TRUE);
}

default
{
    state_entry()
    {
        GetFloatLink();
        g_vColor = llGetColor(ALL_SIDES);
        g_kWearer = llGetOwner();
        TextDisplay("",FALSE);
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
            TextDisplay("",FALSE); 
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
                            TextDisplay("",FALSE);
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
                        TextDisplay("",FALSE);
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
                        TextDisplay("",FALSE);
                    }
                }
                else
                {
                    g_iLastRank = COMMAND_WEARER;
                    TextDisplay("",FALSE);
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
                TextDisplay("",FALSE);
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
                // but kil any entries in the db to clean the house

                llMessageLinked(LINK_ROOT, HTTPDB_DELETE, g_sDBToken , NULL_KEY);
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
