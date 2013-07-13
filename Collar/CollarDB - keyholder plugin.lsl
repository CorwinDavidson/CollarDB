// CollarDB - Keyholder Module
// 
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.
//

// -- Toy Configureation ----------------------------------------
string g_sChatCommand = "kh"; // every menu should have a chat command, so the user can easily access it by type for instance *plugin
integer g_nDebugMode=FALSE; // set to TRUE to enable Debug messages
integer g_iHideLockWhenOff=TRUE; // set to FALSE to not hide the lock when the module is off and the collar is unlocked. :kc
string g_sToyName = "collar";

// Are we in cuff mode?
integer g_iOpenCuffMode = FALSE;

// Who do we send messages to?
integer LINK_WHAT = LINK_SET;

// -- Menu Configureation ----------------------------------------
string g_sSubmenu = "Key Holder"; // Name of the submenu
string g_sParentmenu = "AddOns"; // name of the menu, where the menu plugs in, should be usually Addons. Please do not use the mainmenu anymore ( AddOns or Main is recomended depending on the toy. )

integer g_iConfigMenu = FALSE; // Seperate root config menu? For OCCD and other non-collar toys.
string g_sKeyConfigMenu = "Key Holder Config";
string g_sConfigMenu = "Config";

// Timer menu access...
string g_sTimerMenu = "Timer";

// menu option to go one step back in menustructure
string UPMENU = "^";//when your menu hears this, give the parent menu

// -- State Information ----------------------------------------
key kh_key = NULL_KEY; // id key of the person that has the key
string kh_name; // name of the person that has the key
integer kh_type; // Access type keyholder originally had.
integer kh_saved_openaccess; // saved so it can be restored.
integer kh_saved_locked; // saved so it can be restored.
integer kh_lockout = FALSE; // User is locked out until key return.
// integer kh_failed_time = 0; // When they last failed a check.  Ka: What is this for?  ws: Presnece stuff. Future feature.
// Collar state
integer oc_locked = FALSE;
integer oc_openaccess = FALSE;
// OOCD stuff
integer g_iDeviceShown=TRUE; // True unless told otherwise.

// -- Settings ----------------------------------------
integer kh_on = FALSE; // Is this feature turned on?
float kh_range = 10.0; // In meters. 0 = In sim.
integer kh_disable_openaccess = TRUE; // Disable open access when key is taken?
integer kh_lock_collar = TRUE; // Lock the toy when the key is taken?
integer kh_public_key = FALSE; // Can the key be taken when not open access?
integer kh_main_menu = FALSE; // Display in main menu?
integer kh_return_on_timer = FALSE; // Return key on timer expire?
integer kh_auto_return_timer = FALSE; // Start a timer for key return?
integer kh_auto_return_time = 120; // default 1 hour.
integer g_iGlobalKey = TRUE; // are we on the global key.
// integer kh_present = FALSE; // Requires the keyholder be present or the key is returned. TODO

// -- Constants ------------------------------------------
string TAKEKEY = "*Take Key*";
string RETURNKEY = "*Return Key*";

// Various variables needed by cuffs.
integer g_nCmdChannel    = -190890;
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for

// Backchannel for global key stuff.
integer g_iKeyHolderChannel = -0x3FFF0502;
// Protocol:
// key;take;UUID;auth
// key;return;reason

// ------ TOKEN DEFINITIONS ------
string TOK_DB = "keyholder"; // Stuff that gets stored in the settings DB
string TOK_LOCAL = "localkeyholder"; // Values stroed in the local cache.

// State stuff
key g_kWearer; // key of the current wearer to reset only on owner changes
string g_sPrefix; // sub prefix for databse actions

// Menu Stuff
list localbuttons = [ ]; // any local, not changing buttons which will be used in this plugin, leave emty or add buttons as you like
list externalbuttons = []; // External buttons

// menu handlers
key g_keyMenuID; // For saving the key of the last dialog we sent
key g_keyConfigMenuID;
key g_keyConfigAutoReturnMenuID;

string g_sElementLockedKey = "locked key";
string g_sElementUnlockedKey = "unlocked key";
string g_sElementLockedLock = "locked lock";
string g_sElementUnlockedLock = "unlocked lock";

//===============================================================================
// CollarDB MESSAGE MAP
//===============================================================================
// messages for authenticating users
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_SECOWNER = 501;
integer COMMAND_GROUP = 502;
integer COMMAND_WEARER = 503;
integer COMMAND_EVERYONE = 504;
//integer CHAT = 505;//deprecated
integer COMMAND_OBJECT = 506;
integer COMMAND_RLV_RELAY = 507;
integer COMMAND_SAFEWORD = 510;
integer COMMAND_BLACKLIST = 520;
// added for timer so when the sub is locked out they can use postions
integer COMMAND_WEARERLOCKEDOUT = 521;

