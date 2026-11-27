#define LIAR_BACKSTEP_STRIKES 3
#define LIAR_BACKSTEP_TURN_WINDOW (2 SECONDS)

/datum/action/cooldown/legendary_sword/liar_backstep
	name = "Шаг за спину"
	desc = "Прыгните за спину цели в пределах пяти клеток и нанесите удар, оставляющий сильное кровотечение. Если цель повернётся к вам в течение двух секунд, снова прыгните ей за спину. Всего до трёх ударов."
	button_icon = 'modular_bandastation/weapon/icons/melee/liar_abilities.dmi'
	button_icon_state = "liar_backstep"
	click_to_activate = TRUE
	cooldown_time = 30 SECONDS

/datum/action/cooldown/legendary_sword/liar_backstep/Activate(atom/target)
	var/mob/living/user = owner
	if(!isliving(target))
		return FALSE
	if(!user.apply_status_effect(/datum/status_effect/legendary_sword_sequence/liar_backstep, saber, required_bond, target, src))
		return FALSE
	StartCooldown()
	return TRUE

/datum/status_effect/legendary_sword_sequence/liar_backstep
	id = "liar_backstep"
	tick_interval = STATUS_EFFECT_NO_TICK
	var/mob/living/victim
	var/strikes_left = LIAR_BACKSTEP_STRIKES
	var/turn_timer
	/// Movement initiated by the current jump may reach only this tile.
	var/turf/jump_landing

/datum/status_effect/legendary_sword_sequence/liar_backstep/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond, mob/living/target, datum/action/cooldown/legendary_sword/liar_backstep/ability)
	if(!..() || QDELETED(target) || target == owner || target.stat == DEAD || !isturf(target.loc) || !(target in view(saber.reach, owner)))
		return FALSE
	var/turf/landing = get_step(target, REVERSE_DIR(target.dir))
	if(!landing?.Adjacent(target, mover = owner) || !legendary_sword_can_leap(owner, landing))
		saber.balloon_alert(owner, "путь за спину перекрыт")
		return FALSE
	victim = target
	RegisterSignal(ability, COMSIG_ACTION_REMOVED, PROC_REF(stop_sequence))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_move))
	RegisterSignal(victim, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(on_target_turn))
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(on_target_move))
	RegisterSignals(victim, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(stop_sequence))
	new /obj/effect/temp_visual/liar_glint(owner.loc)
	owner.visible_message(span_warning("Клинок [owner.declent_ru(GENITIVE)] вспыхивает жёлтым."))
	addtimer(CALLBACK(src, PROC_REF(jump_and_strike)), 0.5 SECONDS, TIMER_DELETE_ME)
	return TRUE

