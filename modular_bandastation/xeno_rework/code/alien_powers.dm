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
	if(isnull(choice) || QDELETED(src) || QDELETED(owner))
		return FALSE

	var/obj/structure/choice_path = structures[choice]
	if(!ispath(choice_path))
		return FALSE

	var/mob/living/carbon/alien/adult/banda/alien_owner = owner
	if(!istype(alien_owner))
		return FALSE
	alien_owner.selected_resin_structure = choice_path
	to_chat(owner, span_noticealien("You prepare to build a [choice]."))
	return TRUE

/datum/action/cooldown/alien/build_resin_structure
	name = "Build Resin Structure"
	desc = "Build the selected resin structure on a nearby tile."
	button_icon = 'icons/mob/actions/actions_xeno.dmi'
	button_icon_state = "alien_resin"
	plasma_cost = 55
	click_to_activate = TRUE
	unset_after_click = FALSE
	var/obj/structure/made_structure_type
	var/build_time = 3 SECONDS

/datum/action/cooldown/alien/build_resin_structure/proc/check_for_duplicate(turf/location)
	var/obj/structure/existing_thing = locate(made_structure_type) in location
	if(existing_thing)
		to_chat(owner, span_warning("There is already \a [existing_thing] here!"))
		return FALSE
	// Проверка на множественные типы смолы
	var/static/list/structures = list(
		"resin wall" = /obj/structure/alien/resin/wall,
		"resin membrane" = /obj/structure/alien/resin/membrane,
		"resin nest" = /obj/structure/bed/nest,
		"resin door" = /obj/structure/alien/resin/door,
	)
	for(var/blocker_name in structures)
		var/obj/structure/blocker_type = structures[blocker_name]
		if(locate(blocker_type) in location)
			to_chat(owner, span_warning("There is already a resin structure there!"))
			return FALSE
	return TRUE

/datum/action/cooldown/alien/build_resin_structure/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/carbon/alien/adult/banda/alien_owner = owner
	if(!istype(alien_owner))
		return FALSE
	if(!alien_owner.selected_resin_structure)
		if(feedback)
			to_chat(owner, span_warning("You must select a structure to build first!"))
		return FALSE
	if(!isturf(owner.loc) || isspaceturf(owner.loc))
		if(feedback)
			to_chat(owner, span_warning("You can't build here!"))
		return FALSE
	return TRUE

/datum/action/cooldown/alien/build_resin_structure/PreActivate(atom/target)
	var/turf/location = get_turf(target)
	if(!location)
		return FALSE

	if(get_dist(owner, location) > 1)
		to_chat(owner, span_warning("You can only build on adjacent tiles!"))
		return FALSE

	if(!locate(/obj/structure/alien/weeds) in location)
		to_chat(owner, span_warning("You can only build on xenomorph weeds!"))
		return FALSE

	var/mob/living/carbon/alien/adult/banda/alien_owner = owner
	made_structure_type = alien_owner.selected_resin_structure
	if(!ispath(made_structure_type))
		to_chat(owner, span_warning("No structure selected!"))
		return FALSE

	if(!check_for_duplicate(location))
		return FALSE

	return ..()

/datum/action/cooldown/alien/build_resin_structure/Activate(atom/target)
	var/turf/location = get_turf(target)
	if(!location)
		return FALSE

	var/mob/living/carbon/alien/adult/banda/alien_owner = owner
	var/obj/structure/choice_path = alien_owner.selected_resin_structure
	if(!ispath(choice_path))
		to_chat(owner, span_warning("No structure selected!"))
		return FALSE

	if(alien_owner.getPlasma() < plasma_cost)
		to_chat(owner, span_warning("You don't have enough plasma to start building!"))
		return FALSE

	alien_owner.adjustPlasma(-plasma_cost)

	// Определяем название структуры для сообщений
	var/structure_name
	var/list/structure_map = list(
		"resin wall" = /obj/structure/alien/resin/wall,
		"resin membrane" = /obj/structure/alien/resin/membrane,
		"resin nest" = /obj/structure/bed/nest,
		"resin door" = /obj/structure/alien/resin/door
	)
	for (var/name in structure_map)
		if (choice_path == structure_map[name])
			structure_name = name
			break

	owner.visible_message(
		span_notice("[owner] begins to secrete a thick purple substance towards [location]."),
		span_notice("You start shaping a [structure_name] on [location == owner.loc ? "your tile" : "the adjacent tile"]."),
	)

	if(!do_after(owner, build_time, target = location, extra_checks = CALLBACK(src, /datum/action/cooldown/alien/build_resin_structure/proc/check_for_duplicate, location)))
		to_chat(owner, span_warning("Your construction was interrupted!"))
		return FALSE

	if(location == owner.loc)
		owner.visible_message(
			span_notice("[owner] finishes shaping a [structure_name]."),
			span_notice("You finish shaping a [structure_name]."),
		)
	else
		owner.visible_message(
			span_notice("[owner] finishes shaping a [structure_name] on [location]."),
			span_notice("You finish shaping a [structure_name] on the adjacent tile."),
		)

	new choice_path(location)
	return TRUE

