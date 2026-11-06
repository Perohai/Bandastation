/// Single TGMC Charge. Fixed destination, four tiles, no homing or triple charge.
/datum/action/cooldown/alien/banda/tgmc/ravager_charge
	name = "Eviscerating Charge"
	desc = "Рывок до 4 клеток. Попадание усиливает удар когтей на 25%, парализует на 2 секунды и отбрасывает жертву."
	button_icon_state = "ravager_charge"
	plasma_cost = 500
	cooldown_time = 20 SECONDS
	unset_after_click = TRUE
	var/charge_range = 4
	var/list/turf/charge_path
	var/list/already_hit
	var/datum/weakref/caster_ref
	var/charge_timer

/datum/action/cooldown/alien/banda/tgmc/ravager_charge/PreActivate(atom/target)
	if(charge_path || get_turf(owner) == get_turf(target) || get_dist(owner, target) > charge_range)
		return FALSE
	return ..()

/datum/action/cooldown/alien/banda/tgmc/ravager_charge/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/ravager/caster = owner
	if(!istype(caster))
		return FALSE
	charge_path = get_line(get_turf(caster), get_turf(target))
	charge_path -= get_turf(caster)
	if(length(charge_path) > charge_range)
		charge_path.Cut(charge_range + 1)
	already_hit = list()
	caster_ref = WEAKREF(caster)
	caster.face_atom(target)
	playsound(caster, 'modular_bandastation/xeno_rework/sound/alien_roar2.ogg', 65, TRUE)
	StartCooldown()
	advance_charge()
	return TRUE

/datum/action/cooldown/alien/banda/tgmc/ravager_charge/proc/advance_charge()
	charge_timer = null
	var/mob/living/carbon/alien/adult/banda/ravager/caster = caster_ref?.resolve()
	if(!caster || caster != owner || caster.stat != BANDA_XENO_AWAKE_STAT || caster.anchored || !isturf(caster.loc) || INCAPACITATED_IGNORING(caster, INCAPABLE_GRAB) || !length(charge_path))
		cleanup_charge()
		return
	var/turf/from = get_turf(caster)
	var/turf/next = charge_path[1]
	charge_path.Cut(1, 2)
	if(!caster.tgmc_clear_step(from, next, TRUE))
		cleanup_charge()
		return
	for(var/obj/structure/table/table in next)
		table.deconstruct(FALSE)
	for(var/mob/living/victim in next)
		if(victim.stat != BANDA_XENO_AWAKE_STAT || isalien(victim) || (victim in already_hit))
			continue
		already_hit += victim
		if(caster.tgmc_melee_hit(victim, 1.25) <= 0)
			continue
		if(iscarbon(victim))
			victim.Paralyze(2 SECONDS)
		var/turf/throw_target = get_ranged_target_turf(victim, get_dir(from, next), rand(1, 3))
		if(throw_target)
			victim.throw_at(throw_target, charge_range, 2, caster)
	// Collision was checked above. Like TGMC's leap, Charge passes living mobs.
	// Move() still gets the first chance; forceMove is only for occupied cells.
	if(!caster.Move(next, get_dir(from, next)))
		if(!(locate(/mob/living) in next) || !caster.tgmc_clear_step(from, next, TRUE))
			cleanup_charge()
			return
		caster.forceMove(next)
	if(length(charge_path))
		charge_timer = addtimer(CALLBACK(src, PROC_REF(advance_charge)), 0.2 SECONDS, TIMER_STOPPABLE)
	else
		cleanup_charge()

/datum/action/cooldown/alien/banda/tgmc/ravager_charge/proc/cleanup_charge()
	if(charge_timer)
		deltimer(charge_timer)
	charge_timer = null
	charge_path = null
	already_hit = null
	caster_ref = null

/datum/action/cooldown/alien/banda/tgmc/ravager_charge/Remove(mob/removed_from)
	cleanup_charge()
	return ..()

/datum/action/cooldown/alien/banda/tgmc/ravager_charge/Destroy()
	cleanup_charge()
	return ..()

/datum/action/cooldown/alien/banda/tgmc/ravage
	name = "Ravage"
	desc = "Удар по трём соседним клеткам перед мордой. Усиленные когти, отбрасывание и секундный паралич."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc_ravager_actions.dmi'
	button_icon_state = "ravage"
	plasma_cost = 200
	cooldown_time = 6 SECONDS

