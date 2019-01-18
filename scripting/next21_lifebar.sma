#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#if AMXX_VERSION_NUM < 183
	#define client_disconnected client_disconnect
#endif

#define PLUGIN "Lifebar"
#define VERSION "1.1"
#define AUTHOR "Psycrow"

#define COLORED_LIFEBAR

#if defined COLORED_LIFEBAR
	#define COLOR_RED Float: { 255.0, 0.0, 0.0 }
	#define COLOR_BLUE Float: { 0.0, 0.0, 255.0 }
	#define LIFEBAR_RENDERMODE kRenderTransTexture
	#define LIFEBAR_RENDERAMT 255.0
#endif

#define LIFEBAR_SCALE 0.2

new const MODELS_LIFEBAR[2][] = {
	"sprites/next21_efk/lifebar_numeric.spr",
	"sprites/next21_efk/lifebar_numeric.spr"
}

enum
{
    CVAR_TEAM,				// 0 - for all, 1 - only teammates, 2 - only enemies
    CVAR_ALIVE,				// 0 - for all, 1 - only alive, 2 - only dead
    CVAR_MAX_HEALTH,

    CVAR_END
}


new g_iLifebar[33], g_isAlive[33], g_iTeam[33]
new g_ptLifeBarKey, g_ptEnvSprite
new g_pCvars[CVAR_END], g_iCvars[CVAR_END]