// MARK: SENTINEL

/datum/action/cooldown/alien/acid/banda
	name = "Spit Neurotoxin"
	desc = "Выплёвывает нейротоксин в цель, изнуряя её."
	button_icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'
	button_icon_state = "neurospit_0"
	plasma_cost = 25
	/// A singular projectile? Use this one and leave acid_casing null
	var/acid_projectile = /obj/projectile/neurotoxin/banda
	/// You want it to be more like a shotgun style attack? Use this one and make acid_projectile null
	var/acid_casing
	/// Used in to_chat messages to the owner
	var/projectile_name = "neurotoxin"
	/// The base icon for the ability, so a red box can be put on it using _0 or _1
	var/button_base_icon = "neurospit"
	/// The sound that should be played when the xeno actually spits
	var/spit_sound = 'modular_bandastation/xeno_rework/sound/alien_spitacid.ogg'
	shared_cooldown = MOB_SHARED_COOLDOWN_3
	cooldown_time = 3 SECONDS

/datum/action/cooldown/alien/acid/banda/IsAvailable(feedback = FALSE)
	return ..() && isturf(owner.loc)

/datum/action/cooldown/alien/acid/banda/set_click_ability(mob/on_who)
	. = ..()
	if(!.)
		return

	to_chat(on_who, span_notice("Вы подготавливаете свою железу [projectile_name]. <B>Левый клик, чтобы выстрелить по цели!</B>"))

	button_icon_state = "[button_base_icon]_1"
	build_all_button_icons()
	on_who.update_icons()

/datum/action/cooldown/alien/acid/banda/unset_click_ability(mob/on_who, refund_cooldown = TRUE)
	. = ..()
	if(!.)
		return

	if(refund_cooldown)
		to_chat(on_who, span_notice("Вы опустошаете свою железу [projectile_name]."))

	button_icon_state = "[button_base_icon]_0"
	build_all_button_icons()
	on_who.update_icons()

/datum/action/cooldown/alien/acid/banda/InterceptClickOn(mob/living/clicker, params, atom/target)
	if(!IsAvailable())
		return FALSE

	. = ..()
	if(!.)
		unset_click_ability(clicker, refund_cooldown = FALSE)
		return FALSE

	var/turf/user_turf = clicker.loc
	var/turf/target_turf = get_step(clicker, target.dir)
	if(!isturf(target_turf))
		return FALSE

	var/modifiers = params2list(params)
	clicker.visible_message(
		span_danger("[clicker] выплёвывает [projectile_name]!"),
		span_alertalien("Вы выплёвываете [projectile_name]."),
	)

	if(acid_projectile)
		var/obj/projectile/spit_projectile = new acid_projectile(clicker.loc)
		spit_projectile.aim_projectile(target, clicker, modifiers)
		spit_projectile.firer = clicker
		spit_projectile.fire()
		playsound(clicker, spit_sound, 70, TRUE, 5, 0.9)
		clicker.newtonian_move(get_dir(target_turf, user_turf))
		//unset_click_ability(clicker, refund_cooldown = FALSE)
		StartCooldown()
		return TRUE

	if(acid_casing)
		var/obj/item/ammo_casing/casing = new acid_casing(clicker.loc)
		playsound(clicker, spit_sound, 70, TRUE, 5, 0.9)
		casing.fire_casing(target, clicker, null, null, null, ran_zone(), 0, clicker)
		clicker.newtonian_move(get_dir(target_turf, user_turf))
		//unset_click_ability(clicker, refund_cooldown = FALSE)
		StartCooldown()
		return TRUE

	CRASH("Для плевательной атаки [clicker] не заданы ни acid_projectile, ни acid_casing!")

