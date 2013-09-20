// CollarDB - Attachments
// Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.
//---------------------
// Bridge Interface For Attachments
//---------------------
//
// Creates an interface between the collar and attachments that allow the attatchment scripts to act as if they 
// are within the collar itself.  Auth calls, dialog calls, adding to the menu, etc.
//
integer debug = TRUE;

string g_sSubMenu = "Attachments";
string g_sParentMenu = "Main";
list g_lLocalButtons = [];
list g_lButtons = [];
string UPMENU = "^";
integer g_iRemenu;
key g_kMenuID;

list messages = [];

integer g_iHUDChan = -1334245234; // instead this should be the new channel to be used by any object not from the wearer itself. For attachments of the wearer use the interface channel. This channel wil be personlaized below

list nopass = [0xCDB000,0xCDB042,0xCDB499,0xCDB506,0xCDB507,0xCDB500,0xCDB501,0xCDB502,0xCDB503,0xCDB504,0xCDB200,0xCDB201,0xCDB203,0xCDB250,0xCDB251,0xCDB253,0xCDB600,0xCDB601,0xCDB610,0xCDB300,0xCDB301,0xCDB302,0xCDB303,-0xCDB900,-0xCDB901];
//MESSAGE MAP
integer COMMAND_NOAUTH          = 0xCDB000;
integer COMMAND_COLLAR          = 0xCDB499;     //added for collar or cuff commands to put ao to pause or standOff
integer COMMAND_OWNER           = 0xCDB500;
integer COMMAND_SECOWNER        = 0xCDB501;
integer COMMAND_GROUP           = 0xCDB502;
integer COMMAND_WEARER          = 0xCDB503;
integer COMMAND_EVERYONE        = 0xCDB504;
integer COMMAND_OBJECT          = 0xCDB506;
integer COMMAND_RLV_RELAY       = 0xCDB507;
integer COMMAND_SAFEWORD        = 0xCDB510;

integer POPUP_HELP              = -0xCDB001;

integer HTTPDB_REQUEST          = 0xCDB201;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 0xCDB202;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 0xCDB203;     // delete token from DB
integer HTTPDB_EMPTY            = 0xCDB204;     // sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST        = 0xCDB300;
integer MENUNAME_RESPONSE       = 0xCDB301;
integer SUBMENU                 = 0xCDB302;
integer MENUNAME_REMOVE         = 0xCDB303;

integer ATTACHMENT_REQUEST      = -0xCDB600;
integer ATTACHMENT_RESPONSE     = -0xCDB601;
integer ATTACHMENT_FORWARD      = -0xCDB609;
integer ATTACHMENT_PASSTHROUGH  = -0xCDB610;
integer COLLAR_PASSTHROUGH      = -0xCDB611;

// messages to the dialog helper
integer DIALOG                  = -0xCDB900;
integer DIALOG_RESPONSE         = -0xCDB901;
integer DIALOG_TIMEOUT          = -0xCDB902;

integer RLV_CMD                 = 0xCDB600;
integer RLV_REFRESH             = 0xCDB601;     // RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR               = 0xCDB602;     // RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION             = 0xCDB603;     // RLV Plugins can recieve the used rl viewer version upon receiving this message.
integer RLV_OFF                 = 0xCDB610;     // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON                  = 0xCDB611;     // send to inform plugins that RLV is enabled now, no message or key needed
integer RLVR_CMD                = 0xCDB612;

//added for attachment auth
integer g_iInterfaceChannel = -12587429;
integer g_iListenHandleAtt;

key g_kWearer;

//------BRIDGE COMMAND---------
list g_lAttDialogKeyID;
list g_lAttMenu;
//-----------------------------

Debug(string sStr)
{
    if (debug)
        llOwnerSay(llGetScriptName() + " ¿ " + sStr);
}

integer GetOwnerChannel(key kOwner, integer iOffset)
{
    integer iChan = (integer)("0x"+llGetSubString((string)kOwner,2,7)) + iOffset;
    if (iChan>0)
    {
        iChan=iChan*(-1);
    }
    if (iChan > -10000)
    {
        iChan -= 30000;
    }
    return iChan;
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

string StringReplace(string sSrc, string sFrom, string sTo)
{//replaces all occurrences of 'sFrom' with 'sTo' in 'sSrc'.
    return llDumpList2String(llParseStringKeepNulls((sSrc = "") + sSrc, [sFrom], []), sTo);
}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

Notify(key kID, string sMsg, integer iAlsoNotifyWearer) {
    if (kID == g_kWearer) {
        llOwnerSay(sMsg);
    } else {
            llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) {
            llOwnerSay(sMsg);
        }
    }
}

DoMenu(key kAv)
{
    list lMyButtons;
    string sPrompt;
 
    sPrompt = "Select the Attachment you would like to view the Menu for.";
  
    lMyButtons += llListSort(g_lLocalButtons + g_lButtons, 1, TRUE);
 
    g_kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0);
}

