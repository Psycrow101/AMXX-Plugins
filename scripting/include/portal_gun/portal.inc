#if defined _portal_gun_portal_inc
	#endinput
#endif
#define _portal_gun_portal_inc

#include <fakemeta>
#include <xs>

#define PORTAL_IS_VALID_PAIR(%0)	(pev_valid(g_portals[%0][0]) && pev_valid(g_portals[%0][1]))

#define PORTAL_1	0
#define PORTAL_2	1
#define PORTAL_ALL	2

static g_portals[MAX_PLAYERS][2]

bool:portal_test_owner(player, ent, type) {
	if(ent == 0)
		return false
	
	if(type < 2) {
		if(g_portals[player][type] == ent)
			return true
	}
	else {
		if(g_portals[player][0] == ent || g_portals[player][1] == ent)
			return true
	}
	
	return false
}

bool:portal_is_set_pair(player) {
	return (g_portals[player][0] && g_portals[player][1])
}

bool:portal_create_pair(player) {
	if(PORTAL_IS_VALID_PAIR(player)) {
		set_pev(g_portals[player][0], pev_effects, pev(g_portals[player][0], pev_effects) | EF_NODRAW)
		set_pev(g_portals[player][1], pev_effects, pev(g_portals[player][1], pev_effects) | EF_NODRAW)
		
		return true
	}
	
	new pair[2]
	
	for(new i; i < 2; i++) {
		pair[i] = engfunc(EngFunc_CreateNamedEntity, g_pStringInfTarg)
		if(!pev_valid(pair[i])) {
			// @TODO лог - ошибка создания энтити
			if(i == 1) {
				engfunc(EngFunc_RemoveEntity, pair[0])
			}
			
			return false
		}
		
		engfunc(EngFunc_SetModel, pair[i], g_sPortalModel)
		set_pev_string(pair[i], pev_classname, g_pStringPortalClass)
		set_pev(pair[i], pev_solid, SOLID_TRIGGER)
		set_pev(pair[i], pev_movetype, MOVETYPE_NONE)
		set_pev(pair[i], pev_effects, pev(pair[i], pev_effects) | EF_NODRAW)
	}
	
	set_pev(pair[0], pev_owner, pair[1])
	set_pev(pair[1], pev_owner, pair[0])
	
	g_portals[player][0] = pair[0]
	g_portals[player][1] = pair[1]
	
	return true
}

void:portal_open(player, const pbox[portalBox_t], type, bool:sound) {
	if(!PORTAL_IS_VALID_PAIR(player)) {
		//@TODO лог, порталы не были созданы или энтити порталов удалены
		return
	}
	
	// @TODO проверить расчёты
	// upd1: хотя не обязательно
	new Float:min[3], Float:max[3]
	max[0] = PORTAL_HEIGHT/2 - PORTAL_WIDTH/2 * floatabs(pbox[pfwd][0])
	max[1] = PORTAL_HEIGHT/2 - PORTAL_WIDTH/2 * floatabs(pbox[pfwd][1])
	max[2] = PORTAL_HEIGHT/2 - PORTAL_WIDTH/2 * floatabs(pbox[pfwd][2])

	min[0] = -max[0]
	min[1] = -max[1]
	min[2] = -max[2]
	
	new Float:angle[3]
	engfunc(EngFunc_VecToAngles, pbox[pfwd], angle)
	
	new portal = g_portals[player][type]
	
	engfunc(EngFunc_SetSize, portal, min, max)
	
	engfunc(EngFunc_SetOrigin, portal, pbox[pcenter])
	set_pev(portal, pev_angles, angle)
	set_pev(portal, pev_effects, pev(portal, pev_effects) & ~EF_NODRAW)
	set_pev(portal, pev_skin, type)
	
	if(sound) {
		emit_sound(portal, CHAN_AUTO, random_num(0,1) ? g_sPortalSoundOpen1 : g_sPortalSoundOpen2, 1.0, ATTN_NORM, 0, PITCH_NORM)	
	}
}

