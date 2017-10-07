/*
https://next21.ru/2013/07/%D0%BF%D0%BB%D0%B0%D0%B3%D0%B8%D0%BD-%D0%B4%D1%83%D1%8D%D0%BB%D0%B8/
*/

#include <amxmodx>
#include <fakemeta>
#include <xs>
#include <hamsandwich>
#include <WPMGPrintChatColor>

//#define AES_EXP

#if defined AES_EXP
	#include <aes_main>
#endif

#define PLUGIN "Duels"
#define VERSION "0.7"
#define AUTHOR "Psycrow"

#define SOUND_DUEL_ACCEPTED 		"next21_duels/duel_challenge_accepted.wav"
#define SOUND_DUEL_WIN				"next21_duels/win.wav"
#define SOUND_DUEL_LOSE				"next21_duels/lose.wav"

#define SPRITE_DUEL					"sprites/next21_duels/duel.spr"

#define DUEL_SPRITE_DISTANCE		10.0
#define DUEL_WAITING_TIME			10.0

#define Player[%1][%2]		g_player_data[%1 - 1][%2]

enum _:Player_Properties
{
	PlrInServer,
	PlrIsAlive,
	PlrTeam,
	PlrDuelReady,
	PlrDuelWaiting,
	PlrDuelFrags,
	PlrDuelSprite,
	Float: PlrDeathReasonTime,
	Float: PlrDuelWaitingTime
}

new
g_player_data[32][Player_Properties], g_maxplayers, g_infoTarget,
g_forwardAddToFullPack, g_forwardCheckVisibility,
#if !defined AES_EXP
	DUEL_MAXMONEY,
#endif
DUEL_FRAGS, DUEL_REWARD, DUEL_LOSING, DUEL_COMPENSATION, DUEL_SOUNDS, DUEL_SPITE

public plugin_precache()
{		
	precache_sound(SOUND_DUEL_ACCEPTED)
	precache_sound(SOUND_DUEL_WIN)
	precache_sound(SOUND_DUEL_LOSE)
	
	precache_model(SPRITE_DUEL)
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_cvar("cv_duels_frags","3")
	register_cvar("cv_duels_reward","6000")
	register_cvar("cv_duels_losing","3000")
	register_cvar("cv_duels_compensation","3000")
	register_cvar("cv_duels_sounds","1")
	register_cvar("cv_duels_sprite","1")

	register_clcmd( "say /duel", "duel_check_players")
	register_clcmd( "say_team /duel", "duel_check_players")
	
	register_clcmd( "say /unduel", "unduel")
	register_clcmd( "say_team /unduel", "unduel")
	
	register_logevent("fw_RoundStart", 2, "1=Round_Start")
	
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn", 1)
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled", 1)
	RegisterHam(Ham_Player_PreThink, "player", "fw_PlayerPreThink")
	
	register_message(get_user_msgid("TeamInfo"), "fw_TeamInfo")
	
	g_maxplayers = get_maxplayers()
	g_infoTarget = engfunc(EngFunc_AllocString, "info_target")
	
	#if !defined AES_EXP
	register_cvar("cv_duels_maxmoney","16000")
	#endif
	
	register_dictionary("next21_duels.txt")
}