/datum/action/cooldown/alien/banda/tgmc/ravage/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/ravager/caster = owner
	if(!istype(caster))
		return FALSE
	if(target != caster)
		caster.face_atom(target)
	var/turf/origin = get_turf(caster)
	var/list/directions = list(caster.dir, turn(caster.dir, 45), turn(caster.dir, -45))
	for(var/direction in directions)
		var/turf/location = get_step(origin, direction)
		if(!location || location.density)
			continue
		if(!caster.tgmc_clear_step(origin, location))
			// A door can be struck; a victim behind it cannot.
			for(var/obj/obstacle in location)
				if(obstacle.density && !istype(obstacle, /obj/structure/alien) && (istype(obstacle, /obj/structure) || istype(obstacle, /obj/machinery/door)))
					obstacle.take_damage(caster.melee_damage_upper, BRUTE, MELEE, armour_penetration = caster.tgmc_melee_penetration)
			continue
		new /obj/effect/temp_visual/dir_setting/tailsweep/ravager(location, direction)
		for(var/mob/living/victim in location)
			if(caster.tgmc_melee_hit(victim, 1.25) <= 0)
				continue
			victim.Paralyze(1 SECONDS)
			var/turf/throw_target = get_step(location, get_dir(caster, victim))
			if(throw_target)
				victim.throw_at(throw_target, 1, 2, caster)
		for(var/obj/structure/structure in location)
			if(!istype(structure, /obj/structure/alien))
				structure.take_damage(caster.melee_damage_upper, BRUTE, MELEE, armour_penetration = caster.tgmc_melee_penetration)
	playsound(caster, 'modular_bandastation/xeno_rework/sound/alien_tail_swipe.ogg', 60, TRUE)
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/banda/tgmc/endure
	name = "Endure"
	desc = "На 10 секунд позволяет сражаться ниже нулевого здоровья и защищает от замедления и пошатывания. Порог смерти сохраняется; взрыв в упор остаётся смертельным."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc_ravager_actions.dmi'
	button_icon_state = "ignore_pain"
	click_to_activate = FALSE
	plasma_cost = 200
	cooldown_time = 60 SECONDS
	// TGMC permits activation in critical and while staggered, but not while dead.
	check_flags = NONE

/datum/action/cooldown/alien/banda/tgmc/endure/IsAvailable(feedback = FALSE)
	. = ..()
	var/mob/living/caster = owner
	if(!. || caster.stat == DEAD || caster.has_status_effect(/datum/status_effect/xeno_tgmc_endure))
		return FALSE
	return TRUE

/datum/action/cooldown/alien/banda/tgmc/endure/Activate(atom/target)
	var/mob/living/caster = owner
	caster.apply_status_effect(/datum/status_effect/xeno_tgmc_endure)
	StartCooldown()
	return TRUE

/datum/status_effect/xeno_tgmc_endure
	id = "xeno_tgmc_endure"
	alert_type = null
	duration = 10 SECONDS
	tick_interval = 1 SECONDS
	var/saved_dead_threshold
	var/warning_sent = FALSE
	var/empowered = FALSE

/datum/status_effect/xeno_tgmc_endure/on_apply()
	var/mob/living/carbon/alien/adult/banda/ravager/caster = owner
	if(!istype(caster))
		return FALSE
	saved_dead_threshold = caster.tgmc_get_dead_threshold()
	caster.set_tgmc_armor(id, new /datum/armor/xeno_tgmc_endure)
	owner.add_traits(list(TRAIT_NOSOFTCRIT, TRAIT_NOHARDCRIT, TRAIT_NO_STAGGER), XENO_TGMC_ENDURE_SOURCE)
	owner.ignore_slowdown(XENO_TGMC_ENDURE_SOURCE)
	owner.remove_status_effect(/datum/status_effect/staggered)
	owner.add_filter(id, 4, outline_filter(1, COLOR_PURPLE))
	owner.update_stat()
	owner.balloon_alert(owner, "выдержка активна")
	return TRUE

