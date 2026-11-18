/** Choose the type of resin structure to build. */
/datum/action/cooldown/alien/select_resin_structure
	name = "Выбрать смоляную постройку"
	desc = "Выберите тип смоляной постройки."
	button_icon = 'icons/mob/actions/actions_xeno.dmi'
	button_icon_state = "alien_resin"
	plasma_cost = 0
	cooldown_time = 0 SECONDS
	/// Player-facing structure choices for resin selection.
	var/static/list/structures = list(
		"Смоляная стена" = /obj/structure/alien/resin/wall,
		"Смоляная мембрана" = /obj/structure/alien/resin/membrane,
		"Смоляное гнездо" = /obj/structure/bed/nest/banda,
		"Смоляная дверь" = /obj/structure/alien/resin/door,
		"кислотная мина" = /obj/structure/alien/acid_mine,
		"кислотная турель" = /obj/structure/alien/acid_turret,
		"укреплённая смоляная стена" = /obj/structure/alien/resin/wall/reinforced,
	)

/datum/action/cooldown/alien/select_resin_structure/Activate(atom/target)
	var/list/choices = structures.Copy()
	for(var/name in structures)
		if(!can_build_hive_structure(owner, structures[name]))
			choices -= name
	var/choice = tgui_input_list(owner, "Выберите, что построить", "Смоляные постройки", choices)
	if(isnull(choice) || QDELETED(src) || QDELETED(owner) || !IsAvailable())
		return FALSE

	var/obj/structure/choice_path = structures[choice]
	if(!ispath(choice_path) || !can_build_hive_structure(owner, choice_path))
		return FALSE

	var/mob/living/carbon/alien/alien_owner = owner
	alien_owner.selected_resin_structure = choice_path
	to_chat(owner, span_noticealien("Вы готовитесь возвести постройку: [choice]."))
	return TRUE

/datum/action/cooldown/alien/select_resin_structure/IsAvailable(feedback = FALSE)
	return isalien(owner) && resin_caste_allowed() && ..()

/** Also guards the native resin action obtained from a transplanted organ. */
/datum/action/cooldown/alien/proc/resin_caste_allowed()
	if(istype(owner, /mob/living/carbon/alien/hivemind))
		var/mob/living/carbon/alien/hivemind/hivemind = owner
		return hivemind.operational() && hivemind.manifested && !hivemind.channeling
	if(istype(owner, /mob/living/carbon/alien/adult/banda))
		return is_hive_resin_builder(owner)
	return TRUE

/datum/action/cooldown/alien/make_structure/resin/IsAvailable(feedback = FALSE)
	return resin_caste_allowed() && ..()

/** Build the selected resin structure on nearby xenomorph weeds. */
/datum/action/cooldown/alien/build_resin_structure
	name = "Возвести смоляную постройку"
	desc = "Возводит выбранную смоляную постройку на ксеноморфной траве поблизости."
	button_icon_state = "alien_resin"
	plasma_cost = 55
	click_to_activate = TRUE
	unset_after_click = FALSE
	/// Uninterrupted construction duration, in deciseconds.
	var/build_time = 3 SECONDS
	/// Native builders are adjacent; the Hivemind reaches four visible tiles.
	var/build_range = 1
	/// Server-side allowlist of resin construction paths.
	var/static/list/structure_types = list(
		/obj/structure/alien/resin/wall,
		/obj/structure/alien/resin/membrane,
		/obj/structure/bed/nest,
		/obj/structure/bed/nest/banda,
		/obj/structure/alien/resin/door,
		/obj/structure/alien/acid_mine,
		/obj/structure/alien/acid_turret,
		/obj/structure/alien/resin/wall/reinforced,
	)

