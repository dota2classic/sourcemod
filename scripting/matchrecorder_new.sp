#include <sourcemod>
#include <sdktools>
// #include <sdkhooks>
#include <smjansson>
#include <steamworks>
#include <d2c>

#pragma newdecls required
//# export interface PlayerInMatchDTO {
//#   readonly steam_id: string;
//#   readonly team: number;
//#   readonly kills: number;
//#   readonly deaths: number;
//#   readonly assists: number;
//#   readonly level: number;
//#   readonly items: string[];
//#   readonly gpm: number;
//#   readonly xpm: number;
//#   readonly last_hits: number;
//#   readonly denies: number;
//#
//#   readonly hero: string;
//# }
//#
//# export class GameResultsEvent {
//#   constructor(
//#     public readonly matchId: number,
//#     public readonly radiantWin: boolean,
//#     public readonly duration: number,
//#     public readonly type: MatchmakingMode,
//#     public readonly timestamp: number,
//#     public readonly server: string,
//#     public readonly players: PlayerInMatchDTO[],
//#   ) {}
//# }


int match_id;
int game_mode;
char server_url[40];
Handle matchData;
char callbackURL[1024];

int expected_player_count = 0;


public void OnMapStart()
{
	PrintToServer("Map start called");
    PopulatePlayerDataInPlayerResource();
}

public void OnPluginStart()
{
	
	PrintToServer("PLUGIN LOADED");
	ReadCallbackURL();
	
	ReadMatchData();
	
	
	HookEvent("dota_match_done", OnMatchFinish, EventHookMode:0);
	HookEvent("game_rules_state_change", OnMatchStart, EventHookMode:0)

	AddCommandListener(Command_jointeam, "jointeam");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	CreateTimer(10.0, SetPlayersToStartGame);
}

public void ReadMatchData(){
	char buffer[4096];
	GetCommandLineParamJson("-match", buffer, sizeof(buffer), "{}");
	
	
	PrintToServer("%s", buffer);
	
	matchData = json_load(buffer);

	match_id = json_object_get_int(matchData, "matchId");
	game_mode = json_object_get_int(matchData, "mode");
	PrintToServer("Match ID: %d", match_id);
	PrintToServer("Mode: %d", match_id);


	Handle players = json_object_get(matchData, "players");
	expected_player_count = json_array_size(players);

	// json_object_get_string(hObj, "server_url", server_url, sizeof(server_url))
	
}

public void ReadCallbackURL(){
	GetCommandLineParamStr("-callback", callbackURL, sizeof(callbackURL), "#NO_CALLBACK_URL");
	PrintToServer("Callback URL: %s", callbackURL);
}

public void GetAssignedPlayerName(int index, char[] buffer, int bufSize){
	Handle players = json_object_get(matchData, "players");
	Handle plr = json_array_get(players, index);
	json_object_get_string(plr, "name", buffer, bufSize);
}

public int GetAssignedPlayerTeamID(int index){
	Handle players = json_object_get(matchData, "players");
	Handle plr = json_array_get(players, index);
	return json_object_get_int(plr, "team");
}

public int GetAssignedPlayerSteamID(int index){
	Handle players = json_object_get(matchData, "players");
	Handle plr = json_array_get(players, index);
	return json_object_get_int(plr, "steam32");
}


public void AssignPlayerSlot(int pr, int steamIdOffset, int teamOffset, int nameOffset, int i, int steamId32, int team, char[] name)
{
	PrintToServer("Reserve slot for %s at team %d", name, team);
	SetEntData(pr, i * 8 + steamIdOffset, steamId32, 4, true);
	SetEntData(pr, i * 8 + steamIdOffset + 4, any:17825793, 4, true);
	SetEntData(pr, i * 4 + teamOffset, team, 4, true);
	SetEntData(pr, i * 4 + nameOffset, UTIL_AllocPooledString(name), 4, true);
	return 0;
}

