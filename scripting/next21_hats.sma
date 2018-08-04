/*
https://next21.ru/2016/04/hats/
*/

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <nvault>

#if AMXX_VERSION_NUM < 183
	#define client_disconnected client_disconnect
	#include <colorchat>
#endif

#define PLUGIN 		"Hats"
#define AUTHOR 		"Psycrow"
#define VERSION 	"1.5"

#define HATS_PATH 		"models/next21_hats"
#define MAX_HATS 		64
#define VIP_FLAG 		ADMIN_LEVEL_H
#define VAULT_DAYS 		30

#define MENU_SIZE 		1124
#define NAME_LEN 		64

#define KEY_HAT_MODEL	"next21_hat_model"
#define KEY_HAT_PART	"next21_hat_part"

#define MAXSTUDIOBODYPARTS	32
#define	MENU_KEYS	(1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9)

enum _:PLAYER_DATA
{
	PLR_HAT_ENT,
	PLR_CURRENT_PAGE,
	PLR_CURRENT_SUBPAGE,
	PLR_MENU_PAGES,
	PLR_HAT_ID,
	PLR_SUB_ID
}

enum _:HAT_DATA
{
	HAT_MODEL[NAME_LEN],
	HAT_NAME[NAME_LEN],
	HAT_SKINS_NUM,
	HAT_BODIES_NUM,
	HAT_BODIES_NAMES[MAXSTUDIOBODYPARTS * NAME_LEN],
	HAT_VIP_FLAG
}

new g_ePlayerData[33][PLAYER_DATA], g_eHatData[MAX_HATS][HAT_DATA],
	g_iPagesNum, g_iTotalHats, g_infoTarget, g_fwChangeHat, g_vaultHat


public plugin_precache()
{
	new szCfgDir[32], szHatFile[64]
	get_configsdir(szCfgDir, 31)
	formatex(szHatFile, 63, "%s/HatList.ini", szCfgDir)
	load_hats(szHatFile)
	
	new szCurrentFile[256]
	for (new i = 1; i < g_iTotalHats; i++)
	{
		formatex(szCurrentFile, 255, "%s/%s", HATS_PATH, g_eHatData[i][HAT_MODEL])
		precache_model(szCurrentFile)
		server_print("[%s] Precached %s", PLUGIN, szCurrentFile)
	}
}

public plugin_cfg()
{
	g_vaultHat = nvault_open("next21_hat")
			
	if (g_vaultHat == INVALID_HANDLE)
		set_fail_state("Error opening nVault!")
		
	nvault_prune(g_vaultHat, 0, get_systime() - (86400 * VAULT_DAYS))
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
		
	register_concmd("amx_givehat", "cmd_give_hat", ADMIN_RCON, "<nick> <hat #> <part #>")
	register_concmd("amx_removehats", "cmd_remove_all_hats", ADMIN_RCON, " - Removes hats from everyone")
	
	register_menucmd(register_menuid("\yHat Menu: ["), MENU_KEYS, "menu_handler")
	register_menucmd(register_menuid("\yHat Skin ("), MENU_KEYS, "menu_skins_handler")
	register_menucmd(register_menuid("\yHat Model ("), MENU_KEYS, "menu_bodies_handler")
	
	register_clcmd("say /hats", "cmd_show_menu", -1, "Shows hats menu")
	register_clcmd("say_team /hats", "cmd_show_menu", -1, "Shows hats menu")
	register_clcmd("hats", "cmd_show_menu", -1, "Shows hats menu")

	register_dictionary("next21_hats.txt")
	
	g_fwChangeHat = CreateMultiForward("ka_change_hat", ET_STOP, FP_CELL, FP_CELL)
	g_infoTarget = engfunc(EngFunc_AllocString, "info_target")
}

public plugin_end()
{
	nvault_close(g_vaultHat)
	DestroyForward(g_fwChangeHat)
}