/datum/status_effect/legendary_sword_sequence/liar_backstep/on_remove()
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	if(victim)
		UnregisterSignal(victim, list(COMSIG_ATOM_POST_DIR_CHANGE, COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	victim = null
	return ..()

/datum/status_effect/legendary_sword_sequence/liar_backstep/proc/on_owner_move()
	SIGNAL_HANDLER
	if(!jump_landing || owner.loc != jump_landing)
		qdel(src)

/datum/status_effect/legendary_sword_sequence/liar_backstep/proc/on_target_move()
	SIGNAL_HANDLER
	if(!isturf(victim.loc) || (strikes_left != LIAR_BACKSTEP_STRIKES && !owner.Adjacent(victim)))
		qdel(src)

/datum/status_effect/legendary_sword_sequence/liar_backstep/proc/target_faces_owner()
	var/toward_owner = get_dir(victim, owner)
	return toward_owner && abs(closer_angle_difference(dir2angle(victim.dir), dir2angle(toward_owner))) <= 45

/datum/status_effect/legendary_sword_sequence/liar_backstep/proc/on_target_turn(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(!turn_timer || old_dir == new_dir || !owner.Adjacent(victim) || !target_faces_owner())
		return
	deltimer(turn_timer)
	turn_timer = null
	// Let the turn or movement that triggered the jump finish first.
	addtimer(CALLBACK(src, PROC_REF(jump_and_strike)), 0.2 SECONDS, TIMER_DELETE_ME)

/datum/status_effect/legendary_sword_sequence/liar_backstep/proc/jump_and_strike()
	if(!can_continue() || QDELETED(victim) || victim.stat == DEAD || !isturf(victim.loc))
		qdel(src)
		return
	if(strikes_left == LIAR_BACKSTEP_STRIKES && !(victim in view(saber.reach, owner)))
		qdel(src)
		return
	if(strikes_left != LIAR_BACKSTEP_STRIKES && (!owner.Adjacent(victim) || !target_faces_owner()))
		qdel(src)
		return
	var/turf/landing = get_step(victim, REVERSE_DIR(victim.dir))
	if(!landing?.Adjacent(victim, mover = owner) || !legendary_sword_can_leap(owner, landing))
		qdel(src)
		return
	var/turf/origin = owner.loc
	if(origin != landing)
		var/obj/effect/temp_visual/decoy/fading/halfsecond/echo = new(origin, owner, 150)
		echo.color = LIGHT_COLOR_DIM_YELLOW
		jump_landing = landing
		owner.forceMove(landing)
		jump_landing = null
	if(!can_continue() || owner.loc != landing || QDELETED(victim) || !owner.Adjacent(victim) || landing != get_step(victim, REVERSE_DIR(victim.dir)))
		qdel(src)
		return
	if(origin != landing)
		playsound(landing, 'modular_bandastation/weapon/sound/melee/lz_backstep_jump.ogg', 42, FALSE)
	owner.setDir(get_dir(owner, victim))
	var/first_strike = strikes_left == LIAR_BACKSTEP_STRIKES
	strikes_left--
	var/turf/impact = victim.loc
	var/damage = strike(victim, 18, silence_hitsound = TRUE)
	if(damage > 0)
		playsound(impact, 'modular_bandastation/weapon/sound/melee/lz_backstep_hit.ogg', 53, FALSE)
	if(QDELETED(src))
		return
	if(damage <= 0)
		qdel(src)
		return
	if(first_strike && iscarbon(victim))
		apply_backstep_bleed()
	if(!strikes_left)
		qdel(src)
		return
	turn_timer = addtimer(CALLBACK(src, PROC_REF(stop_sequence)), LIAR_BACKSTEP_TURN_WINDOW, TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/status_effect/legendary_sword_sequence/liar_backstep/proc/apply_backstep_bleed()
	var/mob/living/carbon/wounded = victim
	var/obj/item/bodypart/chest = wounded.get_bodypart(BODY_ZONE_CHEST)
	if(chest?.can_bleed())
		chest.adjustBleedStacks(10)
		to_chat(victim, span_userdanger("Удар в спину оставляет глубокую кровоточащую рану!"))

#undef LIAR_BACKSTEP_TURN_WINDOW
#undef LIAR_BACKSTEP_STRIKES

#define LIAR_LAST_LIE_RANGE 8
#define LIAR_LAST_LIE_COPY_DURATION (4 SECONDS)
#define LIAR_LAST_LIE_RUN_DELAY (0.25 SECONDS)

/datum/action/cooldown/legendary_sword/liar_last_lie
	name = "Последняя ложь"
	desc = "Погасите клинок и исчезните, оставив на месте падающего двойника. Появитесь на выбранной свободной клетке в пределах восьми шагов. Рядом появится вторая копия и пробежит до восьми клеток."
	button_icon = 'modular_bandastation/weapon/icons/melee/liar_abilities.dmi'
	button_icon_state = "liar_last_lie"
	required_bond = 50
	cooldown_time = 50 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/legendary_sword/liar_last_lie/Activate(atom/target)
	var/mob/living/carbon/user = owner
	var/turf/destination = isturf(target) ? target : target?.loc
	if(!istype(user) || user.body_position != STANDING_UP || user.get_active_held_item() != saber || HAS_TRAIT(user, TRAIT_IMMOBILIZED))
		return FALSE
	if(!istype(destination) || destination == user.loc || !(destination in view(LIAR_LAST_LIE_RANGE, user)) || !legendary_sword_can_leap(user, destination))
		saber.balloon_alert(user, "выберите свободную клетку в пределах восьми шагов")
		return FALSE
	if(!user.apply_status_effect(/datum/status_effect/liar_last_lie, saber, required_bond, destination))
		return FALSE
	StartCooldown()
	return TRUE

/datum/status_effect/liar_last_lie
	id = "liar_last_lie"
	alert_type = null
	tick_interval = STATUS_EFFECT_NO_TICK
	on_remove_on_mob_delete = TRUE
	var/obj/item/dualsaber/legendary_saber/blade
	var/turf/origin
	var/turf/destination
	var/required_bond
	var/previous_invisibility

/datum/status_effect/liar_last_lie/on_apply(obj/item/dualsaber/legendary_saber/sword, bond, turf/landing)
	var/datum/component/two_handed/grip = sword.GetComponent(/datum/component/two_handed)
	if(!grip?.wielded)
		return FALSE
	if(!liar_last_lie_escape_direction(landing, owner.loc))
		sword.balloon_alert(owner, "двойнику некуда бежать")
		return FALSE
	var/ordinary_unwield_sound = grip.unwieldsound
	grip.unwieldsound = null
	grip.unwield(owner, show_message = FALSE)
	if(!QDELETED(grip))
		grip.unwieldsound = ordinary_unwield_sound
	if(QDELETED(owner) || QDELETED(sword) || owner.get_active_held_item() != sword || !isturf(owner.loc))
		return FALSE

	blade = sword
	origin = owner.loc
	destination = landing
	required_bond = bond
	new /obj/effect/temp_visual/decoy/legendary_liar/last_lie_fallen(origin, owner, blade)
	new /obj/effect/temp_visual/liar_glint(origin)
	playsound(origin, 'modular_bandastation/weapon/sound/melee/lz_last_lie_vanish.ogg', 50, FALSE)
	previous_invisibility = owner.invisibility
	owner.invisibility = INVISIBILITY_MAXIMUM
	ADD_TRAIT(owner, TRAIT_IMMOBILIZED, REF(src))
	RegisterSignal(owner, COMSIG_MOB_CLICKON, PROC_REF(block_click))
	RegisterSignals(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH), PROC_REF(interrupt))
	RegisterSignals(blade, list(COMSIG_ITEM_DROPPED, COMSIG_QDELETING, COMSIG_TWOHANDED_WIELD), PROC_REF(interrupt))
	addtimer(CALLBACK(src, PROC_REF(reappear)), 0.4 SECONDS, TIMER_DELETE_ME)
	return TRUE

/datum/status_effect/liar_last_lie/on_remove()
	if(!isnull(previous_invisibility))
		if(owner.invisibility == INVISIBILITY_MAXIMUM)
			owner.invisibility = previous_invisibility
		REMOVE_TRAIT(owner, TRAIT_IMMOBILIZED, REF(src))
		UnregisterSignal(owner, list(COMSIG_MOB_CLICKON, COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH))
	if(blade)
		UnregisterSignal(blade, list(COMSIG_ITEM_DROPPED, COMSIG_QDELETING, COMSIG_TWOHANDED_WIELD))
	blade = null
	origin = null
	destination = null

/datum/status_effect/liar_last_lie/proc/block_click()
	SIGNAL_HANDLER
	return COMSIG_MOB_CANCEL_CLICKON

/datum/status_effect/liar_last_lie/proc/interrupt()
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/liar_last_lie/proc/reappear()
	var/mob/living/carbon/wielder = owner
	var/turf/landing = destination
	if(QDELETED(wielder) || wielder.loc != origin || wielder.body_position != STANDING_UP || wielder.get_active_held_item() != blade)
		qdel(src)
		return
	if(HAS_TRAIT_NOT_FROM(wielder, TRAIT_IMMOBILIZED, REF(src)) || HAS_TRAIT(wielder, TRAIT_HANDS_BLOCKED) || !blade?.can_use_legendary_ability(wielder, required_bond, require_wielded = FALSE) || !legendary_sword_can_leap(wielder, landing))
		qdel(src)
		return
	var/escape_direction = liar_last_lie_escape_direction(landing, origin)
	if(!escape_direction)
		blade.balloon_alert(wielder, "двойнику некуда бежать")
		qdel(src)
		return

	var/obj/item/dualsaber/legendary_saber/sword = blade
	UnregisterSignal(wielder, COMSIG_MOVABLE_MOVED)
	wielder.forceMove(landing)
	qdel(src)
	if(QDELETED(wielder) || wielder.loc != landing)
		return
	var/turf/runner_tile = get_step(landing, escape_direction)
	new /obj/effect/temp_visual/decoy/legendary_liar/last_lie_runner(runner_tile, wielder, sword, escape_direction)
	new /obj/effect/temp_visual/liar_glint(landing)
	new /obj/effect/temp_visual/liar_glint(runner_tile)
	playsound(landing, 'modular_bandastation/weapon/sound/melee/lz_last_lie_return.ogg', 52, FALSE)

/obj/effect/temp_visual/liar_glint
	name = "золотая искра"
	icon_state = "mech_sparks"
	color = LIGHT_COLOR_DIM_YELLOW
	duration = 0.3 SECONDS

/// Prefer a full escape lane, then the longest one available. Break ties at random.
/proc/liar_last_lie_escape_direction(turf/landing, turf/origin)
	var/best_direction = NONE
	var/best_length = 1 // The first tile is for the runner to appear on.
	for(var/direction in shuffle(GLOB.cardinals))
		var/turf/current = landing
		var/length_clear = 0
		while(length_clear <= LIAR_LAST_LIE_RANGE)
			var/turf/next_tile = get_step(current, direction)
			if(!isopenturf(next_tile) || next_tile == origin || next_tile.is_blocked_turf() || !current.Adjacent(next_tile))
				break
			current = next_tile
			length_clear++
		if(length_clear == LIAR_LAST_LIE_RANGE + 1)
			return direction
		if(length_clear > best_length)
			best_length = length_clear
			best_direction = direction
	return best_direction

/obj/effect/temp_visual/decoy/legendary_liar/last_lie_fallen
	duration = LIAR_LAST_LIE_COPY_DURATION

/obj/effect/temp_visual/decoy/legendary_liar/last_lie_fallen/Initialize(mapload, mob/living/mimiced_atom, obj/item/dualsaber/legendary_saber/blade)
	. = ..()
	layer = LYING_MOB_LAYER
	var/matrix/prone = matrix(transform)
	prone.Turn(dir == EAST ? -90 : 90)
	var/fall_facing = (dir & (EAST|WEST)) ? SOUTH : dir
	animate(src, transform = prone, dir = fall_facing, pixel_y = pixel_y - 6, time = 0.3 SECONDS, easing = SINE_EASING)

/obj/effect/temp_visual/decoy/legendary_liar/last_lie_runner
	duration = LIAR_LAST_LIE_COPY_DURATION
	anchored = FALSE

/// Like a projected hologram, the copy has no momentum between its visible steps.
/obj/effect/temp_visual/decoy/legendary_liar/last_lie_runner/Process_Spacemove(movement_dir = 0, continuous_move = FALSE)
	return TRUE

/obj/effect/temp_visual/decoy/legendary_liar/last_lie_runner/Initialize(mapload, mob/living/mimiced_atom, obj/item/dualsaber/legendary_saber/blade, escape_direction)
	. = ..()
	setDir(escape_direction)
	addtimer(CALLBACK(src, PROC_REF(run_step), escape_direction, LIAR_LAST_LIE_RANGE), LIAR_LAST_LIE_RUN_DELAY, TIMER_DELETE_ME)

/obj/effect/temp_visual/decoy/legendary_liar/last_lie_runner/proc/run_step(escape_direction, steps_left)
	var/turf/current_tile = loc
	var/turf/next_tile = get_step(current_tile, escape_direction)
	if(!istype(current_tile) || !isopenturf(next_tile) || next_tile.is_blocked_turf() || !current_tile.Adjacent(next_tile))
		return
	if(Move(next_tile, escape_direction, DELAY_TO_GLIDE_SIZE(LIAR_LAST_LIE_RUN_DELAY)) && steps_left > 1)
		addtimer(CALLBACK(src, PROC_REF(run_step), escape_direction, steps_left - 1), LIAR_LAST_LIE_RUN_DELAY, TIMER_DELETE_ME)

#undef LIAR_LAST_LIE_RUN_DELAY
#undef LIAR_LAST_LIE_COPY_DURATION
#undef LIAR_LAST_LIE_RANGE

#define LIAR_FOUR_FACES_DURATION (5 SECONDS)
#define LIAR_FOUR_FACES_DAMAGE_FRACTION 0.05

/datum/action/cooldown/legendary_sword/liar_four_faces
	name = "Четыре лика"
	desc = "Окружите цель с тремя двойниками и займите случайную клетку среди них. Пять секунд двойники повторяют каждый ваш обычный взмах. Если цель в досягаемости двойника, он атакует с силой в 5% от урона клинка. Каждый удар можно заблокировать отдельно."
	button_icon = 'modular_bandastation/weapon/icons/melee/liar_abilities.dmi'
	button_icon_state = "liar_four_faces"
	required_bond = 100
	cooldown_time = 80 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/legendary_sword/liar_four_faces/Activate(atom/target)
	var/mob/living/user = owner
	var/mob/living/victim = target
	if(!istype(victim) || victim == user || victim.stat == DEAD || !isturf(victim.loc) || !(victim in view(3, user)) || HAS_TRAIT(user, TRAIT_PACIFISM) || HAS_TRAIT(user, TRAIT_IMMOBILIZED))
		return FALSE
	var/list/turf/positions = list()
	for(var/direction in GLOB.alldirs)
		var/turf/tile = get_step(victim, direction)
		if(tile?.Adjacent(victim) && legendary_sword_can_leap(user, tile))
			positions += tile
	if(length(positions) < 4)
		saber.balloon_alert(user, "мало места для двойников")
		return FALSE
	// The real fighter and the copies draw from the same tiles without replacement.
	var/turf/actual_position = pick_n_take(positions)
	StartCooldown()
	user.forceMove(actual_position)
	if(user.loc != actual_position || !saber.can_use_legendary_ability(user, required_bond))
		return TRUE
	user.setDir(get_dir(user, victim))
	user.apply_status_effect(/datum/status_effect/legendary_sword_sequence/liar_four_faces, saber, required_bond, positions, victim, src)
	return TRUE

/datum/status_effect/legendary_sword_sequence/liar_four_faces
	id = "liar_four_faces"
	tick_interval = STATUS_EFFECT_NO_TICK
	locks_manual_attacks = FALSE
	var/list/obj/effect/temp_visual/decoy/legendary_liar/doubles = list()
	/// Set by a normal attack and consumed by its actual animation.
	var/atom/swing_target
	var/swing_force = 0
	var/play_swing_sound = FALSE

/datum/status_effect/legendary_sword_sequence/liar_four_faces/on_apply(obj/item/dualsaber/legendary_saber/blade, required_bond, list/positions, mob/living/victim, datum/action/cooldown/legendary_sword/liar_four_faces/ability)
	if(!..() || QDELETED(victim) || QDELETED(ability))
		return FALSE
	for(var/count in 1 to 3)
		var/turf/decoy_position = pick_n_take(positions)
		var/obj/effect/temp_visual/decoy/legendary_liar/illusion = new(decoy_position, owner, saber)
		illusion.setDir(get_dir(illusion, victim))
		doubles += illusion
	playsound(victim, 'modular_bandastation/weapon/sound/melee/lz_four_faces_cast.ogg', 48, FALSE)
	RegisterSignal(ability, COMSIG_ACTION_REMOVED, PROC_REF(stop_sequence))
	RegisterSignals(saber, list(COMSIG_ITEM_ATTACK, COMSIG_ITEM_ATTACK_ATOM), PROC_REF(prepare_swing))
	RegisterSignal(saber, COMSIG_ITEM_ATTACK_ANIMATION, PROC_REF(mirror_swing))
	RegisterSignals(owner, list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY), PROC_REF(refresh_copies))
	addtimer(CALLBACK(src, PROC_REF(stop_sequence)), LIAR_FOUR_FACES_DURATION, TIMER_DELETE_ME)
	return TRUE

/datum/status_effect/legendary_sword_sequence/liar_four_faces/on_remove()
	if(saber)
		UnregisterSignal(saber, list(COMSIG_ITEM_ATTACK, COMSIG_ITEM_ATTACK_ATOM, COMSIG_ITEM_ATTACK_ANIMATION))
	if(owner)
		UnregisterSignal(owner, list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY))
	swing_target = null
	QDEL_LIST(doubles)
	return ..()

/datum/status_effect/legendary_sword_sequence/liar_four_faces/proc/prepare_swing(datum/source, atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(user != owner)
		return
	swing_target = null
	play_swing_sound = FALSE
	if(QDELETED(target) || target == owner || !islist(attack_modifiers) || !can_continue() || attack_modifiers[LEGENDARY_ABILITY_STRIKE] || attack_modifiers[AUTONOMOUS_MELEE_STRIKE])
		return
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion as anything in doubles)
		if(QDELETED(illusion))
			continue
		swing_target = target
		swing_force = CALCULATE_FORCE(saber, attack_modifiers)
		// The normal click delay has already started on a melee attack. Skip the real fighter's extra spin.
		attack_modifiers[AUTONOMOUS_MELEE_STRIKE] = TRUE
		if(isliving(target) && swing_force > 0 && !attack_modifiers[SILENCE_HITSOUND] && !attack_modifiers[REPLACE_MELEE_HIT_EFFECTS])
			play_swing_sound = TRUE
			attack_modifiers[SILENCE_HITSOUND] = TRUE
		return

/datum/status_effect/legendary_sword_sequence/liar_four_faces/proc/mirror_swing(datum/source, atom/movable/attacker, atom/target)
	SIGNAL_HANDLER
	if(attacker != owner || !swing_target || target != swing_target || QDELETED(target))
		return
	swing_target = null
	var/force = swing_force
	var/turf/impact = get_turf(target)
	if(impact && play_swing_sound)
		playsound(impact, 'modular_bandastation/weapon/sound/melee/lz_four_faces_hit.ogg', 52, FALSE)
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion as anything in doubles)
		if(QDELETED(illusion))
			continue
		var/swing_direction = get_dir(illusion, target) || illusion.dir
		var/facing = swing_direction
		if(ISDIAGONALDIR(facing))
			// A direct melee click uses the dominant axis, favoring east/west on ties.
			facing &= abs(target.x - illusion.x) < abs(target.y - illusion.y) ? (NORTH | SOUTH) : (EAST | WEST)
		illusion.setDir(facing)
		var/atom/aim = illusion.Adjacent(target) ? target : get_step(illusion, swing_direction)
		if(aim)
			illusion.do_attack_animation(aim, used_item = saber, fov_effect = FALSE)
	if(isliving(target) && force > 0 && can_continue())
		resolve_copy_hits(target, force)