//integer SEND_IM = 1000; deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bit of lag caused by having IM slave scripts
integer POPUP_HELP = 1001;

// messages for storing and retrieving values from http db
integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
//str must be in form of "token=value"
integer HTTPDB_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB
integer HTTPDB_EMPTY = 2004;//sent by httpdb script when a token has no value in the db

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

// messages for RLV commands
integer RLV_CMD = 6000;
integer RLV_REFRESH = 6001;//RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR = 6002;//RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION = 6003; //RLV Plugins can recieve the used rl viewer version upon receiving this message..

// messages for poses and couple anims
integer ANIM_START = 7000;//send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP = 7001;//send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST = 7002;//id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE = 7003;//str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START = 7004;//str should be valid anim name.  id should be av
integer CPLANIM_STOP = 7005;//str should be valid anim name.  id should be av

integer WEARERLOCKOUT=620;

integer APPEARANCE_ALPHA = -8000;
integer APPEARANCE_COLOR = -8001;
integer APPEARANCE_TEXTURE = -8002;
integer APPEARANCE_POSITION = -8003;
integer APPEARANCE_ROTATION = -8004;
integer APPEARANCE_SIZE = -8005;
integer APPEARANCE_SIZE_FACTOR = -8105;

integer TIMER_EVENT = -10000; // str = "start" or "end". For start, either "online" or "realtime".

// For other things that want to manage showing/hiding keys.
integer KEY_VISIBLE = -10100;
integer KEY_INVISIBLE = -10100;

//===============================================================================
// Misc utility functions.
//===============================================================================

integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)llGetOwner(),3,8)) + g_nCmdChannelOffset;
    if (chan>0)
    {
        chan=chan*(-1);
    }
    if (chan > -10000)
    {
        chan -= 30000;
    }
    return chan;
}

string strReplace(string str, string search, string replace) {
    return llDumpList2String(llParseStringKeepNulls((str = "") + str, [search], []), replace);
}

// Returns true if it matches with or with out the DB prefix
integer CompareDBPrefix(string str, string value)
{
    return ((str == value) || (str == (g_sPrefix + value)));
}

Debug(string sMsg)
{
    if (!g_nDebugMode) return;
    llOwnerSay(llGetScriptName() + ": " + sMsg);
}

Notify(key kID, string msg, integer alsoNotifyWearer)
{
    if (kID == g_kWearer)
    {
        llOwnerSay(msg);
    }
    else
    {
        llInstantMessage(kID,msg);
        if (alsoNotifyWearer)
        {
            llOwnerSay(msg);
        }
    }
}

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_WHAT, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), kID);
    return kID;
}

string CheckBox(string name, integer value)
{
    string s = "()";
    if (value)
        s = "(*)";
        
    return s + name;
}

DoMenuSpecial(key kID, integer page, integer special)
{
    string prompt;
    list mybuttons = localbuttons + externalbuttons;
    list utility_buttons;

    //fill in your button list and additional prompt here
    if (!kh_on)
    {
        prompt = "This module is turned off. An Owner can turn it on from the Configure menu.";
    }
    else if (kID == kh_key)
    {
        prompt = "You hold the key! You may return it to the lock if you wish.";
        mybuttons = [ "Return Key" ] + mybuttons;
    }
    else if (kh_key == NULL_KEY)
    {
        prompt = "The key is available for the taking!";        
        mybuttons = [ "Take Key" ] + mybuttons;
    }
    else
    {
        prompt = "The key is held by " + kh_name + "\n\nOwners can force a key return.";
        mybuttons = [ "Force Return" ] + mybuttons;
    }
    
    if (!special)
    {
        prompt += "\n\nLockout - Lock wearer out IMMEDIATLY. Unset on key return.";
        if (!kh_lockout)
            mybuttons += "Lockout";

        mybuttons += [ "Configure" ];
    }

    // Utility buttons are shown on every page
    if (!special)
        utility_buttons += [UPMENU]; //make sure there's a button to return to the parent menu

    // and dispay the menu
    g_keyMenuID = Dialog(kID, prompt, mybuttons, utility_buttons, 0);
}

DoMenu(key kID, integer page)
{
    DoMenuSpecial(kID, page, FALSE);
}

