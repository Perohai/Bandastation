#define STINGER_RANGE 5
#define STINGER_APPROACH_STEP (0.1 SECONDS)
#define STINGER_DRIVE_STEP (0.15 SECONDS)
#define STINGER_DAMAGE_INTERVAL (0.4 SECONDS)

/datum/action/cooldown/legendary_sword/star_deep_stinger
	name = "Чёрная комета"
	desc = "Выберите противника в пределах пяти клеток. Тёмная Звезда подхватит его и понесёт перед клинком до стены. Захват и каждые 0,4 секунды полёта наносят урон двух обычных ударов. Удар о стену наносит четырёхкратный урон и сбивает цель с ног на 3 секунды. Пока длится рывок, прямой урон по вам снижен на 95%."
	button_icon = 'modular_bandastation/weapon/icons/melee/dark_star_stinger_action.dmi'
	button_icon_state = "star_deep_stinger"
	required_bond = 100
	cooldown_time = 90 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/legendary_sword/star_deep_stinger/Activate(atom/target)
	var/mob/living/user = owner
	if(!isliving(target) || !saber?.can_use_legendary_ability(user, required_bond))
		return FALSE
	if(!user.apply_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger, saber, required_bond, target))
		return FALSE
	StartCooldown()
	return TRUE

/datum/status_effect/dark_star_sequence/deep_stinger
	parent_type = /datum/status_effect/dark_star_sequence/protected_dash
	tick_interval = STATUS_EFFECT_NO_TICK
	var/mob/living/marked_enemy
	var/obj/effect/dark_star_stinger_pose/pose
	var/obj/effect/dark_star_swing/windup
	var/steps_left = STINGER_RANGE
	var/travel_dir
	var/holding_target = FALSE
	var/owner_glide
	var/target_glide
	/// Only the step currently driven by the sword supplies its own momentum in zero gravity.
	var/mob/living/propelled

/datum/status_effect/dark_star_sequence/deep_stinger/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond, mob/living/victim)
	if(!..())
		return FALSE
	marked_enemy = victim
	if(!can_target(victim) || !is_enemy() || !has_approach())
		return FALSE
	RegisterSignal(owner, COMSIG_MOB_CLIENT_PRE_LIVING_MOVE, PROC_REF(block_manual_move))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(check_displacement))
	RegisterSignal(owner, COMSIG_MOVABLE_SPACEMOVE, PROC_REF(control_momentum))
	RegisterSignals(victim, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), TYPE_PROC_REF(/datum/status_effect/legendary_sword_sequence, stop_sequence))
	owner_glide = owner.glide_size
	ADD_TRAIT(owner, TRAIT_PULL_BLOCKED, REF(src))
	owner.face_atom(victim)
	windup = new(owner, saber, victim)
	owner.visible_message(span_warning("[capitalize(owner.declent_ru(NOMINATIVE))] направляет Тёмную Звезду на [victim.declent_ru(ACCUSATIVE)] и готовится к рывку!"))
	playsound(owner, saber.wieldsound, 45, FALSE)
	addtimer(CALLBACK(src, PROC_REF(approach)), 0.4 SECONDS, TIMER_DELETE_ME)
	return TRUE

/datum/status_effect/dark_star_sequence/deep_stinger/on_remove()
	propelled = null
	UnregisterSignal(owner, list(COMSIG_MOB_CLIENT_PRE_LIVING_MOVE, COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_SPACEMOVE))
	REMOVE_TRAIT(owner, TRAIT_PULL_BLOCKED, REF(src))
	if(!isnull(owner_glide) && (owner.glide_size == DELAY_TO_GLIDE_SIZE(STINGER_APPROACH_STEP) || owner.glide_size == DELAY_TO_GLIDE_SIZE(STINGER_DRIVE_STEP)))
		owner.set_glide_size(owner_glide)
	if(marked_enemy)
		UnregisterSignal(marked_enemy, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_SPACEMOVE))
		if(holding_target)
			marked_enemy.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_PULL_BLOCKED), REF(src))
			if(marked_enemy.glide_size == DELAY_TO_GLIDE_SIZE(STINGER_DRIVE_STEP))
				marked_enemy.set_glide_size(target_glide)
		marked_enemy = null
	QDEL_NULL(pose)
	QDEL_NULL(windup)
	return ..()

