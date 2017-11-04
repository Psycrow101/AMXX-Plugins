/*
https://next21.ru/2013/06/deathrun-%D1%87%D0%B5%D0%BA%D0%BF%D0%BE%D0%B8%D0%BD%D1%82%D1%8B/
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta_util>
#include <hamsandwich>

#if AMXX_VERSION_NUM < 183
#include <colorchat>
#include <dhudmessage>
#endif

#define PLUGIN "Checkpoints"
#define VERSION "0.8"
#define AUTHOR "Psycrow"

#define MODEL_CHECKPOINT			"models/next21_deathrun/checkpoint.mdl"
#define SOUND_CHECKPOINT			"next21_deathrun/checkpoint.wav"

#define CLASSNAME_CHECKPOINT		"next21_checkpoint"

#define MAX_CHECKPOINTS				32
#define TASK_RETURN_PLAYER			100

#define RETURN_PLAYER_TRY_TIMES		10

#define CHECKPOINT_RADIUS	45.0

#define DHUD_POSITION 		0, 255, 0, -1.0, 0.8, 2, 1.05, 1.05, 0.05, 3.0

#define	CHAT_PREFIX			"^3[Checkpoints]"
#define ACCESS_FLAG			ADMIN_MAP
#define COLOR_EFFECT 		// color transition effect in checkpoints
//#define DUELS_ENABLED 	// for https://dev-cs.ru/resources/136/


#if defined DUELS_ENABLED
#include <deathrun_duel>
#endif

enum _:CvarList
{
	CVAR_CHECKPOINT_REWARD,				// common reward, 0 - none
	CVAR_CHECKPOINT_KOEF,				// common reward multiplier
	CVAR_CHECKPOINT_FINISH_REWARD[3],	// rewards for finish, 0 - none
	CVAR_CHECKPOINT_TELEPORT,			// teleport after spawn
	CVAR_CHECKPOINT_LIGHT,				// 0 - none, 1 - light
	CVAR_CHECKPOINT_GLOW,				// glow size
	CVAR_CHECKPOINT_SKIP_LIMIT,			// the number of checkpoints that can't be skipped
	CVAR_CHECKPOINT_MAXMONEY
}

new
	g_iCheckpointsNum,
	g_iCheckpoint[MAX_CHECKPOINTS],
	g_iWasChanged,
	HamHook: g_fwTouch,
	g_iRoundEnd,
	g_iPlrCompleted[33],
	g_iFinishedNum,
	g_iCheckpointKey,
	#if defined DUELS_ENABLED
	g_iDuelStart,
	#endif
	g_pCvars[CvarList]


public plugin_precache()
{
	precache_model(MODEL_CHECKPOINT)
	precache_sound(SOUND_CHECKPOINT)
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
		
	register_menu("Checkpoint Menu", MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_0,
		"handler_checkpoint_menu")
		
	register_concmd("say /checkpoint", "show_checkpoint_menu", ACCESS_FLAG, "-Open Checkpoint Spawn Menu")
	register_concmd("say_team /checkpoint", "show_checkpoint_menu", ACCESS_FLAG, "-Open Checkpoint Spawn Menu")
	
	register_dictionary("next21_checkpoints.txt")
	
	g_pCvars[CVAR_CHECKPOINT_REWARD] = register_cvar("cv_checkpoint_reward", "300")
	g_pCvars[CVAR_CHECKPOINT_KOEF] = register_cvar("cv_checkpoint_money_koef", "1")
	g_pCvars[CVAR_CHECKPOINT_FINISH_REWARD][0] = register_cvar("cv_checkpoint_money_last_first", "6000")
	g_pCvars[CVAR_CHECKPOINT_FINISH_REWARD][1] = register_cvar("cv_checkpoint_money_last_second", "4000")
	g_pCvars[CVAR_CHECKPOINT_FINISH_REWARD][2] = register_cvar("cv_checkpoint_money_last_third", "3500")
	g_pCvars[CVAR_CHECKPOINT_TELEPORT] = register_cvar("cv_checkpoint_teleport", "0")
	g_pCvars[CVAR_CHECKPOINT_LIGHT] = register_cvar("cv_checkpoint_light_effect", "1")
	g_pCvars[CVAR_CHECKPOINT_GLOW] = register_cvar("cv_checkpoint_glow_effect", "0.0")
	g_pCvars[CVAR_CHECKPOINT_SKIP_LIMIT] = register_cvar("cv_checkpoint_skip_limit", "0")
	g_pCvars[CVAR_CHECKPOINT_MAXMONEY] = register_cvar("cv_checkpoint_money_max", "16000")
	
	g_iCheckpointKey = engfunc(EngFunc_AllocString, CLASSNAME_CHECKPOINT)

	load_checkpoints()
}

/*** Checkpoints functions ***/

