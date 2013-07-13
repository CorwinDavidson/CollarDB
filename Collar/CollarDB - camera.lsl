//CollarDB - camera - 3.520
//allows dom to set different camera mode
//responds to commands from modes list

key g_kWearer;
integer g_iLastNum;
string g_sDBToken = "cam";
string g_sMyMenu = "Camera";
string g_sParentMenu = "AddOns";
key g_kMenuID;
string g_sCurrentMode = "default";
float g_fReapeat = 0.5;

//these 4 are used for syncing dom to us by broadcasting cam pos/rot
integer g_iSync2Me;//TRUE if we're currently dumping cam pos/rot iChanges to chat so the owner can sync to us
vector g_vCamPos;
rotation g_rCamRot;
integer g_rBroadChan;

//a 2-strided list in the form modename,camparams, where camparams is a serialized list
list g_lModes = [
"default", "|/?!@#|12|0",//[CAMERA_ACTIVE, FALSE]
"1stperson", "|/?!@#|12|1|7/0.500000|1@<2.500000, 0.000000, 1.000000>", //CAMERA_ACTIVE, TRUE, CAMERA_DISTANCE, 0.5,CAMERA_FOCUS_OFFSET, <2.5,0,1.0>]]
"ass", "|/?!@#|12|1|7/0.500000",//[CAMERA_ACTIVE, TRUE, CAMERA_DISTANCE, 0.5]
"far", "|/?!@#|12|1|7/10.000000", //[CAMERA_ACTIVE, TRUE,CAMERA_DISTANCE, 10.0]]
"god", "|/?!@#|12|1|7/10.000000|0/80.000000", //[CAMERA_ACTIVE, TRUE,CAMERA_DISTANCE, 10.0,CAMERA_PITCH, 80.0]]
"ground", "|/?!@#|12|1|0/-15.000000",//[CAMERA_ACTIVE, TRUE, CAMERA_PITCH, -15.0]
"worm", "|/?!@#|12|1|7/0.500000|1@<0.000000, 0.000000, -0.750000>|0/-15.000000" //[CAMERA_ACTIVE, TRUE,CAMERA_DISTANCE, 0.5,CAMERA_FOCUS_OFFSET, <0,0,-0.75>, CAMERA_PITCH, -15.0]
];

//      MESSAGE MAP
integer COMMAND_NOAUTH          = 0xCDB000;
integer COMMAND_OWNER           = 0xCDB500;
integer COMMAND_SECOWNER        = 0xCDB501;
integer COMMAND_GROUP           = 0xCDB502;
integer COMMAND_WEARER          = 0xCDB503;
integer COMMAND_EVERYONE        = 0xCDB504;
integer COMMAND_OBJECT          = 0xCDB506;
integer COMMAND_RLV_RELAY       = 0xCDB507;
integer COMMAND_SAFEWORD        = 0xCDB510;
integer COMMAND_BLACKLIST       = 0xCDB520;

integer POPUP_HELP              = -0xCDB001;      

integer HTTPDB_SAVE             = 0xCDB200;     // scripts send messages on this channel to have settings saved to httpdb
                                                // str must be in form of "token=value"
integer HTTPDB_REQUEST          = 0xCDB201;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 0xCDB202;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 0xCDB203;     // delete token from DB
integer HTTPDB_EMPTY            = 0xCDB204;     // sent by httpdb script when a token has no value in the db
integer HTTPDB_REQUEST_NOCACHE  = 0xCDB205;

integer LOCALSETTING_SAVE       = 0xCDB250;
integer LOCALSETTING_REQUEST    = 0xCDB251;
integer LOCALSETTING_RESPONSE   = 0xCDB252;
integer LOCALSETTING_DELETE     = 0xCDB253;
integer LOCALSETTING_EMPTY      = 0xCDB254;

integer MENUNAME_REQUEST        = 0xCDB300;
integer MENUNAME_RESPONSE       = 0xCDB301;
integer SUBMENU                 = 0xCDB302;
integer MENUNAME_REMOVE         = 0xCDB303;

integer DIALOG                  = -0xCDB900;
integer DIALOG_RESPONSE         = -0xCDB901;
integer DIALOG_TIMEOUT          = -0xCDB902;

string UPMENU = "^";
//string MORE = ">";