public fw_RoundStart()
{
	DUEL_FRAGS = get_cvar_num("cv_duels_frags")
	DUEL_REWARD = get_cvar_num("cv_duels_reward")
	DUEL_LOSING = get_cvar_num("cv_duels_losing")
	DUEL_COMPENSATION = get_cvar_num("cv_duels_compensation")
	DUEL_SOUNDS = get_cvar_num("cv_duels_sounds")
	#if !defined AES_EXP
	DUEL_MAXMONEY = get_cvar_num("cv_duels_maxmoney")
	#endif
		
	if (get_cvar_num("cv_duels_sprite") && !DUEL_SPITE)
	{		
		for(new i = 1; i <= g_maxplayers; i++)
		{
			Player[i][PlrDuelSprite] = engfunc(EngFunc_CreateNamedEntity, g_infoTarget)
			
			if(pev_valid(Player[i][PlrDuelSprite]) != 2)
			{
				Player[i][PlrDuelSprite] = 0
				server_print("[%s] ERROR: sprite duel entities are not initialized", PLUGIN)
				break
			}
		
			engfunc(EngFunc_SetSize, Player[i][PlrDuelSprite], Float: {-1.0, -1.0, -1.0} , Float:{1.0, 1.0, 1.0})
			engfunc(EngFunc_SetModel, Player[i][PlrDuelSprite], SPRITE_DUEL)
			
			set_pev(Player[i][PlrDuelSprite], pev_renderfx, kRenderFxNone)
			set_pev(Player[i][PlrDuelSprite], pev_rendercolor, Float: {255.0, 255.0, 255.0})
			set_pev(Player[i][PlrDuelSprite], pev_rendermode, kRenderTransAdd)
			set_pev(Player[i][PlrDuelSprite], pev_renderamt, 0.0)
			
			set_pev(Player[i][PlrDuelSprite], pev_solid, SOLID_NOT)
			set_pev(Player[i][PlrDuelSprite], pev_movetype, MOVETYPE_PUSHSTEP)
		}
		
		g_forwardAddToFullPack = register_forward(FM_AddToFullPack, "fw_AddToFullPack" , 1)
		g_forwardCheckVisibility = register_forward(FM_CheckVisibility, "fw_CheckVisibility")
		DUEL_SPITE = 1
	}
	else if (!get_cvar_num("cv_duels_sprite") && DUEL_SPITE)
	{
		for(new i = 1; i <= g_maxplayers; i++ )
			if (pev_valid(Player[i][PlrDuelSprite]) == 2)
			{
				Player[i][PlrDuelSprite] = 0
				engfunc(EngFunc_RemoveEntity, Player[i][PlrDuelSprite])
			}
				
		unregister_forward(FM_AddToFullPack, g_forwardAddToFullPack)
		unregister_forward(FM_CheckVisibility, g_forwardCheckVisibility)
		DUEL_SPITE = 0
	}
}

public client_putinserver(id)
{
	Player[id][PlrInServer] = 1
	Player[id][PlrIsAlive] = 0
	Player[id][PlrTeam] = 0
}

public client_disconnect(id)
{
	Player[id][PlrInServer] = 0
	Player[id][PlrIsAlive] = 0
	Player[id][PlrTeam] = 0
	
	if(Player[id][PlrDuelReady] && Player[Player[id][PlrDuelReady]][PlrInServer])
	{	
		if(is_user_connected(Player[id][PlrDuelReady]))
		{
			new playerName[24]
			pev(id, pev_netname, playerName, 23)
			
			PrintChatColor(Player[id][PlrDuelReady], PRINT_COLOR_RED, "!g[%s] !t%L",
				PLUGIN, Player[id][PlrDuelReady], "DUEL_DISCONNECT", playerName)
			
			duel_compensation(Player[id][PlrDuelReady], id)
		}
		else
		{
			Player[Player[id][PlrDuelWaiting]][PlrInServer] = 0
			Player[Player[id][PlrDuelReady]][PlrDuelReady] = 0
			Player[id][PlrDuelReady] = 0
		}
	}
	
	if(Player[id][PlrDuelWaiting] && Player[Player[id][PlrDuelWaiting]][PlrInServer])
	{
		new victim = Player[id][PlrDuelWaiting], playerName[24]
		pev(id, pev_netname, playerName, 23)
		PrintChatColor(victim, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, victim, "DUEL_DISCONNECT_W", playerName)
		
		Player[id][PlrDuelWaiting] = 0
		Player[victim][PlrDuelWaiting] = 0
		
		Player[id][PlrDuelWaitingTime] = 0
		Player[victim][PlrDuelWaitingTime] = 0
	}
}

public fw_PlayerSpawn(id)
{
	if(!is_user_alive(id))
		return HAM_IGNORED
		
	Player[id][PlrTeam] = get_pdata_int(id, 114, 5)
	Player[id][PlrIsAlive] = 1
	
	return HAM_IGNORED
}

