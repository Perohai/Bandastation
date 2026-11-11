/datum/action/cooldown/alien/select_resin_structure
	name = "Select Resin Structure"
	desc = "Choose the type of resin structure to build."
	button_icon = 'icons/mob/actions/actions_xeno.dmi'
	button_icon_state = "alien_resin"
	plasma_cost = 0
	cooldown_time = 0 SECONDS
	var/static/list/structures = list(
		"resin wall" = /obj/structure/alien/resin/wall,
		"resin membrane" = /obj/structure/alien/resin/membrane,
		"resin nest" = /obj/structure/bed/nest,
		"resin door" = /obj/structure/alien/resin/door,
	)

/datum/action/cooldown/alien/select_resin_structure/Activate(atom/target)
	var/choice = tgui_input_list(owner, "Select a shape to build", "Resin building", structures)
	if(isnull(choice) || QDELETED(src) || QDELETED(owner) || !IsAvailable())
		return FALSE

	var/obj/structure/choice_path = structures[choice]
	if(!ispath(choice_path))
		return FALSE

	var/mob/living/carbon/alien/alien_owner = owner
	alien_owner.selected_resin_structure = choice_path
	to_chat(owner, span_noticealien("You prepare to build a [choice]."))
	return TRUE

/datum/action/cooldown/alien/select_resin_structure/IsAvailable(feedback = FALSE)
	return isalien(owner) && ..()

/datum/action/cooldown/alien/build_resin_structure
	name = "Build Resin Structure"
	desc = "Build the selected resin structure on nearby xenomorph weeds."
	button_icon_state = "alien_resin"
	plasma_cost = 55
	click_to_activate = TRUE
	unset_after_click = FALSE
	var/build_time = 3 SECONDS
	var/static/list/structure_types = list(
		/obj/structure/alien/resin/wall,
		/obj/structure/alien/resin/membrane,
		/obj/structure/bed/nest,
		/obj/structure/alien/resin/door,
	)

/// Used both before construction and after the do_after, since weeds and blockers can change.
/datum/action/cooldown/alien/build_resin_structure/proc/can_build(turf/location, structure_type)
	if(QDELETED(owner) || !isalien(owner) || !isturf(owner.loc) || !isopenturf(location) || isspaceturf(location))
		return FALSE
	if(!(structure_type in structure_types) || get_dist(owner, location) > 1 || owner.z != location.z)
		return FALSE
	if(!(locate(/obj/structure/alien/weeds) in location))
		return FALSE
	for(var/blocker_type in structure_types)
		if(locate(blocker_type) in location)
			return FALSE
	return TRUE

/datum/action/cooldown/alien/build_resin_structure/Activate(atom/target)
	if(!IsAvailable())
		return FALSE
	var/mob/living/carbon/alien/alien_owner = owner
	var/structure_type = alien_owner.selected_resin_structure
	var/turf/location = get_turf(target)
	if(!IsAvailable() || !can_build(location, structure_type))
		return FALSE
	if(!do_after(owner, build_time, target = location, extra_checks = CALLBACK(src, PROC_REF(can_build), location, structure_type)))
		return FALSE
	if(QDELETED(src) || QDELETED(owner) || !IsAvailable() || !can_build(location, structure_type))
		return FALSE
	new structure_type(location)
	// The alien action's PreActivate pays plasma once Activate succeeds.
	return TRUE

/datum/action/cooldown/alien/build_resin_structure/IsAvailable(feedback = FALSE)
	return isalien(owner) && ..()

// MARK: QUEEN

/datum/action/cooldown/alien/banda/queen_screech
	name = "Deafening Screech"
	desc = "Издаёт оглушительный визг, который, вероятно, ненадолго выведет из строя всех слышащих существ вокруг. Перезарядка 3 минуты."
	button_icon_state = "screech"
	cooldown_time = 3 MINUTES
	plasma_cost = 250

