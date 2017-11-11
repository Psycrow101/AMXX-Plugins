#if defined _portal_gun_portalBox_inc
	#endinput
#endif
#define _portal_gun_portalBox_inc

#define PBOX_SHIFT	1.0	// стандартный отступ от стены
#define PBOX_DEPTH	3.0	// отступ 'вглубь' для построения portalBox для проверки поверхности
#define PBOX_STEP	1.0 // шаг для смещения портала, смещение портала используется для обнаружения ровной поверхности
#define PBOX_ITERS	35	// максимальное количество шагов для смещения портала

enum _:portalBox_t {
	Float:ppointUL[3],	// up left
	Float:ppointUR[3],	// up right
	Float:ppointDR[3],	// down right
	Float:ppointDL[3],	// down left
	
	Float:pcenter[3],
	
	Float:pfwd[3],
	Float:pup[3],
	Float:pright[3]
}

bool:portalBox_create(const Float:shotFrom[3], const Float:shotDirection[3], playerId, outPortalBox[portalBox_t]) {
	static Float:pointEnd[3], Float:normal[3]
	
	xs_vec_mul_scalar(shotDirection, 9999.0, pointEnd)
	xs_vec_add(shotFrom, pointEnd, pointEnd)
	
	engfunc(EngFunc_TraceLine, shotFrom, pointEnd, 0, playerId, g_pCommonTr)
	
	get_tr2(g_pCommonTr, TR_vecEndPos, pointEnd)
	get_tr2(g_pCommonTr, TR_vecPlaneNormal, normal)
	
	portalBox_create2(pointEnd, normal, outPortalBox)
	
	static firstPortalBox[portalBox_t]
	portalBox_copy(outPortalBox, firstPortalBox)
	
	portalBox_move(outPortalBox, outPortalBox[pfwd], PBOX_SHIFT)
	
	static i, res
	for(i=0; i<PBOX_ITERS; i++) {
		res = portalBox_check(outPortalBox, normal)
		
		if(res == 1) 
			return true
			
		if(res == -1) {
			portalBox_copy(firstPortalBox, outPortalBox)
			
			return false
		}
		
		portalBox_move(outPortalBox, normal, PBOX_STEP)
	}
	
	portalBox_copy(firstPortalBox, outPortalBox)
	
	return false
}

void:portalBox_create2(const Float:pointCenter[3], const Float:normal[3], outPortalBox[portalBox_t]) {
	static Float:fwd[3], Float:right[3], Float:up[3], Float:left[3], Float:down[3]
	
	vector_to_angle(normal, fwd)
	xs_anglevectors(fwd, fwd, right, up)
	
	up[2] = -up[2]
	fwd[2] = -fwd[2]
	right[2] = -right[2]
	
	xs_vec_copy(fwd, outPortalBox[pfwd])
	xs_vec_copy(up, outPortalBox[pup])
	xs_vec_copy(right, outPortalBox[pright])
	xs_vec_copy(pointCenter, outPortalBox[pcenter])
	
	xs_vec_mul_scalar(right, PORTAL_WIDTH / 2, right)
	xs_vec_mul_scalar(up, PORTAL_HEIGHT / 2, up)
	xs_vec_neg(right, left)
	xs_vec_neg(up, down)
	
	xs_vec_add(up, left, outPortalBox[ppointUL])
	xs_vec_add(up, right, outPortalBox[ppointUR])
	xs_vec_add(down, right, outPortalBox[ppointDR])
	xs_vec_add(down, left, outPortalBox[ppointDL])
	
	xs_vec_add(pointCenter, outPortalBox[ppointUL], outPortalBox[ppointUL])
	xs_vec_add(pointCenter, outPortalBox[ppointUR], outPortalBox[ppointUR])
	xs_vec_add(pointCenter, outPortalBox[ppointDR], outPortalBox[ppointDR])
	xs_vec_add(pointCenter, outPortalBox[ppointDL], outPortalBox[ppointDL])
}

void:portalBox_move(portalBox[portalBox_t], const Float:direction[/*3*/], Float:dist) {
	vec_move_point(portalBox[ppointUL], direction, dist)
	vec_move_point(portalBox[ppointUR], direction, dist)
	vec_move_point(portalBox[ppointDR], direction, dist)
	vec_move_point(portalBox[ppointDL], direction, dist)
	vec_move_point(portalBox[pcenter], direction, dist)
}