public fw_PlayerKilled(victim, attacker, corpse)
{	
	Player[victim][PlrIsAlive] = 0
	
	if (attacker && attacker != victim)
		set_flag_duel(attacker, victim)
}

public fw_PlayerPreThink(id)
{
	if(Player[id][PlrDuelWaiting] && Player[id][PlrDuelWaitingTime] <= get_gametime())
	{
		Player[id][PlrDuelWaitingTime] = 0
		Player[Player[id][PlrDuelWaiting]][PlrDuelWaitingTime] = 0
		
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_WAITING_TIME")
		PrintChatColor(Player[id][PlrDuelWaiting], PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, Player[id][PlrDuelWaiting], "DUEL_WAITING_TIME")
		
		Player[Player[id][PlrDuelWaiting]][PlrDuelWaiting] = 0
		Player[id][PlrDuelWaiting] = 0
	}
}

public fw_TeamInfo()
{
	new id = get_msg_arg_int(1)
	
	new team[2]
	get_msg_arg_string(2, team, 1)
			
	switch (team[0])
	{
		case 'T': Player[id][PlrTeam] = 1
		case 'C': Player[id][PlrTeam] = 2
		case 'S': Player[id][PlrTeam] = 3
		default: Player[id][PlrTeam] = 0
	}
			
	new victim = Player[id][PlrDuelReady]
	if(victim)
	{
		if(Player[victim][PlrInServer])
		{
			if(Player[id][PlrTeam] == Player[victim][PlrTeam]
				|| Player[id][PlrTeam] == 3 || !Player[id][PlrTeam])
			{
				PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_TEAM")
				PrintChatColor(victim, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, victim, "DUEL_TEAM")
				
				if(Player[id][PlrDuelFrags] < Player[victim][PlrDuelFrags])
					duel_compensation(victim, id)
				else if(Player[id][PlrDuelFrags] > Player[victim][PlrDuelFrags])
					duel_compensation(id, victim)
				
				Player[id][PlrDuelFrags] = 0
				Player[victim][PlrDuelFrags] = 0
				Player[id][PlrDuelReady] = 0
				Player[victim][PlrDuelReady] = 0
			}		
		}
		
		victim = Player[id][PlrDuelWaiting]
		if(victim && Player[victim][PlrInServer])	
		{
			if(Player[id][PlrTeam] == Player[victim][PlrTeam]
				|| Player[id][PlrTeam] == 3 || !Player[id][PlrTeam])
			{
				PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_TEAM")
				PrintChatColor(victim, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, victim, "DUEL_TEAM")
				
				Player[id][PlrDuelWaiting] = 0
				Player[victim][PlrDuelWaiting] = 0
				
				Player[id][PlrDuelWaitingTime] = 0
				Player[victim][PlrDuelWaitingTime] = 0
			}
		}
	}
}
	
public fw_AddToFullPack(es_state, e, ent, host, hostflags, player)
{
	if(!Player[host][PlrIsAlive] || !ent || player)
		return FMRES_IGNORED
		
	if(!Player[host][PlrDuelReady])
		return FMRES_IGNORED
					
	static iOwner; iOwner = Player[host][PlrDuelReady]
	if(Player[iOwner][PlrDuelSprite] != ent)
		return FMRES_IGNORED
			
	if(!Player[iOwner][PlrIsAlive])
		return FMRES_IGNORED
				
	static Float: startPosition[3],
	Float: endPosition[3],
	Float: fVector[3],
	Float: fVectorNormal[3],
	Float: fView[3],
	Float: endCurPosition[3]
				
	pev(iOwner, pev_origin, endPosition)
	endPosition[2] += 60.0			
		
	pev(host, pev_origin, startPosition)
	pev(host, pev_view_ofs, fView)
	xs_vec_add(startPosition, fView, startPosition)
		
	xs_vec_sub(endPosition, startPosition, fVector)
	xs_vec_normalize(fVector, fVectorNormal)
		
	engfunc(EngFunc_TraceLine, startPosition, endPosition, IGNORE_MONSTERS, host, 0)
	get_tr2(0, TR_vecEndPos, endCurPosition)
		
	xs_vec_mul_scalar(fVectorNormal, -10.0, fVector)
	xs_vec_add(endCurPosition, fVector, endCurPosition)
		
	if(get_distance_f(startPosition, endCurPosition) - get_distance_f(endPosition, endCurPosition) < 100.0)
	{
		xs_vec_mul_scalar(fVectorNormal, floatmin(100.0, get_distance_f(startPosition, endCurPosition)), endCurPosition)
		xs_vec_add(startPosition, endCurPosition, endCurPosition)
			
		set_es(es_state , ES_Scale , get_distance_f(startPosition, endCurPosition) / 100.0 * 0.5)
	}
		
	set_es(es_state, ES_AimEnt, 0)
	set_es(es_state, ES_Origin , endCurPosition)	
	set_es(es_state, ES_RenderAmt, 255)

	return FMRES_IGNORED
}