/datum/action/cooldown/alien/banda/queen_screech/Activate()
	. = ..()
	var/mob/living/carbon/alien/adult/banda/queenie = owner
	playsound(queenie, 'modular_bandastation/xeno_rework/sound/alien_queen_screech.ogg', 70, FALSE, 8, 0.9)
	queenie.create_shriekwave()
	shake_camera(owner, 2, 2)

	for(var/mob/living/screech_target in get_hearers_in_view(7, get_turf(queenie)))
		if(isalien(screech_target) || screech_target.get_ear_protection() >= EAR_PROTECTION_NORMAL)
			continue
		screech_target.soundbang_act(intensity = SOUNDBANG_NORMAL, stun_pwr = 1 SECONDS, damage_pwr = 5, deafen_pwr = 3 SECONDS)
		shake_camera(screech_target, 4, 3)
		to_chat(screech_target, span_red("[queenie] lets out a deafening screech!"))

	StartCooldown()
	return TRUE

// MARK: DEFENDER

/datum/movespeed_modifier/defender_fortify
	multiplicative_slowdown = 6

/datum/action/cooldown/alien/banda/defender_shared
	button_icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'

/datum/action/cooldown/alien/banda/defender_shared/proc/get_defender_owner()
	var/mob/living/carbon/alien/adult/banda/defender/D = owner
	if(!istype(D))
		return null
	return D

/datum/action/cooldown/alien/banda/defender_fortify
	button_icon = 'modular_bandastation/xeno_rework/icons/combat_actions.dmi'
	button_icon_state = "fortify"
	parent_type = /datum/action/cooldown/alien/banda/defender_shared
	name = "Fortify"
	desc = "Занять укреплённую позицию: сильно замедлиться, но получить защиту от дальнего урона и взрывов."
	cooldown_time = 5 SECONDS
	can_be_used_always = TRUE

/datum/action/cooldown/alien/banda/defender_fortify/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/defender/D = get_defender_owner()
	if(!D)
		return FALSE

	cooldown_time = D.defender_fortify_cooldown

	if(D.fortified)
		D.exit_fortify()
	else
		D.enter_fortify()

	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/banda/defender_tail_sweep
	parent_type = /datum/action/cooldown/alien/banda/defender_shared
	name = "Tail Sweep"
	desc = "Круговой удар хвостом, отбрасывающий и опрокидывающий соседние цели."
	button_icon_state = "crush_tail"
	plasma_cost = 10
	cooldown_time = 10 SECONDS

/datum/action/cooldown/alien/banda/defender_tail_sweep/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/defender/D = get_defender_owner()
	if(!D)
		return FALSE

	plasma_cost = D.defender_tail_sweep_plasma_cost
	cooldown_time = D.defender_tail_sweep_cooldown

	D.visible_message(
		span_warning("[D] sweeps its tail in a brutal circle!"),
		span_warning("Мы сокрушающе взмахиваем хвостом вокруг себя!"),
	)
	playsound(D, 'sound/effects/clang.ogg', 70, TRUE, 8, 0.9)
	D.spin(4, 1)

	for(var/mob/living/L in orange(D.defender_tail_sweep_radius, D))
		if(L == D)
			continue
		if(isalien(L))
			continue
		if(L.stat == DEAD)
			continue
		if(!D.Adjacent(L))
			continue

		var/turf/throw_target = get_ranged_target_turf(D, get_dir(D, L), D.defender_tail_sweep_throw_range)
		if(!throw_target)
			throw_target = get_step_away(L, D)

		L.apply_damage(D.defender_tail_sweep_brute, BRUTE, BODY_ZONE_CHEST)
		L.Knockdown(D.defender_tail_sweep_knockdown)
		L.throw_at(throw_target, D.defender_tail_sweep_throw_range, D.defender_tail_sweep_throw_speed, D)
		shake_camera(L, 2, 1)
		to_chat(L, span_userdanger("Хвост [D] обрушивается на вас, отбрасывая назад!"))

	for(var/obj/item/I in orange(D.defender_tail_sweep_radius, D))
		if(I.anchored)
			continue
		if(I.w_class > D.defender_tail_sweep_small_item_weight_class)
			continue

		var/turf/item_throw_target = get_ranged_target_turf(D, get_dir(D, I), D.defender_tail_sweep_throw_range)
		if(item_throw_target)
			I.throw_at(item_throw_target, D.defender_tail_sweep_throw_range, D.defender_tail_sweep_throw_speed, D)

	if(D.fortified)
		D.exit_fortify(TRUE)

	StartCooldown()
	return TRUE