/// Used both before construction and after the do_after, since weeds and blockers can change.
/datum/action/cooldown/alien/build_resin_structure/proc/can_build(turf/location, structure_type)
	if(QDELETED(owner) || !isalien(owner) || !isturf(owner.loc) || !isopenturf(location) || isspaceturf(location))
		return FALSE
	if(!can_build_hive_structure(owner, structure_type) || !(structure_type in structure_types) || get_dist(owner, location) > build_range || owner.z != location.z || !(location in view(build_range, owner)))
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
	var/list/spec = hive_structure_spec(structure_type)
	var/cost = spec ? spec["plasma"] : initial(plasma_cost)
	if(alien_owner.getPlasma() < cost)
		return FALSE
	var/duration = spec ? spec["time"] : build_time
	if(GLOB.xeno_hive?.purchased["construction"] && is_hive_resin_builder(owner))
		duration *= 0.8
	if(!do_after(owner, duration, target = location, extra_checks = CALLBACK(src, PROC_REF(can_build), location, structure_type)))
		return FALSE
	if(QDELETED(src) || QDELETED(alien_owner) || owner != alien_owner || !IsAvailable() || !can_build(location, structure_type))
		return FALSE
	if(alien_owner.getPlasma() < cost)
		return FALSE
	// PreActivate pays the base price. Charge the remainder after final validation.
	alien_owner.adjustPlasma(-(cost - plasma_cost))
	new structure_type(location)
	playsound(location, 'modular_bandastation/xeno_rework/sound/alien_resin_move2.ogg', 50, TRUE)
	// The alien action's PreActivate pays plasma once Activate succeeds.
	return TRUE

/datum/action/cooldown/alien/build_resin_structure/IsAvailable(feedback = FALSE)
	return isalien(owner) && resin_caste_allowed() && ..()

/// Drone and Queen receive the hive's construction upgrades.
/proc/is_hive_resin_builder(mob/user)
	return istype(user, /mob/living/carbon/alien/adult/banda/drone) || istype(user, /mob/living/carbon/alien/adult/banda/queen)

// MARK: QUEEN

/** Издаёт оглушительный визг, который, вероятно, ненадолго выведет из строя всех слышащих существ вокруг. Перезарядка 3 минуты. */
/datum/action/cooldown/alien/banda/queen_screech
	name = "Оглушительный визг"
	desc = "Оглушительный визг на короткое время выводит из строя существ поблизости, способных его услышать. Перезарядка — 3 минуты."
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
		to_chat(screech_target, span_red("[queenie] издаёт оглушительный визг!"))

	StartCooldown()
	return TRUE

// MARK: DEFENDER

/** Movement slowdown while the Defender is fortified. */
/datum/movespeed_modifier/defender_fortify
	multiplicative_slowdown = 6

/** Shared validation and caste-specific values for Defender abilities. */
/datum/action/cooldown/alien/banda/defender_shared
	button_icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'

/** Return the correctly typed, usable Defender owner. */
/datum/action/cooldown/alien/banda/defender_shared/proc/get_defender_owner()
	var/mob/living/carbon/alien/adult/banda/defender/defender = owner
	if(!istype(defender))
		return null
	return defender

/** Занять укреплённую позицию: сильно замедлиться, но получить защиту от дальнего урона и взрывов. */
/datum/action/cooldown/alien/banda/defender_fortify
	button_icon = 'modular_bandastation/xeno_rework/icons/combat_actions.dmi'
	button_icon_state = "fortify"
	parent_type = /datum/action/cooldown/alien/banda/defender_shared
	name = "Оборонительная стойка"
	desc = "Занимает оборонительную стойку. Передвижение сильно замедляется, зато растёт защита от дальнобойных атак и взрывов."
	cooldown_time = 5 SECONDS
	can_be_used_always = TRUE

/datum/action/cooldown/alien/banda/defender_fortify/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/defender/defender = get_defender_owner()
	if(!defender)
		return FALSE

	cooldown_time = defender.defender_fortify_cooldown

	if(defender.fortified)
		defender.exit_fortify()
	else
		defender.enter_fortify()

	StartCooldown()
	return TRUE

/** Круговой удар хвостом, отбрасывающий и опрокидывающий соседние цели. */
/datum/action/cooldown/alien/banda/defender_tail_sweep
	parent_type = /datum/action/cooldown/alien/banda/defender_shared
	name = "Круговой удар хвостом"
	desc = "Взмах хвостом по широкой дуге. Соседних противников отбрасывает и сбивает с ног."
	button_icon_state = "crush_tail"
	plasma_cost = 10
	cooldown_time = 10 SECONDS

