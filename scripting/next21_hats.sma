/*
https://next21.ru/2016/04/hats/
*/

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <WPMGPrintChatColor>

#define PLUG_NAME 		"Hats"
#define PLUG_AUTH 		"Psycrow"
#define PLUG_VERS 		"1.4"

#define MENUSIZE 		1124
#define HATS_PATH 		"models/next21_hats"
#define MAX_HATS 		64
#define VIP_FLAG 		ADMIN_LEVEL_H

#define MAXSTUDIOBODYPARTS	32


new g_bwEnt[33]

new MenuPages, TotalHats
new CurrentMenu[33], CurrentSubMenu[33], CurrentSubPages[33], CurrentSubId[33]

new UserHatId[33]

new HATMDL[MAX_HATS][128]
new HATNAME[MAX_HATS][128] // s - skin only, b - bodies only, c - bodies and skin, n - normal hat, t - team skin, o - not connected
new HATSKINS[MAX_HATS]
new HATBODIES[MAX_HATS]
new HATBODIESNAME[MAX_HATS][MAXSTUDIOBODYPARTS][64]
new HATVIP[MAX_HATS]

new g_InfoTarget, forward_change_hat

public plugin_precache()
{
	new cfgDir[32], HatFile[64]
	get_configsdir(cfgDir, 31)
	formatex(HatFile, 63, "%s/HatList.ini", cfgDir)
	command_load(HatFile)
	
	for (new i = 1; i < TotalHats; ++i)
	{
		new CurrFile[256]
		formatex(CurrFile, charsmax(CurrFile), "%s/%s", HATS_PATH, HATMDL[i])

		precache_model(CurrFile)
		server_print("[%s] Precached %s", PLUG_NAME, CurrFile)
	}
}

public plugin_init()
{
	register_plugin(PLUG_NAME, PLUG_VERS, PLUG_AUTH)
		
	register_concmd("amx_givehat", "Give_Hat", ADMIN_RCON, "<nick> <mdl #> <part #>")
	register_concmd("amx_removehats", "Remove_All_Hat", ADMIN_RCON, " - Removes hats from everyone.")
	
	register_menucmd(register_menuid("\yHat Menu: ["), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "MenuCommand")
	register_menucmd(register_menuid("\yHat Skin ("), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "SkinMenuCommand")
	register_menucmd(register_menuid("\yHat Model ("), (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9), "BodyMenuCommand")
	
	register_clcmd("say /hats", "ShowMenu", -1, "Shows Knife menu")
	register_clcmd("say_team /hats", "ShowMenu", -1, "Shows Knife menu")
	register_clcmd("hats", "ShowMenu", -1, "Shows Knife menu")
	
	forward_change_hat = CreateMultiForward("ka_change_hat", ET_STOP, FP_CELL, FP_CELL)
	g_InfoTarget = engfunc(EngFunc_AllocString, "info_target")
}