int UTIL_AllocPooledString(char[] value){
	int m_iName = -1;
	if (m_iName == -1)
	{
		m_iName = FindSendPropInfo("CBaseEntity", "m_iName");
	}
	int helperEnt = FindEntityByClassname(-1, "*");
	int backup = GetEntData(helperEnt, m_iName, 4);
	DispatchKeyValue(helperEnt, "targetname", value);
	int ret = GetEntData(helperEnt, m_iName, 4);
	SetEntData(helperEnt, m_iName, backup, 4, false);
	return ret;
}


public void PopulatePlayerDataInPlayerResource()
{
	int pr = GetPlayerResourceEntity();
	int id_offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
	int team_offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerTeams");
	int name_offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iszPlayerNames");
	int radiantIndex;
	int direIndex = 5;
	char name[32];
	Handle players = json_object_get(matchData, "players");
	for(int i =0;i < json_array_size(players); i++)
	{
		GetAssignedPlayerName(i, name, sizeof(name));
		int teamID = GetAssignedPlayerTeamID(i);
		if (teamID == 2 && radiantIndex < 5)
		{
			AssignPlayerSlot(pr, id_offset, team_offset, name_offset, radiantIndex, GetAssignedPlayerSteamID(i), teamID, name);
			radiantIndex++;
		}
		else if (teamID == 3 && direIndex < 10)
		{
			AssignPlayerSlot(pr, id_offset, team_offset, name_offset, direIndex, GetAssignedPlayerSteamID(i), teamID, name);
			direIndex++;
		}
	}
}

public bool PlayerInMatchJSON(Handle hObj, int index){
	char steamid[20]
	bool hasPlayer = GetSteamid(index, steamid)

	if(!hasPlayer){
		return false;
	}

	char heroName[40]
	GetHero(index, heroName)


	json_object_set_new(hObj, "hero", json_string(heroName));
	json_object_set_new(hObj, "steam_id", json_string(steamid));
	json_object_set_new(hObj, "team", json_integer( GetTeam(index) ));
	json_object_set_new(hObj, "level", json_integer( GetLevel(index) ));

	json_object_set_new(hObj, "kills", json_integer( GetKills(index) ));
	json_object_set_new(hObj, "deaths", json_integer( GetDeaths(index) ));
	json_object_set_new(hObj, "assists", json_integer( GetAssists(index) ));

	json_object_set_new(hObj, "gpm", json_integer(  GetGPM(index) ));
	json_object_set_new(hObj, "xpm", json_integer(  GetXPM(index) ));

	json_object_set_new(hObj, "last_hits", json_integer(  GetLasthits(index) ));
	json_object_set_new(hObj, "denies", json_integer( GetDenies(index) ));

	Handle hArray = json_array();

	GetItems(index, hArray)




	json_object_set_new(hObj, "items", hArray);

//	CreatePlayerIfNotExists(steamid);
//	InsertPlayerInMatch(matchId, steamid, heroName, team, kills, deaths, assists, level, items, gpm, xpm, lastHits, denies);
	return true
}

public void GenerateMatchResults(){

	int winnerTeam = GameRules_GetProp("m_nGameWinner", 4, 0);
	bool isRadiantWin = winnerTeam == 2;

	Handle obj = json_object();
	json_object_set_new(obj, "matchId", json_integer(match_id));
	json_object_set_new(obj, "radiantWin", json_boolean(isRadiantWin));
	json_object_set_new(obj, "duration", json_integer(GetDuration()));
	json_object_set_new(obj, "type", json_integer(game_mode));
	json_object_set_new(obj, "timestamp", json_integer(GetTime()));
	json_object_set_new(obj, "server", json_string(server_url));
	Handle hArray = json_array();

	int heroCount = 0;

	for (int i = 0; i <= 10; i++){
		PrintToServer("Saving for player %d", i)
		Handle pObj = json_object();
		bool good = PlayerInMatchJSON(pObj, i);
		PrintToServer("%d", good)
		if(good){
			json_array_append(hArray, pObj)
			heroCount++;
		}
	}
	if(heroCount != 2 && heroCount != 10){
		PrintToChatAll("Матч не будет сохранен: неполная игра");
		return;

	}

	json_object_set_new(obj, "players", hArray);
	char sJSON[10000];
	json_dump(obj, sJSON, sizeof(sJSON), 0);
	PrintToServer(sJSON)

	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, "http://localhost:5001/match_results")
	if(request == null){
		PrintToServer("Request is null.")
		return;
	}

	SteamWorks_SetHTTPRequestRawPostBody(request, "application/json; charset=UTF-8", sJSON, strlen(sJSON));
	SteamWorks_SetHTTPRequestNetworkActivityTimeout(request, 30);
	SteamWorks_SetHTTPCallbacks(request, HTTPCompleted, HeadersReceived, HTTPDataReceive);

	SteamWorks_SendHTTPRequest(request);


}

