/** Armoured breacher; momentum, stomp and crest toss follow TGMC's Crusher role. */
/mob/living/carbon/alien/adult/banda/final_caste/crusher
	name = "alien crusher"
	previous_evolution = /mob/living/carbon/alien/adult/banda/warrior
	desc = "Тяжёлый ксеноморф с бронированным гребнем. Разгоняется по прямой и прорывает оборону противника."
	caste = "crusher"
	inhand_caste = "warrior"
	icon = 'modular_bandastation/xeno_rework/icons/castes/crusher.dmi'
	icon_state = "aliencrusher"
	hud_sprite_height = 40
	health = 350
	maxHealth = 350
	damage_resistance = 35
	melee_damage_lower = 15
	melee_damage_upper = 15
	/// Whether straight-line movement builds momentum.
	var/charge_enabled = TRUE
	/// Consecutive unforced steps in the same cardinal direction.
	var/momentum = 0
	/// Direction and timestamp used to discard interrupted runs.
	var/charge_direction = NONE
	/// Absolute timestamp of the last unforced charge step.
	var/last_charge_step = 0
	/// TGMC charge parameters; native movement applies the same negative slowdown.
	var/speed_per_step = 0.15
	/// Crushing begins after seven consecutive cardinal steps.
	var/steps_for_charge = 7
	/// Maximum speed is reached at fourteen steps.
	var/max_steps_buildup = 14

/mob/living/carbon/alien/adult/banda/final_caste/crusher/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/ysera)

/mob/living/carbon/alien/adult/banda/final_caste/crusher/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/banda/crusher_charge)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/crusher_stomp)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/crusher_toss)
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

/** Same buildup, timing and plasma rules as TGMC; collision damage uses native TG armor. */
/mob/living/carbon/alien/adult/banda/final_caste/crusher/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(forced || old_loc == loc)
		return
	if(!can_build_momentum(movement_dir, old_loc))
		stop_momentum()
		return
	charge_direction = movement_dir
	last_charge_step = world.time
	momentum++
	update_charge_speed()
	if(momentum >= steps_for_charge)
		adjustPlasma(-round(charge_speed()))
		if(momentum % 4 == 0)
			playsound(src, 'sound/effects/bang.ogg', 50, TRUE)
		for(var/mob/living/victim in loc)
			if(!isalien(victim) && victim.stat != DEAD && victim.body_position == LYING_DOWN && !victim.buckled)
				victim.apply_damage(charge_damage(), BRUTE, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, MELEE))
				log_combat(src, victim, "crusher ran over")

/// Living targets take the same capped damage on a direct hit or when run over.
/mob/living/carbon/alien/adult/banda/final_caste/crusher/proc/charge_damage()
	return min(80, 20 + 12 * (momentum - 6))

/mob/living/carbon/alien/adult/banda/final_caste/crusher/proc/charge_speed()
	return min(momentum, max_steps_buildup) * speed_per_step

/mob/living/carbon/alien/adult/banda/final_caste/crusher/proc/can_build_momentum(movement_dir, atom/old_loc)
	return charge_enabled && !HAS_TRAIT(src, TRAIT_PACIFISM) && !resting && !incapacitated && !(HAS_TRAIT(src, TRAIT_IMMOBILIZED)) && isturf(loc) && isturf(old_loc) && !isspaceturf(old_loc) && !isspaceturf(loc) && !pulling && !pulledby && !throwing && (movement_dir in GLOB.cardinals) && movement_dir == dir && (!momentum || movement_dir == charge_direction) && (!momentum || world.time <= last_charge_step + 0.5 SECONDS) && getPlasma() >= speed_per_step * max_steps_buildup

/mob/living/carbon/alien/adult/banda/final_caste/crusher/proc/update_charge_speed()
	if(momentum <= 0)
		remove_movespeed_modifier(/datum/movespeed_modifier/xeno_crusher_charge)
	else
		add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/xeno_crusher_charge, multiplicative_slowdown = -charge_speed())

/mob/living/carbon/alien/adult/banda/final_caste/crusher/proc/stop_momentum()
	momentum = 0
	charge_direction = NONE
	last_charge_step = 0
	update_charge_speed()

