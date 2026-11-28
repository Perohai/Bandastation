#define VOID_SLASH_RADIUS 3
#define VOID_SLASH_WINDUP (0.5 SECONDS)
#define VOID_SLASH_HOLD (1.3 SECONDS)
#define VOID_SLASH_RECOVERY (0.5 SECONDS)

/datum/action/cooldown/legendary_sword/star_void_slash
	name = "Разрез пустоты"
	desc = "Укажите направление и сохраняйте стойку. Через полсекунды взмах нанесёт обычный удар мечом по каждой цели в секторе до трёх клеток и замедлит раненых. Через 1,3 секунды разлом схлопнется. Каждая цель, которую он сдвинет к вам, получит ещё один обычный удар."
	button_icon = 'modular_bandastation/weapon/icons/melee/dark_star_void_action.dmi'
	button_icon_state = "star_void_slash"
	click_to_activate = TRUE
	required_bond = 50
	cooldown_time = 25 SECONDS

/datum/action/cooldown/legendary_sword/star_void_slash/Activate(atom/target)
	var/mob/living/user = owner
	if(!saber?.can_use_legendary_ability(user, required_bond))
		return FALSE
	var/turf/aim = get_turf(target)
	if(!aim || aim == user.loc || !(aim in view(user)))
		return FALSE
	if(!user.apply_status_effect(/datum/status_effect/dark_star_sequence/void_slash, saber, required_bond, aim))
		return FALSE
	StartCooldown()
	return TRUE

/datum/status_effect/dark_star_sequence/void_slash
	tick_interval = STATUS_EFFECT_NO_TICK
	/// Facing is locked to the opening stance even if the wielder turns.
	var/slash_dir
	/// Maps each victim wounded by the opening cut to whether its pull strike has been attempted.
	var/list/caught = list()
	var/obj/effect/dark_star_swing/void_slash/pose
	var/obj/effect/temp_visual/dark_star_void_slash/rift

/datum/status_effect/dark_star_sequence/void_slash/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond, turf/aim)
	if(!..() || !aim || aim.z != owner.z || owner.loc == aim)
		return FALSE
	slash_dir = angle2dir(delta_to_angle(aim.x - owner.x, aim.y - owner.y))
	var/turf/facing_tile = get_step(owner, slash_dir)
	if(!facing_tile)
		return FALSE
	owner.face_atom(facing_tile)
	pose = new(owner, saber, facing_tile)
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/datum/status_effect/legendary_sword_sequence, stop_sequence))
	addtimer(CALLBACK(src, PROC_REF(open_rift)), VOID_SLASH_WINDUP, TIMER_DELETE_ME)
	return TRUE

/datum/status_effect/dark_star_sequence/void_slash/on_remove()
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	release_slows()
	caught.Cut()
	QDEL_NULL(pose)
	QDEL_NULL(rift)
	return ..()

/// Check the actual angle between tile centers, including the edges of the 90-degree arc.
/datum/status_effect/dark_star_sequence/void_slash/proc/in_arc(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD || !isopenturf(victim.loc) || victim.z != owner.z || victim.loc == owner.loc)
		return FALSE
	if(get_dist_euclidean(owner, victim) > VOID_SLASH_RADIUS)
		return FALSE
	var/victim_angle = delta_to_angle(victim.x - owner.x, victim.y - owner.y)
	return abs(closer_angle_difference(dir2angle(slash_dir), victim_angle)) <= 45 && victim.IsReachableBy(owner, VOID_SLASH_RADIUS)

/datum/status_effect/dark_star_sequence/void_slash/proc/open_rift()
	if(!can_continue())
		qdel(src)
		return
	rift = new(owner.loc, slash_dir)
	playsound(owner, 'modular_bandastation/weapon/sound/melee/ds_void_open.ogg', 50, FALSE)
	for(var/mob/living/victim in oview(VOID_SLASH_RADIUS, owner))
		if(!in_arc(victim))
			continue
		var/damage_done = strike_marked_target(victim, list(SILENCE_HITSOUND = TRUE))
		// A block or retaliation can disarm the wielder during the attack.
		if(!can_continue())
			qdel(src)
			return
		if(damage_done > 0 && !QDELETED(victim) && victim.stat != DEAD)
			caught[WEAKREF(victim)] = FALSE
			victim.apply_status_effect(/datum/status_effect/grouped/dark_star_void, REF(src))
	addtimer(CALLBACK(src, PROC_REF(collapse)), VOID_SLASH_HOLD, TIMER_DELETE_ME)