public fw_CheckVisibility(ent)
{
	static i
	for(i = 1; i <= g_maxplayers; i++)
	{
		if(Player[i][PlrDuelReady] && Player[i][PlrDuelSprite] == ent && Player[i][PlrIsAlive])
		{
			forward_return(FMV_CELL, 1)
			return FMRES_SUPERCEDE
		}
	}
	
	return FMRES_IGNORED
}

public duel_check_players(id)
{
	if(Player[id][PlrDuelReady])
	{
		new player_name[24]
		pev(Player[id][PlrDuelReady], pev_netname, player_name, 23)
		
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_EXIST", player_name)
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_UNDUEL")
		return
	}
		
	if(Player[id][PlrDuelWaiting])
	{
		new player_name[24]
		pev(Player[id][PlrDuelWaiting], pev_netname, player_name, 23)
		
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_EXIST_W", player_name)
		return
	}
	
	if(!Player[id][PlrTeam] || Player[id][PlrTeam] == 3)
	{
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_WRONG_TEAM")
		return		
	}
	
	new menuName[64]
	format(menuName, 63, "\r%L", id, "DUEL_HEADNAME")
	
	new Players_Menu = menu_create(menuName, "duel_menu_handler")
	new s_Name[24], s_Player[4], iEnemyTeam = Player[id][PlrTeam] == 2 ? 1 : 2
		
	for(new i = 1; i <= g_maxplayers; i++)
	{ 
		if (!Player[i][PlrInServer] || Player[i][PlrTeam] != iEnemyTeam || is_user_hltv(i))
			continue
		
		pev(i, pev_netname, s_Name, 23)
		num_to_str(i, s_Player, 3)
		
		if(Player[i][PlrDuelReady] || Player[i][PlrDuelWaiting])
			format(s_Name, 23, "\d%s", s_Name)
		
		menu_additem(Players_Menu, s_Name, s_Player, 0)
	}
	
	new sMenuProp[3][16]
	format(sMenuProp[0], 15, "%L", id, "MENU_NEXT")
	format(sMenuProp[1], 15, "%L", id, "MENU_BACK")
	format(sMenuProp[2], 15, "%L", id, "MENU_EXIT")
	
	menu_setprop(Players_Menu, MPROP_NEXTNAME, sMenuProp[0])
	menu_setprop(Players_Menu, MPROP_BACKNAME, sMenuProp[1])
	menu_setprop(Players_Menu, MPROP_EXITNAME, sMenuProp[2])
	
	menu_display(id, Players_Menu, 0)
}

