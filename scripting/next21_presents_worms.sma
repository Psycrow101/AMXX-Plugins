/*
https://next21.ru/2013/05/%D0%BF%D0%BB%D0%B0%D0%B3%D0%B8%D0%BD-worms-presents-style/
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta_util>
#include <hamsandwich>
#include <WPMGPrintChatColor>

#define PLUGIN "Worms Presents Style"
#define VERSION "0.7"
#define AUTHOR "Psycrow"

#define SPAWN_MODEL 		"models/next21_worms_style/target.mdl"
#define PARACHUTE_MODEL		"models/next21_worms_style/parachute.mdl"
#define BOX_MODEL 		"models/next21_worms_style/box.mdl"

#define FALL_SOUND		"next21_worms_style/box_fall.wav"
#define CREATE_SOUND		"next21_worms_style/box_create.wav"
#define PICKUP_SOUND		"next21_worms_style/box_pickup.wav"

#define SPAWN_CLASS		"worms_spawn_box"
#define PBOX_CLASS		"worms_parachute_box"
#define BOX_CLASS		"worms_box"

#define pev_notrace		pev_fuser1
#define pev_lifes		pev_euser2

static
	Array:g_wb_id,
	Array:g_wb_origin_x,
	Array:g_wb_origin_y,
	Array:g_wb_origin_z,
	Array:g_steam_ids, //Хранилище steam_id игроков, посетивших игру
	Array:g_weapon_list,
	Array:g_weapon_ammo_list,
	Array:g_utilities_list,
	ExplosionMdl,
	SmokeMdl

new	
	bool: g_save_cpl,
	bool: is_spawns_visible,
	bool: g_ham_reg,
	g_round_times[33],
	g_game_times[33]


public plugin_precache()
{
	precache_model(SPAWN_MODEL)
	precache_model(PARACHUTE_MODEL)
	precache_model(BOX_MODEL)
	
	precache_sound(FALL_SOUND)
	precache_sound(CREATE_SOUND)
	precache_sound(PICKUP_SOUND)
	
	ExplosionMdl = precache_model("sprites/zerogxplode.spr")
	SmokeMdl = precache_model("sprites/steam1.spr")
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_cvar("cv_spawnbox_timerate","60.0")
	register_cvar("cv_box_lifes","0")
	register_cvar("cv_wb_times_round", "0")
	register_cvar("cv_wb_times_game", "0")
	register_cvar("cv_wb_solid", "1")
	
	register_cvar("cv_box_health", "1")
	register_cvar("cv_box_health_value", "50")
	register_cvar("cv_box_ammo", "1")
	register_cvar("cv_box_utilities", "1")
	
	if(!get_cvar_num("cv_box_health") && !get_cvar_num("cv_box_ammo") && !get_cvar_num("cv_box_utilities"))
		return
	
	register_clcmd( "say /wb_spawn_menu", "spawn_menu", ADMIN_IMMUNITY)
	register_clcmd( "say_team /wb_spawn_menu", "spawn_menu", ADMIN_IMMUNITY)
		
	g_wb_id = ArrayCreate()
	g_wb_origin_x = ArrayCreate()
	g_wb_origin_y = ArrayCreate()
	g_wb_origin_z = ArrayCreate()
	
	if(get_cvar_num("cv_box_ammo")) 
	{	
		g_weapon_list = ArrayCreate(32)
		g_weapon_ammo_list = ArrayCreate()
	}
	
	if(get_cvar_num("cv_box_utilities")) g_utilities_list = ArrayCreate(32)
	if(get_cvar_num("cv_wb_times_game")) g_steam_ids = ArrayCreate(32)
	
	new const szEntity[][] = 
	{
		"worldspawn", "func_wall", "func_door",  "func_door_rotating",
		"func_wall_toggle", "func_breakable", "func_pushable", "func_train",
		"func_illusionary", "func_button", "func_rot_button", "func_rotating", BOX_CLASS
	}
    
	for(new i; i<sizeof szEntity; i++)
	{
		register_touch(BOX_CLASS, szEntity[i], "fw_box_touch_world")
		register_touch(PBOX_CLASS, szEntity[i], "fw_pbox_touch_world")
	}
	register_touch(BOX_CLASS, "player", "fw_box_touch_player")
	register_touch(PBOX_CLASS, "player", "fw_box_touch_player")
	
	register_logevent("NewRound", 2, "1=Round_Start")
	
	set_task(get_cvar_float("cv_spawnbox_timerate"), "create_box_pre", _, _, _, "b")
	get_maps_cfg()
	
	if(get_cvar_num("cv_box_ammo")) get_weapon_list()
	if(get_cvar_num("cv_box_utilities")) get_utilities_list()
}

public get_maps_cfg()
{
	new map[32]
	get_mapname(map, charsmax(map))
	formatex(map, charsmax(map),"%s.ini",map)
	
	new cfgDir[64], i_Dir, i_File[128]
	get_configsdir(cfgDir, charsmax(cfgDir))
	formatex(cfgDir, charsmax(cfgDir), "/addons/amxmodx/configs/next21_worms_boxes", cfgDir)
	
	i_Dir = open_dir(cfgDir, i_File, charsmax(i_File))
	
	if(i_Dir)
	{
		while(next_file(i_Dir, i_File, charsmax(i_File)))
		{
			if (i_File[0] == '.')
				continue
				
			if(equal(map, i_File))
			{
				format(i_File,128,"%s/%s",cfgDir, i_File)
				get_spawns(i_File)
				break
			}
		}
	}
	else server_print("[%s] Spawns was not loaded", PLUGIN)
}

public set_maps_cfg()
{
	new map[32]
	get_mapname(map, charsmax(map))
	formatex(map, charsmax(map),"%s.ini",map)
	
	new cfgDir[64], i_File[128]
	get_configsdir(cfgDir, charsmax(cfgDir))
	formatex(cfgDir, charsmax(cfgDir), "%s/next21_worms_boxes", cfgDir)
	formatex(i_File, charsmax(i_File),"%s/%s",cfgDir, map)
	
	if(!dir_exists(cfgDir))
		if(!mkdir(cfgDir))
			return
	
	delete_file(i_File)
	
	static spawn_count; spawn_count = ArraySize(g_wb_id)
	if(!spawn_count)
		return
	
	for(new i=0; i<spawn_count; i++)
	{
		new text[128], Float:fOrigin[3], ent = ArrayGetCell(g_wb_id, i)
		drop_to_floor(ent)
		pev(ent, pev_origin, fOrigin)
		format(text, charsmax(text),"^"%f^" ^"%f^" ^"%f^"",fOrigin[0], fOrigin[1], fOrigin[2])
		write_file(i_File, text, -1) 
	}
}

public get_spawns(i_File[128])
{	
	new file = fopen(i_File,"rt")
	
	if(!file)
	{
		server_print("[%s] Spawns was not loaded", PLUGIN)
		return
	}
	
	while(file && !feof(file))
	{
		new sfLineData[512]
		fgets(file, sfLineData, charsmax(sfLineData))
			
		if(sfLineData[0] == ';')
			continue
			
		if(equal(sfLineData,""))
			continue	
			
		new i_origins[3][32], Float: fOrigins[3]		
		parse(sfLineData, i_origins[0], 31, i_origins[1], 31, i_origins[2], 31)
		
		fOrigins[0] = str_to_float(i_origins[0])
		fOrigins[1] = str_to_float(i_origins[1])
		fOrigins[2] = str_to_float(i_origins[2])
		
		create_spawn(fOrigins)
	}
	
	fclose(file)
	
	if(!ArraySize(g_wb_id))
		server_print("[%s] Spawns was not loaded", PLUGIN)
	else if(ArraySize(g_wb_id) == 1)
		server_print("[%s] Loaded one spawn", PLUGIN)
	else
		server_print("[%s] Loaded %d spawns", PLUGIN, ArraySize(g_wb_id))
}

public get_weapon_list()
{
	new cfgDir[64], i_File[128]
	get_configsdir(cfgDir, charsmax(cfgDir))
	formatex(i_File, charsmax(i_File), "%s/next21_worms_boxes/lists/weapon_list.ini", cfgDir)
	
	new file = fopen(i_File,"rt")
	
	if(!file)
		return
		
	while(file && !feof(file))
	{
		new sfLineData[512]
		fgets(file, sfLineData, charsmax(sfLineData))
			
		if(sfLineData[0] == ';')
			continue
			
		if(equal(sfLineData,""))
			continue	
			
		new weapon_name[32], weapon_ammo[8]
		parse(sfLineData, weapon_name, charsmax(weapon_name), weapon_ammo, charsmax(weapon_ammo))
		ArrayPushString(g_weapon_list, weapon_name)
		ArrayPushCell(g_weapon_ammo_list, str_to_num(weapon_ammo))
	}
	
	fclose(file)
}

public get_utilities_list()
{
	new cfgDir[64], i_File[128]
	get_configsdir(cfgDir, charsmax(cfgDir))
	formatex(i_File, charsmax(i_File), "%s/next21_worms_boxes/lists/utilities_list.ini", cfgDir)
	
	new file = fopen(i_File,"rt")
	
	if(!file)
		return
		
	while(file && !feof(file))
	{
		new sfLineData[512]
		fgets(file, sfLineData, charsmax(sfLineData))
			
		if(sfLineData[0] == ';')
			continue
			
		if(equal(sfLineData,""))
			continue	
			
		new utility_name[32]
		parse(sfLineData, utility_name, charsmax(utility_name))
		ArrayPushString(g_utilities_list, utility_name)
	}
	
	fclose(file)
}

public spawn_menu(id)
{
	
	/*if(!is_user_access(id))
	{
		PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tУ вас нет прав на эту функцию", PLUGIN) 
		return PLUGIN_HANDLED
	}*/
	
	is_spawns_visible = true

	new menu_name[128]
	static spawn_count; spawn_count = ArraySize(g_wb_id)
	format(menu_name, charsmax(menu_name), "\rРасстановка спаунов для ящиков^n\dТекущий спаун: %d", spawn_count+1)

	new i_menu = menu_create(menu_name, "menu_handler")
	
	menu_additem(i_menu, "\wУстановить спаун", "1", 0)
		
	if(!spawn_count)
	{
		menu_additem(i_menu, "\dУдалить предыдущий спаун", "2", 0)
		menu_additem(i_menu, "\dУдалить все спауны", "3", 0)
		menu_additem(i_menu, "\dСбросить все ящики", "4", 0)
	}
	else
	{
		menu_additem(i_menu, "\wУдалить предыдущий спаун", "2", 0)
		menu_additem(i_menu, "\wУдалить все спауны", "3", 0)	
		menu_additem(i_menu, "\wСбросить все ящики", "4", 0)
	}
	
	if(!g_save_cpl)
		menu_additem(i_menu, "\dСохранить изменения", "5", 0)
	else menu_additem(i_menu, "\wСохранить изменения", "5", 0)

	menu_setprop(i_menu, MPROP_EXIT, MEXIT_ALL)
	menu_setprop(i_menu, MPROP_EXITNAME, "\yВыход")
	menu_display(id, i_menu, 0)
	unhide_spawns()
		
	return PLUGIN_HANDLED
}

