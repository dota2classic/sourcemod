#include <d2c.inc>
#include <sourcemod>
#include <sdktools>
#include <d2c>
#pragma newdecls required


Handle playerUsedBanMap;
StringMap internalHeroNameByAlias ;
StringMap actualHeroNames;
ArrayList nominatedHeroes;
ArrayList bannedHeroes;
bool enable = false

// weird stuff make it 24 its ok
bool suggestionMap[24];

char printPrefix[] = "\x01\x04[DOTA2CLASSIC]\x01";


public void OnPluginStart()
{
	RegConsoleCmd("ban", OnPlayerBan); 
}

public void OnMapStart()
{
	
	nominatedHeroes = CreateArray(64, 0);
	bannedHeroes = CreateArray(64, 0);
	playerUsedBanMap = CreateTrie();
	fillInternalHeroNameByAlias();
	fillActualHeroNames();
	PrintToServer("GameMopde: %d", GameRules_GetProp("m_iGameMode", 4, 0));
	enable = true;
	if (GameRules_GetProp("m_iGameMode", 4, 0) == 22)
	{
		enable = true;
	}
	else
	{
		enable = false;
		return;
	}
	
	HookEvent("game_rules_state_change", OnGameStateChange, EventHookMode_Post);
	AddCommandListener(restrictPickingBannedHero, "dota_select_hero");
	
	PrintToServer("Enable bans: %d", enable);
}


public Action Command_Say(int client, const char[] command, int argc)
{
	char sayString[32];
	GetCmdArg(1, sayString, sizeof(sayString));
	GetCmdArgString(sayString, sizeof(sayString));
	StripQuotes(sayString);
	PrintToServer(sayString)
	
	char hero[64];
	
	SplitString(sayString, " ", hero, sizeof(hero));
	
	PrintToServer("sayString: '%s'", hero)
	
	if(!strcmp(hero, "/ban", false)){
		PrintToServer("We are trying to ban...");
		ReplaceString(sayString, sizeof(sayString), "/ban ", "");
		PrintToServer("Hero to ban: %s", sayString);
		
		NonimateBan(client, sayString);
		
	}
}

public Action OnPlayerBan(int client, int args) {
	char hero[64];
	GetCmdArg(1, hero, sizeof(hero));
	
	PrintToServer("sayString: '%s'", hero)
		
	NonimateBan(client, hero);
}

public void NonimateBan(int client, char[] hero){
	if(!enable) return;
	
	int steam32 = GetSteamid(client);
	int playerIndex = GetPlayerIndex(steam32);
	
	PrintToServer("Nominating hero by sid=%d, pid=%d", steam32, playerIndex);

	bool alreadySuggested = suggestionMap[playerIndex];
	
	PrintToServer("Already suggested: %d", alreadySuggested);
	
	if(alreadySuggested){
		PrintToServer("Already nominated for ban");
		PrintToChat(client, "%s Ты уже предложил запретить героя.", printPrefix);
		return;
	}
	
	char realName[64];
	bool didFind = internalHeroNameByAlias.GetString(hero, realName, sizeof(realName));
	
	if(!didFind){
		PrintToServer("Hero not found for alias %s", hero);
		PrintToChat(client, "%s Не нашел такого героя!", printPrefix);
		return;
	}
	
	
	int alreadyNominated = nominatedHeroes.FindString(realName) != -1;
	
	if(alreadyNominated){
		PrintToChat(client, "%s Герой уже предложен к запрету.", printPrefix);
		return;
	}
	
	nominatedHeroes.PushString(realName);
	
	char prettyName[64];
	bool hasPretty = actualHeroNames.GetString(realName, prettyName, sizeof(prettyName));
	PrintToChatAll("%s %s был предложен к запрету.", printPrefix, hasPretty ? prettyName : realName);
	
	suggestionMap[playerIndex] = true;
}

public Action OnGameStateChange(Handle event, char[] name, bool dontBroadcast)
{
	
	if (HasDraftStageStarted() && enable)
	{
		PrintToChatAll("%s Баним героев...", printPrefix);
		CreateTimer(3.0, DoBanHeroes);
		enable = false;
	}
	return Plugin_Continue;
}

public Action printInstructionsMsgToAll(Handle timer)
{
	if(!enable) return Plugin_Continue;
	PrintToChatAll("%s Запрети героя к выбору: /ban [название героя или сокращение]", printPrefix);
	return Plugin_Continue;
}

public void HasDraftStageStarted()
{
	return GameRules_GetProp("m_nGameState", 4, 0) > 1;
}

