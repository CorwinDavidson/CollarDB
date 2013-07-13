//CollarDB - coupleanim2 - 3.520
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "CollarDB License" for details.
key g_kPartner;
float g_fTimeOut = 30.0;//time for the potential kissee to respond before we give up

//      MESSAGE MAP
integer COMMAND_NOAUTH          = 0xCDB000;
integer COMMAND_OWNER           = 0xCDB500;
integer COMMAND_SECOWNER        = 0xCDB501;
integer COMMAND_GROUP           = 0xCDB502;
integer COMMAND_WEARER          = 0xCDB503;
integer COMMAND_EVERYONE        = 0xCDB504;
integer COMMAND_OBJECT          = 0xCDB506;
integer COMMAND_RLV_RELAY       = 0xCDB507;

integer POPUP_HELP              = -0xCDB001;      

integer HTTPDB_SAVE             = 0xCDB200;     // scripts send messages on this channel to have settings saved to httpdb
                                                // str must be in form of "token=value"
integer HTTPDB_REQUEST          = 0xCDB201;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 0xCDB202;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 0xCDB203;     // delete token from DB
integer HTTPDB_EMPTY            = 0xCDB204;     // sent by httpdb script when a token has no value in the db

integer MENUNAME_REQUEST        = 0xCDB300;
integer MENUNAME_RESPONSE       = 0xCDB301;
integer SUBMENU                 = 0xCDB302;
integer MENUNAME_REMOVE         = 0xCDB303;

integer RLV_CMD                 = 0xCDB600;
integer RLV_REFRESH             = 0xCDB601;     // RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR               = 0xCDB602;     // RLV plugins should clear their restriction lists upon receiving this message.

integer ANIM_START              = 0xCDB700;     // send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP               = 0xCDB701;     // send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST     = 0xCDB702;     // id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE    = 0xCDB703;     // str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START           = 0xCDB704;     // str should be valid anim name.  id should be av
integer CPLANIM_STOP            = 0xCDB705;     // str should be valid anim name.  id should be av


string g_sStopString = "stop";
integer g_iStopChan = 99;
integer g_iListener;

Debug(string sStr)
{
    //llOwnerSay(llGetScriptName() + ": " + sStr);
}

string FirstName(string sName)
{
    return llList2String(llParseString2List(sName, [" "], []), 0);
}

default
{    
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        Debug("linkmessage: " + sStr);        
        if (iNum == CPLANIM_PERMREQUEST)
        {
            g_kPartner = kID;
            llRequestPermissions(g_kPartner, PERMISSION_TRIGGER_ANIMATION);
            llInstantMessage(g_kPartner, FirstName(llKey2Name(llGetOwner())) + " would like give you a " + sStr + ". Click [Yes] to accept." );            
            llSetTimerEvent(g_fTimeOut);
        }
        else if (iNum == CPLANIM_START)
        {
            llStartAnimation(sStr);//note that we don't double check for permissions here, so if the coupleanim1 script sends its messages out of order, this might fail
            g_iListener = llListen(g_iStopChan, "", g_kPartner, g_sStopString);
            llInstantMessage(g_kPartner, "If you would like to stop the animation early, say /" + (string)g_iStopChan + g_sStopString + " to stop.");
            
        }
        else if (iNum == CPLANIM_STOP)
        {//only when the partner is in the same sim else we get an error
            if (llKey2Name(g_kPartner) != "")
            {
                llStopAnimation(sStr);
            }  
        }
    } 
    
    run_time_permissions(integer perm)
    {
        if (perm & PERMISSION_TRIGGER_ANIMATION)
        {
            key kID = llGetPermissionsKey();
            if (kID == g_kPartner)
            {
                llSetTimerEvent(0.0);
                llMessageLinked(LINK_SET, CPLANIM_PERMRESPONSE, "1", g_kPartner);                
            }
            else
            {
                llInstantMessage(kID, "Sorry, but the request timed out.");
            }
        }
    }
    
    timer()
    {
        llSetTimerEvent(0.0);
        llListenRemove(g_iListener);
        llMessageLinked(LINK_SET, CPLANIM_PERMRESPONSE, "0", g_kPartner);
        g_kPartner = NULL_KEY;
    }
    
    listen(integer channel, string sName, key kID, string sMessage)
    {
        Debug("listen: " + sMessage + ", channel=" + (string)channel);
        llListenRemove(g_iListener);
        if (channel == g_iStopChan)
        {//this abuses the GROUP auth a bit but i think it's ok.
            Debug("message on stop channel");
            llMessageLinked(LINK_SET, COMMAND_GROUP, "stopcouples", kID);
        }
    }
    
    on_rez(integer iParam)
    {
        llResetScript();
    }
}