CamMode(string sMode)
{
    llClearCameraParams();
    integer iIndex = llListFindList(g_lModes, [sMode]);
    string lParams = llList2String(g_lModes, iIndex + 1);    
    llSetCameraParams(TightListTypeParse(lParams));  
    g_sCurrentMode = sMode;
}

ClearCam()
{
    llClearCameraParams();
    g_iLastNum = 0;    
    g_iSync2Me = FALSE;
    llMessageLinked(LINK_SET, LOCALSETTING_DELETE, g_sDBToken, "");    
}

CamFocus(vector g_vCamPos, rotation g_rCamRot)
{
    vector vStartPose = llGetCameraPos();    
    rotation rStartRot = llGetCameraRot();
    float fSteps = 8.0;
    //Keep fSteps a float, but make sure its rounded off to the nearest 1.0
    fSteps = (float)llRound(fSteps);
 
    //Calculate camera position increments
    vector vPosStep = (g_vCamPos - vStartPose) / fSteps;
 
    //Calculate camera rotation increments
    //rotation rStep = (g_rCamRot - rStartRot);
    //rStep = <rStep.x / fSteps, rStep.y / fSteps, rStep.z / fSteps, rStep.s / fSteps>;
 
 
    float fCurrentStep = 0.0; //Loop through motion for fCurrentStep = current step, while fCurrentStep <= Total steps
    for(; fCurrentStep <= fSteps; ++fCurrentStep)
    {
        //Set next position in tween
        vector vNextPos = vStartPose + (vPosStep * fCurrentStep);
        rotation rNextRot = Slerp( rStartRot, g_rCamRot, fCurrentStep / fSteps);
 
        //Set camera parameters
        llSetCameraParams([
            CAMERA_ACTIVE, 1, //1 is active, 0 is inactive
            CAMERA_BEHINDNESS_ANGLE, 0.0, //(0 to 180) degrees
            CAMERA_BEHINDNESS_LAG, 0.0, //(0 to 3) seconds
            CAMERA_DISTANCE, 0.0, //(0.5 to 10) meters
            CAMERA_FOCUS, vNextPos + llRot2Fwd(rNextRot), //Region-relative position
            CAMERA_FOCUS_LAG, 0.0 , //(0 to 3) seconds
            CAMERA_FOCUS_LOCKED, TRUE, //(TRUE or FALSE)
            CAMERA_FOCUS_THRESHOLD, 0.0, //(0 to 4) meters
            CAMERA_POSITION, vNextPos, //Region-relative position
            CAMERA_POSITION_LAG, 0.0, //(0 to 3) seconds
            CAMERA_POSITION_LOCKED, TRUE, //(TRUE or FALSE)
            CAMERA_POSITION_THRESHOLD, 0.0, //(0 to 4) meters
            CAMERA_FOCUS_OFFSET, ZERO_VECTOR //<-10,-10,-10> to <10,10,10> meters
        ]);
    }
}
 
rotation Slerp( rotation a, rotation b, float t ) {
   return llAxisAngle2Rot( llRot2Axis(b /= a), t * llRot2Angle(b)) * a;
}//Written collectively, Taken from http://forums-archive.secondlife.com/54/3b/50692/1.html

