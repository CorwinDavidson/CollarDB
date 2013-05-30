//CollarDB - appearance
//handle appearance menu
//handle saving position on detach, and restoring it on httpdb_response

string g_sSubMenu = "Appearance";
string g_sParentMenu = "Main";

list g_lMenuIDs;//3-strided list of avkey, dialogid, menuname
integer g_iMenuStride = 3;

string POSMENU = "Position";
string ROTMENU = "Rotation";
string SIZEMENU = "Size";
string TEXTUREMENU = "Textures";
string COLORMENU = "Colors";
string HIDEMENU = "Hide/Show";
string ELEMENTMENU;

list g_lLocalButtons = [POSMENU, ROTMENU, SIZEMENU, TEXTUREMENU , COLORMENU, HIDEMENU]; //[POSMENU, ROTMENU];
list g_lRemoteButtons;
list g_lButtons;

float g_fSmallNudge=0.0005;
float g_fMediumNudge=0.005;
float g_fLargeNudge=0.05;

float g_fNudge=0.005; // g_fMediumNudge;
float g_fRotNudge;

// SizeScale
list SIZEMENU_BUTTONS = [ "-1%", "-2%", "-5%", "-10%", "+1%", "+2%", "+5%", "+10%", "100%" ]; // buttons for menu
list g_lSizeFactors = [-1, -2, -5, -10, 1, 2, 5, 10, -1000]; // actual size factors
integer g_iScaleFactor = 100; // the size on rez is always regarded as 100% to preven problem when scaling an item +10% and than - 10 %, which would actuall lead to 99% of the original size

string TICKED = "(*)";
string UNTICKED = "( )";

string APPLOCK = "Lock Appearance";
integer g_iAppLock = FALSE;
string g_sAppLockToken = "AppLock";

// Integrated Alpha / Color / Texture

list g_lHideElements = [];
list g_lAlphaSettings = [];
string g_sAlphaDBToken = "elementalpha";

list g_lColorElements = [];
list g_lColorSettings = [];
string g_sColorDBToken = "colorsettings";
list g_lCategories = ["Blues", "Browns", "Grays", "Greens", "Purples", "Reds", "Yellows"];

list g_lTextureElements = [];
list g_lTextureSettings = [];
string g_sTextureDBToken = "textures";


string g_sCurrentElement = "";
string g_sCurrentCategory = "";

string HIDE = "Hide ";
string SHOW = "Show ";
string SHOWN = "Shown";
string HIDDEN = "Hidden";
string ALL = "All";
string g_sType = "";
key g_kDialogID;


key g_kUser;
key g_kHTTPID;

list g_lColors;
integer g_iStridelength = 2;
integer g_iPage = 0;
integer g_iMenuPage;
integer g_iPagesize = 10;
integer g_iLength;
list g_lNewButtons;

string g_sHTTPDB_Url = "http://data.collardb.com/"; //defaul OC url, can be changed in defaultsettings notecard and wil be send by settings script if changed

// Textures in Notecard for Non Full Perm textures
key g_ktexcardID;
string g_noteName = "";
integer g_noteLine;
list g_textures = [];
list g_read = [];

// Integrated Alpha / Color / Texture

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

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
                            //str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer MENUNAME_REMOVE = 3003;

integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.

integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av

integer APPEARANCE_ALPHA = -8000;
integer APPEARANCE_COLOR = -8001;
integer APPEARANCE_TEXTURE = -8002;
integer APPEARANCE_POSITION = -8003;
integer APPEARANCE_ROTATION = -8004;
integer APPEARANCE_SIZE = -8005;
integer APPEARANCE_SIZE_FACTOR = -8105;

integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;

//string UPMENU = "?";//when your menu hears this, give the parent menu
string UPMENU = "^";

key g_kWearer;
integer g_iRemenu;

// Integrated Alpha / Color / Texture