/datum/action/cooldown/alien/banda/defender_tail_sweep/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/defender/defender = get_defender_owner()
	if(!defender)
		return FALSE

	plasma_cost = defender.defender_tail_sweep_plasma_cost
	cooldown_time = defender.defender_tail_sweep_cooldown

	defender.visible_message(
		span_warning("[defender] с силой хлещет хвостом вокруг себя!"),
		span_warning("Мы с размаху хлещем хвостом вокруг себя!"),
	)
	playsound(defender, 'modular_bandastation/xeno_rework/sound/alien_tail_swipe.ogg', 70, TRUE)
	defender.spin(4, 1)

	for(var/mob/living/victim in orange(defender.defender_tail_sweep_radius, defender))
		if(victim == defender)
			continue
		if(isalien(victim))
			continue
		if(victim.stat == DEAD)
			continue
		if(!defender.Adjacent(victim))
			continue

		var/turf/throw_target = get_ranged_target_turf(defender, get_dir(defender, victim), defender.defender_tail_sweep_throw_range)
		if(!throw_target)
			throw_target = get_step_away(victim, defender)

		victim.apply_damage(defender.defender_tail_sweep_brute, BRUTE, BODY_ZONE_CHEST)
		victim.Knockdown(defender.defender_tail_sweep_knockdown)
		victim.throw_at(throw_target, defender.defender_tail_sweep_throw_range, defender.defender_tail_sweep_throw_speed, defender)
		shake_camera(victim, 2, 1)
		to_chat(victim, span_userdanger("[defender] хлещет вас хвостом и отбрасывает назад!"))

	for(var/obj/item/item in orange(defender.defender_tail_sweep_radius, defender))
		if(item.anchored)
			continue
		if(item.w_class > defender.defender_tail_sweep_small_item_weight_class)
			continue

		var/turf/item_throw_target = get_ranged_target_turf(defender, get_dir(defender, item), defender.defender_tail_sweep_throw_range)
		if(item_throw_target)
			item.throw_at(item_throw_target, defender.defender_tail_sweep_throw_range, defender.defender_tail_sweep_throw_speed, defender)

	if(defender.fortified)
		defender.exit_fortify(TRUE)

	StartCooldown()
	return TRUE

// MARK: WARRIOR

/** Movement bonus granted by Warrior agility. */
/datum/movespeed_modifier/warrior_agility
	multiplicative_slowdown = -2.16

/** Movement penalty while the Warrior holds a special grab. */
/datum/movespeed_modifier/warrior_drag
	multiplicative_slowdown = 0.8


/** Shared Warrior ability validation and grab coordination. */
/datum/action/cooldown/alien/banda/warrior_shared
	button_icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'

/** Return the correctly typed Warrior owner. */
/datum/action/cooldown/alien/banda/warrior_shared/proc/get_warrior_owner()
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = owner
	if(!istype(warrior))
		return null
	return warrior

/** Validate the Warrior and coordinate mutually exclusive combat abilities. */
/datum/action/cooldown/alien/banda/warrior_shared/proc/prepare_warrior_ability()
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = get_warrior_owner()
	if(!warrior)
		return null
	warrior.exit_agility()
	return warrior


// ----------------------------------------
// Agility
// ----------------------------------------

/** Переход на четвереньки значительно ускоряет передвижение, но увеличивает получаемый урон на 50%. Использование любой способности выводит из режима ловкости. */
/datum/action/cooldown/alien/banda/warrior_agility
	name = "Ловкость"
	desc = "Передвижение на четырёх лапах заметно ускоряется, но входящий урон возрастает на 50%. Применение любой способности отключает режим ловкости."
	button_icon_state = "the_speed_is_alot"
	cooldown_time = 0.4 SECONDS
	can_be_used_always = TRUE

/datum/action/cooldown/alien/banda/warrior_agility/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = owner
	if(!istype(warrior))
		return FALSE

	if(warrior.agility)
		warrior.exit_agility()
	else
		warrior.break_warrior_grab(FALSE)
		warrior.enter_agility()

	StartCooldown()
	return TRUE


// ----------------------------------------
// Lunge
// ----------------------------------------

/** Рывок к цели на расстоянии до 4 клеток, сбивая её с ног и хватая. */
/datum/action/cooldown/alien/banda/warrior_lunge
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Рывок"
	desc = "Бросается на цель в пределах 4 клеток, сбивает с ног и хватает."
	button_icon = 'modular_bandastation/xeno_rework/icons/support_actions.dmi'
	button_icon_state = "pounce"
	plasma_cost = 30
	cooldown_time = 20 SECONDS
	click_to_activate = TRUE
	unset_after_click = TRUE

	/// Whether the action currently owns a lunge.
	var/dashing = FALSE
	/// Remaining lunge movement budget.
	var/steps_left = 0
	/// Current lunge target, cleared on completion and cancellation.
	var/mob/living/current_target

