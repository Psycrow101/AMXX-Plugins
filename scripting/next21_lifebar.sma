/*
https://next21.ru/2014/01/lifebar/
*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>

#define PLUGIN "Lifebar"
#define VERSION "1.0"
#define AUTHOR "Psycrow"

#define TEAM_MODE 		0 // 0 - Отображается на всех игроках, 1 - только на союзниках, 2 - только на противниках
#define ALIVE_MODE 		0 // 0 - Отображается в любом состоянии игрока, 1 - только в живом, 2 - только в мертвом
#define MAX_HEALTH 		100 // Максимальное здоровье игрока
#define MODEL_LIFEBAR 		"sprites/next21_knife_v2/lifebar.spr"

new g_maxPlayers, g_lifebar[33], g_isAlive[33], CsTeams: g_playerTeam[33], g_env_sprite

public plugin_precache()
	precache_model(MODEL_LIFEBAR)

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
			
	register_forward(FM_AddToFullPack, "fw_AddToFullPack", 1)
	
	RegisterHam(Ham_Spawn, "player", "fw_HamSpawn", 1)	
	RegisterHam(Ham_Killed, "player", "fw_Ham_Killed_Post", 1)	
	
	register_event("Health", "fw_ChangeHealth", "be")
	
	g_env_sprite = engfunc(EngFunc_AllocString, "env_sprite")
	g_maxPlayers = get_maxplayers()
}

public client_putinserver(id)
{
	g_isAlive[id] = 0
	g_playerTeam[id] = CS_TEAM_SPECTATOR	
	
	g_lifebar[id] = engfunc(EngFunc_CreateNamedEntity, g_env_sprite)
	if(!pev_valid(g_lifebar[id]))
	{
		engfunc(EngFunc_SetModel, g_lifebar[id], MODEL_LIFEBAR)
		set_pev(g_lifebar[id], pev_movetype, MOVETYPE_FOLLOW)
		set_pev(g_lifebar[id], pev_aiment, id)
		set_pev(g_lifebar[id], pev_scale, 0.15)
		set_pev(g_lifebar[id], pev_effects, EF_NODRAW)
	}
	else g_lifebar[id] = 0
}

public client_disconnect(id)
{	
	g_isAlive[id] = 0
	g_playerTeam[id] = CS_TEAM_UNASSIGNED
	
	if (g_lifebar[id])
	{
		engfunc(EngFunc_RemoveEntity, g_lifebar[id])
		g_lifebar[id] = 0
	}
}

public fw_HamSpawn(id)
{
	if(is_user_alive(id))
	{	
		g_isAlive[id] = 1
		g_playerTeam[id] = cs_get_user_team(id)
		
		if (g_lifebar[id])
		{
			set_pev(g_lifebar[id], pev_effects, 0)
			set_pev(g_lifebar[id], pev_frame, 99.0)
		}
	}
}

public fw_Ham_Killed_Post(id)
{
	g_isAlive[id] = 0
	g_playerTeam[id] = cs_get_user_team(id)
	
	if (g_lifebar[id])
		set_pev(g_lifebar[id], pev_effects, EF_NODRAW)
}

public fw_AddToFullPack(es, e, ent, host)
{
	static i, Float: fOrigin[3]
	
	if (!ent)
		return
	
	for(i = 1; i <= g_maxPlayers; i++)
	{
		if(g_lifebar[i] == ent)
		{				
			if(i == host
			|| (TEAM_MODE == 1 && g_playerTeam[i] != g_playerTeam[host])
			|| (TEAM_MODE == 2 && g_playerTeam[i] == g_playerTeam[host])
			|| (ALIVE_MODE == 1 && !g_isAlive[host])
			|| (ALIVE_MODE == 2 && g_isAlive[host]))
			{
				set_es(es, ES_Effects, EF_NODRAW)
			}
			else
			{
				pev(i, pev_origin, fOrigin)						
				fOrigin[2] += 30.0
				set_es(es, ES_AimEnt, 0)
				set_es(es, ES_Origin, fOrigin)
			}
		}
	}
}

public fw_ChangeHealth(id)
{
	static hp
	
	if (g_lifebar[id])
	{
		hp = get_user_health(id)
		if(hp > MAX_HEALTH) hp = MAX_HEALTH
		set_pev(g_lifebar[id], pev_frame, hp * 100 / MAX_HEALTH - 1.0)
	}	
}
