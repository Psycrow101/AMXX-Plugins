/*
https://next21.ru/2013/05/faling-damage/
*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN "Falling Damage"
#define VERSION "1.2"
#define AUTHOR "Psycrow"

new g_iMaxPlayers, g_cpKoef[2]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
		
	g_cpKoef[0] = register_cvar("cv_falldamage_koef_fst", "0.4") // Damage from falling (damage taken * value)
	g_cpKoef[1] = register_cvar("cv_falldamage_koef_snd", "0.9") // Damage to the victim (damage taken * value)
	
	RegisterHam(Ham_TakeDamage, "player", "fw_Ham_TakeDamage")
	
	g_iMaxPlayers = get_maxplayers()
}

public fw_Ham_TakeDamage(victim, inflictor, attacker, Float:damage, bits)
{		
	if (bits & DMG_FALL)
	{
		new Float: dmg_fst = get_pcvar_float(g_cpKoef[0]),
			Float: dmg_snd = get_pcvar_float(g_cpKoef[1])
		
		new iGroundEnt = pev(victim, pev_groundentity)

		if (iGroundEnt && iGroundEnt <= g_iMaxPlayers)
		{
			ExecuteHamB(Ham_TakeDamage, iGroundEnt, victim, victim, damage * dmg_snd, DMG_FALL)
			SetHamParamFloat(4, damage * dmg_fst)
			return HAM_OVERRIDE
		}	
	}
	
	return HAM_IGNORED
}