/datum/status_effect/dark_star_sequence/deep_stinger/proc/block_manual_move()
	SIGNAL_HANDLER
	return COMSIG_MOB_CLIENT_BLOCK_PRE_LIVING_MOVE

/datum/status_effect/dark_star_sequence/deep_stinger/proc/check_displacement(datum/source, atom/old_loc, direction, forced)
	SIGNAL_HANDLER
	if(source != propelled || forced)
		qdel(src)

/datum/status_effect/dark_star_sequence/deep_stinger/proc/control_momentum(datum/source)
	SIGNAL_HANDLER
	if(source == propelled)
		return COMSIG_MOVABLE_STOP_SPACEMOVE

/datum/status_effect/dark_star_sequence/deep_stinger/proc/is_enemy()
	return !owner.has_ally(marked_enemy) && !marked_enemy.has_ally(owner)

/// Only the path up to the target must be open. A target already against a wall is valid.
/datum/status_effect/dark_star_sequence/deep_stinger/proc/has_approach()
	var/turf/current = owner.loc
	var/turf/goal = marked_enemy.loc
	if(get_dist(current, goal) > STINGER_RANGE)
		return FALSE
	while(current != goal)
		var/turf/next = get_step(current, get_dir(current, goal))
		if(!isopenturf(next) || !current.Adjacent(next, mover = owner) || next.is_blocked_turf(source_atom = owner, ignore_atoms = list(marked_enemy)))
			return FALSE
		current = next
	return TRUE

/datum/status_effect/dark_star_sequence/deep_stinger/proc/fly_step(mob/living/mover, turf/next, delay)
	propelled = mover
	var/moved = mover.Move(next, travel_dir, DELAY_TO_GLIDE_SIZE(delay))
	propelled = null
	return moved && can_continue() && !QDELETED(mover) && mover.loc == next

/datum/status_effect/dark_star_sequence/deep_stinger/proc/approach()
	if(!can_continue() || !can_target(marked_enemy) || !is_enemy() || !has_approach())
		qdel(src)
		return
	var/direction = get_dir(owner, marked_enemy) || owner.dir
	if(windup)
		playsound(owner, 'modular_bandastation/weapon/sound/melee/ds_stinger_launch.ogg', 45, FALSE)
	if(!pose || travel_dir != direction)
		QDEL_NULL(windup)
		QDEL_NULL(pose)
		travel_dir = direction
		owner.setDir(direction)
		pose = new(owner, saber, direction)
	if(owner.Adjacent(marked_enemy))
		catch_target()
		return
	if(!steps_left || !fly_step(owner, get_step(owner, travel_dir), STINGER_APPROACH_STEP))
		qdel(src)
		return
	steps_left--
	addtimer(CALLBACK(src, PROC_REF(approach)), STINGER_APPROACH_STEP, TIMER_DELETE_ME)

/datum/status_effect/dark_star_sequence/deep_stinger/proc/catch_target()
	var/turf/contact = marked_enemy.loc
	// A lethal blow can still carry a body. Deletion or a death before contact cancels the charge.
	UnregisterSignal(marked_enemy, COMSIG_LIVING_DEATH)
	var/damage = strike_marked_target(marked_enemy, list(FORCE_MULTIPLIER = 2), 'modular_bandastation/weapon/sound/melee/ds_stinger_pulse.ogg', 42)
	if(!can_continue() || QDELETED(marked_enemy) || damage <= 0 || marked_enemy.loc != contact || !can_carry())
		qdel(src)
		return
	target_glide = marked_enemy.glide_size
	holding_target = TRUE
	RegisterSignal(marked_enemy, COMSIG_MOVABLE_MOVED, PROC_REF(check_displacement))
	RegisterSignal(marked_enemy, COMSIG_MOVABLE_SPACEMOVE, PROC_REF(control_momentum))
	marked_enemy.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_PULL_BLOCKED), REF(src))
	if(QDELETED(src))
		return
	new /obj/effect/temp_visual/dark_star_stinger_pulse(marked_enemy)
	addtimer(CALLBACK(src, PROC_REF(damage_pulse)), STINGER_DAMAGE_INTERVAL, TIMER_LOOP | TIMER_DELETE_ME)
	drive()