public client_putinserver(id)
{
	remove_hat(id)

	new szKey[64], szHatModel[128], szHatPart[3], szAuthid[24]

	get_user_authid(id, szAuthid, 23)
	formatex(szKey, 63, "%s%s", szAuthid, KEY_HAT_MODEL)
	nvault_get(g_vaultHat, szKey, szHatModel, 127)
			
	formatex(szKey, 63, "%s%s", szAuthid, KEY_HAT_PART)
	nvault_get(g_vaultHat, szKey, szHatPart, 2)
											
	if (szHatModel[0])
	{
		if (equal(szHatModel, "!NULL"))
			set_hat(id, 0, id)
		else
		{
			for (new i = 1; i < g_iTotalHats; i++)
			{
				if (equal(szHatModel, g_eHatData[i][HAT_MODEL]))
				{
					if (g_eHatData[i][HAT_VIP_FLAG] && !(get_user_flags(id) & VIP_FLAG))
					{
						set_hat(id, 0, id)
						client_print_color(id, print_team_red, "^4[%s] ^3%L", PLUGIN, id, "HAT_ONLY_VIP")
					}
					else
						set_hat(id, i, id, str_to_num(szHatPart))

					break
				}
			}
		}
	}
}

#if AMXX_VERSION_NUM < 183
public client_disconnect(id)
#elseif
public client_disconnected(id)
#endif
{
	remove_hat(id)
}

public fw_PlayerSpawn_Post(const id)
{
	if (!g_ePlayerData[id][PLR_HAT_ID] || !is_user_alive(id))
		return HAM_IGNORED

	new iHatId = g_ePlayerData[id][PLR_HAT_ID]

	if (g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG]] != 't')
		return HAM_IGNORED

	if (g_eHatData[iHatId][HAT_BODIES_NUM] > 1)
		set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_body, get_pdata_int(id, 114) == 2)
	
	if (g_eHatData[iHatId][HAT_SKINS_NUM] > 1)
		set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_skin, get_pdata_int(id, 114) == 2)
		
	return HAM_IGNORED
}

public cmd_show_menu(id)
{
	g_ePlayerData[id][PLR_CURRENT_PAGE] = 1
	show_hats(id)
	return PLUGIN_HANDLED
}

public cmd_give_hat(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_CONTINUE

	new szPlayerName[32], szHatId[3], szPartId[3]
	read_argv(1, szPlayerName, 31)
	read_argv(2, szHatId, 2)
	read_argv(3, szPartId, 2)
		
	new iTarget = cmd_target(id, szPlayerName, CMDTARGET_ALLOW_SELF)

	if (!iTarget)
	{
		client_print(id, print_console, "[%s] %L", PLUGIN, id, "HAT_NICK_NOT_FOUND")
		return PLUGIN_HANDLED
	}
	
	new iHatId = str_to_num(szHatId)
	
	if (iHatId >= g_iTotalHats)
		return PLUGIN_HANDLED
			
	set_hat(iTarget, iHatId, id, str_to_num(szPartId))
	return PLUGIN_HANDLED
}

public cmd_remove_all_hats(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_CONTINUE

	for (new i = 1; i <= get_maxplayers(); i++)
		if (is_user_connected(i))
			remove_hat(i)
	
	client_print(id, print_console, "[%s] %L", PLUGIN, id, "HAT_ALL_REMOVED")
	return PLUGIN_HANDLED
}