public Action DoBanHeroes(Handle timer)
{
	
	if(nominatedHeroes.Length == 0)
	{
		PrintToChatAll("%s Все герои доступны к выбору.", printPrefix);
		return Plugin_Handled;
	}
	// todo: iterate over all heroes and rol individually
	for(int i = 0; i < nominatedHeroes.Length; i++){
		bool isBanned = GetRandomFloat() > 0.3; // lets not 50-50 here
		char heroName[64];
		nominatedHeroes.GetString(i, heroName, 64);
		char actualHeroName[64];
		actualHeroNames.GetString(heroName, actualHeroName, 64);
		
		
		if(!isBanned){
			PrintToChatAll("% %s не был запрещен.", printPrefix, actualHeroName);
			continue;
		}
		
		
		PrintToChatAll("%s %s был запрещен.", printPrefix, actualHeroName);
		bannedHeroes.PushString(heroName);
	}
	return Plugin_Handled;
}

public Action restrictPickingBannedHero(int client, char[] command, any args)
{
	char heroName[64];
	GetCmdArg(1, heroName, 64);
	
	bool heroIsBanned = bannedHeroes.FindString(heroName) != -1;
	if (heroIsBanned)
	{
		PrintToChat(client, "%s Этот герой запрещен!", printPrefix);
		return Plugin_Handled;
	}
	return Plugin_Continue
}

public void OnClientPutInServer(int client)
{
	if(!enable) return;
	CreateTimer(2.0, PrintInstructionToPlayer, client, 0);
}

public Action PrintInstructionToPlayer(Handle timer, int client)
{
	if(!enable || !IsClientInGame(client)){
		 return Plugin_Continue;
	}
	PrintToChat(client, "%s Запрети героя к выбору: /ban [название героя или сокращение]", printPrefix);
	return Plugin_Continue;
}