string Int2Time(integer sTime)
{
    if (sTime<0) sTime=0;
    integer iSecs=sTime%60;
    sTime = (sTime-iSecs)/60;
    integer iMins=sTime%60;
    sTime = (sTime-iMins)/60;
    integer iHours=sTime%24;
    integer iDays = (sTime-iHours)/24;
    
    return ( (string)iDays+", "+
        llGetSubString("0"+(string)iHours,-2,-1) + ":"+
        llGetSubString("0"+(string)iMins,-2,-1) + ":"+
        llGetSubString("0"+(string)iSecs,-2,-1) );
}

DoMenuAutoReturnConfig(key kID, integer page)
{
    string prompt;
    list mybuttons = localbuttons;
//[23:45:29]  Kadah Coba: 1h, 3h, 6h, 1d, 2d, 3d?, 1w
    list times = [ 1*60*60, 3*60*60, 6*60*60, 1*24*60*60, 2*24*60*60, 4*24*60*60, 7*24*60*60 ];
    integer i;
    integer max_times = llGetListLength(times);
    
    prompt = 
"Key Auto Return Configuration

Turn this feature off, or pick a time to return the key in automatically.

Times in: Days, Hours:Minutes:Seconds.

Only the owner may change these.
";
    //fill in your button list and additional prompt here
    mybuttons += CheckBox("Auto Off", !kh_auto_return_timer);

    for (i = 0; i < max_times; i++)
    {
        mybuttons += CheckBox(Int2Time(llList2Integer(times, i)), llList2Integer(times, i) == kh_auto_return_time && kh_auto_return_timer);
    }
    
    // and dispay the menu
    g_keyConfigAutoReturnMenuID = Dialog(kID, prompt, mybuttons, [UPMENU], 0);
}

DoMenuConfigure(key kID, integer page)
{
    string prompt;
    list mybuttons = localbuttons;

    prompt = 
"Key Holder Configuration

Lock - Does the " + g_sToyName + " lock when someone takes the key?
No Open - Does the " + g_sToyName + " disable open access when someone takes the key?
On - Is the keyholder module turned on?
Pub. Key - Is the key public even when Open Access is turned off?
Main Menu - Is the main menu changed for ease of access.
Global - Is this on the global key system?

Only the owner may change these.
";
    //fill in your button list and additional prompt here
    mybuttons += CheckBox("On", kh_on);
    mybuttons += CheckBox("Lock", kh_lock_collar);
    mybuttons += CheckBox("No Open", kh_disable_openaccess);
    mybuttons += CheckBox("Pub. Key", kh_public_key);
    mybuttons += CheckBox("Main Menu", kh_main_menu);
    mybuttons += CheckBox("Global", g_iGlobalKey);
//    mybuttons += CheckBox("Lockout", kh_lockout);
    mybuttons += [ "Auto Return" ];
   

    // and dispay the menu
    g_keyConfigMenuID = Dialog(kID, prompt, mybuttons, [UPMENU], 0);
}




//===============================================================================
TakeKey(key kAv, integer auth, integer remote)
{
    if (!kh_on)
    {
        Notify(kAv, "This module is turned off by an Owner.",FALSE);
        return;
    }
    
    if (!remote && kh_range > 0.0 && llVecDist(llList2Vector(llGetObjectDetails(kAv, [OBJECT_POS]),0),llGetPos()) > kh_range)
    {
        Notify(kAv, "You are too far away to take " + llKey2Name(llGetOwner()) + "'s key, you will have to move closer.",FALSE);
        return;
    }

    kh_key = kAv;
    kh_name = llKey2Name(kAv);
    kh_type = auth;
    
    kh_saved_openaccess = oc_openaccess;
    kh_saved_locked = oc_locked;
    
    setMainMenu();
    
    if (kh_disable_openaccess && oc_openaccess)
        llMessageLinked(LINK_WHAT, COMMAND_OWNER, "unsetopenaccess", kAv);
    
    if (kh_lock_collar && !oc_locked)
        llMessageLinked(LINK_WHAT, COMMAND_OWNER, "lock", kAv);
    
    llMessageLinked(LINK_WHAT, WEARERLOCKOUT, "on", "");
    
    if (kh_auto_return_timer && kh_auto_return_time)
    {
        integer minutes = (kh_auto_return_time / 60) % 60;
        integer hours = kh_auto_return_time / 60 / 60;
        
        // Set the timer. Real timer for now. Make it an option later.
        llMessageLinked(LINK_WHAT, COMMAND_OWNER, 
            "timer real=" + (string)hours + ":" + (string)minutes,
            NULL_KEY);
        llMessageLinked(LINK_WHAT, COMMAND_OWNER, "timer start", NULL_KEY);
    }
    
    Notify(kAv, "You take " + llKey2Name(llGetOwner()) + "'s key!", FALSE);
    Notify(g_kWearer,"Your key has been taken by " + llKey2Name(kAv) + "!", FALSE);

    if (!remote && g_iGlobalKey)
        llWhisper(g_iKeyHolderChannel, llDumpList2String([
            "key", "take", (string)kAv, (string)auth
            ], ";") );

    updateVisible();
    
    saveSettings();
}