show_hats(id)
{	
	new iKeys = 1<<9
	
	new szMenuBody[MENU_SIZE + 1], iHatId, szMenuItem[256], iPostfix,
		iLen = format(szMenuBody, MENU_SIZE, "\yHat Menu: [%i/%i]^n", g_ePlayerData[id][PLR_CURRENT_PAGE], g_iPagesNum)
	
	for (new i = 0; i < 8; i++)
	{
		iHatId = ((g_ePlayerData[id][PLR_CURRENT_PAGE] * 8) + i - 8)
		if (iHatId >= g_iTotalHats)
			break

		if (iHatId > 0)
		{				
			switch (g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG]])
			{
				case 's': iPostfix = g_eHatData[iHatId][HAT_SKINS_NUM] > 1 ? 1 : 0
				case 'b': iPostfix = g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? 2 : 0
				case 'c': iPostfix = g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? 2 : g_eHatData[iHatId][HAT_SKINS_NUM] > 1 ? 1 : 0 // if bodies > 1 then postfix = 2, else if skins > 1 then postfix = 1, else postfix = 0
				case 't': iPostfix = (g_eHatData[iHatId][HAT_BODIES_NUM] > 1 || g_eHatData[iHatId][HAT_SKINS_NUM] > 1) ? 3 : 0
				default: iPostfix = 0
			}
							
			if (g_eHatData[iHatId][HAT_VIP_FLAG])
			{
				if (!iPostfix)
					format(szMenuItem, charsmax(szMenuItem), "\r[VIP] \y%s",
						g_eHatData[iHatId][HAT_NAME][1])
				else if (iPostfix == 3)
					format(szMenuItem, charsmax(szMenuItem), "\r[VIP] \y%s \w[\r%L\w]",
						g_eHatData[iHatId][HAT_NAME][2], id, g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? "HAT_POSTFIX_TEAM_MODEL" : "HAT_POSTFIX_TEAM_COLOR") 
				else
					format(szMenuItem, charsmax(szMenuItem), "\r[VIP] \y%s \w[\r%L\w]",
						g_eHatData[iHatId][HAT_NAME][2], id, iPostfix == 1 ? "HAT_POSTFIX_SKIN" : "HAT_POSTFIX_MODEL") 
			}
			else
			{
				if (!iPostfix)
					format(szMenuItem, charsmax(szMenuItem), "\y%s",
						g_eHatData[iHatId][HAT_NAME])
				else if (iPostfix == 3)
					format(szMenuItem, charsmax(szMenuItem), "\y%s \w[\r%L\w]",
						g_eHatData[iHatId][HAT_NAME][1], id, g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? "HAT_POSTFIX_TEAM_MODEL" : "HAT_POSTFIX_TEAM_COLOR") 
				else
					format(szMenuItem, charsmax(szMenuItem), "\y%s \w[\r%L\w]",
						g_eHatData[iHatId][HAT_NAME][1], id, iPostfix == 1 ? "HAT_POSTFIX_SKIN" : "HAT_POSTFIX_MODEL") 
			}
		}
		else
			format(szMenuItem, charsmax(szMenuItem), "\r%L", id, g_eHatData[iHatId][HAT_NAME])

		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n\w %i. %s", i + 1, szMenuItem)
		iKeys |= 1<<i
	}
	
	if (g_ePlayerData[id][PLR_CURRENT_PAGE] < g_iPagesNum)
	{
		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n^n\w9. %L", id, "HAT_ITEM_NEXT")
		iKeys |= 1<<8
	}
	else
		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n^n\d9. %L", id, "HAT_ITEM_NEXT")
	
	iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n\w0. %L", id, g_ePlayerData[id][PLR_CURRENT_PAGE] > 1 ? "HAT_ITEM_PREV" : "HAT_ITEM_EXIT")
	
	show_menu(id, iKeys, szMenuBody, -1)
	return PLUGIN_HANDLED
}

show_skins(id)
{		
	new iHatId = g_ePlayerData[id][PLR_SUB_ID]
	new iKeys = 1<<9
	
	new szMenuBody[MENU_SIZE + 1], iSkinId,
		iLen = format(szMenuBody, MENU_SIZE, "\yHat Skin (%s): [%i/%i]^n",
			g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG] + 1], g_ePlayerData[id][PLR_CURRENT_SUBPAGE], g_ePlayerData[id][PLR_MENU_PAGES])
				
	for (new i = 0; i < 8; i++)
	{
		iSkinId = ((g_ePlayerData[id][PLR_CURRENT_SUBPAGE] * 8) + i - 8)
		if (iSkinId >= g_eHatData[iHatId][HAT_SKINS_NUM])
			break
		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n\w %i. \ySkin %i", i + 1, iSkinId)
		iKeys |= 1<<i
	}

	if (g_ePlayerData[id][PLR_CURRENT_SUBPAGE] < g_ePlayerData[id][PLR_MENU_PAGES])
	{
		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n^n\w9. %L", id, "HAT_ITEM_NEXT")
		iKeys |= 1<<8
	}
	else
		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n^n\d9. %L", id, "HAT_ITEM_NEXT")
	
	iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n\w0. %L", id, g_ePlayerData[id][PLR_CURRENT_SUBPAGE] > 1 ? "HAT_ITEM_PREV" : "HAT_ITEM_EXIT")

	show_menu(id, iKeys, szMenuBody, -1)
}