// MARK: WARRIOR

/datum/movespeed_modifier/warrior_agility
	multiplicative_slowdown = -0.8

/datum/movespeed_modifier/warrior_drag
	multiplicative_slowdown = 0.8


/datum/action/cooldown/alien/banda/warrior_shared
	button_icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'

/datum/action/cooldown/alien/banda/warrior_shared/proc/get_warrior_owner()
	var/mob/living/carbon/alien/adult/banda/warrior/W = owner
	if(!istype(W))
		return null
	return W

/datum/action/cooldown/alien/banda/warrior_shared/proc/prepare_warrior_ability()
	var/mob/living/carbon/alien/adult/banda/warrior/W = get_warrior_owner()
	if(!W)
		return null
	W.exit_agility()
	return W


// ----------------------------------------
// Agility
// ----------------------------------------

/datum/action/cooldown/alien/banda/warrior_agility
	name = "Agility"
	desc = "Переход на четвереньки для более быстрого передвижения. Использование любой способности выводит из режима ловкости."
	button_icon_state = "the_speed_is_alot"
	cooldown_time = 0.4 SECONDS
	can_be_used_always = TRUE

/datum/action/cooldown/alien/banda/warrior_agility/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/W = owner
	if(!istype(W))
		return FALSE

	if(W.agility)
		W.exit_agility()
	else
		W.break_warrior_grab(FALSE)
		W.enter_agility()

	StartCooldown()
	return TRUE


// ----------------------------------------
// Lunge
// ----------------------------------------

/datum/action/cooldown/alien/banda/warrior_lunge
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Lunge"
	desc = "Рывок к цели на расстоянии до 4 клеток, сбивая её с ног и хватая."
	button_icon_state = "pounce"
	plasma_cost = 30
	cooldown_time = 20 SECONDS
	click_to_activate = TRUE
	unset_after_click = TRUE

	var/dashing = FALSE
	var/steps_left = 0
	var/mob/living/current_target

/datum/action/cooldown/alien/banda/warrior_lunge/PreActivate(atom/target)
	if(!isliving(target))
		to_chat(owner, span_warning("You can only lunge at living targets!"))
		return FALSE

	var/mob/living/L = target
	if(L == owner)
		return FALSE

	if(L.stat == DEAD)
		to_chat(owner, span_warning("That target is dead!"))
		return FALSE

	var/mob/living/carbon/alien/adult/banda/warrior/W = owner
	if(!istype(W))
		return FALSE

	if(get_dist(W, L) > W.warrior_lunge_range)
		to_chat(W, span_warning("That target is too far away!"))
		return FALSE

	if(!isturf(W.loc))
		to_chat(W, span_warning("You can't lunge from here!"))
		return FALSE

	return ..()

/datum/action/cooldown/alien/banda/warrior_lunge/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/W = prepare_warrior_ability()
	if(!W)
		return FALSE

	if(!isliving(target))
		return FALSE

	var/mob/living/L = target
	if(L.stat == DEAD)
		return FALSE

	if(W.get_warrior_grab_target())
		W.break_warrior_grab(FALSE)

	current_target = L
	steps_left = W.warrior_lunge_range
	dashing = TRUE

	W.visible_message(
		span_danger("[W] lunges toward [L]!"),
		span_alertalien("We lunge at [L]!"),
	)

	StartCooldown()

	if(W.Adjacent(L))
		_finish_lunge(W, L)
		return TRUE

	_dash_step(W)
	return TRUE

