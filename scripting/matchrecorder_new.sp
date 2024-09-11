#include <sourcemod>
#include <sdktools>
#include <d2c>
#include <ripext>

#pragma newdecls required
#pragma dynamic 131072


int match_id;
int lobbyType;
char server_url[128];
JSONObject matchData;
JSONObject GSMatchInfo;
char callbackURL[1024];

int expected_player_count = 0;

HTTPClient client;

public void OnMapStart()
{
	PrintToServer("Map start called");
    PopulatePlayerDataInPlayerResource();
}

public void OnPluginStart()
{

	int iPort = GetConVarInt(FindConVar( "hostport" ));

	PrintToServer("PLUGIN LOADED %d", iPort);
	
	ReadMatchData();
	
	
	HookEvent("dota_match_done", OnMatchFinish, EventHookMode:0);
	HookEvent("game_rules_state_change", OnMatchStart, EventHookMode:0)
	

	AddCommandListener(Command_jointeam, "jointeam");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	// I don't like it, but it works
	// Try on map start
	CreateTimer(10.0, SetPlayersToStartGame);
	
	client = new HTTPClient("http://localhost:7777");
	
	
	CreateTimer(4.0, OnGameUpdate, 0, TIMER_REPEAT);
	
    RegServerCmd("test1", Command_Test);
    Test123();
}


public void ReadMatchData(){
	char buffer[4096];
	GetCommandLineParamJson("-match", buffer, sizeof(buffer), "{}");
	
	matchData = JSONObject.FromString(buffer);
	
	PrintToServer("%s", buffer);
	
	matchData.GetString("url", server_url, sizeof(server_url));
	match_id = matchData.GetInt("matchId");
	
	GSMatchInfo = matchData.Get("info");
	
	lobbyType = GSMatchInfo.GetInt("mode")

	
	PrintToServer("Match ID: %d", match_id);
	PrintToServer("Mode: %d", lobbyType);
	PrintToServer("Running on server: %s", server_url);


	JSONArray players = GSMatchInfo.Get("players");
	expected_player_count = players.Length;

	
	
}

public JSONObject GetPlayer(int index){
	JSONArray players = GSMatchInfo.Get("players")	
	return players.Get(index);
}

public void GetAssignedPlayerName(int index, char[] buffer, int bufSize){
	JSONObject plr = GetPlayer(index);
	plr.GetString("name", buffer, bufSize);
}

public int GetAssignedPlayerTeamID(int index){
	JSONObject plr = GetPlayer(index);
	return plr.GetInt("team");
}

public int GetAssignedPlayerSteamID(int index){
	JSONObject plr = GetPlayer(index);
	char buffer[32];
	JSONObject pid = plr.Get("playerId");
	pid.GetString("value", buffer, sizeof(buffer));
	return StringToInt(buffer);	
}