show_bodies(id)
{
	new iHatId = g_ePlayerData[id][PLR_SUB_ID]
	new iKeys = 1<<9
	
	new szMenuBody[MENU_SIZE + 1], iBodyId,
		iLen = format(szMenuBody, MENU_SIZE, "\yHat Model (%s): [%i/%i]^n",
			g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG] + 1], g_ePlayerData[id][PLR_CURRENT_SUBPAGE], g_ePlayerData[id][PLR_MENU_PAGES])
								
	for (new i = 0; i < 8; i++)
	{
		iBodyId = ((g_ePlayerData[id][PLR_CURRENT_SUBPAGE] * 8) + i - 8)
		if (iBodyId >= g_eHatData[iHatId][HAT_BODIES_NUM])
			break
		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n\w %i. \y%s", i + 1,
			g_eHatData[iHatId][HAT_BODIES_NAMES][iBodyId * NAME_LEN])
		iKeys |= 1<<i
	}
	
	if (g_ePlayerData[id][PLR_CURRENT_SUBPAGE] < g_ePlayerData[id][PLR_MENU_PAGES])
	{
		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n^n\w9. %L", id, "HAT_ITEM_NEXT")
		iKeys |= 1<<8
	}
	else
		iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n^n\d9. %L", id, "HAT_ITEM_NEXT")
	
	iLen += format(szMenuBody[iLen], MENU_SIZE - iLen, "^n\w0. %L", id, g_ePlayerData[id][PLR_CURRENT_SUBPAGE] > 1 ? "HAT_ITEM_PREV" : "HAT_ITEM_EXIT")
				
	show_menu(id, iKeys, szMenuBody, -1)	
}

public menu_handler(id, iKey) 
{
	switch (iKey)
	{
		case 8: //9 - [Next Page]
		{
			g_ePlayerData[id][PLR_CURRENT_PAGE]++
			show_hats(id)
		}
		case 9:	//0 - [Close]
		{
			if(--g_ePlayerData[id][PLR_CURRENT_PAGE] > 0)
				show_hats(id)
		}
		default:
		{
			new iHatId = ((g_ePlayerData[id][PLR_CURRENT_PAGE] * 8) + iKey - 8)
			
			if (g_eHatData[iHatId][HAT_VIP_FLAG] && !(get_user_flags(id) & VIP_FLAG))
			{
				client_print_color(id, print_team_red, "^4[%s] ^3%L", PLUGIN, id, "HAT_ONLY_VIP")
				show_hats(id)
				return PLUGIN_HANDLED
			}
			
			new iPostfix
			switch (g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG]])
			{
				case 's': iPostfix = g_eHatData[iHatId][HAT_SKINS_NUM] > 1 ? 1 : 0
				case 'b': iPostfix = g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? 2 : 0
				case 'c': iPostfix = g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? 2 : g_eHatData[iHatId][HAT_SKINS_NUM] > 1 ? 1 : 0
				case 't': iPostfix = (g_eHatData[iHatId][HAT_BODIES_NUM] > 1 || g_eHatData[iHatId][HAT_SKINS_NUM] > 1) ? 3 : 0
				default: iPostfix = 0
			}
			
			switch (iPostfix)
			{
				case 1:
				{
					g_ePlayerData[id][PLR_CURRENT_SUBPAGE] = 1
					g_ePlayerData[id][PLR_MENU_PAGES] = floatround(((g_eHatData[iHatId][HAT_SKINS_NUM] + 1) / 8.0), floatround_ceil)
					g_ePlayerData[id][PLR_SUB_ID] = iHatId
					show_skins(id)
				}
				case 2:
				{
					g_ePlayerData[id][PLR_CURRENT_SUBPAGE] = 1
					g_ePlayerData[id][PLR_MENU_PAGES] = floatround(((g_eHatData[iHatId][HAT_BODIES_NUM] + 1) / 8.0), floatround_ceil)
					g_ePlayerData[id][PLR_SUB_ID] = iHatId
					show_bodies(id)
				}
				case 3: set_hat(id, iHatId, id, get_pdata_int(id, 114) == 2)
				default: set_hat(id, iHatId, id)
			}				
		}
	}
	return PLUGIN_HANDLED
}

