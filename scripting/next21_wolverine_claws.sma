/*
https://next21.ru/2013/02/%D0%BF%D0%BB%D0%B0%D0%B3%D0%B8%D0%BD-%D0%BA%D0%BE%D0%B3%D1%82%D0%B8-%D1%80%D0%BE%D1%81%D0%BE%D0%BC%D0%B0%D1%85%D0%B8/
*/

#include <amxmodx>
#include <fakemeta_util>
#include <hamsandwich>

#define PLUGIN "Wolverine_Claws"
#define VERSION "1.1"
#define AUTHOR "Psycrow"

#define is_entity_player(%1) (1<=%1&&%1<=g_maxPlayers)

#define MODEL_V_CLAWS "models/n21_admin_wolverine/v_claws.mdl"
#define MODEL_P_CLAWS "models/n21_admin_wolverine/p_claws.mdl"
#define MODEL_V_HANDS "models/n21_admin_wolverine/v_hands.mdl"
#define MODEL_P_HANDS "models/n21_admin_wolverine/p_hands.mdl"

#define TASK_REGEN	1234
#define MAX_HEALTH	100
#define ADMIN_FLAG ADMIN_KICK

new g_maxPlayers, msgIndexWeaponList, regen_type, logan_claws[33],
P_ADMIN, P_DAMAGE, P_REGEN

public plugin_precache()
{
	precache_model(MODEL_V_CLAWS)
	precache_model(MODEL_P_CLAWS)
	precache_model(MODEL_V_HANDS)
	precache_model(MODEL_P_HANDS)
		
	precache_sound("n21_admin_wolverine/idle.wav")
	precache_sound("n21_admin_wolverine/draw.wav")
	precache_sound("n21_admin_wolverine/slash1.wav")
	precache_sound("n21_admin_wolverine/slash2.wav")
	precache_sound("n21_admin_wolverine/slash3.wav")
	precache_sound("n21_admin_wolverine/slash4.wav")
	precache_sound("n21_admin_wolverine/hit1.wav")
	precache_sound("n21_admin_wolverine/hit2.wav")
	precache_sound("n21_admin_wolverine/hit3.wav")
	precache_sound("n21_admin_wolverine/hit4.wav")
	precache_sound("n21_admin_wolverine/wall1.wav")
	precache_sound("n21_admin_wolverine/wall2.wav")
	
	precache_sound("n21_admin_wolverine/claws_off.wav")
	precache_sound("n21_admin_wolverine/draw_B.wav")
	precache_sound("n21_admin_wolverine/slash1_B.wav")
	precache_sound("n21_admin_wolverine/slash2_B.wav")
	precache_sound("n21_admin_wolverine/slash3_B.wav")
	precache_sound("n21_admin_wolverine/hit1_B.wav")
	precache_sound("n21_admin_wolverine/hit2_B.wav")
	precache_sound("n21_admin_wolverine/hit3_B.wav")
	precache_sound("n21_admin_wolverine/hit4_B.wav")
	
	precache_generic("sprites/weapon_n21_claws.txt")
	precache_generic("sprites/n21_admin_wolverine/640hud21.spr")
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("HLTV", "fw_RoundStart", "a", "1=0", "2=0")
	
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Item_AddToPlayer, "weapon_knife", "fw_AddToPlayerKnife", 1)
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_KnifeDeploy", 1)
	
	register_forward(FM_EmitSound, "fw_EmitSound")
	
	register_clcmd("drop", "change_to_claws")
	register_clcmd("weapon_n21_claws", "ClientCommand_SelectClaws")
	
	P_ADMIN = register_cvar("n21wc_admin", "1")
	P_DAMAGE = register_cvar("n21wc_2xdamage", "1")
	P_REGEN = register_cvar("n21wc_regen", "1")
	// 1 - только если в руках ничего нет. 2 - если переключен на нож. 3 - в любое время, 0 - отключить регенерацию
	
	g_maxPlayers = get_maxplayers()
	msgIndexWeaponList = get_user_msgid("WeaponList")
}

public client_putinserver(id)
{
	logan_claws[id] = 0
}

public fw_RoundStart()
{
	remove_task(TASK_REGEN)
	if (get_pcvar_num(P_REGEN))
		set_task(1.0, "regeneration", TASK_REGEN, _, _, "b")
}

public fw_TakeDamage(const victim, const weapon, const attacker, const Float: damage, const bits)
{
	if (!(bits & DMG_BULLET))
		return HAM_IGNORED
		
	if (!weapon || !is_entity_player(attacker) || !logan_claws[attacker])
		return HAM_IGNORED
			
	if (get_pdata_int(attacker, 114) == get_pdata_int(victim, 114) || get_user_weapon(attacker) != CSW_KNIFE)
		return HAM_IGNORED
	
	if (!get_pcvar_num(P_DAMAGE))
		return HAM_IGNORED
				
	SetHamParamFloat(4, damage * 2.0)
	return HAM_OVERRIDE
}

public fw_AddToPlayerKnife(const item, const player)
{
	if(pev_valid(item) && is_user_alive(player) && (get_user_flags(player) & ADMIN_FLAG || !get_pcvar_num(P_ADMIN)))
	{
		message_begin( MSG_ONE, msgIndexWeaponList, .player = player )
		{
			write_string("weapon_n21_claws")
			write_byte(-1)
			write_byte(-1)
			write_byte(-1)
			write_byte(-1)
			write_byte(2)
			write_byte(1)
			write_byte(CSW_KNIFE)
			write_byte(0)
		}
		message_end()
	}
}