public void fillInternalHeroNameByAlias()
{
	internalHeroNameByAlias = new StringMap();
	
	internalHeroNameByAlias.SetString("abaddon", "npc_dota_hero_abaddon", true);
	internalHeroNameByAlias.SetString("abadon", "npc_dota_hero_abaddon", true);
	internalHeroNameByAlias.SetString("aba", "npc_dota_hero_abaddon", true);
	internalHeroNameByAlias.SetString("alchemist", "npc_dota_hero_alchemist", true);
	internalHeroNameByAlias.SetString("alch", "npc_dota_hero_alchemist", true);
	internalHeroNameByAlias.SetString("alc", "npc_dota_hero_alchemist", true);
	internalHeroNameByAlias.SetString("aa", "npc_dota_hero_ancient_apparition", true);
	internalHeroNameByAlias.SetString("ancient apparition", "npc_dota_hero_ancient_apparition", true);
	internalHeroNameByAlias.SetString("am", "npc_dota_hero_antimage", true);
	internalHeroNameByAlias.SetString("antimage", "npc_dota_hero_antimage", true);
	internalHeroNameByAlias.SetString("anti-mage", "npc_dota_hero_antimage", true);
	internalHeroNameByAlias.SetString("anti mage", "npc_dota_hero_antimage", true);
	internalHeroNameByAlias.SetString("axe", "npc_dota_hero_axe", true);
	internalHeroNameByAlias.SetString("bane", "npc_dota_hero_bane", true);
	internalHeroNameByAlias.SetString("batrider", "npc_dota_hero_batrider", true);
	internalHeroNameByAlias.SetString("bat", "npc_dota_hero_batrider", true);
	internalHeroNameByAlias.SetString("beastmaster", "npc_dota_hero_beastmaster", true);
	internalHeroNameByAlias.SetString("beast", "npc_dota_hero_beastmaster", true);
	internalHeroNameByAlias.SetString("blood", "npc_dota_hero_bloodseeker", true);
	internalHeroNameByAlias.SetString("bs", "npc_dota_hero_bloodseeker", true);
	internalHeroNameByAlias.SetString("bloodseeker", "npc_dota_hero_bloodseeker", true);
	internalHeroNameByAlias.SetString("seeker", "npc_dota_hero_bloodseeker", true);
	internalHeroNameByAlias.SetString("bounty hunter", "npc_dota_hero_bounty_hunter", true);
	internalHeroNameByAlias.SetString("bh", "npc_dota_hero_bounty_hunter", true);
	internalHeroNameByAlias.SetString("bounty", "npc_dota_hero_bounty_hunter", true);
	internalHeroNameByAlias.SetString("brewmaster", "npc_dota_hero_brewmaster", true);
	internalHeroNameByAlias.SetString("brew", "npc_dota_hero_brewmaster", true);
	internalHeroNameByAlias.SetString("brist", "npc_dota_hero_bristleback", true);
	internalHeroNameByAlias.SetString("bristle", "npc_dota_hero_bristleback", true);
	internalHeroNameByAlias.SetString("bristleback", "npc_dota_hero_bristleback", true);
	internalHeroNameByAlias.SetString("bb", "npc_dota_hero_bristleback", true);
	internalHeroNameByAlias.SetString("brood", "npc_dota_hero_broodmother", true);
	internalHeroNameByAlias.SetString("broodmother", "npc_dota_hero_broodmother", true);
	internalHeroNameByAlias.SetString("cent", "npc_dota_hero_centaur", true);
	internalHeroNameByAlias.SetString("centaur", "npc_dota_hero_centaur", true);
	internalHeroNameByAlias.SetString("ck", "npc_dota_hero_chaos_knight", true);
	internalHeroNameByAlias.SetString("chaos", "npc_dota_hero_chaos_knight", true);
	internalHeroNameByAlias.SetString("chaos knight", "npc_dota_hero_chaos_knight", true);
	internalHeroNameByAlias.SetString("chen", "npc_dota_hero_chen", true);
	internalHeroNameByAlias.SetString("clinkz", "npc_dota_hero_clinkz", true);
	internalHeroNameByAlias.SetString("bone fletcher", "npc_dota_hero_clinkz", true);
	internalHeroNameByAlias.SetString("cm", "npc_dota_hero_crystal_maiden", true);
	internalHeroNameByAlias.SetString("crystal maiden", "npc_dota_hero_crystal_maiden", true);
	internalHeroNameByAlias.SetString("ds", "npc_dota_hero_dark_seer", true);
	internalHeroNameByAlias.SetString("dark seer", "npc_dota_hero_dark_seer", true);
	internalHeroNameByAlias.SetString("dazzle", "npc_dota_hero_dazzle", true);
	internalHeroNameByAlias.SetString("dp", "npc_dota_hero_death_prophet", true);
	internalHeroNameByAlias.SetString("death prophet", "npc_dota_hero_death_prophet", true);
	internalHeroNameByAlias.SetString("disruptor", "npc_dota_hero_disruptor", true);
	internalHeroNameByAlias.SetString("doom", "npc_dota_hero_doom_bringer", true);
	internalHeroNameByAlias.SetString("dk", "npc_dota_hero_dragon_knight", true);
	internalHeroNameByAlias.SetString("dragon knight", "npc_dota_hero_dragon_knight", true);
	internalHeroNameByAlias.SetString("drow", "npc_dota_hero_drow_ranger", true);
	internalHeroNameByAlias.SetString("drow ranger", "npc_dota_hero_drow_ranger", true);
	internalHeroNameByAlias.SetString("earth spirit", "npc_dota_hero_earth_spirit", true);
	internalHeroNameByAlias.SetString("earthspirit", "npc_dota_hero_earth_spirit", true);
	internalHeroNameByAlias.SetString("earthshaker", "npc_dota_hero_earthshaker", true);
	internalHeroNameByAlias.SetString("shaker", "npc_dota_hero_earthshaker", true);
	internalHeroNameByAlias.SetString("elder titan", "npc_dota_hero_elder_titan", true);
	internalHeroNameByAlias.SetString("et", "npc_dota_hero_elder_titan", true);
	internalHeroNameByAlias.SetString("ember", "npc_dota_hero_ember_spirit", true);
	internalHeroNameByAlias.SetString("ember spirit", "npc_dota_hero_ember_spirit", true);
	internalHeroNameByAlias.SetString("ench", "npc_dota_hero_enchantress", true);
	internalHeroNameByAlias.SetString("enchantress", "npc_dota_hero_enchantress", true);
	internalHeroNameByAlias.SetString("enigma", "npc_dota_hero_enigma", true);
	internalHeroNameByAlias.SetString("void", "npc_dota_hero_faceless_void", true);
	internalHeroNameByAlias.SetString("fv", "npc_dota_hero_faceless_void", true);
	internalHeroNameByAlias.SetString("faceless void", "npc_dota_hero_faceless_void", true);
	internalHeroNameByAlias.SetString("furion", "npc_dota_hero_furion", true);
	internalHeroNameByAlias.SetString("np", "npc_dota_hero_furion", true);
	internalHeroNameByAlias.SetString("natures prophet", "npc_dota_hero_furion", true);
	internalHeroNameByAlias.SetString("gyrocopter", "npc_dota_hero_gyrocopter", true);
	internalHeroNameByAlias.SetString("gyro", "npc_dota_hero_gyrocopter", true);
	internalHeroNameByAlias.SetString("huskar", "npc_dota_hero_huskar", true);
	internalHeroNameByAlias.SetString("invoker", "npc_dota_hero_invoker", true);
	internalHeroNameByAlias.SetString("jakiro", "npc_dota_hero_jakiro", true);
	internalHeroNameByAlias.SetString("jug", "npc_dota_hero_juggernaut", true);
	internalHeroNameByAlias.SetString("jugg", "npc_dota_hero_juggernaut", true);
	internalHeroNameByAlias.SetString("juggernaut", "npc_dota_hero_juggernaut", true);
	internalHeroNameByAlias.SetString("kotl", "npc_dota_hero_keeper_of_the_light", true);
	internalHeroNameByAlias.SetString("keeper of the light", "npc_dota_hero_keeper_of_the_light", true);
	internalHeroNameByAlias.SetString("kunkka", "npc_dota_hero_kunkka", true);
	internalHeroNameByAlias.SetString("kunka", "npc_dota_hero_kunkka", true);
	internalHeroNameByAlias.SetString("lc", "npc_dota_hero_legion_commander", true);
	internalHeroNameByAlias.SetString("legion", "npc_dota_hero_legion_commander", true);
	internalHeroNameByAlias.SetString("legion commander", "npc_dota_hero_legion_commander", true);
	internalHeroNameByAlias.SetString("leshrac", "npc_dota_hero_leshrac", true);
	internalHeroNameByAlias.SetString("lesh", "npc_dota_hero_leshrac", true);
	internalHeroNameByAlias.SetString("lich", "npc_dota_hero_lich", true);
	internalHeroNameByAlias.SetString("naix", "npc_dota_hero_life_stealer", true);
	internalHeroNameByAlias.SetString("lifestealer", "npc_dota_hero_life_stealer", true);
	internalHeroNameByAlias.SetString("ls", "npc_dota_hero_life_stealer", true);
	internalHeroNameByAlias.SetString("life stealer", "npc_dota_hero_life_stealer", true);
	internalHeroNameByAlias.SetString("lina", "npc_dota_hero_lina", true);
	internalHeroNameByAlias.SetString("lion", "npc_dota_hero_lion", true);
	internalHeroNameByAlias.SetString("lone druid", "npc_dota_hero_lone_druid", true);
	internalHeroNameByAlias.SetString("ld", "npc_dota_hero_lone_druid", true);
	internalHeroNameByAlias.SetString("luna", "npc_dota_hero_luna", true);
	internalHeroNameByAlias.SetString("lycan", "npc_dota_hero_lycan", true);
	internalHeroNameByAlias.SetString("magnus", "npc_dota_hero_magnataur", true);
	internalHeroNameByAlias.SetString("medusa", "npc_dota_hero_medusa", true);
	internalHeroNameByAlias.SetString("dusa", "npc_dota_hero_medusa", true);
	internalHeroNameByAlias.SetString("meepo", "npc_dota_hero_meepo", true);
	internalHeroNameByAlias.SetString("mirana", "npc_dota_hero_mirana", true);
	internalHeroNameByAlias.SetString("morphling", "npc_dota_hero_morphling", true);
	internalHeroNameByAlias.SetString("morph", "npc_dota_hero_morphling", true);
	internalHeroNameByAlias.SetString("naga", "npc_dota_hero_naga_siren", true);
	internalHeroNameByAlias.SetString("naga siren", "npc_dota_hero_naga_siren", true);
	internalHeroNameByAlias.SetString("necrolyte", "npc_dota_hero_necrolyte", true);
	internalHeroNameByAlias.SetString("necro", "npc_dota_hero_necrolyte", true);
	internalHeroNameByAlias.SetString("necrophos", "npc_dota_hero_necrolyte", true);
	internalHeroNameByAlias.SetString("sf", "npc_dota_hero_nevermore", true);
	internalHeroNameByAlias.SetString("shadow fiend", "npc_dota_hero_nevermore", true);
	internalHeroNameByAlias.SetString("nevermore", "npc_dota_hero_nevermore", true);
	internalHeroNameByAlias.SetString("night stalker", "npc_dota_hero_night_stalker", true);
	internalHeroNameByAlias.SetString("ns", "npc_dota_hero_night_stalker", true);
	internalHeroNameByAlias.SetString("nyx", "npc_dota_hero_nyx_assassin", true);
	internalHeroNameByAlias.SetString("nyx assassin", "npc_dota_hero_nyx_assassin", true);
	internalHeroNameByAlias.SetString("od", "npc_dota_hero_obsidian_destroyer", true);
	internalHeroNameByAlias.SetString("ogre", "npc_dota_hero_ogre_magi", true);
	internalHeroNameByAlias.SetString("ogre magi", "npc_dota_hero_ogre_magi", true);
	internalHeroNameByAlias.SetString("omni", "npc_dota_hero_omniknight", true);
	internalHeroNameByAlias.SetString("omniknight", "npc_dota_hero_omniknight", true);
	internalHeroNameByAlias.SetString("oracle", "npc_dota_hero_oracle", true);
	internalHeroNameByAlias.SetString("phantom assassin", "npc_dota_hero_phantom_assassin", true);
	internalHeroNameByAlias.SetString("pa", "npc_dota_hero_phantom_assassin", true);
	internalHeroNameByAlias.SetString("pl", "npc_dota_hero_phantom_lancer", true);
	internalHeroNameByAlias.SetString("phantom lancer", "npc_dota_hero_phantom_lancer", true);
	internalHeroNameByAlias.SetString("lancer", "npc_dota_hero_phantom_lancer", true);
	internalHeroNameByAlias.SetString("phoenix", "npc_dota_hero_phoenix", true);
	internalHeroNameByAlias.SetString("puck", "npc_dota_hero_puck", true);
	internalHeroNameByAlias.SetString("pudge", "npc_dota_hero_pudge", true);
	internalHeroNameByAlias.SetString("pugna", "npc_dota_hero_pugna", true);
	internalHeroNameByAlias.SetString("queen of pain", "npc_dota_hero_queenofpain", true);
	internalHeroNameByAlias.SetString("qop", "npc_dota_hero_queenofpain", true);
	internalHeroNameByAlias.SetString("clockwerk", "npc_dota_hero_rattletrap", true);
	internalHeroNameByAlias.SetString("clock", "npc_dota_hero_rattletrap", true);
	internalHeroNameByAlias.SetString("razor", "npc_dota_hero_razor", true);
	internalHeroNameByAlias.SetString("riki", "npc_dota_hero_riki", true);
	internalHeroNameByAlias.SetString("rubick", "npc_dota_hero_rubick", true);
	internalHeroNameByAlias.SetString("sand king", "npc_dota_hero_sand_king", true);
	internalHeroNameByAlias.SetString("sk", "npc_dota_hero_sand_king", true);
	internalHeroNameByAlias.SetString("sd", "npc_dota_hero_shadow_demon", true);
	internalHeroNameByAlias.SetString("shadow demon", "npc_dota_hero_shadow_demon", true);
	internalHeroNameByAlias.SetString("ss", "npc_dota_hero_shadow_shaman", true);
	internalHeroNameByAlias.SetString("shadow shaman", "npc_dota_hero_shadow_shaman", true);
	internalHeroNameByAlias.SetString("timber", "npc_dota_hero_shredder", true);
	internalHeroNameByAlias.SetString("timbersaw", "npc_dota_hero_shredder", true);
	internalHeroNameByAlias.SetString("silencer", "npc_dota_hero_silencer", true);
	internalHeroNameByAlias.SetString("wk", "npc_dota_hero_skeleton_king", true);
	internalHeroNameByAlias.SetString("wraith king", "npc_dota_hero_skeleton_king", true);
	internalHeroNameByAlias.SetString("sky", "npc_dota_hero_skywrath_mage", true);
	internalHeroNameByAlias.SetString("skywrath", "npc_dota_hero_skywrath_mage", true);
	internalHeroNameByAlias.SetString("skywrath_mage", "npc_dota_hero_skywrath_mage", true);
	internalHeroNameByAlias.SetString("slardar", "npc_dota_hero_slardar", true);
	internalHeroNameByAlias.SetString("slark", "npc_dota_hero_slark", true);
	internalHeroNameByAlias.SetString("sniper", "npc_dota_hero_sniper", true);
	internalHeroNameByAlias.SetString("spectre", "npc_dota_hero_spectre", true);
	internalHeroNameByAlias.SetString("sb", "npc_dota_hero_spirit_breaker", true);
	internalHeroNameByAlias.SetString("spirit breaker", "npc_dota_hero_spirit_breaker", true);
	internalHeroNameByAlias.SetString("bara", "npc_dota_hero_spirit_breaker", true);
	internalHeroNameByAlias.SetString("storm", "npc_dota_hero_storm_spirit", true);
	internalHeroNameByAlias.SetString("storm spirit", "npc_dota_hero_storm_spirit", true);
	internalHeroNameByAlias.SetString("sven", "npc_dota_hero_sven", true);
	internalHeroNameByAlias.SetString("techies", "npc_dota_hero_techies", true);
	internalHeroNameByAlias.SetString("ta", "npc_dota_hero_templar_assassin", true);
	internalHeroNameByAlias.SetString("templar assassin", "npc_dota_hero_templar_assassin", true);
	internalHeroNameByAlias.SetString("templar", "npc_dota_hero_templar_assassin", true);
	internalHeroNameByAlias.SetString("tb", "npc_dota_hero_terrorblade", true);
	internalHeroNameByAlias.SetString("terrorblade", "npc_dota_hero_terrorblade", true);
	internalHeroNameByAlias.SetString("tide", "npc_dota_hero_tidehunter", true);
	internalHeroNameByAlias.SetString("tidehunter", "npc_dota_hero_tidehunter", true);
	internalHeroNameByAlias.SetString("tinker", "npc_dota_hero_tinker", true);
	internalHeroNameByAlias.SetString("tiny", "npc_dota_hero_tiny", true);
	internalHeroNameByAlias.SetString("treant", "npc_dota_hero_treant", true);
	internalHeroNameByAlias.SetString("troll", "npc_dota_hero_troll_warlord", true);
	internalHeroNameByAlias.SetString("troll warlord", "npc_dota_hero_troll_warlord", true);
	internalHeroNameByAlias.SetString("tusk", "npc_dota_hero_tusk", true);
	internalHeroNameByAlias.SetString("undying", "npc_dota_hero_undying", true);
	internalHeroNameByAlias.SetString("ursa", "npc_dota_hero_ursa", true);
	internalHeroNameByAlias.SetString("venge", "npc_dota_hero_vengefulspirit", true);
	internalHeroNameByAlias.SetString("vengeful spirit", "npc_dota_hero_vengefulspirit", true);
	internalHeroNameByAlias.SetString("venomancer", "npc_dota_hero_venomancer", true);
	internalHeroNameByAlias.SetString("veno", "npc_dota_hero_venomancer", true);
	internalHeroNameByAlias.SetString("viper", "npc_dota_hero_viper", true);
	internalHeroNameByAlias.SetString("visage", "npc_dota_hero_visage", true);
	internalHeroNameByAlias.SetString("warlock", "npc_dota_hero_warlock", true);
	internalHeroNameByAlias.SetString("weaver", "npc_dota_hero_weaver", true);
	internalHeroNameByAlias.SetString("windrunner", "npc_dota_hero_windrunner", true);
	internalHeroNameByAlias.SetString("windranger", "npc_dota_hero_windrunner", true);
	internalHeroNameByAlias.SetString("wr", "npc_dota_hero_windrunner", true);
	internalHeroNameByAlias.SetString("ww", "npc_dota_hero_winter_wyvern", true);
	internalHeroNameByAlias.SetString("wyvern", "npc_dota_hero_winter_wyvern", true);
	internalHeroNameByAlias.SetString("winter wyvern", "npc_dota_hero_winter_wyvern", true);
	internalHeroNameByAlias.SetString("io", "npc_dota_hero_wisp", true);
	internalHeroNameByAlias.SetString("wisp", "npc_dota_hero_wisp", true);
	internalHeroNameByAlias.SetString("wd", "npc_dota_hero_witch_doctor", true);
	internalHeroNameByAlias.SetString("witch doctor", "npc_dota_hero_witch_doctor", true);
	internalHeroNameByAlias.SetString("zeus", "npc_dota_hero_zuus", true);
	return 0;
}

