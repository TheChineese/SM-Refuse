#include <sourcemod>
#include <multicolors>

#undef REQUIRE_PLUGIN
#include <updater>
#include <freeday>

#define UPDATE_URL    "http://bitbucket.toastdev.de/sourcemod-plugins/raw/master/Refuse.txt"

public Plugin:myinfo = 
{
	name = "Refuse 2.0",
	author = "Toast",
	description = "A new refuse plugin for Jail",
	version = "1.0.4",
	url = "bitbucket.toastdev.de"
}
new Handle:c_RefuseTime;
new Handle:c_RefuseAmount;
new Float:RefuseTime_Float;
new bool:plugin_freeday = false;
new RefuseAmount;
new RefuseTime;
new MaxRefuse[MAXPLAYERS + 1];
new CurrentRefuseAmount[MAXPLAYERS + 1];
new CurrentlyRefusing;
new Refusing[MAXPLAYERS + 1];
new RefuseQuestioner;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("FREEDAY_SetFreeday");
	MarkNativeAsOptional("FREEDAY_HasFreeday");
	MarkNativeAsOptional("Updater_AddPlugin");
	return APLRes_Success;
}

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_disconnect", PlayerDissconnect);
	HookEvent("player_activate", PlayerJoin);
	
	c_RefuseTime = CreateConVar("refuse_time", "4.0", "The time Terrorists can refuse");
	c_RefuseAmount = CreateConVar("refuse_amount", "1.0", "How often Terrorists can refuse by Default");
	HookConVarChange(c_RefuseTime, ConVarChanged);
	HookConVarChange(c_RefuseAmount, ConVarChanged);
	AutoExecConfig();
	c_RefuseTime = FindConVar("refuse_time");
	c_RefuseAmount = FindConVar("refuse_amount");
	
	RefuseTime = GetConVarInt(c_RefuseTime);
	RefuseTime_Float = GetConVarFloat(c_RefuseTime);
	RefuseAmount = GetConVarInt(c_RefuseAmount);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		MaxRefuse[i] = RefuseAmount;
	}
	
	RegConsoleCmd("sm_v", RefuseCommandHandler);
	
	LoadTranslations("refuse.phrases");
	
	CurrentlyRefusing = 0;
	
	if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
	if (LibraryExists("freeday"))
    {
        plugin_freeday = true;
    }
}
public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL)
    }
    if (StrEqual(name, "freeday"))
    {
        plugin_freeday = true;
    }
}
public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "freeday"))
    {
        plugin_freeday = false;
    }
}
public ConVarChanged(Handle:cvar, const String:oldValue[], const String:newValue[]) {
	
	if(cvar == c_RefuseTime){
		RefuseTime = StringToInt(newValue);
		RefuseTime_Float = StringToFloat(newValue);
		
	}
	else if(cvar == c_RefuseAmount){
		
		RefuseAmount = StringToInt(newValue);
		for (new i = 1; i <= MaxClients; i++)
		{
			MaxRefuse[i] = RefuseAmount;
		}
	}
	
}

public PlayerDissconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid;
	userid = GetEventInt(event, "userid");
	new client;
	client = GetClientOfUserId(userid);
	MaxRefuse[client] = RefuseAmount;
	CurrentRefuseAmount[client] = 0;
	Refusing[client] = 0;
	
}
public PlayerJoin(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid;
	userid = GetEventInt(event, "userid");
	new client;
	client = GetClientOfUserId(userid);
	MaxRefuse[client] = RefuseAmount;
	CurrentRefuseAmount[client] = 0;
	Refusing[client] = 0;
	
}
public PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid;
	userid = GetEventInt(event, "userid");
	new client;
	client = GetClientOfUserId(userid);
	CurrentRefuseAmount[client] = 0;
	Refusing[client] = 0;
}