/datum/status_effect/xeno_tgmc_endure/tick(seconds_between_ticks)
	if(owner.stat == DEAD)
		qdel(src)
		return
	if(!warning_sent && duration <= 3 SECONDS)
		warning_sent = TRUE
		to_chat(owner, span_userdanger("Выдержка заканчивается через 3 секунды!"))

/datum/status_effect/xeno_tgmc_endure/proc/empower()
	if(empowered)
		return
	empowered = TRUE
	var/mob/living/carbon/alien/adult/banda/ravager/caster = owner
	caster.tgmc_set_dead_threshold(min(saved_dead_threshold, -150))

/datum/status_effect/xeno_tgmc_endure/proc/extend_from_slash()
	duration = min(10 SECONDS, duration + 2 SECONDS)
	if(duration > 3 SECONDS)
		warning_sent = FALSE

/datum/status_effect/xeno_tgmc_endure/on_remove()
	if(isnull(saved_dead_threshold))
		return
	var/mob/living/carbon/alien/adult/banda/ravager/caster = owner
	caster.tgmc_set_dead_threshold(saved_dead_threshold)
	owner.remove_traits(list(TRAIT_NOSOFTCRIT, TRAIT_NOHARDCRIT, TRAIT_NO_STAGGER), XENO_TGMC_ENDURE_SOURCE)
	owner.unignore_slowdown(XENO_TGMC_ENDURE_SOURCE)
	caster.remove_tgmc_armor(id)
	owner.remove_filter(id)
	// TGMC's base Endure leaves a surviving ravager at its normal crit boundary.
	if(owner.stat != DEAD && owner.health <= owner.crit_threshold)
		caster.tgmc_heal(owner.crit_threshold - owner.health + 1)
	owner.update_stat()

/datum/action/cooldown/alien/banda/tgmc/rage
	name = "Rage"
	desc = "Доступна при здоровье не выше 50%. На 10 секунд усиливает когти и скорость, даёт временную плазму и защиту от контроля. При здоровье 0 и ниже сбрасывает Charge/Ravage; удары лечат и продлевают Endure."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc_ravager_actions.dmi'
	button_icon_state = "rage"
	click_to_activate = FALSE
	plasma_cost = 0
	cooldown_time = 60 SECONDS

/datum/action/cooldown/alien/banda/tgmc/rage/IsAvailable(feedback = FALSE)
	. = ..()
	var/mob/living/caster = owner
	if(!. || caster.health > caster.maxHealth * 0.5 || caster.has_status_effect(/datum/status_effect/xeno_tgmc_rage))
		return FALSE
	return TRUE

/datum/action/cooldown/alien/banda/tgmc/rage/Activate(atom/target)
	var/mob/living/caster = owner
	caster.apply_status_effect(/datum/status_effect/xeno_tgmc_rage)
	StartCooldown()
	return TRUE

/datum/movespeed_modifier/xeno_tgmc_rage
	multiplicative_slowdown = -0.25
	variable = TRUE

/datum/status_effect/xeno_tgmc_rage
	id = "xeno_tgmc_rage"
	alert_type = null
	duration = 10 SECONDS
	tick_interval = 1 SECONDS
	var/power = 0
	var/temporary_plasma = 0
	var/melee_lower_bonus = 0
	var/melee_upper_bonus = 0
	var/warning_sent = FALSE

/datum/status_effect/xeno_tgmc_rage/on_apply()
	if(!istype(owner, /mob/living/carbon/alien/adult/banda/ravager))
		return FALSE
	var/mob/living/carbon/alien/adult/banda/ravager/caster = owner
	power = min(0.5, (1 - caster.health / caster.maxHealth) * 0.5)
	melee_lower_bonus = caster.melee_damage_lower * power
	melee_upper_bonus = caster.melee_damage_upper * power
	caster.melee_damage_lower += melee_lower_bonus
	caster.melee_damage_upper += melee_upper_bonus
	temporary_plasma = min(caster.get_max_plasma() - caster.getPlasma(), caster.get_max_plasma() * power)
	caster.adjustPlasma(temporary_plasma)
	var/datum/movespeed_modifier/xeno_tgmc_rage/speed = new
	speed.multiplicative_slowdown = -0.5 * power
	caster.add_movespeed_modifier(speed)
	caster.add_traits(list(TRAIT_STUNIMMUNE, TRAIT_NO_STAGGER), XENO_TGMC_RAGE_SOURCE)
	caster.ignore_slowdown(XENO_TGMC_RAGE_SOURCE)
	caster.add_filter(id, 5, outline_filter(1.5, COLOR_RED))
	if(power >= 0.5)
		for(var/datum/action/cooldown/alien/banda/tgmc/ability in caster.actions)
			if(istype(ability, /datum/action/cooldown/alien/banda/tgmc/ravager_charge) || istype(ability, /datum/action/cooldown/alien/banda/tgmc/ravage))
				ability.ResetCooldown()
		var/datum/status_effect/xeno_tgmc_endure/endure = caster.has_status_effect(/datum/status_effect/xeno_tgmc_endure)
		endure?.empower()
	playsound(caster, 'modular_bandastation/xeno_rework/sound/alien_roar1.ogg', 70, TRUE)
	return TRUE

