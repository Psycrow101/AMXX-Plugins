/*
https://next21.ru/2015/01/simple-adverts/
*/

#include <amxmodx>
#include <amxmisc>
#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
	#define client_disconnected client_disconnect
#endif
#include <fakemeta>


enum _:CvarList
{
	CVAR_PRINTMODE,
	CVAR_PREFIX[32],
	CVAR_PERIOD,
	CVAR_ORDER,
	CVAR_EFFECT,
	CVAR_FXTIME,
	CVAR_HOLDTIME,
	CVAR_FADETIME,
	CVAR_FADEOUTTIME,
	CVAR_CHANNEL,
	CVAR_ALIVE,
	CVAR_TEAM,
	CVAR_COLOR,
	CVAR_RED,
	CVAR_GREEN,
	CVAR_BLUE,
	CVAR_POS_X,
	CVAR_POS_Y,
	CVAR_CONSOLE
}

new
Array: g_apMessages,
g_pCvars[CvarList],
g_iMaxPlayers, g_iArraySize, g_iConneted[32], g_msgSayText

public plugin_init()
{
	register_plugin("Simple HUD Adverts", "1.01", "Oli Desu")
	
	register_srvcmd("n21_ads_reset", "plugin_cfg", .info = "Reset adverts settings")
	
	register_cvar("n21_ads_printmode", "0")
	register_cvar("n21_ads_prefix", "!g[Adverts]!y ")
	register_cvar("n21_ads_period", "60.0")
	register_cvar("n21_ads_order", "1")
	register_cvar("n21_ads_effect", "1")
	register_cvar("n21_ads_fxtime", "1.0")
	register_cvar("n21_ads_holdtime", "10.0")
	register_cvar("n21_ads_fadetime", "0.1")
	register_cvar("n21_ads_fadeouttime", "0.2")
	register_cvar("n21_ads_channel", "-1")
	register_cvar("n21_ads_alive", "0")
	register_cvar("n21_ads_team", "0")
	register_cvar("n21_ads_color", "0")
	register_cvar("n21_ads_red", "255")
	register_cvar("n21_ads_green", "255")
	register_cvar("n21_ads_blue", "255")
	register_cvar("n21_ads_pos_x", "-1.0")
	register_cvar("n21_ads_pos_y", "0.25")
	register_cvar("n21_ads_console", "0")
	
	g_apMessages = ArrayCreate(128)
	g_iMaxPlayers = get_maxplayers()
	g_msgSayText = get_user_msgid("SayText")
}

public plugin_cfg()
{
	new szCfgDir[64], szFile[128]
	get_configsdir(szCfgDir, 63)
	add(szCfgDir, 63, "/next21_ads")
	
	if (!dir_exists(szCfgDir))
		if (mkdir(szCfgDir))
			set_fail_state("Enable to create adverts directory")
		
	new pFile, szHostname[64], szIP[32], szLine[128], szMapname[32]
	get_user_ip(0, szIP, 31)
	get_cvar_string("hostname", szHostname, 63)
	get_mapname(szMapname, 31)
	formatex(szFile, 127, "%s/ads.ini", szCfgDir)
	
	if ((pFile = fopen(szFile, "rt")))
	{
		while (!feof(pFile))
		{
			fgets(pFile, szLine, 127)
			if (szLine[0] && szLine[0] != ';')
			{
				replace_all(szLine, 127, "%ip%", szIP)
				replace_all(szLine, 127, "%hostname%", szHostname)
				replace_all(szLine, 127, "%mapname%", szMapname)
				replace_all(szLine, 127, "%new%", "^n")
				ArrayPushArray(g_apMessages, szLine)
			}
		}
		fclose(pFile)
	}
	else
		write_file(szFile, ";Adverts", -1)
		
	
	formatex(szFile, 127, "%s/%s-ads.ini", szCfgDir, szMapname)
	if ((pFile = fopen(szFile, "rt")))
	{
		while (!feof(pFile))
		{
			fgets(pFile, szLine, 127)
			if(szLine[0] && szLine[0] != ';')
			{
				replace_all(szLine, 127, "%ip%", szIP)
				replace_all(szLine, 127, "%hostname%", szHostname)
				replace_all(szLine, 127, "%mapname%", szMapname)
				replace_all(szLine, 127, "%new%", "^n")
				ArrayPushArray(g_apMessages, szLine)
			}
		}
		fclose(pFile)
	}
	
	g_iArraySize = ArraySize(g_apMessages)
		
	if (g_iArraySize)
	{
		g_pCvars[CVAR_PRINTMODE] = get_cvar_num("n21_ads_printmode")
		g_pCvars[CVAR_PERIOD] = _:get_cvar_float("n21_ads_period")
		g_pCvars[CVAR_ORDER] = get_cvar_num("n21_ads_order")
		g_pCvars[CVAR_EFFECT] = get_cvar_num("n21_ads_effect")
		g_pCvars[CVAR_FXTIME] = _:get_cvar_float("n21_ads_fxtime")
		g_pCvars[CVAR_HOLDTIME] = _:get_cvar_float("n21_ads_holdtime")
		g_pCvars[CVAR_FADETIME] = _:get_cvar_float("n21_ads_fadetime")
		g_pCvars[CVAR_FADEOUTTIME] = _:get_cvar_float("n21_ads_fadeouttime")
		g_pCvars[CVAR_CHANNEL] = get_cvar_num("n21_ads_channel")
		g_pCvars[CVAR_ALIVE] = get_cvar_num("n21_ads_alive")
		g_pCvars[CVAR_TEAM] = get_cvar_num("n21_ads_team")
		g_pCvars[CVAR_COLOR] = get_cvar_num("n21_ads_color")
		g_pCvars[CVAR_RED] = get_cvar_num("n21_ads_red")
		g_pCvars[CVAR_GREEN] = get_cvar_num("n21_ads_green")
		g_pCvars[CVAR_BLUE] = get_cvar_num("n21_ads_blue")
		g_pCvars[CVAR_POS_X] = _:get_cvar_float("n21_ads_pos_x")
		g_pCvars[CVAR_POS_Y] = _:get_cvar_float("n21_ads_pos_y")
		g_pCvars[CVAR_CONSOLE] = get_cvar_num("n21_ads_console")
		get_cvar_string("n21_ads_prefix", g_pCvars[CVAR_PREFIX], 31)
				
		remove_task(999)
		set_task(Float: g_pCvars[CVAR_PERIOD], "show_advert", .id = 999, .flags = "b")
	}
}