/datum/action/cooldown/alien/banda/warrior_lunge/PreActivate(atom/target)
	if(!isliving(target))
		to_chat(owner, span_warning("Рывок доступен только против живых целей!"))
		return FALSE

	var/mob/living/victim = target
	if(victim == owner)
		return FALSE

	if(victim.stat == DEAD)
		to_chat(owner, span_warning("Цель уже мертва!"))
		return FALSE

	var/mob/living/carbon/alien/adult/banda/warrior/warrior = owner
	if(!istype(warrior))
		return FALSE

	if(get_dist(warrior, victim) > warrior.warrior_lunge_range)
		to_chat(warrior, span_warning("Цель слишком далеко!"))
		return FALSE

	if(!isturf(warrior.loc))
		to_chat(warrior, span_warning("Отсюда нельзя совершить рывок!"))
		return FALSE

	return ..()

/datum/action/cooldown/alien/banda/warrior_lunge/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = prepare_warrior_ability()
	if(!warrior)
		return FALSE

	if(!isliving(target))
		return FALSE

	var/mob/living/victim = target
	if(victim.stat == DEAD)
		return FALSE

	if(warrior.get_warrior_grab_target())
		warrior.break_warrior_grab(FALSE)

	current_target = victim
	steps_left = warrior.warrior_lunge_range
	dashing = TRUE
	playsound(warrior, 'modular_bandastation/xeno_rework/sound/pounce.ogg', 60, TRUE)

	warrior.visible_message(
		span_danger("[warrior] бросается к [victim]!"),
		span_alertalien("Мы бросаемся к [victim]!"),
	)

	StartCooldown()

	if(warrior.Adjacent(victim))
		_finish_lunge(warrior, victim)
		return TRUE

	_dash_step(warrior)
	return TRUE

/** Advance one scheduled lunge step while revalidating its target. */
/datum/action/cooldown/alien/banda/warrior_lunge/proc/_dash_step(mob/living/carbon/alien/adult/banda/warrior/warrior)
	if(QDELETED(src) || QDELETED(warrior) || owner != warrior || warrior.incapacitated || !isturf(warrior.loc) || !dashing)
		_cleanup_lunge()
		return

	if(QDELETED(current_target) || !isliving(current_target) || current_target.stat == DEAD)
		_cleanup_lunge()
		return

	if(steps_left <= 0)
		_cleanup_lunge()
		return

	if(warrior.Adjacent(current_target))
		_finish_lunge(warrior, current_target)
		return

	var/turf/current = get_turf(warrior)
	var/turf/dest = get_turf(current_target)
	if(!isturf(current) || !isturf(dest))
		_cleanup_lunge()
		return

	var/dir_to = get_dir(current, dest)
	if(!dir_to)
		_cleanup_lunge()
		return

	new /obj/effect/temp_visual/decoy/fading/halfsecond(warrior.loc, warrior, 90)
	var/moved = step(warrior, dir_to)
	if(!moved)
		_cleanup_lunge()
		return

	steps_left--
	addtimer(CALLBACK(src, PROC_REF(_dash_step), warrior), warrior.warrior_lunge_step_delay)

/** Finish the lunge and attempt its grab against the current target. */
/datum/action/cooldown/alien/banda/warrior_lunge/proc/_finish_lunge(mob/living/carbon/alien/adult/banda/warrior/warrior, mob/living/victim)
	if(QDELETED(src) || QDELETED(warrior) || QDELETED(victim) || owner != warrior || warrior.incapacitated || !isturf(warrior.loc) || victim.stat == DEAD)
		_cleanup_lunge()
		return

	_cleanup_lunge()

	if(!warrior.Adjacent(victim))
		return

	if(!warrior.start_pulling(victim))
		return

	warrior.lunging = TRUE
	warrior.add_movespeed_modifier(/datum/movespeed_modifier/warrior_drag)
	warrior.do_attack_animation(victim, ATTACK_EFFECT_DISARM)
	playsound(victim, 'sound/items/weapons/thudswoosh.ogg', 60, TRUE)

	if(isalien(victim))
		warrior.visible_message(
			span_notice("[warrior] хватает [victim]!"),
			span_noticealien("Мы хватаем [victim]."),
		)
		return

	victim.drop_all_held_items()

	victim.Paralyze(warrior.warrior_lunge_stun)
	victim.Knockdown(warrior.warrior_lunge_knockdown)

	warrior.visible_message(
		span_danger("[warrior] с размаху врезается в [victim] и хватает [victim.p_them()]!"),
		span_alertalien("Мы с размаху врезаемся в [victim] и хватаем добычу!"),
	)

