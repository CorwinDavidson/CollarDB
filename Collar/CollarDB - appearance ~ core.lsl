//CollarDB - appearance ~ core

integer COMMAND_NOAUTH          = 0xCDB000;
integer COMMAND_OWNER           = 0xCDB500;
integer COMMAND_SECOWNER        = 0xCDB501;
integer COMMAND_GROUP           = 0xCDB502;
integer COMMAND_WEARER          = 0xCDB503;
integer COMMAND_EVERYONE        = 0xCDB504;

integer HTTPDB_SAVE             = 0xCDB200;     // scripts send messages on this channel to have settings saved to httpdb
                                                // str must be in form of "token=value"
integer HTTPDB_REQUEST          = 0xCDB201;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 0xCDB202;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 0xCDB203;     // delete token from DB
integer HTTPDB_EMPTY            = 0xCDB204;     // sent by httpdb script when a token has no value in the db
integer HTTPDB_REQUEST_NOCACHE  = 0xCDB205;

integer APPEARANCE_ALPHA        = -0xCDB800;
integer APPEARANCE_COLOR        = -0xCDB801;
integer APPEARANCE_TEXTURE      = -0xCDB802;
integer APPEARANCE_POSITION     = -0xCDB803;
integer APPEARANCE_ROTATION     = -0xCDB804;
integer APPEARANCE_SIZE         = -0xCDB805;
integer APPEARANCE_SIZE_FACTOR  = -0xCDB815;

float MIN_SIZE = .01;
float MAX_SIZE = 10;
float MAX_DISTANCE = 10; 
float MIN_SCALE = .1;

// -----  HOVERTEXT --------------
vector g_vHideScale = <.02,.02,.02>;
vector g_vShowScale = <.02,.02,1.0>;

integer g_iHoverLink=0;
integer g_iHoverLastRank = 0;
integer g_iHoverOn = FALSE;
string g_sHoverText;
vector g_vHoverColor;
string g_sHoverLinkName = "FloatText";
// --------------------------------


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


integer g_iAppLock = FALSE;
string g_sAppLockToken = "AppLock";

integer g_iScaleFactor = 100; // the size on rez is always regarded as 100% to preven problem when scaling an item +10% and than - 10 %, which would actuall lead to 99% of the original size
integer g_iSizedByScript = FALSE; // prevent reseting of the script when the item has been chnged by the script
list g_lPrimStartSizes; // area for initial prim sizes (stored on rez)

key g_kWearer;

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
        integer iIndex;
        if (!(~(integer)llListFindList(lElement, ["nocolor"])))
        {
            iIndex = llListFindList(g_lColorElements, [sElement]);
            if (iIndex == -1)
                g_lColorElements += [sElement,(string)n];
            else 
                g_lColorElements = llListReplaceList(g_lColorElements,[sElement,llList2String(g_lColorElements,iIndex+1) + "§" + (string)n ], iIndex, iIndex+1);
        }
        if (!(~(integer)llListFindList(lElement, ["notexture"])))
        {
            iIndex = llListFindList(g_lTextureElements, [sElement]);
            if (iIndex == -1)
                g_lTextureElements += [sElement,(string)n];
            else 
                g_lTextureElements = llListReplaceList(g_lTextureElements,[sElement,llList2String(g_lTextureElements,iIndex+1) + "§" + (string)n ], iIndex, iIndex+1);
        }
        if (!(~(integer)llListFindList(lElement, ["nohide"])))
        {
            iIndex = llListFindList(g_lHideElements, [sElement]);
            if (iIndex == -1)
                g_lHideElements += [sElement,(string)n];
            else 
                g_lHideElements = llListReplaceList(g_lHideElements,[sElement,llList2String(g_lHideElements,iIndex+1) + "§" + (string)n ], iIndex, iIndex+1);
        }        
    }
    g_lColorElements = llListSort(g_lColorElements, 2, TRUE);
    g_lTextureElements = llListSort(g_lTextureElements, 2, TRUE);    
    g_lHideElements = llListSort(g_lHideElements, 2, TRUE);
}