/mob/living/carbon/alien/adult/banda/final_caste/crusher/proc/lose_momentum(steps)
	momentum = max(0, momentum - steps)
	update_charge_speed()

/mob/living/carbon/alien/adult/banda/final_caste/crusher/Bump(atom/obstacle)
	if(momentum < steps_for_charge || !can_build_momentum(dir, loc))
		stop_momentum()
		return ..()
	var/impact_speed = charge_speed()
	if(isliving(obstacle))
		var/mob/living/victim = obstacle
		if(!isalien(victim) && victim.stat != DEAD)
			victim.buckled?.unbuckle_mob(victim)
			victim.apply_damage(charge_damage(), BRUTE, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, MELEE))
			if(QDELETED(victim))
				return ..()
			victim.Paralyze(impact_speed * 2 SECONDS)
			log_combat(src, victim, "crusher charged")
		if(victim.anchored || victim.mob_size >= mob_size || !knock_aside(victim, impact_speed))
			stop_momentum()
			if(!ishuman(victim))
				Paralyze(0.5 SECONDS, ignore_canstun = TRUE)
	else if(isobj(obstacle))
		var/obj/target = obstacle
		if(target.resistance_flags & INDESTRUCTIBLE)
			stun_on_blocked_charge()
			return ..()
		var/was_anchored = target.anchored
		var/border = target.flags_1 & ON_BORDER_1
		var/front_border = border && target.dir == REVERSE_DIR(dir)
		var/damage_multiplier = !was_anchored ? 20 : border ? (front_border ? 80 : 160) : 240
		target.take_damage(impact_speed * damage_multiplier, BRUTE, MELEE)
		if(was_anchored)
			lose_momentum(front_border ? 3 : border ? 1 : 2)
		if(!QDELETED(target) && target.density && (was_anchored || target.move_resist >= move_force || !knock_aside(target, impact_speed)))
			stun_on_blocked_charge()
	else if(isturf(obstacle))
		if(istype(obstacle, /turf/closed/wall))
			var/turf/closed/wall/wall = obstacle
			wall.xeno_charge_impact(momentum >= max_steps_buildup)
		else
			obstacle.ex_act(momentum >= max_steps_buildup ? EXPLODE_HEAVY : EXPLODE_LIGHT)
		if(!QDELETED(obstacle) && obstacle.density)
			stun_on_blocked_charge()
	return ..()

/mob/living/carbon/alien/adult/banda/final_caste/crusher/proc/stun_on_blocked_charge()
	stop_momentum()
	Paralyze(0.5 SECONDS, ignore_canstun = TRUE)

/mob/living/carbon/alien/adult/banda/final_caste/crusher/proc/knock_aside(atom/movable/target, impact_speed)
	var/side = pick(dir & (NORTH|SOUTH) ? list(EAST, WEST) : list(NORTH, SOUTH))
	var/steps = min(round(impact_speed) + 1, 3)
	var/moved = FALSE
	for(var/index in 1 to steps)
		if(!step(target, side))
			break
		moved = TRUE
	return moved

/datum/movespeed_modifier/xeno_crusher_charge
	variable = TRUE

/** TG walls have no cumulative HP. Remember impacts on this physical wall until native dismantling. */
/turf/closed/wall
	/// Reinforced walls need four ordinary charge impacts, or two maximum-speed ones.
	var/xeno_charge_impacts = 0

/turf/closed/wall/proc/xeno_charge_impact(maximum_speed)
	xeno_charge_impacts += maximum_speed ? 2 : 1
	add_dent(WALL_DENT_HIT)
	playsound(src, 'sound/effects/bang.ogg', 80, TRUE)
	if(xeno_charge_impacts >= (istype(src, /turf/closed/wall/r_wall) ? 4 : 2))
		dismantle_wall(TRUE)

/datum/action/cooldown/alien/banda/crusher_charge
	name = "Таранный разбег"
	desc = "Разгонитесь по прямой. Таран начинается с седьмого шага и наносит до 80 урона живой цели. Поворот, захват, отдых или остановка сбрасывают разгон. Столкновение с преградой, которую не удалось пробить или оттолкнуть, оглушает на полсекунды."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/crusher.dmi'
	button_icon_state = "ready_charge"

