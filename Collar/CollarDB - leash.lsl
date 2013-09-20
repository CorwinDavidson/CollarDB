//CollarDB - leash - 3.531
//leash script for the Open Collar Project (c)
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.

// ------ TOKEN DEFINITIONS ------
// ---- Immutable ----
// - Should be constant across collars, so not prefixed
// --- db tokens ---
string TOK_LENGTH   = "leashlength";
string TOK_ROT = "leashrot";
string TOK_DEST     = "leashedto"; // format: uuid,rank
// --- channel tokens ---
//      MESSAGE MAP
integer COMMAND_NOAUTH          = 0xCDB000;
integer COMMAND_OWNER           = 0xCDB500;
integer COMMAND_SECOWNER        = 0xCDB501;
integer COMMAND_GROUP           = 0xCDB502;
integer COMMAND_WEARER          = 0xCDB503;
integer COMMAND_EVERYONE        = 0xCDB504;
integer COMMAND_SAFEWORD        = 0xCDB510;

integer POPUP_HELP              = -0xCDB001;      

integer HTTPDB_SAVE             = 0xCDB200;     // scripts send messages on this channel to have settings saved to httpdb
                                                // str must be in form of "token=value"
integer HTTPDB_REQUEST          = 0xCDB201;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 0xCDB202;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 0xCDB203;     // delete token from DB
integer HTTPDB_EMPTY            = 0xCDB204;     // sent by httpdb script when a token has no value in the db

integer LOCALSETTING_SAVE       = 0xCDB250;
integer LOCALSETTING_REQUEST    = 0xCDB251;
integer LOCALSETTING_RESPONSE   = 0xCDB252;
integer LOCALSETTING_DELETE     = 0xCDB253;
integer LOCALSETTING_EMPTY      = 0xCDB254;

integer MENUNAME_REQUEST        = 0xCDB300;
integer MENUNAME_RESPONSE       = 0xCDB301;
integer MENUNAME_SUBMENU        = 0xCDB302;
integer MENUNAME_REMOVE         = 0xCDB303;

integer RLV_CMD                 = 0xCDB600;

integer DIALOG                  = -0xCDB900;
integer DIALOG_RESPONSE         = -0xCDB901;
integer DIALOG_TIMEOUT          = -0xCDB902;


integer LOCKMEISTER         = -8888;

integer COMMAND_PARTICLE = 20000;
integer COMMAND_LEASH_SENSOR = 20001;

// --- menu tokens ---
string UPMENU       = "^";
string MORE         = ">";
string PARENTMENU   = "Main";
string SUBMENU      = "Leash";
string LEASH        = "Grab";
string LEASH_TO     = "LeashTo";
string FOLLOW       = "Follow Me";
string FOLLOW_MENU  = "FollowTarget";
string UNLEASH      = "Unleash";
string UNFOLLOW     = "Unfollow";
string STAY         = "Stay";
string UNSTAY       = "UnStay";
string ROT         = "Rotate";
string UNROT       = "Don't Rotate";
string L_LENGTH     = "Length";
string GIVE_HOLDER  = "Give Holder";
string GIVE_POST    = "Give Post";
string REZ_POST     = "Rez Post";
string L_POST       = "Post";
string L_YANK       = "Yank";
string L_BECKON       = "Beckon";

// --- tokens for g_iSensorMode ---
// - to remember what the sensor is tracking
// sensors for chat
integer SENSORMODE_FIND_TARGET_FOR_LEASH_CHAT   = 1;
integer SENSORMODE_FIND_TARGET_FOR_FOLLOW_CHAT  = 2;
integer SENSORMODE_FIND_TARGET_FOR_POST_CHAT    = 3;
// sensors for menus
integer SENSORMODE_FIND_TARGET_FOR_LEASH_MENU   = 100;
integer SENSORMODE_FIND_TARGET_FOR_FOLLOW_MENU  = 101;
integer SENSORMODE_FIND_TARGET_FOR_POST_MENU    = 102;

// key NULLKEY = NULL_KEY; - Starship, this actually takes away from mem by adding a global for a pre-defined value
// ---------------------------------------------
// ------ VARIABLE DEFINITIONS ------
// ----- menu -----
//integer g_iListen;
string g_sCurrentMenu = "";
//string g_sPostPrompt;
string g_sMenuUser;
key g_kDialogID;
list g_lButtons = [L_LENGTH, LEASH_TO, FOLLOW_MENU, GIVE_HOLDER, L_POST, REZ_POST, GIVE_POST];
list g_oButtons = [LEASH, FOLLOW, L_YANK];

//list g_lPostButtons;
list g_lPostKeys;

// ----- collar -----
//string g_sMyID;
string g_sWearer;
key g_kWearer;
integer g_iJustMoved;
// ----- leash -----
float g_fLength = 3.0;
float g_fScanRange = 10.0;
integer g_iStay = FALSE;
integer g_iRot = TRUE;
integer g_iTargetHandle;
integer g_iLastRank;
integer g_iStayRank;
vector g_vPos = ZERO_VECTOR;
string g_sSensorMode;
string g_sTmpName;
key g_kCmdGiver;
//key g_kLeashHolder;
key g_kLeashedTo = NULL_KEY;
integer g_bLeashedToAvi;
integer g_bFollowMode = FALSE;

