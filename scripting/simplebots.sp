#include <sourcemod>
#include <sdktools>
#include <d2c>
#include <ripext>

#pragma newdecls required
#pragma dynamic 131072

bool enabled = false;


public void OnPluginStart()
{
	
	char simpleMode[64];
	GetCommandLineParamStr("+simple", simpleMode, 64, "false");
	
	PrintToServer("%s simple?", simpleMode);
	
	if(strcmp(simpleMode, "true", false))
	{
		return;
	}
	enabled = true;
	
}

public void OnMapStart(){
	if(!enabled) return;
	CreateTimer(1.0, UpdateGPM, 0, TIMER_REPEAT);
}



public Action UpdateGPM(Handle timer){
	int gameState = GameRules_GetProp("m_nGameState");
	if(gameState != DOTA_GAMERULES_STATE_GAME_IN_PROGRESS) return;

	
	int isPaused = GameRules_GetProp("m_bGamePaused");
	if(isPaused != 0) return;
	
	for(int i = 0; i < 10; i++){
		GPMForPlayer(i);
	}
}



int threshold[] = {
		200,
		300,
		400,
		500,
		600,
		600,
		600,
		1200,
		1000,
		600,
		2200,
		800,
		1400,
		1500,
		1600,
		1700,
		1800,
		1900,
		2000,
		2100,
		2200,
		2300,
		2400,
		2500,
		2500
	};
	
public int GetMaxXPForLevel(int level){
	int sum = 0;
	for(int i = 0 ; i < level; i++) {
		sum += threshold[i];
	}
	
	return sum;
	
}
	
// Find which team has real players
// Add gold to the real players
// Subtract gold for enemy bots
public void GPMForPlayer(int client){
	int goodTeam = GetPlayerTeam();
	
	int entity = client < 5 ? FindEntityByClassname(-1, "dota_data_radiant") : FindEntityByClassname(-1, "dota_data_dire");
	int index = client < 5 ? client : 10 - client;
	
	int wasGold = GetEntProp(entity, Prop_Send, "m_iReliableGold", 4, index);
	
	int sid = GetSteamid(client);
	int team = GetTeam(client);

	if(sid < 10 && team != goodTeam) {
		// We reduce their gold muahaha
		int newGold = wasGold - 1;
		SetEntProp(entity, Prop_Send, "m_iReliableGold", newGold, 4, index);
		       
	} else if(sid > 10) {
		int newGold = wasGold + 2;
		SetEntProp(entity, Prop_Send, "m_iReliableGold", newGold, 4, index);
		
		
		int heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", client);
		int xp = GetEntProp(heroEntity, Prop_Send, "m_iCurrentXP", 4, 0)
		
		int lvl = GetLevel(client);
		
		int maxXP = GetMaxXPForLevel(lvl);
		
		int xpBonus = 0;
		if(lvl < 5){
			xpBonus = 2;
		} else if(lvl < 10) {
			xpBonus = 4;
		} else {
			xpBonus = 8;
		}
				
		int newXp = (maxXP - xp) > 100 ? xp + xpBonus : xp;
		
		SetEntProp(heroEntity, Prop_Send, "m_iCurrentXP", newXp, 4, 0);
		
		SetMaxRespawnTime(client, 30.0);
	}
}

public void SetMaxRespawnTime(int client, float maxRespawn){
	int heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", client);
	float currentGameTime = GameRules_GetPropFloat("m_fGameTime");
	float currentRespawnTime = GetEntPropFloat(heroEntity, Prop_Send, "m_flRespawnTime", 0);
		
	float respawnTimeLeft = currentRespawnTime - currentGameTime;
	
	if(respawnTimeLeft > maxRespawn) {
		SetEntPropFloat(heroEntity, Prop_Send, "m_flRespawnTime", currentGameTime + maxRespawn);
	}
}

public int GetPlayerTeam(){
	int playersTeam = -1;
	for(int i = 0; i < 10; i++){
		int sid = GetSteamid(i);
		if(sid < 10) continue;

		// Real player
		playersTeam = GetTeam(i);
		break;
	}
	return playersTeam;
}


public void Test(int client) {
//	m_iIncomeGold
	PrintToServer("Client %d", client);
	int income = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iLevel", 4, 0);
	
	SetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iLevel", 20, 4, 0)
	
	
	PrintToServer("amogus %d", income);
}