public menu_handler(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		hide_spawns()
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	static spawn_count; spawn_count = ArraySize(g_wb_id)
	switch(item)
	{
		case 0:
		{	
			g_save_cpl = true
			
			static Float:fOrigins[3]
			fm_get_aim_origin(id, fOrigins)
			
			create_spawn(fOrigins)
			spawn_menu(id)
		}
		case 1:
		{
			if(!spawn_count)
			{
				PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tНа карте нет спаунов", PLUGIN) 
				spawn_menu(id)
				return PLUGIN_HANDLED
			}
			
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tСпаун удален", PLUGIN)
			
			g_save_cpl = true
			remove_entity(ArrayGetCell(g_wb_id, spawn_count-1))
			ArrayDeleteItem(g_wb_id, spawn_count-1)
			ArrayDeleteItem(g_wb_origin_x, spawn_count-1)
			ArrayDeleteItem(g_wb_origin_y, spawn_count-1)
			ArrayDeleteItem(g_wb_origin_z, spawn_count-1)
			spawn_menu(id)
		}
		case 2:
		{
			if(!spawn_count)
			{
				PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tНа карте нет спаунов", PLUGIN) 
				spawn_menu(id)
				return PLUGIN_HANDLED
			}
			
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tБыло удалено !g%d !tспаун.", PLUGIN, spawn_count)
			
			g_save_cpl = true
			
			for(new i=0; i<spawn_count; i++)
				remove_entity(ArrayGetCell(g_wb_id, i))
			ArrayClear(g_wb_id) 
			ArrayClear(g_wb_origin_x) 
			ArrayClear(g_wb_origin_y) 
			ArrayClear(g_wb_origin_z) 
			spawn_menu(id)
		}
		case 3:
		{
			if(spawn_count)
				for(new i=0; i<spawn_count; i++)
					create_box(i)
			spawn_menu(id)
		}
		case 4:
		{
			if(!g_save_cpl)
			{
				spawn_menu(id)
				return PLUGIN_HANDLED
			}
			
			g_save_cpl = false
			set_maps_cfg()
			
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tСохранено", PLUGIN)
			spawn_menu(id)
		}
	}
	return PLUGIN_HANDLED
}