BridgePassthrough(string sStr, key kID)
{
    messages += [sStr];
    list lParts = llParseStringKeepNulls(sStr, ["¿"], []);
    string rNum = llList2String(lParts,0);
    string sCmd = llList2String(lParts,1);
    list lParams = llParseStringKeepNulls(sCmd, ["¥"], []);
    integer iParamNum = llList2Integer(lParams,0);
    string sParamStr =  llList2String(lParams,1);
    key kParamID = llList2Key(lParams,2);
    llMessageLinked(LINK_SET,iParamNum,sParamStr,kParamID);
    if (iParamNum == DIALOG)
    {
        integer idx = llListFindList(g_lAttDialogKeyID,[kID]);
        if (idx != -1)
        {                    
            g_lAttDialogKeyID = llDeleteSubList(g_lAttDialogKeyID,idx,idx+1);
        }        
        
        g_lAttDialogKeyID += [kID,kParamID];        
    }    
    else if (iParamNum == MENUNAME_RESPONSE)
    {
        list lMenu = llParseStringKeepNulls(sParamStr, ["|"], []);
        string sParentmenu = llList2String(lMenu,0);
        string sSubmenu = llList2String(lMenu,1);
        g_lAttMenu += [kID,sParentmenu,sSubmenu];
    }

}

integer fromAttachment(integer iNum, string sStr, key id)
{
    integer rtnCode = TRUE;
    string cmd = (string)ATTACHMENT_PASSTHROUGH + "¿" + (string)iNum + "¥" + sStr + "¥" + (string)id;
    integer idx;
    idx = llListFindList(messages,[cmd]);
    if (idx != -1)
    {
        rtnCode = TRUE;
        messages = ListItemDelete(messages, cmd);
    }
    else
    { 
        rtnCode = FALSE;
    }
    
    return rtnCode;
    
}

list ListItemDelete(list mylist,string element_old) {
    integer placeinlist = llListFindList(mylist, [element_old]);
    if (placeinlist != -1)
        return llDeleteSubList(mylist, placeinlist, placeinlist);
    return mylist;
}


