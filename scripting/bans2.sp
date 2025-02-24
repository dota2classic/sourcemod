#include <d2c.inc>
#include <sourcemod>
#include <sdktools>
#include <d2c>
#pragma newdecls required

public void OnPluginStart()
{
	// GameRules_SetProp("m_LockedHeroesPerPlayer", 101, 4, 0)
//	int someProp = GameRules_GetPropEnt("DT_DOTA_GameManager")
//	PrintToServer("%d", someProp);
	for(int i = 0; i < 50; i++){
		int h = GameRules_GetProp("m_SelectedHeroes", 4, i);
		PrintToServer("At %d=%b|%d", i, h, h);
	}
}