/datum/action/cooldown/alien/banda/warrior_lunge/proc/_dash_step(mob/living/carbon/alien/adult/banda/warrior/W)
	if(QDELETED(src) || QDELETED(W) || owner != W || W.incapacitated || !isturf(W.loc) || !dashing)
		_cleanup_lunge()
		return

	if(QDELETED(current_target) || !isliving(current_target) || current_target.stat == DEAD)
		_cleanup_lunge()
		return

	if(steps_left <= 0)
		_cleanup_lunge()
		return

	if(W.Adjacent(current_target))
		_finish_lunge(W, current_target)
		return

	var/turf/current = get_turf(W)
	var/turf/dest = get_turf(current_target)
	if(!isturf(current) || !isturf(dest))
		_cleanup_lunge()
		return

	var/dir_to = get_dir(current, dest)
	if(!dir_to)
		_cleanup_lunge()
		return

	var/moved = step(W, dir_to)
	if(!moved)
		_cleanup_lunge()
		return

	steps_left--
	addtimer(CALLBACK(src, PROC_REF(_dash_step), W), W.warrior_lunge_step_delay)

/datum/action/cooldown/alien/banda/warrior_lunge/proc/_finish_lunge(mob/living/carbon/alien/adult/banda/warrior/W, mob/living/L)
	if(QDELETED(src) || QDELETED(W) || QDELETED(L) || owner != W || W.incapacitated || !isturf(W.loc) || L.stat == DEAD)
		_cleanup_lunge()
		return

	_cleanup_lunge()

	if(!W.Adjacent(L))
		return

	if(!W.start_pulling(L))
		return

	W.lunging = TRUE
	W.add_movespeed_modifier(/datum/movespeed_modifier/warrior_drag)

	if(isalien(L))
		W.visible_message(
			span_notice("[W] grabs [L]!"),
			span_noticealien("We grab [L]."),
		)
		return

	L.drop_all_held_items()

	L.Paralyze(W.warrior_lunge_stun)
	L.Knockdown(W.warrior_lunge_knockdown)

	W.visible_message(
		span_danger("[W] crashes into [L] and seizes [L.p_them()]!"),
		span_alertalien("We slam into [L] and seize them!"),
	)

/datum/action/cooldown/alien/banda/warrior_lunge/proc/_cleanup_lunge()
	dashing = FALSE
	steps_left = 0
	current_target = null

/datum/action/cooldown/alien/banda/warrior_lunge/Destroy()
	_cleanup_lunge()
	return ..()

/datum/action/cooldown/alien/banda/warrior_lunge/Remove(mob/living/remove_from)
	_cleanup_lunge()
	return ..()


// ----------------------------------------
// Throw (grabbed target only)
// ----------------------------------------

/datum/action/cooldown/alien/banda/warrior_throw
	button_icon = 'modular_bandastation/xeno_rework/icons/combat_actions.dmi'
	button_icon_state = "warrior_throw"
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Throw"
	desc = "Бросок захваченного существа на выбранную клетку. Дальше, чем Fling, и с точным выбором точки."
	plasma_cost = 20
	cooldown_time = 20 SECONDS
	shared_cooldown = MOB_SHARED_COOLDOWN_3
	click_to_activate = TRUE
	unset_after_click = TRUE

/datum/action/cooldown/alien/banda/warrior_throw/PreActivate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/W = owner
	if(!istype(W))
		return FALSE

	var/mob/living/grabbed = W.get_warrior_grab_target()
	if(!grabbed)
		to_chat(W, span_warning("You are not grabbing anyone!"))
		return FALSE

	var/turf/T = get_turf(target)
	if(!T)
		return FALSE

	var/range = W.warrior_throw_range
	if(grabbed.mob_size >= MOB_SIZE_LARGE)
		range -= W.warrior_throw_range_large_penalty

	if(get_dist(W, T) > range)
		to_chat(W, span_warning("That tile is too far away!"))
		return FALSE

	return ..()

/datum/action/cooldown/alien/banda/warrior_throw/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/W = prepare_warrior_ability()
	if(!W)
		return FALSE

	var/mob/living/grabbed = W.get_warrior_grab_target()
	if(!grabbed)
		return FALSE

	var/turf/T = get_turf(target)
	if(!T)
		return FALSE

	var/range = W.warrior_throw_range
	if(grabbed.mob_size >= MOB_SIZE_LARGE)
		range -= W.warrior_throw_range_large_penalty

	W.visible_message(
		span_danger("[W] hurls [grabbed] away!"),
		span_alertalien("We hurl [grabbed] away!"),
	)

	W.stop_pulling()
	grabbed.throw_at(T, range, W.warrior_throw_speed, W)
	grabbed.Knockdown(W.warrior_throw_knockdown)

	StartCooldown()
	return TRUE