load_checkpoints()
{
	new szMap[48]
	get_mapname(szMap, 47)
	add(szMap, 47, ".ini")
	
	new szDirCfg[128], iDir, szFile[128]
	get_configsdir(szDirCfg, 127)
	add(szDirCfg, 127, "/next21_checkpoints")
	
	iDir = open_dir(szDirCfg, szFile, 126)
	
	if (!iDir)
	{
		server_print("[%s] Checkpoints were not loaded", PLUGIN)
		return
	}
	
	while (next_file(iDir, szFile, 126))
	{
		if (szFile[0] == '.')
			continue
			
		if (equali(szMap, szFile))
		{
			format(szFile, 126, "%s/%s", szDirCfg, szFile)
			load_spawn(szFile)
			break
		}
	}
	
	close_dir(iDir)
}

load_spawn(const szFile[])
{	
	new iFile = fopen(szFile, "rt")
	
	if (!iFile)
	{
		server_print("[%s] Unable to open %s.", PLUGIN, szFile)
		return
	}
	
	new szLineData[512], szOrigin[3][24], Float: fOrigin[3], szAngle[24], Float: fAngle
	
	while (iFile && !feof(iFile))
	{
		fgets(iFile, szLineData, 511)
			
		if (!szLineData[0] || szLineData[0] == ';')
			continue
						
		parse(szLineData, szOrigin[0], 23, szOrigin[1], 23, szOrigin[2], 23, szAngle, 23)
		
		fOrigin[0] = str_to_float(szOrigin[0])
		fOrigin[1] = str_to_float(szOrigin[1])
		fOrigin[2] = str_to_float(szOrigin[2])
		fAngle = str_to_float(szAngle)
				
		create_checkpoint(fOrigin, fAngle)
	}
	
	fclose(iFile)
	
	switch (g_iCheckpointsNum)
	{
		case 0: server_print("[%s] Checkpoints were not loaded", PLUGIN)
		case 1: server_print("[%s] Loaded one checkpoint", PLUGIN)
		default: server_print("[%s] Loaded %d checkpoints", PLUGIN, g_iCheckpointsNum)
	}

	set_finish_bodypart()
}

create_checkpoint(const Float: fOrigin[3], const Float: fAngle)
{
	static infotarget, iEventsRegistration
	if (!infotarget)
		infotarget = engfunc(EngFunc_AllocString, "info_target")
		
	if (g_iCheckpointsNum == MAX_CHECKPOINTS)
		return 1
		
	new iEnt = engfunc(EngFunc_CreateNamedEntity, infotarget)
	if (pev_valid(iEnt) != 2)
		return 1
				
	engfunc(EngFunc_SetOrigin, iEnt, fOrigin)
	engfunc(EngFunc_SetModel, iEnt, MODEL_CHECKPOINT)
	engfunc(EngFunc_SetSize, iEnt, Float: {-CHECKPOINT_RADIUS, -CHECKPOINT_RADIUS, -CHECKPOINT_RADIUS},
		Float: {CHECKPOINT_RADIUS, CHECKPOINT_RADIUS, CHECKPOINT_RADIUS})
			
	new Float: fAngles[3]
	fAngles[1] = fAngle
	set_pev(iEnt, pev_angles, fAngles)
			
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_movetype, MOVETYPE_NOCLIP)
	set_pev(iEnt, pev_classname, CLASSNAME_CHECKPOINT)
	set_pev(iEnt, pev_impulse, g_iCheckpointKey)
	
	set_pev(iEnt, pev_framerate, 1.0)
	set_pev(iEnt, pev_colormap, random(256))
	
	#if defined COLOR_EFFECT
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	#endif
	
	new Float: fGlow = get_pcvar_float(g_pCvars[CVAR_CHECKPOINT_GLOW])
	if (fGlow > 0.0)
	{
		new Float: fColors[3]
		fColors[0] = random(256) + 0.0
		fColors[1] = random(256) + 0.0
		fColors[2] = random(256) + 0.0
		
		set_pev(iEnt, pev_renderfx, kRenderFxGlowShell)
		set_pev(iEnt, pev_renderamt, fGlow)
		set_pev(iEnt, pev_rendercolor, fColors)
	}
		
	if (get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_LIGHT]))
		set_pev(iEnt, pev_effects, EF_DIMLIGHT)
			
	g_iCheckpoint[g_iCheckpointsNum++] = iEnt
	
	if (!iEventsRegistration)
	{
		register_event("HLTV", "fw_RoundStart", "a", "1=0", "2=0")
		register_event("SendAudio", "fw_RoundEnd", "a", "2&%!MRAD_rounddraw")
		register_event("SendAudio", "fw_RoundEnd", "a", "2&%!MRAD_terwin")
		register_event("SendAudio", "fw_RoundEnd", "a", "2&%!MRAD_ctwin")
				
		g_fwTouch = RegisterHamFromEntity(Ham_Touch, iEnt, "fw_TouchCheckpoint")
		
		#if defined COLOR_EFFECT
		RegisterHamFromEntity(Ham_Think, iEnt, "fw_ThinkCheckpoint")
		#endif
		
		if (g_iWasChanged)
			DisableHamForward(g_fwTouch)
			
		RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn", 1)
		
		fw_RoundStart()
			
		iEventsRegistration = 1
	}
	
	return 0
}