/datum/action/cooldown/alien/acid/banda/Activate(atom/target)
	return TRUE

/obj/projectile/neurotoxin/banda
	name = "neurotoxin spit"
	icon_state = "neurotoxin"
	damage = 30
	paralyze = 0
	damage_type = STAMINA
	armor_flag = BIO

/obj/projectile/neurotoxin/banda/on_hit(atom/target, blocked = 0, pierce_hit)
	if(isalien(target))
		damage = 0
	return ..()

/datum/action/cooldown/alien/acid/banda/lethal
	name = "Spit Acid"
	desc = "Выплёвывает нейротоксин в цель, обжигая её."
	acid_projectile = /obj/projectile/neurotoxin/banda/acid
	button_icon_state = "acidspit_0"
	projectile_name = "acid"
	button_base_icon = "acidspit"

/obj/projectile/neurotoxin/banda/acid
	name = "acid spit"
	icon_state = "toxin"
	damage = 20
	paralyze = 0
	damage_type = BURN

// MARK: RAVAGER VISUAL (abilities are in code/tgmc/ravager_powers.dm)

/obj/effect/temp_visual/dir_setting/tailsweep/ravager
	icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'
	icon_state = "slice_tail_anim"

// MARK: QUEEN

/datum/action/cooldown/alien/banda/queen_screech
	name = "Deafening Screech"
	desc = "Издаёт оглушительный визг, который, вероятно, ненадолго выведет из строя всех слышащих существ вокруг. Перезарядка 3 минуты."
	button_icon_state = "screech"
	cooldown_time = 3 MINUTES

/datum/action/cooldown/alien/banda/queen_screech/Activate()
	. = ..()
	var/mob/living/carbon/alien/adult/banda/queenie = owner
	playsound(queenie, 'modular_bandastation/xeno_rework/sound/alien_queen_screech.ogg', 70, FALSE, 8, 0.9)
	queenie.create_shriekwave()
	shake_camera(owner, 2, 2)

	for(var/mob/living/carbon/human/screech_target in get_hearers_in_view(7, get_turf(queenie)))
		screech_target.soundbang_act(intensity = 5, stun_pwr = 50, damage_pwr = 10, deafen_pwr = 30) //Only being deaf will save you from the screech
		shake_camera(screech_target, 4, 3)
		to_chat(screech_target, span_red("[queenie] lets out a deafening screech!"))

	return TRUE

/datum/action/cooldown/spell/aoe/repulse/xeno/banda_tailsweep/hard_throwing
	name = "Flinging Tail Sweep"
	desc = "Размашистый удар хвоста отбрасывает врагов назад с огромной силой."

	aoe_radius = 2
	repulse_force = MOVE_FORCE_OVERPOWERING //Fuck everyone who gets hit by this tail in particular

	button_icon_state = "throw_tail"

	sparkle_path = /obj/effect/temp_visual/dir_setting/tailsweep/praetorian

	impact_sound = 'sound/items/weapons/slap.ogg'
	impact_damage = 20
	impact_wound_bonus = 10

/obj/effect/temp_visual/dir_setting/tailsweep/praetorian
	icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'
	icon_state = "throw_tail_anim"

// MARK: banda_tailsweep

/datum/action/cooldown/spell/aoe/repulse/xeno/banda_tailsweep
	name = "Crushing Tail Sweep"
	desc = "Отбросьте нападающих взмахом хвоста, вероятно, ломая им кости."

	cooldown_time = 60 SECONDS

	aoe_radius = 1

	button_icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'
	button_icon_state = "crush_tail"

	//sparkle_path = /obj/effect/temp_visual/dir_setting/tailsweep/defender

	/// The sound that the tail sweep will make upon hitting something
	var/impact_sound = 'sound/effects/clang.ogg'
	/// How long mobs hit by the tailsweep should be knocked down for
	var/knockdown_time = 4 SECONDS
	/// How much damage tail sweep impacts should do to a mob
	var/impact_damage = 30
	/// What wound bonus should the tai sweep impact have
	var/impact_wound_bonus = 20
	/// What type of sharpness should this tail sweep have
	var/impact_sharpness = FALSE
	/// What type of damage should the tail sweep do
	var/impact_damage_type = BRUTE