/datum/status_effect/legendary_sword_sequence/liar_four_faces/proc/resolve_copy_hits(mob/living/victim, force)
	if(victim.mob_biotypes & (MOB_ROBOTIC | MOB_MINERAL | MOB_SKELETAL))
		force *= saber.get_demolition_modifier(victim)
	var/copy_damage = round(force * LIAR_FOUR_FACES_DAMAGE_FRACTION, DAMAGE_PRECISION)
	if(copy_damage <= 0)
		return
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion as anything in doubles)
		if(QDELETED(victim) || victim.stat == DEAD || !can_continue())
			return
		if(QDELETED(illusion) || !isturf(victim.loc) || !illusion.Adjacent(victim))
			continue
		if(victim.check_block(illusion, copy_damage, "удар двойника", MELEE_ATTACK, saber.armour_penetration, saber.damtype))
			continue
		var/zone = victim.get_random_valid_zone(check_zone(owner.zone_selected), victim.body_position == LYING_DOWN ? 90 : 80)
		var/armor = victim.run_armor_check(zone, MELEE, armour_penetration = saber.armour_penetration, weak_against_armour = saber.weak_against_armour, silent = TRUE)
		victim.apply_damage(copy_damage, saber.damtype, zone, min(armor, ARMOR_MAX_BLOCK), wound_bonus = CANT_WOUND, attack_direction = get_dir(illusion, victim), attacking_item = illusion, wound_clothing = FALSE)