set_finish_bodypart()
{
	if (!g_iCheckpointsNum)	
		return
	
	for (new i = 0; i < g_iCheckpointsNum - 1; i++)
	{
		set_pev(g_iCheckpoint[i], pev_body, 0)
		set_pev(g_iCheckpoint[i], pev_skin, 0)
	}
		
	set_pev(g_iCheckpoint[g_iCheckpointsNum - 1], pev_body, 1)
	set_pev(g_iCheckpoint[g_iCheckpointsNum - 1], pev_skin, 1)
}

save_checkpoints()
{
	new szDirCfg[128], szFile[128]
	get_configsdir(szDirCfg, 127)
	add(szDirCfg, 127, "/next21_checkpoints")
	
	get_mapname(szFile, 127)
	format(szFile, 127, "%s/%s.ini", szDirCfg, szFile)
	
	if (!dir_exists(szDirCfg))
		mkdir(szDirCfg)
	
	delete_file(szFile)
	
	if (!g_iCheckpointsNum)
		return 0
		
	for (new i = 0; i < g_iCheckpointsNum; i++)
	{
		new szText[128], Float: fOrigin[3], Float: fAngles[3]
		pev(g_iCheckpoint[i], pev_origin, fOrigin)
		pev(g_iCheckpoint[i], pev_angles, fAngles)
		format(szText, 127, "^"%f^" ^"%f^" ^"%f^" ^"%f^"",
			fOrigin[0], fOrigin[1], fOrigin[2], fAngles[2])
		write_file(szFile, szText, -1)
	}
	
	return 0
}

/*** Menu handlers ***/

public show_checkpoint_menu(id, level, cid)
{
	if (cmd_access(id, level, cid, 1))
		display_checkpoint_menu(id)
	
	return PLUGIN_HANDLED
}

display_checkpoint_menu(const id)
{
	new szMenu[512], iLen, iKeys = MENU_KEY_0
	
	iLen = formatex(szMenu, 511, "\r%L \y[\w%i/%i\y]^n^n",
		LANG_PLAYER, "MENU_HEADER", g_iCheckpointsNum, MAX_CHECKPOINTS)
		
	if (g_iCheckpointsNum != MAX_CHECKPOINTS)
	{
		iLen += formatex(szMenu[iLen], 511 - iLen, "\r1. \w%L^n", id, "MENU_SPAWN")
		iKeys |= MENU_KEY_1
	}
			
	if (g_iCheckpointsNum)
	{
		iLen += formatex(szMenu[iLen], 511 - iLen, "\r2. \w%L^n", id, "MENU_REMOVE")
		iLen += formatex(szMenu[iLen], 511 - iLen, "\r3. \w%L^n", id, "MENU_REMOVE_ALL")
		iKeys |= MENU_KEY_2 | MENU_KEY_3
	}
	
	if (g_iWasChanged)
	{
		iLen += formatex(szMenu[iLen], 511 - iLen, "^n\r4. \w%L^n", id, "MENU_SAVE")
		iKeys |= MENU_KEY_4
	}
	
	iLen += formatex(szMenu[iLen], 511 - iLen, "^n\r0. \w%L", id, "MENU_EXIT")
			
	show_menu(id, iKeys, szMenu, -1, "Checkpoint Menu")
}