/datum/status_effect/xeno_tgmc_rage/tick(seconds_between_ticks)
	if(owner.stat == DEAD)
		qdel(src)
		return
	if(!warning_sent && duration <= 3 SECONDS)
		warning_sent = TRUE
		to_chat(owner, span_userdanger("Ярость заканчивается через 3 секунды!"))

/datum/status_effect/xeno_tgmc_rage/on_remove()
	var/mob/living/carbon/alien/adult/banda/ravager/caster = owner
	if(!istype(caster))
		return
	caster.melee_damage_lower -= melee_lower_bonus
	caster.melee_damage_upper -= melee_upper_bonus
	caster.adjustPlasma(-temporary_plasma)
	caster.remove_movespeed_modifier(/datum/movespeed_modifier/xeno_tgmc_rage)
	caster.remove_traits(list(TRAIT_STUNIMMUNE, TRAIT_NO_STAGGER), XENO_TGMC_RAGE_SOURCE)
	caster.unignore_slowdown(XENO_TGMC_RAGE_SOURCE)
	caster.remove_filter(id)

/mob/living/carbon/alien/adult/banda/ravager/tgmc_on_slash(mob/living/victim, damage)
	adjustPlasma(damage * 1.5)
	var/datum/status_effect/xeno_tgmc_rage/rage = has_status_effect(/datum/status_effect/xeno_tgmc_rage)
	if(rage?.power >= 0.5)
		tgmc_heal(damage * rage.power)
		var/datum/status_effect/xeno_tgmc_endure/endure = has_status_effect(/datum/status_effect/xeno_tgmc_endure)
		endure?.extend_from_slash()

/mob/living/carbon/alien/adult/banda/ravager/proc/tgmc_on_damage(datum/source, damage, damagetype)
	SIGNAL_HANDLER
	if(damage > 0 && stat != DEAD && (damagetype == BRUTE || damagetype == BURN))
		adjustPlasma(damage * 0.5)

/mob/living/carbon/alien/adult/banda/ravager/fire_act(exposed_temperature, exposed_volume)
	. = ..()
	if(stat != DEAD && world.time >= tgmc_next_fire_fury)
		tgmc_next_fire_fury = world.time + 1 SECONDS
		adjustPlasma(50)

/mob/living/carbon/alien/adult/banda/ravager/Destroy()
	UnregisterSignal(src, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	return ..()

/// TG alien explosions do not consult bomb armor. This scoped implementation
/// makes Ravager's 10 base / +20 Endure bomb armor effective for heavy/light hits.
/mob/living/carbon/alien/adult/banda/ravager/ex_act(severity, target, origin)
	if(severity == EXPLODE_DEVASTATE)
		return ..()
	if(HAS_TRAIT(src, TRAIT_GODMODE))
		return FALSE
	var/health_before = health
	var/modifier = max(0, 1 - getarmor(null, BOMB) / 100)
	switch(severity)
		if(EXPLODE_HEAVY)
			take_overall_damage(60 * modifier, 60 * modifier)
			if(prob(50) && !has_status_effect(/datum/status_effect/xeno_tgmc_endure))
				Unconscious(2 SECONDS)
			sound_damage(30, 240 SECONDS)
		if(EXPLODE_LIGHT)
			take_overall_damage(30 * modifier, 0)
	if(stat != DEAD)
		adjustPlasma(max(0, health_before - health) * 0.5)
	return TRUE