/datum/status_effect/dark_star_sequence/deep_stinger/proc/can_carry()
	return !QDELETED(marked_enemy) && isopenturf(marked_enemy.loc) && !marked_enemy.buckled && is_enemy() && marked_enemy.can_be_pulled(owner, MOVE_FORCE_STRONG)

/datum/status_effect/dark_star_sequence/deep_stinger/proc/damage_pulse()
	if(!can_continue() || !can_carry() || !owner.Adjacent(marked_enemy))
		qdel(src)
		return
	if(marked_enemy.stat != DEAD && strike_marked_target(marked_enemy, list(FORCE_MULTIPLIER = 2), 'modular_bandastation/weapon/sound/melee/ds_stinger_pulse.ogg', 32) > 0 && !QDELETED(src))
		new /obj/effect/temp_visual/dark_star_stinger_pulse(marked_enemy)

/datum/status_effect/dark_star_sequence/deep_stinger/proc/wall_ahead()
	var/turf/ahead = get_step(marked_enemy, travel_dir)
	if(!ahead)
		return FALSE
	if(isclosedturf(ahead) && ahead.density)
		return TRUE
	for(var/obj/structure/falsewall/wall in ahead)
		if(wall.density)
			return TRUE
	return FALSE

/// Move the victim first and follow into the vacated tile. Each Move resolves normal collisions.
/datum/status_effect/dark_star_sequence/deep_stinger/proc/drive()
	if(!can_continue() || !can_carry())
		qdel(src)
		return
	var/turf/contact = marked_enemy.loc
	if(owner.loc != contact && (get_step(owner, travel_dir) != contact || !owner.Adjacent(marked_enemy) || contact.is_blocked_turf(source_atom = owner, ignore_atoms = list(marked_enemy))))
		qdel(src)
		return
	if(wall_ahead())
		hit_wall()
		return
	var/turf/next = get_step(contact, travel_dir)
	if(!isopenturf(next) || next.is_blocked_turf(source_atom = marked_enemy) || !contact.Adjacent(next, mover = marked_enemy) || !fly_step(marked_enemy, next, STINGER_DRIVE_STEP))
		qdel(src)
		return
	if(owner.loc != contact && !fly_step(owner, contact, STINGER_DRIVE_STEP))
		qdel(src)
		return
	// The next drive starts when both sprites have glided to the new tile.
	addtimer(CALLBACK(src, PROC_REF(drive)), STINGER_DRIVE_STEP, TIMER_DELETE_ME)

/datum/status_effect/dark_star_sequence/deep_stinger/proc/hit_wall()
	var/mob/living/victim = marked_enemy
	new /obj/effect/temp_visual/dir_setting/dark_star_stinger_impact(victim.loc, travel_dir)
	playsound(victim, 'modular_bandastation/weapon/sound/melee/ds_stinger_wall.ogg', 60, FALSE)
	if(!QDELETED(pose))
		pose.finish()
		QDEL_IN(pose, 0.35 SECONDS)
		pose = null
	if(victim.stat != DEAD)
		strike_marked_target(victim, list(FORCE_MULTIPLIER = 4, SILENCE_HITSOUND = TRUE))
		if(!QDELETED(victim) && victim.stat != DEAD)
			victim.Knockdown(3 SECONDS)
	qdel(src)

/obj/effect/temp_visual/dark_star_stinger_pulse
	parent_type = /obj/effect/temp_visual/dark_star_target
	icon = 'icons/obj/weapons/guns/projectiles_impact.dmi'
	icon_state = "impact_greyscale"
	color = "#d0a1ff"
	layer = ABOVE_MOB_LAYER
	duration = 0.2 SECONDS

/obj/effect/temp_visual/dir_setting/dark_star_stinger_impact
	icon = 'modular_bandastation/weapon/icons/melee/dark_star_stinger_impact.dmi'
	icon_state = "impact"
	base_pixel_x = -16
	base_pixel_y = -16
	pixel_x = -16
	pixel_y = -16
	duration = 0.4 SECONDS

/obj/effect/temp_visual/dir_setting/dark_star_stinger_impact/Initialize(mapload, set_dir)
	. = ..()
	flick(icon_state, src)

#undef STINGER_RANGE
#undef STINGER_APPROACH_STEP
#undef STINGER_DRIVE_STEP
#undef STINGER_DAMAGE_INTERVAL