public plugin_precache()
{
	precache_model(MODELS_LIFEBAR[0])
	if (!equali(MODELS_LIFEBAR[1], MODELS_LIFEBAR[0]))
		precache_model(MODELS_LIFEBAR[1])
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	RegisterHam(Ham_Spawn, "player", "FM_HamPlayerSpawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "FM_PlayerKilled_Post", 1)
	
	register_event("Health", "Event_ChangeHealth", "be")
	register_message(get_user_msgid("TeamInfo"), "Event_TeamInfo")
	
	g_ptEnvSprite = engfunc(EngFunc_AllocString, "env_sprite")
	g_ptLifeBarKey = engfunc(EngFunc_AllocString, "next21_lifebar")

	g_pCvars[CVAR_TEAM] = register_cvar("lifebar_team", "0")
	g_pCvars[CVAR_ALIVE] = register_cvar("lifebar_alive", "0")
	g_pCvars[CVAR_MAX_HEALTH] = register_cvar("lifebar_max_health", "100")

	#if AMXX_VERSION_NUM > 183
		for (new i; i < CVAR_END; i++)
			bind_pcvar_num(g_pCvars[i], g_iCvars[i])
		hook_cvar_change(g_pCvars[CVAR_TEAM], "cvar_team_changed")
		hook_cvar_change(g_pCvars[CVAR_ALIVE], "cvar_alive_changed")
	#else
		register_event("HLTV", "update_cvars", "a", "1=0", "2=0")
		update_cvars()
	#endif
}

public client_putinserver(iPlayer)
{
	g_isAlive[iPlayer] = g_iTeam[iPlayer] = 0
	g_iLifebar[iPlayer] = 0

	new iLifeBar = engfunc(EngFunc_CreateNamedEntity, g_ptEnvSprite)

	if (pev_valid(iLifeBar))
	{
		set_pev(iLifeBar, pev_movetype, MOVETYPE_FOLLOW)
		set_pev(iLifeBar, pev_aiment, iPlayer)
		set_pev(iLifeBar, pev_scale, LIFEBAR_SCALE)
		set_pev(iLifeBar, pev_effects, EF_NODRAW)
		set_pev(iLifeBar, pev_impulse, g_ptLifeBarKey)

		#if defined COLORED_LIFEBAR
			set_pev(iLifeBar, pev_rendermode, LIFEBAR_RENDERMODE)
			set_pev(iLifeBar, pev_renderamt, LIFEBAR_RENDERAMT)
		#else
			set_pev(iLifeBar, pev_rendermode, kRenderNormal)
		#endif

		g_iLifebar[iPlayer] = iLifeBar
	}
}

public client_disconnected(iPlayer)
{	
	g_isAlive[iPlayer] = g_iTeam[iPlayer] = 0
	
	if (g_iLifebar[iPlayer])
	{
		engfunc(EngFunc_RemoveEntity, g_iLifebar[iPlayer])
		g_iLifebar[iPlayer] = 0
	}
}

public FM_HamPlayerSpawn_Post(iPlayer)
{
	if (is_user_alive(iPlayer))
	{	
		g_isAlive[iPlayer] = 1
		g_iTeam[iPlayer] = get_pdata_int(iPlayer, 114)
		
		new iLifeBar = g_iLifebar[iPlayer]
		if (iLifeBar)
		{
			new iTeam = g_iTeam[iPlayer]
			if (0 < iTeam < 3)
				engfunc(EngFunc_SetModel, iLifeBar, MODELS_LIFEBAR[iTeam - 1])
			set_pev(iLifeBar, pev_effects, 0)
		}

		Event_ChangeHealth(iPlayer)
	}
}

public FM_PlayerKilled_Post(iPlayer)
{
	g_isAlive[iPlayer] = 0
	
	if (g_iLifebar[iPlayer])
		set_pev(g_iLifebar[iPlayer], pev_effects, EF_NODRAW)
}

public FM_AddToFullPack_Post(eState, e, iEnt, iHost)
{	
	if (!pev_valid(iEnt) || pev(iEnt, pev_impulse) != g_ptLifeBarKey)
		return

	static iTarget, bool: isTeamHide, bool: isAliveHide
	iTarget = pev(iEnt, pev_aiment)
	isTeamHide = g_iCvars[CVAR_TEAM] - _:(g_iTeam[iTarget] == g_iTeam[iHost]) == 1
	isAliveHide = g_iCvars[CVAR_ALIVE] - g_isAlive[iHost] == 1

	if (iHost == iTarget || isTeamHide || isAliveHide)
		set_es(eState, ES_Effects, EF_NODRAW)
}

public Event_ChangeHealth(iPlayer)
{
	static iHealth, iMaxHealth
	
	if (g_iLifebar[iPlayer])
	{
		iMaxHealth = g_iCvars[CVAR_MAX_HEALTH]
		iHealth = get_user_health(iPlayer)
		
		if (iHealth > iMaxHealth)
			iHealth = iMaxHealth

		set_pev(g_iLifebar[iPlayer], pev_frame, iHealth * 100 / iMaxHealth - 1.0)
	}	
}

public Event_TeamInfo()
{
	new iPlayer = get_msg_arg_int(1)
	
	new szTeamName[2], iTeam
	get_msg_arg_string(2, szTeamName, 1)
			
	switch (szTeamName[0])
	{
		case 'T': iTeam = 1
		case 'C': iTeam = 2
		default: iTeam = 0
	}

	g_iTeam[iPlayer] = iTeam

	new iLifeBar = g_iLifebar[iPlayer]
	if (iLifeBar)
	{
		if (iTeam)
			engfunc(EngFunc_SetModel, iLifeBar, MODELS_LIFEBAR[iTeam - 1])

		#if defined COLORED_LIFEBAR
			switch (iTeam)
			{
				case 1: set_pev(iLifeBar, pev_rendercolor, COLOR_RED)
				case 2: set_pev(iLifeBar, pev_rendercolor, COLOR_BLUE)
			}
		#endif
	}
}

#if AMXX_VERSION_NUM > 183
	public cvar_team_changed(pCvar, const szOldValue[], const szNewValue[])
		switch_ATFP(str_to_num(szNewValue) || g_iCvars[CVAR_ALIVE])
	
	public cvar_alive_changed(pCvar, const szOldValue[], const szNewValue[])
		switch_ATFP(g_iCvars[CVAR_TEAM] || str_to_num(szNewValue))
#else
	public update_cvars()
	{
		for (new i; i < CVAR_END; i++)
			g_iCvars[i] = get_pcvar_num(g_pCvars[i])

		switch_ATFP(g_iCvars[CVAR_TEAM] || g_iCvars[CVAR_ALIVE])
	}
#endif

switch_ATFP(iMode)
{
	static fwdAddToFullPack = 0

	if (fwdAddToFullPack && !iMode)
	{
		unregister_forward(FM_AddToFullPack, fwdAddToFullPack, 1)
		fwdAddToFullPack = 0
	}
	else if (!fwdAddToFullPack && iMode)
		fwdAddToFullPack = register_forward(FM_AddToFullPack, "FM_AddToFullPack_Post", 1)
}