public Action:RefuseCommandHandler(client, args)
{
	//CT started Refuse Question
	new Team;
	
	Team = GetClientTeam(client);
	
	if(Team == 3){
		if(IsPlayerAlive(client)){
			if(CurrentlyRefusing == 0){
				new bool:all_refused = true;

				for (new i = 1; i <= MaxClients; i++)
				{
					if(IsClientInGame(i))
					{
						if(IsPlayerAlive(i) && GetClientTeam(i) == 2 && CurrentRefuseAmount[i] < MaxRefuse[i]){
							all_refused = false;
						}
					}

				}
				if(all_refused){
					CReplyToCommand(client, "%t %t", "prefix", "error_all_refused");
					return;
				}

				RefuseQuestion(client);
				
				return;	
			}
			else{
				CReplyToCommand(client,"%t %t", "prefix", "error_already_refusing");
				return;
			}
		}
		else{
			CReplyToCommand(client,"%t %t", "prefix", "error_dead");
			return;
		}
	}
	else{
		
		CReplyToCommand(client,"%t %t", "prefix", "error_team_wrong");
		return;
		
	}
}

Action:RefuseQuestion(any:client)
{
	ResetRefusers();
	RefuseQuestioner = client;
	CurrentlyRefusing = 1;
	CPrintToChatAll("%t %t", "prefix", "StartRefusing", RefuseTime);
	updateRefuseAwnser();
	CreateTimer(RefuseTime_Float, RefuseTimer);
	for (new i = 1; i <= MaxClients; i++)
	{
		
		if(IsClientInGame(i)){
			UnmarkRefuser(i);
			if(IsPlayerAlive(i) && GetClientTeam(i) == 2 && CurrentRefuseAmount[i] < MaxRefuse[i])
			{
				displayrefusemenu(i);
			}
		}
	}
	
	
	
}
public Action:RefuseTimer(Handle:timer)
{
	CurrentlyRefusing = 0;
	CPrintToChatAll("%t %t", "prefix", "StopRefusing");
}

displayrefusemenu(client)
{
	new String:string[64];
	new Handle:menu = CreateMenu(RefuseMenuHandler);
	Format(string,sizeof(string),"%t", "RefuseQuestionMenuTitle", LANG_SERVER);
	SetMenuTitle(menu, string);
	Format(string,sizeof(string),"%t", "Refuse", LANG_SERVER);
	AddMenuItem(menu, "refuse", string);
	Format(string,sizeof(string),"%t", "NoRefuse", LANG_SERVER);
	AddMenuItem(menu, "norefuse", string);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, RefuseTime);
}
updateRefuseAwnser()
{	
	if(CurrentlyRefusing == 1)
	{
		new client = RefuseQuestioner;
		new String:string[64];
		new Handle:menu = CreateMenu(RefuseAwnserMenuHandler);
		Format(string,sizeof(string),"%t", "RefuseAwnserMenuTitle", LANG_SERVER);
		SetMenuTitle(menu, string);
		for (new i = 1; i <= MaxClients; i++)
		{
			if(Refusing[i] == 1 && IsClientInGame(i)){
				
				GetClientName(i, string, sizeof(string));
				AddMenuItem(menu, "refuser", string, ITEMDRAW_DISABLED);
			}
		}
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
}

public RefuseMenuHandler(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[64];
		GetMenuItem(menu, param2, info, sizeof(info));
		if(strcmp(info, "refuse") == 0)
		{
			new String:clientname[32];
			GetClientName(client, clientname, sizeof(clientname));
			CurrentRefuseAmount[client] = CurrentRefuseAmount[client] + 1;
			CPrintToChatAll("%t %t", "prefix", "player_refused", clientname);
			Refusing[client] = 1;
			updateRefuseAwnser();
			MarkRefuser(client);
		}
	}
}

public RefuseAwnserMenuHandler(Handle:menu, MenuAction:action, client, param2)
{
	//Nothing
}

MarkRefuser(client)
{
	if(plugin_freeday){
		if(!FREEDAY_HasFreeday(client)){
			SetEntityRenderMode(client,RENDER_TRANSCOLOR);
			SetEntityRenderColor(client, 0, 0, 255, 255);
		}
	}
	else{
		SetEntityRenderMode(client,RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 0, 0, 255, 255);
	}
	
	
}
UnmarkRefuser(client)
{
	if(!FREEDAY_HasFreeday(client)){
		SetEntityRenderMode(client,RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

ResetRefusers(){
	for (new i = 1; i <= MaxClients; i++)
	{
		Refusing[i] = 0;
	}
}