/** Release the current lunge target and temporary movement state. */
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

/** Бросок захваченного существа на выбранную клетку. Дальше, чем Fling, и с точным выбором точки. */
/datum/action/cooldown/alien/banda/warrior_throw
	button_icon = 'modular_bandastation/xeno_rework/icons/combat_actions.dmi'
	button_icon_state = "warrior_throw"
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Бросить"
	desc = "Бросает схваченную жертву на выбранную клетку. Дальность больше, чем у «Отшвырнуть», а место падения можно указать точно."
	plasma_cost = 20
	cooldown_time = 20 SECONDS
	shared_cooldown = MOB_SHARED_COOLDOWN_3
	click_to_activate = TRUE
	unset_after_click = TRUE

/datum/action/cooldown/alien/banda/warrior_throw/PreActivate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = owner
	if(!istype(warrior))
		return FALSE

	var/mob/living/grabbed = warrior.get_warrior_grab_target()
	if(!grabbed)
		to_chat(warrior, span_warning("Вы никого не держите!"))
		return FALSE

	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return FALSE

	var/range = warrior.warrior_throw_range
	if(grabbed.mob_size >= MOB_SIZE_LARGE)
		range -= warrior.warrior_throw_range_large_penalty

	if(get_dist(warrior, target_turf) > range)
		to_chat(warrior, span_warning("Выбранная клетка находится слишком далеко!"))
		return FALSE

	return ..()

/datum/action/cooldown/alien/banda/warrior_throw/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = prepare_warrior_ability()
	if(!warrior)
		return FALSE

	var/mob/living/grabbed = warrior.get_warrior_grab_target()
	if(!grabbed)
		return FALSE

	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return FALSE

	var/range = warrior.warrior_throw_range
	if(grabbed.mob_size >= MOB_SIZE_LARGE)
		range -= warrior.warrior_throw_range_large_penalty

	warrior.visible_message(
		span_danger("[warrior] швыряет [grabbed] прочь!"),
		span_alertalien("Мы швыряем [grabbed] прочь!"),
	)

	warrior.stop_pulling()
	warrior.do_attack_animation(target_turf, ATTACK_EFFECT_DISARM)
	playsound(warrior, 'sound/effects/magic/tail_swing.ogg', 65, TRUE)
	grabbed.throw_at(target_turf, range, warrior.warrior_throw_speed, warrior)
	grabbed.Knockdown(warrior.warrior_throw_knockdown)

	StartCooldown()
	return TRUE


// ----------------------------------------
// Fling
// ----------------------------------------

/** Отбрасывает соседнюю цель от себя. Короче, чем Throw, но не требует захвата и накладывает дебафф. */
/datum/action/cooldown/alien/banda/warrior_fling
	button_icon = 'modular_bandastation/xeno_rework/icons/combat_actions.dmi'
	button_icon_state = "warrior_fling"
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Отшвырнуть"
	desc = "Отшвыривает соседнюю цель. Дальность меньше, чем у «Бросить», зато захват не нужен. На жертву накладывается ослабление."
	plasma_cost = 20
	cooldown_time = 20 SECONDS
	shared_cooldown = MOB_SHARED_COOLDOWN_3
	click_to_activate = TRUE
	unset_after_click = TRUE

/datum/action/cooldown/alien/banda/warrior_fling/PreActivate(atom/target)
	if(!isliving(target))
		to_chat(owner, span_warning("Отшвыривать можно только живые цели!"))
		return FALSE

	var/mob/living/victim = target
	if(victim == owner)
		return FALSE
	if(victim.stat == DEAD)
		return FALSE
	if(!owner.Adjacent(victim))
		to_chat(owner, span_warning("Цель должна находиться по соседству!"))
		return FALSE

	return ..()

