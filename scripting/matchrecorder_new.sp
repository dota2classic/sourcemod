#include <sourcemod>
#include <sdktools>
#include <d2c>
#include <ripext>

#pragma newdecls required
#pragma dynamic 131072



// enum DOTA_GameState : int {
//   DOTA_GAMERULES_STATE_INIT = 0,
//   DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD = 1,
//   DOTA_GAMERULES_STATE_HERO_SELECTION = 2,
//   DOTA_GAMERULES_STATE_STRATEGY_TIME = 3,
//   DOTA_GAMERULES_STATE_PRE_GAME = 4,
//   DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 5,
//   DOTA_GAMERULES_STATE_POST_GAME = 6,
//   DOTA_GAMERULES_STATE_DISCONNECT = 7,
//   DOTA_GAMERULES_STATE_TEAM_SHOWCASE = 8,
//   DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP = 9,
//   DOTA_GAMERULES_STATE_WAIT_FOR_MAP_TO_LOAD = 10,
//   DOTA_GAMERULES_STATE_SCENARIO_SETUP = 11,
//   DOTA_GAMERULES_STATE_LAST = 12
// }

int match_id;
int lobbyType;
char server_url[128];
JSONObject matchData;
JSONObject GSMatchInfo;

char callbackURL[1024];
char logfile[256];

int expected_player_count = 0;

HTTPClient client;

int abandonCount = 0;


// NATIVE IMPLEMENTATION

int Native_OnAbandon(Handle plugin, int params){
	int steamID = GetNativeCell(1);
	ReportAbandonedPlayer(steamID, abandonCount);
	if(abandonCount == 0){
		PrintToChatAll("Игрок покинул игру и испортил матч.");
		PrintToChatAll("Если ты покинешь игру, то потеряешь рейтинг, но не получишь бан поиска.");
		PrintToChatAll("Покинув игру, ты еще больше подставишь ваших союзников.");
	}

	abandonCount++;
	return 0;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("OnAbandon", Native_OnAbandon);
	return APLRes_Success;
}
//

public void OnMapStart()
{
	PrintToServer("Map start called");
    PopulatePlayerDataInPlayerResource();


    // Start recording
    StartRecording();

    SetPlayersToStart(expected_player_count);

    PrintToServer("lobby type is: %d", lobbyType)
    if(lobbyType == 7){
    	// Bot lobby
    	PrintToServer("SV_CHEATS 1 CALL");
    	ServerCommand("sv_cheats 1");

    	PrintToServer("dota_bot_set_difficulty 0 CALL");
    	ServerCommand("dota_bot_set_difficulty 0");


        PrintToServer("dota_bot_populate CALL");
    	ServerCommand("dota_bot_populate");

    	PrintToServer("SV_CHEATS 0 CALL");
    	// ServerCommand("sv_cheats 0");
		// PopulateBots(2); // 2 = hard
    }
}

public void OnPluginStart()
{
	int iPort = GetConVarInt(FindConVar( "hostport" ));

	PrintToServer("PLUGIN LOADED %d", iPort);

	ReadMatchData();


	// Disable pause on loading

	HookEvent("dota_match_done", OnMatchFinish, EventHookMode:0);
	HookEvent("game_rules_state_change", OnGameRulesStateChange, EventHookMode:0)


	AddCommandListener(Command_jointeam, "jointeam");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	client = new HTTPClient("http://localhost:7777");

	GetCommandLineParamStr("+con_logfile", logfile, 256, "logs/");
	if (StrContains(logfile, ".log", true) == -1)
	{
		StrCat(logfile, sizeof(logfile), ".log");
	}

	PrintToServer("LogFile %s", logfile);


	CreateTimer(4.0, OnGameUpdate, 0, TIMER_REPEAT);
	CreateTimer(1.0, CheckIsGameViable, 0, TIMER_REPEAT);

    RegServerCmd("test1", Command_Test);
//    Test123();
}