ReturnKey(string reason, integer remote)
{
    key kAv = kh_key;
    
    if (kh_key == NULL_KEY) return;
    
    kh_key = NULL_KEY;
    kh_name = "";
    kh_type = 0;
    
    setMainMenu();

    if (kh_disable_openaccess && kh_saved_openaccess && !oc_openaccess)
        llMessageLinked(LINK_WHAT, COMMAND_OWNER, "setopenaccess", kAv); 
    
    if (kh_lock_collar && !kh_saved_locked && oc_locked)
        llMessageLinked(LINK_WHAT, COMMAND_OWNER, "unlock", kAv);
    
    // Need to check if someone else is doing this too... but really that should be handled by 
    // the auth module somehow.
    llMessageLinked(LINK_WHAT, WEARERLOCKOUT, "off", "");
    
    // Lockout canceled on key return
    kh_lockout = FALSE;
    
    if (kh_auto_return_timer && kh_auto_return_time)
    {
        llMessageLinked(LINK_WHAT, COMMAND_OWNER, "timer stop", NULL_KEY);
    }
            
    Notify(kAv, llKey2Name(llGetOwner()) + "'s key is returned. " + reason, FALSE);
    Notify(g_kWearer,"Your key has been returned. " + reason,FALSE);
    
    if (!remote && g_iGlobalKey)
        llWhisper(g_iKeyHolderChannel, llDumpList2String([
            "key", "return", (string)reason
            ], ";") );
    
    updateVisible();
    
    saveSettings();
}

//===============================================================================
//
//===============================================================================
setMainMenu()
{
    llMessageLinked(LINK_WHAT, MENUNAME_REMOVE, "Main" + "|" + RETURNKEY, NULL_KEY);
    llMessageLinked(LINK_WHAT, MENUNAME_REMOVE, "Main" + "|" + TAKEKEY, NULL_KEY);
    
    if (kh_on && kh_main_menu)
    {
        if (kh_key != NULL_KEY)
            llMessageLinked(LINK_WHAT, MENUNAME_RESPONSE, "Main" + "|" + RETURNKEY, NULL_KEY);
        else
            llMessageLinked(LINK_WHAT, MENUNAME_RESPONSE, "Main" + "|" + TAKEKEY, NULL_KEY);
    }
}

//===============================================================================
//
//===============================================================================
setTimerMenu()
{
    llMessageLinked(LINK_WHAT, MENUNAME_RESPONSE, g_sTimerMenu + "|" + CheckBox("Return Key", kh_return_on_timer), NULL_KEY);
    llMessageLinked(LINK_WHAT, MENUNAME_REMOVE, g_sTimerMenu + "|" + CheckBox("Return Key", !kh_return_on_timer), NULL_KEY);
}

//===============================================================================
//
//===============================================================================
updateVisible()
{
    integer show_key = FALSE;
    
    if (g_iDeviceShown == FALSE)
    {
        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementLockedKey +"§0.0§" + (string)FALSE, NULL_KEY);
        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedKey +"§0.0§" + (string)FALSE, NULL_KEY);
        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedLock +"§0.0§" + (string)FALSE, NULL_KEY);
        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementLockedLock +"§0.0§" + (string)FALSE, NULL_KEY);
    }
    else if (oc_locked)
    {
        if (kh_key == NULL_KEY && kh_on)
        {
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementLockedKey +"§1.0§" + (string)FALSE, NULL_KEY);
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedKey +"§0.0§" + (string)FALSE, NULL_KEY);            
            show_key = TRUE;
        }
        else
        {
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementLockedKey +"§0.0§" + (string)FALSE, NULL_KEY);
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedKey +"§0.0§" + (string)FALSE, NULL_KEY);
        }
        
        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedLock +"§0.0§" + (string)FALSE, NULL_KEY);
        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementLockedLock +"§1.0§" + (string)FALSE, NULL_KEY);
    }
    else
    {
        if (kh_key == NULL_KEY && kh_on)
        {
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementLockedKey +"§0.0§" + (string)FALSE, NULL_KEY);
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedKey +"§1.0§" + (string)FALSE, NULL_KEY);
            show_key = TRUE;
        }
        else
        {
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementLockedKey +"§0.0§" + (string)FALSE, NULL_KEY);
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedKey +"§0.0§" + (string)FALSE, NULL_KEY);
        }
        
        if (!kh_on && g_iHideLockWhenOff) // just hide the thing entirely in this case.
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedLock +"§0.0§" + (string)FALSE, NULL_KEY);
        else
            llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementUnlockedLock +"§1.0§" + (string)FALSE, NULL_KEY);
        llMessageLinked(LINK_SET, APPEARANCE_ALPHA, g_sElementLockedLock +"§0.0§" + (string)FALSE, NULL_KEY);
    }
    
    // Let other people know in case they are handling it and not us.
    if (show_key)
        llMessageLinked(LINK_WHAT, KEY_VISIBLE, "", "");
    else
        llMessageLinked(LINK_WHAT, KEY_INVISIBLE, "", "");

    
    // Handle cuffs, if we are in Cuff mode.
    if (g_iOpenCuffMode)
    {
        llRegionSay(g_nCmdChannel+1,"rlac|*|khShowKey=" + (string)show_key + "|" + (string)llGetOwner());
    }
}