public create_spawn(Float: fOrigins[3])
{
	static ent; ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(ent)) return
	
	ArrayPushCell(g_wb_id, ent)
		
	ArrayPushCell(g_wb_origin_x, fOrigins[0])
	ArrayPushCell(g_wb_origin_y, fOrigins[1])
	ArrayPushCell(g_wb_origin_z, fOrigins[2])
	
	set_pev(ent, pev_origin, fOrigins)
	engfunc(EngFunc_SetModel, ent, SPAWN_MODEL)
		
	set_pev(ent, pev_solid, SOLID_TRIGGER)
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_classname, SPAWN_CLASS)
	set_pev(ent, pev_lifes, get_cvar_num("cv_box_lifes"))
	
	if(!is_spawns_visible)
		entity_set_int(ent, EV_INT_effects, entity_get_int(ent, EV_INT_effects) | EF_NODRAW)
	
	if(!g_ham_reg)
	{
		RegisterHamFromEntity(Ham_TraceAttack, ent, "fw_box_trace_attack")
		g_ham_reg = true
	}
}

public create_box_pre()
{
	static spawn_count; spawn_count = ArraySize(g_wb_id)
	
	if(!spawn_count)
		return
		
	new boxes_sum = 0
	for(new i=0; i<spawn_count; i++)
	{
		static ent; ent = ArrayGetCell(g_wb_id, i)
		new classname[32]
		pev(ent, pev_classname, classname, charsmax(classname)) 
				
		if(equal(classname, SPAWN_CLASS) && (pev(ent, pev_lifes) || !get_cvar_num("cv_box_lifes")))
			boxes_sum++	
	}
	
	if(!boxes_sum)
		return 
	
	new id = -1
	while(id == -1)
	{
		new i = random_num(0, spawn_count-1)
		
		static ent; ent = ArrayGetCell(g_wb_id, i)
		new classname[32]
		pev(ent, pev_classname, classname, charsmax(classname))
		
		if(equal(classname, SPAWN_CLASS) && (pev(ent, pev_lifes) || !get_cvar_num("cv_box_lifes")))
			id = i
	}
	
	create_box(id)
	
	return
}

