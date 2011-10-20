string g_sHTTPDB = "http://data.mycollar.org/";
string g_sHTTPDB2 = "http://data.collardb.com/";
list g_sTokenIDs;
key g_kAllID;
key g_kCheckID;
key g_kWearer = NULL_KEY;
string ALLTOKEN = "_all";

// Save a value to httpdb with the specified name.
HTTPDBSave( string sName, string sValue )
{
    llHTTPRequest( g_sHTTPDB2 + "db/" + sName, [HTTP_METHOD, "PUT"], sValue );
    llSleep(1.0);//sleep added to prevent hitting the sim's http throttle limit
}

init()
{
    if (g_kWearer == NULL_KEY)
    {//if we just started, save owner key
        g_kWearer = llGetOwner();
    }
    else if (g_kWearer != llGetOwner())
    {//we've changed hands.  reset script
        llResetScript();
    }
    
    g_kCheckID = llHTTPRequest(g_sHTTPDB2 + "db/imported", [HTTP_METHOD, "GET"], "");
}


default
{
    state_entry()
    {
        //check if we're in an updater.  if so, don't do regular startup routine.
        if (llSubStringIndex(llGetObjectName(), "CollarDBUpdater") == 0)
        {
            //we're in an updater. go to sleep
            llSetScriptState(llGetScriptName(), FALSE);
        }
        else
        {        
            init();
        }
    }
    
    on_rez(integer iParam)
    {
        //check if we're in an updater.  if so, don't do regular startup routine.
        if (llSubStringIndex(llGetObjectName(), "CollarDBUpdater") == 0)
        {
            //we're in an updater. go to sleep
            llSetScriptState(llGetScriptName(), FALSE);
        }
        else
        {        
            init();
        }
    }
    
    http_response(key kID, integer iStatus, list lMeta, string sBody)
    {
        string sOwners;
    	  if (kID == g_kCheckID)
    	  {
    	    	if (iStatus != 200)
    	    	{
  	    	    g_kAllID = llHTTPRequest(g_sHTTPDB + "db/" + ALLTOKEN, [HTTP_METHOD, "GET"], "");
    	    	}
    	  } 	
        else if (kID == g_kAllID)
        {
            if (iStatus == 200)
            {
                //got all settings page, parse it
                list g_iLines = llParseString2List(sBody, ["\n"], []);
                integer iStop = llGetListLength(g_iLines);
                integer n;
                for (n = 0; n < iStop; n++)
                {
                    list lParams = llParseString2List(llList2String(g_iLines, n), ["="], []);
                    string sToken = llList2String(lParams, 0);
                    string sValue = llList2String(lParams, 1);
                    HTTPDBSave(sToken,sValue);
                }
    	    	    HTTPDBSave("imported","1");
                llRemoveInventory(llGetScriptName());
            }
        }
    }
}    