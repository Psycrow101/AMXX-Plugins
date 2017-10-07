/*
https://next21.ru/2013/05/faling-damage/
*/

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN "Falling Damage"
#define VERSION "1.0"
#define AUTHOR "Psycrow"

new g_MaxPlayers, cv_koef[2]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
		
	cv_koef[0] = register_cvar("cv_falldamage_koef_fst","0.4") // Урон от падени¤ (полученный урон * значение)
	cv_koef[1] = register_cvar("cv_falldamage_koef_snd","0.9") // Урон жертве, на которую упали (полученный урон * значение)
	
	RegisterHam(Ham_TakeDamage, "player", "Ham_TakeDamage_Post")
	
	g_MaxPlayers = get_maxplayers()
}

public Ham_TakeDamage_Post(victim, inflictor, attacker, Float:damage, bits)
{	
	if(attacker) return HAM_IGNORED
						
	if(bits & DMG_FALL)
	{
		new bool: was_damaged = false, 
		Float: dmg_fst = get_pcvar_float(cv_koef[0]),
		Float: dmg_snd = get_pcvar_float(cv_koef[1])
		
		for(new i=1; i<=g_MaxPlayers; i++)
			if(is_user_alive(i) && i != victim && is_plr_on_plr(victim, i))
			{
				was_damaged = true
				ExecuteHamB(Ham_TakeDamage, i, victim, victim, damage*dmg_snd, DMG_FALL)
			}
			
		if(was_damaged)
		{
			SetHamParamFloat(4, damage*dmg_fst)
			return HAM_OVERRIDE
		}	
	}
	
	return HAM_IGNORED
}

bool: is_plr_on_plr(plr1, plr2)
{
	new Float: origins[2][3], Float: mins[2][3], Float: maxs[2][3]
	
	pev(plr1, pev_origin, origins[0])
	pev(plr2, pev_origin, origins[1])
	pev(plr1, pev_mins, mins[0])
	pev(plr2, pev_maxs, maxs[1])
	
	if(origins[1][2] + maxs[1][2] - origins[0][2] + mins[0][2] > 3.0)
		return false
				
	pev(plr1, pev_maxs, maxs[0])
	pev(plr2, pev_mins, mins[1])
	
	new Float: a[2][2], Float: b[2][2]
	
	a[0][0] = origins[0][0] + mins[0][0]
	a[0][1] = origins[0][0] + maxs[0][0]
	a[1][0] = origins[0][1] + mins[0][1]
	a[1][1] = origins[0][1] + maxs[0][1]
	
	b[0][0] = origins[1][0] + mins[1][0]
	b[0][1] = origins[1][0] + maxs[1][0]
	b[1][0] = origins[1][1] + mins[1][1]
	b[1][1] = origins[1][1] + maxs[1][1]
	
	if((a[0][0] > b[0][0] && a[0][0] < b[0][1]) || (a[0][1] > b[0][0] && a[0][1] < b[0][1]))
		if((a[1][0] > b[1][0] && a[1][0] < b[1][1]) || (a[1][1] > b[1][0] && a[1][1] < b[1][1]))
			return true
			
	return false
}