public create_box(id)
{
	static ent; ent = ArrayGetCell(g_wb_id, id)
		
	new Float:fOrigin[3], Float:fNewOrigin[3], PC, Float:dist
	fOrigin[0] = ArrayGetCell(g_wb_origin_x, id)
	fOrigin[1] = ArrayGetCell(g_wb_origin_y, id)
	fOrigin[2] = ArrayGetCell(g_wb_origin_z, id)
	fNewOrigin = get_origin_to_roof(ent, fOrigin)
	PC = engfunc(EngFunc_PointContents, fNewOrigin)
	dist = floatabs(fNewOrigin[2]-fOrigin[2])
	
	if(PC != CONTENTS_SKY)
	{
		if(dist - 80.0 <= 90.0) fNewOrigin[2] = fOrigin[2] + 10.0
		else fNewOrigin[2] -= 80.0	
	}
	else fNewOrigin[2] = fOrigin[2] + 200.0
		
	set_pev(ent, pev_origin, fNewOrigin)
	engfunc(EngFunc_SetModel, ent, PARACHUTE_MODEL)
		
	if(get_cvar_num("cv_wb_solid"))
		set_pev(ent, pev_solid, SOLID_BBOX)
	else 
		set_pev(ent, pev_solid, SOLID_TRIGGER)
		
	set_pev(ent, pev_movetype, MOVETYPE_FLY)
	set_pev(ent, pev_velocity, {0.0, 0.0, -40.0})
	set_pev(ent, pev_classname, PBOX_CLASS)
	
	new Float:maxs[3] = {10.0, 10.0, 80.0}
	new Float:mins[3] = {-10.0, -10.0, 0.0}
	engfunc(EngFunc_SetSize, ent, mins, maxs)
	entity_set_int(ent, EV_INT_effects, entity_get_int(ent, EV_INT_effects) & ~EF_NODRAW)
	
	emit_sound(ent, CHAN_ITEM, CREATE_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	new iType = -1
	
	while(iType == -1)
	{
		iType = random_num(0,2)
		
		if(iType == 0 && !get_cvar_num("cv_box_health"))
			iType = -1
			
		if(iType == 1 && !get_cvar_num("cv_box_ammo"))
			iType = -1
			
		if(iType == 2 && !get_cvar_num("cv_box_utilities"))
			iType = -1
	}
		
	set_pev(ent, pev_body, iType)
	set_pev(ent, pev_framerate, 1.0)
	set_pev(ent, pev_sequence, iType)
}

public explode_box(ent)
{
	if(!is_valid_ent(ent)) return
	
	static iOrigin[3], Float: fOrigin[3]
	pev(ent, pev_origin, fOrigin)
	iOrigin[0] = floatround(fOrigin[0])
	iOrigin[1] = floatround(fOrigin[1])
	iOrigin[2] = floatround(fOrigin[2])
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(3)
	write_coord(iOrigin[0])
	write_coord(iOrigin[1])
	write_coord(iOrigin[2])
	write_short(ExplosionMdl)
	write_byte(random_num(0,20) + 20)
	write_byte(12)
	write_byte(0)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(5)
	write_coord(iOrigin[0])
	write_coord(iOrigin[1])
	write_coord(iOrigin[2] + 10)
	write_short(SmokeMdl)
	write_byte(60)
	write_byte(10)
	message_end()
}

public hide_box(ent)
{
	if(!is_valid_ent(ent)) return
			
	set_pev(ent, pev_solid, SOLID_NOT)
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_classname, SPAWN_CLASS)
	
	if(!is_spawns_visible)
		entity_set_int(ent, EV_INT_effects, entity_get_int(ent, EV_INT_effects) | EF_NODRAW)
		
	engfunc(EngFunc_SetModel, ent, SPAWN_MODEL)
	
	new Float:maxs[3] = {0.0, 0.0, 0.0}
	new Float:mins[3] = {0.0, 0.0, 0.0}
	engfunc(EngFunc_SetSize, ent, mins, maxs)
	
	static spawns_count; spawns_count = ArraySize(g_wb_id)
	for (new i=0; i<spawns_count; i++)
		if(ent == ArrayGetCell(g_wb_id, i))
		{
			new Float:fOrigin[3]
			fOrigin[0] = ArrayGetCell(g_wb_origin_x, i)
			fOrigin[1] = ArrayGetCell(g_wb_origin_y, i)
			fOrigin[2] = ArrayGetCell(g_wb_origin_z, i)
			set_pev(ent, pev_origin, fOrigin)
		}
	
	if(pev(ent, pev_lifes))
		set_pev(ent, pev_lifes, pev(ent, pev_lifes)-1) 
}