/datum/action/cooldown/alien/banda/warrior_fling/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = prepare_warrior_ability()
	if(!warrior)
		return FALSE

	if(!isliving(target))
		return FALSE

	var/mob/living/victim = target
	if(!warrior.Adjacent(victim) || victim.stat == DEAD)
		return FALSE

	var/fling_range = warrior.warrior_fling_range
	if(victim.mob_size >= MOB_SIZE_LARGE)
		fling_range -= warrior.warrior_fling_range_large_penalty

	var/fling_dir = get_dir(warrior, victim)
	if(!fling_dir)
		return FALSE

	var/turf/target_turf = get_ranged_target_turf(warrior, fling_dir, fling_range)
	if(!target_turf)
		return FALSE

	victim.drop_all_held_items()
	victim.Knockdown(warrior.warrior_fling_knockdown)
	warrior.do_attack_animation(victim, ATTACK_EFFECT_DISARM)
	playsound(warrior, 'sound/items/weapons/thudswoosh.ogg', 65, TRUE)

	victim.apply_status_effect(/datum/status_effect/staggered, warrior.warrior_fling_stagger SECONDS)


	warrior.visible_message(
		span_danger("[warrior] с силой отбрасывает [victim]!"),
		span_alertalien("Мы с силой отбрасываем [victim]!"),
	)

	victim.throw_at(target_turf, fling_range, warrior.warrior_fling_speed, warrior)

	StartCooldown()
	return TRUE


// ----------------------------------------
// Punch
// ----------------------------------------

/** Удар по цели рядом, наносящий урон выносливости, замедление и пошатывание. Захваченной цели наносит усиленный эффект. */
/datum/action/cooldown/alien/banda/warrior_punch
	button_icon = 'modular_bandastation/xeno_rework/icons/combat_actions.dmi'
	button_icon_state = "warrior_punch"
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Сокрушительный удар"
	desc = "Наносит соседней цели удар, истощающий выносливость, замедляющий и вызывающий пошатывание. Схваченная жертва получает усиленный эффект."
	plasma_cost = 15
	cooldown_time = 10 SECONDS
	click_to_activate = TRUE
	unset_after_click = TRUE

/datum/action/cooldown/alien/banda/warrior_punch/PreActivate(atom/target)
	if(!isliving(target))
		to_chat(owner, span_warning("Кулаком можно бить только живые цели!"))
		return FALSE

	var/mob/living/victim = target
	if(victim == owner)
		return FALSE
	if(victim.stat == DEAD)
		return FALSE
	if(!owner.Adjacent(victim))
		to_chat(owner, span_warning("Цель должна находиться по соседству!"))
		return FALSE

	return ..()

/datum/action/cooldown/alien/banda/warrior_punch/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = prepare_warrior_ability()
	if(!warrior)
		return FALSE

	if(!isliving(target))
		return FALSE

	var/mob/living/victim = target
	if(!warrior.Adjacent(victim) || victim.stat == DEAD)
		return FALSE

	var/brute_damage = warrior.warrior_punch_brute
	var/stamina_damage = warrior.warrior_punch_stamina
	var/knockdown_time = warrior.warrior_punch_knockdown
	var/is_grabbed_combo = (warrior.get_warrior_grab_target() == victim)

	if(is_grabbed_combo)
		brute_damage = round(brute_damage * warrior.warrior_punch_grab_multiplier)
		stamina_damage = round(stamina_damage * warrior.warrior_punch_grab_multiplier)
		knockdown_time = warrior.warrior_punch_grab_knockdown
		warrior.stop_pulling()

	warrior.visible_message(
		span_danger("[warrior] со всей силы бьёт [victim] кулаком!"),
		span_alertalien("Мы со всей силы бьём [victim] кулаком!"),
	)

	warrior.do_attack_animation(victim, ATTACK_EFFECT_PUNCH)
	playsound(victim, 'sound/items/weapons/punch1.ogg', 70, TRUE)
	victim.apply_damage(brute_damage, BRUTE, BODY_ZONE_CHEST)
	victim.apply_damage(stamina_damage, STAMINA)

	if(!QDELETED(victim))
		victim.apply_status_effect(/datum/status_effect/staggered, is_grabbed_combo ? 4 SECONDS : 2 SECONDS)
		victim.Knockdown(knockdown_time)

	StartCooldown()
	return TRUE
// MARK:RUNNER

// Pounce

/** Прыжок, сбивающий цель с ног. Щит может отбить атаку. */
/datum/action/cooldown/alien/banda/pounce_runner
	name = "Наброситься"
	desc = "Прыгает на цель и сбивает её с ног. Щит способен отразить прыжок."
	button_icon = 'modular_bandastation/xeno_rework/icons/support_actions.dmi'
	button_icon_state = "pounce"
	plasma_cost = 10
	cooldown_time = 13 SECONDS
	click_to_activate = TRUE
	unset_after_click = TRUE
	/// Whether the runner is in an ability-driven leap.
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

