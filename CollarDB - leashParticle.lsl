//leash particle script for the Open Collar Project (c)
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.
//Split from the leash script in April 2010 by Garvin Twine

// - MESSAGE MAP
integer COMMAND_NOAUTH      = 0;
integer COMMAND_OWNER       = 500;
integer COMMAND_SECOWNER    = 501;
integer COMMAND_GROUP       = 502;
integer COMMAND_WEARER      = 503;
integer COMMAND_EVERYONE    = 504;
integer COMMAND_SAFEWORD    = 510;
integer POPUP_HELP          = 1001;
// -- SETTINGS (HTTPDB / LOCAL)
// - Setting strings must be in the format: "token=value"
integer HTTPDB_SAVE             = 2000; // to have settings saved to httpdb
integer HTTPDB_REQUEST          = 2001; // send requests for settings on this channel
integer HTTPDB_RESPONSE         = 2002; // responses received on this channel
integer HTTPDB_DELETE           = 2003; // delete token from DB
integer HTTPDB_EMPTY            = 2004; // returned when a token has no value in the httpdb
integer LOCALSETTING_SAVE       = 2500;
integer LOCALSETTING_REQUEST    = 2501;
integer LOCALSETTING_RESPONSE   = 2502;
integer LOCALSETTING_DELETE     = 2503;
integer LOCALSETTING_EMPTY      = 2504;
// -- MENU/DIALOG
integer MENUNAME_REQUEST    = 3000;
integer MENUNAME_RESPONSE   = 3001;
integer SUBMENU_CHANNEL     = 3002;
integer MENUNAME_REMOVE     = 3003;

integer DIALOG              = -9000;
integer DIALOG_RESPONSE     = -9001;
integer DIALOG_TIMEOUT      = -9002;
integer LOCKMEISTER         = -8888;
integer LOCKGUARD           = -9119;
integer g_iLMListener;
integer g_iLMListernerDetach;

integer COMMAND_PARTICLE = 20000;
integer COMMAND_LEASH_SENSOR = 20001;

// --- menu tokens ---
string UPMENU       = "^";
string MORE         = ">";
string PARENTMENU   = "Leash";
string SUBMENU      = "L-Options";
string L_TEXTURE    = "Texture";
string L_DENSITY    = "Density";
string L_COLOR      = "Color";
string L_GRAVITY    = "Gravity";
string L_SIZE       = "Size";
string L_DEFAULTS   = "ResetDefaults";

list g_lSettings; //["tex", "texName", "size", "0.07", "color", "1,1,1", "gravity", "1.0", "density", "0.04", "Glow", "1"]

string g_sCurrentMenu = "";
string g_sMenuUser;
key g_kDialogID;

string g_sCurrentCategory = "";
list g_lCategories = ["Blues", "Browns", "Grays", "Greens", "Purples", "Reds", "Yellows"];
list g_lColors;
key g_kHTTPID;
string g_sHTTPDB_Url = "http://data.collardb.com/";

// Textures in Notecard for Non Full Perm textures
key g_ktexcardID;
string g_noteName = "";
integer g_noteLine;
list g_textures = [];
list g_read = [];


// ----- collar -----
//string g_sWearerName;
key g_kWearer;

key NULLKEY = "";
key g_kLeashedTo = NULLKEY;
key g_kLeashToPoint = NULLKEY;
key g_kParticleTarget = NULLKEY;
integer g_bLeasherInRange;
integer g_bInvisibleLeash = FALSE;
integer g_iAwayCounter;

integer g_bLeashActive;

//List of 4 leash/chain points, lockmeister names used (list has to be all lower case, prims dont matter, converting on compare to lower case)
//strided list... LM name, linkNumber, BOOL_ACVTIVE
list g_lLeashPrims;


//global integer used for loops
integer g_iLoop;

debug(string sText)
{
    //llOwnerSay(llGetScriptName() + " DEBUG: " + sText);
}