// ----------------------------------------
// Fling
// ----------------------------------------

/datum/action/cooldown/alien/banda/warrior_fling
	button_icon = 'modular_bandastation/xeno_rework/icons/combat_actions.dmi'
	button_icon_state = "warrior_fling"
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Fling"
	desc = "Отбрасывает соседнюю цель от себя. Короче, чем Throw, но не требует захвата и накладывает дебафф."
	plasma_cost = 20
	cooldown_time = 20 SECONDS
	shared_cooldown = MOB_SHARED_COOLDOWN_3
	click_to_activate = TRUE
	unset_after_click = TRUE

/datum/action/cooldown/alien/banda/warrior_fling/PreActivate(atom/target)
	if(!isliving(target))
		to_chat(owner, span_warning("You can only fling living targets!"))
		return FALSE

	var/mob/living/L = target
	if(L == owner)
		return FALSE
	if(L.stat == DEAD)
		return FALSE
	if(!owner.Adjacent(L))
		to_chat(owner, span_warning("That target must be adjacent!"))
		return FALSE

	return ..()

/datum/action/cooldown/alien/banda/warrior_fling/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/W = prepare_warrior_ability()
	if(!W)
		return FALSE

	if(!isliving(target))
		return FALSE

	var/mob/living/L = target
	if(!W.Adjacent(L) || L.stat == DEAD)
		return FALSE

	var/fling_range = W.warrior_fling_range
	if(L.mob_size >= MOB_SIZE_LARGE)
		fling_range -= W.warrior_fling_range_large_penalty

	var/fling_dir = get_dir(W, L)
	if(!fling_dir)
		return FALSE

	var/turf/target_turf = get_ranged_target_turf(W, fling_dir, fling_range)
	if(!target_turf)
		return FALSE

	L.drop_all_held_items()
	L.Knockdown(W.warrior_fling_knockdown)

	L.apply_status_effect(/datum/status_effect/staggered, W.warrior_fling_stagger SECONDS)


	W.visible_message(
		span_danger("[W] violently flings [L] away!"),
		span_alertalien("We violently fling [L] away!"),
	)

	L.throw_at(target_turf, fling_range, W.warrior_fling_speed, W)

	StartCooldown()
	return TRUE


// ----------------------------------------
// Punch
// ----------------------------------------

/datum/action/cooldown/alien/banda/warrior_punch
	button_icon = 'modular_bandastation/xeno_rework/icons/combat_actions.dmi'
	button_icon_state = "warrior_punch"
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Punch"
	desc = "Удар по цели рядом, наносящий урон выносливости, замедление и пошатывание. Захваченной цели наносит усиленный эффект."
	plasma_cost = 15
	cooldown_time = 10 SECONDS
	click_to_activate = TRUE
	unset_after_click = TRUE

/datum/action/cooldown/alien/banda/warrior_punch/PreActivate(atom/target)
	if(!isliving(target))
		to_chat(owner, span_warning("You can only punch living targets!"))
		return FALSE

	var/mob/living/L = target
	if(L == owner)
		return FALSE
	if(L.stat == DEAD)
		return FALSE
	if(!owner.Adjacent(L))
		to_chat(owner, span_warning("That target must be adjacent!"))
		return FALSE

	return ..()

/datum/action/cooldown/alien/banda/warrior_punch/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/W = prepare_warrior_ability()
	if(!W)
		return FALSE

	if(!isliving(target))
		return FALSE

	var/mob/living/L = target
	if(!W.Adjacent(L) || L.stat == DEAD)
		return FALSE

	var/brute_damage = W.warrior_punch_brute
	var/stamina_damage = W.warrior_punch_stamina
	var/knockdown_time = W.warrior_punch_knockdown
	var/is_grabbed_combo = (W.get_warrior_grab_target() == L)

	if(is_grabbed_combo)
		brute_damage = round(brute_damage * W.warrior_punch_grab_multiplier)
		stamina_damage = round(stamina_damage * W.warrior_punch_grab_multiplier)
		knockdown_time = W.warrior_punch_grab_knockdown
		W.stop_pulling()

	W.visible_message(
		span_danger("[W] smashes [L] with a brutal punch!"),
		span_alertalien("We smash [L] with a brutal punch!"),
	)

	L.apply_damage(brute_damage, BRUTE, BODY_ZONE_CHEST)
	L.apply_damage(stamina_damage, STAMINA)

	if(!QDELETED(L))
		L.apply_status_effect(/datum/status_effect/staggered, is_grabbed_combo ? 4 SECONDS : 2 SECONDS)
		L.Knockdown(knockdown_time)

	StartCooldown()
	return TRUE