/datum/action/cooldown/spell/aoe/repulse/xeno/banda_tailsweep/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE

	var/mob/living/carbon/alien/adult/banda/owner_alien = owner
	if(!istype(owner_alien) || owner_alien.unable_to_use_abilities)
		return FALSE

/datum/action/cooldown/spell/aoe/repulse/xeno/banda_tailsweep/cast_on_thing_in_aoe(atom/movable/victim, atom/caster)
	if(!isliving(victim) && !istype(victim, /obj/vehicle/sealed))
		return

	if(isalien(victim))
		return

	var/turf/throwtarget = get_edge_target_turf(
		caster,
		get_dir(caster, get_step_away(victim, caster))
	)

	if(!throwtarget)
		return

	var/dist_from_caster = get_dist(victim, caster)

	if(isliving(victim))
		var/mob/living/victim_living = victim

		if(dist_from_caster <= 0)
			victim_living.Knockdown(knockdown_time)
		else
			victim_living.Knockdown(knockdown_time * 2)

		if(sparkle_path)
			new sparkle_path(get_turf(victim_living), get_dir(caster, victim_living))

		victim_living.apply_damage(
			impact_damage,
			impact_damage_type,
			BODY_ZONE_CHEST,
			wound_bonus = impact_wound_bonus,
			sharpness = impact_sharpness
		)

		shake_camera(victim_living, 4, 3)
		playsound(victim_living, impact_sound, 70, TRUE, 8, 0.9)

		to_chat(
			victim_living,
			span_userdanger("Хвост [caster] обрушивается на вас, отбрасывая назад!")
		)

	else if(istype(victim, /obj/vehicle/sealed))
		var/obj/vehicle/sealed/vehicle = victim

		if(sparkle_path)
			new sparkle_path(get_turf(vehicle), get_dir(caster, vehicle))

		playsound(vehicle, impact_sound, 70, TRUE, 8, 0.9)

	victim.throw_at(
		throwtarget,
		clamp(
			max_throw - clamp(dist_from_caster - 2, 0, dist_from_caster),
			3,
			max_throw
		),
		1,
		caster,
		FALSE,
		FALSE,
		null,
		repulse_force,
		FALSE,
		TRUE
	)

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
	parent_type = /datum/action/cooldown/alien/banda/defender_shared
	name = "Fortify"
	desc = "Занять укреплённую позицию: сильно замедлиться, но получить защиту от дальнего урона и взрывов."
	button_icon_state = "fortify"
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
		if(D.defender_tail_sweep_stagger && hascall(L, "adjust_stagger"))
			call(L, "adjust_stagger")(D.defender_tail_sweep_stagger)
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
	button_icon_state = "runner_pounce"
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
	if(QDELETED(src) || QDELETED(W) || !dashing)
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
	if(QDELETED(src) || QDELETED(W) || QDELETED(L))
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

	if(hascall(L, "Paralyze"))
		call(L, "Paralyze")(W.warrior_lunge_stun)
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


// ----------------------------------------
// Throw (grabbed target only)
// ----------------------------------------