FindLinkedPrims()
{
    integer linkcount = llGetNumberOfPrims();
    //root prim is 1, so start at 2
    for (g_iLoop = 2; g_iLoop <= linkcount; g_iLoop++)
    {
        string sPrimDesc = (string)llGetObjectDetails(llGetLinkKey(g_iLoop), [OBJECT_DESC]);
        list lTemp = llParseString2List(sPrimDesc, ["~"], []);
        integer iLoop;
        for (iLoop = 0; iLoop < llGetListLength(lTemp); iLoop++)
        {
            string sTest = llList2String(lTemp, iLoop);
            debug(sTest);
            //expected either "leashpoint" or "leashpoint:point"
            if (llGetSubString(sTest, 0, 9) == "leashpoint")
            {
                if (llGetSubString(sTest, 11, -1) == "")
                {
                    g_lLeashPrims += [sTest, (string)g_iLoop, "1"];
                }
                else
                {
                    g_lLeashPrims += [llGetSubString(sTest, 11, -1), (string)g_iLoop, "1"];
                }
            }
        }
    }
    //if we did not find any leashpoint... we unset the root as one
    if (!llGetListLength(g_lLeashPrims))
    {
        g_lLeashPrims = ["collar", LINK_THIS, "1"];
    }
}

//Particle system and variables

string g_sParticleTexture = "chain";
string g_sParticleTextureID; //we need the UUID for llLinkParticleSystem
float g_fLeashLength;
vector g_vLeashColor = <1,1,1>;
vector g_vLeashSize = <0.07, 0.07, 1.0>;
integer g_bParticleGlow = TRUE;
float g_fParticleAge = 3.0;
float g_fParticleAlpha = 1.0;
vector g_vLeashGravity = <0.0,0.0,-1.0>;
integer g_iParticleCount = 1;
float g_fBurstRate = 0.04;
//same g_lSettings but to store locally the default settings recieved from the defaultsettings note card, using direct string here to save some bits
list g_lDefaultSettings = [L_TEXTURE, g_sParticleTexture, L_SIZE, "<0.07,0.07,0.07>", L_COLOR, "<1,1,1>", L_DENSITY, "0.04", L_GRAVITY, "<0.0,0.0,-1.0>", "Glow", "1"];

Particles(integer iLink, key kParticleTarget)
{
    //when we have no target to send particles to, dont create any
    if (kParticleTarget == NULLKEY)
    {
        return;
    }
    //taken out as vars to save memory
    //float fMaxSpeed = 3.0;          // Max speed each particle is spit out at
    //float fMinSpeed = 3.0;          // Min speed each particle is spit out at
    //these values do nothing when particles go to a target, the speed is determined by the particle age then
    //integer iFlags = PSYS_PART_INTERP_COLOR_MASK | PSYS_PART_INTERP_SCALE_MASK | PSYS_PART_FOLLOW_VELOCITY_MASK | PSYS_PART_TARGET_POS_MASK;
    integer iFlags = PSYS_PART_FOLLOW_VELOCITY_MASK | PSYS_PART_TARGET_POS_MASK|PSYS_PART_FOLLOW_SRC_MASK;

    if (g_bParticleGlow) iFlags = iFlags | PSYS_PART_EMISSIVE_MASK;

    list lTemp = [
        PSYS_PART_MAX_AGE,g_fParticleAge,
        PSYS_PART_FLAGS,iFlags,
        PSYS_PART_START_COLOR, g_vLeashColor,
        //PSYS_PART_END_COLOR, g_vLeashColor,
        PSYS_PART_START_SCALE,g_vLeashSize,
        //PSYS_PART_END_SCALE,g_vLeashSize,
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_DROP,
        PSYS_SRC_BURST_RATE,g_fBurstRate,
        PSYS_SRC_ACCEL, g_vLeashGravity,
        PSYS_SRC_BURST_PART_COUNT,g_iParticleCount,
        //PSYS_SRC_BURST_SPEED_MIN,fMinSpeed,
        //PSYS_SRC_BURST_SPEED_MAX,fMaxSpeed,
        PSYS_SRC_TARGET_KEY,kParticleTarget,
        PSYS_SRC_MAX_AGE, 0,
        PSYS_SRC_TEXTURE, g_sParticleTextureID
            //PSYS_PART_START_ALPHA, g_fParticleAlpha,
            //PSYS_PART_END_ALPHA, g_fParticleAlpha
            ];
    llLinkParticleSystem(iLink, lTemp);
}

StartParticles(key kParticleTarget)
{
    debug(llList2CSV(g_lLeashPrims));
    for (g_iLoop = 0; g_iLoop < llGetListLength(g_lLeashPrims); g_iLoop = g_iLoop + 3)
    {
        if ((integer)llList2String(g_lLeashPrims, g_iLoop + 2))
        {
            Particles((integer)llList2String(g_lLeashPrims, g_iLoop + 1), kParticleTarget);
        }
    }
    llSetTimerEvent(3.0);
    g_bLeashActive = TRUE;
}