/datum/status_effect/dark_star_sequence/void_slash/proc/release_slows()
	for(var/datum/weakref/target_ref as anything in caught)
		var/mob/living/victim = target_ref.resolve()
		victim?.remove_status_effect(/datum/status_effect/grouped/dark_star_void, REF(src))

/datum/status_effect/dark_star_sequence/void_slash/proc/collapse()
	if(!can_continue() || QDELETED(rift))
		qdel(src)
		return
	rift.icon_state = "collapse"
	flick(rift.icon_state, rift)
	playsound(owner, 'modular_bandastation/weapon/sound/melee/ds_void_collapse.ogg', 48, FALSE)
	release_slows()
	pull_step()
	if(QDELETED(src))
		return
	addtimer(CALLBACK(src, PROC_REF(pull_step)), 0.2 SECONDS, TIMER_DELETE_ME)
	QDEL_IN(src, VOID_SLASH_RECOVERY)

/datum/status_effect/dark_star_sequence/void_slash/proc/pull_step()
	if(!can_continue())
		qdel(src)
		return
	var/list/visible = view(VOID_SLASH_RADIUS, owner)
	for(var/datum/weakref/target_ref as anything in caught)
		var/mob/living/victim = target_ref.resolve()
		if(!(victim in visible) || !in_arc(victim) || victim.buckled || get_dist(victim, owner) <= 1)
			continue
		if(!victim.can_be_pulled(owner, MOVE_FORCE_STRONG))
			continue
		var/direction = get_dir(victim, owner)
		var/turf/next_tile = get_step(victim, direction)
		if(!next_tile || next_tile.is_blocked_turf(source_atom = victim))
			continue
		var/turf/start_tile = victim.loc
		victim.Move(next_tile, direction)
		if(!can_continue())
			qdel(src)
			return
		if(caught[target_ref] || QDELETED(victim) || victim.stat == DEAD || !isopenturf(victim.loc) || victim.z != start_tile.z)
			continue
		// A diagonal Move can advance one cardinal step even when its second half is blocked.
		if(get_dist(start_tile, victim) != 1 || get_dist_euclidean(owner, victim) >= get_dist_euclidean(owner, start_tile))
			continue
		caught[target_ref] = TRUE
		strike_marked_target(victim, list(SILENCE_HITSOUND = TRUE))
		if(!can_continue())
			qdel(src)
			return

/obj/effect/temp_visual/dark_star_void_slash
	parent_type = /obj/effect/temp_visual/dir_setting
	icon = 'modular_bandastation/weapon/icons/melee/dark_star_void_slash.dmi'
	icon_state = "rift"
	base_pixel_x = -96
	base_pixel_y = -96
	pixel_x = -96
	pixel_y = -96
	duration = VOID_SLASH_HOLD + VOID_SLASH_RECOVERY

/obj/effect/temp_visual/dark_star_void_slash/Initialize(mapload, set_dir)
	. = ..()
	flick(icon_state, src)

/// Concurrent rifts release only their own slow when the wielder breaks stance.
/datum/status_effect/grouped/dark_star_void
	id = "dark_star_void_slow"
	tick_interval = STATUS_EFFECT_NO_TICK

/datum/status_effect/grouped/dark_star_void/on_apply()
	. = ..()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/status_effect/dark_star_void)

/datum/status_effect/grouped/dark_star_void/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/status_effect/dark_star_void)
	return ..()

/datum/movespeed_modifier/status_effect/dark_star_void
	multiplicative_slowdown = 4.5

#undef VOID_SLASH_RADIUS
#undef VOID_SLASH_WINDUP
#undef VOID_SLASH_HOLD
#undef VOID_SLASH_RECOVERY