/datum/action/cooldown/alien/banda/warrior_throw
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Throw"
	desc = "Бросок захваченного существа на выбранную клетку. Дальше, чем Fling, и с точным выбором точки."
	button_icon_state = "fling"
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
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Fling"
	desc = "Отбрасывает соседнюю цель от себя. Короче, чем Throw, но не требует захвата и накладывает дебафф."
	button_icon_state = "tail_sweep"
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

	if(hascall(L, "adjust_stagger"))
		call(L, "adjust_stagger")(W.warrior_fling_stagger)

	if(hascall(L, "add_slowdown"))
		call(L, "add_slowdown")(W.warrior_fling_slowdown)

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
	parent_type = /datum/action/cooldown/alien/banda/warrior_shared
	name = "Punch"
	desc = "Удар по цели рядом, наносящий урон выносливости, замедление и пошатывание. Захваченной цели наносит усиленный эффект."
	button_icon_state = "punch"
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

	if(hascall(L, "adjust_stagger"))
		call(L, "adjust_stagger")(is_grabbed_combo ? 2 : 1)

	if(hascall(L, "add_slowdown"))
		call(L, "add_slowdown")(is_grabbed_combo ? 2 : 1)

	if(hascall(L, "adjust_blurriness"))
		call(L, "adjust_blurriness")(is_grabbed_combo ? 2 : 1)

	L.Knockdown(knockdown_time)
	step_away(L, W, is_grabbed_combo ? 2 : 1)

	StartCooldown()
	return TRUE
// MARK:DRONE

/datum/action/cooldown/alien/banda/heal_aura
	name = "Healing Aura"
	desc = "Дружественные ксеноморфы в небольшом радиусе вокруг вас будут получать пассивное исцеление."
	button_icon_state = "healaura"
	plasma_cost = 100
	cooldown_time = 90 SECONDS
	/// Is the healing aura currently active or not
	var/aura_active = FALSE
	/// How long the healing aura should last
	var/aura_duration = 30 SECONDS
	/// How far away the healing aura should reach
	var/aura_range = 5
	/// How much brute/burn individually the healing aura should heal each time it fires
	var/aura_healing_amount = 5
	/// What color should the + particles caused by the healing aura be
	var/aura_healing_color = COLOR_BLUE_LIGHT
	/// The healing aura component itself that the ability uses
	var/datum/component/aura_healing/aura_healing_component

/datum/action/cooldown/alien/banda/heal_aura/Activate()
	. = ..()
	if(aura_active)
		owner.balloon_alert(owner, "already healing")
		return FALSE
	owner.balloon_alert(owner, "healing aura started")
	to_chat(owner, span_danger("Мы испускаем феромоны, которые побуждают сестёр рядом с нами исцеляться в течение следующих [aura_duration / 10] секунд."))
	addtimer(CALLBACK(src, PROC_REF(aura_deactivate)), aura_duration)
	aura_active = TRUE
	aura_healing_component = owner.AddComponent(/datum/component/aura_healing, range = aura_range, requires_visibility = TRUE, brute_heal = aura_healing_amount, burn_heal = aura_healing_amount, limit_to_trait = TRAIT_XENO_HEAL_AURA, healing_color = aura_healing_color)
	return TRUE

/datum/action/cooldown/alien/banda/heal_aura/proc/aura_deactivate()
	if(!aura_active)
		return
	aura_active = FALSE
	QDEL_NULL(aura_healing_component)
	owner.balloon_alert(owner, "healing aura ended")

/datum/action/cooldown/alien/banda/heal_aura/juiced
	name = "Strong Healing Aura"
	desc = "Дружественные ксеноморфы в большем радиусе вокруг вас будут получать пассивное исцеление."
	button_icon_state = "healaura_juiced"
	plasma_cost = 100
	cooldown_time = 90 SECONDS
	aura_range = 7
	aura_healing_amount = 10
	aura_healing_color = COLOR_RED_LIGHT

// MARK:PRAETORIAN

/datum/action/cooldown/alien/acid/banda/spread
	name = "Spit Neurotoxin Spread"
	desc = "Выплёвывает нейротоксин, истощая противника."
	plasma_cost = 50
	acid_projectile = null
	acid_casing = /obj/item/ammo_casing/xenospit
	spit_sound = 'modular_bandastation/xeno_rework/sound/alien_spitacid2.ogg'
	cooldown_time = 10 SECONDS

/obj/item/ammo_casing/xenospit //This is probably really bad, however I couldn't find any other nice way to do this
	name = "big glob of neurotoxin"
	projectile_type = /obj/projectile/neurotoxin/banda/spitter_spread
	pellets = 3
	variance = 20

/obj/item/ammo_casing/xenospit/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/caseless)

/obj/item/ammo_casing/xenospit/tk_firing(mob/living/user, atom/fired_from)
	return FALSE