public client_putinserver(id)
	g_iConneted[id - 1] = 1
	
public client_disconnected(id)
	g_iConneted[id - 1] = 0

public show_advert()
{	
	new szMessage[128], szName[32]
	
	static iCounter = -1
	
	if (g_pCvars[CVAR_ORDER])
	{
		if(++iCounter >= g_iArraySize)
			iCounter = 0
	}
	else
	{
		new iRandomNum = random(g_iArraySize)
		if (g_iArraySize > 1)
			while (iCounter == iRandomNum)
				iRandomNum = random(g_iArraySize)
		iCounter = iRandomNum
		server_print("%d", iRandomNum)
	}
	
	ArrayGetString(g_apMessages, iCounter, szMessage, 127)
	format(szMessage, 127, "%s%s", g_pCvars[CVAR_PREFIX], szMessage) 
	
	switch (g_pCvars[CVAR_PRINTMODE])
	{
		case 1: set_hudmessage(
			g_pCvars[CVAR_COLOR] ? random(256) : g_pCvars[CVAR_RED],
			g_pCvars[CVAR_COLOR] ? random(256) : g_pCvars[CVAR_GREEN],
			g_pCvars[CVAR_COLOR] ? random(256) : g_pCvars[CVAR_BLUE],
			Float: g_pCvars[CVAR_POS_X],
			Float: g_pCvars[CVAR_POS_Y],
			g_pCvars[CVAR_EFFECT],
			Float: g_pCvars[CVAR_FXTIME],
			Float: g_pCvars[CVAR_HOLDTIME],
			Float: g_pCvars[CVAR_FADETIME],
			Float: g_pCvars[CVAR_FADEOUTTIME],
			g_pCvars[CVAR_CHANNEL])
		case 2: set_dhudmessage(
			g_pCvars[CVAR_COLOR] ? random(256) : g_pCvars[CVAR_RED],
			g_pCvars[CVAR_COLOR] ? random(256) : g_pCvars[CVAR_GREEN],
			g_pCvars[CVAR_COLOR] ? random(256) : g_pCvars[CVAR_BLUE],
			Float: g_pCvars[CVAR_POS_X],
			Float: g_pCvars[CVAR_POS_Y],
			g_pCvars[CVAR_EFFECT],
			Float: g_pCvars[CVAR_FXTIME],
			Float: g_pCvars[CVAR_HOLDTIME],
			Float: g_pCvars[CVAR_FADETIME],
			Float: g_pCvars[CVAR_FADEOUTTIME])		
	}
	
	new iAliveState = g_pCvars[CVAR_ALIVE],
		iTeamState = g_pCvars[CVAR_TEAM],
		iPrintState = g_pCvars[CVAR_PRINTMODE],
		iConsoleState = g_pCvars[CVAR_CONSOLE],
		iUserAlive
	
		
	for (new i = 1; i <= g_iMaxPlayers; i++)
	{
		if (!g_iConneted[i - 1])
			continue
		
		iUserAlive = is_user_alive(i)
		
		if (iAliveState == 1 && !iUserAlive)
			continue
		
		if (iAliveState == 2 && iUserAlive)
			continue
				
		if (iTeamState && iTeamState != get_pdata_int(i, 114))
			continue
		
		get_user_name(i, szName, 127)
		replace_all(szMessage, 127, "%name%", szName)
		
		switch (iPrintState)
		{
			case 1:
			{
				if (iConsoleState)
					client_print(i, print_console, "%s", szMessage)	
				show_hudmessage(i, szMessage)
			}
			case 2:
			{
				if (iConsoleState)
					client_print(i, print_console, "%s", szMessage)	
				show_dhudmessage(i, szMessage)
			}
			default:
			{
				replace_all(szMessage, 127, "!g", "^4")
				replace_all(szMessage, 127, "!y", "^1")
				replace_all(szMessage, 127, "!t", "^3")
	
				message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, _, i)
				write_byte(i)
				write_string(szMessage)
				message_end()
			}
		}
	}
}