public duel_menu_handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
	if(!Player[id][PlrTeam] || Player[id][PlrTeam] == 3)
	{
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_WRONG_TEAM")
		return PLUGIN_HANDLED	
	}
	
	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	
	new key = str_to_num(s_Data)
		
	if(!Player[key][PlrInServer] || Player[id][PlrTeam] == Player[key][PlrTeam] || !Player[key][PlrTeam] || Player[key][PlrTeam] == 3)
	{
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_ERROR_PLAYER")
		duel_check_players(id)
		return PLUGIN_HANDLED
	}
	
	if(Player[key][PlrDuelReady] || Player[key][PlrDuelWaiting])
	{
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_WARNING_PLAYER")
		duel_check_players(id)
		return PLUGIN_HANDLED
	}
	
	new enemyName[24]
	pev(key, pev_netname, enemyName, 23)
	
	PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_WAITING", enemyName)
	Player[key][PlrDuelWaiting] = id
	Player[id][PlrDuelWaiting] = key
	
	new Float: gameTime = get_gametime()
	Player[id][PlrDuelWaitingTime] = _:(gameTime + DUEL_WAITING_TIME)
	Player[key][PlrDuelWaitingTime] = _:(gameTime + DUEL_WAITING_TIME)
	
	menu_destroy(menu)
	
	new menuName[120], playerName[24]
	pev(id, pev_netname, playerName, 23)
	format(menuName, 119, "\r%L", key, "DUEL_CHALLENGE", playerName)
	
	new duel_Menu = menu_create(menuName, "duel_challenge_handler")
	
	new strMenuItem[64]
	format(strMenuItem, 63, "\w%L", key, "DUEL_AGREE")
	menu_additem(duel_Menu, strMenuItem, "1", 0)
	format(strMenuItem, 63, "\w%L", key, "DUEL_REFUSE")
	menu_additem(duel_Menu, strMenuItem, "2", 0)
	
	menu_setprop(duel_Menu, MPROP_EXIT, -1)
	menu_display(key, duel_Menu, 0)
	
	if(is_user_bot(key))
		duel_challenge_handler(key, duel_Menu, 0)
	
	return PLUGIN_CONTINUE
}

public duel_challenge_handler(id, menu, item)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED
	
	new enemy = Player[id][PlrDuelWaiting]
	
	if(!enemy)
	{
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_WAITING_TIME")
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
	switch(item)
	{
		case 0:
		{
			new playerName[24], enemyName[24]
			pev(id, pev_netname, playerName, 23)
			pev(enemy, pev_netname, enemyName, 23)
			PrintChatColor(enemy, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, enemy, "DUEL_PLAYER_AGREE", playerName)
			PrintChatColor(enemy, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, enemy, "DUEL_RULE", DUEL_FRAGS)
			PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_RULE", DUEL_FRAGS)
			Player[enemy][PlrDuelReady] = id
			Player[id][PlrDuelReady] = enemy
			
			if (DUEL_SOUNDS)
			{
				client_cmd(enemy, "spk %s", SOUND_DUEL_ACCEPTED)
				client_cmd(id, "spk %s", SOUND_DUEL_ACCEPTED)
			}
			
			new Float: fOrigin[3]
			pev(enemy, pev_origin, fOrigin)
			engfunc(EngFunc_SetOrigin, Player[id][PlrDuelSprite], fOrigin)
			pev(id, pev_origin, fOrigin)
			engfunc(EngFunc_SetOrigin, Player[enemy][PlrDuelSprite], fOrigin)
			
			menu_destroy(menu)
			
		}
		case 1:
		{
			new playerName[24]
			pev(id, pev_netname, playerName, 23)
			PrintChatColor(enemy, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, enemy, "DUEL_PLAYER_REFUSE", playerName)
			menu_destroy(menu)
		}
		default: return PLUGIN_HANDLED
	}
	
	Player[enemy][PlrDuelWaiting] = 0
	Player[id][PlrDuelWaiting] = 0
	
	Player[id][PlrDuelWaitingTime] = 0
	Player[enemy][PlrDuelWaitingTime] = 0
	
	return PLUGIN_HANDLED	
}

public unduel(id)
{
	new enemy = Player[id][PlrDuelReady]
	
	if(!enemy)
	{
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_NOEXIST")
		return
	}
	
	new playerName[24]
	pev(id, pev_netname, playerName, 23)
	PrintChatColor(enemy, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, enemy, "DUEL_BREAK", playerName)
	PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_BREAK_V")
	
	if(Player[id][PlrDuelFrags] < Player[enemy][PlrDuelFrags])
	{		
		if(DUEL_LOSING)
		{
			#if defined AES_EXP
			aes_add_player_exp(id, -DUEL_LOSING)
			PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_ARS_BREAK_FINE", DUEL_LOSING)
			#else
			new curMoney = cs_get_user_money(id)
			new money = curMoney - DUEL_LOSING < 0 ? curMoney : DUEL_LOSING
			cs_set_user_money(id, curMoney - money)
			PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_BREAK_FINE", money)
			#endif
		}
	}
	
	duel_compensation(enemy, id)
}