public menu_skins_handler(id, iKey) 
{
	switch (iKey)
	{
		case 8: //9 - [Next Page]
		{
			g_ePlayerData[id][PLR_CURRENT_SUBPAGE]++
			show_skins(id)
		}
		case 9:	//0 - [Close]
		{
			if(--g_ePlayerData[id][PLR_CURRENT_SUBPAGE] > 0)
				show_skins(id)
			else
				show_hats(id)
		}
		default:
		{	
			new iSkinId = ((g_ePlayerData[id][PLR_CURRENT_SUBPAGE] * 8) + iKey - 8)
			new iHatId = g_ePlayerData[id][PLR_SUB_ID]
			set_hat(id, iHatId, id, iSkinId)
		}
	}
	return PLUGIN_HANDLED
}

public menu_bodies_handler(id, iKey) 
{
	switch(iKey)
	{
		case 8: //9 - [Next Page]
		{
			g_ePlayerData[id][PLR_CURRENT_SUBPAGE]++
			show_bodies(id)
		}
		case 9:	//0 - [Close]
		{
			if(--g_ePlayerData[id][PLR_CURRENT_SUBPAGE] > 0)
				show_bodies(id)
			else
				show_hats(id)
		}
		default:
		{			
			new iBodyId = ((g_ePlayerData[id][PLR_CURRENT_SUBPAGE] * 8) + iKey - 8)
			new iHatId = g_ePlayerData[id][PLR_SUB_ID]
			set_hat(id, iHatId, id, iBodyId)
		}
	}
	return PLUGIN_HANDLED
}

remove_hat(const id)
{
	if (g_ePlayerData[id][PLR_HAT_ENT])
		engfunc(EngFunc_RemoveEntity, g_ePlayerData[id][PLR_HAT_ENT])

	g_ePlayerData[id][PLR_HAT_ENT] = 0
	g_ePlayerData[id][PLR_HAT_ID] = 0
}