/obj/projectile/neurotoxin/banda/spitter_spread //Slightly nerfed because its a shotgun spread of these
	name = "neurotoxin spit"
	icon_state = "neurotoxin"
	damage = 25

/datum/action/cooldown/alien/acid/banda/spread/lethal
	name = "Spit Acid Spread"
	desc = "Выплёвывает облако кислоты в цель, обжигая её."
	acid_projectile = null
	acid_casing = /obj/item/ammo_casing/xenospit/spread/lethal
	button_icon_state = "acidspit_0"
	projectile_name = "acid"
	button_base_icon = "acidspit"

/obj/item/ammo_casing/xenospit/spread/lethal
	name = "big glob of acid"
	projectile_type = /obj/projectile/neurotoxin/banda/acid/spitter_spread
	pellets = 4
	variance = 30

/obj/projectile/neurotoxin/banda/acid/spitter_spread
	name = "acid spit"
	icon_state = "toxin"
	damage = 15
	damage_type = BURN

// MARK:RUNNER

// Pounce

/datum/action/cooldown/alien/banda/pounce_runner
	name = "Наброситься"
	desc = "Сбивает цель с ног."
	button_icon_state = "pounce"
	plasma_cost = 15
	cooldown_time = 13 SECONDS

	var/pounce_range = 7 //max "click" range

	/// dash steps (ticks)
	var/dash_step_delay = 1 //how fast we jump
	var/dash_max_steps = 7 //max pounce range

	/// stun
	var/stun_time = 1.5 SECONDS
	var/knockdown_time = 2 SECONDS

	var/shield_block_chance = 50

	/// internal state
	var/pounce_active = FALSE
	var/turf/landing_turf
	var/datum/weakref/expected_target_ref
	var/has_resolved = FALSE


/datum/action/cooldown/alien/banda/pounce_runner/Activate(atom/target)
	if(!IsAvailable())
		return FALSE
	set_click_ability(owner)
	return TRUE


/datum/action/cooldown/alien/banda/pounce_runner/set_click_ability(mob/on_who)
	. = ..()
	if(!.)
		return
	to_chat(on_who, span_notice("Вы готовитесь совершить прыжок."))


/datum/action/cooldown/alien/banda/pounce_runner/unset_click_ability(mob/on_who, refund_cooldown = TRUE)
	. = ..()
	return


/datum/action/cooldown/alien/banda/pounce_runner/InterceptClickOn(mob/living/clicker, params, atom/target)
	if(!IsAvailable())
		return FALSE

	. = ..()
	if(!.)
		unset_click_ability(clicker, refund_cooldown = FALSE)
		return FALSE

	var/mob/living/carbon/alien/adult/banda/runner/R = owner
	if(!istype(R) || clicker != R)
		unset_click_ability(clicker, refund_cooldown = FALSE)
		return FALSE

	if(pounce_active)
		unset_click_ability(clicker, refund_cooldown = FALSE)
		return FALSE

	var/turf/T = get_turf(target)
	if(!isturf(T))
		unset_click_ability(clicker, refund_cooldown = FALSE)
		return TRUE

	if(get_dist(R, T) > pounce_range)
		R.balloon_alert(R, "слишком далеко")
		unset_click_ability(clicker, refund_cooldown = FALSE)
		return TRUE

	expected_target_ref = null
	if(ismob(target))
		var/mob/living/L0 = target
		if(L0.stat != DEAD)
			expected_target_ref = WEAKREF(L0)

	landing_turf = T
	pounce_active = TRUE
	has_resolved = FALSE

	R.visible_message(span_danger("[R] набрасывается!"), span_userdanger("Вы совершаете прыжок!"))
	R.face_atom(landing_turf)

	playsound(R, 'modular_bandastation/xeno_rework/sound/pounce.ogg', 50, TRUE)

	_start_dash(R, landing_turf, dash_max_steps)

	addtimer(CALLBACK(src, PROC_REF(_pounce_timeout)), 50)

	unset_click_ability(clicker, refund_cooldown = FALSE)
	StartCooldown()
	return TRUE


