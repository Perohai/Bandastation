/datum/action/cooldown/alien/banda/ravager_empower
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "empower"
	name = "Усиление (50P)"
	desc = "Первое нажатие даёт щит. Повторное нажатие в течение шести секунд усиливает его за каждого врага рядом."
	var/awaiting_second_activation = FALSE
	var/empower_deadline = 0

/datum/action/cooldown/alien/banda/ravager_empower/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	var/mob/living/carbon/alien/xeno = owner
	return awaiting_second_activation || xeno.getPlasma() >= 50

/datum/action/cooldown/alien/banda/ravager_empower/Activate()
	var/mob/living/carbon/alien/xeno = owner
	if(!awaiting_second_activation)
		if(xeno.getPlasma() < 50)
			return FALSE
		xeno.adjustPlasma(-50)
		xeno.apply_status_effect(/datum/status_effect/xeno_overshield, 50, 15 SECONDS)
		awaiting_second_activation = TRUE
		empower_deadline = world.time + 6 SECONDS
		addtimer(CALLBACK(src, PROC_REF(expire_empower)), 6 SECONDS)
		StartCooldown(0.4 SECONDS)
		return TRUE
	if(world.time > empower_deadline)
		return FALSE
	var/enemies = 0
	for(var/mob/living/enemy in view(3, owner))
		if(isalien(enemy) || enemy.stat == DEAD)
			continue
		if(++enemies >= 5)
			break
	var/datum/status_effect/xeno_overshield/shield = owner.has_status_effect(/datum/status_effect/xeno_overshield)
	xeno.apply_status_effect(/datum/status_effect/xeno_overshield, (shield?.remaining || 0) + enemies * 50, 15 SECONDS)
	if(enemies >= 3)
		xeno.apply_status_effect(/datum/status_effect/xeno_super_empowered)
	awaiting_second_activation = FALSE
	StartCooldown(22 SECONDS)
	return TRUE

/datum/action/cooldown/alien/banda/ravager_empower/proc/expire_empower()
	if(!awaiting_second_activation || !owner)
		return
	awaiting_second_activation = FALSE
	StartCooldown(22 SECONDS)

/datum/action/cooldown/alien/banda/ravager_empower/Remove(mob/living/remove_from)
	awaiting_second_activation = FALSE
	return ..()

/datum/status_effect/xeno_super_empowered
	id = "xeno_super_empowered"
	duration = 5 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	on_remove_on_mob_delete = TRUE
	var/mutable_appearance/aura

/datum/status_effect/xeno_super_empowered/on_apply()
	aura = mutable_appearance('modular_bandastation/xeno_rework/icons/xeno_auras.dmi', "empower")
	RegisterSignal(owner, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(append_aura))
	owner.update_appearance(UPDATE_OVERLAYS)
	return TRUE

/datum/status_effect/xeno_super_empowered/proc/append_aura(datum/source, list/overlays)
	SIGNAL_HANDLER
	overlays += aura

/datum/status_effect/xeno_super_empowered/on_remove()
	UnregisterSignal(owner, COMSIG_ATOM_UPDATE_OVERLAYS)
	owner.update_appearance(UPDATE_OVERLAYS)
	QDEL_NULL(aura)

/datum/action/cooldown/alien/banda/ravager_charge
	name = "Рывок"
	desc = "Рывок на пять клеток. При усилении опрокидывает, рассекает и отбрасывает противника."
	button_icon_state = "ravager_charge"
	plasma_cost = 25
	cooldown_time = 14 SECONDS
	click_to_activate = TRUE
	var/charging = FALSE