set_hat(id, iHatId, iSender, iPart = 0)
{
	new iReturn = PLUGIN_CONTINUE
	
	if (g_eHatData[iHatId][HAT_VIP_FLAG] && !(get_user_flags(id) & VIP_FLAG))
	{
		client_print_color(iSender, print_team_red, "^4[%s] ^3%L", PLUGIN, iSender, "HAT_ONLY_VIP")
		return 0
	}
	
	if (iHatId == 0)
	{
		remove_hat(id)

		client_print_color(iSender, print_team_red, "^4[%s] ^3%L", PLUGIN, iSender, "HAT_REMOVE")

		ExecuteForward(g_fwChangeHat, iReturn, id, 0)

		new szKey[64], szAuthid[24]

		get_user_authid(id, szAuthid, 23)
		
		formatex(szKey, 63, "%s%s", szAuthid, KEY_HAT_MODEL)
		nvault_set(g_vaultHat, szKey, "!NULL")
			
		formatex(szKey, 63, "%s%s", szAuthid, KEY_HAT_PART)
		nvault_set(g_vaultHat, szKey, "0")

		return 0
	}
	
	if (g_ePlayerData[id][PLR_HAT_ENT] < 1)
	{
		g_ePlayerData[id][PLR_HAT_ENT] = engfunc(EngFunc_CreateNamedEntity, g_infoTarget)
		if (g_ePlayerData[id][PLR_HAT_ENT] < 1)
			return 0
											
		set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_movetype, MOVETYPE_FOLLOW)
		set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_aiment, id)
		set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_rendermode, kRenderNormal)
		set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_renderamt, 0.0)
	}

	ExecuteForward(g_fwChangeHat, iReturn, id, g_ePlayerData[id][PLR_HAT_ENT])	
	g_ePlayerData[id][PLR_HAT_ID] = iHatId
		
	new szModelName[256]
	formatex(szModelName, 255, "%s/%s", HATS_PATH, g_eHatData[iHatId][HAT_MODEL])	
	engfunc(EngFunc_SetModel, g_ePlayerData[id][PLR_HAT_ENT], szModelName)
	
	new iSkin, iBody, iPrefix
	switch (g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG]])
	{
		case 's':
		{
			iSkin = iPart < g_eHatData[iHatId][HAT_SKINS_NUM] ? iPart : 0
			iBody = 0
			iPrefix = g_eHatData[iHatId][HAT_SKINS_NUM] > 1 ? 1 : 0
		}
		case 'b':
		{
			iSkin = 0
			iBody = iPart < g_eHatData[iHatId][HAT_BODIES_NUM] ? iPart : 0
			iPrefix = g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? 2 : 0
		}
		case 'c':
		{
			iSkin = iPart < g_eHatData[iHatId][HAT_SKINS_NUM] ? iPart : 0
			iBody = iPart < g_eHatData[iHatId][HAT_BODIES_NUM] ? iPart : 0
			iPrefix = g_eHatData[iHatId][HAT_BODIES_NUM] > 1 ? 2 : g_eHatData[iHatId][HAT_SKINS_NUM] > 1 ? 1 : 0
		}
		case 't':
		{
			iSkin = iPart < g_eHatData[iHatId][HAT_SKINS_NUM] ? iPart : 0
			iBody = iPart < g_eHatData[iHatId][HAT_BODIES_NUM] ? iPart : 0
			iPrefix = (g_eHatData[iHatId][HAT_BODIES_NUM] > 1 || g_eHatData[iHatId][HAT_SKINS_NUM] > 1) ? 3 : 0
		}
		default:
		{
			iSkin = 0
			iBody = 0
			iPrefix = 0
		}
	}
	
	switch (iPrefix)
	{
		case 0: client_print_color(iSender, print_team_red, "^4[%s] ^3%L ^4%s", PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG]])
		case 1: client_print_color(iSender, print_team_red, "^4[%s] ^3%L ^4%s ^3(skin %i)", PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG] + 1], iSkin)
		case 2: client_print_color(iSender, print_team_red, "^4[%s] ^3%L ^4%s", PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_BODIES_NAMES][iBody * NAME_LEN])
		case 3: client_print_color(iSender, print_team_red, "^4[%s] ^3%L ^4%s", PLUGIN, iSender, "HAT_SET", g_eHatData[iHatId][HAT_NAME][g_eHatData[iHatId][HAT_VIP_FLAG] + 1])
	}

	set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_skin, iSkin)
	set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_body, iBody)
	
	set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_sequence, iBody)
	set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_framerate, 1.0)
	set_pev(g_ePlayerData[id][PLR_HAT_ENT], pev_animtime, get_gametime())
								
	new szKey[64], szValue[3], szAuthid[24]

	get_user_authid(id, szAuthid, 23)

	formatex(szKey, 63, "%s%s", szAuthid, KEY_HAT_MODEL)
	nvault_set(g_vaultHat, szKey, g_eHatData[iHatId][HAT_MODEL])
			
	formatex(szKey, 63, "%s%s", szAuthid, KEY_HAT_PART)
	formatex(szValue, 2, "%i", iPart)
	nvault_set(g_vaultHat, szKey, szValue)

	return g_ePlayerData[id][PLR_HAT_ENT]
}