integer g_iReturnMenu = TRUE;
integer g_iSensorMode = 0;
key g_kMenuUser;

list g_lLeashers;
list g_lLengths = ["1", "2", "3", "4", "5", "8","10" , "15", "20", "25", "30"];

// ------ FUNCTION DEFINITIONS ------
// Debug Messages - commenting all debug out saves over 3K mem on this script
debug(string sStr)
{
    //llOwnerSay(llGetScriptName() + ": " + sStr);
}

integer g_iUnixTime;

// RLV-Force avatar to face the leasher by Tapple Gao
turnToTarget(vector target)
{
    if (g_iRot)
    {
        // do not need this as we are only doint at target
        //float MAX_TURN_ANGLE = 70 * DEG_TO_RAD;
        vector pointTo = target - llGetPos();
        //vector myEuler = llRot2Euler(llGetRot());
        //float  myAngle = PI_BY_TWO - myEuler.z;
        float  turnAngle = llAtan2(pointTo.x, pointTo.y);// - myAngle;
        //while (turnAngle < -PI) turnAngle += TWO_PI;
        //while (turnAngle >  PI) turnAngle -= TWO_PI;
        //if (turnAngle < -MAX_TURN_ANGLE) turnAngle = -MAX_TURN_ANGLE;
        //if (turnAngle >  MAX_TURN_ANGLE) turnAngle =  MAX_TURN_ANGLE;
        llMessageLinked(LINK_SET, RLV_CMD, "setrot:" + (string)(turnAngle) + "=force", NULL_KEY);
    }
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    //debug("dialog:"+(string)llGetFreeMemory( ));
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

integer CheckCommandAuth(key kCmdGiver, integer iAuth)
{
    // Check for invalid auth
    if (iAuth < COMMAND_OWNER && iAuth > COMMAND_WEARER)
        return FALSE;
    
    // If leashed, only move leash if Comm Giver outranks current leasher
    if (g_kLeashedTo != NULL_KEY && iAuth > g_iLastRank)
    {
        string sFirstName = GetFirstName(g_sWearer);
        Notify(kCmdGiver, "Sorry, someone who outranks you on " + g_sWearer +"'s collar leashed " + sFirstName + " already.", FALSE);

        return FALSE;
    }

    return TRUE;
}

LeashMenu(key kIn)
{
    g_sCurrentMenu = "leash";
    g_iReturnMenu = FALSE;

    list lButtons = [];
    if (kIn != g_kWearer)
    {    
        lButtons += g_oButtons; // Only if not the wearer.
        if (g_kLeashedTo != NULL_KEY)
            lButtons += [L_YANK];
        else
            lButtons += [L_BECKON];
    }
        
    lButtons += g_lButtons;
    
    if (g_kLeashedTo != NULL_KEY)
    {
        if (g_bFollowMode)
            lButtons += [UNFOLLOW];
        else
            lButtons += [UNLEASH];
    }
    
    if (g_iStay)
        lButtons += [UNSTAY];
    else
        lButtons += [STAY];

    if (kIn == g_kWearer) // Only for wearer.
    {
        if (g_iRot)
            lButtons += [UNROT];
        else
            lButtons += [ROT];
    }    

    string sPrompt = "Leash Options";
    g_kDialogID = Dialog(kIn, sPrompt, lButtons, [UPMENU], 0);
}

LengthMenu(key kIn)
{
    g_sCurrentMenu = "length";
    string sPrompt = "Set a leash length in meter:\nCurrent length is: " + (string)g_fLength + "m";
    g_kDialogID = Dialog(kIn, sPrompt, g_lLengths, [UPMENU], 0);
}


SetLength(float fIn)
{
    g_fLength = fIn;
    // llTarget needs to be changed to the new length if leashed
    if(g_kLeashedTo != NULL_KEY)
    {
        llTargetRemove(g_iTargetHandle);
        g_iTargetHandle = llTarget(g_vPos, g_fLength);
    }
}

// Wrapper to send notices to wearer, leasher, and target
// Only sends notices if Leasher is an AV, as objects normally handle their own messages for such things
SayLeashed(key kTarget,key kCmdGiver, integer iAuth)
{
    if (!KeyIsAv(g_kCmdGiver)) return; // failsafe
    string sTarget = llKey2Name(kTarget);
    string sWearMess;
    if (kCmdGiver == g_kWearer) // Wearer is Leasher
    {
        //sCmdMess = ""; // Only one message will need to be sent
        sWearMess = "You take your leash";
        if (kTarget == g_kWearer) // self bondage - shouldn't ever happen, but just in case
        {
            //sWearMess += ""; // We could put in some sort of self-deprecating humor here ;)
        }
        else if (KeyIsAv(kTarget)) // leashing self to someone else
        {
            sWearMess += ", and hand it to " + sTarget;
        }
        else // leashing self to an object
        {
            sWearMess += ", and tie it to " + sTarget;
        }
    }
    else // Leasher is not Wearer
    {
        string sPsv = "'s"; // Possessive, will vary if name ends in "s"
        if (endswith(g_sWearer, "s")) sPsv = "'";
        string sCmdMess= "You grab " + g_sWearer + sPsv + " leash";
        sWearMess = llKey2Name(kCmdGiver) + " grabs your leash";
        if (kCmdGiver != kTarget) // Leasher is not LeashTo
        {
            if (kTarget == g_kWearer) // LeashTo is Wearer
            {
                sCmdMess += ", and hand it to " + GetFirstName(g_sWearer);
                sWearMess += ", and hands it to you";
            }
            else if (KeyIsAv(kTarget)) // LeashTo someone else
            {
                sCmdMess += ", and hand it to " + sTarget;
                sWearMess += ", and hands it to " + sTarget;
                Notify(kTarget, llKey2Name(kCmdGiver) + " hands you " + g_sWearer + sPsv + " leash", FALSE);
            }
            else // LeashTo object
            {
                sCmdMess += ", and tie it to " + sTarget;
                sWearMess += ", and ties it to " + sTarget;
            }
        }
        Notify(kCmdGiver, sCmdMess, FALSE);
    }
    Notify(g_kWearer, sWearMess, FALSE);
}

SayUnleash(key kTarget, key kCmdGiver, integer iAuth)
{
    string sTarget = llKey2Name(g_kLeashedTo);
    string sCmdGiver = llKey2Name(kCmdGiver);
    string sWearMess;
    string sCmdMess;
    string sTargetMess;
    
    if (!KeyIsAv(kTarget))
        return;
        
    if (kTarget == kCmdGiver) // Wearer is Leasher
    {
        sWearMess = "You unleash yourself from " + sTarget + "."; // sTarget might be an object
        sTargetMess = GetFirstName(g_sWearer) + " unleashes from you.";
        if (KeyIsAv(g_kLeashedTo))
            Notify(g_kLeashedTo, sTargetMess, FALSE);
    }
    else // Unleasher is not Wearer
    {
        if (kTarget == g_kLeashedTo)
        {
            sCmdMess= "You unleash  " + g_sWearer + ".";
            sWearMess = sCmdGiver + " unleashes you.";
        }
        else
        {
            sCmdMess= "You unleash  " + GetFirstName(g_sWearer) + " from " + sTarget + ".";
            sWearMess = sCmdGiver + " unleashes you from " + sTarget + ".";
            sTargetMess = sCmdGiver + " unleashes " + GetFirstName(g_sWearer) + " from you.";
            if (KeyIsAv(g_kLeashedTo))
                Notify(g_kLeashedTo, sTargetMess, FALSE);
        }
        Notify(kTarget, sCmdMess, FALSE);
    }
    Notify(g_kWearer, sWearMess, FALSE);
}

SayFollow(key kTarget, key kCmdGiver, integer iAuth)
{
    // TODO: why this??  It seems to have something to do with getting commands from objects.
    if (kTarget == kCmdGiver && llGetOwnerKey(kCmdGiver) == g_kWearer) 
        return;

    // Send notices to wearer, leasher, and target
    // Only send notices if Leasher is an AV, as objects normally handle their own messages for such things
    if (KeyIsAv(kCmdGiver)) 
    {
        string sTarget = llKey2Name(kTarget);
        string sWearMess;
        if (kCmdGiver == g_kWearer) // Wearer is Leasher
        {
            //sCmdMess = ""; // Only one message will need to be sent
            sWearMess = "You begin following " + sTarget + ".";
        }
        else // Leasher is not Wearer
        {
            string sCmdMess= "You command " + g_sWearer + " to follow " + sTarget + ".";
            sWearMess = llKey2Name(kCmdGiver) + " commands you to follow " + sTarget + ".";
            if (KeyIsAv(kTarget)) // LeashTo someone else
                Notify(kTarget, llKey2Name(kCmdGiver) + " commands " + g_sWearer + " to follow you.", FALSE);
            
            Notify(kCmdGiver, sCmdMess, FALSE);
        }
        Notify(g_kWearer, sWearMess, FALSE);
    }
}

SayUnfollow(key kTarget, key kCmdGiver, integer iAuth)
{
    string sTarget = llKey2Name(g_kLeashedTo);
    string sCmdGiver = llKey2Name(kTarget);
    string sWearMess;
    string sCmdMess;
    string sTargetMess;
    
    if (!KeyIsAv(kTarget))
        return;

    if (kTarget == g_kWearer) // Wearer is Leasher
    {
        sWearMess = "You stop following " + sTarget + ".";
        sTargetMess = GetFirstName(g_sWearer) + " stops following you.";
        if (KeyIsAv(g_kLeashedTo))
            Notify(g_kLeashedTo, sTargetMess, FALSE);
    }
    else // Unleasher is not Wearer
    {
        if (kCmdGiver == g_kLeashedTo)
        {
            sCmdMess= "You release " + GetFirstName(g_sWearer) + " from following you.";
            sWearMess = sCmdGiver + " releases you from following.";
        }
        else
        {
            sCmdMess= "You release " + GetFirstName(g_sWearer) + " from following " + sTarget + ".";
            sWearMess = sCmdGiver + " releases you from following " + sTarget + ".";
            sTargetMess = g_sWearer + " stops following you.";
            if (KeyIsAv(g_kLeashedTo))
                Notify(g_kLeashedTo, sTargetMess, FALSE);
        }
        Notify(kTarget, sCmdMess, FALSE);
    }
    Notify(g_kWearer, sWearMess, FALSE);
}

// Wrapper for DoLeash, so that on restoring leash from localsettings we can call DoLeash and not redundantly save the settings again.
LeashTo(key kTarget, key kCmdGiver, integer iRank, list lPoints)
{
    // can't leash wearer to self.
    if (kTarget == g_kWearer)
        return;
    
    if (g_bFollowMode)
        SayFollow(kTarget, kCmdGiver, iRank);
    else
        SayLeashed(kTarget, kCmdGiver, iRank);
    
    if (!g_bLeashedToAvi)
    {
        if (KeyIsAv(kTarget))
        {
            g_bLeashedToAvi = TRUE;
        }
    }
    llMessageLinked(LINK_SET, LOCALSETTING_SAVE, TOK_DEST + "=" + (string)kTarget + "," + (string)iRank + "," + (string)g_bLeashedToAvi + "," + (string)g_bFollowMode, NULL_KEY);
    DoLeash(kTarget, iRank, lPoints);
    
    // Notify Target how to unleash, only if:
    // Avatar
    // Didn't send the command
    // Don't own the object that sent the command
    if (KeyIsAv(kTarget) && kCmdGiver != kTarget && llGetOwnerKey(kCmdGiver) != kTarget)
    {
        if (g_bFollowMode)
            FollowHelp(g_kLeashedTo);
        else
            LeashToHelp(g_kLeashedTo);
    }    
}

DoLeash(key kTarget, integer iRank, list lPoints)
{
    g_iLastRank = iRank;
    g_kLeashedTo = kTarget;
    
    if (g_bFollowMode)
    {
        llMessageLinked(LINK_THIS, COMMAND_PARTICLE, "unleash", g_kLeashedTo);
    }
    else
    {
        integer iPointCount = llGetListLength(lPoints);
        string sCheck = "";  
        if (iPointCount)
        {//if more than one leashpoint, listen for all strings, else listen just for that point
            if (iPointCount == 1) sCheck = (string)llGetOwnerKey(kTarget) + llList2String(lPoints, 0) + " ok";
        }
        //Send link message to the particle script 
        llMessageLinked(LINK_THIS, COMMAND_PARTICLE, "leash" + sCheck + "|" + (string)g_bLeashedToAvi, g_kLeashedTo);
    }

    // change to llTarget events by Lulu Pink 
    g_vPos = llList2Vector(llGetObjectDetails(g_kLeashedTo, [OBJECT_POS]), 0);
    //to prevent multiple target events and llMoveToTargets
    llTargetRemove(g_iTargetHandle);
    llStopMoveToTarget();
    g_iTargetHandle = llTarget(g_vPos, g_fLength);
    if (g_vPos != ZERO_VECTOR)
    {
        //turnToTarget(g_vPos);// only at target
        llMoveToTarget(g_vPos, 0.7);
    }
    g_iUnixTime = llGetUnixTime();
}

// sets up a sensor callback which locates potential targets to display menu for leash / follow / post
DisplayTargetMenu(key kCmdGiver, integer iAuth, integer iSensorMode, string sChattedTarget)
{
    if (iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_CHAT)
    {
        if (llStringLength(sChattedTarget) == 0)
            return;
    }
    g_iSensorMode = iSensorMode;
    g_kMenuUser = kCmdGiver;
    g_iLastRank = iAuth;
    if ((iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_MENU) || (iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_CHAT))
        llSensor("", NULL_KEY, PASSIVE | ACTIVE, g_fScanRange, PI);
    else
        llSensor("", "", AGENT, g_fScanRange, PI);
}

StayPut(key kIn, integer iRank)
{
    g_iStayRank = iRank;
    g_iStay = TRUE;
    llRequestPermissions(g_kWearer, PERMISSION_TAKE_CONTROLS);
    llOwnerSay(llKey2Name(kIn) + " commanded you to stay in place, you cannot move until the command is revoked again.");
    Notify(kIn, "You commanded " + g_sWearer + " to stay in place. Either leash the slave with the grab command or use \"unstay\" to enable movement again.", FALSE);
}

CleanUp()
{
    llTargetRemove(g_iTargetHandle);
    llStopMoveToTarget();
}

Unleash(key kCmdGiver)
{
    if (g_bFollowMode)
    {
        g_bFollowMode = FALSE;
        SayUnfollow(g_kLeashedTo,kCmdGiver,0);
    }
    else
        SayUnleash(g_kLeashedTo,kCmdGiver,0);
    
    CleanUp();
    llMessageLinked(LINK_THIS, COMMAND_PARTICLE, "unleash", g_kLeashedTo);
    g_kLeashedTo = NULL_KEY;
    g_iLastRank = COMMAND_EVERYONE;
    llMessageLinked(LINK_SET, LOCALSETTING_DELETE, TOK_DEST, "");
}

integer KeyIsAv(key id)
{
    return llGetAgentSize(id) != ZERO_VECTOR;
}
// Returns sName's first name
string GetFirstName(string sName)
{
    return llGetSubString(sName, 0, llSubStringIndex(sName, " ") - 1);
}

integer startswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, llStringLength(needle), -1) == needle;
}

