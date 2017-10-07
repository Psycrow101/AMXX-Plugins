/*
https://next21.ru/2013/06/deathrun-%D1%87%D0%B5%D0%BA%D0%BF%D0%BE%D0%B8%D0%BD%D1%82%D1%8B/
*/

#include <amxmodx>
#include <amxmisc>
#include <fakemeta_util>
#include <hamsandwich>
#include <dhudmessage>
#include <WPMGPrintChatColor>

#define PLUGIN "Checkpoints"
#define VERSION "0.7"
#define AUTHOR "Psycrow"

#define MODEL_CP		"models/n21_deathrun/checkpoints/cp.mdl"
#define SOUND_CP		"n21_deathrun/checkpoint2.wav"

#define CLASSNAME_CP		"checkpoint"

#define DHUD_POSITION 		0, 255, 0, -1.0, 0.8, 2, 1.05, 1.05, 0.05, 3.0

#if cellbits == 32
	#define OFFSET_CSMONEY 115
#else
	#define OFFSET_CSMONEY 140
#endif

new
	g_msgMoney,
	g_infoTarget,
	g_maxPlayers,
	bool: g_save_cpl,				//Изменения в расположении чекпоинтов
	bool: g_registration,				//Ничего не регистрировать если чекпоинтов нет
	bool: is_round_end,				//Блокирует сбор чекпоинтов после окончания раунда
	cp_count,					//Кол-во чекпоинтов
	g_cp_pass[33],					//Последний пройденный чекпоинт игроком
	g_finished[33],					//Кто на каком месте пришел к финишу.
	g_fin_pos,					//Последнее занятое место

	Array:g_cp_id,					//Индексы чекпоинтов
	Array:g_cp_origin_x,
	Array:g_cp_origin_y,
	Array:g_cp_origin_z,
	
	P_MONEY,
	P_TELEPORT,
	P_MONEY_GIVE,
	P_MONEY_KOEF,
	P_MONEY_LAST[3],
	P_MONEY_MAX

public plugin_precache()
{
	precache_model(MODEL_CP)
	precache_sound(SOUND_CP)
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
		
	P_MONEY = register_cvar("cv_checkpoint_money","1") // Выдавать ли деньги?
	P_TELEPORT = register_cvar("cv_checkpoint_teleport","1") // Возрождать ли у чекпоинта?
	P_MONEY_GIVE = register_cvar("cv_checkpoint_money_give","300") // Сколько выдавать денег на прохождение обычных чекпоинтов
	P_MONEY_KOEF = register_cvar("cv_checkpoint_money_koef","1") // Умножать ли награду за пройденный чекпоинт на номер чекпоинта?
	P_MONEY_LAST[0] = register_cvar("cv_checkpoint_money_last_first","6000") // Сколько выдавать денег за пройденный последний чекпоинт на первом месте
	P_MONEY_LAST[1] = register_cvar("cv_checkpoint_money_last_second","4000") // На втором месте
	P_MONEY_LAST[2] = register_cvar("cv_checkpoint_money_last_third","3500") // На третьем месте
	P_MONEY_MAX = register_cvar("cv_checkpoint_money_max","16000") // Лимит денег
	
	register_clcmd("say /checkpoint", "checkpoint_menu")
	register_clcmd("say_team /checkpoint", "checkpoint_menu")
				
	g_infoTarget = engfunc(EngFunc_AllocString, "info_target")
}

public plugin_cfg()
{
	new map[32]
	get_mapname(map, charsmax(map))
	add(map, charsmax(map), ".ini")
	
	new cfgDir[64], iDir, szFile[128]
	get_configsdir(cfgDir, charsmax(cfgDir))
	add(cfgDir, charsmax(cfgDir), "/next21_checkpoints")
	
	iDir = open_dir(cfgDir, szFile, charsmax(szFile))
	
	if(iDir)
	{
		if(szFile[0] != '.' && equal(map, szFile))
		{
			format(szFile, charsmax(szFile), "%s/%s", cfgDir, szFile)
			get_checkpoints(szFile)
			return
		}
		
		while(next_file(iDir, szFile, charsmax(szFile)))
		{
			if (szFile[0] == '.')
				continue
				
			if(equal(map, szFile))
			{
				format(szFile, charsmax(szFile), "%s/%s", cfgDir, szFile)
				get_checkpoints(szFile)
				break
			}
		}
	}
	else server_print("[%s] Checkpoints was not loaded", PLUGIN)	
}

