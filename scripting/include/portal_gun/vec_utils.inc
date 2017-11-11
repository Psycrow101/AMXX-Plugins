#if defined _portal_gun_vec_inc
	#endinput
#endif
#define _portal_gun_vec_inc

new stock const	Float:Vec3Zero[3] = {0.0, 0.0, 0.0}
new stock const Float:VEC_HUMAN_HULL_MIN[3] = {-16.0, -16.0, 0.0}
new stock const Float:VEC_HUMAN_HULL_MAX[3] = {16.0, 16.0, 72.0}

new stock const Float:VEC_HUMAN_HULL[3] = {16.0, 16.0, 36.0}

stock void:vec_move_point(Float:vec[], const Float:direction[], const Float:dist) {
	static Float:tmp[3]
	xs_vec_mul_scalar(direction, dist, tmp)
	xs_vec_add(vec, tmp, vec)
}

stock void:point_forward(const id, const Float:dist, Float:out[3]) {
	static Float:angles[3], Float:origin[3]
	pev(id, pev_angles, angles)
	pev(id, pev_origin, origin)
	angle_vector(angles, ANGLEVECTOR_FORWARD, angles)
	angles[2] = -angles[2]
	xs_vec_mul_scalar(angles, dist, angles)
	xs_vec_add(angles, origin, out)
}