string ElementType(integer iLinkNumber)
{
    // return a strided list representing primname|nocolor|notexture|nohide
    string sDesc = (string)llGetObjectDetails(llGetLinkKey(iLinkNumber), [OBJECT_DESC]);
    //each prim should have <elementname> in its description, plus "nocolor" or "notexture", if you want the prim to
    //not appear in the color or texture menus
    list lParams = llParseString2List(sDesc, ["~"], []);
    string type = llList2String(lParams, 0) + "|";
    if (type == g_sHoverLinkName + "|") 
    {
        g_iHoverLink = iLinkNumber;
    }
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

LoadAlphaSettings()
{
    integer n;
    integer iItemCount = llGetListLength(g_lAlphaSettings);
    for (n = 0; n <= iItemCount; n=n+2)
    {
        string sElement = llList2String(g_lAlphaSettings, n);
        float fAlpha = (float)llList2String(g_lAlphaSettings, n + 1);
        SetElementAlpha(sElement, fAlpha, FALSE);
    }
}

SetAllElementsAlpha(float fAlpha, integer bSaveHTTPDB)
{
 //   llSetLinkAlpha(LINK_SET, fAlpha, ALL_SIDES);
    //set alphasettings of all elements to fAlpha (either 1.0 or 0.0 here)
    g_lAlphaSettings = [];
    integer n;
    integer iStop = llGetListLength(g_lHideElements);
    for (n = 0; n < iStop; n=n + 2)
    {
        string sElement = llList2String(g_lHideElements, n);
        SetElementAlpha(sElement, fAlpha, FALSE);
        g_lAlphaSettings += [sElement, fAlpha];
    }
    if (bSaveHTTPDB)
    {
        if (llGetListLength(g_lAlphaSettings)>0)
        {
            llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sAlphaDBToken + "=" + llDumpList2String(g_lAlphaSettings, ","), NULL_KEY);
        }
        else
        {
            llMessageLinked(LINK_SET, HTTPDB_DELETE, g_sAlphaDBToken, NULL_KEY);
        }
    }
}

SetElementAlpha(string sElement2Set, float fAlpha, integer bSaveHTTPDB)
{
    //loop through links, setting color if element type matches what we're changing
    //root prim is 1, so start at 2
    integer iIndex;
    integer i;
    iIndex = llListFindList(g_lHideElements, [sElement2Set]);
    if (iIndex != -1)
    {
        string sElement = llList2String(g_lHideElements,iIndex);
        list lLinks = llParseString2List(llList2String(g_lHideElements,iIndex+1),["§"],[]);
        integer n;
        for (n = 0; n < llGetListLength(lLinks); n++)
        {
            llSetLinkAlpha(n, fAlpha, ALL_SIDES);
        }
        integer iIndex2 = llListFindList(g_lAlphaSettings, [sElement]);
        if (iIndex2 == -1)
        {
            g_lAlphaSettings += [sElement, fAlpha];
        }
        else
        {
            g_lAlphaSettings = llListReplaceList(g_lAlphaSettings, [fAlpha], iIndex2+ 1, iIndex2 + 1);
        }
    }
    if (bSaveHTTPDB)
    {
        if (llGetListLength(g_lAlphaSettings)>0)
        {
            llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sAlphaDBToken + "=" + llDumpList2String(g_lAlphaSettings, ","), NULL_KEY);
        }
        else
        {
            llMessageLinked(LINK_SET, HTTPDB_DELETE, g_sAlphaDBToken, NULL_KEY);
        }
    }
}

LoadColorSettings()
{
    integer n;
    integer iItemCount = llGetListLength(g_lColorSettings);
    for (n = 0; n <= iItemCount; n=n+2)
    {
        string sElement = llList2String(g_lColorSettings, n);
        vector vColor = (vector)llList2String(g_lColorSettings, n + 1);
        SetElementColor(sElement, vColor, FALSE);
    }
}

SetElementColor(string sElement2Set, vector vColor, integer bSaveHTTPDB)
{
    integer iIndex;
    integer i;
    iIndex = llListFindList(g_lColorElements, [sElement2Set]);
    if (iIndex != -1)
    {
        string sElement = llList2String(g_lColorElements,iIndex);
        list lLinks = llParseString2List(llList2String(g_lColorElements,iIndex+1),["§"],[]);
        integer n;
        for (n = 0; n < llGetListLength(lLinks); n++)
        {
            llSetLinkColor(n, vColor, ALL_SIDES);
        }
        //create shorter string from the color vectors before saving
        string sStrColor = (string)vColor;
        //change the g_lColorSettings list entry for the current element
        integer iIndex = llListFindList(g_lColorSettings, [sElement2Set]);
        if (iIndex != -1)
        {
            g_lColorSettings += [sElement2Set, sStrColor];
        }
        else
        {
            g_lColorSettings = llListReplaceList(g_lColorSettings, [sStrColor], iIndex + 1, iIndex + 1);
        }
    }
    if (bSaveHTTPDB)
    {
        llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sColorDBToken + "=" + llDumpList2String(g_lColorSettings, "~"), NULL_KEY);
    }
}