load_hats(const szHatFile[64])
{
	if (file_exists(szHatFile))
	{
		g_eHatData[0][HAT_MODEL] = ""
		g_eHatData[0][HAT_NAME] = "HAT_ITEM_REMOVE"
		g_iTotalHats = 1

		new szLineData[128], iFile = fopen(szHatFile, "rt"), iTag
		while (iFile && !feof(iFile))
		{
			fgets(iFile, szLineData, 127)
			
			if (containi(szLineData, ";") > -1 || strlen(szLineData) < 7)
				continue
			
			parse(szLineData, g_eHatData[g_iTotalHats][HAT_MODEL], NAME_LEN - 1,
				g_eHatData[g_iTotalHats][HAT_NAME], NAME_LEN - 1)
			
			new szCurrentFile[256]
			formatex(szCurrentFile, 255, "%s/%s", HATS_PATH, g_eHatData[g_iTotalHats][HAT_MODEL])
				
			if (!file_exists(szCurrentFile))
			{
				server_print("[%s] Failed to precache %s", PLUGIN, szCurrentFile)
				continue
			}
			
			if (g_eHatData[g_iTotalHats][HAT_NAME][0] == 'v')
			{
				iTag = 1
				g_eHatData[g_iTotalHats][HAT_VIP_FLAG] = 1
			}
			else
				iTag = 0
				
			if (g_eHatData[g_iTotalHats][HAT_NAME][iTag] == 's'
				|| g_eHatData[g_iTotalHats][HAT_NAME][iTag] == 'b'
				|| g_eHatData[g_iTotalHats][HAT_NAME][iTag] == 'c' 
				|| g_eHatData[g_iTotalHats][HAT_NAME][iTag] == 't')
			{								
				new studiomodel = fopen(szCurrentFile, "rb"),			
					bodypartindex, numbodyparts, nummodels
											
				fseek(studiomodel, 196, SEEK_SET)
				fread(studiomodel, g_eHatData[g_iTotalHats][HAT_SKINS_NUM], BLOCK_INT)
						
				fseek(studiomodel, 204, SEEK_SET)
				fread(studiomodel, numbodyparts, BLOCK_INT)
				fread(studiomodel, bodypartindex, BLOCK_INT)
						
				fseek(studiomodel, bodypartindex, SEEK_SET)
				for (new i = 0, j; i < numbodyparts; i++)
				{
					fseek(studiomodel, 64, SEEK_CUR)
					fread(studiomodel, nummodels, BLOCK_INT)
					fseek(studiomodel, 4, SEEK_CUR)
					new modelindex; fread(studiomodel, modelindex, BLOCK_INT)
										
					if (nummodels > g_eHatData[g_iTotalHats][HAT_BODIES_NUM])
					{
						g_eHatData[g_iTotalHats][HAT_BODIES_NUM] = nummodels
						
						new nextpos = ftell(studiomodel)	
						fseek(studiomodel, modelindex, SEEK_SET)
						for (j = 0; j < nummodels; j++)
						{
							fread_blocks(studiomodel, g_eHatData[g_iTotalHats][HAT_BODIES_NAMES][j * NAME_LEN], NAME_LEN, BLOCK_CHAR)
							fseek(studiomodel, 48, SEEK_CUR)
						}
						fseek(studiomodel, nextpos, SEEK_SET)
					}
				}
		
				fclose(studiomodel)
			}
			
			static wasSpawnReg
			if (!wasSpawnReg && g_eHatData[g_iTotalHats][HAT_NAME][iTag] == 't'
				&& (g_eHatData[g_iTotalHats][HAT_SKINS_NUM] > 1 || g_eHatData[g_iTotalHats][HAT_BODIES_NUM] > 1))
				{
					RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
					wasSpawnReg = 1
				}
				
			if (++g_iTotalHats == MAX_HATS)
			{
				server_print("[%s] Reached hat limit", PLUGIN)
				break
			}
		}

		if (iFile)
			fclose(iFile)
	}
	
	g_iPagesNum = floatround((g_iTotalHats / 8.0), floatround_ceil)
	server_print("[%s] Loaded %i hats, Generated %i pages)", PLUGIN, g_iTotalHats - 1, g_iPagesNum)
}