BuildElementList()
{
    g_lColorElements = [];
    g_lTextureElements = [];
    g_lHideElements = [];
    
    integer n;
    integer iLinkCount = llGetNumberOfPrims();

    //root prim is 1, so start at 2
    for (n = 2; n <= iLinkCount; n++)
    {
        list lElement = llParseString2List(ElementType(n),["|"],[]);
        string sElement = llList2String(lElement,0);
        if (!(~(integer)llListFindList(g_lColorElements, [sElement])) && !(~(integer)llListFindList(lElement, ["nocolor"])))
            g_lColorElements += [sElement];
        if (!(~(integer)llListFindList(g_lTextureElements, [sElement])) && !(~(integer)llListFindList(lElement, ["notexture"])))
            g_lTextureElements += [sElement];
        if (!(~(integer)llListFindList(g_lHideElements, [sElement])) && !(~(integer)llListFindList(lElement, ["nohide"])))
            g_lHideElements += [sElement];
    }
    g_lColorElements = llListSort(g_lColorElements, 1, TRUE);
    g_lTextureElements = llListSort(g_lTextureElements, 1, TRUE);    
    g_lHideElements = llListSort(g_lHideElements, 1, TRUE);
}

ElementMenu(key kAv,list lElements)
{
    g_sCurrentElement = "";
    string sPrompt = "Pick which part of the collar you would like to " + g_sType;
    g_lButtons = [];

    if (g_sType == "hide or show")
    {
        integer n;
        integer iStop = llGetListLength(lElements);
        for (n = 0; n < iStop; n++)
        {
            string sElement = llList2String(lElements, n);
            integer iIndex = llListFindList(g_lAlphaSettings, [sElement]);
            if (iIndex == -1)
            {
                g_lButtons += HIDE + sElement;
            }
            else
            {
                float fAlpha = (float)llList2String(g_lAlphaSettings, iIndex + 1);
                if (fAlpha)
                {
                    g_lButtons += HIDE + sElement;
                }
                else
                {
                    g_lButtons += SHOW + sElement;
                }
            }
        }
        g_lButtons += [SHOW + ALL, HIDE + ALL];    
    }
    else
    {
        g_lButtons = llListSort(lElements, 1, TRUE);
    }
    key kMenuID = Dialog(kAv, sPrompt, g_lButtons, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, ELEMENTMENU);    
}

CategoryMenu(key kAv)
{
    //give kAv a dialog with a list of color cards
    string sPrompt = "Pick a Color.";
    key kMenuID = Dialog(kAv, sPrompt, g_lCategories, [UPMENU],0);
    MenuIDAdd(kAv, kMenuID, COLORMENU);
}

ColorMenu(key kAv)
{
    string sPrompt = "Pick a Color.";
    list g_lButtons = llList2ListStrided(g_lColors,0,-1,2);
    key kMenuID = Dialog(kAv, sPrompt, g_lButtons, [UPMENU],0);
    MenuIDAdd(kAv, kMenuID, COLORMENU);
}

TextureMenu(key kAv, integer iPage)
{
    //create a list
    list lButtons;
    string sPrompt = "Choose the texture to apply.";

    integer iNumTex = llGetInventoryNumber(INVENTORY_TEXTURE);
    integer n;
    for (n=0;n<iNumTex;n++)
    {
        string sName = llGetInventoryName(INVENTORY_TEXTURE,n);
        lButtons += [sName];
    }
    integer iNoteTex = llGetListLength(g_textures);
    for (n=0;n<iNoteTex;n=n+2)
    {
        string sName = llList2String(g_textures,n);
        lButtons += [sName];
    }
    key kMenuID = Dialog(kAv, sPrompt, lButtons, [UPMENU], iPage);
    MenuIDAdd(kAv, kMenuID, TEXTUREMENU);
}