//===============================================================================
// State Saving
//===============================================================================
saveSettings()
{
    llMessageLinked(LINK_THIS, HTTPDB_SAVE, 
        g_sPrefix + TOK_DB + "=" +
        llDumpList2String([
                kh_on,
                kh_range,
                kh_disable_openaccess,
                kh_lock_collar,
                kh_public_key,
                kh_main_menu,
                kh_return_on_timer,
                kh_auto_return_timer,
                kh_auto_return_time,
                g_iGlobalKey
            ], ","), NULL_KEY);
    
    // Save the keyholder if we have one.
    if (kh_key != NULL_KEY)
    {
        llMessageLinked(LINK_THIS, LOCALSETTING_SAVE, TOK_LOCAL + "=" +
            llDumpList2String([ 
                kh_key,
                kh_type,
                kh_name,
                kh_saved_openaccess,
                kh_saved_locked
            ], ","), NULL_KEY);
    } else {
        llMessageLinked(LINK_THIS, LOCALSETTING_DELETE, TOK_LOCAL, NULL_KEY);
    }
}

loadDBSettings(string sSettings)
{
    list lValues = llParseStringKeepNulls(sSettings, [ "," ], []);
    
    kh_on = (integer)llList2String(lValues, 0);
    kh_range = (float)llList2String(lValues, 1);
    kh_disable_openaccess = (integer)llList2String(lValues, 2);
    kh_lock_collar = (integer)llList2String(lValues, 3);
    kh_public_key = (integer)llList2String(lValues, 4);
    kh_main_menu = (integer)llList2String(lValues, 5);
    kh_return_on_timer = (integer)llList2String(lValues, 6);
    kh_auto_return_timer = (integer)llList2String(lValues, 7);
    kh_auto_return_time = (integer)llList2String(lValues, 8);
    g_iGlobalKey = (integer)llList2String(lValues, 9);
    
    setMainMenu();
}

loadLocalSettings(string sSettings)
{
    list lValues = llParseStringKeepNulls(sSettings, [ "," ], []);
    
    if (kh_key != NULL_KEY) return; // Already have a keyholder, do not overwrite.
    
    kh_key = llList2Key(lValues, 0);
    kh_type = (integer)llList2String(lValues, 1);
    kh_name = llList2String(lValues, 2);
    kh_saved_openaccess = (integer)llList2String(lValues, 3);
    kh_saved_locked = (integer)llList2String(lValues, 4);
    
    updateVisible();
    setMainMenu();
}

//===============================================================================
//= parameters   :    none
//=
//= return        :   string     DB prefix from the description of the collar
//=
//= description  :    prefix from the description of the collar
//=
//===============================================================================

string GetDBPrefix()
{//get db prefix from list in object desc
    return llList2String(llParseString2List(llGetObjectDesc(), ["~"], []), 2);
}


//===============================================================================