public hide_spawns()
{
	is_spawns_visible = false
	
	static spawns_count; spawns_count = ArraySize(g_wb_id)
	if(!g_wb_id) return
	
	for (new i=0; i<spawns_count; i++)
	{
		static classname[32], ent; ent = ArrayGetCell(g_wb_id, i)
		pev(ent, pev_classname, classname, charsmax(classname))
		if(!equal(classname, SPAWN_CLASS)) continue
		entity_set_int(ent, EV_INT_effects, entity_get_int(ent, EV_INT_effects) | EF_NODRAW)
	}
}

public unhide_spawns()
{
	static spawns_count; spawns_count = ArraySize(g_wb_id)
	if(!g_wb_id) return
	
	for (new i=0; i<spawns_count; i++)
	{
		static classname[32], ent; ent = ArrayGetCell(g_wb_id, i)
		pev(ent, pev_classname, classname, charsmax(classname))
		if(!equal(classname, SPAWN_CLASS)) continue
		entity_set_int(ent, EV_INT_effects, entity_get_int(ent, EV_INT_effects) & ~EF_NODRAW)
	}
}

public fw_box_trace_attack(ent, attacker, Float:damage, Float:dir[3], ptr, damagetype)
{
	if(!is_valid_ent(ent)) return
	
	static classname[32]
	pev(ent, pev_classname, classname, charsmax(classname)) 
	if(!equal(classname, PBOX_CLASS))
	{
		if(equal(classname, BOX_CLASS) && pev(ent, pev_notrace) < get_gametime())
		{
			explode_box(ent)
			hide_box(ent)
		}
		return
	}
		
	static Float: endtrace[3]
	fm_get_aim_origin(attacker, endtrace)
	
	if(find_closest_bone_to_gunshot(ent, endtrace) == 1)
	{
		engfunc(EngFunc_SetModel, ent, BOX_MODEL)
		set_pev(ent, pev_velocity, {0.0, 0.0, -1.0})
		set_pev(ent, pev_movetype, MOVETYPE_BOUNCE)
		set_pev(ent, pev_classname, BOX_CLASS)
		set_pev(ent, pev_notrace, 0.1 + get_gametime())
		engfunc(EngFunc_SetSize, ent, Float: {-10.0, -10.0, 0.0}, Float: {10.0, 10.0, 28.0})
	}
	else 	
	{	
		explode_box(ent)
		hide_box(ent)
	}
}