/** End the runner leap and remove its temporary floating trait. */
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
/** Окно 0,15 секунды, строго один снаряд. Успех полностью сбрасывает перезарядку; промах — 8 секунд перезарядки и 1,5 секунды замедления. */
/datum/action/cooldown/alien/banda/evade
	name = "Уклонение"
	desc = "Позволяет уклониться от одного снаряда в течение 0,15 секунды. Успешное уклонение мгновенно восстанавливает способность. При неудаче — перезарядка 8 секунд и замедление на 1,5 секунды."
	button_icon_state = "evade"
	cooldown_time = 8 SECONDS
	/// Whether the evasion window is open.
	var/evade_active = FALSE
	/// Limits the activation to a single projectile evasion.
	var/dodged_this_activation = FALSE
	/// Stoppable evasion expiry timer.
	var/window_expires = 0
	/// Expiry is also checked at impact so timer lag never extends protection.
	var/window_timer

/datum/action/cooldown/alien/banda/evade/IsAvailable(feedback = FALSE)
	return !evade_active && ..()

/datum/action/cooldown/alien/banda/evade/Activate()
	if(!IsAvailable() || !isturf(owner.loc) || INCAPACITATED_IGNORING(owner, INCAPABLE_GRAB))
		return FALSE
	evade_active = TRUE
	dodged_this_activation = FALSE
	playsound(owner, 'sound/effects/magic/tail_swing.ogg', 40, TRUE)
	StartCooldown()
	window_expires = world.time + 0.15 SECONDS
	window_timer = addtimer(CALLBACK(src, PROC_REF(end_evade)), 0.15 SECONDS, TIMER_STOPPABLE)
	return TRUE

/** End evasion and release its expiry timer. */
/datum/action/cooldown/alien/banda/evade/proc/end_evade()
	deltimer(window_timer)
	window_timer = null
	if(evade_active && !dodged_this_activation && !QDELETED(owner) && owner.stat != DEAD)
		var/mob/living/living_owner = owner
		living_owner.apply_status_effect(/datum/status_effect/xeno_evade_miss)
	evade_active = FALSE
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/** One projectile per activation; a precise success resets the cooldown. */
/datum/action/cooldown/alien/banda/evade/proc/on_projectile_hit(obj/projectile/hitting_projectile)
	var/mob/living/living_owner = owner
	if(evade_active && world.time >= window_expires)
		end_evade()
	if(!evade_active || dodged_this_activation || QDELETED(owner) || living_owner.resting || !isturf(owner.loc) || INCAPACITATED_IGNORING(owner, INCAPABLE_GRAB))
		return BULLET_ACT_HIT
	dodged_this_activation = TRUE
	evade_active = FALSE
	deltimer(window_timer)
	window_timer = null
	owner.visible_message(span_danger("[owner] уклоняется от снаряда!"), span_noticealien("Точное уклонение!"))
	playsound(owner, 'modular_bandastation/xeno_rework/sound/spin.ogg', 60, TRUE)
	ResetCooldown()
	return BULLET_ACT_FORCE_PIERCE

/datum/action/cooldown/alien/banda/evade/Remove(mob/living/remove_from)
	deltimer(window_timer)
	window_timer = null
	evade_active = FALSE
	return ..()

// MARK:BASE XENO

/** Иногда даже кровожадным чужим нужно немного полежать. */
/datum/action/cooldown/alien/banda/sleepytime
	name = "Отдых"
	desc = "Даже самым свирепым ксеноморфам иногда нужен отдых."
	button_icon_state = "sleepytime"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED
	can_be_used_always = TRUE

/datum/action/cooldown/alien/banda/sleepytime/Activate()
	var/mob/living/carbon/sleepytime_mob = owner
	if(!isalien(owner))
		return FALSE
	if(!sleepytime_mob.resting)
		sleepytime_mob.set_resting(new_resting = TRUE, silent = FALSE, instant = TRUE)
		return TRUE
	sleepytime_mob.set_resting(new_resting = FALSE, silent = FALSE, instant = FALSE)
	return TRUE

