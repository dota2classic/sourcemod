#include <d2c.inc>
#include <sourcemod>
#include <sdktools>
#include <d2c>
#include <ripext>
#pragma newdecls required


int match_id = -1;
int matchmaking_mode = -1;

public bool GetDidRandom(int index)
{
	return GetEntProp(GetPlayerResourceEntity(), PropType:0, "m_bHasRandomed", 4, index);
}

public void GetPosition(int index, float vec[3])
{
	GetEntPropVector(index, PropType:0, "m_vecOrigin", vec, 0);
}


public void FillHeroData(JSONObject obj, int hero){
	// Steam id
	int pid = GetEntProp(hero, Prop_Send, "m_iPlayerID")
	obj.SetInt("steam_id", pid);
	
	// Is Bot?
	obj.SetBool("bot", pid <= 10);

	// Position on map
	float vec[3];
	GetEntPropVector(hero, Prop_Send, "m_vecOrigin", vec);
	obj.SetFloat("pos_x", (vec[0] + 7500.0) / 15000.0);
	obj.SetFloat("pos_y", (vec[1] + 7500.0) / 15000.0);
	
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
			items.PushString("item_emptyitembg");
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
}


public Action Command_Test(int args){
	Update()
}


public void UpdateLiveMatch(){
	char buffer[10000];
	
	JSONObject match = new JSONObject();
	match.SetInt("match_id", match_id);
	match.SetInt("matchmaking_mode", matchmaking_mode);
	match.SetInt("game_mode", matchmaking_mode);
	match.SetInt("timestamp", GetTime());
	
	
	
	JSONArray heroes = new JSONArray();
	for(int i = 0; i < 10; i++){
		
		int heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", i);
		JSONObject o = new JSONObject();
		FillHeroData(o, heroEntity);	
		FillPlayerData(o, i);
		
		heroes.Push(o);
		
//		o.ToString(buffer, sizeof(buffer));
//		PrintToServer(buffer);
	}
	
	match.Set("heroes", heroes);

	
	
	
}