/datum/status_effect/legendary_sword_sequence/liar_four_faces/proc/refresh_copies(datum/source, cache_index, changed_overlay)
	SIGNAL_HANDLER
	if(!changed_overlay)
		return
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion as anything in doubles)
		if(!QDELETED(illusion))
			illusion.overlays = owner.overlays

/obj/effect/temp_visual/decoy/legendary_liar
	duration = LIAR_FOUR_FACES_DURATION
	density = FALSE
	light_system = OVERLAY_LIGHT
	light_on = FALSE
	desc = null
	var/datum/weakref/wielder_ref

/obj/effect/temp_visual/decoy/legendary_liar/Initialize(mapload, mob/living/mimiced_atom, obj/item/dualsaber/legendary_saber/blade)
	. = ..()
	RegisterSignal(src, COMSIG_ATOM_PRE_BULLET_ACT, PROC_REF(disperse_on_projectile))
	mouse_opacity = MOUSE_OPACITY_ICON
	if(mimiced_atom)
		wielder_ref = WEAKREF(mimiced_atom)
	if(!QDELETED(blade))
		var/datum/component/overlay_lighting/blade_light = blade.GetComponent(/datum/component/overlay_lighting)
		if(blade_light?.light.currently_displaying && blade_light.light.current_holder == mimiced_atom)
			// The copied appearance already includes the held blade's light mask.
			underlays -= blade_light.light.visible_mask
		set_light_range_power_color(blade.light_range, blade.light_power, blade.light_color)
		set_light_on(blade.light_on)

/obj/effect/temp_visual/decoy/legendary_liar/examine(mob/user)
	var/mob/living/wielder = wielder_ref?.resolve()
	return wielder ? wielder.examine(user) : ..()

/obj/effect/temp_visual/decoy/legendary_liar/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !user.combat_mode || !user.Adjacent(src))
		return
	qdel(src)
	return TRUE

/obj/effect/temp_visual/decoy/legendary_liar/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(CALCULATE_FORCE(attacking_item, attack_modifiers) <= 0 || !user.Adjacent(src))
		return ..()
	qdel(src)
	return TRUE

/obj/effect/temp_visual/decoy/legendary_liar/proc/disperse_on_projectile(datum/source)
	SIGNAL_HANDLER
	qdel(src)
	return COMPONENT_BULLET_PIERCED

#undef LIAR_FOUR_FACES_DURATION
#undef LIAR_FOUR_FACES_DAMAGE_FRACTION