portalBox_check(const portalBox[portalBox_t], Float:outBestDirection[/*3*/]) {	
	static portalBoxBackward[portalBox_t], Float:backward[3]
	portalBox_copy(portalBox, portalBoxBackward)
	xs_vec_neg(portalBoxBackward[pfwd], backward)
	portalBox_move(portalBoxBackward, backward, PBOX_DEPTH)
	
	static Float:resTable[4]
	engfunc(EngFunc_TraceLine, portalBox[ppointUL], portalBoxBackward[ppointUL], IGNORE_ALL, 0, g_pCommonTr)
	get_tr2(g_pCommonTr, TR_flFraction, resTable[0])

	engfunc(EngFunc_TraceLine, portalBox[ppointUR], portalBoxBackward[ppointUR], IGNORE_ALL, 0, g_pCommonTr)
	get_tr2(g_pCommonTr, TR_flFraction, resTable[1])
	
	engfunc(EngFunc_TraceLine, portalBox[ppointDR], portalBoxBackward[ppointDR], IGNORE_ALL, 0, g_pCommonTr)
	get_tr2(g_pCommonTr, TR_flFraction, resTable[2])
	
	engfunc(EngFunc_TraceLine, portalBox[ppointDL], portalBoxBackward[ppointDL], IGNORE_ALL, 0, g_pCommonTr)
	get_tr2(g_pCommonTr, TR_flFraction, resTable[3])
	
	//@TODO переставить значения массива, чтоб в конце были те состояние, которые чаще всего встречаются
	enum {VALID, INVALID, UP, UP_RIGHT, UP_LEFT, DOWN, DOWN_RIGHT, DOWN_LEFT, RIGHT, LEFT}
	static const dirState[][] = {
		{0, 0, 0, 0},	{0, 0, 0, 1},	{0, 0, 1, 0},	{0, 0, 1, 1},	{0, 1, 0, 0},	{0, 1, 0, 1},	{0, 1, 1, 0},	{0, 1, 1, 1},
		{1, 0, 0, 0},	{1, 0, 0, 1},	{1, 0, 1, 0},	{1, 0, 1, 1},	{1, 1, 0, 0},	{1, 1, 0, 1},	{1, 1, 1, 0},	{1, 1, 1, 1}
	}
	static const dirAction[] = {
		INVALID,		DOWN_LEFT,		DOWN_RIGHT,		DOWN,			UP_RIGHT,		UP_RIGHT /**/,	RIGHT,			DOWN_RIGHT,
		UP_LEFT, 		LEFT, 			INVALID, 		DOWN_LEFT, 		UP,				UP_LEFT, 		UP_RIGHT, 		VALID
	}
	
	static i
	for(i=0; i<sizeof resTable; i++)
		resTable[i] = resTable[i] == 1.0 ? 0.0 : 1.0
	
	for(i=(sizeof dirState)-1; i>-1; i--) {
		if(	(resTable[0] == dirState[i][0]) &&
			(resTable[1] == dirState[i][1]) &&
			(resTable[2] == dirState[i][2]) &&
			(resTable[3] == dirState[i][3]))
			break
	}
	
	static Float:tmpVec[3]
	switch(dirAction[i]) {
		case VALID:		return 1
		case INVALID:	return -1
		case UP:		xs_vec_copy(portalBox[pup], outBestDirection)
		case UP_RIGHT:	{
						xs_vec_copy(portalBox[pup], outBestDirection)
						xs_vec_add(portalBox[pright], outBestDirection, outBestDirection)
			}
		case UP_LEFT:	{
						xs_vec_neg(portalBox[pright],tmpVec)
						xs_vec_copy(portalBox[pup], outBestDirection)
						xs_vec_add(tmpVec, outBestDirection, outBestDirection)
			}
		case DOWN:		xs_vec_neg(portalBox[pup], outBestDirection)
		case DOWN_RIGHT:{
						xs_vec_neg(portalBox[pup], outBestDirection)
						xs_vec_add(outBestDirection, portalBox[pright], outBestDirection)
			}
		case DOWN_LEFT:	{
						xs_vec_neg(portalBox[pright], tmpVec)
						xs_vec_neg(portalBox[pup], outBestDirection)
						xs_vec_add(tmpVec, outBestDirection, outBestDirection)
			}
		case RIGHT:		xs_vec_copy(portalBox[pright], outBestDirection)
		case LEFT:		xs_vec_neg(portalBox[pright], outBestDirection)
	}
	
	return 0
}

void:portalBox_copy(const portalBox[portalBox_t], outPortalBox[portalBox_t]) {
	xs_vec_copy(portalBox[ppointUL], outPortalBox[ppointUL])
	xs_vec_copy(portalBox[ppointDL], outPortalBox[ppointDL])
	xs_vec_copy(portalBox[ppointDR], outPortalBox[ppointDR])
	xs_vec_copy(portalBox[ppointUR], outPortalBox[ppointUR])
	
	xs_vec_copy(portalBox[pcenter], outPortalBox[pcenter])
	
	xs_vec_copy(portalBox[pfwd], outPortalBox[pfwd])
	xs_vec_copy(portalBox[pup], outPortalBox[pup])
	xs_vec_copy(portalBox[pright], outPortalBox[pright])
}