set_flag_duel(attacker, victim)
{		
	if(Player[victim][PlrDuelReady] != attacker || Player[attacker][PlrDuelReady] != victim)
		return
	
	new attackerName[24], victimName[24]
	pev(victim, pev_netname, victimName, 23)
	pev(attacker, pev_netname, attackerName, 23)
	
	Player[attacker][PlrDuelFrags]++
	
	if(Player[attacker][PlrDuelFrags] == DUEL_FRAGS)
	{
		PrintChatColor(0, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, LANG_PLAYER, "DUEL_WIN", attackerName, victimName, attackerName, Player[attacker][PlrDuelFrags], Player[victim][PlrDuelFrags])
		
		if(DUEL_REWARD)
		{
			#if defined AES_EXP
			aes_add_player_exp(attacker, DUEL_REWARD)
			PrintChatColor(attacker, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, attacker, "DUEL_AES_REWARD", DUEL_REWARD)
			#else
			new curMoney = cs_get_user_money(attacker)
			new money = curMoney + DUEL_REWARD > DUEL_MAXMONEY ? DUEL_MAXMONEY - curMoney : DUEL_REWARD
			cs_set_user_money(attacker, curMoney + money)
			PrintChatColor(attacker, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, attacker, "DUEL_REWARD", money)
			#endif
		}
		
		if(DUEL_LOSING)
		{
			#if defined AES_EXP
			aes_add_player_exp(victim, -DUEL_LOSING)
			PrintChatColor(victim, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, victim, "DUEL_AES_LOOSE", DUEL_LOSING)
			#else
			new curMoney = cs_get_user_money(victim)
			new money = curMoney - DUEL_LOSING < 0 ? curMoney : DUEL_LOSING
			cs_set_user_money(victim, curMoney - money)
			PrintChatColor(victim, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, victim, "DUEL_LOOSE", money)
			#endif
		}
		
		if(DUEL_SOUNDS)
		{
			client_cmd(attacker, "spk %s", SOUND_DUEL_WIN)
			client_cmd(victim, "spk %s", SOUND_DUEL_LOSE)
		}
		
		Player[attacker][PlrDuelFrags] = 0
		Player[victim][PlrDuelFrags] = 0
		Player[attacker][PlrDuelReady] = 0
		Player[victim][PlrDuelReady] = 0
		return
	}
	
	PrintChatColor(attacker, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, attacker, "DUEL_FRAG_A", DUEL_FRAGS - Player[attacker][PlrDuelFrags])
	PrintChatColor(victim, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, victim, "DUEL_FRAG_V", DUEL_FRAGS - Player[attacker][PlrDuelFrags])
}

duel_compensation(id, victim)
{
	if(DUEL_COMPENSATION && Player[id][PlrDuelFrags] > Player[victim][PlrDuelFrags])
	{
		#if defined AES_EXP
		aes_add_player_exp(id, DUEL_COMPENSATION)
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_AES_COMPENSATION", DUEL_COMPENSATION)
		#else
		new curMoney = cs_get_user_money(id)
		new money = curMoney + DUEL_COMPENSATION > DUEL_MAXMONEY ? DUEL_MAXMONEY - curMoney : DUEL_COMPENSATION
		cs_set_user_money(id, curMoney + money)
		PrintChatColor(id, PRINT_COLOR_RED, "!g[%s] !t%L", PLUGIN, id, "DUEL_COMPENSATION", money)
		#endif
	}
	
	Player[id][PlrDuelFrags] = 0
	Player[victim][PlrDuelFrags] = 0
	Player[id][PlrDuelReady] = 0
	Player[victim][PlrDuelReady] = 0
}