integer endswith(string haystack, string needle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return llDeleteSubString(haystack, 0, ~llStringLength(needle)) == needle;
}

LeashToHelp(key kIn)
{
    llMessageLinked(LINK_SET, POPUP_HELP, g_sWearer + " has been leashed to you.  Say \"_PREFIX_unleash\" to unleash them.  Say \"_PREFIX_giveholder\" to get a leash holder.", kIn);
}

FollowHelp(key kIn)
{
    llMessageLinked(LINK_SET, POPUP_HELP, g_sWearer + " has been commanded to follow you.  Say \"_PREFIX_unfollow\" to relase them.", kIn);
}

YankTo(key kIn)
{
    llMoveToTarget(llList2Vector(llGetObjectDetails(kIn, [OBJECT_POS]), 0), 0.5);
    llSleep(2.0);
    llStopMoveToTarget();    
}

// ---------------------------------------------
// ------ IMPLEMENTATION ------
default
{
    state_entry()
    {
        //debug("statentry:"+(string)llGetFreeMemory( ));
        g_kWearer = llGetOwner();
        g_sWearer = llKey2Name(g_kWearer);
        llMinEventDelay(0.3);
        //g_sMyID =  llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
        Unleash(g_kWearer);
        //llOwnerSay("stateentryend:"+(string)llGetFreeMemory());
    }
    
    on_rez(integer start_param)
    {
        llResetScript();
    }
    
    link_message(integer iPrim, integer iAuth, string sMessage, key kMessageID)
    {
        list lParam = [];
        list lPoints = [];
        string sMesL = llToLower(sMessage);

        if (iAuth >= COMMAND_OWNER && iAuth <= COMMAND_WEARER)
        {
            g_kCmdGiver = kMessageID;
            lParam = llParseString2List(sMessage, [" "], []);
            string sComm = llToLower(llList2String(lParam, 0));
            if (sMesL == "grab" || sMesL == "leash" || (sMesL == "toggleleash" && NULL_KEY == g_kLeashedTo))
            {
                if (CheckCommandAuth(kMessageID, iAuth)) LeashTo(kMessageID, kMessageID, iAuth, ["handle"]);
            }
            else if(sComm == "follow")
            {
                if (CheckCommandAuth(kMessageID, iAuth))
                {
                    string sChattedTarget = llList2String(lParam, 1);
                    if (sMesL == sComm) // no parameters were passed
                    {
//                        SayFollow(kMessageID, kMessageID, iAuth);
                        g_bFollowMode = TRUE;
                        LeashTo(kMessageID, kMessageID, iAuth, ["handle"]);
                    }       
                    else if ((key)sChattedTarget)
                    {
//                        SayFollow((key)sChattedTarget, kMessageID, iAuth);
                        g_bFollowMode = TRUE;
                        LeashTo(kMessageID, kMessageID, iAuth, ["handle"]);
                    } 
                    else
                    {
                        g_iReturnMenu = FALSE;
                        DisplayTargetMenu(kMessageID, iAuth, SENSORMODE_FIND_TARGET_FOR_FOLLOW_CHAT, sChattedTarget);
                    }
                }
                if (!g_iReturnMenu) return;
            }
            else if (sMesL == "unleash" || sMesL == "unfollow" || (sMesL == "toggleleash" && NULL_KEY != g_kLeashedTo))
            {
                if (CheckCommandAuth(kMessageID, iAuth)) 
                        Unleash(kMessageID);
            }
            else if (sMesL == "giveholder")
            {
                llGiveInventory(kMessageID, "DB Leash Holder");
            }
            else if (sMesL == "givepost")
            {
                llGiveInventory(kMessageID, "DB_Leash_Post");
            }
            else if (sMesL == "rezpost")
            {
                llRezObject("DB_Leash_Post", llGetPos() + (<1.0, 0, -0.3> * llGetRot()), ZERO_VECTOR, llEuler2Rot(<0, 90, 0> * DEG_TO_RAD), 0);
            }
            else if (sMesL == "yank" && kMessageID == g_kLeashedTo)
            {
                //Person holding the leash can yank.
                YankTo(kMessageID);
            }
            else if (sMesL == "beckon" && iAuth == COMMAND_OWNER)
            {
                //Owner can beckon
                YankTo(kMessageID);
            }
            else if (sMesL == "stay")
            {
                if (iAuth <= COMMAND_GROUP)
                {
                    StayPut(kMessageID, iAuth);
                }
            }
            else if ((sMesL == "unstay" || sMesL == "move") && g_iStay)
            {
                if (iAuth <= g_iStayRank)
                {
                    g_iStay = FALSE;
                    llReleaseControls();
                    llOwnerSay("You are free to move again.");
                    Notify(kMessageID,"You allowed " + g_sWearer + " to move freely again.", FALSE);
                }
            }
            else if(sMesL == "don't rotate" && g_iRot)
            {
                if (g_kWearer == kMessageID)
                {
                    g_iRot = FALSE;
                    llMessageLinked(LINK_SET, LOCALSETTING_SAVE, TOK_ROT + "=0", "");
                }
                else
                {
                    Notify(kMessageID,"Only the wearer can change the rotate setting", FALSE);
                }
            }
            else if(sMesL == "rotate" && !g_iRot)
            {
                if (g_kWearer == kMessageID)
                {
                    g_iRot = TRUE;
                    llMessageLinked(LINK_SET, LOCALSETTING_DELETE, TOK_ROT, "");
                }
                else
                {
                    Notify(kMessageID,"Only the wearer can change the rotate setting", FALSE);
                }
            }
            else jump othermenu;
            if (g_iReturnMenu) 
                LeashMenu(kMessageID);
            return ;
            @othermenu;
            if(sMesL == "leashmenu" || sMessage == "menu " + SUBMENU)
            {

                if (CheckCommandAuth(kMessageID, iAuth)) 
                    LeashMenu(kMessageID);
                else if (sMesL == "menu " + SUBMENU) 
                {
                    llMessageLinked(LINK_SET, iAuth, "menu " + PARENTMENU, kMessageID); 
                    return;
                }
            }            
            else if(sComm == "leashto")
            {
                if (!CheckCommandAuth(kMessageID, iAuth)) 
                    return;
                
                string sChattedTarget = llList2String(lParam, 1);
                
                if (sMesL == sComm) // no parameters were passed
                {
                    DisplayTargetMenu(kMessageID, iAuth, SENSORMODE_FIND_TARGET_FOR_LEASH_MENU,"");
                }       
                else if((key)sChattedTarget)
                {
                    if (llGetListLength(lParam) > 2) 
                        lPoints = llList2List(lParam, 2, -1);
                    LeashTo((key)sChattedTarget, kMessageID, iAuth, lPoints);
                }
                else
                {
                    DisplayTargetMenu(kMessageID, iAuth, SENSORMODE_FIND_TARGET_FOR_LEASH_CHAT, sChattedTarget);
                }                
                if (!g_iReturnMenu) return;
            }
            else if(sComm == "followtarget")
            {
                if (!CheckCommandAuth(kMessageID, iAuth)) 
                    return;
                    
                DisplayTargetMenu(kMessageID, iAuth, SENSORMODE_FIND_TARGET_FOR_FOLLOW_MENU,"");
                if (!g_iReturnMenu) return;
            }
            else if (sComm == "length")
            {
                float fNewLength = (float)llList2String(lParam, 1);
                if(fNewLength > 0.0)
                {
                    if (kMessageID == g_kLeashedTo || CheckCommandAuth(kMessageID, iAuth)) 
                    {
                        SetLength(fNewLength);
                        //tell wearer  
                        Notify(kMessageID, "Leash length set to " + (string)fNewLength, TRUE);        
                        llMessageLinked(LINK_SET, LOCALSETTING_SAVE, TOK_LENGTH + "=" + (string)fNewLength, "");
                    }
                }
                else Notify(kMessageID, "The current leash length is " + (string)g_fLength + "m.", TRUE);
            }
            else if (sComm == "post")
            {
                string sChattedTarget = llList2String(lParam, 1);
                if (!CheckCommandAuth(kMessageID, iAuth)) return;

                else if (sMesL == sComm) // no parameters were passed
                {
                    DisplayTargetMenu(kMessageID, iAuth, SENSORMODE_FIND_TARGET_FOR_POST_MENU, "");
                }       
                else if((key)sChattedTarget)
                {
                    list lPoints;
                    if (llGetListLength(lParam) > 2) lPoints = llList2List(lParam, 2, -1);
                    //debug("leash target is key");//could be a post, or could be we specified an av key
                    LeashTo((key)sChattedTarget, kMessageID, iAuth, lPoints);
                }
                else
                {
                    DisplayTargetMenu(kMessageID, iAuth, SENSORMODE_FIND_TARGET_FOR_POST_CHAT, sChattedTarget);
                }
                if (!g_iReturnMenu) return;
            }
            return;
        }
        else if (iAuth == COMMAND_LEASH_SENSOR)
        {
            if (sMessage == "Leasher out of range")
            {// particle script sensor lost the leasher... stop to follow
                CleanUp();
            }
            else if (sMessage == "Leasher in range")
            {// particle script sensor found the leasher again, restart to follow
                llTargetRemove(g_iTargetHandle);
                g_vPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
                g_iTargetHandle = llTarget(g_vPos, g_fLength);
            }
            return;
        }
        else if (iAuth == COMMAND_EVERYONE)
        {
            if (kMessageID == g_kLeashedTo)
            {
                if (sMesL == "unleash" || sMesL == "unfollow" || (sMesL == "toggleleash" && NULL_KEY != g_kLeashedTo))
                {
                    Unleash(kMessageID);
                }
                else if (sMesL == "giveholder")
                {
                    llGiveInventory(kMessageID, "DB Leash Holder");
                }
                else if (sMesL == "yank")
                {
                    YankTo(kMessageID);
                }
            }
            return;
        }        
        else if (iAuth == MENUNAME_REQUEST)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, PARENTMENU + "|" + SUBMENU, NULL_KEY);
        }
        else if (iAuth == MENUNAME_SUBMENU && sMessage == UPMENU)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, PARENTMENU + "|" + SUBMENU, NULL_KEY);
        }
        else if (iAuth == MENUNAME_SUBMENU && sMessage == SUBMENU)
        {
            LeashMenu(kMessageID);
        }
        else if (iAuth == MENUNAME_RESPONSE)
        {
            list lParts = llParseString2List(sMessage, ["|"], []);
            if (llList2String(lParts, 0) == SUBMENU)
            {//someone wants to stick something in our menu
                string button = llList2String(lParts, 1);
                if (llListFindList(g_lButtons, [button]) == -1)
                {
                    g_lButtons = llListSort(g_lButtons + [button], 1, TRUE);
                }
            }
        }
        else if (iAuth == COMMAND_SAFEWORD)
        {
            if(g_iStay)
            {
                g_iStay = FALSE;
                llReleaseControls();
            }
            Unleash(kMessageID);
        }
        else if (iAuth == LOCALSETTING_RESPONSE)
        {
            integer iInd = llSubStringIndex(sMessage, "=");
            string sTOK = llGetSubString(sMessage, 0, iInd -1);
            string sVAL = llGetSubString(sMessage, iInd + 1, -1);
            if (sTOK == TOK_DEST)
            {
                //we got the last leasher's id and rank from the local settings
                lParam = llParseString2List(llGetSubString(sMessage, iInd + 1, -1), [","], []);
                key kTarget = (key)llList2String(lParam, 0);
                g_bLeashedToAvi = (integer)llList2String(lParam, 2);
                g_bFollowMode = (integer)llList2String(lParam, 3);
                list lPoints;
                if (g_bLeashedToAvi)
                {
                    lPoints = ["collar", "handle"];
                }
                DoLeash(kTarget, (integer)llList2String(lParam, 1), lPoints);                
            }
            else if (sTOK == TOK_LENGTH)
            {
                SetLength((float)sVAL);
            }
            else if (sTOK == TOK_ROT)
            {
                g_iRot = (integer)sVAL;
            }
        }
        // All default settings from the settings notecard are sent over "HTTPDB_RESPONSE" channel
        else if (iAuth == HTTPDB_RESPONSE)
        {
            integer iInd = llSubStringIndex(sMessage, "=");
            string sTOK = llGetSubString(sMessage, 0, iInd -1);
            string sVAL = llGetSubString(sMessage, iInd + 1, -1);
            if (sTOK == TOK_LENGTH)
            {
                SetLength((float)sVAL);
            }
            else if (sTOK == TOK_ROT)
            {
                g_iRot = (integer)sVAL;
            }
        }
        else if (iAuth == DIALOG_TIMEOUT)
        {
            g_sCurrentMenu = "";
        }
        else if (iAuth == DIALOG_RESPONSE)
        {
            if (kMessageID == g_kDialogID)
            {
                list lMenuParams = llParseString2List(sMessage, ["|"], []);
                key kAV = (key)llList2String(lMenuParams, 0);          
                string sButton = llList2String(lMenuParams, 1);
                g_sMenuUser = kAV;
                
                if(sButton == UPMENU)
                {
                    if(g_sCurrentMenu == "length" || g_sCurrentMenu == "leashto" || g_sCurrentMenu == "post")
                    {
                        LeashMenu(kAV);
                    }
                    else
                    {
                        llMessageLinked(LINK_SET, MENUNAME_SUBMENU, PARENTMENU, kAV);
                        return;
                    }
                }                
                else if(sButton == L_LENGTH)
                {
                    LengthMenu(kAV);
                    return;
                }
                else if(sButton == GIVE_HOLDER)
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "giveholder", kAV);
                else if(sButton == GIVE_POST)
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "givepost", kAV);
                else if(sButton == REZ_POST)
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "rezpost", kAV);
                else if((sButton == LEASH_TO) || (sButton == FOLLOW_MENU) || (sButton == L_POST))
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, sButton, kAV);
                }                            
                else if(llListFindList(g_lLengths,[sButton]) != -1)
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "length " + sButton, kAV);
                    LengthMenu(kAV);
                    return; // no re-main leash menu                    
                }
                else
                {
                    if ((g_iSensorMode >= SENSORMODE_FIND_TARGET_FOR_LEASH_MENU) && (g_iSensorMode <= SENSORMODE_FIND_TARGET_FOR_POST_MENU))
                    {                        
                        if ((key)sButton)
                        {
                            g_kLeashedTo = (key)sButton;
                            if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_FOLLOW_MENU)
                            {
                                g_bFollowMode = TRUE;
                                LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "handle"]);
                                //SayFollow(g_kLeashedTo, g_kCmdGiver, g_iLastRank);
                            }
                            else if(g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_LEASH_MENU)
                            {
                                if (CheckCommandAuth(g_kCmdGiver, g_iLastRank))
                                    LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "handle"]);
                            }
                            else if(g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_MENU)
                            {
                                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "post " + sButton + " collar post", kAV);
                            }
                            if (!g_iReturnMenu) return;
                        }
                    } 
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, llToLower(sButton), kAV);
                    list lTemp = [LEASH, L_YANK, UNLEASH];
                    if (!~llListFindList(lTemp, [sButton]))
                    {
                        return;
                    }                                    
                }                
                LeashMenu(kAV);
            }
        }
    }


   sensor(integer iSense)
    {
        //debug((string)llGetFreeMemory( ));
        integer iLoop;
        string sPrompt;
        if ((g_iSensorMode >= SENSORMODE_FIND_TARGET_FOR_LEASH_MENU) && (g_iSensorMode <= SENSORMODE_FIND_TARGET_FOR_POST_MENU))
        {
            if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_FOLLOW_MENU)
                sPrompt = "Pick someone/thing to follow."; 
            else if(g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_LEASH_MENU)
                sPrompt = "Pick someone/thing to leash to.";  
            else if(g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_MENU)
                sPrompt = "Pick the object that you would like the sub to be leashed to.  If it's not in the list, have the sub move closer and try again.\n";
            
            list lButtons = []; // just used for menu building
            for (iLoop = 0; iLoop < iSense; iLoop++)
            {
                if((llDetectedName(iLoop) != "Object") ||  (g_iSensorMode < SENSORMODE_FIND_TARGET_FOR_POST_MENU))
                    lButtons += [llDetectedKey(iLoop)];
                
            }
            g_kDialogID = Dialog(g_kMenuUser, sPrompt, lButtons, [UPMENU], 0);
        }
        else if ((g_iSensorMode >= SENSORMODE_FIND_TARGET_FOR_LEASH_CHAT) && (g_iSensorMode <= SENSORMODE_FIND_TARGET_FOR_POST_CHAT))        
        {
            if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_FOLLOW_CHAT)
                "Could not find '" + g_sTmpName + "' to follow.";
            else
                "Could not find '" + g_sTmpName + "' to leash to.";
                
            // Loop through detected avs, seeing if one matches tmpname
            for (iLoop = 0; iLoop < iSense; iLoop++)
            {
                string sName = llDetectedName(iLoop);
                if (startswith(llToLower(sName), llToLower(g_sTmpName)))
                {
                    g_kLeashedTo = llDetectedKey(iLoop);
                    if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_FOLLOW_CHAT)
                    {
                        g_bFollowMode = TRUE;
                        LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "handle"]);
                        //SayFollow(g_kLeashedTo, g_kCmdGiver, g_iLastRank);
                    }
                    else if (CheckCommandAuth(g_kCmdGiver, g_iLastRank))
                    {
                        if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_LEASH_CHAT)
                            LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "handle"]);
                        else if (g_iSensorMode == SENSORMODE_FIND_TARGET_FOR_POST_CHAT)
                            LeashTo(g_kLeashedTo, g_kCmdGiver, g_iLastRank, ["collar", "post"]);
                    }
                    return;
                }
            }
            // No match found -
            Notify(g_kCmdGiver, "Could not find '" + g_sTmpName + "' to follow.", FALSE);
        } 
    }
    
    no_sensor()
    {
        // Nothing found close enough to leash onto, tell menuuser
        Notify(g_kMenuUser, "Unable to find any nearby targets.", FALSE);
        if (g_iSensorMode >= SENSORMODE_FIND_TARGET_FOR_LEASH_MENU && g_iReturnMenu)
            LeashMenu(g_kMenuUser);
    }        
    
    at_target(integer iNum, vector vTarget, vector vMe)
    {
        g_iUnixTime = llGetUnixTime();
        llStopMoveToTarget();
        llTargetRemove(g_iTargetHandle);
        g_vPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
        g_iTargetHandle = llTarget(g_vPos, g_fLength);
        if(g_iJustMoved)
        {
            turnToTarget( llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0));
            g_iJustMoved = 0;
        }   
    }
    
    not_at_target()
    {
        g_iJustMoved = 1;
        g_iUnixTime = llGetUnixTime();
        // i ran into a problem here which seems to be "speed" related, specially when using the menu to unleash this event gets triggered together or just after the CleanUp() function
        //to prevent to get stay in the target events i added a check on g_kLeashedTo is NULL_KEY
        if(g_kLeashedTo)
        {
            vector vNewPos = llList2Vector(llGetObjectDetails(g_kLeashedTo,[OBJECT_POS]),0);
            //llStopMoveToTarget();
            if (g_vPos != vNewPos)
            {
                llTargetRemove(g_iTargetHandle);
                g_vPos = vNewPos;
                g_iTargetHandle = llTarget(g_vPos, g_fLength);
            }
            if (g_vPos != ZERO_VECTOR)
            {
                //only at target
               /* if (!(llGetAgentInfo(g_kWearer) & AGENT_SITTING))
                {
                    if ((g_iUnixTime + 2) >= llGetUnixTime())
                    {
                        turnToTarget(g_vPos);
                    }
                }*/
                llMoveToTarget(g_vPos,0.7);
            }
            else
            {
                llStopMoveToTarget();
            }
        }
        else
        {
            Unleash(g_kLeashedTo);
        }
    }
  
    run_time_permissions(integer iPerm)
    {
        if (iPerm & PERMISSION_TAKE_CONTROLS)
        {
            //disbale all controls but left mouse button (for stay cmd)
            llTakeControls(CONTROL_ROT_LEFT | CONTROL_ROT_RIGHT | CONTROL_LBUTTON | CONTROL_ML_LBUTTON, FALSE, FALSE);
        }
    }
}