string ElementType(integer linkiNumber)
{
    // return a strided list representing primname|nocolor|notexture|nohide
    string sDesc = (string)llGetObjectDetails(llGetLinkKey(linkiNumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to
    //not appear in the color or texture menus
    list lParams = llParseString2List(sDesc, ["~"], []);
    string type = llList2String(lParams, 0) + "|";
    if (sDesc == "" || sDesc == " " || sDesc == "(No Description)")
    {
        type += "nocolor|notexture|nohide";
    }
    else if ((~(integer)llListFindList(lParams, ["nocolor"])) || (~(integer)llListFindList(lParams, ["notexture"])) || (~(integer)llListFindList(lParams, ["nohide"])))
    {
        if (~(integer)llListFindList(lParams, ["nocolor"]))
        {
            type += "nocolor|";
        }
        else
        {
            type += "|";
        }
        if (~(integer)llListFindList(lParams, ["notexture"]))
        {
            type += "notexture|";
        }
        else
        {
            type += "|";
        }        
        if (~(integer)llListFindList(lParams, ["nohide"]))
        {
            type += "nohide|";
        }
        else
        {
            type += "|";
        }                
    }        
    
    return type;
}

MenuIDAdd(key kAv, key kMenuID, string sMenu)
{
    integer iMenuIndex = llListFindList(g_lMenuIDs, [kAv]);
    list lAddMe = [kAv, kMenuID, sMenu];
    if (iMenuIndex == -1)
    {
        g_lMenuIDs += lAddMe;
    }
    else
    {
        g_lMenuIDs = llListReplaceList(g_lMenuIDs, lAddMe, iMenuIndex, iMenuIndex + g_iMenuStride - 1);
    }
}

integer StartsWith(string sHayStack, string sNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(sHayStack, llStringLength(sNeedle), -1) == sNeedle;
}

loadNoteCards(string param)
{
    if (g_noteName != "" &&  param == "EOF")
    {
        g_read += [g_noteName];
        g_textures = llListSort(g_textures,2,TRUE);
    }
        
    if (g_noteName == "" &&  param == "")
    {
        g_read = [];
        g_textures = [];
    }
        
    if ((g_noteName != "" &&  param == "EOF") || (g_noteName == "" &&  param == ""))
    {
        integer iNumNote = llGetInventoryNumber(INVENTORY_NOTECARD);
        integer n;
        for (n=0;n<iNumNote;n++)
        {
            string sName = llGetInventoryName(INVENTORY_NOTECARD,n);
            if (StartsWith(llToLower(sName),"~cdbt_"))
            {
                if (llListFindList(g_read,[sName]) == -1)
                {
                    n=iNumNote;                
                    g_noteName = sName;
                    g_noteLine = 0;
                    g_ktexcardID = llGetNotecardLine(g_noteName, g_noteLine);
                }
            }
            
        }    
    }
}

// Integrated Alpha / Color / Texture

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
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

Debug(string sStr)
{
    //llOwnerSay(llGetScriptName() + ": " + sStr);
}

RotMenu(key kAv)
{
    string sPrompt = "Adjust the collar rotation.";
    list lMyButtons = ["tilt up", "right", "tilt left", "tilt down", "left", "tilt right"];// ria change
    key kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, ROTMENU);
}

PosMenu(key kAv)
{
    string sPrompt = "Adjust the collar position:\nChoose the size of the nudge (S/M/L), and move the collar in one of the three directions (X/Y/Z).\nCurrent nudge size is: ";
    list lMyButtons = ["left", "up", "forward", "right", "down", "backward"];// ria iChange
    if (g_fNudge!=g_fSmallNudge) lMyButtons+=["Nudge: S"];
    else sPrompt += "Small.";
    if (g_fNudge!=g_fMediumNudge) lMyButtons+=["Nudge: M"];
    else sPrompt += "Medium.";
    if (g_fNudge!=g_fLargeNudge) lMyButtons+=["Nudge: L"];
    else sPrompt += "Large.";
    
    key kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, POSMENU);
}

SizeMenu(key kAv)
{
    string sPrompt = "Adjust the collar scale. It is based on the size the collar has on rezzing. You can change back to this size by using '100%'.\nCurrent size: " + (string)g_iScaleFactor + "%\n\nATTENTION! May break the design of collars. Make a copy of the collar before using!";
    key kMenuID = Dialog(kAv, sPrompt, SIZEMENU_BUTTONS, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, SIZEMENU);    
}