LoadTextureSettings()
{
    integer n;
    integer iItemCount = llGetListLength(g_lTextureSettings);
    for (n = 0; n <= iItemCount; n=n+2)
    {
        string sElement = llList2String(g_lTextureSettings, n);
        key kTex = (key)llList2String(g_lTextureSettings, n + 1);
        SetElementTexture(sElement, kTex, FALSE);
    }
}

SetElementTexture(string sElement2Set, key kTex,integer bSaveHTTPDB)
{
    integer iIndex;
    integer i;
    iIndex = llListFindList(g_lTextureElements, [sElement2Set]);
    if (iIndex != -1)
    {
        string sElement = llList2String(g_lTextureElements,iIndex);
        list lLinks = llParseString2List(llList2String(g_lTextureElements,iIndex+1),["§"],[]);
        integer n;
        for (n = 0; n < llGetListLength(lLinks); n++)
        {
            list lParams=llGetLinkPrimitiveParams(n, [ PRIM_TEXTURE, ALL_SIDES]);
            integer iSides=llGetListLength(lParams);
            integer iSide;
            list lTemp=[];
            for (iSide = 0; iSide < iSides; iSide = iSide +4)
            {
                lTemp += [PRIM_TEXTURE, iSide/4, kTex] + llList2List(lParams, iSide+1, iSide+3);
            }
            llSetLinkPrimitiveParamsFast(n, lTemp);
        }

        //change the textures list entry for the current element
        integer iIndex=llListFindList(g_lTextureSettings, [sElement2Set]);
        if (iIndex != -1)
        {
            g_lTextureSettings += [sElement2Set, kTex];
        }
        else
        {
            g_lTextureSettings = llListReplaceList(g_lTextureSettings, [kTex], iIndex + 1, iIndex + 1);
        }
    }
    if (bSaveHTTPDB)
    {
        llMessageLinked(LINK_SET, HTTPDB_SAVE, g_sTextureDBToken + "=" + llDumpList2String(g_lTextureSettings, "~"), NULL_KEY);
    }
}

float min(float a, float b) {
    if (a < b) return a;
    return b;
}
 
float max(float a, float b) {
    if (a > b) return a;
    return b;
}
 
float constrainMinMax(float value, float min, float max) {
    value = max(value, min);
    value = min(value, max);
    return value;
}
 
vector constrainSize(vector size) {
    size.x = constrainMinMax(size.x, MIN_SIZE, MAX_SIZE);
    size.y = constrainMinMax(size.y, MIN_SIZE, MAX_SIZE);
    size.z = constrainMinMax(size.z, MIN_SIZE, MAX_SIZE);
    return size;
}
 
vector constrainDistance(vector delta) {
    delta.x = min(delta.x, MAX_DISTANCE);
    delta.y = min(delta.y, MAX_DISTANCE);
    delta.z = min(delta.z, MAX_DISTANCE);
    return delta;
}
Store_StartScaleLoop()
{
    g_lPrimStartSizes = [];
    integer iPrimIndex;
    vector vPrimScale;
    vector vPrimPos;
    list lPrimParams;
    for(iPrimIndex = 0; iPrimIndex <= llGetNumberOfPrims(); iPrimIndex++)
    {
        lPrimParams = llGetLinkPrimitiveParams( iPrimIndex, [PRIM_SIZE, PRIM_POS_LOCAL]);
        vPrimScale = llList2Vector(lPrimParams, 0);
        vPrimPos = llList2Vector(lPrimParams, 1);

        g_lPrimStartSizes += [(string)vPrimScale + "#" + (string)vPrimPos];
    }
    g_iScaleFactor = 100;
    llMessageLinked(LINK_SET, APPEARANCE_SIZE_FACTOR, (string)g_iScaleFactor, NULL_KEY);
}