public void StartRecording(){
    PrintToServer("StartRecording called");
    ServerCommand("tv_record replays/%d.dem", match_id);
    PrintToServer("Server command executed: tv_record replays/%d.dem", match_id);
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
	if(strlen(buffer) == 0){
		strcopy(buffer, bufSize, "Player")
	}
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
	for(int i = 0;i < players.Length; i++)
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

	bool hasPlayer = IsValidEntity(GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", index));

	if(!hasPlayer){
		return false;
	}

	char heroName[40]
	GetHero(index, heroName)

	matchResult.SetString("hero", heroName);

	bool hasParty = GetPartyIdForSteamId(steamid, heroName, sizeof(heroName));
	if(hasParty){
		matchResult.SetString("party_id", heroName);
	} else {
		matchResult.SetNull("party_id")
	}

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



	int conStatus = GetConnectionState(index);
	matchResult.SetInt("connection", conStatus);


	JSONArray items = new JSONArray();

	GetItems(index, items)
	matchResult.Set("items", items);

	return true;
}

public void GenerateMatchResults(bool save){

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

	for (int i = 0; i < 10; i++){
		JSONObject playerObject = new JSONObject();

		bool good = PlayerInMatchJSON(playerObject, i);
		PrintToServer("PIM [%d] processed, ok: %d", i, good);
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

	if(save){
		client.Post("match_results", dto, OnMatchSaved);
	}
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



public void OnClientPutInServer(int client)
{

	if(!IsFakeClient(client)){
		int steamId = GetSteamAccountID(client);


		int team = GetTeamForSteamID(steamId)
		if(team != -1){
			ChangeClientTeam(client, team);
			ReportPlayerConnected(client, steamId);
		}else{
			KickClient(client, "Вы не участник игры");
		}


	}
}


public Action Command_jointeam(int client, const char[] command, int args)
{
	return Plugin_Handled;
}


public Action Command_Test(int args)
{
	GenerateMatchResults(false);
//	Tests()
	return Plugin_Handled;
}


public void GetItems(int index, JSONArray items){
	int hero = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", index);


	for (int i = 0; i < 6; ++i){
		int item = GetEntPropEnt(hero, Prop_Send, "m_hItems", i);

		char classname[200];
		if (!IsValidEntity(item)){
			classname = "item_empty"
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
		// OnMatchFinished(false);
//		Tests();
	}
}


public void Tests(){
	PrintToServer("Stats");
	for (int i = 0; i < 10; i++){
		int some = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iConnectionState", 4, i);
		PrintToServer("%d %b", some, some);
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

public bool GetPartyIdForSteamId(int steamId, char[] partyId, int partyIdSize){
	bool success = false;
	JSONArray players = GSMatchInfo.Get("players");
	for(int iElement = 0; iElement < players.Length; iElement++) {
		JSONObject plr = players.Get(iElement);

		char buffer[32];
		JSONObject pid = plr.Get("playerId");
		pid.GetString("value", buffer, sizeof(buffer));

		delete pid;

		int check = StringToInt(buffer);
		if(check == steamId){
			plr.GetString("partyId", partyId, partyIdSize);
			success = true;
			delete plr;
			break;
		}

		delete plr;
	}

	delete players;

	return success;
}




public Action OnGameRulesStateChange(Handle event, char[] name, bool dontBroadcast){
	int gameState = GameRules_GetProp("m_nGameState");

	// GameRules

	PrintToServer("GameRules change to: %d", gameState);

	if(gameState == DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD) {
		ServerCommand("dota_allow_pause_in_match 0");
		PrintToServer("Disabled pause while waiting for players to connect");
	}else if(gameState == DOTA_GAMERULES_STATE_PRE_GAME) {
		ServerCommand("dota_allow_pause_in_match 1");
		PrintToServer("Enabling pause back: game started");
	} else if(gameState == DOTA_GAMERULES_STATE_DISCONNECT){
		PrintToServer("Players failed to load");
		// Detect leavers
		OnFailedMatch();
	}
}

public Action OnFailedMatch(){
	// Report what caused failed match(who didnt load)
	JSONArray plrs = new JSONArray();
	for (int i = 0; i < 10; i++){
		JSONObject plr = new JSONObject();
		int pid = GetSteamid(i);
		if(pid == 0) continue;
		plr.SetInt("connection", GetConnectionState(i));
		plr.SetInt("steam_id", pid);

		char party_id[64];
		bool good = GetPartyIdForSteamId(pid, party_id, sizeof(party_id));
		if(good){
			plr.SetString("party_id", party_id);
		} else {
			plr.SetNull("party_id");
		}

		plrs.Push(plr);

	}

	JSONObject dto = new JSONObject();
	dto.Set("players", plrs);
	dto.SetInt("match_id", match_id);
	dto.SetString("server", server_url);

	client.Post("failed_match", dto, OnLiveUpdated);

	// And then shutdown
	Shutdown(INVALID_HANDLE);
}


public Action OnMatchFinish(Handle event, char[] name, bool dontBroadcast){
	OnMatchFinished(true);
}

public void OnMatchFinished(bool shutdown){

	if(shutdown){
		CreateTimer(60.0, Shutdown);
		PrintToChatAll("Сервер отключится через минуту");
	}
	GenerateMatchResults(true);
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
	delete items;

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


	char party_id[64];
	GetPartyIdForSteamId(pid, party_id, sizeof(party_id));
	o.SetString("party_id", party_id);

}

public Action OnGameUpdate(Handle timer)
{
	int gameState = GameRules_GetProp("m_nGameState", 4, 0);
	if (gameState > DOTA_GAMERULES_STATE_INIT && gameState < DOTA_GAMERULES_STATE_TEAM_SHOWCASE)
	{
		UpdateLiveMatch(gameState);
	}

}

public void UpdateLiveMatch(DOTA_GameState gameState){
	JSONObject live_match = new JSONObject();

	int gameState = GameRules_GetProp("m_nGameState", 4, 0)

	live_match.SetInt("match_id", match_id);
	live_match.SetInt("matchmaking_mode", lobbyType);
	live_match.SetInt("duration", GetDuration());
	live_match.SetString("server", server_url);
	live_match.SetInt("game_mode", GameRules_GetProp("m_iGameMode", 4, 0));
	live_match.SetInt("game_state", gameState);
	live_match.SetInt("timestamp", GetTime());



	JSONArray heroes = new JSONArray();
	for(int i = 0; i < 10; i++){
		int steam_id = GetSteamid(i);

		int heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", i);

		JSONObject slot = new JSONObject();
		if(IsValidEntity(heroEntity) && gameState >= DOTA_GAMERULES_STATE_PRE_GAME){
			JSONObject o = new JSONObject();
			FillHeroData(o, heroEntity);
			FillPlayerData(o, i);
			slot.Set("hero_data", o);
			delete o;
		}


		int conStatus = GetConnectionState(i);
		slot.SetInt("team", GetTeam(i));
		slot.SetInt("steam_id", steam_id);
		slot.SetInt("connection", conStatus);


		heroes.Push(slot);
		delete slot;
	}
	live_match.Set("heroes", heroes);
	delete heroes;

	client.Post("live_match", live_match, OnLiveUpdated);

	delete live_match;
}

void OnLiveUpdated(HTTPResponse response, any value){

    if (response.Status != HTTPStatus_Created) {
        // Failed to retrieve todo
        PrintToServer("Bad status code %d", response.Status);
        return;
    }

}

public Action CheckIsGameViable(Handle timer)
{
	int gameState = GameRules_GetProp("m_nGameState", 4, 0);
	if (gameState != DOTA_GAMERULES_STATE_PRE_GAME && gameState != DOTA_GAMERULES_STATE_GAME_IN_PROGRESS)
	{
		return Action:0;
	}

	if(!GameHasActivePlayers()){
		PrintToServer("Everybody left the game, i shut down.");
		Shutdown(INVALID_HANDLE);
	}
}

// Check is there any active players at all?
bool GameHasActivePlayers(){

	bool hasActivePlayer = false;

	for(int i = 0; i < 10; i++){
		int pid = GetSteamid(i);

		// It's a bot
		if(pid <= 10) continue;

		int conState = GetConnectionState(i);
		if(conState != 4){
			hasActivePlayer = true;
			break;
		}
	}

	return hasActivePlayer;
}


void ReportPlayerConnected(int clientIndex, int steamID){
	PrintToServer("I send request that player %d did connect", steamID)

	char ip[64];
    GetClientIP(clientIndex, ip, sizeof(ip), true);

	JSONObject connectDto = new JSONObject();
	connectDto.SetInt("steam_id", steamID);
	connectDto.SetInt("match_id", match_id);
	connectDto.SetString("server", server_url);
	connectDto.SetString("ip", ip);

	client.Post("player_connect", connectDto, OnLiveUpdated);

	delete connectDto;
}

void ReportAbandonedPlayer(int steamID, int abandonIndex){
	PrintToServer("I send request that player %d did abandon", steamID);

	JSONObject abandonDto = new JSONObject();
	abandonDto.SetInt("steam_id", steamID);
	abandonDto.SetInt("match_id", match_id);
	abandonDto.SetInt("abandon_index", abandonIndex);
	abandonDto.SetInt("mode", lobbyType);
	abandonDto.SetString("server", server_url);


	client.Post("player_abandon", abandonDto, OnLiveUpdated);

	delete abandonDto;
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