DoMenu(key kAv)
{
    list lMyButtons;
    string sPrompt;
    if (g_iAppLock)
    {
        sPrompt = "The appearance of the collar has be locked. To modified it a owner has to unlock it.";
        lMyButtons = [TICKED + APPLOCK];
    }
    else
    {
        sPrompt = "Which aspect of the appearance would you like to modify? Owners can lock the appearance of the collar, so it cannot be changed at all.\n";
    
        lMyButtons = [UNTICKED + APPLOCK];
        lMyButtons += llListSort(g_lLocalButtons + g_lRemoteButtons, 1, TRUE);
    }
    key kMenuID = Dialog(kAv, sPrompt, lMyButtons, [UPMENU], 0);
    MenuIDAdd(kAv, kMenuID, g_sSubMenu);   
}

string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}

default
{
    state_entry()
    {
        g_kWearer = llGetOwner();       
        g_fRotNudge = PI / 32.0;//have to do this here since we can't divide in a global var declaration   
        
        BuildElementList();
        
//        Store_StartScaleLoop();
        string sPrefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (sPrefix != "")
        {
            g_sAlphaDBToken = sPrefix + g_sAlphaDBToken;
            g_sColorDBToken = sPrefix + g_sColorDBToken;
            g_sTextureDBToken = sPrefix + g_sTextureDBToken;                        
        }
        
        loadNoteCards("");                
        
        Debug((string)(llGetFreeMemory() / 1024) + " KB Free");
    }
    
    on_rez(integer iParam)
    {
        llResetScript();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == APPEARANCE_SIZE_FACTOR)
        {
            g_iScaleFactor = (integer)sStr;
            return;
        }
        if (iNum == SUBMENU && sStr == g_sSubMenu)
        {
            //someone asked for our menu
            //give this plugin's menu to id
            g_iRemenu = TRUE;
            llMessageLinked(LINK_SET, COMMAND_NOAUTH, "appearance",kID);
        }
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {         
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, NULL_KEY);
        }
        else if (iNum == MENUNAME_RESPONSE)
        {
            list lParts = llParseString2List(sStr, ["|"], []);
            if (llList2String(lParts, 0) == g_sSubMenu)
            {//someone wants to stick something in our menu
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lRemoteButtons, [button]) == -1)
                {
                    g_lRemoteButtons = llListSort(g_lRemoteButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llToLower(llList2String(lParams, 0));
            string sValue = llToLower(llList2String(lParams, 1));
            if (sStr == "refreshmenu")
            {
                g_lButtons = [];
                g_lRemoteButtons = [];
                llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, NULL_KEY);
            }
            else if (sStr == "appearance")
            {
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
                {
                    Notify(kID,"You are not allowed to change the collar appearance.", FALSE);
                    if (g_iRemenu) llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kID);
                }
                else DoMenu(kID);
                g_iRemenu=FALSE;
            }
            else if (sStr == "rotation")
            {
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
                {
                    Notify(kID,"You are not allowed to change the collar rotation.", FALSE);
                }
                else if (g_iAppLock)
                {
                    Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
                    DoMenu(kID);
                }
                else RotMenu(kID);
             }
            else if (sStr == "position")
            {
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
                {
                    Notify(kID,"You are not allowed to change the collar position.", FALSE);
                }
                else if (g_iAppLock)
                {
                    Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
                    DoMenu(kID);
                }
                else PosMenu(kID);
            }
            else if (sStr == "size")
            {
                if (kID!=g_kWearer && iNum!=COMMAND_OWNER)
                {
                    Notify(kID,"You are not allowed to change the collar size.", FALSE);
                }
                else if (g_iAppLock)
                {
                    Notify(kID,"The appearance of the collar is locked. You cannot access this menu now!", FALSE);
                    DoMenu(kID);
                }
                else SizeMenu(kID);
            }
            else if (llGetSubString(sStr,0,6) == "applock")
            {
                if (iNum == COMMAND_OWNER)
                {
                    if(llGetSubString(sStr, -1, -1) == "0")
                    {
                        g_iAppLock = FALSE;
                        llMessageLinked(LINK_SET, HTTPDB_DELETE, g_sAppLockToken, NULL_KEY);
                        llMessageLinked(LINK_SET, COMMAND_OWNER, "lockappearance 0", kID);
                    }
                    else
                    {
                        g_iAppLock = TRUE;
                        llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sAppLockToken + "=1", NULL_KEY);
                        llMessageLinked(LINK_SET, COMMAND_OWNER, "lockappearance 1", kID);
                    }
                }
                else
                {
                    Notify(kID,"Only owners can use this option.",FALSE);
                }
                DoMenu(kID);
            }

        }
        else if (iNum == HTTPDB_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);

            if (sToken == g_sAppLockToken)
            {
                g_iAppLock = (integer)sValue;
            }
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1)
            {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);          
                string sMessage = llList2String(lMenuParams, 1);                                         
                integer iPage = (integer)llList2String(lMenuParams, 2);
                string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
                //remove stride from g_lMenuIDs
                //we have to subtract from the index because the dialog id comes in the middle of the stride
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                  
                if (sMenuType == g_sSubMenu)
                {
                    if (sMessage == UPMENU)
                    {
                        //give kID the parent menu
                        llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
                    }
                    else if(llGetSubString(sMessage, llStringLength(TICKED), -1) == APPLOCK)
                    {
                            if(llGetSubString(sMessage, 0, llStringLength(TICKED) - 1) == TICKED)
                            {
                                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "applock 0", kAv);
                            }
                            else
                            {
                                llMessageLinked(LINK_SET, COMMAND_NOAUTH, "applock 1", kAv);
                            }

                        }
                    else if (~llListFindList(g_lLocalButtons, [sMessage]))
                    {
                        //we got a response for something we handle locally
                        if (sMessage == POSMENU)
                        {
                            PosMenu(kAv);
                        }
                        else if (sMessage == ROTMENU)
                        {
                            RotMenu(kAv);
                        }
                        else if (sMessage == SIZEMENU)
                        {
                            SizeMenu(kAv);
                        }
                        else if (sMessage == COLORMENU)
                        {
                            g_sCurrentElement = "";
                            ELEMENTMENU = COLORMENU;
                            g_sType = "color";
                            ElementMenu(kAv, g_lColorElements);
                        }
                        else if (sMessage == HIDEMENU)
                        {
                            g_sCurrentElement = "";
                            ELEMENTMENU = HIDEMENU;
                            g_sType = "hide or show";
                            ElementMenu(kAv, g_lHideElements);
                        }
                        else if (sMessage == TEXTUREMENU)
                        {
                            g_sCurrentElement = "";
                            ELEMENTMENU = TEXTUREMENU;
                            g_sType = "texture";
                            ElementMenu(kAv, g_lTextureElements);
                        }                        
                    }
                    else if (~llListFindList(g_lRemoteButtons, [sMessage]))
                    {
                        //we got a submenu selection
                        llMessageLinked(LINK_SET, SUBMENU, sMessage, kAv);
                    }                                
                }
                else if (sMenuType == POSMENU)
                {
                    if (sMessage == UPMENU)
                    {
                        DoMenu(kAv);
                        return;
                    }
                    else if (llGetAttached())
                    {
                        vector vNudge = <0,0,0>;
                        if (sMessage == "left")
                        {
                            vNudge.x = g_fNudge;
                        }
                        else if (sMessage == "up")
                        {
                            vNudge.y = g_fNudge;                
                        }
                        else if (sMessage == "forward")
                        {
                            vNudge.z = g_fNudge;                
                        }            
                        else if (sMessage == "right")
                        {
                            vNudge.x = -g_fNudge;                
                        }            
                        else if (sMessage == "down")
                        {
                            vNudge.y = -g_fNudge;                    
                        }            
                        else if (sMessage == "backward")
                        {
                            vNudge.z = -g_fNudge;                
                        }                            
                        llMessageLinked(LINK_SET, APPEARANCE_POSITION, (string)vNudge, kAv);                        
                        
                        if (sMessage == "Nudge: S")
                        {
                            g_fNudge=g_fSmallNudge;
                        }
                        else if (sMessage == "Nudge: M")
                        {
                            g_fNudge=g_fMediumNudge;                
                        }
                        else if (sMessage == "Nudge: L")
                        {
                            g_fNudge=g_fLargeNudge;                
                        }                        
                    }
                    else
                    {
                        Notify(kAv, "Sorry, position can only be adjusted while worn",FALSE);
                    }
                    PosMenu(kAv);                    
                }
                else if (sMenuType == ROTMENU)
                {
                    if (sMessage == UPMENU)
                    {
                        DoMenu(kAv);
                        return;
                    }
                    else if (llGetAttached())
                    {
                        vector vNudge = <0,0,0>;
                        if (sMessage == "tilt up")
                        {
                            vNudge.x = g_fRotNudge;
                        }
                        else if (sMessage == "right")
                        {
                            vNudge.y = g_fRotNudge;                
                        }
                        else if (sMessage == "tilt left")
                        {
                            vNudge.z = g_fRotNudge;               
                        }            
                        else if (sMessage == "tilt down")
                        {
                            vNudge.x = -g_fRotNudge;                
                        }            
                        else if (sMessage == "left")
                        {
                            vNudge.y = -g_fRotNudge;                  
                        }            
                        else if (sMessage == "tilt right")
                        {
                            vNudge.z = -g_fRotNudge;               
                        }
                        llMessageLinked(LINK_SET, APPEARANCE_ROTATION, (string)vNudge, kAv);                        
                    }
                    else
                    {
                        Notify(kAv, "Sorry, position can only be adjusted while worn", FALSE);
                    }
                    RotMenu(kAv);                     
                }
                else if (sMenuType == SIZEMENU)
                {
                    if (sMessage == UPMENU)
                    {
                        DoMenu(kAv);
                        return;
                    }
                    else
                    {
                        integer iMenuCommand = llListFindList(SIZEMENU_BUTTONS, [sMessage]);
                        if (iMenuCommand != -1)
                        {
                            integer iSizeFactor = llList2Integer(g_lSizeFactors, iMenuCommand);
                            if (iSizeFactor == -1000)
                            {
                                // ResSize requested
                                if (g_iScaleFactor == 100)
                                {
                                    Notify(kAv, "The collar is already at rez size, resizing canceled.", FALSE); 
                                }
                                else
                                {
                                    llMessageLinked(LINK_SET, APPEARANCE_SIZE, "100§" + (string)TRUE, kAv);
                                }
                            }
                            else
                            {
                                llMessageLinked(LINK_SET, APPEARANCE_SIZE, (string)(g_iScaleFactor + iSizeFactor) + "§" + (string)FALSE, kAv);
                            }
                        }
                        SizeMenu(kAv);
                    }
                }
                else if (sMenuType == COLORMENU)
                {
                    if (sMessage == UPMENU)
                    {
                        if (g_sCurrentElement == "")
                        {
                            //main menu
                            llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
                        }
                        else if (g_sCurrentCategory == "")
                        {
                            g_sCurrentElement = "";
                            ELEMENTMENU = COLORMENU;
                            g_sType = "color";
                            ElementMenu(kAv, g_lColorElements);
                        }
                        else
                        {
                            g_sCurrentCategory = "";
                            CategoryMenu(kAv);
                        }
                    }
                    else if (g_sCurrentElement == "")
                    {
                        g_sCurrentElement = sMessage;
                        g_iPage = 0;
                        g_sCurrentCategory = "";
                        CategoryMenu(kAv);
                    }

                    else if (g_sCurrentCategory == "")
                    {
                        g_lColors = [];
                        g_sCurrentCategory = sMessage;
                        g_iPage = 0;
                        g_kUser = kAv;
                        string sUrl = g_sHTTPDB_Url + "static/colors-" + g_sCurrentCategory + ".txt";
                        g_kHTTPID = llHTTPRequest(sUrl, [HTTP_METHOD, "GET"], "");
                    }
                    else if (~(integer)llListFindList(g_lColors, [sMessage]))
                    {
                        integer iIndex = llListFindList(g_lColors, [sMessage]);
                        vector vColor = (vector)llList2String(g_lColors, iIndex + 1);
                        llMessageLinked(LINK_SET, APPEARANCE_COLOR, g_sCurrentElement + "§" + (string)vColor  + "§" + (string)TRUE, kAv);
                        ColorMenu(kAv);
                    }
                
                }
                else if (sMenuType == HIDEMENU)
                {
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
                            ELEMENTMENU = HIDEMENU;
                            g_sType = "hide or show";
                            ElementMenu(kAv, g_lHideElements);                            
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
                                llMessageLinked(LINK_SET, APPEARANCE_ALPHA, "ALL§1.0§" + (string)TRUE, kAv);
                            }
                            else if (sCmd == HIDE)
                            {
                                llMessageLinked(LINK_SET, APPEARANCE_ALPHA, "ALL§0.0§" + (string)TRUE, kAv);
                            }
                        }
                        else if (sElement != "")//ignore empty element strings since they won't work anyway
                        {
                            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, sElement +"§" + (string)fAlpha + "§" + (string)TRUE, kAv);
                        }
                        //SaveAlphaSettings();
                        g_sCurrentElement = "";
                        ELEMENTMENU = HIDEMENU;
                        g_sType = "hide or show";
                        ElementMenu(kAv, g_lHideElements);
                    }
                }
                else if (sMenuType == TEXTUREMENU)
                {
                    if (sMessage == UPMENU)
                    {
                        if (g_sCurrentElement == "")
                        {
                            //main menu
                            llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
                        }
                        else if (g_sCurrentCategory == "")
                        {
                            g_sCurrentElement = "";
                            ELEMENTMENU = TEXTUREMENU;
                            g_sType = "texture";
                            ElementMenu(kAv, g_lTextureElements);
                        }
                    }
                    else if (g_sCurrentElement == "")
                    {
                        g_sCurrentElement = sMessage;
                        TextureMenu(kAv, iPage);
                    }
                    else
                    {
                        //got a texture name
                        string sTex;
                        if (llListFindList(g_textures,[sMessage]) != -1)
                        {
                            sTex = llList2String(g_textures,llListFindList(g_textures,[sMessage]) + 1);
                        }
                        else
                        {
                            sTex = (string)llGetInventoryKey(sMessage);
                        }
                        //loop through links, setting texture if element type matches what we're changing
                        //root prim is 1, so start at 2
                        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sCurrentElement +"§" + sTex + "§" + (string)TRUE, kAv);
                        TextureMenu(kAv, iPage);
                    }                            
                }                
            }            
        }
        else if (iNum == DIALOG_TIMEOUT)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (iMenuIndex != -1)
            {
                //remove stride from g_lMenuIDs
                //we have to subtract from the index because the dialog id comes in the middle of the stride
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);                          
            }            
        }
    } 
    
    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        if (kID == g_kHTTPID)
        {
            if (iStatus == 200)
            {
                //we'll have gotten several lines like "Chartreuse|<0.54118, 0.98431, 0.09020>"
                //parse that into 2-strided list of colorname, colorvector
                g_lColors = llParseString2List(sBody, ["\n", "|"], []);
                g_lColors = llListSort(g_lColors, 2, TRUE);
                ColorMenu(g_kUser);
            }
        }
    }

   dataserver(key query_id, string data)
    {
        if (query_id == g_ktexcardID)
        {
            if (data == EOF)
                loadNoteCards("EOF");
            else
            {
                list temp = llParseString2List(data,[",",":","|","="],[]);
                g_textures += [llList2String(temp,0),llList2Key(temp,1)];
                // bump line number for reporting purposes and in preparation for reading next line
                ++g_noteLine;
                g_ktexcardID = llGetNotecardLine(g_noteName, g_noteLine);
            }
        }
    }
    
   
    changed(integer iChange)
    {
        if(iChange & CHANGED_INVENTORY)
        {
            loadNoteCards("");
        }        
    }
    
}