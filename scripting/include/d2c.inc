#if defined _d2c_helpers
 #endinput
#endif
#define _d2c_helpers

#include <sourcemod>
#include <sdktools>

#include <base64>

 enum DOTA_GameState 
 {
   DOTA_GAMERULES_STATE_INIT = 0,
   DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD = 1,
   DOTA_GAMERULES_STATE_HERO_SELECTION = 2,
   DOTA_GAMERULES_STATE_STRATEGY_TIME = 3,
   DOTA_GAMERULES_STATE_PRE_GAME = 4,
   DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 5,
   DOTA_GAMERULES_STATE_POST_GAME = 6,
   DOTA_GAMERULES_STATE_DISCONNECT = 7,
   DOTA_GAMERULES_STATE_TEAM_SHOWCASE = 8,
   DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP = 9,
   DOTA_GAMERULES_STATE_WAIT_FOR_MAP_TO_LOAD = 10,
   DOTA_GAMERULES_STATE_SCENARIO_SETUP = 11,
   DOTA_GAMERULES_STATE_LAST = 12
 }

enum GameMode 
{ 
	GameMode_Ranked = 0,
	GameMode_Unranked = 1,
	GameMode_Solomid = 2,
	GameMode_Diretide = 3,
	GameMode_Greeviling = 4,
	GameMode_AbilityDraft = 5,
}

native void OnAbandon(steam_id);

public GetIntProperty(index, String:prop[]){
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, prop, 4, index)
}

public Float:GetFloatProperty(index, String:prop[]){
	return GetEntPropFloat(GetPlayerResourceEntity(), Prop_Send, prop, index)
}


public GetDuration(){
	new non_game_time = RoundFloat(GameRules_GetPropFloat("m_flGameStartTime"))
	new total_time = RoundFloat(GameRules_GetPropFloat("m_fGameTime"))
	return total_time - non_game_time;
}

public int GetNetworth(index){
	int spec = FindEntityByClassname(-1, "dota_data_spectator");
	return GetEntProp(spec, Prop_Send, "m_iNetWorth", 4, index);
}

public GetXPM(index){
	new totalEarned = GetIntProperty(index, "m_iTotalEarnedXP")
	return totalEarned / RoundFloat(GameRules_GetPropFloat("m_fGameTime") / 60)
}

public GetGPM(index){
	new totalEarned = GetIntProperty(index, "m_iTotalEarnedGold")
	return totalEarned / RoundFloat(GameRules_GetPropFloat("m_fGameTime") / 60)
}


public GetDenies(index){
	return GetIntProperty(index, "m_iDenyCount");
}

public GetLasthits(index){
	return GetIntProperty(index, "m_iLastHitCount");
}

//DOTA_CONNECTION_STATE_UNKNOWN = 0
//DOTA_CONNECTION_STATE_NOT_YET_CONNECTED = 1
//DOTA_CONNECTION_STATE_CONNECTED = 2
//DOTA_CONNECTION_STATE_DISCONNECTED = 3
//DOTA_CONNECTION_STATE_ABANDONED = 4
//DOTA_CONNECTION_STATE_LOADING = 5
//DOTA_CONNECTION_STATE_FAILED = 6
public GetConnectionState(index){
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iConnectionState", 4, index)
}

public GetLevel(index){
	return GetIntProperty(index, "m_iLevel");
}

public GetTeam(index){
	return GetIntProperty(index, "m_iPlayerTeams");
}

public GetKills(index){
	return GetIntProperty(index, "m_iKills");
}

public GetDeaths(index){
	return GetIntProperty(index, "m_iDeaths");
}

public GetAssists(index){
	return GetIntProperty(index, "m_iAssists");
}

public GetHero(index, String:buffer[40]){
	new heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", index);
	GetEntityClassname(heroEntity, buffer, sizeof(buffer));
}

public int GetSteamid(int index){
	new offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
	new sid = GetEntData(GetPlayerResourceEntity(), offset + index * 8, 4);
	
	return sid
}

public GetPlayersCount(){
	new heroCount = 0;
	
	for (new i = 0; i <= 10; i++){
	
		int steamid = GetSteamid(i)
		
		if(steamid != 0){
			heroCount++;
		}
	} 
	
	return heroCount;
}

public SetPlayersToStart(int toStart)
{
    ServerCommand("dota_wait_for_players_to_load_count %d", toStart);
    PrintToServer("Server command executed(wait for load count)");
}

public PopulateBots(int difficulty)
{
	ServerCommand("dota_bot_set_difficulty %d", difficulty);
    ServerCommand("dota_bot_populate");
    PrintToServer("Server command executed(populate bots)");
}


void GetCommandLineParamStr(const char[] param, char[] value, int maxlen, const char[] defValue, char endSymbol = ' ', bool includeEndSymbol = false)
{
    if (!FindCommandLineParam(param))
    {
        Format(value, maxlen, "%s", defValue);
        return;
    }

    char commandLine[4000];                              
    bool isValidCommandLine = GetCommandLine(commandLine, sizeof(commandLine))
    if (isValidCommandLine)
    {
        int i = StrContains(commandLine, param) + strlen(param)
        int j = 0;
        int started = false;

        while (i < strlen(commandLine))
        {
             if (!started) {
                if (commandLine[i] != ' ')
                {
                    started = true;
                    if (commandLine[i] == '"')
                    {
                        endSymbol = commandLine[i];
                        includeEndSymbol = false;
                        i++;
                    }
                }
            }

            if (started)
            {
                if (commandLine[i] == endSymbol || commandLine[i] == '\0')
                {
                    if (commandLine[i] == endSymbol && includeEndSymbol)
                    {
                        value[j] = commandLine[i];
                    }
                    break;
                }
                value[j] = commandLine[i];
                j++;
            }
            i++;
        }
    }
    else
    {
        Format(value, maxlen, "%s", defValue);
    }
}



void GetCommandLineParamJson(const char[] param, char[] value, int maxlen, const char[] defValue){
	char buffer[2048];
	GetCommandLineParamStr(param, buffer, sizeof(buffer), "");
	PrintToServer("Before: %s", buffer);
	
	DecodeBase64(value, maxlen, buffer);
}