public int HTTPCompleted(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statuscode, any data, any data2) {
	PrintToServer("HTTP Complted")
}

public int HTTPDataReceive(Handle request, bool failure, int offset, int statuscode, any dp) {
	PrintToServer("Data received %d", statuscode)
	if(statuscode == 200){
		PrintToChatAll("Матч сохранен.")
	}
	delete request;
}

public int HeadersReceived(Handle request, bool failure, any data, any datapack) {
	PrintToServer("Headers received")
}

public void OnClientPutInServer(int client)
{

	if(!IsFakeClient(client)){
		int steamId = GetSteamAccountID(client);


		int team = GetTeamForSteamID(steamId)
		if(team != -1){
			ChangeClientTeam(client, team);
		}else{
			KickClient(client, "Вы не участник игры");
		}


	}
}


public Action Command_jointeam(int client, const char[] command, int args)
{
	return Plugin_Handled;
}




public Action SetPlayersToStartGame(Handle timer){
	if(game_mode == GameMode_Solomid){
		SetPlayersToStart(2);
	}else{
		SetPlayersToStart(10);
	}
}


public Action Command_Test(int args)
{
	PrintToServer("%d", match_id)
	return Plugin_Handled;
}


public void GetItems(int index, Handle items){
	int hero = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", index);


	for (int i = 0; i < 6; ++i){
		int item = GetEntPropEnt(hero, Prop_Send, "m_hItems", i);

		char classname[200];
		if (!IsValidEntity(item)){
			classname = "item_emptyitembg"
		}else{
			GetEdictClassname(item, classname, sizeof(classname));
		}

		json_array_append_new(items, json_string(classname));
	}
}


public Action Command_Say(int client, const char[] command, int argc)
{
	char sayString[32];
	GetCmdArg(1, sayString, sizeof(sayString));
	GetCmdArgString(sayString, sizeof(sayString));
	StripQuotes(sayString);
	if(!strcmp(sayString,"-save",false))
	{
		PopulatePlayerDataInPlayerResource();
		// OnMatchFinished(false);
	}
}

public int GetTeamForSteamID(int steamId){
	
	Handle players = json_object_get(matchData, "players");
	for(int iElement = 0; iElement < json_array_size(players); iElement++) {
		Handle plr = json_array_get(players, iElement);
		int check = json_object_get_int(plr, "steam32");
		if(check == steamId){
			return json_object_get_int(plr, "team");
		}
	}
	
	return -1;
}




public Action OnMatchStart(Handle event, char[] name, bool dontBroadcast){
	int gameState = GameRules_GetProp("m_nGameState");
	
	// GameRules


	if(gameState == 3){
		// HERO_SELECTION
		// check if all players are here
		if(GetPlayersCount() < expected_player_count){
			// not enough players
		}
	}
}

public Action OnMatchFinish(Handle event, char[] name, bool dontBroadcast){
	OnMatchFinished(true);
}

public void OnMatchFinished(bool shutdown){

	if(shutdown){
		CreateTimer(60.0, Shutdown);
		PrintToChatAll("Сервер отключится через минуту");
	}
	GenerateMatchResults();
}

public Action Shutdown(Handle timer)
{
	ServerCommand("exit");
}