/** Позволяет нам эволюционировать в высшую касту нашего типа, если такая ещё не существует. */
/datum/action/cooldown/alien/banda/generic_evolve
	name = "Эволюция"
	desc = "Эволюция в доступную высшую касту занимает 5 секунд. Линька прерывается при движении или потере сознания."
	button_icon_state = "evolution"
	/// Locks requests after caste selection and before the channel yields.
	var/evolving = FALSE
	/// Matches larval preparation; the existing inter-evolution cooldown is separate.
	var/evolution_time = 5 SECONDS

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
	if(!istype(evolver) || !evolver.get_evolution_type() || evolver.has_evolved_recently || !isturf(evolver.loc))
		return FALSE
	var/obj/item/organ/alien/hivenode/node = evolver.get_organ_slot(ORGAN_SLOT_XENO_HIVENODE)
	return node && !node.recent_queen_death

/datum/action/cooldown/alien/banda/generic_evolve/Activate()
	if(evolving || !IsAvailable())
		return FALSE
	var/mob/living/carbon/alien/adult/banda/evolver = owner
	var/list/options = evolver.get_evolution_options()
	var/evolution_type = evolver.get_evolution_type()
	if(length(options) > 1)
		var/list/choices = list()
		for(var/mob/living/carbon/alien/adult/banda/caste_type as anything in options)
			choices[initial(caste_type.name)] = caste_type
		var/choice = tgui_input_list(evolver, "Выберите направление эволюции", "Эволюция", choices)
		if(QDELETED(src) || QDELETED(evolver) || owner != evolver || !IsAvailable() || !(choice in choices))
			return FALSE
		evolution_type = choices[choice]
	return evolve_into(evolution_type)

/** Caste, slot and actor are checked again after the interruptible shedding animation. */
/datum/action/cooldown/alien/banda/generic_evolve/proc/evolve_into(evolution_type)
	var/mob/living/carbon/alien/adult/banda/evolver = owner
	if(evolving || !evolution_type || !IsAvailable() || !istype(evolver))
		return FALSE
	if(!evolver.can_evolve(evolution_type))
		evolver.balloon_alert(evolver, "Такая высшая каста уже есть в улье")
		return FALSE
	evolving = TRUE
	var/turf/start = evolver.loc
	evolver.visible_message(span_warning("[evolver] начинает сбрасывать старую хитиновую оболочку!"))
	evolver.start_hive_evolution_visual()
	var/ready = do_after(evolver, evolution_time, target = evolver)
	if(!QDELETED(evolver))
		evolver.remove_filter("xeno_evolution")
	if(QDELETED(src))
		return FALSE
	evolving = FALSE
	if(!ready || QDELETED(evolver) || owner != evolver || evolver.loc != start || !IsAvailable() || !evolver.can_evolve(evolution_type))
		return FALSE
	var/new_xeno = new evolution_type(evolver.loc)
	playsound(new_xeno, 'sound/mobs/non-humanoids/alien/alien_explode.ogg', 60, TRUE)
	evolver.alien_evolve(new_xeno)
	return TRUE

/datum/action/cooldown/alien/banda/generic_evolve/Remove(mob/living/remove_from)
	remove_from?.remove_filter("xeno_evolution")
	return ..()

/// Each T3 and purchased specialization has its own simultaneous limit.
/mob/living/carbon/alien/adult/banda/proc/can_evolve(evolution_target)
	if(!evolution_target)
		evolution_target = get_evolution_type()
	if(!ispath(evolution_target, /mob/living/carbon/alien/adult/banda) || !isturf(loc) || has_evolved_recently)
		return FALSE
	if(!(evolution_target in get_evolution_options()))
		return FALSE
	var/obj/item/organ/alien/hivenode/node = get_organ_slot(ORGAN_SLOT_XENO_HIVENODE)
	if(!node || node.recent_queen_death)
		return FALSE
	if(evolution_target == /mob/living/carbon/alien/adult/banda/queen)
		for(var/mob/living/carbon/alien/other in GLOB.alive_mob_list)
			if(istype(other, /mob/living/carbon/alien/adult/banda/queen) || istype(other, /mob/living/carbon/alien/adult/royal/queen))
				return FALSE
		return TRUE
	var/mob/living/carbon/alien/adult/banda/evolution_type = evolution_target
	if(initial(evolution_type.evolution_tier) >= 3 || evolution_target == /mob/living/carbon/alien/adult/banda/final_caste/hunter)
		return GLOB.xeno_hive.slot_available(evolution_target)
	return TRUE
