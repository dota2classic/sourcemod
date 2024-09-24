

#include <sdkhooks>
#include <sdktools>

#pragma newdecls required

bool pluginIsActive;
int disconnectTime[10];
char clientNames[10][32];
char playerColors[12];

public void InitPlayerColors()
{
	playerColors[0] = 25;
	playerColors[0] = 12;
	playerColors[0] = 26;
	playerColors[0] = 20;
	playerColors[1] = 27;
	playerColors[1] = 17;
	playerColors[1] = 21;
	playerColors[1] = 23;
	playerColors[2] = 24;
	playerColors[2] = 16;
}

char GetPlayerColor(int playerID){
	if (playerID > 9)
	{
		return 1;
	}
	return playerColors[playerID];
}

int GetPlayerSteamID(int playerID)
{
	int steamIdOffset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
	int resource = GetPlayerResourceEntity();
	return GetEntData(resource, playerID * 8 + steamIdOffset, 4);
}

int GetPlayerIndex(int steamID32)
{
	int steamIdOffset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
	int resource = GetPlayerResourceEntity();
    for(int i = 0 ; i < 10; i++){
		int id = GetEntData(resource, i * 8 + steamIdOffset, 4);
		if (steamID32 == id) return i;
	}
	return -1;
}

bool IsPaused()
{
	return GameRules_GetProp("m_bGamePaused", 4, 0);
}

public void OnPluginStart()
{
    PrintToServer("Start abandon plugin");
	InitPlayerColors();
	// CreateTimer(5.0, HookGameRulesStateChange);
    HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode_Post);
    PrintToServer("Hook called");
}

public void OnMapStart()
{
    for(int i = 0; i < 10; i++){
        disconnectTime[i] = -1;
    }
}

public Action HookGameRulesStateChange(Handle timer)
{
	
	return Plugin_Continue;
}

public Action OnGameStateChange(Handle event, char[] name, bool dontBroadcast)
{
	int gameState = GameRules_GetProp("m_nGameState", 4, 0);
	pluginIsActive = gameState > 1 && gameState < 6;
    PrintToServer("Game state %d is active? %b", gameState, pluginIsActive);
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
    PrintToServer("On disconnect");
	if (!pluginIsActive || IsFakeClient(client))
	{
		return;
	}
	int teamId = GetClientTeam(client);
	bool isPlayer = teamId == 2 || teamId == 3;
	if (!isPlayer)
	{
		return; 
	}
	int steamID32 = GetSteamAccountID(client, true);
	if (0 >= steamID32)
	{
		return;
	}
	int playerIndex = GetPlayerIndex(steamID32);
	if (playerIndex == -1)
	{
		return;
	}
	GetClientName(client, clientNames[playerIndex], 32);
	CreateTimer(1, Timer_CountMinutesDisconnected, playerIndex, 1);
}

public Action Timer_CountMinutesDisconnected(Handle timer,int playerID)
{
	bool isConnected = GetEntProp(GetPlayerResourceEntity(), PropType:0, "m_iConnectionState", 4, playerID) == 2;
	if (isConnected)
	{
		return Plugin_Stop;
	}
	if (IsPaused())
	{
		return Plugin_Continue;
	}
	disconnectTime[playerID]++;
    PrintToServer("Disconnect timer %d", disconnectTime[playerID]);
	if (disconnectTime[playerID] >= 300)
	{
		AbandonPlayer(playerID);
		return Plugin_Stop;
	}
    // Minute passed
	if (disconnectTime[playerID] % 60 == 0)
	{
		int minutesRemaining = (300 - disconnectTime[playerID]) / 60;
		PrintCenterTextAll("%c%s\x01 has %i minutes left to reconnect.", GetPlayerColor(playerID), clientNames[playerID], minutesRemaining);
	}
	return Plugin_Continue;
}

public void AbandonPlayer(int playerID)
{
	int steamID32 = GetPlayerSteamID(playerID);
	SetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iConnectionState", any:4, 4, playerID);
	PrintCenterTextAll("%c%s\x01 has abandoned the game.", GetPlayerColor(playerID), clientNames[playerID]);
	PrintToServer("Player Abandoned: %i, %s", steamID32, clientNames[playerID]);
}