StopParticles(integer iEnd)
{
    for (g_iLoop = 0; g_iLoop < llGetListLength(g_lLeashPrims); g_iLoop++)
    {
        llLinkParticleSystem((integer)llList2String(g_lLeashPrims, g_iLoop + 1), []);
    }
    if (iEnd)
    {
        g_bLeashActive = FALSE;
        g_kLeashedTo = NULLKEY;
        g_kLeashToPoint = NULLKEY;
        g_kParticleTarget = NULLKEY;
        llSensorRemove();
    }
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

string Vec2String(vector vVec)
{
    list lParts = [vVec.x, vVec.y, vVec.z];
    for (g_iLoop = 0; g_iLoop < 3; g_iLoop++)
    {
        string sStr = llList2String(lParts, g_iLoop);
        //remove any trailing 0's or .'s from sStr
        while ((~(integer)llSubStringIndex(sStr, ".")) && (llGetSubString(sStr, -1, -1) == "0" || llGetSubString(sStr, -1, -1) == "."))
        {
            sStr = llGetSubString(sStr, 0, -2);
        }
        lParts = llListReplaceList(lParts, [sStr], g_iLoop, g_iLoop);
    }
    return "<" + llDumpList2String(lParts, ",") + ">";
}

SaveSettings(string sToken, string sSave, integer bSaveToLocal)
{
    integer iIndex = llListFindList(g_lSettings, [sToken]);
    if (iIndex>=0)
    {
        g_lSettings = llListReplaceList(g_lSettings, [sSave], iIndex +1, iIndex +1);

    }
    else
    {
        g_lSettings = g_lSettings + [sToken, sSave];
    }
    //sToSave = sToSave + llList2CSV(g_lSettings);
    if (bSaveToLocal)
    {
        string sToSave = "leash=" + llDumpList2String(g_lSettings, ",");
        llMessageLinked(LINK_THIS, LOCALSETTING_SAVE, sToSave, NULLKEY);
    }
}

SaveDefaultSettings(string sSetting, string sValue)
{
    integer index = llListFindList(g_lDefaultSettings, [sSetting]) +1;
    g_lDefaultSettings = llListReplaceList(g_lDefaultSettings, [sValue], index, index);
}

string GetDefaultSetting(string sSetting)
{
    integer index = llListFindList(g_lDefaultSettings, [sSetting]);
    return llList2String(g_lDefaultSettings, index + 1);
}

// Added bSave as a boolean, to make this a more versatile wrapper
SetTexture(string sIn, key kIn)
{
    g_sParticleTexture = sIn;
    if (llToLower(g_sParticleTexture) == "noleash")
    {
        g_bInvisibleLeash = TRUE;
    }
    else
    {
        g_bInvisibleLeash = FALSE;
    }
    debug("particleTexture= " + sIn);
    if(llListFindList(g_textures,[sIn]) != -1)
    {
        g_sParticleTextureID = llList2Key(g_textures,llListFindList(g_textures,[sIn])+1);
    }
    else
    {
        g_sParticleTextureID = llGetInventoryKey(sIn);
    }
    debug("particleTextureID= " + (string)g_sParticleTextureID);
    if (kIn)
    {
        Notify(kIn, "Leash texture set to " + g_sParticleTexture, FALSE);
    }
    debug("activeleashpoints= " + (string)g_bLeashActive);
    if (g_bLeashActive)
    {
        if (g_bInvisibleLeash)
        {
            StopParticles(FALSE);
        }
        else
        {
            StartParticles(g_kParticleTarget);
        }
    }
}

integer KeyIsAv(key id)
{
    return llGetAgentSize(id) != ZERO_VECTOR;
}

//Menus
// Create a random "key" for dialog uniqueness
// "chars" provides hexadecimal characters for the function to choose from

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    //debug("dialog:"+(string)llGetFreeMemory( ));
    string sChars = "0123456789abcdef";
    string sOut;
    integer n;
    for (n = 0; n < 8; n++)
    {
        integer iIndex = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        sOut += llGetSubString(sChars, iIndex, iIndex);
    }
    key kID = (key)(sOut + "-0000-0000-0000-000000000000");

    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

OptionsMenu(key kIn)
{
    g_sCurrentMenu = SUBMENU;
    list lButtons = [L_TEXTURE, L_DENSITY, L_GRAVITY, L_COLOR, L_SIZE];
    if (g_bParticleGlow)
    {
        lButtons += "GlowOff";
    }
    else
    {
        lButtons += "GlowOn";
    }
    lButtons += [L_DEFAULTS];
    string sPrompt = "Leash Options (Owner Only)\n";
    g_kDialogID = Dialog(kIn, sPrompt, lButtons, [UPMENU], 0);
}

DensityMenu(key kIn)
{
    list lButtons = ["Default", "+", "-"];
    g_sCurrentMenu = L_DENSITY;
    string sPrompt = "Choose '+' for more and '-' for less particles\n'Default' to revert to the default\n";
    g_kDialogID = Dialog(kIn, sPrompt, lButtons, [UPMENU], 0);
}

GravityMenu(key kIn)
{
    list lButtons = ["Default", "+", "-", "noGravity"];
    g_sCurrentMenu = L_GRAVITY;
    string sPrompt = "Choose '+' for more and '-' for less leash-gravity\n'Default' to revert to the default\nCurrent Gravity = ";
    string sCurrentGravity = llGetSubString((string)g_vLeashGravity.z, 1, 3);
    sPrompt += sCurrentGravity + "\nDefault: 1.0";
    g_kDialogID = Dialog(kIn, sPrompt, lButtons, [UPMENU], 0);
}

SizeMenu(key kIn)
{
    list lButtons = ["Default", "+", "-", "minimum"];
    g_sCurrentMenu = L_SIZE;
    string sPrompt = "Choose '+' for bigger and '-' for smaller size of the leash texture\n'Default' to revert to the default\n'minium' for the smallest possible\nCurrent Size = ";
    string sCurrentSize = llGetSubString((string)g_vLeashSize.x, 0, 3);
    sPrompt += sCurrentSize + "\nDefault: 0.07 (0.03 steps)";
    g_kDialogID = Dialog(kIn, sPrompt, lButtons, [UPMENU], 0);
}

ColorCategoryMenu(key kIn)
{
    //give kAv a dialog with a list of color cards
    string sPrompt = "Pick a Color Category.\n";
    g_sCurrentMenu = "L-ColorCat";
    g_kDialogID = Dialog(kIn, sPrompt, g_lCategories, [UPMENU], 0);
}

ColorMenu(key kIn)
{
    string sPrompt = "Pick a Color.\n";
    list lButtons = llList2ListStrided(g_lColors,0,-1,2);
    g_sCurrentMenu = L_COLOR;
    g_kDialogID = Dialog(kIn, sPrompt, lButtons, [UPMENU], 0);
}

TextureMenu(key kIn)
{
    list lButtons = ["Default"];
    integer iLoop;
    string sName;
    integer iCount = llGetInventoryNumber(0);
    for (iLoop = 0; iLoop < iCount; iLoop++)
    {
        sName = llGetInventoryName(0, iLoop);
        if (sName == "chain" || sName == "rope")
        {
            lButtons += [sName];
        }
        else if (llGetSubString(sName, 0, 5) == "leash_")
        {
            sName = llDeleteSubString(sName, 0, 5);
            lButtons += [sName];
        }
        integer iNoteTex = llGetListLength(g_textures);
        for (iLoop=0;iLoop<iNoteTex;iLoop=iLoop+2)
        {
            string sName = llList2String(g_textures,iLoop);
            lButtons += [sName];
        }        
    }
    lButtons += ["noTexture", "noLeash"];
    g_sCurrentMenu = L_TEXTURE;
    string sPrompt = "Choose a texture\nnoTexture does default SL particle dots\nnoLeash means no particle leash at all\ncurrent Texture = ";
    sPrompt += g_sParticleTexture + "\n";
    g_kDialogID = Dialog(kIn, sPrompt, lButtons, [UPMENU], 0);
}

LMSay()
{
    llShout(LOCKMEISTER, (string)llGetOwnerKey(g_kLeashedTo) + "collar");
    llShout(LOCKMEISTER, (string)llGetOwnerKey(g_kLeashedTo) +  "handle");
}

integer isInSimOrJustOutside(vector v)
{
    if(v == ZERO_VECTOR || v.x < -25 || v.x > 280 || v.y < -25 || v.y > 280)
        return FALSE;
    return TRUE;
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
            if (StartsWith(llToLower(sName),"~cdblt_"))
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

default
{
    state_entry()
    {
        loadNoteCards("");
        StopParticles(TRUE);
        FindLinkedPrims();
        SetTexture(g_sParticleTexture, NULLKEY);
        llSleep(1.0);
        llMessageLinked(LINK_SET, MENUNAME_RESPONSE, PARENTMENU + "|" + SUBMENU, NULL_KEY);
        g_kWearer = llGetOwner();
        //llOwnerSay((string)llGetFreeMemory());
    }
    on_rez(integer iRez)
    {
        llResetScript();
    }

    link_message(integer iSenderPrim, integer iAuth, string sMessage, key kMessageID)
    {
        if (iAuth == COMMAND_PARTICLE)
        {
            g_kLeashedTo = kMessageID;
            if (sMessage == "unleash")
            {
                g_bLeasherInRange = FALSE;
                StopParticles(TRUE);
                llListenRemove(g_iLMListener);
                llListenRemove(g_iLMListernerDetach);
            }
            else
            {
                if (g_bInvisibleLeash)
                {// only start the sensor for the leasher
                    g_bLeasherInRange = TRUE;
                    llSetTimerEvent(3.0);
                }
                else
                {
                    integer bLeasherIsAv = (integer)llList2String(llParseString2List(sMessage, ["|"], [""]), 1);
                    g_bLeasherInRange = TRUE;
                    g_kParticleTarget = g_kLeashedTo;
                    StartParticles(g_kParticleTarget);
                    if (bLeasherIsAv)
                    {
                        llListenRemove(g_iLMListener);
                        llListenRemove(g_iLMListernerDetach);
                        if (llGetSubString(sMessage, 0, 10)  == "leashhandle")
                        {
                            g_iLMListener = llListen(LOCKMEISTER, "", "", (string)g_kLeashedTo + "handle ok");
                            g_iLMListernerDetach = llListen(LOCKMEISTER, "", "", (string)g_kLeashedTo + "handle detached");
                        }
                        else
                        {
                            g_iLMListener = llListen(LOCKMEISTER, "", "", "");
                        }
                        LMSay();
                    }
                }
            }
        }
        else if (iAuth >= COMMAND_OWNER && iAuth <= COMMAND_WEARER)
        {
            if (llToLower(sMessage) == llToLower(SUBMENU))
            {
                if(iAuth == COMMAND_OWNER)
                {
                    OptionsMenu(kMessageID);
                }
                else
                {
                    Notify(kMessageID, "Leash Options can only be changed by Collar Owners.", FALSE);
                }
            }
        }
        else if (iAuth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, PARENTMENU + "|" + SUBMENU, NULL_KEY);
        }
        else if (iAuth == SUBMENU_CHANNEL && sMessage == UPMENU)
        {
            llMessageLinked(LINK_SET, SUBMENU_CHANNEL, PARENTMENU , NULL_KEY);
        }
        else if (iAuth == DIALOG_RESPONSE)
        {
            if (kMessageID == g_kDialogID)
            {
                list lMenuParams = llParseString2List(sMessage, ["|"], []);
                key kAV = (key)llList2String(lMenuParams, 0);
                string sButton = llList2String(lMenuParams, 1);
                g_sMenuUser = kAV;
                if (sButton == UPMENU)
                {
                    if(g_sCurrentMenu == SUBMENU)
                    {
                        llMessageLinked(LINK_SET, SUBMENU_CHANNEL, PARENTMENU, kAV);
                    }
                    else if (g_sCurrentMenu == L_COLOR)
                    {
                        ColorCategoryMenu(kAV);
                    }
                    else
                    {
                        OptionsMenu(kAV);
                    }
                }
                else if (g_sCurrentMenu == "L-Options")
                {
                    if (sButton == L_DEFAULTS)
                    {
                        SetTexture(GetDefaultSetting(L_TEXTURE), NULLKEY);
                        g_fBurstRate = (float)GetDefaultSetting(L_DENSITY);
                        g_vLeashGravity = (vector)GetDefaultSetting(L_GRAVITY);
                        g_vLeashSize = (vector)GetDefaultSetting(L_SIZE);
                        g_vLeashColor = (vector)GetDefaultSetting(L_COLOR);
                        g_bParticleGlow = TRUE;
                        g_lSettings = g_lDefaultSettings;
                        Notify(g_sMenuUser, "Leash-settings restored to collar defaults.", FALSE);
                        // Cleo: as we use standard, no reason to keep the local settings
                        llMessageLinked(LINK_SET, LOCALSETTING_DELETE, "leash", NULL_KEY);
                        if (!g_bInvisibleLeash && g_bLeashActive)
                        {
                            StartParticles(g_kParticleTarget);
                        }
                        OptionsMenu(kAV);
                    }
                    else if (sButton == L_TEXTURE)
                    {
                        TextureMenu(kAV);
                    }
                    else if (sButton == L_COLOR)
                    {
                        ColorCategoryMenu(kAV);
                    }
                    else if (sButton == L_DENSITY)
                    {
                        DensityMenu(kAV);
                    }
                    else if (sButton == L_GRAVITY)
                    {
                        GravityMenu(kAV);
                    }
                    else if (sButton == L_SIZE)
                    {
                        SizeMenu(kAV);
                    }
                    else if (llGetSubString(sButton, 0, 3) == "Glow")
                    {
                        g_bParticleGlow = !g_bParticleGlow;
                        SaveSettings("Glow", (string)g_bParticleGlow, TRUE);
                        if (!g_bInvisibleLeash && g_bLeashActive)
                        {
                            StartParticles(g_kParticleTarget);
                        }
                        OptionsMenu(kAV);
                    }
                }
                else if (g_sCurrentMenu == "L-ColorCat")
                {
                    g_lColors = [];
                    g_sCurrentCategory = sButton;
                    g_sMenuUser = kAV;
                    string sUrl = g_sHTTPDB_Url + "static/colors-" + g_sCurrentCategory + ".txt";
                    g_kHTTPID = llHTTPRequest(sUrl, [HTTP_METHOD, "GET"], "");
                }
                else if (g_sCurrentMenu == L_COLOR)
                {
                    integer iIndex = llListFindList(g_lColors, [sButton]) +1;
                    if (iIndex)
                    {
                        g_vLeashColor = (vector)llList2String(g_lColors, iIndex);
                        SaveSettings(L_COLOR, Vec2String(g_vLeashColor), TRUE);
                    }
                    if (!g_bInvisibleLeash && g_bLeashActive)
                    {
                        StartParticles(g_kParticleTarget);
                    }
                    ColorMenu(kAV);
                }
                else if (g_sCurrentMenu == L_TEXTURE)
                {
                    g_bInvisibleLeash = FALSE;
                    if (sButton == "Default")
                    {
                        SetTexture(GetDefaultSetting(L_TEXTURE), g_sMenuUser);
                    }
                    else if (sButton == "chain")
                    {
                        SetTexture(sButton, g_sMenuUser);
                    }
                    else if(sButton == "rope")
                    {
                        SetTexture(sButton, g_sMenuUser);
                    }
                    else if (sButton == "noTexture")
                    {
                        SetTexture(sButton, g_sMenuUser);
                    }
                    else if (sButton == "noLeash")
                    {
                        SetTexture(sButton, g_sMenuUser);
                    }
                    else if(llListFindList(g_textures,[sButton]) != -1)
                    {
                        SetTexture(sButton, g_sMenuUser);
                    }
                    else
                    {
                        sButton = "leash_" + sButton;
                        if (llGetInventoryKey(sButton)) //the texture exists
                        {
                            SetTexture(sButton, g_sMenuUser);
                        }
                    }
                    SaveSettings(L_TEXTURE, g_sParticleTexture, TRUE);
                    TextureMenu(kAV);
                }
                else if (g_sCurrentMenu == L_DENSITY)
                {
                    if (sButton == "Default")
                    {
                        g_fBurstRate = (float)GetDefaultSetting(L_DENSITY);
                    }
                    else if (sButton == "+")
                    {
                        g_fBurstRate -= 0.01;
                    }
                    else if (sButton == "-")
                    {
                        g_fBurstRate += 0.01;
                    }
                    if (!g_bInvisibleLeash && g_bLeashActive)
                    {
                        StartParticles(g_kParticleTarget);
                    }
                    SaveSettings(L_DENSITY, (string)g_fBurstRate, TRUE);
                    DensityMenu(kAV);
                }
                else if (g_sCurrentMenu == L_GRAVITY)
                {
                    if (sButton == "Default")
                    {
                        g_vLeashGravity = (vector)GetDefaultSetting(L_GRAVITY);
                    }
                    else if (sButton == "+")
                    {
                        g_vLeashGravity.z -=0.1;
                    }
                    else if (sButton == "-")
                    {
                        if (g_vLeashGravity == <0.0,0.0,0.0>)
                        {
                            Notify(kAV, "You have reached already 0 leash-gravity.", FALSE);
                        }
                        else
                        {
                            g_vLeashGravity.z += 0.1;
                        }
                    }
                    else if (sButton == "noGravity")
                    {
                        g_vLeashGravity = <0.0,0.0,0.0>;
                    }
                    if (!g_bInvisibleLeash && g_bLeashActive)
                    {
                        StartParticles(g_kParticleTarget);
                    }
                    SaveSettings(L_GRAVITY, (string)g_vLeashGravity.z, TRUE);
                    GravityMenu(kAV);
                }
                else if (g_sCurrentMenu == L_SIZE)
                {
                    if (sButton == "Default")
                    {
                        g_vLeashSize = (vector)GetDefaultSetting(L_SIZE);
                    }
                    else if (sButton == "+")
                    {
                        g_vLeashSize.x +=0.03;
                        g_vLeashSize.y +=0.03;
                    }
                    else if (sButton == "-")
                    {
                        if (g_vLeashSize == <0.04,0.04,0.0>)
                        {
                            Notify(kAV, "You have reached the minimum size for particles.", FALSE);
                        }
                        else
                        {
                            g_vLeashSize.x -=0.03;
                            g_vLeashSize.y -=0.03;
                        }
                    }
                    else if (sButton == "minimum")
                    {
                        g_vLeashSize = <0.04,0.04,0.0>;
                    }
                    if (!g_bInvisibleLeash && g_bLeashActive)
                    {
                        StartParticles(g_kParticleTarget);
                    }
                    SaveSettings(L_SIZE, (string)g_vLeashSize.x, TRUE);
                    SizeMenu(kAV);
                }
            }
        }
        else if (iAuth == LOCALSETTING_RESPONSE)
        {
            //debug("LocalSettingsResponse: " + sMessage);
            integer iIndex = llSubStringIndex(sMessage, "=");
            string sToken = llGetSubString(sMessage, 0, iIndex -1);
            string sValue = llGetSubString(sMessage, iIndex + 1, -1);
            if (llGetSubString(sToken, 0, 4) == "leash")
            {
                debug(sMessage);
                list lRecievedSettings = llParseString2List(sValue, [","],[]);
                iIndex = llListFindList(lRecievedSettings, [L_TEXTURE]) + 1;
                if (iIndex)
                {
                    string sTemp = llList2String(lRecievedSettings, iIndex);
                    SetTexture(sTemp, NULLKEY);
                    SaveSettings(L_TEXTURE, g_sParticleTexture, FALSE);
                }
                iIndex = llListFindList(lRecievedSettings, [L_DENSITY]) + 1;
                if (iIndex)
                {
                    g_fBurstRate = (float)llList2String(lRecievedSettings, iIndex);
                    SaveSettings(L_DENSITY, (string)g_fBurstRate, FALSE);
                }
                iIndex = llListFindList(lRecievedSettings, [L_GRAVITY]) + 1;
                if (iIndex)
                {
                    g_vLeashGravity.z = (float)llList2String(lRecievedSettings, iIndex);
                    SaveSettings(L_GRAVITY, (string)g_vLeashGravity.z, FALSE);
                }
                iIndex = llListFindList(lRecievedSettings, [L_SIZE]) + 1;
                if (iIndex)
                {
                    g_vLeashSize.x = (float)llList2String(lRecievedSettings, iIndex);
                    g_vLeashSize.y = (float)llList2String(lRecievedSettings, iIndex);
                    SaveSettings(L_SIZE, (string)g_vLeashSize.x, FALSE);
                }
                iIndex = llListFindList(lRecievedSettings, [L_COLOR]) + 1;
                if (iIndex)
                {
                    g_vLeashColor = (vector)llList2CSV(llList2List(lRecievedSettings, iIndex, iIndex + 2));
                    SaveSettings(L_COLOR, Vec2String(g_vLeashColor), FALSE);
                }
            }
        }
        // All default settings from the settings notecard are sent over "HTTPDB_RESPONSE" channel
        else if (iAuth == HTTPDB_RESPONSE)
        {
            //debug("HTTPDBResponse: " + sMessage);
            integer iIndex = llSubStringIndex(sMessage, "=");
            string sToken = llGetSubString(sMessage, 0, iIndex -1);
            string sValue = llGetSubString(sMessage, iIndex + 1, -1);

            if (llGetSubString(sToken, 0, 4) == "leash")
            {
                sToken = llGetSubString(sToken, 5, -1);
                if (sToken == L_TEXTURE)
                {
                    SetTexture(sValue, NULLKEY);
                    SaveDefaultSettings(sToken, sValue);
                }
                else if (sToken == L_DENSITY)
                {
                    g_fBurstRate = (float)sValue;
                    SaveDefaultSettings(sToken, sValue);
                }
                else if (sToken == L_GRAVITY)
                {
                    g_vLeashGravity.z = -(float)sValue;
                    SaveDefaultSettings(sToken, Vec2String(g_vLeashGravity));
                }
                else if (sToken == L_SIZE)
                {
                    g_vLeashSize.x = (float)sValue;
                    g_vLeashSize.y = (float)sValue;
                    SaveDefaultSettings(sToken, Vec2String(g_vLeashSize));
                }
                else if (sToken == L_COLOR)
                {
                    g_vLeashColor = (vector)sValue;
                    SaveDefaultSettings(sToken, Vec2String(g_vLeashColor));
                }
                else if (sToken == "Glow")
                {
                    if (llToLower(sValue) == "off")
                    {
                        g_bParticleGlow = FALSE;
                    }
                    else
                    {
                        g_bParticleGlow = TRUE;
                    }
                    SaveDefaultSettings(sToken, (string)g_bParticleGlow);
                }
                // in case wearer is currently leashed
                if (g_kLeashedTo != NULLKEY)
                {
                    StartParticles(g_kParticleTarget);
                }
            }
        }
        else if (iAuth == HTTPDB_EMPTY)
        {
            //debug("HTTPDB EMPTY");
            if (sMessage == ("leash" + L_TEXTURE)) // no designer-set texture
            {
                SetTexture("chain", NULLKEY);
                if (g_kLeashedTo != NULLKEY)
                {
                    StartParticles(g_kParticleTarget);
                }
            }
        }
    }
    listen(integer iChannel, string sName, key kID, string sMessage)
    {
        if (iChannel == LOCKMEISTER)
        {
            //leash holder announced it got detached... send particles to avi
            if (sMessage == (string)g_kLeashedTo + "handle detached")
            {
                g_kParticleTarget = g_kLeashedTo;
                StartParticles(g_kParticleTarget);
            }
            // We heard from a leash holder. re-direct particles
            if (llGetOwnerKey(kID) == g_kLeashedTo)
            {
                sMessage = llGetSubString(sMessage, 36, -1);
                if (sMessage == "collar ok")
                {
                    g_kParticleTarget = kID;
                    StartParticles(g_kParticleTarget);
                }
                if (sMessage == "handle ok")
                {
                    g_kParticleTarget = kID;
                    StartParticles(g_kParticleTarget);
                }
            }
        }
    }

    timer()
    {
        if (isInSimOrJustOutside(llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0)) && llVecDist(llGetPos(), llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0))<60)
        {
            if(!g_bLeasherInRange)
            {
                llMessageLinked(LINK_THIS, COMMAND_LEASH_SENSOR, "Leasher in range", NULLKEY);
                LMSay();
                if (g_iAwayCounter)
                {
                    g_iAwayCounter = 0;
                    llSetTimerEvent(3.0);
                }
                StartParticles(g_kParticleTarget);
                g_bLeasherInRange = TRUE;
                //hate this sleep but somehow sometimes this message seems to get lost...
                llSleep(1.5);
                llMessageLinked(LINK_THIS, COMMAND_LEASH_SENSOR, "Leasher in range", NULLKEY);
                LMSay();
            }
            //actually not needed when using the new leash holder but to be sure not to dangle the leash but releash to avi
            if(llKey2Name(g_kParticleTarget) == "")
            {
                g_kParticleTarget = g_kLeashedTo;
                StartParticles(g_kParticleTarget);
                LMSay();
            }
        }
        else
        {
            if(g_bLeasherInRange)
            {
                StopParticles(FALSE);
                llMessageLinked(LINK_THIS, COMMAND_LEASH_SENSOR, "Leasher out of range", NULLKEY);
                if (g_iAwayCounter > 3)
                {
                    g_bLeasherInRange = FALSE;
                }
            }
            g_iAwayCounter++; //+1 every 3 secs
            if (g_iAwayCounter > 200) //10 mins
            {//slow down the sensor:
                g_iAwayCounter = 1;
                llSetTimerEvent(11.0);
            }
        }
    }

    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        if (kID == g_kHTTPID)
        {
            if (iStatus == 200)
            {
                //we'll have gotten several g_iLines like "Chartreuse|<0.54118, 0.98431, 0.09020>"
                //parse that into 2-strided list of g_lColorsName, colorvector
                g_lColors = llParseString2List(sBody, ["\n", "|"], []);
                g_lColors = llListSort(g_lColors, 2, TRUE);
                ColorMenu(g_sMenuUser);
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
    
    changed(integer change)
    {
        if(change & CHANGED_INVENTORY)
        {
            loadNoteCards("");
        }
    }
    
}