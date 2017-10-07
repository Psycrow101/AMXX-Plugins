/*
https://next21.ru/2012/11/%D0%BF%D0%BB%D0%B0%D0%B3%D0%B8%D0%BD-%D0%B4%D0%BE%D0%BC%D0%B8%D0%BD%D0%B8%D1%80%D0%BE%D0%B2%D0%B0%D0%BD%D0%B8%D0%B5/
*/

#include <amxmodx>
#include <WPMGPrintChatColor>

#define PLUGIN "Dominations"
#define VERSION "0.6"
#define AUTHOR "Psycrow"

#define SOUND_DOMINATION	"next21_dominations/tf_domination.wav"
#define SOUND_REVENGE 		"next21_dominations/tf_revenge.wav"
#define SOUND_FREEZE_CAM 	"next21_dominations/freeze_cam.wav"

#define TASK_ID			1021

#define is_entity_player(%1)	(1<=%1&&%1<=g_iMaxplayers)

new
g_iFrags[33][33],
g_iMaxplayers,
DM_FRAGS, DM_SOUNDS, DM_TOTAL

public plugin_natives()
	register_native("ka_set_flag_dmn", "_n21_set_flag_dmn", 0) // 1 - id

public plugin_precache()
{		
	precache_sound(SOUND_DOMINATION)
	precache_sound(SOUND_REVENGE)
	precache_sound(SOUND_FREEZE_CAM)
}
	
public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("DeathMsg", "DeathMsg", "a")
	register_logevent("fw_RoundStart", 2, "1=Round_Start")
	
	register_cvar("cv_dominations_frags","3")
	register_cvar("cv_dominations_sounds","1")
	register_cvar("cv_dominations_total","1")
		
	g_iMaxplayers = get_maxplayers()
}

public client_putinserver(id)
{	
	for (new i = 1; i <= g_iMaxplayers; i++)
		g_iFrags[id][i] = 0
}

public client_disconnect(id)
{
	new szNames[33][24], iNum
	for (new i = 1; i <= g_iMaxplayers; i++)
		if (g_iFrags[i][id] >= DM_FRAGS) 
			get_user_name(i, szNames[iNum++], 23)
	
	if (iNum)
	{
		new szVictimName[24]
		get_user_name(id, szVictimName, 23)
		
		if (iNum == 1)
			PrintChatColor(0, PRINT_COLOR_RED, "!g[%s] !tИгрок !g%s !tпокидает сервер, не отомстив своему палачу !g%s", PLUGIN, szVictimName, szNames[0])
		else
		{
			new szMessage[256], iLen
			PrintChatColor(0, PRINT_COLOR_RED, "!g[%s] !tИгрок !g%s !tпокидает сервер, не отомстив своим палачам:", PLUGIN, szVictimName)
			for (new i = 0; i < iNum; i++)
			{
				iLen += format(szMessage, 255, "%s%s", szNames[i], i < (iNum - 1) ? ", " : "")
				if (iLen > 93)
				{
					add(szMessage, 255, "...")
					break
				}
			}
			PrintChatColor(0, PRINT_COLOR_RED, "%s", szMessage)
		}
	}
}

public fw_RoundStart()
{
	DM_FRAGS = get_cvar_num("cv_dominations_frags")
	DM_SOUNDS = get_cvar_num("cv_dominations_sounds")
	DM_TOTAL = get_cvar_num("cv_dominations_total")
}

public DeathMsg()
{
	set_flags(read_data(1), read_data(2))
}
	
public fw_MapChange()
{	
	new iMax, iNum, szName[24]
	for(new i = 1, j; i <= g_iMaxplayers; i++)
	{
		iNum = 0
		for(j = 1; j <= g_iMaxplayers; j++)
			if(g_iFrags[i][j] >= DM_FRAGS)
				iNum++
			
		if (iNum > iMax)
		{
			iMax = iNum
			get_user_name(i, szName, 23)
		}
	}
	
	if(iMax > 2)
		PrintChatColor(0, PRINT_COLOR_RED, "!g[%s] !tИгрок !g%s !tсохранил !g%d !tдоминирований", PLUGIN, szName, iMax)
}

set_flags(iAttacker, iVictim)
{
	if (!is_entity_player(iAttacker))
		return
	
	if (cs_get_user_team(iAttacker) == cs_get_user_team(iVictim))
		return
		
	g_iFrags[iAttacker][iVictim]++
	new szNameV[24], szNameA[24]
	get_user_name(iVictim, szNameV, 23) 
	get_user_name(iAttacker, szNameA, 23)
	
	if (strlen(szNameV) > 12)
	{
		formatex(szNameV, 11, "%s", szNameV)
		add(szNameV, 13, "..")
	}
	
	if (strlen(szNameA) > 12)
	{
		formatex(szNameA, 11, "%s", szNameA)
		add(szNameA, 13, "..")
	}
		
	if (g_iFrags[iAttacker][iVictim] == DM_FRAGS)
	{
		PrintChatColor(0, PRINT_COLOR_RED, "!g[%s] !tИгрок !g%s !tтеперь доминирует над игроком !g%s", PLUGIN, szNameA, szNameV)
		if(DM_SOUNDS)
			emit_sound(iAttacker, CHAN_AUTO, SOUND_DOMINATION, 1.0, 1.0, 0, 100)
			
		if(DM_TOTAL)	
		{
			remove_task(TASK_ID)
			set_task(get_timeleft() + 0.0, "fw_MapChange", TASK_ID)
		}
	}
	else if (g_iFrags[iAttacker][iVictim] > DM_FRAGS)
	{
		PrintChatColor(iAttacker, PRINT_COLOR_RED, "!g[%s] !tВы снова убили свою жертву !g%s", PLUGIN, szNameV)
		PrintChatColor(iVictim, PRINT_COLOR_RED, "!g[%s] !tВас снова убил ваш палач !g%s", PLUGIN, szNameA)
		if(DM_SOUNDS)
			client_cmd(iVictim, "spk %s", SOUND_FREEZE_CAM)
	}
	else if(g_iFrags[iVictim][iAttacker] >= DM_FRAGS)
	{
		PrintChatColor(0, PRINT_COLOR_RED, "!g[%s] !tИгрок !g%s !tотомстил своему обидчику !g%s", PLUGIN, szNameA, szNameV)
		if (DM_SOUNDS)
			emit_sound(iAttacker, CHAN_AUTO, SOUND_REVENGE, 1.0, 1.0, 0, 100)
	}
	
	g_iFrags[iVictim][iAttacker]++
}

public _n21_set_flag_dmn(plugin, num_params)
{
	set_flags(get_param(1), get_param(2))
}
