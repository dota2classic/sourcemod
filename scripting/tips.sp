#include <sourcemod>
#include <d2c_subscriptions>
#include <d2c>
// если ты это читаешь, то знай, то что в autismpizda мы переместим в d2c будущем. W

StringMap actualHeroNames;

public Plugin:myinfo =
{
	name = "Tips",
	author = "Vrode normas | ZETA",
	description = "Tip your noob lmao",
	version = "10/10",
	url = "dotaclassic.ru"
};

public void OnPluginStart()
{
	fillActualHeroNames();
	RegConsoleCmd("sm_tip", OnPlayerTip); // для использавание /tip.
}

public Action OnPlayerTip(int client, int args)
{
	if(GameRules_GetProp("m_nGameState") <= DOTA_GAMERULES_STATE_PRE_GAME){
		PrintToChat(client, "\x01\x04[DOTA2CLASSIC]\x01 Вы не можете типнуть игрока не во время игры.");
		return Plugin_Handled;
	}
	if(args < 1) {
		PrintToChat(client, "[DOTA2CLASSIC] Не найден игрок которого вы хотите типнуть. Укажите героя на котором играет игрок, которого вы хотите типнуть. Пример /tip pudge");
		return Plugin_Handled;
	}
	bool noPerson = true;
	char steam32Tipper[64];
	IntToString(GetSteamid(client), steam32Tipper, sizeof(steam32Tipper));
	//if(!HasTipSubscription(steam32Tipper) || TipsLeft(steam32Tipper) <= 0) {PrintToChat(client, "\x01\x04[DOTA2CLASSIC]\x01 Вы не можете типнуть игрока так как у вас отсуствуют типы или DotaClassicPlus."); return Plugin_Handled;}
	if(TipsLeft(steam32Tipper) <= 0) {
		PrintToChat(client, "\x01\x04[DOTA2CLASSIC]\x01 Вы не можете типнуть игрока так как у вас отсуствуют типы");
		return Plugin_Handled;
	}

	bool tripedTipMyself = false;
	char heroTipper[40];
	int steam32TripperInteger = GetSteamid(client);
	int clientIndexTipper = GetPlayerIndex(steam32TripperInteger);
	int heroEntityTipper = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", clientIndexTipper-1); // Вот на эту строку я тебе рекоммендую смотреть, это пиздец.
	if(!IsValidEntity(heroEntityTipper)) return Plugin_Handled;
	GetEntityClassname(heroEntityTipper, heroTipper, sizeof(heroTipper));

	char tipTarget[64];
	GetCmdArg(1, tipTarget, sizeof(tipTarget));
	for(int playerIndex = 0; playerIndex < 10; playerIndex++) {
		int heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", playerIndex);
		if(!IsValidEntity(heroEntity)) continue;
		char heroname[40];
		GetEntityClassname(heroEntity, heroname, sizeof(heroname));
		if(StrContains(heroname, tipTarget, false) >= 0 && !tripedTipMyself) {
			/*if(StrContains(heroTipper, heroname, false) >= 0) {
				tripedTipMyself = true;
				continue;
			}*/
			noPerson = false;
			DoTip(heroTipper, heroname, client, playerIndex);
			break;
		}
	}
	/*for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && !IsFakeClient(i)) {
			char nicknameChecker[64];
			char nicknameWhoTipped[64];
			GetClientName(i, nicknameChecker, sizeof(nicknameChecker));
			GetClientName(client, nicknameWhoTipped, sizeof(nicknameWhoTipped));
			if(StrEqual(nicknameChecker, nicknameGotTipped)) {
				NoPerson = false;
				DoTip(nicknameWhoTipped, nicknameGotTipped, client, i);
				break;
			}
		}
	}*/
	if(!noPerson) return Plugin_Handled;
	if(tripedTipMyself) {
		PrintToChat(client, "\x01\x04[DOTA2CLASSIC]\x01 Вы не можете типнуть самого себя.");
		return Plugin_Handled;
	}
	char msgToPutOnConsole[1024];
	Format(msgToPutOnConsole, sizeof(msgToPutOnConsole), "\n\n\n[DOTA2CLASSIC] Игроки(Герои) который вы можете типнуть.\n");
	for(int zzz = 0; zzz < 10; zzz++) {
		int heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", zzz);
		char heroname[128];
		GetEntityClassname(heroEntity, heroname, sizeof(heroname));
		ReplaceString(heroname, 128, "npc_dota_hero_", "");
		Format(msgToPutOnConsole, sizeof(msgToPutOnConsole), "%s%s\n", msgToPutOnConsole, heroname);
	}
	Format(msgToPutOnConsole, sizeof(msgToPutOnConsole), "%s[DOTA2CLASSIC] Для типа: /tip hero\n\n\n", msgToPutOnConsole);
	PrintToChat(client, "\x01\x04[DOTA2CLASSIC]\x01 к сожалению, данного игрока нет. Посмотрите консоль.");
	PrintToConsole(client, msgToPutOnConsole);
}

public void DoTip(char whoTipped[40], char tippedPlayer[40], int client, int tippedindex)
{
	char actualHeroNameTipper[64];
	actualHeroNames.GetString(whoTipped, actualHeroNameTipper, 64);
	char actualHeroNameTipped[64];
	actualHeroNames.GetString(tippedPlayer, actualHeroNameTipped, 64);
	int steam32ForTipInteregr = GetSteamid(client);
	int cIndex = GetPlayerIndex(steam32ForTipInteregr);
	ReduceTips(cIndex);
	PrintToChatAll("\x01\x04[DOTA2CLASSIC]\x01 \x04%s%s\x01 похвалил \x07%s%s\x01 за игру. Хорошо сыграно!\x01", GetPlayerColor(client-1), actualHeroNameTipper, GetPlayerColor(tippedindex), actualHeroNameTipped);
	for(int z = 1; z <= MaxClients; z++)
	{
		if (!IsClientInGame(z) || IsFakeClient(z)) continue;

		ClientCommand(z, "playgamesound ui/coins.wav");
	}
}

public fillActualHeroNames()
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
}