public handler_checkpoint_menu(id, key)
{
	if (key == 9)
		return PLUGIN_CONTINUE
		
	switch (key + 1)
	{
		case 1:
		{
			new Float: fOrigin[3], Float: fAngles[3]
			fm_get_aim_origin(id, fOrigin)
			fOrigin[2] += CHECKPOINT_RADIUS
			pev(id, pev_v_angle, fAngles)
			
			if (!create_checkpoint(fOrigin, fAngles[1]))
			{
				set_finish_bodypart()
				g_iWasChanged = 1
				DisableHamForward(g_fwTouch)
				
				if (check_stuck(fOrigin, id))
					client_print_color(id, print_team_red, "%s ^1%L", CHAT_PREFIX, LANG_PLAYER, "CP_CAN_STUCK")
			}
		}
		case 2:
		{
			engfunc(EngFunc_RemoveEntity, g_iCheckpoint[--g_iCheckpointsNum])
			if (g_iCheckpointsNum)
				set_finish_bodypart()
				
			g_iWasChanged = 1
			DisableHamForward(g_fwTouch)
		}
		case 3:
		{
			for (new i = 0; i < g_iCheckpointsNum; i++)
				engfunc(EngFunc_RemoveEntity, g_iCheckpoint[i])
				
			g_iCheckpointsNum = 0
			g_iWasChanged = 1
			DisableHamForward(g_fwTouch)
		}
		case 4:
		{
			if (!save_checkpoints())
			{
				client_print_color(id, print_team_red, "%s ^1%L", CHAT_PREFIX, LANG_PLAYER, "CP_SAVED")
				g_iWasChanged = 0
				
				if (g_iCheckpointsNum)
					EnableHamForward(g_fwTouch)
					
				arrayset(g_iPlrCompleted, -1, 33)
				g_iFinishedNum = 0
			}
		}
	}
	
	display_checkpoint_menu(id)
	return PLUGIN_CONTINUE
}

/*** Global events ***/

public fw_RoundStart()
{
	g_iRoundEnd = 0
	
	arrayset(g_iPlrCompleted, -1, 33)
	g_iFinishedNum = 0
}

public fw_RoundEnd()
{	
	g_iRoundEnd = 1
}

/*** Player events ***/

public client_putinserver(id)
{
	g_iPlrCompleted[id] = -1
}

public fw_PlayerSpawn(const iPlayer)
{
	remove_task(iPlayer + TASK_RETURN_PLAYER)
	if (get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_TELEPORT]) && g_iPlrCompleted[iPlayer] > -1)
	{
		if (return_player(iPlayer, g_iPlrCompleted[iPlayer]))
			set_task(0.5, "task_teleport_player", iPlayer + TASK_RETURN_PLAYER,
				.flags = "a", .repeat = RETURN_PLAYER_TRY_TIMES)
	}
}

public task_return_player(id)
{
	new iPlayer = id - TASK_RETURN_PLAYER
	
	if (g_iPlrCompleted[iPlayer] >= g_iCheckpointsNum)
		g_iPlrCompleted[iPlayer] = -1
		
	if (!return_player(iPlayer, g_iPlrCompleted[iPlayer]))
	{
		print_skip_ad(iPlayer)
		remove_task(id)
	}
}

public task_teleport_player(id)
{
	new iPlayer = id - TASK_RETURN_PLAYER
	
	if (g_iPlrCompleted[iPlayer] >= g_iCheckpointsNum || !return_player(iPlayer, g_iPlrCompleted[iPlayer]))
	{
		remove_task(id)
		return
	}
}

/*** Checkpoint's actions ***/