default
{
    state_entry()
    {
        // sleep a second to allow all scripts to be initialized
        llSleep(1.0);
        // send request to main menu and ask other menus if they want to register with us
        llMessageLinked(LINK_WHAT, MENUNAME_REQUEST, g_sSubmenu, NULL_KEY);
        llMessageLinked(LINK_WHAT, MENUNAME_RESPONSE, g_sParentmenu + "|" + g_sSubmenu, NULL_KEY);

        // get dbprefix from object desc, so that it doesn't need to be hard coded, and scripts between differently-primmed collars can be identical
        g_sPrefix = GetDBPrefix();
        g_kWearer=llGetOwner();
        updateVisible();
        
        if (g_iOpenCuffMode) 
            g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset); // get the owner defined channel
               
        // Global Key
        llListen(g_iKeyHolderChannel, "", "", "");
        
        // Get us up to date.
        setMainMenu();
        setTimerMenu();
		
		llOwnerSay(llGetScriptName() + ": "(string)(llGetFreeMemory() / 1024) + " KB Free");
    }

    // reset the script if wearer changes. By only reseting on owner change we can keep most of our
    // configuration in the script itself as global variables, so that we don't loose anything in case
    // the httpdb server isn't available
    on_rez(integer param)
    {
        if (llGetOwner()!=g_kWearer)
        {
            // Reset if wearer changed
            llResetScript();
        }
        
        if ( kh_lockout || kh_key != NULL_KEY )
            llMessageLinked(LINK_WHAT, WEARERLOCKOUT, "on", "");
        
        updateVisible();
    }


    // listen for linked messages from OC scripts
    link_message(integer sender, integer num, string str, key kID)
    {
        if (num == SUBMENU)
        {
            // Main Menu
            if (str == g_sSubmenu)
            {
                DoMenu(kID, 0);
            }
            // Config Menu
            else if (str == g_sKeyConfigMenu)
            {
                DoMenuConfigure(kID, 0);
            }
            // This is out of the timer module...
            else if (str == "(*)Return Key")
            {
                llMessageLinked(LINK_WHAT, COMMAND_NOAUTH, "khunsettimerreturnkey", kID);
            }
            else if (str == "()Return Key")
            {
                llMessageLinked(LINK_WHAT, COMMAND_NOAUTH, "khsettimerreturnkey", kID);
            }
            // Take / Return key from the main menu
            else if (str == TAKEKEY)
            {
                llMessageLinked(LINK_WHAT, COMMAND_NOAUTH, "khtakekeymain", kID);
            }
            else if (str == RETURNKEY)
            {
                if (kh_key != kID)
                {
                    Notify(kID, "You are not the keyholder.", FALSE);
                }
                else
                {
                    ReturnKey("", FALSE);
                }  
            }      
        }
        else if (num == MENUNAME_REQUEST)
            // our parent menu requested to receive buttons, so send ours
        {
            if (str == g_sParentmenu)
                llMessageLinked(LINK_WHAT, MENUNAME_RESPONSE, g_sParentmenu + "|" + g_sSubmenu, NULL_KEY);

            if (str == "Main")
                setMainMenu();
            else if (str == g_sTimerMenu)
                setTimerMenu();
        }
        else if (num == MENUNAME_RESPONSE)
            // a button is send to be added to a menu
        {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == g_sSubmenu)
            {//someone wants to stick something in our menu
                string button = llList2String(parts, 1);
                if (llListFindList(externalbuttons, [button]) == -1)
                    // if the button isnt in our menu yet, than we add it
                {
                    externalbuttons = llListSort(externalbuttons + [button], 1, TRUE);
                }
            }
        }
        else if (num == MENUNAME_REMOVE)
            // a button is send to be removed from a menu
        {
            list parts = llParseString2List(str, ["|"], []);
            if (llList2String(parts, 0) == g_sSubmenu)
            {//someone wants to stick something in our menu
                string button = llList2String(parts, 1);
                integer iIndex = llListFindList(externalbuttons, [button]);
                if (iIndex != -1)
                {
                    externalbuttons = llDeleteSubList(externalbuttons, iIndex, iIndex);
                }
            }
        }
        else if(num == COMMAND_WEARERLOCKEDOUT)
        {
            // Do nothing, they are not allowed.
            if (str == "menu" && ( kh_key != NULL_KEY || kh_lockout ) )
            {
                if ( kh_key == NULL_KEY )
                    llOwnerSay("You are locked out of the " + g_sToyName + " until someone takes and returns your key.");
                else
                llOwnerSay("You are locked out of the " + g_sToyName + " until your key is returned.");
            }
        }
        
        else if (
                (num >= COMMAND_OWNER && num <= COMMAND_WEARER) ||
                (num == COMMAND_EVERYONE && str == "khtakekey" && kh_public_key)
            )
            // a validated command from a owner, secowner, groupmember or the wearer has been received
            // can also be used to listen to chat commands
        {
            if (str == "reset")
            {
                if (num == COMMAND_WEARER || num == COMMAND_OWNER)
                {   // only owner and wearer may reset
                    llResetScript();
                }
            }
            else if (str == "khtakekey" || str == "khtakekeymain")
            {
                if (kID == g_kWearer)
                {
                    Notify(kID, "Taking your own key does not make any sense.", FALSE);
                }
                else if (kh_key != NULL_KEY)
                {
                    Notify(kID, "The key is not in the lock.", FALSE);
                }
                else
                {
                    TakeKey(kID, num, FALSE);
                }
                if (str == "khtakekey")
                    DoMenu(kID, 0);
            }
            else if (num != COMMAND_OWNER)
            {
                // Only onwner accessable commands past here.
                if (llGetSubString(str, 0, 1) == "kh")
                    Notify(kID, "That command can only be accessed by an Owner.", FALSE);
            }
            else if (llGetSubString(str, 0, 4) == "khset" && (
                 llGetSubString(str, 5, 6) == "0," || 
                (integer)llGetSubString(str, 5, 5) > 0
                ) )
            {
                list times = llParseString2List(str, [ "khset", ",", ":" ], []);
                kh_auto_return_time = 
                    ( (integer)llList2String(times, 0) * 24 * 60 * 60 ) + // days
                    ( (integer)llList2String(times, 1) * 60 * 60 ) + // Hours
                    ( (integer)llList2String(times, 2) * 60 ) + // Minutes
                    ( (integer)llList2String(times, 3)  ) ; // Seconds
                
                kh_auto_return_timer = TRUE;
                
                DoMenuAutoReturnConfig(kID, 0);
        
        saveSettings();
            }
            else if (str == "khsetautooff")
            {
                kh_auto_return_timer = FALSE; 
            
                DoMenuAutoReturnConfig(kID, 0);
        
        saveSettings();
            }
            else if (str == "khforcereturn")
            {
                if (kh_key == NULL_KEY)
                    Notify(kID, "The key is already in the lock.", FALSE);
                else
                {
                    ReturnKey(llKey2Name(kID) + " forced the return.", FALSE);
                    Notify(kID, "You force-return the key to the lock.", FALSE);
                }
                DoMenu(kID, 0);
            }
            else if (str == "khtimerreturn")
            {
                if (kh_key != NULL_KEY)
                {
                    ReturnKey("Key returned by timer.", FALSE);
                }
            }
            else if (str == "khsetlock" || str == "khunsetlock")
            {
                kh_lock_collar = ( str == "khsetlock" );
                DoMenuConfigure(kID, 0);
        saveSettings();
            }
            else if (str == "khsetnoopen" || str == "khunsetnoopen")
            {
                kh_disable_openaccess = ( str == "khsetnonoopen" );
                DoMenuConfigure(kID, 0);
        saveSettings();
            }
            else if (str == "khsetpub.key" || str == "khunsetpub.key")
            {
                kh_public_key = ( str == "khsetpub.key" );
                DoMenuConfigure(kID, 0);
        saveSettings();
            }
            else if (str == "khlockout")
            {
                if (kh_lockout)
                    return;
                
                kh_lockout = TRUE;
                
                llOwnerSay("You are now locked out until your key is taken and returned.");
                
                llMessageLinked(LINK_WHAT, WEARERLOCKOUT, "on", "");
                
                if (kID != llGetOwner())
                    DoMenuConfigure(kID, 0);
            }
            else if (str == "khsetmainmenu" || str == "khunsetmainmenu")
            {
                kh_main_menu = ( str == "khsetmainmenu" );
                setMainMenu();
                DoMenuConfigure(kID, 0);
                saveSettings();
            }
            else if (str == "khsetglobal" || str == "khunsetglobal")
            {
                g_iGlobalKey = ( str == "khsetglobal" );
                DoMenuConfigure(kID, 0);
                saveSettings();
            }
            else if (str == "khseton" || str == "khunseton")
            {
                kh_on = ( str == "khseton" );
                
                if (kh_key != NULL_KEY)
                    ReturnKey("Key Holder plugin turned off by " + llKey2Name(kID), FALSE);

                DoMenuConfigure(kID, 0);
                
                updateVisible();
        saveSettings();
            }
            else if (str == "khunsettimerreturnkey" || str == "khsettimerreturnkey")
            {
                kh_return_on_timer = ( str == "khsettimerreturnkey");
                setTimerMenu();
                llMessageLinked(LINK_WHAT, SUBMENU, g_sTimerMenu, kID);
        saveSettings();
            }
        }
        else if (str == "khreturnkey")
        {
            if (kh_key != kID)
            {
                Notify(kID, "You are not the keyholder.", FALSE);
            }
            else
            {
                ReturnKey("", FALSE);
            }
        }
        else if (num == DIALOG_RESPONSE)
        {
            if (kID == g_keyMenuID || kID == g_keyConfigMenuID || kID == g_keyConfigAutoReturnMenuID)
            {
                // Extract the values...
                list menuparams = llParseString2List(str, ["|"], []);
                key kAv = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                
                // request to change to parent menu
                if (message == UPMENU)
                {
                    if (kID == g_keyMenuID)
                        llMessageLinked(LINK_WHAT, SUBMENU, g_sParentmenu, kAv);
                    if (kID == g_keyConfigMenuID)
                    {
                            DoMenu(kAv, 0);
                    }
                    else if (kID == g_keyConfigAutoReturnMenuID)
                        DoMenuConfigure(kAv, 0);
                }
                else if (message == "Configure")
                {
                    DoMenuConfigure(kAv, 0);
                }
                else if (message == "Auto Return")
                {
                    DoMenuAutoReturnConfig(kAv, 0);
                }
                else
                {
                    // Handle checkboxes.
                    integer checkbox = FALSE;
                    list l = llParseString2List(message, [ ], [ "()", "(*)" ]);
                    string s = llList2String(l, 0);
                    string cmd = message;
                    
                    if (s == "()" || s == "(*)")
                    {
                        checkbox = TRUE;
                        cmd = llList2String(l, 1);
                        if (s == "(*)")
                            cmd = "unset" + cmd;
                        else
                            cmd = "set" + cmd;
                    }
                    
                    // Module prefix for text version of command
                    cmd = g_sChatCommand + cmd;                   
                    // Remove spaces from the button name
                    cmd = strReplace(cmd, " ", "");
                    // Lowercase
                    cmd = llToLower(cmd);
                    
                    // Send it to get authenitcated
                    llMessageLinked(LINK_WHAT, COMMAND_NOAUTH, cmd, kAv);
                }
                
                if (kID == g_keyMenuID)
                    g_keyMenuID = NULL_KEY;
                if (kID == g_keyConfigMenuID)
                    g_keyConfigMenuID = NULL_KEY;
            }
        }
        else if (num == DIALOG_TIMEOUT)
        {
            if (kID == g_keyMenuID)
                g_keyMenuID = NULL_KEY;
            if (kID == g_keyConfigMenuID)
                g_keyConfigMenuID = NULL_KEY;
        }
        else if (num == COMMAND_EVERYONE)
        {
            // Auth keyholder commands
            if (kID == kh_key)
            {
                llMessageLinked(LINK_WHAT, COMMAND_GROUP, str, kID);
            }
            else if (kh_key == NULL_KEY && str == "menu" && !oc_openaccess && kh_public_key)
            {
                DoMenuSpecial(kID, 0, TRUE);
            }
        }
        else if (num == HTTPDB_RESPONSE || num == HTTPDB_SAVE || num == LOCALSETTING_RESPONSE || num == LOCALSETTING_SAVE)
        {
            list params = llParseString2List(str, ["="], []);
            string token = llList2String(params, 0);
            string value = llList2String(params, 1);
            
            if ( CompareDBPrefix(token, "locked") )
            {
                oc_locked = (integer)value;
                updateVisible();
            }
            else if ( CompareDBPrefix(token, "openaccess") )
            {
                oc_openaccess = (integer)value;
            }
            else if ( CompareDBPrefix(token, TOK_DB) )
            {
                loadDBSettings(value);
            }
            else if ( CompareDBPrefix(token, TOK_LOCAL) )
            {
                loadLocalSettings(value);
            }            
        }
        else if (num == HTTPDB_DELETE)
        {
            // Saddly it's deleted to indicate FALSE rather than set to 0...
            if ( CompareDBPrefix(str, "locked") )
            {
                oc_locked = FALSE;
                updateVisible();
            }
            else if ( CompareDBPrefix(str, "openaccess") )
                oc_openaccess = FALSE;
        }
        else if (num == COMMAND_SAFEWORD)
        {
            ReturnKey(llKey2Name(kID) + " has safeworded, key auto-returned.", FALSE);
        }
        else if (num == TIMER_EVENT)
        {
            if (str == "end")
            {
                if (kh_auto_return_timer)
                    ReturnKey("The automatic timer has expired.", FALSE);
                else if (kh_return_on_timer)
                    ReturnKey("The timer has expired.", FALSE);
            }
        }
    }
    
    listen(integer channel, string name, key kID, string message)
    {
        if (channel == g_iKeyHolderChannel)
        {
            if (!g_iGlobalKey) return; // don't care.
            if (llGetOwner() != llGetOwnerKey(kID)) return; // Not for us.
            
            list lArgs = llParseString2List(message, [";"], []);            
            if (llList2String(lArgs, 0) != "key") return; // channel overlap?            
            if (llList2String(lArgs, 1) == "take")
            {
                TakeKey(llList2Key(lArgs, 2), (integer)llList2String(lArgs, 3), TRUE);
            }
            else if (llList2String(lArgs, 1) == "return")
            {
                ReturnKey(llList2String(lArgs, 2), TRUE);
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
}