LockCam()
{
    llSetCameraParams([
        CAMERA_ACTIVE, TRUE,
        //CAMERA_POSITION, llGetCameraPos()
        CAMERA_POSITION_LOCKED, TRUE
    ]);  
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage)
{
    key kID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

CamMenu(key kID)
{
    string sPrompt = "Current camera mode is " + g_sCurrentMode + ".  Select an option";
    list lButtons = ["Clear"];
    integer n;
    integer stop = llGetListLength(g_lModes);    
    for (n = 0; n < stop; n +=2)
    {
        lButtons += [Capitalize(llList2String(g_lModes, n))];
    }
    
    lButtons += ["Freeze"];
    g_kMenuID = Dialog(kID, sPrompt, lButtons, [UPMENU], 0);
}

string Capitalize(string sIn)
{
    return llToUpper(llGetSubString(sIn, 0, 0)) + llGetSubString(sIn, 1, -1);
}

string StringReplace(string sSrc, string sFrom, string sTo)
{//replaces all occurrences of 'sFrom' with 'sTo' in 'sSrc'.
    return llDumpList2String(llParseStringKeepNulls((sSrc = "") + sSrc, [sFrom], []), sTo);
}

//These TightListType functions allow serializing a list to a string, and deserializing it back, while preserving variable type information.  We use them so we can have a list of camera modes, where each mode is itself a list
 
list TightListTypeParse(string sInput) {
    list lPartial;
    if(llStringLength(sInput) > 6)
    {
        string sSeperators = llGetSubString(sInput,(0),6);
        integer iPos = ([] != (lPartial = llList2List(sInput + llParseStringKeepNulls(llDeleteSubString(sInput,(0),5), [],[sInput=llGetSubString(sSeperators,(0),(0)), llGetSubString(sSeperators,1,1),llGetSubString(sSeperators,2,2),llGetSubString(sSeperators,3,3), llGetSubString(sSeperators,4,4),llGetSubString(sSeperators,5,5)]), (llSubStringIndex(sSeperators,llGetSubString(sSeperators,6,6)) < 6) << 1, -1)));
        integer iType = (0);
        integer iSubPos = (0);
        do
        {
            list s_Current = (list)(sInput = llList2String(lPartial, iSubPos= -~iPos));//TYPE_STRING || TYPE_INVALID (though we don't care about invalid)
            if(!(iType = llSubStringIndex(sSeperators, llList2String(lPartial,iPos))))//TYPE_INTEGER
                s_Current = (list)((integer)sInput);
            else if(iType == 1)//TYPE_FLOAT
                s_Current = (list)((float)sInput);
            else if(iType == 3)//TYPE_KEY
                s_Current = (list)((key)sInput);
            else if(iType == 4)//TYPE_VECTOR
                s_Current = (list)((vector)sInput);
            else if(iType == 5)//TYPE_ROTATION
                s_Current = (list)((rotation)sInput);
            lPartial = llListReplaceList(lPartial, s_Current, iPos, iSubPos);
        }while((iPos= -~iSubPos) & 0x80000000);
    }
    return lPartial;
}
 
Notify(key kID, string sMsg, integer iAlsoNotifyWearer) 
{
    if (kID == g_kWearer) 
    {
        llOwnerSay(sMsg);
    } else {
        llInstantMessage(kID,sMsg);
        if (iAlsoNotifyWearer) 
        {
            llOwnerSay(sMsg);
        }
    }    
}

Debug(string sStr)
{
    //llOwnerSay(llGetScriptName() + ": " + sStr);
}

SaveSetting(string sSetting)
{
    llMessageLinked(LINK_SET, LOCALSETTING_SAVE, g_sDBToken + "=" + sSetting + "," + (string)g_iLastNum, "");
}

ChatCamParams(integer chan)
{
    g_vCamPos = llGetCameraPos();
    g_rCamRot = llGetCameraRot();
    string sPosLine = StringReplace((string)g_vCamPos, " ", "") + " " + StringReplace((string)g_rCamRot, " ", ""); 
    //if not channel 0, say to whole region.  else just say locally   
    if (chan)
    {
        llRegionSay(chan, sPosLine);                    
    }
    else
    {
        llSay(chan, sPosLine);
    }
}

default
{
    on_rez(integer iNum)
    {
        llResetScript();
    }    
    
    state_entry()
    {
        if (llGetAttached())
        {
            llRequestPermissions(llGetOwner(), PERMISSION_CONTROL_CAMERA | PERMISSION_TRACK_CAMERA);
        }
        g_kWearer = llGetOwner();
    }
    
    run_time_permissions(integer iPerms)
    {
        if (iPerms & PERMISSION_CONTROL_CAMERA)
        {
            llClearCameraParams();
        }
    }
    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        //only respond to owner, secowner, group, wearer
        if (iNum >= COMMAND_OWNER && iNum <= COMMAND_WEARER)
        {
            list lParams = llParseString2List(sStr, [" "], []);
            string sCommand = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            string sValue2 = llList2String(lParams, 2);
            string sLastValue = llList2String(lParams, -1);//with this, the menu can be just a layer over the chat commands. put a "returnmenu" here and user will be given a menu after the command takes effect.
            if (sCommand == "cam" || sCommand == "camera")
            {
                if (llGetPermissions() & PERMISSION_CONTROL_CAMERA)
                {
                    if (!g_iLastNum || iNum <= g_iLastNum)
                    {
                        Debug("g_iLastNum=" + (string)g_iLastNum);                        
                        if (sValue == "clear")
                        {
                            ClearCam();
                            Notify(kID, "Cleared camera settings.", TRUE);
                        }
                        else if (sValue == "")
                        {
                            //they just said *cam.  give menu
                            CamMenu(kID);
                        }
                        else if (sValue == "freeze")
                        {
                            LockCam();
                            Notify(kID, "Freezing current camera position.", TRUE);
                            g_iLastNum = iNum;                    
                            SaveSetting("freeze");                          
                        }
                        else if ((vector)sValue != ZERO_VECTOR && (vector)sValue2 != ZERO_VECTOR)
                        {
                            Notify(kID, "Setting camera focus to " + sValue + ".", TRUE);
                            //CamFocus((vector)sValue, (vector)sValue2);
                            g_iLastNum = iNum;                        
                            Debug("newiNum=" + (string)iNum);
                        }
                        else
                        {
                            integer iIndex = llListFindList(g_lModes, [sValue]);
                            if (iIndex != -1)
                            {
                                CamMode(sValue);
                                g_iLastNum = iNum;
                                Notify(kID, "Set " + sValue + " camera mode.", TRUE);
                                SaveSetting(sValue);
                            }
                            else
                            {
                                Notify(kID, "Invalid camera mode: " + sValue, FALSE);
                            }
                        }
                    }   
                    else
                    {
                        Notify(kID, "Sorry, cam settings have already been set by someone outranking you.", FALSE);
                    }   
                    
                    if (sLastValue == "returnmenu")
                    {
                        //give the cam menu back to kID
                        CamMenu(kID);
                    }                              
                }
                else
                {
                    Notify(kID, "Permissions error: Can not control camera.", FALSE);
                }
                
            } 
            else if (sCommand == "camto")
            {
                if (!g_iLastNum || iNum <= g_iLastNum)
                {
                    CamFocus((vector)sValue, (rotation)sValue2);
                    g_iLastNum = iNum;                    
                }
                else
                {
                    Notify(kID, "Sorry, cam settings have already been set by someone outranking you.", FALSE);
                }
            }
            else if (sCommand == "camdump")
            {
                g_rBroadChan = (integer)sValue;
                integer g_fReapeat = (integer)sValue2;
                ChatCamParams(g_rBroadChan);
                if (g_fReapeat)
                {
                    g_iSync2Me = TRUE;
                    llSetTimerEvent(g_fReapeat);
                }
            }
            else if (kID == g_kWearer && sStr == "runaway")
            {
                ClearCam();
                llResetScript();
            }
            else if (iNum == COMMAND_OWNER && sStr == "reset")
            {
                ClearCam();
                llResetScript();
            }
        }
        else if (iNum == COMMAND_SAFEWORD)
        {
            ClearCam();
            llResetScript();
        }
        else if (iNum == SUBMENU && sStr == g_sMyMenu)
        {
            CamMenu(kID);
        }    
        else if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(LINK_SET, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sMyMenu, "");
        }    
        else if (iNum == LOCALSETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["=", ","], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            integer iNum = (integer)llList2String(lParams, 2);
            if (sToken == g_sDBToken)
            {
                if (llGetPermissions() & PERMISSION_CONTROL_CAMERA)
                {
                    if (sValue == "freeze")
                    {
                        LockCam();
                    }
                    else if (~llListFindList(g_lModes, [sValue]))
                    {
                        CamMode(sValue);
                    }
                    g_iLastNum = iNum;                    
                }
            }            
        }
        else if (iNum == DIALOG_RESPONSE)
        {
            if (kID == g_kMenuID)
            {
                //got a menu response meant for us.  pull out values
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);          
                string sMessage = llList2String(lMenuParams, 1);                                         
                integer iPage = (integer)llList2String(lMenuParams, 2); 
                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, SUBMENU, g_sParentMenu, kAv);
                }
                else
                {
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "cam " + llToLower(sMessage) + " returnmenu", kAv);
                }                              
            }
        }
    }
    
    timer()
    {       
        //handle cam pos/rot changes 
        if (g_iSync2Me)
        {
            vector vNewPos = llGetCameraPos();
            rotation rNewRot = llGetCameraRot();
            if (vNewPos != g_vCamPos || rNewRot != g_rCamRot)
            {
                ChatCamParams(g_rBroadChan);
            }
        }
        else
        {
            llSetTimerEvent(0.0);            
        }
    }    
}