/datum/action/cooldown/alien/banda/pounce_runner/proc/_start_dash(mob/living/carbon/alien/adult/banda/runner/R, turf/dest, steps_left)
	if(QDELETED(src) || QDELETED(R) || QDELETED(dest))
		_pounce_cleanup()
		return
	if(!pounce_active || has_resolved)
		return

	if(R.loc == dest || steps_left <= 0)
		_pounce_cleanup()
		return

	var/turf/current = get_turf(R)
	if(!isturf(current))
		_pounce_cleanup()
		return

	var/dir_to = get_dir(current, dest)
	if(!dir_to)
		_pounce_cleanup()
		return

	var/turf/next = get_step(current, dir_to)
	if(!isturf(next))
		_pounce_cleanup()
		return

	var/mob/living/candidate = _pick_occupant_for_hit(next)

	if(candidate)
		_do_pounce_hit(R, candidate)
		has_resolved = TRUE
		_pounce_cleanup()
		return

	// Otherwise move normally.
	var/moved = step(R, dir_to)
	if(!moved)
		_pounce_cleanup()
		return

	addtimer(CALLBACK(src, PROC_REF(_start_dash), R, dest, steps_left - 1), dash_step_delay)


/datum/action/cooldown/alien/banda/pounce_runner/proc/_pick_occupant_for_hit(turf/next)
	if(!isturf(next))
		return null

	// Prefer the clicked target if it is on that turf
	if(expected_target_ref)
		var/datum/weakref/W = expected_target_ref
		var/mob/living/Pref = W ? W.resolve() : null
		if(Pref && Pref.stat != DEAD && get_turf(Pref) == next)
			return Pref

	// Otherwise: any living mob on that turf
	for(var/mob/living/L in next)
		if(L.stat == DEAD)
			continue
		if(L == owner)
			continue
		return L

	return null


/datum/action/cooldown/alien/banda/pounce_runner/proc/_do_pounce_hit(mob/living/carbon/alien/adult/banda/runner/R, mob/living/L)
	if(QDELETED(src) || QDELETED(R) || QDELETED(L))
		return

	// Shield can block
	if(_shield_blocks(L))
		R.visible_message(span_warning("[L] отбивает прыжок [R]!"), span_warning("Твою атаку отбили!"))
		return

	_apply_hit_effects(L)


/datum/action/cooldown/alien/banda/pounce_runner/proc/_apply_hit_effects(mob/living/L)
	if(QDELETED(src) || QDELETED(L))
		return

	// stun
	if(hascall(L, "Paralyze"))
		call(L, "Paralyze")(stun_time)
	else
		L.Knockdown(stun_time)

	// Then knockdown
	L.Knockdown(knockdown_time)


/datum/action/cooldown/alien/banda/pounce_runner/proc/_pounce_timeout()
	_pounce_cleanup()


/datum/action/cooldown/alien/banda/pounce_runner/proc/_pounce_cleanup()
	if(!pounce_active && !landing_turf && !expected_target_ref)
		return
	pounce_active = FALSE
	landing_turf = null
	expected_target_ref = null
	has_resolved = FALSE


/datum/action/cooldown/alien/banda/pounce_runner/Destroy()
	_pounce_cleanup()
	return ..()


/datum/action/cooldown/alien/banda/pounce_runner/proc/_shield_blocks(mob/living/L)
	if(!ishuman(L))
		return FALSE
	var/mob/living/carbon/human/H = L
	return H.is_holding_item_of_type(/obj/item/shield) && prob(shield_block_chance)

// Evade

/datum/action/cooldown/alien/banda/evade
	name = "Уклонение"
	desc = "Короткое окно уклонения от снарядов. Успешное уклонение сбрасывает перезарядку. Если нажать впустую — 15 секунд перезарядки."
	button_icon_state = "evade"
	plasma_cost = 10
	cooldown_time = 0 SECONDS

	/// active window flag
	var/evade_active = FALSE
	/// did we actually dodge a projectile during this activation?
	var/dodged_this_activation = FALSE

	/// how long the invuln-to-projectiles window lasts
	var/evade_window = 0.6 SECONDS

	/// cooldown if you miss
	var/fail_cooldown = 15 SECONDS

	/// our own cooldown tracker (world.time ticks)
	var/next_available_time = 0


/datum/action/cooldown/alien/banda/evade/proc/_is_ready()
	return (world.time >= next_available_time)