public client_putinserver(id)
{
	Remove_Hat(id)
	
	new hatMdl[128], smodelpart[2]
	get_user_info(id, "next21_hat", hatMdl, charsmax(hatMdl))
	get_user_info(id, "next21_hat_part", smodelpart, charsmax(smodelpart))
											
	if(!equal(hatMdl, ""))
	{
		if(equal(hatMdl, "!NULL"))
			Set_Hat(id, 0, id)
		else
		{
			for(new i = 1; i <= TotalHats; i++)
			{
				if(equal(hatMdl, HATMDL[i]))
				{
					if(HATVIP[i] && !(get_user_flags(id) & VIP_FLAG))
					{
						Set_Hat(id, 0, id)
						PrintChatColor(id, _, "!g[%s] !yЭта шапка доступна только для VIP игроков", PLUG_NAME)
					}
					else
						Set_Hat(id, i, id, str_to_num(smodelpart))
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
	Remove_Hat(id)
}

public fw_PlayerSpawn_Post(id)
{
	if (!UserHatId[id] || !is_user_alive(id))
		return HAM_IGNORED

	if (HATNAME[UserHatId[id]][HATVIP[UserHatId[id]]] != 't')
		return HAM_IGNORED
		
	if (HATBODIES[UserHatId[id]] > 1)
		set_pev(g_bwEnt[id], pev_body, get_pdata_int(id, 114) == 2 ? 1 : 0)
	
	if (HATSKINS[UserHatId[id]] > 1)
		set_pev(g_bwEnt[id], pev_skin, get_pdata_int(id, 114) == 2 ? 1 : 0)
		
	return HAM_IGNORED
}

public ShowMenu(id)
{
	CurrentMenu[id] = 1
	ShowHats(id)
	return PLUGIN_HANDLED
}

public ShowHats(id)
{	
	new keys = (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9)
	
	new szMenuBody[MENUSIZE + 1], HatID
	new nLen = format(szMenuBody, MENUSIZE, "\yHat Menu: [%i/%i]^n", CurrentMenu[id], MenuPages)
	
	// Get Hat Names And Add Them To The List
	for (new i = 0; i < 8; i++)
	{
		HatID = ((CurrentMenu[id] * 8) + i - 8)
		if (HatID < TotalHats)
		{
			new hatText[512], prefix
			if(HatID > 0)
			{				
				switch(HATNAME[HatID][HATVIP[HatID]])
				{
					case 's': prefix = HATSKINS[HatID] > 1 ? 1 : 0
					case 'b': prefix = HATBODIES[HatID] > 1 ? 2 : 0
					case 'c': prefix = HATBODIES[HatID] > 1 ? 2 : HATSKINS[HatID] > 1 ? 1 : 0 // if bodies > 1 then postfix = 2, else if skins > 1 then postfix = 1, else postfix = 0
					case 't': prefix = (HATBODIES[HatID] > 1 || HATSKINS[HatID] > 1) ? 3 : 0
					default: prefix = 0
				}
								
				if(HATVIP[HatID])
				{
					if(!prefix)
						format(hatText, charsmax(hatText), "\r[VIP] \y%s", HATNAME[HatID][1])
					else if (prefix == 3)
						format(hatText, charsmax(hatText), "\r[VIP] \y%s \w[\r%s\w]", HATNAME[HatID][2], HATBODIES[HatID] > 1 ? "модель команды" : "цвет команды") 
					else
						format(hatText, charsmax(hatText), "\r[VIP] \y%s \w[\r%s\w]", HATNAME[HatID][2], prefix == 1 ? "выбрать скин" : "выбрать модель") 
				}
				else
				{
					if(!prefix)
						format(hatText, charsmax(hatText), "\y%s", HATNAME[HatID])
					else if (prefix == 3)
						format(hatText, charsmax(hatText), "\y%s \w[\r%s\w]", HATNAME[HatID][1], HATBODIES[HatID] > 1 ? "модель команды" : "цвет команды") 
					else
						format(hatText, charsmax(hatText), "\y%s \w[\r%s\w]", HATNAME[HatID][1], prefix == 1 ? "выбрать скин" : "выбрать модель") 
				}
			}
			else
				format(hatText, charsmax(hatText), "\r%s", HATNAME[HatID])
			nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n\w %i. %s", i + 1, hatText)
		}
	}
	
	// Next Page And Previous/Close
	nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n^n%s", CurrentMenu[id] == MenuPages ? "\d9. Вперед" : "\w9. Вперед")
	nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n\w0. %s", CurrentMenu[id] > 1 ? "Назад" : "Выход")
	
	show_menu(id, keys, szMenuBody, -1)
	return PLUGIN_HANDLED
}

public MenuCommand(id, key) 
{
	switch(key)
	{
		case 8: //9 - [Next Page]
		{
			if(CurrentMenu[id] < MenuPages) CurrentMenu[id]++
			ShowHats(id)
		}
		case 9:	//0 - [Close]
		{
			CurrentMenu[id]--
			if(CurrentMenu[id] > 0)
				ShowHats(id)
		}
		default:
		{
			new HatID = ((CurrentMenu[id] * 8) + key - 8)
			if(HatID >= TotalHats) 
			{
				ShowHats(id)
				return PLUGIN_HANDLED
			}
			
			if(HATVIP[HatID] && !(get_user_flags(id) & VIP_FLAG))
			{
				PrintChatColor(id, _, "!g[%s] !yЭта шапка доступна только для VIP игроков", PLUG_NAME)
				ShowHats(id)
				return PLUGIN_HANDLED
			}
			
			new prefix
			switch(HATNAME[HatID][HATVIP[HatID]])
			{
				case 's': prefix = HATSKINS[HatID] > 1 ? 1 : 0
				case 'b': prefix = HATBODIES[HatID] > 1 ? 2 : 0
				case 'c': prefix = HATBODIES[HatID] > 1 ? 2 : HATSKINS[HatID] > 1 ? 1 : 0
				case 't': prefix = (HATBODIES[HatID] > 1 || HATSKINS[HatID] > 1) ? 3 : 0
				default: prefix = 0
			}
			
			switch (prefix)
			{
				case 1:
				{
					CurrentSubMenu[id] = 1
					CurrentSubPages[id] = floatround(((HATSKINS[HatID] + 1) / 8.0), floatround_ceil)
					CurrentSubId[id] = HatID
					ShowSkins(id)
				}
				case 2:
				{
					CurrentSubMenu[id] = 1
					CurrentSubPages[id] = floatround(((HATBODIES[HatID] + 1) / 8.0), floatround_ceil)
					CurrentSubId[id] = HatID
					ShowBodies(id)
				}
				case 3: Set_Hat(id, HatID, id, get_pdata_int(id, 114) == 2 ? 1 : 0)
				default: Set_Hat(id, HatID, id)
			}				
		}
	}
	return PLUGIN_HANDLED
}

public ShowSkins(id)
{		
	new HatID = CurrentSubId[id]
	new keys = (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9)
	
	new szMenuBody[MENUSIZE + 1], SkinID
	new nLen = format(szMenuBody, MENUSIZE, "\yHat Skin (%s): [%i/%i]^n", HATNAME[HatID][HATVIP[HatID] + 1], CurrentSubMenu[id], CurrentSubPages[id])
				
	for (new i = 0; i < 8; i++)
	{
		SkinID = ((CurrentSubMenu[id] * 8) + i - 8)
		if(SkinID < HATSKINS[HatID])
			nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n\w %i. \yСкин %i", i + 1, SkinID)
	}
	
	// Next Page And Previous/Close
	nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n^n%s", CurrentSubMenu[id] == CurrentSubPages[id] ? "\d9. Вперед" : "\w9. Вперед")
	nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n\w0. %s", CurrentSubMenu[id] > 1 ? "Назад" : "Выход")
				
	show_menu(id, keys, szMenuBody, -1)
}

public SkinMenuCommand(id, key) 
{
	switch(key)
	{
		case 8: //9 - [Next Page]
		{
			if(CurrentSubMenu[id] < CurrentSubPages[id]) CurrentSubMenu[id]++
			ShowSkins(id)
		}
		case 9:	//0 - [Close]
		{
			CurrentSubMenu[id]--
			if(CurrentSubMenu[id] > 0) ShowSkins(id)
			else ShowHats(id)
		}
		default:
		{	
			new SkinID = ((CurrentSubMenu[id] * 8) + key - 8)
			new HatID = CurrentSubId[id]
			if(SkinID >= HATSKINS[HatID]) ShowSkins(id)
			else Set_Hat(id, HatID, id, SkinID)
		}
	}
	return PLUGIN_HANDLED
}

public ShowBodies(id)
{
	new HatID = CurrentSubId[id]
	new keys = (1<<0|1<<1|1<<2|1<<3|1<<4|1<<5|1<<6|1<<7|1<<8|1<<9)
	
	new szMenuBody[MENUSIZE + 1], BodyID
	new nLen = format(szMenuBody, MENUSIZE, "\yHat Model (%s): [%i/%i]^n", HATNAME[HatID][HATVIP[HatID] + 1], CurrentSubMenu[id], CurrentSubPages[id])
								
	for (new i = 0; i < 8; i++)
	{
		BodyID = ((CurrentSubMenu[id] * 8) + i - 8)
		if(BodyID < HATBODIES[HatID])
			nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n\w %i. \y%s", i + 1, HATBODIESNAME[HatID][BodyID])
	}
	
	// Next Page And Previous/Close
	nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n^n%s", CurrentSubMenu[id] == CurrentSubPages[id] ? "\d9. Вперед" : "\w9. Вперед")
	nLen += format(szMenuBody[nLen], MENUSIZE - nLen, "^n\w0. %s", CurrentSubMenu[id] > 1 ? "Назад" : "Выход")
				
	show_menu(id, keys, szMenuBody, -1)	
}

public BodyMenuCommand(id, key) 
{
	switch(key)
	{
		case 8: //9 - [Next Page]
		{
			if(CurrentSubMenu[id] < CurrentSubPages[id]) CurrentSubMenu[id]++
			ShowBodies(id)
		}
		case 9:	//0 - [Close]
		{
			CurrentSubMenu[id]--
			if(CurrentSubMenu[id] > 0) ShowBodies(id)
			else ShowHats(id)
		}
		default:
		{			
			new BodyID = ((CurrentSubMenu[id] * 8) + key - 8)
			new HatID = CurrentSubId[id]
			if(BodyID >= HATBODIES[HatID]) ShowBodies(id)
			else Set_Hat(id, HatID, id, BodyID)
		}
	}
	return PLUGIN_HANDLED
}

public Give_Hat(id)
{
	new smodelnum[5], name[32], smodelpart[2]
	read_argv(1, name, 31)
	read_argv(2, smodelnum, 4)
	read_argv(3, smodelpart, 2)
		
	new player = cmd_target(id, name, 2)
	if (!player)
	{
		PrintChatColor(id, _, "!g[%s] !yИгрок с таким именем не найден", PLUG_NAME)
		return PLUGIN_HANDLED
	}
	
	new imodelnum = str_to_num(smodelnum)
	
	if(imodelnum >= TotalHats)
		return PLUGIN_HANDLED
			
	Set_Hat(player, imodelnum, id, str_to_num(smodelpart))

	return PLUGIN_CONTINUE
}

public Remove_Hat(id)
{
	if(g_bwEnt[id] > 0) engfunc(EngFunc_RemoveEntity, g_bwEnt[id])
	g_bwEnt[id] = 0
	UserHatId[id] = 0
}

public Remove_All_Hat(id)
{
	for(new i = 0; i < get_maxplayers(); ++i)
		if(is_user_connected(i))
			Remove_Hat(i)
	
	client_print(id, print_chat, "[%s] Removed hats from everyone.", PLUG_NAME)
	return PLUGIN_CONTINUE
}

stock Set_Hat(player, imodelnum, targeter, part = 0)
{
	new iReturn = PLUGIN_CONTINUE
	
	if(HATVIP[imodelnum] && !(get_user_flags(player) & VIP_FLAG))
	{
		PrintChatColor(player, _, "!g[%s] !yЭта шапка доступна только для VIP игроков", PLUG_NAME)
		return 0
	}
	
	if(imodelnum == 0)
	{
		Remove_Hat(player)

		PrintChatColor(targeter, _, "!g[%s] !yВы сняли шапку", PLUG_NAME)
		ExecuteForward(forward_change_hat, iReturn, player, 0)
		
		client_cmd(player, "setinfo ^"next21_hat^" ^"!NULL^"")
		client_cmd(player, "setinfo ^"next21_hat_part^" ^"0^"")
		
		return 0
	}
	
	if(g_bwEnt[player] < 1)
	{
		g_bwEnt[player] = engfunc(EngFunc_CreateNamedEntity, g_InfoTarget)
		if(g_bwEnt[player] < 1)
			return 0
											
		set_pev(g_bwEnt[player], pev_movetype, MOVETYPE_FOLLOW)
		set_pev(g_bwEnt[player], pev_aiment, player)
		set_pev(g_bwEnt[player], pev_rendermode, kRenderNormal)
		set_pev(g_bwEnt[player], pev_renderamt, 0.0)
	}

	ExecuteForward(forward_change_hat, iReturn, player, g_bwEnt[player])	
	UserHatId[player] = imodelnum
		
	new mdlName[256]
	formatex(mdlName, charsmax(mdlName), "%s/%s", HATS_PATH, HATMDL[imodelnum])	
	engfunc(EngFunc_SetModel, g_bwEnt[player], mdlName)
	
	new skin, body, prefix
	switch(HATNAME[imodelnum][HATVIP[imodelnum]])
	{
		case 's':
		{
			skin = part < HATSKINS[imodelnum] ? part : 0
			body = 0
			prefix = HATSKINS[imodelnum] > 1 ? 1 : 0
		}
		case 'b':
		{
			skin = 0
			body = part < HATBODIES[imodelnum] ? part : 0
			prefix = HATBODIES[imodelnum] > 1 ? 2 : 0
		}
		case 'c':
		{
			skin = part < HATSKINS[imodelnum] ? part : 0
			body = part < HATBODIES[imodelnum] ? part : 0
			prefix = HATBODIES[imodelnum] > 1 ? 2 : HATSKINS[imodelnum] > 1 ? 1 : 0 // if bodies > 1 then postfix = 2, else if skins > 1 then postfix = 1, else postfix = 0
		}
		case 't':
		{
			skin = part < HATSKINS[imodelnum] ? part : 0
			body = part < HATBODIES[imodelnum] ? part : 0
			prefix = (HATBODIES[imodelnum] > 1 || HATSKINS[imodelnum] > 1) ? 3 : 0
		}
		default:
		{
			skin = 0
			body = 0
			prefix = 0
		}
	}
	
	switch(prefix)
	{
		case 0: PrintChatColor(targeter, _, "!g[%s] !yВы надели шапку !g%s", PLUG_NAME, HATNAME[imodelnum][HATVIP[imodelnum]])
		case 1: PrintChatColor(targeter, _, "!g[%s] !yВы надели шапку !g%s !y(скин %i)", PLUG_NAME, HATNAME[imodelnum][HATVIP[imodelnum] + 1], skin)
		case 2: PrintChatColor(targeter, _, "!g[%s] !yВы надели шапку !g%s", PLUG_NAME, HATBODIESNAME[imodelnum][body])
		case 3: PrintChatColor(targeter, _, "!g[%s] !yВы надели шапку !g%s", PLUG_NAME, HATNAME[imodelnum][HATVIP[imodelnum] + 1])
	}
				
	set_pev(g_bwEnt[player], pev_skin, skin)
	set_pev(g_bwEnt[player], pev_body, body)
	
	set_pev(g_bwEnt[player], pev_sequence, body)
	set_pev(g_bwEnt[player], pev_framerate, 1.0)
	set_pev(g_bwEnt[player], pev_animtime, get_gametime())
							
	client_cmd(player, "setinfo ^"next21_hat^" ^"%s^"", HATMDL[imodelnum])
	client_cmd(player, "setinfo ^"next21_hat_part^" ^"%i^"", part)
	
	return g_bwEnt[player]
}

command_load(HatFile[64])
{
	if(file_exists(HatFile))
	{
		HATMDL[0] = ""
		HATNAME[0] = "Снять шапку"
		TotalHats = 1
		new sfLineData[128], file = fopen(HatFile, "rt"), tag
		while(file && !feof(file))
		{
			fgets(file,sfLineData,127)
			
			// Skip Comment and Empty Lines
			if (containi(sfLineData,";") > -1) continue
			
			// BREAK IT UP!
			parse(sfLineData, HATMDL[TotalHats], 40, HATNAME[TotalHats], 40)
			
			new CurrFile[256]
			formatex(CurrFile, charsmax(CurrFile), "%s/%s", HATS_PATH, HATMDL[TotalHats])
				
			if(!file_exists(CurrFile))
			{
				server_print("[%s] Failed to precache %s", PLUG_NAME, CurrFile)
				continue
			}
			
			if(HATNAME[TotalHats][0] == 'v')
			{
				tag = 1
				HATVIP[TotalHats] = 1
			}
			else
				tag = 0
				
			if(HATNAME[TotalHats][tag] == 's' || HATNAME[TotalHats][tag] == 'b'
				|| HATNAME[TotalHats][tag] == 'c' || HATNAME[TotalHats][tag] == 't')
			{								
				new studiomodel = fopen(CurrFile, "rb"),			
				bodypartindex, numbodyparts, nummodels
											
				fseek(studiomodel, 196, SEEK_SET)
				fread(studiomodel, HATSKINS[TotalHats], BLOCK_INT)
						
				fseek(studiomodel, 204, SEEK_SET)
				fread(studiomodel, numbodyparts, BLOCK_INT)
				fread(studiomodel, bodypartindex, BLOCK_INT)
						
				fseek(studiomodel, bodypartindex, SEEK_SET)
				for(new i = 0; i < numbodyparts; i++)
				{
					fseek(studiomodel, 64, SEEK_CUR)
					fread(studiomodel, nummodels, BLOCK_INT)
					fseek(studiomodel, 4, SEEK_CUR)
					new modelindex; fread(studiomodel, modelindex, BLOCK_INT)
										
					if(nummodels > HATBODIES[TotalHats])
					{
						HATBODIES[TotalHats] = nummodels
						
						new nextpos = ftell(studiomodel)	
						fseek(studiomodel, modelindex, SEEK_SET)
						for(new j = 0; j < nummodels; j++)
						{
							fread_blocks(studiomodel, HATBODIESNAME[TotalHats][j], 64, BLOCK_CHAR)
							fseek(studiomodel, 48, SEEK_CUR)
						}
						fseek(studiomodel, nextpos, SEEK_SET)
					}
				}
		
				fclose(studiomodel)
			}
			
			static wasSpawnReg
			if (!wasSpawnReg && HATNAME[TotalHats][tag] == 't'
				&& (HATSKINS[TotalHats] > 1 || HATBODIES[TotalHats] > 1))
				{
					RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
					wasSpawnReg = 1
				}
				
			
			TotalHats++
			if(TotalHats >= MAX_HATS)
			{
				server_print("[%s] Reached hat limit", PLUG_NAME)
				break
			}
		}
		if(file) fclose(file)
	}
	
	MenuPages = floatround((TotalHats / 8.0), floatround_ceil)
	server_print("[%s] Loaded %i hats, Generated %i pages)", PLUG_NAME, TotalHats - 1, MenuPages)
}

public plugin_end()
{
	DestroyForward(forward_change_hat)
}