public fw_PlayerSpawn(id)
	teleport(id)

public fw_RoundStart()
{
	is_round_end = false
	g_fin_pos = 0
	
	for(new i = 1; i <= g_maxPlayers; i++)
	{
		g_finished[i] = 0
		g_cp_pass[i] = -1
	}
}

public fw_RoundEnd()
{	
	//Тут можно вставить тройку победителей, используя g_finished[id]
	
	is_round_end = true
}

public fw_TouchCheckpoint(ent, id)
{	
	if(is_round_end || !is_user_alive(id) || !pev_valid(ent))
		return
					
	if(g_cp_pass[id] == cp_count-1)
		return
		
	static className[32]
	pev(ent, pev_classname, className, 31)
	if(!equal(className, CLASSNAME_CP))
		return
 
	static i
	for(i = g_cp_pass[id] + 1; i < cp_count; i++)
	{
		if(ent == ArrayGetCell(g_cp_id, i))	
		{		
			client_cmd(id, "spk %s", SOUND_CP)
			g_cp_pass[id] = i
			
			set_dhudmessage(DHUD_POSITION)
			new reward
			
			if(i == cp_count - 1)
			{
				g_fin_pos++
				show_dhudmessage(id, "Вы прошли через последний чекпоинт и финишировали на^n %d месте", g_fin_pos)
				new player_name[32] 
				get_user_name(id, player_name, 31) 	
				PrintChatColor(0, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tИгрок !g%s !tпришел к финишу на !g%d !tместе", PLUGIN, player_name, g_fin_pos) 
				
				if (g_fin_pos < 4)
					reward = get_pcvar_num(P_MONEY_LAST[g_fin_pos - 1])
				else
				{
					reward = get_pcvar_num(P_MONEY_GIVE)
					if(get_pcvar_num(P_MONEY_KOEF))
						reward *= i + 1
				}
				
				g_finished[id] = g_fin_pos
			}
			else
			{
				reward = get_pcvar_num(P_MONEY_GIVE)
				if(get_pcvar_num(P_MONEY_KOEF))
					reward *= i + 1
				show_dhudmessage(id, "Вы прошли через чекпоинт %d",i + 1)
			}
			
			if(get_pcvar_num(P_MONEY))
			{
				new curr_money, max_money
				curr_money = get_pdata_int(id, OFFSET_CSMONEY)
				max_money = get_pcvar_num(P_MONEY_MAX)
	
				if(curr_money + reward > max_money)
					reward = max_money - curr_money
			
				set_pdata_int(id, OFFSET_CSMONEY, curr_money + reward)
			
				message_begin(MSG_ONE, g_msgMoney, _, id)
				write_long(curr_money + reward)
				write_byte(1)
				message_end()
			
				PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tВы получаете !g%d$", PLUGIN, reward) 
			}
		}
	}
}

public checkpoint_menu(id)
{
	if(!(get_user_flags(id) & ADMIN_IMMUNITY))
		return PLUGIN_CONTINUE
	
	new menu_name[80]
	format(menu_name, 79, "\rРасстановка чекпоинтов^n\dТекущий чекпоинт: %d", cp_count + 1)

	new i_menu = menu_create(menu_name, "menu_handler")
	
	menu_additem(i_menu, "\wУстановить Чекпоинт", "1", 0)
	
	if(!cp_count)
	{
		menu_additem(i_menu, "\dУдалить предыдущий Чекпоинт", "2", 0)
		menu_additem(i_menu, "\dУдалить все Чекпоинты", "3", 0)
	}
	else 
	{
		menu_additem(i_menu, "\wУдалить предыдущий Чекпоинт", "2", 0)
		menu_additem(i_menu, "\wУдалить все Чекпоинты", "3", 0)
	}
	
	if(!g_save_cpl)
		menu_additem(i_menu, "\dСохранить изменения", "4", 0)
	else menu_additem(i_menu, "\wСохранить изменения", "4", 0)

	menu_setprop(i_menu, MPROP_EXIT, MEXIT_ALL)
	menu_setprop(i_menu, MPROP_EXITNAME, "\yВыход")
	menu_display(id, i_menu, 0)
		
	return PLUGIN_HANDLED
}

public menu_handler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
	switch(item)
	{
		case 0:
		{		
			new Float:fOrigin[3]
			fm_get_aim_origin(id, fOrigin)
			fOrigin[2] += 60.0
			
			if(create_checkpoint(fOrigin))
				g_save_cpl = true
				
			menu_destroy(menu)
			checkpoint_menu(id)
		}
		case 1:
		{
			if(!cp_count)
			{
				PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tНа карте нет Чекпоинтов", PLUGIN) 
				
				menu_destroy(menu)
				checkpoint_menu(id)
				
				return PLUGIN_HANDLED
			}
			
			g_save_cpl = true
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tЧекпоинт удален", PLUGIN)
			
			cp_count--
			engfunc(EngFunc_RemoveEntity, ArrayGetCell(g_cp_id, cp_count))
			ArrayDeleteItem(g_cp_id, cp_count)
			ArrayDeleteItem(g_cp_origin_x, cp_count)
			ArrayDeleteItem(g_cp_origin_y, cp_count)
			ArrayDeleteItem(g_cp_origin_z, cp_count)
			
			if(cp_count)
			{
				set_pev(ArrayGetCell(g_cp_id, cp_count - 1), pev_body, 1)
				set_pev(ArrayGetCell(g_cp_id, cp_count - 1), pev_skin, 0)
			}
			
			menu_destroy(menu)
			checkpoint_menu(id)
		}
		case 2:
		{
			if(!cp_count)
			{
				PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tНа карте нет Чекпоинтов", PLUGIN) 
				
				menu_destroy(menu)
				checkpoint_menu(id)
				
				return PLUGIN_HANDLED
			}
			
			g_save_cpl = true
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tБыло удалено !g%d !tЧекпоинтов", PLUGIN, cp_count)
			
			for(new i = 0; i < cp_count; i++)
				engfunc(EngFunc_RemoveEntity, ArrayGetCell(g_cp_id, i))
				
			cp_count = 0
			
			ArrayClear(g_cp_id) 
			ArrayClear(g_cp_origin_x) 
			ArrayClear(g_cp_origin_y) 
			ArrayClear(g_cp_origin_z) 
			
			menu_destroy(menu)
			checkpoint_menu(id)
		}
		case 3:
		{
			if(!g_save_cpl)
			{
				menu_destroy(menu)
				checkpoint_menu(id)
				
				return PLUGIN_HANDLED
			}
			
			g_save_cpl = false
			
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !t%s", PLUGIN, set_checkpoints() ? "Сохранено" : "Не сохранено")
			
			menu_destroy(menu)
			checkpoint_menu(id)
		}
	}
	return PLUGIN_HANDLED
}