public void AssignPlayerSlot(int pr, int steamIdOffset, int teamOffset, int nameOffset, int i, int steamId32, int team, char[] name)
{
	PrintToServer("Reserve slot for %s at team %d", name, team);
	SetEntData(pr, i * 8 + steamIdOffset, steamId32, 4, true);
	SetEntData(pr, i * 8 + steamIdOffset + 4, any:17825793, 4, true); // steam64 bits
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
	JSONArray players = GSMatchInfo.Get("players");
	for(int i =0;i < players.Length; i++)
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

public bool PlayerInMatchJSON(JSONObject matchResult, int index){
	
	int steamid = GetSteamid(index)
	bool hasPlayer = steamid != 0;

	if(!hasPlayer){
		return false;
	}

	char heroName[40]
	GetHero(index, heroName)

	matchResult.SetString("hero", heroName);
	matchResult.SetInt("steam_id", steamid);
	matchResult.SetInt("team",  GetTeam(index) );
	matchResult.SetInt("level",  GetLevel(index) );
	
	matchResult.SetInt("kills",  GetKills(index) );
	matchResult.SetInt("deaths",  GetDeaths(index) );
	matchResult.SetInt("assists",  GetAssists(index) );
	
	matchResult.SetInt("gpm",   GetGPM(index) );
	matchResult.SetInt("xpm",   GetXPM(index) );
	
	matchResult.SetInt("last_hits",   GetLasthits(index) );
	matchResult.SetInt("denies",  GetDenies(index));
	
	matchResult.SetInt("tower_kills", GetIntProperty(index, "m_iTowerKills"));
	matchResult.SetInt("roshan_kills", GetIntProperty(index, "m_iRoshanKills"));
	matchResult.SetFloat("roshan_kills", GetFloatProperty(index, "m_fHealing"));
	
	
	matchResult.SetInt("networth", GetNetworth(index));
	
	
	
	int conStatus = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iConnectionState", 4, index);
	matchResult.SetBool("abandon", conStatus == 3)
	
	
	
	// Note: i think we have to parse logs...
	// TODO: Add tower damage, hero damage
	


	JSONArray items = new JSONArray();

	GetItems(index, items)
	matchResult.Set("items", items);

	return true;
}

public void GenerateMatchResults(){

	int winnerTeam = GameRules_GetProp("m_nGameWinner", 4, 0);
//
	JSONObject dto = new JSONObject();
	dto.SetInt("matchId", match_id);
	dto.SetInt("winner", winnerTeam);
	dto.SetInt("duration", GetDuration());
	dto.SetInt("type", lobbyType);
	dto.SetInt("gameMode", GameRules_GetProp("m_iGameMode", 4, 0));
	dto.SetInt("timestamp", GetTime());
	dto.SetString("server", server_url);
	
	JSONArray players = new JSONArray();
	
	int heroCount = 0;

	for (int i = 0; i <= 10; i++){
		PrintToServer("Saving for player %d", i)
		JSONObject playerObject = new JSONObject();
		
		bool good = PlayerInMatchJSON(playerObject, i);
		PrintToServer("%d", good);
		if(good){
			players.Push(playerObject);
			heroCount++;
		}
	}
	
	dto.Set("players", players);
	
//	if(heroCount != 2 && heroCount != 10){
//		PrintToChatAll("Матч не будет сохранен: неполная игра");
//		return;
//	}
	
	char buffer[12000];
	
	dto.ToString(buffer, sizeof(buffer));
	PrintToServer("%s", buffer);
	
	
	client.Post("match_results", dto, OnMatchSaved);

}

void OnMatchSaved(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_Created) {
        // Failed to retrieve todo
        PrintToServer("Bad status code %d", response.Status);
        return;
    }
	PrintToChatAll("Матч сохранен.");
} 

void OnLiveUpdated(HTTPResponse response, any value){
	
    if (response.Status != HTTPStatus_Created) {
        // Failed to retrieve todo
        PrintToServer("Bad status code %d", response.Status);
        return;
    }
	
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
	SetPlayersToStart(expected_player_count);
}


public Action Command_Test(int args)
{
	GenerateMatchResults();
	return Plugin_Handled;
}


public void GetItems(int index, JSONArray items){
	int hero = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", index);


	for (int i = 0; i < 6; ++i){
		int item = GetEntPropEnt(hero, Prop_Send, "m_hItems", i);

		char classname[200];
		if (!IsValidEntity(item)){
			classname = "item_emptyitembg"
		}else{
			GetEdictClassname(item, classname, sizeof(classname));
		}

		items.PushString(classname);
	}
}


public Action Command_Say(int client, const char[] command, int argc)
{
	char sayString[32];
	GetCmdArg(1, sayString, sizeof(sayString));
	GetCmdArgString(sayString, sizeof(sayString));
	StripQuotes(sayString);
	if(!strcmp(sayString,"-savematch",false))
	{
		// PopulatePlayerDataInPlayerResource();
		OnMatchFinished(false);
	}
}