/datum/action/cooldown/alien/banda/crusher_charge/Grant(mob/grant_to)
	. = ..()
	RegisterSignal(grant_to, COMSIG_ATOM_DIR_CHANGE, PROC_REF(on_charge_turn))
	RegisterSignal(grant_to, COMSIG_LIVING_RESTING, PROC_REF(on_charge_rest))

/datum/action/cooldown/alien/banda/crusher_charge/proc/on_charge_turn(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(old_dir == new_dir)
		return
	var/mob/living/carbon/alien/adult/banda/final_caste/crusher/crusher = owner
	crusher.stop_momentum()

/datum/action/cooldown/alien/banda/crusher_charge/proc/on_charge_rest(datum/source, is_resting)
	SIGNAL_HANDLER
	if(is_resting)
		var/mob/living/carbon/alien/adult/banda/final_caste/crusher/crusher = owner
		crusher.stop_momentum()

/datum/action/cooldown/alien/banda/crusher_charge/Remove(mob/living/remove_from)
	UnregisterSignal(remove_from, list(COMSIG_ATOM_DIR_CHANGE, COMSIG_LIVING_RESTING))
	var/mob/living/carbon/alien/adult/banda/final_caste/crusher/crusher = remove_from
	crusher.stop_momentum()
	return ..()

/datum/action/cooldown/alien/banda/crusher_charge/Activate()
	var/mob/living/carbon/alien/adult/banda/final_caste/crusher/crusher = owner
	crusher.charge_enabled = !crusher.charge_enabled
	crusher.stop_momentum()
	return TRUE

/** Area stomp, stronger against an enemy directly underneath the Crusher. */
/datum/action/cooldown/alien/banda/crusher_stomp
	name = "Сокрушительный топот"
	desc = "С силой обрушивается на землю. Противник прямо под ногами получает 50 урона и паралич на 2,5 секунды. Соседние цели — 20 урона, отбрасывание и паралич на 0,5 секунды."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/crusher.dmi'
	button_icon_state = "stomp"
	plasma_cost = 100
	cooldown_time = 20 SECONDS

/datum/action/cooldown/alien/banda/crusher_stomp/Activate()
	playsound(owner, 'sound/effects/bang.ogg', 70, TRUE)
	owner.do_attack_animation(owner)
	for(var/mob/living/victim in view(1, owner))
		if(isalien(victim) || victim.stat == DEAD)
			continue
		var/same_tile = victim.loc == owner.loc
		victim.apply_damage(same_tile ? 50 : 20, BRUTE)
		victim.Paralyze(same_tile ? 2.5 SECONDS : 0.5 SECONDS)
		if(!same_tile)
			step_away(victim, owner)
	StartCooldown()
	return TRUE

/** Throw an adjacent creature over the crest, or forward in combat mode. */
/datum/action/cooldown/alien/banda/crusher_toss
	name = "Удар гребнем"
	desc = "Мощным ударом гребня отбрасывает соседнюю цель на шесть клеток: в боевом режиме — вперёд, в обычном — за спину. Враг получает 36 урона, союзник — без урона."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/crusher.dmi'
	button_icon_state = "cresttoss"
	plasma_cost = 75
	cooldown_time = 12 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/alien/banda/crusher_toss/Activate(atom/target)
	if(!isliving(target) || !owner.Adjacent(target) || !isturf(owner.loc))
		return FALSE
	var/mob/living/victim = target
	if(victim.anchored || victim.move_resist >= MOVE_FORCE_OVERPOWERING)
		return FALSE
	var/mob/living/carbon/alien/crusher = owner
	var/direction = crusher.combat_mode ? get_dir(owner, victim) : get_dir(victim, owner)
	if(!isalien(victim))
		victim.apply_damage(36, BRUTE)
	victim.throw_at(get_ranged_target_turf(owner, direction, 6), 6, 1, owner)
	owner.do_attack_animation(victim)
	StartCooldown()
	return TRUE