bool: set_checkpoints()
{
	new map[32]
	get_mapname(map, charsmax(map))
	formatex(map, charsmax(map), "%s.ini", map)
	
	new cfgDir[64], szFile[128]
	get_configsdir(cfgDir, charsmax(cfgDir))
	formatex(cfgDir, charsmax(cfgDir), "%s/next21_checkpoints", cfgDir)
	formatex(szFile, charsmax(szFile), "%s/%s", cfgDir, map)
	
	if(!dir_exists(cfgDir))
		if(!mkdir(cfgDir))
			return false
	
	delete_file(szFile)
	
	if(!cp_count)
		return true
	
	for(new i = 0; i < cp_count; i++)
	{
		new text[128], Float:fOrigin[3], ent = ArrayGetCell(g_cp_id, i)
		pev(ent, pev_origin, fOrigin)
		format(text, charsmax(text),"^"%f^" ^"%f^" ^"%f^"",fOrigin[0], fOrigin[1], fOrigin[2])
		write_file(szFile, text, -1) 
	}
	
	return true
}

get_checkpoints(const szFile[128])
{	
	new file = fopen(szFile, "rt")
	
	if(!file)
	{
		server_print("[%s] Checkpoints was not loaded", PLUGIN)
		return
	}
		
	while(file && !feof(file))
	{
		new sfLineData[512]
		fgets(file, sfLineData, charsmax(sfLineData))
			
		if(sfLineData[0] == ';' || equal(sfLineData, ""))
			continue
						
		new szOrigin[3][32], Float: fOrigin[3]		
		parse(sfLineData, szOrigin[0], 31, szOrigin[1], 31, szOrigin[2], 31)
		
		fOrigin[0] = str_to_float(szOrigin[0])
		fOrigin[1] = str_to_float(szOrigin[1])
		fOrigin[2] = str_to_float(szOrigin[2])
		
		create_checkpoint(fOrigin)
	}
	
	fclose(file)
	
	switch (cp_count)
	{
		case 0: server_print("[%s] Checkpoints was not loaded", PLUGIN)
		case 1: server_print("[%s] Loaded one checkpoint", PLUGIN)
		default: server_print("[%s] Loaded %d checkpoints", PLUGIN, cp_count)
	}
}