void:portal_close(player, type) {
	if(!PORTAL_IS_VALID_PAIR(player)) {
		//@TODO лог, порталы не были созданы или энтити порталов удалены
		return
	}
	
	if(type < 2) {
		set_pev(g_portals[player][type], pev_effects, pev(g_portals[player][type], pev_effects) | EF_NODRAW)
	}
	else {
		set_pev(g_portals[player][0], pev_effects, pev(g_portals[player][0], pev_effects) | EF_NODRAW)
		set_pev(g_portals[player][1], pev_effects, pev(g_portals[player][1], pev_effects) | EF_NODRAW)
	}
}

void:portal_remove_pair(player) {
	for(new i; i < 2; i++) {
		if(!pev_valid(g_portals[player][i])) {
			g_portals[player][i] = 0
			continue
		}
		
		engfunc(EngFunc_RemoveEntity, g_portals[player][i])
		g_portals[player][i] = 0
	}
}

// creepy... @TODO рефактор
bool:portal_teleport(id, entPortalOut, entPortalIn)
{
	#define VEC_FLOOR					Float:{0.0, 0.0, 1.0}
	#define VEC_CEILING					Float:{0.0, 0.0, -1.0}
	#define IGNORE_ANGLE_DEG_FL			75.0
	#define IGNORE_ANGLE_DEG_CE			50.0
	#define IGNORE_SPEED				300.0
	
	#define xs_1_neg(%1)				%1 = -%1
	
	enum
	{
		Portal_On_Floor = 1,
		Portal_On_Ceiling
	}
	
	enum _:Portal_Properties
	{
		Portal_Start,
		Portal_End
	}
	
	new Float:fPortalAngles[Portal_Properties][3],
		Float:fPortalNormal[Portal_Properties][3],
		Float:fPortalEndOrigin[3],
		bitPortalAprxmOrig[Portal_Properties],
		Float:fEntAngles[3],
		Float:fEntVelocity[3]
	
	pev(entPortalIn,	pev_angles, fPortalAngles[Portal_Start])
	pev(entPortalOut,	pev_angles, fPortalAngles[Portal_End])
	angle_vector(fPortalAngles[Portal_Start], ANGLEVECTOR_FORWARD, fPortalNormal[Portal_Start])
	angle_vector(fPortalAngles[Portal_End], ANGLEVECTOR_FORWARD, fPortalNormal[Portal_End])
	xs_1_neg(fPortalNormal[Portal_Start][2])
	xs_1_neg(fPortalNormal[Portal_End][2])
	pev(entPortalOut,	pev_origin, fPortalEndOrigin)
	pev(id, pev_v_angle, fEntAngles)
	pev(id, pev_velocity, fEntVelocity)
	
	if(xs_vec_angle(VEC_FLOOR, fPortalNormal[Portal_Start]) < IGNORE_ANGLE_DEG_FL)	bitPortalAprxmOrig[Portal_Start] |= Portal_On_Floor	// [0] портал на вход примерно на полу
	if(xs_vec_angle(VEC_CEILING, fPortalNormal[Portal_Start]) < IGNORE_ANGLE_DEG_CE)bitPortalAprxmOrig[Portal_Start] |= Portal_On_Ceiling
	if(xs_vec_angle(VEC_FLOOR, fPortalNormal[Portal_End]) < IGNORE_ANGLE_DEG_FL)	bitPortalAprxmOrig[Portal_End] |= Portal_On_Floor	// [1] портал на выход премерно на потолке
	if(xs_vec_angle(VEC_CEILING, fPortalNormal[Portal_End]) < IGNORE_ANGLE_DEG_CE)	bitPortalAprxmOrig[Portal_End] |= Portal_On_Ceiling
	
	//------------------------------- orig
	new Float:min[3], Float:max[3]
	pev(id, pev_mins, min)
	pev(id, pev_maxs, max)
	
	new classname[32]
	pev(id, pev_classname, classname, charsmax(classname))
	
	// для "нулевой" энтити не надо
	if(!xs_vec_nearlyequal(min, Vec3Zero) && !xs_vec_nearlyequal(max, Vec3Zero))
	{
		new Float:boxSize[3], Float:zCenter
		boxSize[0] = (floatabs(min[0]) + floatabs(max[0])) / 2.0
		boxSize[1] = (floatabs(min[1]) + floatabs(max[1])) / 2.0
		boxSize[2] = (floatabs(min[2]) + floatabs(max[2])) / 2.0
		
		zCenter = boxSize[2] > max[2] ? (max[2] - boxSize[2]) : (boxSize[2] - max[2])
		
		new Float:portalMin[3], Float:portalMax[3]
		pev(entPortalOut, pev_mins, portalMin)
		pev(entPortalOut, pev_maxs, portalMax)
		
		new Float:portalBoxSize[3]
		portalBoxSize[0] = (floatabs(min[0]) + floatabs(max[0])) / 2.0
		portalBoxSize[1] = (floatabs(min[1]) + floatabs(max[1])) / 2.0
		portalBoxSize[2] = (floatabs(min[2]) + floatabs(max[2])) / 2.0
		
		// объекты больше чем портал нельзя телепортировать
		if((boxSize[0] > portalBoxSize[0]) || (boxSize[1] > portalBoxSize[1]) || (boxSize[2] > portalBoxSize[2]))
			return false
		
		// @TODO переосмыслить
		new Float:sinAngle = xs_sin(xs_vec_angle(fPortalAngles[Portal_End], Vec3Zero), degrees)
		new Float:shift, dimension = 1
		
		if(fPortalAngles[Portal_End][XS_PITCH] > 45.0)
			dimension = 2
		
		shift = boxSize[dimension] / sinAngle + portalMax[dimension] / sinAngle
		
		new Float:destination[3]
		xs_vec_mul_scalar(fPortalNormal[Portal_End], shift + PORTAL_DESTINATION_SHIFT, destination)
		xs_vec_add(destination, fPortalEndOrigin, destination)
		
		engfunc(EngFunc_TraceHull, destination, destination, 0, HULL_HUMAN, id, g_pCommonTr)
		if(get_tr2(g_pCommonTr, TR_StartSolid) || get_tr2(g_pCommonTr, TR_AllSolid) || get_tr2(g_pCommonTr, TR_pHit) >= 0)
			return false
		
		destination[2] += zCenter
		
		if(equal(classname, "player") || equal(classname, "hostage_entity"))
			engfunc(EngFunc_SetOrigin, id, destination)
		else
			set_pev(id, pev_origin, destination)
	}
	else {
		set_pev(id, pev_origin, fPortalEndOrigin)
	}
	
	//-------------------------------- angl
	
	new Float:fOutAngles[3], Float:fSpeed = vector_length(fEntVelocity)
	
	if(bitPortalAprxmOrig[Portal_End] && fSpeed > IGNORE_SPEED) {
		if(xs_vec_nearlyequal(fPortalNormal[Portal_End], VEC_FLOOR) || xs_vec_nearlyequal(fPortalNormal[Portal_End], VEC_CEILING))
			xs_vec_copy(fEntAngles, fOutAngles)
		else {
			fOutAngles[0] = fEntAngles[0] - 80.0 - fPortalAngles[Portal_Start][0] + fPortalAngles[Portal_End][0]
			fOutAngles[1] = fPortalAngles[Portal_End][1]
			fOutAngles[2] = fPortalAngles[Portal_End][2] // ??
		}
	}
	else if((bitPortalAprxmOrig[Portal_Start] && bitPortalAprxmOrig[Portal_End]) || (~bitPortalAprxmOrig[Portal_Start] && bitPortalAprxmOrig[Portal_End]))
		xs_vec_copy(fEntAngles, fOutAngles)
	else if(bitPortalAprxmOrig[Portal_Start] && ~bitPortalAprxmOrig[Portal_End])
		xs_vec_copy(fPortalAngles[Portal_End], fOutAngles)
	else
	{
		fOutAngles[0] = fEntAngles[0]
		fOutAngles[1] = fEntAngles[1] + 180.0 + fPortalAngles[Portal_End][1] - fPortalAngles[Portal_Start][1]
		fOutAngles[2] = fEntAngles[2]
	}
	
	set_pev(id, pev_angles, fOutAngles)
	
	if(equal(classname, "player"))
	{
		set_pev(id, pev_v_angle, fOutAngles)
		set_pev(id, pev_fixangle, 1)
	}
	
	//-------------------------------- velo
	
	new Float:fOutVelocity[3]
	
	if(	(bitPortalAprxmOrig[Portal_Start] & Portal_On_Floor && bitPortalAprxmOrig[Portal_End] & Portal_On_Ceiling) ||
		(bitPortalAprxmOrig[Portal_Start] & Portal_On_Ceiling && bitPortalAprxmOrig[Portal_End] & Portal_On_Floor) )
	{
		xs_vec_copy(fEntVelocity, fOutVelocity)
		set_pev(id, pev_velocity, fOutVelocity)
		return true
	}
	
	if(	(bitPortalAprxmOrig[Portal_Start] & Portal_On_Floor && bitPortalAprxmOrig[Portal_End] & Portal_On_Floor) || 
		(bitPortalAprxmOrig[Portal_Start] & Portal_On_Ceiling && bitPortalAprxmOrig[Portal_End] & Portal_On_Ceiling))
	{
		if(fSpeed < IGNORE_SPEED)
		{
			xs_vec_copy(fEntVelocity, fOutVelocity)
			xs_1_neg(fOutVelocity[2])
		}
		else
			xs_vec_mul_scalar(fPortalNormal[Portal_End], fSpeed, fOutVelocity)
		set_pev(id, pev_velocity, fOutVelocity)
		return true
	}
	else if(bitPortalAprxmOrig[Portal_Start] & (Portal_On_Floor | Portal_On_Ceiling) && ~bitPortalAprxmOrig[Portal_End])
	{
		xs_vec_mul_scalar(fPortalNormal[Portal_End], fSpeed, fOutVelocity)
		set_pev(id, pev_velocity, fOutVelocity)
		return true
	}
	else if(bitPortalAprxmOrig[Portal_End] & (Portal_On_Floor | Portal_On_Ceiling) && ~bitPortalAprxmOrig[Portal_Start])
	{
		if(fSpeed < IGNORE_SPEED)
			xs_vec_copy(fEntVelocity, fOutVelocity)
		else
			xs_vec_mul_scalar(fPortalNormal[Portal_End], fSpeed, fOutVelocity)
		set_pev(id, pev_velocity, fOutVelocity)
		return true
	}
	
	new Float:fNormalVelocity[3]
	xs_vec_normalize(fEntVelocity, fNormalVelocity)
	
	new Float:fReflectNormal[3]
	xs_vec_add(fPortalNormal[Portal_Start], fPortalNormal[Portal_End], fReflectNormal)
	
	xs_vec_normalize(fReflectNormal, fReflectNormal)
	xs_vec_reflect(fNormalVelocity, fReflectNormal, fOutVelocity)
	xs_1_neg(fOutVelocity[2])
	xs_vec_neg(fOutVelocity, fOutVelocity)
	xs_vec_reflect(fOutVelocity, fPortalNormal[Portal_End], fOutVelocity)
	
	if(vector_length(fOutVelocity) <= 0)
		xs_vec_copy(fNormalVelocity, fOutVelocity)
	
	xs_vec_mul_scalar(fOutVelocity, fSpeed, fOutVelocity)
	
	if(vector_length(fOutVelocity) <= 0)			//"PM Got a NaN velocity %"
		xs_vec_set(fOutVelocity, 0.1, 0.1, 0.1)
	
	set_pev(id, pev_velocity, fOutVelocity)

	return true
	#undef VEC_FLOOR
	#undef VEC_CEILING
	#undef IGNORE_ANGLE_DEG_FL
	#undef IGNORE_ANGLE_DEG_CE
	#undef IGNORE_SPEED
	
	#undef xs_1_neg
}

#undef PORTAL_IS_VALID_PAIR
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