// MARK:RUNNER

// Pounce

/datum/action/cooldown/alien/banda/pounce_runner
	name = "Наброситься"
	desc = "Прыжок, сбивающий цель с ног. Щит может отбить атаку."
	button_icon_state = "pounce"
	plasma_cost = 10
	cooldown_time = 13 SECONDS
	click_to_activate = TRUE
	unset_after_click = TRUE
	var/pounce_active = FALSE

/datum/action/cooldown/alien/banda/pounce_runner/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/runner/runner = owner
	var/turf/destination = get_turf(target)
	if(!istype(runner) || pounce_active || !isturf(runner.loc) || !destination || destination.z != runner.z || get_dist(runner, destination) > 7)
		return FALSE
	if(destination == runner.loc || !runner.has_gravity() || !destination.has_gravity())
		return FALSE
	runner.layer = initial(runner.layer)
	pounce_active = TRUE
	ADD_TRAIT(runner, TRAIT_MOVE_FLOATING, REF(src))
	playsound(runner, 'modular_bandastation/xeno_rework/sound/pounce.ogg', 50, TRUE)
	if(!runner.throw_at(destination, 7, 1, runner, spin = FALSE, diagonals_first = TRUE, callback = CALLBACK(src, PROC_REF(finish_pounce))))
		finish_pounce()
		return FALSE
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/banda/pounce_runner/proc/finish_pounce()
	pounce_active = FALSE
	if(owner)
		REMOVE_TRAIT(owner, TRAIT_MOVE_FLOATING, REF(src))

/datum/action/cooldown/alien/banda/pounce_runner/Remove(mob/living/remove_from)
	finish_pounce()
	return ..()

/mob/living/carbon/alien/adult/banda/runner/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	if(!pounce_ability?.pounce_active)
		return ..()
	if(isliving(hit_atom) && !isalien(hit_atom) && !incapacitated)
		var/mob/living/victim = hit_atom
		var/blocked = FALSE
		if(ishuman(victim))
			var/mob/living/carbon/human/human = victim
			blocked = human.check_block(src, 0, name, attack_type = LEAP_ATTACK)
		if(!blocked)
			victim.Knockdown(2 SECONDS)
		Paralyze(0.5 SECONDS)
	pounce_ability.finish_pounce()

// Evade
/datum/action/cooldown/alien/banda/evade
	name = "Уклонение"
	desc = "Окно уклонения от снарядов на 0,6 секунды. Успешное уклонение сбрасывает двухсекундную перезарядку."
	button_icon_state = "evade"
	cooldown_time = 2 SECONDS
	var/evade_active = FALSE
	var/dodged_this_activation = FALSE
	var/window_timer

/datum/action/cooldown/alien/banda/evade/IsAvailable(feedback = FALSE)
	return !evade_active && ..()

/datum/action/cooldown/alien/banda/evade/Activate()
	if(!IsAvailable() || !isturf(owner.loc) || INCAPACITATED_IGNORING(owner, INCAPABLE_GRAB))
		return FALSE
	evade_active = TRUE
	dodged_this_activation = FALSE
	StartCooldown()
	window_timer = addtimer(CALLBACK(src, PROC_REF(end_evade)), 0.6 SECONDS, TIMER_STOPPABLE)
	return TRUE