public fw_TouchCheckpoint(const iEnt, const iPlayer)
{		
	static i, iPos

	if (g_iRoundEnd || pev(iEnt, pev_impulse) != g_iCheckpointKey)
		return HAM_IGNORED

	#if defined DUELS_ENABLED		
	if (g_iDuelStart)
		return HAM_IGNORED
	#endif
	
	for (i = 0; i < g_iCheckpointsNum; i++)
	{
		if (g_iCheckpoint[i] == iEnt)
		{
			iPos = i
			break
		}
	}
		
	if (g_iPlrCompleted[iPlayer] >= iPos || !is_user_alive(iPlayer))
		return HAM_IGNORED
		
	new iSkipLimit = get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_SKIP_LIMIT])
	if (iSkipLimit && iPos - g_iPlrCompleted[iPlayer] > iSkipLimit)
	{
		if (!return_player(iPlayer, g_iPlrCompleted[iPlayer]))
			print_skip_ad(iPlayer)
		else if (!task_exists(iPlayer + TASK_RETURN_PLAYER))
			set_task(0.5, "task_return_player", iPlayer + TASK_RETURN_PLAYER,
				.flags = "a", .repeat = RETURN_PLAYER_TRY_TIMES)
	
		return HAM_IGNORED
	}
	
	client_cmd(iPlayer, "spk %s", SOUND_CHECKPOINT)
	
	new iReward
		
	set_dhudmessage(DHUD_POSITION)

	if (iPos == g_iCheckpointsNum - 1)
	{
		show_dhudmessage(iPlayer, "%L", LANG_PLAYER, "CP_FINISH", ++g_iFinishedNum)
		
		new szPlayerName[24]
		get_user_name(iPlayer, szPlayerName, 23)
		
		if (szPlayerName[22] != 0)
			szPlayerName[22] = szPlayerName[21] = szPlayerName[20] = '.'
		
		client_print_color(0, print_team_red, "%s ^1%L", CHAT_PREFIX, LANG_PLAYER, "FINISH_AD", szPlayerName, g_iFinishedNum)
				
		if (g_iFinishedNum > 3)
		{
			iReward = get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_REWARD])
			if (get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_KOEF]))
				iReward *= iPos + 1
		}
		else
			iReward = get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_FINISH_REWARD][g_iFinishedNum - 1])
	}
	else
	{
		show_dhudmessage(iPlayer, "%L", LANG_PLAYER, "CP_COMPLETE", iPos + 1)
		
		iReward = get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_REWARD])
		if (get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_KOEF]))
			iReward *= iPos + 1
	}
	
	if (iReward)
	{
		new iCurMoney = cs_get_user_money(iPlayer),
			iMaxMoney = get_pcvar_num(g_pCvars[CVAR_CHECKPOINT_MAXMONEY])	
		
		if (iCurMoney + iReward > iMaxMoney)
			iReward = iMaxMoney - iCurMoney
			
		cs_set_user_money(iPlayer, iCurMoney + iReward)
		client_print_color(iPlayer, print_team_red, "%s ^1%L", CHAT_PREFIX, LANG_PLAYER, "CP_REWARD", iReward)
	}
	
	g_iPlrCompleted[iPlayer] = iPos
	
	return HAM_IGNORED
}

public fw_ThinkCheckpoint(const iEnt)
{
	static iTopColor

	if (pev(iEnt, pev_impulse) != g_iCheckpointKey)
		return HAM_IGNORED

	iTopColor = pev(iEnt, pev_colormap)
	iTopColor = iTopColor == 255 ? 0 : iTopColor + 1
		
	set_pev(iEnt, pev_colormap, iTopColor)
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
		
	return HAM_IGNORED
}

/*** Other stuff ***/

return_player(const iPlayer, const iPos)
{
	new Float: fOrigin[3], Float: fAngles[3]
	
	if (iPos == -1)
	{
		new iSpawnEnts[32], iSpawnNum, iSpawn = -1
		
		while ((iSpawn = engfunc(EngFunc_FindEntityByString, iSpawn, "classname", "info_player_start")))
			iSpawnEnts[iSpawnNum++] = iSpawn

		pev(iSpawnEnts[random(iSpawnNum)], pev_origin, fOrigin)
	}
	else
	{
		pev(g_iCheckpoint[iPos], pev_origin, fOrigin)
		pev(g_iCheckpoint[iPos], pev_angles, fAngles)
	}
	
	if (check_stuck(fOrigin, iPlayer))
		return 1

	engfunc(EngFunc_SetOrigin, iPlayer, fOrigin)
	set_pev(iPlayer, pev_angles, fAngles)
	set_pev(iPlayer, pev_fixangle, 1)
	set_pev(iPlayer, pev_velocity, Float: {0.0, 0.0, 0.0})
	
	return 0
}

print_skip_ad(const iPlayer)
{
	new szPlayerName[18]
	get_user_name(iPlayer, szPlayerName, 17)
	
	if (szPlayerName[16] != 0)
		szPlayerName[16] = szPlayerName[15] = szPlayerName[14] = '.'
	
	client_print_color(0, print_team_red, "%s ^1%L", CHAT_PREFIX, LANG_PLAYER, "CP_RETURN", szPlayerName)
}

bool: check_stuck(const Float: fOrigin[3], const iPlayer)
{
	static tr
	engfunc(EngFunc_TraceHull, fOrigin, fOrigin, 0, HULL_HUMAN, iPlayer, tr)
		
	if (!get_tr2(tr, TR_StartSolid) || !get_tr2(tr, TR_AllSolid))
		return false
	return true
}

/*** Duel forwards ***/

#if defined DUELS_ENABLED
public dr_duel_start(iPlayerCT, iPlayerTE)
{
	g_iDuelStart = 1
	remove_task(iPlayerCT + TASK_RETURN_PLAYER)
	remove_task(iPlayerTE + TASK_RETURN_PLAYER)
}
public dr_duel_finish() g_iDuelStart = 0
public dr_duel_canceled() g_iDuelStart = 0
#endif