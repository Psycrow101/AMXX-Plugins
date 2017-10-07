/**
 * Called after changing hat
 *
 * @param 	id				- Player id
 * @param	hat				- Hat entity id
 */
forward ka_change_hat(id, ent)


/**
 * Get the hat entity id on the player
 *
 * @param 	id				- Player id
 * @return					- Hat entity id
 */
native ka_get_hat(const id)

/**
 * Set the hat model ("!NULL" - remove hat from the player)
 *
 * @param 	id				- Player id
 * @param	model			- Hat model
 * @param	part			- Hat part (skin or body)
 * @return					- Hat entity id (successful) or 0 (failure/hat removed)
 */
native ka_set_hat_model(const id, const model[], const part = 0)