ScalePrimLoop(integer iScale, integer iRezSize, key kAV)
{    
    integer iPrimIndex;
    list iPrim;
    float fScale = iScale / 100.0;
    list lPrimParams; 
    vector vPrimScale;
    vector vPrimPos;
    vector vSize;

    Notify(kAV, "Scaling started, please wait ...", TRUE);
    g_iSizedByScript = TRUE;
    for (iPrimIndex = 0; iPrimIndex <= llGetNumberOfPrims(); iPrimIndex++ )
    {
        iPrim = llParseString2List(llList2String(g_lPrimStartSizes,iPrimIndex), ["#"], []);
        if (fScale == 1.0)
        {
            vPrimScale = (vector)llList2String(iPrim, 0) * fScale;
            vPrimPos = (vector)llList2String(iPrim, 1)  * fScale;            
        }
        else
        {
            vPrimScale = constrainSize((vector)llList2String(iPrim, 0) * fScale);
            vPrimPos = constrainDistance((vector)llList2String(iPrim, 1)  * fScale);
        }

        if (iPrimIndex > 1) 
        {
            llSetLinkPrimitiveParamsFast(iPrimIndex, [PRIM_SIZE, vPrimScale, PRIM_POSITION, vPrimPos]);
        }
        else 
        {
            llSetLinkPrimitiveParamsFast(iPrimIndex, [PRIM_SIZE, vPrimScale]);
            
        }
    }
    g_iScaleFactor = iScale;
    llMessageLinked(LINK_SET, APPEARANCE_SIZE_FACTOR, (string)g_iScaleFactor, NULL_KEY);
    g_iSizedByScript = TRUE;
    Notify(kAV, "Scaling finished, the collar is now on "+ (string)g_iScaleFactor +"% of the rez size.", TRUE);
}


ForceUpdate()
{
    //workaround for https://jira.secondlife.com/browse/VWR-1168
    llSetText(".", <1,1,1>, 1.0);
    llSetText("", <1,1,1>, 1.0);
}

AdjustPos(vector vDelta)
{
    if (llGetAttached())
    {
        llSetPos(llGetLocalPos() + vDelta);
        ForceUpdate();
    }
}

AdjustRot(vector vDelta)
{
    if (llGetAttached())
    {
        llSetLocalRot(llGetLocalRot() * llEuler2Rot(vDelta));
        ForceUpdate();
    }
}

// ---  HOVERTEXT  ----

TextDisplay(string sText, integer iVisible)
{
    vector vColor;
    vector vScale;        
    if(iVisible)
    {
        vColor = g_vHoverColor;
        vScale = g_vShowScale;
        g_iHoverOn = TRUE;
    }
    else
    {
        vColor = <1,1,1>;
        vScale = g_vHideScale;
        g_iHoverOn = FALSE;
    }
    llSetLinkPrimitiveParamsFast(g_iHoverLink,[PRIM_TEXT, sText, vColor, 1.0]);
    if (g_iHoverLink > 1)
    {//don't scale the root prim
        llSetLinkPrimitiveParamsFast(g_iHoverLink,[PRIM_SIZE,vScale]);
    }    
}