bool: create_checkpoint(const Float: fOrigin[3])
{
	new ent = engfunc(EngFunc_CreateNamedEntity, g_infoTarget)
	if(!pev_valid(ent)) return false
	
	if(!g_registration)
	{
		if(get_pcvar_num(P_TELEPORT))
			RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn", 1)
			
		register_event("HLTV", "fw_RoundStart", "a", "1=0", "2=0")
		register_event("SendAudio", "fw_RoundEnd", "a", "2&%!MRAD_rounddraw")
		register_event("SendAudio", "fw_RoundEnd", "a", "2&%!MRAD_terwin")
		register_event("SendAudio", "fw_RoundEnd", "a", "2&%!MRAD_ctwin")
		
		RegisterHamFromEntity(Ham_Touch, ent, "fw_TouchCheckpoint")
		
		fw_RoundStart()
		
		g_cp_id = ArrayCreate()
		g_cp_origin_x = ArrayCreate()
		g_cp_origin_y = ArrayCreate()
		g_cp_origin_z = ArrayCreate()
		
		g_maxPlayers = get_maxplayers()
		g_msgMoney = get_user_msgid("Money")
		
		g_registration = true
	}
		
	ArrayPushCell(g_cp_id, ent)
		
	ArrayPushCell(g_cp_origin_x, fOrigin[0])
	ArrayPushCell(g_cp_origin_y, fOrigin[1])
	ArrayPushCell(g_cp_origin_z, fOrigin[2])
	
	engfunc(EngFunc_SetModel, ent, MODEL_CP)
	set_pev(ent, pev_origin, fOrigin)
	set_pev(ent, pev_solid, SOLID_TRIGGER)
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_sequence, 0)
	set_pev(ent, pev_framerate, 1.0)
	set_pev(ent, pev_classname, CLASSNAME_CP)
	set_pev(ent, pev_effects, 8)
	set_pev(ent, pev_body, 1)
	engfunc(EngFunc_SetSize, ent, Float: {-45.0, -45.0, -45.0}, Float:{45.0, 45.0, 45.0})
	
	cp_count++

	if(cp_count > 1)
	{
		set_pev(ArrayGetCell(g_cp_id, cp_count - 2), pev_body, 0)
		set_pev(ArrayGetCell(g_cp_id, cp_count - 2), pev_skin, random_num(0, 4))
	}
	
	return true
}

teleport(const id)
{
	if(g_cp_pass[id] == -1)
		return
			
	new Float: fOrigin[3]
	fOrigin[0] = ArrayGetCell(g_cp_origin_x, g_cp_pass[id])
	fOrigin[1] = ArrayGetCell(g_cp_origin_y, g_cp_pass[id])
	fOrigin[2] = ArrayGetCell(g_cp_origin_z, g_cp_pass[id])
	
	set_pev(id, pev_origin, fOrigin)
}
