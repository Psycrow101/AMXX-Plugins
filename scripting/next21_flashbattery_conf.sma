#include <amxmodx>
#include <fakemeta>

#define PLUGIN "Flashlight Battery Configuration"
#define VERSION "1.0"
#define AUTHOR "Oli Desu"

#define	m_flFlashLightTime	243
#define	m_iFlashBattery		244

#define FLASH_DRAIN_TIME		1.2
#define FLASH_CHARGE_TIME		0.2


new g_pDrain, g_pCharge, g_iFlashBattery[33]


public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_Spawn, "fwd_Spawn_Post", 1)
	register_forward(FM_UpdateClientData, "fwd_UpdateClientData_Post", 1)
	
	g_pDrain = register_cvar("n21_flashlight_drain", "1.2")
	g_pCharge = register_cvar("n21_flashlight_charge", "0.2")
}

public fwd_Spawn_Post(id)
{
	if (is_user_alive(id))
		g_iFlashBattery[id] = get_pdata_int(id, m_iFlashBattery)
}

public fwd_UpdateClientData_Post(id)
{
	static iFlashBattery
	iFlashBattery = get_pdata_int(id, m_iFlashBattery)
	
	if (g_iFlashBattery[id] > iFlashBattery)
	{
		set_pdata_float(id, m_flFlashLightTime,
			get_pdata_float(id, m_flFlashLightTime) - FLASH_DRAIN_TIME
			+ get_pcvar_float(g_pDrain))
	}
	else if (g_iFlashBattery[id] < iFlashBattery)
	{
		set_pdata_float(id, m_flFlashLightTime,
			get_pdata_float(id, m_flFlashLightTime) - FLASH_CHARGE_TIME
			+ get_pcvar_float(g_pCharge))
	}
		
	g_iFlashBattery[id] = iFlashBattery
}