BridgeResponse(integer iSender, integer iNum, string sStr, key kID)
{
    if (llListFindList(nopass,[iNum]) == -1)
    {
        llWhisper(g_iInterfaceChannel, (string)COLLAR_PASSTHROUGH + "¿" + (string)iNum + "¥" +  sStr  + "¥" +  (string)kID);
    }
    else if (iNum == DIALOG_RESPONSE)
    {
            integer idx = llListFindList(g_lAttDialogKeyID,[kID]);        
            if (idx != -1)
            {   
                //sStr = StringReplace(sStr,"|","~");
                //string kObjectID = llList2String(g_lAttMenu,idx-1); 
                string kObjectID = llList2String(g_lAttDialogKeyID,idx-1);                 
               // llWhisper(g_iInterfaceChannel, "Command|" + (string)DIALOG_RESPONSE + "|" + sStr + "|" + (string)kID);
               llRegionSayTo((key)kObjectID, g_iInterfaceChannel, (string)COLLAR_PASSTHROUGH + "¿" + (string)iNum + "¥" +  sStr  + "¥" +  (string)kID);
                g_lAttDialogKeyID = llDeleteSubList(g_lAttDialogKeyID,idx-1,idx);
            }
            else
            {
                list lParams = llParseStringKeepNulls(sStr,["|"],[]);
                key kAV = llList2Key(lParams,0);
                string sItem = llList2String(lParams,1);
                integer idx = llListFindList(g_lAttMenu,[sItem]);
                if(idx != -1)
                {   
                    if((idx+1)%3 == 0)
                    {
                        string kObjectID = llList2String(g_lAttMenu,idx-2); 
                        //llRegionSayTo((key)kObjectID,g_iInterfaceChannel, "Command|" + (string)SUBMENU + "|" + (string)kAV + "~" + sItem + "~0|" + (string)kAV);
                        llRegionSayTo((key)kObjectID,g_iInterfaceChannel, (string)COLLAR_PASSTHROUGH + "¿" + (string)iNum + "¥" +  sStr  + "¥" +  (string)kID);                  
                    }
                }
            } 
            return;
    }
    else if (iNum == MENUNAME_REQUEST)
    {
        integer idx;
        integer len;        
        list buffer = g_lAttMenu;
        if (sStr == g_sSubMenu)
        {
            llWhisper(g_iInterfaceChannel, (string)COLLAR_PASSTHROUGH + "¿" + (string)iNum + "¥" +  sStr  + "¥" +  (string)kID);
        }
        else if (llGetListLength(g_lAttMenu) > 0)
        {
            integer count;
            @loop;
            count = count + 1;      
            idx = llListFindList(buffer,[sStr]);
            if(idx != -1)
            {
                len = llGetListLength(buffer);
                string sParentmenu = llList2String(buffer,idx);
                string sSubmenu = llList2String(buffer,idx+1);                
                llMessageLinked(LINK_SET, MENUNAME_RESPONSE, sStr + "|" + llList2String(buffer,idx+1), NULL_KEY);                
                buffer = llList2List(buffer,idx+2,len-1);
                jump loop;
            }    
        }
    }
   else if (iNum == MENUNAME_RESPONSE)
    {
        list lParts = llParseStringKeepNulls(sStr, ["|"], []);
        if (llList2String(lParts, 0) == g_sSubMenu)
        {//someone wants to stick something in our menu
            string button = llList2String(lParts, 1);
            if (llListFindList(g_lButtons, [button]) == -1)
            {
                g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
            }
        }
    }
    else if (iNum == MENUNAME_REMOVE)
    {
        //sStr should be in form of parentmenu|childmenu
        list lParams = llParseStringKeepNulls(sStr, ["|"], []);
        string child = llList2String(lParams, 1);
        if (llList2String(lParams, 0)==g_sSubMenu)
        {
            integer iIndex = llListFindList(g_lButtons, [child]);
            //only remove if it's there
            if (iIndex != -1)
            {
                g_lButtons = llDeleteSubList(g_lButtons, iIndex, iIndex);
            }
        }
    }    
    else if (iNum == SUBMENU)
    {
        integer idx = llListFindList(g_lAttMenu,[sStr]);
        if(idx != -1)
        {   
            if((idx+1)%3 == 0)
            {
                string kObjectID = llList2String(g_lAttMenu,idx-2);        
                llRegionSayTo((key)kObjectID,g_iInterfaceChannel, "Command|" + (string)SUBMENU + "|" + (string)kID + "¥" + sStr + "¥0|" + (string)kID);
            }
        }
    }    
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();

        g_iHUDChan = GetOwnerChannel(g_kWearer, 1111); // persoalized channel for this sub

        g_iInterfaceChannel = (integer)("0x" + llGetSubString(g_kWearer,30,-1));
        if (g_iInterfaceChannel > 0) g_iInterfaceChannel = -g_iInterfaceChannel;
        
        messages = [];
        llSetTimerEvent(5.0);
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == SUBMENU && sStr == g_sSubMenu)
        {
            //someone asked for our menu
            //give this plugin's menu to id
            g_iRemenu = TRUE;
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, llToLower(g_sSubMenu),kID);
            return;
        }        
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
            return;
        }
        else if (iNum == MENUNAME_RESPONSE)
        {
            list lParts = llParseStringKeepNulls(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu)
            {//someone wants to stick something in our menu
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1)
                {
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iNum == MENUNAME_REMOVE)
        {
            //sStr should be in form of parentmenu|childmenu
            list lParams = llParseStringKeepNulls(sStr, ["|"], []);
            string child = llList2String(lParams, 1);
            if (llList2String(lParams, 0)==g_sSubMenu)
            {
                integer iIndex = llListFindList(g_lButtons, [child]);
                //only remove if it's there
                if (iIndex != -1)
                {
                    g_lButtons = llDeleteSubList(g_lButtons, iIndex, iIndex);
                }
            }
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == g_kMenuID)
            {
                list lMenuParams = llParseStringKeepNulls(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iPage = (integer)llList2String(lMenuParams, 2);
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
                }
                else if (llListFindList(g_lButtons,[sMessage]) != -1)
                {
                    llMessageLinked(LINK_SET, SUBMENU, sMessage, kAv);
                }
            return;                
            }
        }
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            list lParams = llParseStringKeepNulls(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
            if (sStr == "refreshmenu")
            {
                g_lButtons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, NULL_KEY);
            }
            else if (sStr == llToLower(g_sSubMenu))
            {
                DoMenu(kID);
                g_iRemenu=FALSE;
            }
            return;
        }
        else if (iNum == ATTACHMENT_FORWARD)
        {
            list lParts = llParseStringKeepNulls(sStr, ["|"], []);
            if ((integer)llList2String(lParts,0) == ATTACHMENT_PASSTHROUGH)
            {
                BridgePassthrough(sStr,kID);
            }
            return;
        }
        if (!fromAttachment(iNum,sStr,kID))
        {        
            BridgeResponse(iSender,iNum,sStr,kID);
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER)
        {
            llResetScript();
        }
    }
    
    on_rez(integer iParam)
    {
        llResetScript();
    }
    
    timer()
    {
        integer max = llGetListLength(g_lAttMenu);
        if(max > 0)
        {
            integer i;
            list temp = [];
            for(i=0;i<max;i=i+3)
            {
               if (llGetObjectDetails(llList2Key(g_lAttMenu,i),[OBJECT_ATTACHED_POINT]) != [] )
               {
                   temp += llList2List(g_lAttMenu, i, i+2);
               }
               else
               {
                    llMessageLinked(LINK_SET, MENUNAME_REMOVE, llList2String(g_lAttMenu,i+1) + "|" +  llList2String(g_lAttMenu,i+2), NULL_KEY);
                }
            }
            g_lAttMenu = temp;
        }
    }    
}