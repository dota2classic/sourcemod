#include <d2c.inc>
#include <sourcemod>
#include <sdktools>
#include <d2c>
#pragma newdecls required


public void OnPluginStart()
{
	
}


public void OnMapStart()
{
	HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode:1);
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}



public Action Command_Say(int client, const char[] command, int argc)
{
	
	char text[24];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	if(!strcmp(text, "/roll", false)){
		Roll(client);
	}
}

public void Roll(int client){
	if (IsFakeClient(client))
	{
		return;
	}
	
	int team = GetClientTeam(client);
	if(team != 2 && team != 3){
		return;
	}

	int rollValue = GetRandomInt(1, 100);
	char username[32];
	GetClientName(client, username, 32);
	
	PrintToChatAll("%s выпало число %i", username, rollValue);
	
}


public Action OnGameStateChange(Handle event, char[] name, bool dontBroadcast)
{
	int gameState = GameRules_GetProp("m_nGameState");

	// GameRules

	PrintToServer("GameRules change to: %d", gameState);

	if(gameState == DOTA_GAMERULES_STATE_WAIT_FOR_PLAYERS_TO_LOAD || gameState == DOTA_GAMERULES_STATE_HERO_SELECTION) {
		PrintToChatAll("Используйте команду '/roll', чтобы получить случайное число от 1 до 100");
	}
	return Plugin_Continue;
}