/datum/action/cooldown/alien/banda/ravager_charge/Activate(atom/target)
	var/turf/destination = get_turf(target)
	if(charging || !isturf(owner.loc) || !destination || destination == owner.loc || owner.z != destination.z)
		return FALSE
	var/mob/living/carbon/alien/adult/banda/ravager/ravager = owner
	if(!istype(ravager))
		return FALSE
	charging = TRUE
	StartCooldown()
	if(!ravager.throw_at(destination, 5, 2, ravager, spin = FALSE, diagonals_first = TRUE, callback = CALLBACK(src, PROC_REF(finish_charge))))
		finish_charge()
		ResetCooldown()
		return FALSE
	return TRUE

/datum/action/cooldown/alien/banda/ravager_charge/proc/finish_charge()
	charging = FALSE

/datum/action/cooldown/alien/banda/ravager_charge/Remove(mob/living/remove_from)
	finish_charge()
	return ..()

/mob/living/carbon/alien/adult/banda/ravager/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	var/datum/action/cooldown/alien/banda/ravager_charge/charge = locate() in actions
	if(!charge?.charging)
		return ..()
	if(isliving(hit_atom) && !isalien(hit_atom) && !incapacitated)
		var/mob/living/victim = hit_atom
		victim.apply_damage(10, BRUTE, BODY_ZONE_CHEST)
		if(has_status_effect(/datum/status_effect/xeno_super_empowered) && !QDELETED(victim))
			victim.Knockdown(2 SECONDS)
			victim.apply_damage(15, BRUTE, BODY_ZONE_CHEST, sharpness = SHARP_EDGED, wound_bonus = 30)
			victim.throw_at(get_ranged_target_turf(src, get_dir(src, victim), 3), 3, 1, src)
		charge.StartCooldownSelf(max(0, charge.next_use_time - world.time - 4 SECONDS))
	charge.finish_charge()

/datum/action/cooldown/alien/banda/ravager_cut
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "scissor_cut"
	name = "Резкий удар"
	desc = "После предупреждения рассекает линию длиной четыре клетки. При усилении замедляет поражённых врагов."
	plasma_cost = 25
	cooldown_time = 10 SECONDS
	click_to_activate = TRUE
	var/preparing = FALSE

/datum/action/cooldown/alien/banda/ravager_cut/Activate(atom/target)
	var/turf/start = get_turf(owner)
	var/turf/target_turf = get_turf(target)
	if(preparing || !isturf(owner.loc) || !target_turf || start == target_turf || start.z != target_turf.z)
		return FALSE
	var/list/attack_line = list()
	var/direction = get_dir(start, target_turf)
	var/turf/location = start
	for(var/distance in 1 to 4)
		location = get_step(location, direction)
		if(!location || isclosedturf(location))
			break
		attack_line += location
		new /obj/effect/temp_visual/smartgun_target/xeno_cut(location)
	preparing = TRUE
	var/ready = do_after(owner, 0.5 SECONDS, target = start)
	preparing = FALSE
	if(!ready || QDELETED(src) || QDELETED(owner) || owner.loc != start || !IsAvailable())
		return FALSE
	for(var/turf/hit_turf as anything in attack_line)
		if(isclosedturf(hit_turf))
			break
		for(var/mob/living/victim in hit_turf)
			if(isalien(victim))
				continue
			victim.apply_damage(25, BRUTE, BODY_ZONE_CHEST, sharpness = SHARP_EDGED)
			if(owner.has_status_effect(/datum/status_effect/xeno_super_empowered) && !QDELETED(victim))
				victim.apply_status_effect(/datum/status_effect/xeno_hamstrung)
	StartCooldown()
	return TRUE

/obj/effect/temp_visual/smartgun_target/xeno_cut
	color = COLOR_RED
	duration = 0.5 SECONDS

/datum/status_effect/xeno_hamstrung
	id = "xeno_hamstrung"
	duration = 3 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	on_remove_on_mob_delete = TRUE

/datum/status_effect/xeno_hamstrung/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/xeno_hamstrung)
	return TRUE

/datum/status_effect/xeno_hamstrung/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/xeno_hamstrung)

/datum/movespeed_modifier/xeno_hamstrung
	multiplicative_slowdown = 2