/datum/action/cooldown/alien/banda/evade/Activate()
	if(evade_active)
		owner.balloon_alert(owner, "уже уклоняемся")
		return FALSE

	if(!_is_ready())
		owner.balloon_alert(owner, "на перезарядке")
		return FALSE

	// Must be on turf, not incapacitated
	if(!isturf(owner.loc) || INCAPACITATED_IGNORING(owner, INCAPABLE_GRAB))
		owner.balloon_alert(owner, "не могу")
		return FALSE

	evade_active = TRUE
	dodged_this_activation = FALSE

	owner.balloon_alert(owner, "уклонение")

	addtimer(CALLBACK(src, PROC_REF(_evade_window_end)), evade_window)
	return TRUE


/datum/action/cooldown/alien/banda/evade/proc/_evade_window_end()
	if(!evade_active)
		return

	evade_active = FALSE

	if(!dodged_this_activation)
		next_available_time = world.time + fail_cooldown
		owner.balloon_alert(owner, "не успели")


/**
 * Called from runner/bullet_act(). Returns BULLET_ACT_*
 */
/datum/action/cooldown/alien/banda/evade/proc/on_projectile_hit(obj/projectile/hitting_projectile = null)
	if(!evade_active)
		return BULLET_ACT_HIT

	if(!isturf(owner.loc) || INCAPACITATED_IGNORING(owner, INCAPABLE_GRAB))
		return BULLET_ACT_HIT

	// Successful dodge!
	evade_active = FALSE
	dodged_this_activation = TRUE

	owner.visible_message(
		span_danger("[owner] уклоняется от снаряда!"),
		span_userdanger("Вы уклоняетесь от снаряда!")
	)

	playsound(get_turf(owner), 'modular_bandastation/xeno_rework/sound/spin.ogg', 60, TRUE)

	// Reset cooldown on success: available immediately
	next_available_time = world.time

	return BULLET_ACT_FORCE_PIERCE


/datum/action/cooldown/alien/banda/evade/Destroy()
	evade_active = FALSE
	dodged_this_activation = FALSE
	next_available_time = 0
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
	/// What type this ability will turn the owner into upon completion
	var/type_to_evolve_into

/datum/action/cooldown/alien/banda/generic_evolve/Grant(mob/grant_to)
	. = ..()
	if(!istype(owner, /mob/living/carbon/alien/adult/banda))
		return
	var/mob/living/carbon/alien/adult/banda/target_alien = owner
	plasma_cost = target_alien.get_max_plasma() //This ability should always require that a xeno be at their max plasma capacity to use

/datum/action/cooldown/alien/banda/generic_evolve/Activate()
	var/mob/living/carbon/alien/adult/banda/evolver = owner

	if(!istype(evolver))
		to_chat(owner, span_warning("You aren't an alien, you can't evolve!"))
		return FALSE

	type_to_evolve_into = evolver.next_evolution
	if(!type_to_evolve_into)
		to_chat(evolver, span_bolddanger("Something is wrong... We can't evolve into anything?"))
		CRASH("Couldn't find an evolution for [owner] ([owner.type]).")

	if(!isturf(evolver.loc))
		return FALSE

	if(get_alien_type(type_to_evolve_into))
		evolver.balloon_alert(evolver, "Слишком много наших эволюционировавших форм уже существует.")
		return FALSE

	var/obj/item/organ/alien/hivenode/node = evolver.get_organ_by_type(/obj/item/organ/alien/hivenode)
	if(!node)
		to_chat(evolver, span_bolddanger("Мы не ощущаем связь нашего узла с ульем... Мы не можем эволюционировать!"))
		return FALSE

	if(node.recent_queen_death)
		to_chat(evolver, span_bolddanger("Смерть нашей королевы... Мы не можем собрать достаточно ментальной энергии, чтобы эволюционировать..."))
		return FALSE

	if(evolver.has_evolved_recently)
		evolver.balloon_alert(evolver, "сможет эволюционировать через 1.5 минуты") //Make that 1.5 variable later, but it keeps fucking up for me :(
		return FALSE

	var/new_beno = new type_to_evolve_into(evolver.loc)
	evolver.alien_evolve(new_beno)
	return TRUE