public fw_box_touch_player(ent, player)
{
	if(!is_valid_ent(ent)) return
	if(get_cvar_num("cv_wb_times_round") && !g_round_times[player]) return
	if(get_cvar_num("cv_wb_times_game") && !g_game_times[player]) return
	
	if(g_round_times[player]) g_round_times[player]--
	if(g_game_times[player]) g_game_times[player]--
	
	client_cmd(player, "spk %s", PICKUP_SOUND)
	
	static iType; iType = pev(ent, pev_body)
	switch(iType)
	{
		case 0:
		{
			static hp; hp = get_cvar_num("cv_box_health_value")
			fm_set_user_health(player, pev(player, pev_health)+hp)
			PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tВы получаете !gздоровье (%d hp)", PLUGIN, hp)
		}
		case 1:
		{
			static weapon_list_count; weapon_list_count = ArraySize(g_weapon_list)
			if(!weapon_list_count)
			{
				PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tЯщик оказался пустым", PLUGIN)
				hide_box(ent)
				return
			}
			
			static i; i = random_num(0, weapon_list_count-1)
			static weapon_name[32], weapon_short_name[16], blank_str[2]
			ArrayGetString(g_weapon_list, i, weapon_name, charsmax(weapon_name))
			strtok(weapon_name, blank_str, charsmax(blank_str), weapon_short_name, charsmax(weapon_short_name), '_')
			new wEnt = find_ent_by_owner(-1, weapon_name, player)
			if(!wEnt)
			{
				wEnt = ham_give_weapon(player, weapon_name)
				PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tВы подобрали !g%s", PLUGIN, weapon_short_name)
				cs_set_weapon_ammo(wEnt, ArrayGetCell(g_weapon_ammo_list, i))
			}
			else
			{
				PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tВы подобрали патроны для !g%s", PLUGIN, weapon_short_name)
				cs_set_user_bpammo(player, get_weaponid(weapon_name), cs_get_user_bpammo(player, get_weaponid(weapon_name)) + ArrayGetCell(g_weapon_ammo_list, i))
			}
		}
		case 2:
		{
			static utilities_list_count; utilities_list_count = ArraySize(g_utilities_list)
			if(!utilities_list_count)
			{
				PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tЯщик оказался пустым", PLUGIN)
				hide_box(ent)
				return
			}
			
			static i; i = random_num(0, utilities_list_count-1)
			static utility_name[32]
			ArrayGetString(g_utilities_list, i, utility_name, charsmax(utility_name))
			
			if(equal(utility_name,"nightvision"))
			{
				PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tВы подобрали !gnightvision", PLUGIN)
				cs_set_user_nvg(player)
			}
			else if(equal(utility_name,"defuse kit") && cs_get_user_team(player) == CS_TEAM_CT)
			{
				PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tВы подобрали !gdefuse kit", PLUGIN)
				cs_set_user_defuse(player)
			}
			else if(equal(utility_name,"armor"))
			{
				PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tВы подобрали !garmor", PLUGIN)
				cs_set_user_armor(player, 100, CS_ARMOR_KEVLAR)
			}
			else if(equal(utility_name,"armor+helmet"))
			{
				PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tВы подобрали !garmor+helmet", PLUGIN)
				cs_set_user_armor(player, 100, CS_ARMOR_VESTHELM)
			}
			else PrintChatColor(player, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tЯщик оказался пустым", PLUGIN)
		}
	}
	hide_box(ent)
}

public fw_pbox_touch_world(ent, world)
{
	if(!is_valid_ent(ent)) return
					
	engfunc(EngFunc_SetModel, ent, BOX_MODEL)
	set_pev(ent, pev_velocity, {0.0, 0.0, 0.0})
	set_pev(ent, pev_movetype, MOVETYPE_BOUNCE)
	set_pev(ent, pev_classname, BOX_CLASS)	
	set_pev(ent, pev_notrace, 0.1 + get_gametime()) 
	
	new Float:maxs[3] = {10.0, 10.0, 28.0}
	new Float:mins[3] = {-10.0, -10.0, 0.0}
	engfunc(EngFunc_SetSize, ent, mins, maxs)
}

public fw_box_touch_world(ent, world)
{
	if(!is_valid_ent(ent)) return
	
	static Float:fVelocity[3]
	pev(ent, pev_velocity, fVelocity) 
    
	fVelocity[0] *= 0.85
	fVelocity[1] *= 0.85
	fVelocity[2] *= 0.85

	set_pev(ent, pev_velocity, fVelocity) 
	
	if(floatabs(fVelocity[2]) > 100.0) emit_sound(ent, CHAN_ITEM, FALL_SOUND, 1.0, ATTN_NORM, 0, PITCH_NORM)
	else emit_sound(ent, CHAN_ITEM, FALL_SOUND, floatabs(fVelocity[2])/100, ATTN_NORM, 0, PITCH_NORM)
}

public NewRound()
{
	for(new id=1;id<=32;id++)
		g_round_times[id] = get_cvar_num("cv_wb_times_round")		
}

public client_putinserver(id)
{
	if(!get_cvar_num("cv_wb_times_game"))
		return
			
	static id_count; id_count = ArraySize(g_steam_ids)
		
	new steam_id[32]
	get_user_authid(id, steam_id, charsmax(steam_id))
		
	for(new i=0;i<id_count;i++)
	{
		new saved_steam_id[32]
		ArrayGetString (g_steam_ids, id_count-1, saved_steam_id, charsmax(saved_steam_id)) 
		
		if(equal(saved_steam_id, steam_id))
			return
	}
	
	g_game_times[id] = get_cvar_num("cv_wb_times_game")
	ArrayPushString(g_steam_ids, steam_id)
	
	return
}

find_closest_bone_to_gunshot(victim, Float:endtrace[3])
{
	new Float:angles[3], Float:origin[3], Float:dist = 9999999.99, Float:curorigin[3], bone_nr
	for (new i=0;i<=2;i++)
	{
		engfunc(EngFunc_GetBonePosition, victim, i, curorigin, angles)
		xs_vec_sub(curorigin, endtrace, angles)
		
		if(xs_vec_len(angles) <= dist)
		{
			origin = curorigin
			dist = xs_vec_len(angles)
			bone_nr = i
		}
	}
	
	return bone_nr
}

Float: get_origin_to_roof(iEnt, Float: fStart[3]) 
{ 
	new Float: fDest[3] = {0.0, 0.0, 9999.0}
	xs_vec_add(fStart, fDest, fDest) 
		 
	engfunc(EngFunc_TraceLine, fStart, fDest, 0, iEnt, 0)
	new Float: fOrigin[3]	
	get_tr2(0, TR_vecEndPos, fOrigin)
	     	     
	return fOrigin
}

ham_give_weapon(id,weapon[])
{
	if(!equal(weapon,"weapon_",7)) return 0
 
	new wEnt = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,weapon))
	if(!pev_valid(wEnt)) return 0
 
	set_pev(wEnt,pev_spawnflags,SF_NORESPAWN)
	dllfunc(DLLFunc_Spawn,wEnt)
     
	if(!ExecuteHamB(Ham_AddPlayerItem,id,wEnt))
	{
		if(pev_valid(wEnt)) set_pev(wEnt,pev_flags,pev(wEnt,pev_flags) | FL_KILLME)
		return 0
	}

	ExecuteHamB(Ham_Item_AttachToPlayer,wEnt,id)
	return wEnt
}