/datum/action/cooldown/alien/banda/evade/proc/end_evade()
	window_timer = null
	evade_active = FALSE
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/datum/action/cooldown/alien/banda/evade/proc/on_projectile_hit(obj/projectile/hitting_projectile)
	if(!evade_active || QDELETED(owner) || !isturf(owner.loc) || INCAPACITATED_IGNORING(owner, INCAPABLE_GRAB))
		return BULLET_ACT_HIT
	if(!dodged_this_activation)
		dodged_this_activation = TRUE
		owner.visible_message(span_danger("[owner] уклоняется от снаряда!"), span_noticealien("Вы уклоняетесь от снаряда!"))
		playsound(owner, 'modular_bandastation/xeno_rework/sound/spin.ogg', 60, TRUE)
		ResetCooldown()
	return BULLET_ACT_FORCE_PIERCE

/datum/action/cooldown/alien/banda/evade/Remove(mob/living/remove_from)
	deltimer(window_timer)
	window_timer = null
	evade_active = FALSE
	return ..()

// MARK:BASE XENO

/datum/action/cooldown/alien/banda/sleepytime //I don't think this has a mechanical advantage but they have cool resting sprites so...
	name = "Rest"
	desc = "Иногда даже кровожадным чужим нужно немного полежать."
	button_icon_state = "sleepytime"

/datum/action/cooldown/alien/banda/sleepytime/Activate()
	var/mob/living/carbon/sleepytime_mob = owner
	if(!isalien(owner))
		return FALSE
	if(!sleepytime_mob.resting)
		sleepytime_mob.set_resting(new_resting = TRUE, silent = FALSE, instant = TRUE)
		return TRUE
	sleepytime_mob.set_resting(new_resting = FALSE, silent = FALSE, instant = FALSE)
	return TRUE

/datum/action/cooldown/alien/banda/generic_evolve
	name = "Evolve"
	desc = "Позволяет нам эволюционировать в высшую касту нашего типа, если такая ещё не существует."
	button_icon_state = "evolution"

/datum/action/cooldown/alien/banda/generic_evolve/Grant(mob/grant_to)
	. = ..()
	if(!isalien(owner))
		return
	var/mob/living/carbon/alien/target_alien = owner
	plasma_cost = target_alien.get_max_plasma() //This ability should always require that a xeno be at their max plasma capacity to use

/datum/action/cooldown/alien/banda/generic_evolve/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	var/mob/living/carbon/alien/adult/banda/evolver = owner
	if(!istype(evolver) || !evolver.next_evolution || evolver.has_evolved_recently || !isturf(evolver.loc))
		return FALSE
	var/obj/item/organ/alien/hivenode/node = evolver.get_organ_slot(ORGAN_SLOT_XENO_HIVENODE)
	return node && !node.recent_queen_death

/datum/action/cooldown/alien/banda/generic_evolve/Activate()
	if(!IsAvailable())
		return FALSE
	var/mob/living/carbon/alien/adult/banda/evolver = owner
	if(!evolver.can_evolve())
		evolver.balloon_alert(evolver, "высшая каста уже существует")
		return FALSE
	var/evolution_type = evolver.next_evolution
	var/new_xeno = new evolution_type(evolver.loc)
	evolver.alien_evolve(new_xeno)
	return TRUE

/// T3 combat castes share one slot; queens have their own single slot.
/mob/living/carbon/alien/adult/banda/proc/can_evolve()
	if(!ispath(next_evolution, /mob/living/carbon/alien/adult/banda) || !isturf(loc) || has_evolved_recently)
		return FALSE
	var/obj/item/organ/alien/hivenode/node = get_organ_slot(ORGAN_SLOT_XENO_HIVENODE)
	if(!node || node.recent_queen_death)
		return FALSE
	if(next_evolution == /mob/living/carbon/alien/adult/banda/queen)
		for(var/mob/living/carbon/alien/other in GLOB.alive_mob_list)
			if(istype(other, /mob/living/carbon/alien/adult/banda/queen) || istype(other, /mob/living/carbon/alien/adult/royal/queen))
				return FALSE
		return TRUE
	var/mob/living/carbon/alien/adult/banda/evolution_type = next_evolution
	if(initial(evolution_type.evolution_tier) == 3)
		for(var/mob/living/carbon/alien/adult/banda/other in GLOB.alive_mob_list)
			if(other.evolution_tier == 3)
				return FALSE
	return TRUE