public int GetTeamForSteamID(int steamId){
	JSONArray players = GSMatchInfo.Get("players");
	for(int iElement = 0; iElement < players.Length; iElement++) {
		JSONObject plr = players.Get(iElement);
		
		char buffer[32];
		JSONObject pid = plr.Get("playerId");
		pid.GetString("value", buffer, sizeof(buffer));
		
		int check = StringToInt(buffer);
		if(check == steamId){
			return plr.GetInt("team");
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

// UPDATER
public bool GetDidRandom(int index)
{
	return GetEntProp(GetPlayerResourceEntity(), PropType:0, "m_bHasRandomed", 4, index);
}

public void GetPosition(int index, float vec[3])
{
	GetEntPropVector(index, PropType:0, "m_vecOrigin", vec, 0);
}


public void FillHeroData(JSONObject obj, int hero){
	
	// Is Bot?

	// Position on map
	float vec[3];
	GetEntPropVector(hero, Prop_Send, "m_vecOrigin", vec);
	float full = 14144.0;
	float half = full / 2;
	
	obj.SetFloat("pos_x", (vec[0] + half) / full);
	obj.SetFloat("pos_y", (vec[1] + half) / full);
	
	// Angle
	float angle = GetEntPropFloat(hero, Prop_Send, "m_angRotation[1]");
	obj.SetFloat("angle", angle);
	
	// Hero name
	char heroname[40];
	GetEntityClassname(hero, heroname, sizeof(heroname));
	obj.SetString("hero", heroname)
	
	// Level
	obj.SetInt("level", GetEntProp(hero, Prop_Send, "m_iCurrentLevel"))
	
	// Health and mana
	int max_health = GetEntProp(hero, Prop_Send, "m_iMaxHealth");
	int health = GetEntProp(hero, Prop_Send, "m_iHealth");
	obj.SetInt("health", health);
	obj.SetInt("max_health", max_health);
	
	float max_mana = GetEntPropFloat(hero, Prop_Send, "m_flMaxMana");
	float mana = GetEntPropFloat(hero, Prop_Send, "m_flMana");
	obj.SetFloat("mana", mana);
	obj.SetFloat("max_mana", max_mana);
	
	
	// Respawn timer, todo: how it works?>
	int duration = GetDuration()
	float respawn_time = GetEntPropFloat(hero, Prop_Send, "m_flRespawnTime");
	obj.SetFloat("respawn_time", respawn_time);
	
	float m_flRespawnTimePenalty = GetEntPropFloat(hero, Prop_Send, "m_flRespawnTimePenalty");
	obj.SetInt("r_duration", duration);
	
	
	// Items
	JSONArray items = new JSONArray();
	char buf[64];
	for(int i = 0; i < 6; i++){
		int item = GetEntPropEnt(hero, Prop_Send, "m_hItems", i);
		if(!IsValidEntity(item)){
			items.PushString("item_empty");
		}else {
			GetEntPropString(item, Prop_Send, "m_iName", buf, sizeof(buf))
			items.PushString(buf);
		}
	}
	obj.Set("items", items);
	
	return obj;
}

public void FillPlayerData(JSONObject o, int player){
	o.SetInt("kills", GetKills(player));
	o.SetInt("deaths", GetDeaths(player));
	o.SetInt("assists", GetAssists(player));
	o.SetInt("team", GetTeam(player));
	
	

	int pid = GetSteamid(player);
	o.SetInt("steam_id", pid);
	o.SetBool("bot", pid <= 10);
	
}

public Action OnGameUpdate(Handle timer)
{
	int gameState = GameRules_GetProp("m_nGameState", 4, 0);
	if (gameState != 4 && gameState != 5)
	{
		return Action:0;
	}
	UpdateLiveMatch();
}


public void UpdateLiveMatch(){
	char buffer[32768];
	
	JSONObject match = new JSONObject();
	match.SetInt("match_id", match_id);
	match.SetInt("matchmaking_mode", lobbyType);
	match.SetInt("duration", GetDuration());
	match.SetString("server", server_url);
	// get it here
	match.SetInt("game_mode", GameRules_GetProp("m_iGameMode", 4, 0));
	match.SetInt("timestamp", GetTime());
	
	
	
	JSONArray heroes = new JSONArray();
	for(int i = 0; i < 10; i++){
		
		int heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", i);
		if(!IsValidEntity(heroEntity)) continue;
		
		JSONObject o = new JSONObject();
		FillHeroData(o, heroEntity);	
		FillPlayerData(o, i);
		
		heroes.Push(o);
		
//		o.ToString(buffer, sizeof(buffer));
//		PrintToServer(buffer);
	}
	
	match.Set("heroes", heroes);

	
//	match.ToString(buffer, sizeof(buffer));
//	PrintToServer(buffer);
		
	client.Post("live_match", match, OnLiveUpdated);
	
	
}

void Test123(){
	
	
//	int i = -1;
//	int ent = FindEntityByClassname(i, "npc_dota_tower");

//	PrintToServer("Hey :)")
//	int spec = FindEntityByClassname(-1, "dota_data_spectator");
//	
//	for(int i = 0; i < 10; i++){
//			int totalGold = GetEntProp(spec, Prop_Send, "m_iNetWorth", 4, i);
//	
//		PrintToServer("[%d] %d networth", i, totalGold);
//	}
//	for(int i = 0; i < 10; i++){
//		PrintToServer("%d events", GetIntProperty(i, "m_iMetaLevel"));
//		
//	}

//
//	for(int i = 0; i < 5000; i++){
//		if(!IsValidEntity(i)) continue;
//		
//		char nc[64];
//		GetEntityNetClass(i, nc, sizeof(nc));
//		
//		if(!strcmp(nc, "CDOTA_DataSpectator", false)){
//			GetEntityClassname(i, nc, sizeof(nc))
//			PrintToServer("%s c", nc);
//		}
//	}
	

}