public fw_KnifeDeploy(weapon)
{
	if (pev_valid(weapon) != 2)
		return HAM_IGNORED
	
	new id = get_pdata_cbase(weapon, 41, 4)
	
	if (pev_valid(id) != 2)
		return HAM_IGNORED
	
	if(get_user_flags(id) & ADMIN_FLAG || !get_pcvar_num(P_ADMIN))
	{
		set_pev(id, pev_viewmodel2, logan_claws[id] ? MODEL_V_CLAWS : MODEL_V_HANDS)
		set_pev(id, pev_weaponmodel2, logan_claws[id] ? MODEL_P_CLAWS : MODEL_P_HANDS)
	}
	
	return HAM_IGNORED
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_entity_player(id))
		return FMRES_IGNORED
	
	if(get_user_weapon(id) != CSW_KNIFE)
		return FMRES_IGNORED

	if(!get_pcvar_num(P_ADMIN) || get_user_flags(id) & ADMIN_FLAG)
	{
		if(equal(sample, "weapons/knife_hit1.wav"))
		{
			emit_sound(id, channel, logan_claws[id] ? "n21_admin_wolverine/hit1.wav" : "n21_admin_wolverine/hit1_B.wav", volume, attn, flags, pitch)
			return FMRES_SUPERCEDE
		}
	
		if(equal(sample, "weapons/knife_hit2.wav"))
		{
			emit_sound(id, channel, logan_claws[id] ? "n21_admin_wolverine/hit2.wav" : "n21_admin_wolverine/hit2_B.wav", volume, attn, flags, pitch)		
			return FMRES_SUPERCEDE
		}
	
		if(equal(sample, "weapons/knife_hit3.wav"))
		{
			emit_sound(id, channel, logan_claws[id] ? "n21_admin_wolverine/hit3.wav" : "n21_admin_wolverine/hit3_B.wav", volume, attn, flags, pitch)
			return FMRES_SUPERCEDE
		}
	
		if(equal(sample, "weapons/knife_hit4.wav"))
		{
			emit_sound(id, channel, logan_claws[id] ? "n21_admin_wolverine/hit4.wav" : "n21_admin_wolverine/hit4_B.wav", volume, attn, flags, pitch)			
			return FMRES_SUPERCEDE
		}
	
		if(equal(sample, "weapons/knife_hitwall1.wav"))
		{
			emit_sound(id, channel, logan_claws[id] ? "n21_admin_wolverine/wall1.wav" : "n21_admin_wolverine/hit3_B.wav", volume, attn, flags, pitch)
			return FMRES_SUPERCEDE
		}
	
		if(equal(sample, "weapons/knife_hitwall2.wav"))
		{
			emit_sound(id, channel, logan_claws[id] ? "n21_admin_wolverine/wall2.wav" : "n21_admin_wolverine/hit4_B.wav", volume, attn, flags, pitch)
			return FMRES_SUPERCEDE
		}
	
		if(equal(sample, "weapons/knife_stab.wav"))
		{
			new szNewSound[32]
			format(szNewSound, 31, logan_claws[id] ? "n21_admin_wolverine/hit%i.wav" : "n21_admin_wolverine/hit%i_B.wav", random(4) + 1)
			emit_sound(id, channel, szNewSound, volume, attn, flags, pitch)
			
			return FMRES_SUPERCEDE
		}

		if(equal(sample, "weapons/knife_slash1.wav") || equal(sample, "weapons/knife_slash2.wav"))
		{
			new szNewSound[48]
			if (logan_claws[id])
				format(szNewSound, 47, "n21_admin_wolverine/slash%i.wav", random(4) + 1)
			else
				format(szNewSound, 47, "n21_admin_wolverine/slash%i_B.wav", random(3) + 1)
				
			emit_sound(id, channel, szNewSound, volume, attn, flags, pitch)
			return FMRES_SUPERCEDE
		}
	}
	
	return FMRES_IGNORED
}

public change_to_claws(id)
{	
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	
	new weapon_ent = get_pdata_cbase(id, 373)
	if (pev_valid(weapon_ent) != 2 || get_pdata_int(weapon_ent, 43, 4) != CSW_KNIFE)
		return PLUGIN_CONTINUE
		
	if(get_user_flags(id) & ADMIN_FLAG || !get_pcvar_num(P_ADMIN))
	{			
		logan_claws[id] = !logan_claws[id]
		ExecuteHamB(Ham_Item_Deploy, weapon_ent)
		UTIL_PlayWeaponAnimation(id, logan_claws[id] ? 3 : 8)
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public ClientCommand_SelectClaws(const client) engclient_cmd(client, "weapon_knife")

public regeneration()
{
	new hp, isKnife
	for(new id = 1; id <= g_maxPlayers; id++)
	{
		if(!is_user_alive(id))
			continue
		
		hp = pev(id, pev_health)
		
		if(hp >= MAX_HEALTH)
			continue
		
		isKnife = get_user_weapon(id) == CSW_KNIFE
		
		if(regen_type == 1 && (logan_claws[id] || !isKnife))
			continue
		
		if(regen_type == 2 && !isKnife)
			continue
		
		fm_set_user_health(id, min(MAX_HEALTH, hp + 2))	
	}
}

UTIL_PlayWeaponAnimation(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
   
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(0)
	message_end()
}