ShowText(string sNewText)
{
    g_sHoverText = sNewText;
    list lTmp = llParseString2List(g_sHoverText, ["\\n"], []);
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
//-----------------------------------------
default
{
    state_entry()
    {
        g_kWearer = llGetOwner();       
        
        BuildElementList();
        
        g_vHoverColor = (vector)llList2String(llGetLinkPrimitiveParams(g_iHoverLink,[PRIM_COLOR,0]),0);
        TextDisplay("",FALSE);
        
        Store_StartScaleLoop();
        string sPrefix = llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        if (sPrefix != "")
        {
            g_sAlphaDBToken = sPrefix + g_sAlphaDBToken;
            g_sColorDBToken = sPrefix + g_sColorDBToken;
            g_sTextureDBToken = sPrefix + g_sTextureDBToken;                        
        }
        llRequestPermissions(g_kWearer, PERMISSION_TAKE_CONTROLS);
        llSetTimerEvent(15.0);
        
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
                if (g_iHoverOn)
                {
                    //only change text if commander has smae or greater auth
                    if (iNum <= g_iHoverLastRank)
                    {
                        if (sNewText == "")
                        {
                            g_sHoverText = "";
                            TextDisplay("",FALSE);
                        }
                        else
                        {
                            ShowText(sNewText);
                            g_iHoverLastRank = iNum;
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
                        g_sHoverText = "";
                        TextDisplay("",FALSE);
                    }
                    else
                    {
                        ShowText(sNewText);
                        g_iHoverLastRank = iNum;
                    }
                }
            }
            else if (sCommand == "textoff")
            {
                if (g_iHoverOn)
                {
                    //only turn off if commander auth is >= g_iLastRank
                    if (iNum <= g_iHoverLastRank)
                    {
                        g_iHoverLastRank = COMMAND_WEARER;
                        TextDisplay("",FALSE);
                    }
                }
                else
                {
                    g_iHoverLastRank = COMMAND_WEARER;
                    TextDisplay("",FALSE);
                }
            }
            else if (sCommand == "texton")
            {
                if( g_sHoverText != "")
                {
                    g_iHoverLastRank = iNum;
                    ShowText(g_sHoverText);
                }
            }
            else if (sStr == "reset" && (iNum == COMMAND_OWNER || iNum == COMMAND_WEARER))
            {
                g_sHoverText = "";
                TextDisplay("",FALSE);
                llResetScript();
            }
        }    
        else if (iNum == HTTPDB_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);

            if (sToken == g_sAlphaDBToken)
            {
                //we got the list of alphas for each element
                g_lAlphaSettings = llParseString2List(sValue, [","], []);
                LoadAlphaSettings();
            }
            else if (sToken == g_sColorDBToken)
            {
                g_lColorSettings = llParseString2List(sValue, ["~"], []);
                LoadColorSettings();
            }
            else if (sToken == g_sTextureDBToken)
            {
                g_lTextureSettings = llParseString2List(sValue, ["~"], []);
                //llInstantMessage(llGetOwner(), "Loaded texture settings.");
                LoadTextureSettings();
            }
            else if (sToken == g_sAppLockToken)
            {
                g_iAppLock = (integer)sValue;
            }
        }
        else if (iNum >= APPEARANCE_SIZE && iNum <= APPEARANCE_ALPHA)
        {
            list lParams = llParseString2List(sStr, ["§"], []);
            string sParam1 = llList2String(lParams, 0);
            string sParam2 = llList2String(lParams, 1);
            string sParam3 = llList2String(lParams, 2);            
            if (iNum == APPEARANCE_POSITION)
            {
                AdjustPos((vector)sParam1);
            }
            else if (iNum == APPEARANCE_ROTATION)
            {
                AdjustRot((vector)sParam1);
            }
            else if (iNum == APPEARANCE_SIZE)
            {
                ScalePrimLoop((integer)sParam1, (integer)sParam2, kID);
            }
            else if (iNum == APPEARANCE_ALPHA)
            {
                if (sParam1 == "ALL")
                    SetAllElementsAlpha((float)sParam2, (integer)sParam3);
                else
                    SetElementAlpha(sParam1, (float)sParam2, (integer)sParam3);
        
            }
            else if (iNum == APPEARANCE_COLOR)
            {
                SetElementColor(sParam1, (vector)sParam2, (integer)sParam3);        
            }
            else if (iNum == APPEARANCE_TEXTURE)
            {
                SetElementTexture(sParam1, (key)sParam2,(integer)sParam3);         
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
            g_vHoverColor = (vector)llList2String(llGetLinkPrimitiveParams(g_iHoverLink,[PRIM_COLOR,0]),0);
            if (g_iHoverOn)
            {
                ShowText(g_sHoverText);
            }
        }
        
        if (iChange & (CHANGED_SCALE))
        {
            if (!g_iSizedByScript)
            {
                    Store_StartScaleLoop();
            }
        }
        if (iChange & (CHANGED_SHAPE | CHANGED_LINK))
        {
            Store_StartScaleLoop();
        }
    }

    on_rez(integer start)
    {
        if(g_iHoverOn && g_sHoverText != "")
        {
            ShowText(g_sHoverText);
        }
        else
        {
            TextDisplay("",FALSE); 
        }
    }
    
    timer()
    {

        if(llGetPermissions() & PERMISSION_TAKE_CONTROLS) return;
        llRequestPermissions(g_kWearer, PERMISSION_TAKE_CONTROLS);

        // the timer is needed as the changed_size even is triggered twice        
        if (g_iSizedByScript)
            g_iSizedByScript = FALSE;
    }    
}