public void fillActualHeroNames()
{
	actualHeroNames = CreateTrie();
	actualHeroNames.SetString("npc_dota_hero_abaddon", "Abaddon", true);
	actualHeroNames.SetString("npc_dota_hero_alchemist", "Alchemist", true);
	actualHeroNames.SetString("npc_dota_hero_ancient_apparition", "Ancient Apparition", true);
	actualHeroNames.SetString("npc_dota_hero_antimage", "Anti-Mage", true);
	actualHeroNames.SetString("npc_dota_hero_bane", "Bane", true);
	actualHeroNames.SetString("npc_dota_hero_batrider", "Batrider", true);
	actualHeroNames.SetString("npc_dota_hero_beastmaster", "Beastmaster", true);
	actualHeroNames.SetString("npc_dota_hero_bloodseeker", "Bloodseeker", true);
	actualHeroNames.SetString("npc_dota_hero_bounty_hunter", "Bounty Hunter", true);
	actualHeroNames.SetString("npc_dota_hero_brewmaster", "Brewmaster", true);
	actualHeroNames.SetString("npc_dota_hero_bristleback", "Bristleback", true);
	actualHeroNames.SetString("npc_dota_hero_broodmother", "Broodmother", true);
	actualHeroNames.SetString("npc_dota_hero_centaur", "Centaur", true);
	actualHeroNames.SetString("npc_dota_hero_chaos_knight", "Chaos Knight", true);
	actualHeroNames.SetString("npc_dota_hero_chen", "Chen", true);
	actualHeroNames.SetString("npc_dota_hero_clinkz", "Clinkz", true);
	actualHeroNames.SetString("npc_dota_hero_crystal_maiden", "Crystal Maiden", true);
	actualHeroNames.SetString("npc_dota_hero_dark_seer", "Dark Seer", true);
	actualHeroNames.SetString("npc_dota_hero_dazzle", "Dazzle", true);
	actualHeroNames.SetString("npc_dota_hero_death_prophet", "Death Prophet", true);
	actualHeroNames.SetString("npc_dota_hero_disruptor", "Disruptor", true);
	actualHeroNames.SetString("npc_dota_hero_doom_bringer", "Doom", true);
	actualHeroNames.SetString("npc_dota_hero_dragon_knight", "Dragon Knight", true);
	actualHeroNames.SetString("npc_dota_hero_drow_ranger", "Drow Ranger", true);
	actualHeroNames.SetString("npc_dota_hero_earth_spirit", "Earth Spirit", true);
	actualHeroNames.SetString("npc_dota_hero_earthshaker", "Earthshaker", true);
	actualHeroNames.SetString("npc_dota_hero_elder_titan", "Elder Titan", true);
	actualHeroNames.SetString("npc_dota_hero_ember_spirit", "Ember Spirit", true);
	actualHeroNames.SetString("npc_dota_hero_enchantress", "Enchantress", true);
	actualHeroNames.SetString("npc_dota_hero_enigma", "Enigma", true);
	actualHeroNames.SetString("npc_dota_hero_faceless_void", "Faceless Void", true);
	actualHeroNames.SetString("npc_dota_hero_furion", "Nature's Prophet", true);
	actualHeroNames.SetString("npc_dota_hero_gyrocopter", "Gyrocopter", true);
	actualHeroNames.SetString("npc_dota_hero_huskar", "Huskar", true);
	actualHeroNames.SetString("npc_dota_hero_invoker", "Invoker", true);
	actualHeroNames.SetString("npc_dota_hero_jakiro", "Jakiro", true);
	actualHeroNames.SetString("npc_dota_hero_juggernaut", "Juggernaut", true);
	actualHeroNames.SetString("npc_dota_hero_keeper_of_the_light", "Keeper of the Light", true);
	actualHeroNames.SetString("npc_dota_hero_kunkka", "Kunkka", true);
	actualHeroNames.SetString("npc_dota_hero_legion_commander", "Legion Commander", true);
	actualHeroNames.SetString("npc_dota_hero_leshrac", "Leshrac", true);
	actualHeroNames.SetString("npc_dota_hero_lich", "Lich", true);
	actualHeroNames.SetString("npc_dota_hero_life_stealer", "Lifestealer", true);
	actualHeroNames.SetString("npc_dota_hero_lina", "Lina", true);
	actualHeroNames.SetString("npc_dota_hero_lion", "Lion", true);
	actualHeroNames.SetString("npc_dota_hero_lone_druid", "Lone Druid", true);
	actualHeroNames.SetString("npc_dota_hero_luna", "Luna", true);
	actualHeroNames.SetString("npc_dota_hero_lycan", "Lycan", true);
	actualHeroNames.SetString("npc_dota_hero_magnataur", "Magnus", true);
	actualHeroNames.SetString("npc_dota_hero_medusa", "Medusa", true);
	actualHeroNames.SetString("npc_dota_hero_meepo", "Meepo", true);
	actualHeroNames.SetString("npc_dota_hero_mirana", "Mirana", true);
	actualHeroNames.SetString("npc_dota_hero_morphling", "Morphling", true);
	actualHeroNames.SetString("npc_dota_hero_naga_siren", "Naga Siren", true);
	actualHeroNames.SetString("npc_dota_hero_necrolyte", "Necrophos", true);
	actualHeroNames.SetString("npc_dota_hero_nevermore", "Shadow Fiend", true);
	actualHeroNames.SetString("npc_dota_hero_night_stalker", "Night Stalker", true);
	actualHeroNames.SetString("npc_dota_hero_nyx_assassin", "Nyx Assassin", true);
	actualHeroNames.SetString("npc_dota_hero_obsidian_destroyer", "Outworld Devourer", true);
	actualHeroNames.SetString("npc_dota_hero_ogre_magi", "Ogre Magi", true);
	actualHeroNames.SetString("npc_dota_hero_omniknight", "Omniknight", true);
	actualHeroNames.SetString("npc_dota_hero_oracle", "Oracle", true);
	actualHeroNames.SetString("npc_dota_hero_phantom_assassin", "Phantom Assassin", true);
	actualHeroNames.SetString("npc_dota_hero_phantom_lancer", "Phantom Lancer", true);
	actualHeroNames.SetString("npc_dota_hero_phoenix", "Phoenix", true);
	actualHeroNames.SetString("npc_dota_hero_puck", "Puck", true);
	actualHeroNames.SetString("npc_dota_hero_pudge", "Pudge", true);
	actualHeroNames.SetString("npc_dota_hero_pugna", "Pugna", true);
	actualHeroNames.SetString("npc_dota_hero_queenofpain", "Queen of Pain", true);
	actualHeroNames.SetString("npc_dota_hero_rattletrap", "Clockwerk", true);
	actualHeroNames.SetString("npc_dota_hero_razor", "Razor", true);
	actualHeroNames.SetString("npc_dota_hero_riki", "Riki", true);
	actualHeroNames.SetString("npc_dota_hero_rubick", "Rubick", true);
	actualHeroNames.SetString("npc_dota_hero_sand_king", "Sand King", true);
	actualHeroNames.SetString("npc_dota_hero_shadow_demon", "Shadow Demon", true);
	actualHeroNames.SetString("npc_dota_hero_shadow_shaman", "Shadow Shaman", true);
	actualHeroNames.SetString("npc_dota_hero_shredder", "Timbersaw", true);
	actualHeroNames.SetString("npc_dota_hero_silencer", "Silencer", true);
	actualHeroNames.SetString("npc_dota_hero_skeleton_king", "Wraith King", true);
	actualHeroNames.SetString("npc_dota_hero_skywrath_mage", "Skywrath Mage", true);
	actualHeroNames.SetString("npc_dota_hero_slardar", "Slardar", true);
	actualHeroNames.SetString("npc_dota_hero_slark", "Slark", true);
	actualHeroNames.SetString("npc_dota_hero_sniper", "Sniper", true);
	actualHeroNames.SetString("npc_dota_hero_spectre", "Spectre", true);
	actualHeroNames.SetString("npc_dota_hero_spirit_breaker", "Spirit Breaker", true);
	actualHeroNames.SetString("npc_dota_hero_storm_spirit", "Storm Spirit", true);
	actualHeroNames.SetString("npc_dota_hero_sven", "Sven", true);
	actualHeroNames.SetString("npc_dota_hero_techies", "Techies", true);
	actualHeroNames.SetString("npc_dota_hero_templar_assassin", "Templar Assassin", true);
	actualHeroNames.SetString("npc_dota_hero_terrorblade", "Terrorblade", true);
	actualHeroNames.SetString("npc_dota_hero_tidehunter", "Tidehunter", true);
	actualHeroNames.SetString("npc_dota_hero_tinker", "Tinker", true);
	actualHeroNames.SetString("npc_dota_hero_tiny", "Tiny", true);
	actualHeroNames.SetString("npc_dota_hero_treant", "Treant Protector", true);
	actualHeroNames.SetString("npc_dota_hero_troll_warlord", "Troll Warlord", true);
	actualHeroNames.SetString("npc_dota_hero_tusk", "Tusk", true);
	actualHeroNames.SetString("npc_dota_hero_undying", "Undying", true);
	actualHeroNames.SetString("npc_dota_hero_ursa", "Ursa", true);
	actualHeroNames.SetString("npc_dota_hero_vengefulspirit", "Vengeful Spirit", true);
	actualHeroNames.SetString("npc_dota_hero_venomancer", "Venomancer", true);
	actualHeroNames.SetString("npc_dota_hero_visage", "Visage", true);
	actualHeroNames.SetString("npc_dota_hero_warlock", "Warlock", true);
	actualHeroNames.SetString("npc_dota_hero_weaver", "Weaver", true);
	actualHeroNames.SetString("npc_dota_hero_windrunner", "Windranger", true);
	actualHeroNames.SetString("npc_dota_hero_winter_wyvern", "Winter Wyvern", true);
	actualHeroNames.SetString("npc_dota_hero_wisp", "Io", true);
	actualHeroNames.SetString("npc_dota_hero_witch_doctor", "Witch Doctor", true);
	actualHeroNames.SetString("npc_dota_hero_zuus", "Zeus", true);
	return 0;
}

 