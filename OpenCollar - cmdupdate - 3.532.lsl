//OpenCollar - cmdupdate - 3.434
//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life.  See "OpenCollar License" for details.

string HTTPDB = "http://data.mycollar.org/db/"; //db url
key    reqid_load;                          // request id

integer HTTPDB_SAVE = 2000;//scripts send messages on this channel to have settings saved to httpdb
integer HTTPDB_RESPONSE = 2002;//the httpdb script will send responses on this channel
integer HTTPDB_DELETE = 2003;//delete token from DB

list tokenids;//strided list of token names and their corresponding request ids, so that token names can be returned in link messages

// Save a value to httpdb with the specified name.
httpdb_save( string name, string value )
{
    llHTTPRequest( HTTPDB + name, [HTTP_METHOD, "PUT"], value );
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit
}

// Load named data from httpdb.
httpdb_load( string name )
{
    tokenids += [name, llHTTPRequest( HTTPDB + name, [HTTP_METHOD, "GET"], "" )];
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit
}

httpdb_delete(string name) {
    //httpdb_request( HTTPDB_DELETE, "DELETE", name, "" );
    llHTTPRequest(HTTPDB + name, [HTTP_METHOD, "DELETE"], "");
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit
}

default
{
    state_entry()
    {
        //httpdb_load("owner");
        //httpdb_load("secowners");
        llSetTimerEvent(300);
    }

    on_rez(integer param)
    {
        //httpdb_load("owner");
        //httpdb_load("secowners");
    }

    http_response( key id, integer status, list meta, string body )
    {
        integer index = llListFindList(tokenids, [id]);
        if ( index != -1 )
        {
            string token = llList2String(tokenids, index - 1);
            if (status == 200)
            {
                httpdb_save(token, body);;
            }
            //remove token, id from list
            tokenids = llDeleteSubList(tokenids, index - 1, index);
            if(tokenids ==[])
            {
                //llSetTimerEvent(120);
            }
        }
    }
    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == HTTPDB_RESPONSE && sStr == "remoteon=1")
        {
            llSleep(1);
            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "httpon=1", NULL_KEY);
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, "remoteon", NULL_KEY);
        }
        else if (iNum == HTTPDB_RESPONSE && sStr == "remoteon=0")
        {
            llSleep(1);
            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "httpon=0", NULL_KEY);
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, "remoteon", NULL_KEY);
        }
        else if ((iNum == HTTPDB_RESPONSE) && (llGetSubString(sStr, 0, 10) == "badwordanim"))
        {
            llSleep(1);
            list lParams = llParseString2List(sStr, ["="], []);
            string sValue = llList2String(lParams, 1);
            llMessageLinked(LINK_THIS, HTTPDB_SAVE, "badwordsanim="+sValue, NULL_KEY);
            llMessageLinked(LINK_THIS, HTTPDB_DELETE, "badwordanim", NULL_KEY);
        }
    }
    timer()
    {
        llRemoveInventory(llGetScriptName());
    }
}