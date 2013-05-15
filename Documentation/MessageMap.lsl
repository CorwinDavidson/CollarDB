//MESSAGE MAP

//relay specific message map
integer CMD_ADDSRC              = 11;
integer CMD_REMSRC              = 12;

integer JSON_REQUEST            = 201;
integer JSON_RESPONSE           = 202;

integer COMMAND_NOAUTH          = 0;
integer COMMAND_COLLAR          = 499;      //added for collar or cuff commands to put ao to pause or standOff
integer COMMAND_OWNER           = 500;
integer COMMAND_SECOWNER        = 501;
integer COMMAND_GROUP           = 502;
integer COMMAND_WEARER          = 503;
integer COMMAND_EVERYONE        = 504;
integer CHAT                    = 505;      // DEPRECATED
integer COMMAND_OBJECT          = 506;
integer COMMAND_RLV_RELAY       = 507;
integer COMMAND_SAFEWORD        = 510;
integer COMMAND_RELAY_SAFEWORD  = 511;
integer COMMAND_BLACKLIST       = 520;
integer COMMAND_WEARERLOCKEDOUT = 521;      // added so when the sub is locked out they can use postions

integer ATTACHMENT_REQUEST      = 600;      // added for attachment auth (garvin)
integer ATTACHMENT_RESPONSE     = 601;      // added for attachment auth (garvin)

integer WEARERLOCKOUT           =620;

integer SEND_IM                 = 1000;     // deprecated.  each script should send its own IMs now.  This is to reduce even the tiny bt of lag caused by having IM slave scripts
integer POPUP_HELP              = 1001;      

integer HTTPDB_SAVE             = 2000;     // scripts send messages on this channel to have settings saved to httpdb
                                            // str must be in form of "token=value"
integer HTTPDB_REQUEST          = 2001;     // when startup, scripts send requests for settings on this channel
integer HTTPDB_RESPONSE         = 2002;     // the httpdb script will send responses on this channel
integer HTTPDB_DELETE           = 2003;     // delete token from DB
integer HTTPDB_EMPTY            = 2004;     // sent by httpdb script when a token has no value in the db
integer HTTPDB_REQUEST_NOCACHE  = 2005;

integer LOCALSETTING_SAVE       = 2500;
integer LOCALSETTING_REQUEST    = 2501;
integer LOCALSETTING_RESPONSE   = 2502;
integer LOCALSETTING_DELETE     = 2503;
integer LOCALSETTING_EMPTY      = 2504;

integer MENUNAME_REQUEST        = 3000;
integer MENUNAME_RESPONSE       = 3001;
integer SUBMENU                 = 3002;
integer MENUNAME_REMOVE         = 3003;

integer RLV_CMD                 = 6000;
integer RLVR_CMD                = 6010;
integer RLV_REFRESH             = 6001;     // RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR               = 6002;     // RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION             = 6003;     // RLV Plugins can recieve the used rl viewer version upon receiving this message..
integer RLV_OFF                 = 6100;     // send to inform plugins that RLV is disabled now, no message or key needed
integer RLV_ON                  = 6101;     // send to inform plugins that RLV is enabled now, no message or key needed

integer ANIM_START              = 7000;     // send this with the name of an anim in the string part of the message to play the anim
integer ANIM_STOP               = 7001;     // send this with the name of an anim in the string part of the message to stop the anim
integer CPLANIM_PERMREQUEST     = 7002;     // id should be av's key, str should be cmd name "hug", "kiss", etc
integer CPLANIM_PERMRESPONSE    = 7003;     // str should be "1" for got perms or "0" for not.  id should be av's key
integer CPLANIM_START           = 7004;     // str should be valid anim name.  id should be av
integer CPLANIM_STOP            = 7005;     // str should be valid anim name.  id should be av

integer UPDATE                  = 10001;

integer DIALOG                  = -9000;
integer DIALOG_RESPONSE         = -9001;
integer DIALOG_TIMEOUT          = -9002;

integer TIMER_EVENT             = -10000;   // str = "start" or "end". For start, either "online" or "realtime".
integer KEY_VISIBLE             = -10100;   // For other things that want to manage showing/hiding keys.
integer KEY_INVISIBLE           = -10100;   // For other things that want to manage showing/hiding keys.

integer COMMAND_PARTICLE        = 20000;
integer COMMAND_LEASH_SENSOR    = 20001;