/** Первое нажатие даёт щит. Повторное нажатие в течение шести секунд усиливает его за каждого врага рядом. */
/datum/action/cooldown/alien/banda/ravager_empower
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "empower"
	name = "Усиление (50P)"
	desc = "Первое нажатие создаёт защитный барьер. Повторное нажатие в течение шести секунд добавляет по 40 прочности барьера за врага поблизости, до пяти врагов."
	/// Whether the Ravager can amplify its initial shield.
	var/awaiting_second_activation = FALSE
	/// Absolute expiry timestamp of the second-activation window.
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
		xeno.apply_status_effect(/datum/status_effect/xeno_overshield/ravager, 50, 15 SECONDS)
		playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_roar1.ogg', 65, TRUE)
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
		enemies++
		if(enemies >= 5)
			break
	var/datum/status_effect/xeno_overshield/shield = owner.has_status_effect(/datum/status_effect/xeno_overshield)
	xeno.apply_status_effect(/datum/status_effect/xeno_overshield/ravager, (shield?.remaining || 0) + enemies * 40, 15 SECONDS)
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_roar2.ogg', 75, TRUE)
	if(enemies >= 3)
		xeno.apply_status_effect(/datum/status_effect/xeno_super_empowered)
	awaiting_second_activation = FALSE
	StartCooldown(22 SECONDS)
	return TRUE

/** Close the Ravager shield amplification window. */
/datum/action/cooldown/alien/banda/ravager_empower/proc/expire_empower()
	if(!awaiting_second_activation || !owner)
		return
	awaiting_second_activation = FALSE
	StartCooldown(22 SECONDS)

/datum/action/cooldown/alien/banda/ravager_empower/Remove(mob/living/remove_from)
	awaiting_second_activation = FALSE
	return ..()

/** Temporary empowered state for the Ravager charge and cleave. */
/datum/status_effect/xeno_super_empowered
	parent_type = /datum/status_effect/xeno_aura
	id = "xeno_super_empowered"
	aura_color = "#702b2b"
	duration = 5 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	on_remove_on_mob_delete = TRUE

/** Рывок на пять клеток. При усилении опрокидывает, рассекает и отбрасывает противника. */
/datum/action/cooldown/alien/banda/ravager_charge
	name = "Рывок"
	desc = "Бросается вперёд на пять клеток. В усиленном состоянии сбивает врага с ног, рассекает и отбрасывает."
	button_icon_state = "ravager_charge"
	plasma_cost = 25
	cooldown_time = 14 SECONDS
	click_to_activate = TRUE
	/// Whether this action currently owns a charge throw.
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
	playsound(owner, 'modular_bandastation/xeno_rework/sound/pounce.ogg', 60, TRUE)
	return TRUE

/** Release the charge state after its thrown movement ends. */
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
		playsound(victim, 'sound/items/weapons/punch1.ogg', 65, TRUE)
		victim.apply_damage(10, BRUTE, BODY_ZONE_CHEST)
		if(has_status_effect(/datum/status_effect/xeno_super_empowered) && !QDELETED(victim))
			victim.Knockdown(2 SECONDS)
			victim.apply_damage(15, BRUTE, BODY_ZONE_CHEST, sharpness = SHARP_EDGED, wound_bonus = 30)
			victim.throw_at(get_ranged_target_turf(src, get_dir(src, victim), 3), 3, 1, src)
		charge.StartCooldownSelf(max(0, charge.next_use_time - world.time - 4 SECONDS))
	charge.finish_charge()

/** После предупреждения рассекает линию длиной четыре клетки. При усилении замедляет поражённых врагов. */
/datum/action/cooldown/alien/banda/ravager_cut
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "scissor_cut"
	name = "Стремительный удар"
	desc = "После подготовки рассекает линию длиной четыре клетки. Движение прерывает удар, но перезарядка всё равно начинается. При усилении замедляет поражённых врагов."
	plasma_cost = 25
	cooldown_time = 10 SECONDS
	click_to_activate = TRUE
	/// Guards overlapping channelled activations.
	var/preparing = FALSE
	/// Remembers a deselection even if the action is reselected before the windup ends.
	var/cut_cancelled = FALSE

/datum/action/cooldown/alien/banda/ravager_cut/Activate(atom/target)
	var/mob/living/attacker = owner
	var/turf/start = attacker?.loc
	var/turf/target_turf = get_turf(target)
	if(preparing || !IsAvailable() || !isturf(start) || !target_turf || start == target_turf || start.z != target_turf.z)
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
	cut_cancelled = FALSE
	playsound(attacker, 'sound/effects/magic/tail_swing.ogg', 55, TRUE)
	var/ready = do_after(attacker, 0.5 SECONDS, target = start, extra_checks = CALLBACK(src, PROC_REF(can_finish_cut), attacker, start))
	preparing = FALSE
	if(QDELETED(src) || QDELETED(attacker) || owner != attacker)
		return FALSE
	var/finished = ready && can_finish_cut(attacker, start)
	StartCooldown()
	if(!finished)
		return FALSE
	playsound(attacker, 'modular_bandastation/xeno_rework/sound/bloodyslice.ogg', 70, TRUE)
	attacker.do_attack_animation(target_turf, ATTACK_EFFECT_SLASH)
	for(var/turf/hit_turf as anything in attack_line)
		if(isclosedturf(hit_turf))
			break
		for(var/mob/living/victim in hit_turf)
			if(isalien(victim))
				continue
			victim.apply_damage(30, BRUTE, BODY_ZONE_CHEST, sharpness = SHARP_EDGED)
			if(attacker.has_status_effect(/datum/status_effect/xeno_super_empowered) && !QDELETED(victim))
				victim.apply_status_effect(/datum/status_effect/xeno_hamstrung)
	return TRUE

/// Recheck the original caster and selection throughout the windup.
/datum/action/cooldown/alien/banda/ravager_cut/proc/can_finish_cut(mob/living/attacker, turf/start)
	return !cut_cancelled && !QDELETED(attacker) && owner == attacker && attacker.loc == start && IsAvailable()

/datum/action/cooldown/alien/banda/ravager_cut/unset_click_ability(mob/on_who, refund_cooldown = TRUE)
	if(preparing && on_who == owner)
		cut_cancelled = TRUE
	return ..()

/** Brief visible warning for the Ravager line cleave. */
/obj/effect/temp_visual/smartgun_target/xeno_cut
	color = COLOR_RED
	duration = 0.5 SECONDS

/** Temporary movement penalty applied by an empowered cleave. */
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

/** Movement modifier owned by the Ravager hamstring status. */
/datum/movespeed_modifier/xeno_hamstrung
	multiplicative_slowdown = 2
