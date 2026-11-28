// The fork's role defines are loaded after the base unit-test includes.
#define LIAR_TEST_OFFICER_ROLE "centcom_role_officer"
#define LIAR_TEST_TIME_TO_50_PERCENT (67.5 SECONDS)
#define LIAR_TEST_TIME_TO_FULL_BOND (157.5 SECONDS)

/datum/unit_test/legendary_sword_liar_registry/Run()
	var/obj/item/dualsaber/legendary_saber/liar/sword = EASY_ALLOCATE()
	var/list/bonds = list(
		/datum/action/cooldown/legendary_sword/liar_backstep = 0,
		/datum/action/cooldown/legendary_sword/liar_last_lie = 50,
		/datum/action/cooldown/legendary_sword/liar_four_faces = 100,
	)
	TEST_ASSERT_EQUAL(length(sword.actions), length(bonds), "Liar should grant three actions.")
	TEST_ASSERT_EQUAL(sword.reach, 5, "Liar lost its ordinary dash reach.")
	TEST_ASSERT_EQUAL(sword.attack_spin_chance, 50, "Liar lost its ordinary spin chance.")
	var/list/states = list()
	for(var/slot in 1 to length(bonds))
		var/action_type = bonds[slot]
		var/datum/action/cooldown/legendary_sword/ability = locate(action_type) in sword.actions
		TEST_ASSERT_NOTNULL(ability, "Liar did not grant [action_type].")
		TEST_ASSERT_EQUAL(sword.legendary_abilities[slot], action_type, "Wrong Liar ability in slot [slot].")
		TEST_ASSERT_EQUAL(ability.required_bond, bonds[action_type], "Incorrect bond tier for [action_type].")
		TEST_ASSERT(ability.button_icon_state in icon_states(ability.button_icon), "Missing icon for [action_type].")
		states |= ability.button_icon_state
	TEST_ASSERT_EQUAL(length(states), length(bonds), "Liar abilities reused an icon state.")

/datum/unit_test/legendary_sword_flee_liar
	var/datum/turf_reservation/lane

/datum/unit_test/legendary_sword_flee_liar/Destroy()
	QDEL_NULL(lane)
	return ..()

/datum/unit_test/legendary_sword_flee_liar/Run()
	lane = SSmapping.request_turf_block_reservation(22, 22, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(lane, "Could not reserve the Last Lie test floor.")
	var/turf/corner = lane.bottom_left_turfs[1]
	var/turf/origin = get_step(get_ranged_target_turf(corner, NORTH, 10), EAST)
	var/turf/destination = get_ranged_target_turf(origin, EAST, 8)
	var/turf/listening_tile = get_step(get_ranged_target_turf(origin, EAST, 4), SOUTH)
	var/mob/living/carbon/human/consistent/wielder = allocate(/mob/living/carbon/human/consistent, origin)
	var/mob/living/carbon/human/consistent/dark_star_audio_listener/listener = allocate(/mob/living/carbon/human/consistent/dark_star_audio_listener, listening_tile)
	var/obj/item/dualsaber/legendary_saber/liar/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = LIAR_TEST_OFFICER_ROLE
	sword.bond_meditation_time = LIAR_TEST_TIME_TO_50_PERCENT
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Liar.")
	sword.attack_self(wielder)
	var/datum/action/cooldown/legendary_sword/liar_last_lie/last_lie = locate() in sword.actions
	TEST_ASSERT(last_lie?.IsAvailable(), "The unlocked Last Lie was not available.")
	var/list/vanish_origins = listener.track_sound('modular_bandastation/weapon/sound/melee/lz_last_lie_vanish.ogg')
	var/list/return_origins = listener.track_sound('modular_bandastation/weapon/sound/melee/lz_last_lie_return.ogg')
	var/list/ordinary_unwields = listener.track_sound(sword.unwieldsound)
	var/list/ordinary_wields = listener.track_sound(sword.wieldsound)

	TEST_ASSERT(isturf(destination) && get_dist(origin, destination) == 8, "Last Lie needs a free tile eight steps away.")
	TEST_ASSERT(last_lie.Trigger(wielder), "The Last Lie button did not start targeting.")
	TEST_ASSERT(!last_lie.InterceptClickOn(wielder, null, get_step(destination, EAST)), "Last Lie accepted a tile nine steps away.")
	TEST_ASSERT_EQUAL(wielder.click_intercept, last_lie, "An invalid destination cancelled Last Lie targeting.")
	TEST_ASSERT(last_lie.IsAvailable() && !length(vanish_origins) && !length(return_origins), "An invalid destination consumed or played Last Lie.")
	var/original_invisibility = wielder.invisibility
	var/original_alpha = wielder.alpha
	var/obj/item/coin/marker = allocate(/obj/item/coin, destination)
	var/started_at = world.time
	TEST_ASSERT(last_lie.InterceptClickOn(wielder, null, marker), "Clicking a loose item did not select its open turf eight steps away.")
	TEST_ASSERT_NULL(wielder.click_intercept, "A successful Last Lie left the wielder in targeting mode.")
	TEST_ASSERT_EQUAL(wielder.loc, origin, "Last Lie skipped its disappearance.")
	TEST_ASSERT(wielder.invisibility > original_invisibility || !wielder.alpha, "Last Lie left the real wielder visible during the disappearance.")
	TEST_ASSERT(wielder.is_holding(sword) && !HAS_TRAIT(sword, TRAIT_WIELDED), "Last Lie should dim the blade and keep it in hand.")
	var/obj/effect/temp_visual/decoy/legendary_liar/last_lie_fallen/fallen = locate() in origin
	TEST_ASSERT_NOTNULL(fallen, "Last Lie did not leave a fallen copy at the original position.")
	TEST_ASSERT_EQUAL(length(vanish_origins), 1, "Last Lie did not play its disappearance cue once.")
	TEST_ASSERT_EQUAL(vanish_origins[1], origin, "The disappearance cue did not come from the original position.")
	TEST_ASSERT(!length(return_origins), "The return cue played before the wielder reappeared.")

	var/deadline = started_at + 1 SECONDS
	UNTIL(wielder.loc == destination || world.time >= deadline)
	TEST_ASSERT_EQUAL(wielder.loc, destination, "Last Lie did not land on the selected tile.")
	TEST_ASSERT(world.time >= started_at + 0.4 SECONDS, "Last Lie skipped its disappearance delay.")
	TEST_ASSERT_EQUAL(wielder.invisibility, original_invisibility, "Last Lie did not restore the wielder's visibility.")
	TEST_ASSERT_EQUAL(wielder.alpha, original_alpha, "Last Lie did not restore the wielder's opacity.")
	TEST_ASSERT(!HAS_TRAIT(sword, TRAIT_WIELDED), "Last Lie reignited the blade on return.")
	TEST_ASSERT_EQUAL(fallen.loc, origin, "The fallen copy left the original position when the wielder returned.")
	var/obj/effect/temp_visual/decoy/legendary_liar/last_lie_runner/runner = locate() in range(1, destination)
	TEST_ASSERT_NOTNULL(runner, "Last Lie did not create a running copy beside the selected tile.")
	var/turf/runner_start = get_turf(runner)
	TEST_ASSERT_EQUAL(get_dist(runner_start, destination), 1, "The running copy did not begin beside the wielder.")
	var/returned_at = world.time
	deadline = returned_at + 1 SECONDS
	UNTIL(runner.loc != runner_start || world.time >= deadline)
	TEST_ASSERT(!QDELETED(runner) && get_dist(runner, destination) > 1, "The running copy did not flee the landing area.")
	TEST_ASSERT_EQUAL(length(return_origins), 1, "Last Lie did not play its return cue once.")
	TEST_ASSERT_EQUAL(return_origins[1], destination, "The return cue did not come from the selected tile.")
	TEST_ASSERT(!length(ordinary_wields) && !length(ordinary_unwields), "Last Lie doubled its custom cues with ordinary saber switches.")
	var/datum/component/two_handed/grip = sword.GetComponent(/datum/component/two_handed)
	TEST_ASSERT_EQUAL(grip.wieldsound, sword.wieldsound, "Last Lie changed the ordinary wield sound.")
	TEST_ASSERT_EQUAL(grip.unwieldsound, sword.unwieldsound, "Last Lie changed the ordinary unwield sound.")

	var/turf/escape_end = get_ranged_target_turf(runner_start, get_dir(destination, runner_start), 8)
	deadline = returned_at + 3.2 SECONDS
	UNTIL(runner.loc == escape_end || world.time >= deadline)
	TEST_ASSERT_EQUAL(runner.loc, escape_end, "The copy reached ([runner.x],[runner.y]) instead of ([escape_end.x],[escape_end.y]) eight steps from its starting tile.")
	sleep(0.4 SECONDS)
	TEST_ASSERT_EQUAL(runner.loc, escape_end, "The copy ran a ninth step.")

	deadline = returned_at + 5 SECONDS
	UNTIL((QDELETED(fallen) && QDELETED(runner)) || world.time >= deadline)
	TEST_ASSERT(QDELETED(fallen) && QDELETED(runner), "Last Lie left a copy beyond its lifetime.")

	sword.attack_self(wielder)
	last_lie.ResetCooldown()
	var/turf/blocked_landing = get_step(destination, EAST)
	TEST_ASSERT(last_lie.Trigger(wielder, target = blocked_landing), "Last Lie did not begin a second cast.")
	TEST_ASSERT(HAS_TRAIT(wielder, TRAIT_IMMOBILIZED), "Last Lie let the hidden wielder walk away.")
	var/mob/living/carbon/human/consistent/blocker = allocate(/mob/living/carbon/human/consistent, blocked_landing)
	TEST_ASSERT(blocker.density && blocked_landing.is_blocked_turf(), "The new occupant did not block the selected landing.")
	deadline = world.time + 1 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/liar_last_lie) || world.time >= deadline)
	TEST_ASSERT_EQUAL(wielder.loc, destination, "Last Lie jumped onto a landing that became occupied.")
	TEST_ASSERT_EQUAL(wielder.invisibility, original_invisibility, "An interrupted Last Lie left the wielder invisible.")
	TEST_ASSERT(!HAS_TRAIT(wielder, TRAIT_IMMOBILIZED), "An interrupted Last Lie left the wielder immobilized.")
	TEST_ASSERT_EQUAL(length(return_origins), 1, "An interrupted Last Lie played a second return cue.")

	sword.attack_self(wielder)
	last_lie.ResetCooldown()
	TEST_ASSERT(last_lie.Trigger(wielder, target = origin), "Could not start Last Lie for the immobilization check.")
	ADD_TRAIT(wielder, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	deadline = world.time + 1 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/liar_last_lie) || world.time >= deadline)
	TEST_ASSERT_EQUAL(wielder.loc, destination, "Last Lie escaped an immobilization applied during disappearance.")
	TEST_ASSERT_EQUAL(wielder.invisibility, original_invisibility, "External immobilization left the wielder invisible.")
	TEST_ASSERT(HAS_TRAIT_FROM_ONLY(wielder, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS), "Last Lie changed another source of immobilization.")
	REMOVE_TRAIT(wielder, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)

/datum/unit_test/legendary_sword_liar_backstep
	var/datum/turf_reservation/lane
	var/list/strike_damage = list()

/datum/unit_test/legendary_sword_liar_backstep/Destroy()
	QDEL_NULL(lane)
	return ..()

/datum/unit_test/legendary_sword_liar_backstep/proc/record_strike(datum/source, damage_dealt, damage_type, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(istype(attacking_item, /obj/item/dualsaber/legendary_saber/liar))
		strike_damage += damage_dealt

/datum/unit_test/legendary_sword_liar_backstep/Run()
	lane = SSmapping.request_turf_block_reservation(8, 2, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(lane, "Could not reserve the Backstep test lane.")
	var/turf/origin = lane.bottom_left_turfs[1]
	var/turf/target_tile = get_ranged_target_turf(origin, EAST, 5)
	var/turf/west_landing = get_step(target_tile, WEST)
	var/turf/east_landing = get_step(target_tile, EAST)
	var/mob/living/carbon/human/consistent/wielder = allocate(/mob/living/carbon/human/consistent, origin)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, east_landing)
	var/mob/living/carbon/human/consistent/dark_star_audio_listener/listener = allocate(/mob/living/carbon/human/consistent/dark_star_audio_listener, get_step(target_tile, NORTH))
	var/obj/item/dualsaber/legendary_saber/liar/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = LIAR_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Liar.")
	sword.attack_self(wielder)
	sword.wound_bonus = CANT_WOUND
	sword.attack_spin_chance = 0
	var/list/jump_origins = listener.track_sound('modular_bandastation/weapon/sound/melee/lz_backstep_jump.ogg')
	var/list/impact_origins = listener.track_sound('modular_bandastation/weapon/sound/melee/lz_backstep_hit.ogg')
	var/list/ordinary_hits = listener.track_sound(sword.hit_wield)
	var/datum/action/cooldown/legendary_sword/liar_backstep/backstep = locate() in sword.actions
	TEST_ASSERT(backstep?.IsAvailable(), "Backstep should be available at zero bond.")
	TEST_ASSERT(!backstep.Trigger(wielder, target = victim), "Backstep accepted a target six tiles away.")
	victim.forceMove(target_tile)
	victim.setDir(EAST)
	var/obj/structure/window/barrier = allocate(/obj/structure/window, target_tile, WEST)
	TEST_ASSERT(!backstep.Trigger(wielder, target = victim) && backstep.IsAvailable(), "Backstep started with a window between the rear tile and the target.")
	qdel(barrier)
	victim.setDir(WEST)
	RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(record_strike))

	TEST_ASSERT(backstep.Trigger(wielder, target = victim), "Could not start the range check.")
	victim.forceMove(east_landing)
	var/deadline = world.time + 1 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/legendary_sword_sequence/liar_backstep) || world.time >= deadline)
	TEST_ASSERT(wielder.loc == origin && !length(strike_damage), "Backstep pursued a target beyond its range.")
	victim.forceMove(target_tile)
	backstep.ResetCooldown()
	TEST_ASSERT(backstep.Trigger(wielder, target = victim), "Backstep rejected a target five tiles away.")
	TEST_ASSERT_EQUAL(wielder.loc, origin, "Backstep skipped its opening windup.")
	deadline = world.time + 1 SECONDS
	UNTIL(length(strike_damage) >= 1 || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(strike_damage), 1, "Backstep did not strike once on the opening jump.")
	TEST_ASSERT_EQUAL(wielder.loc, east_landing, "The first jump did not land behind the target.")
	TEST_ASSERT_EQUAL(strike_damage[1], 18, "The opening Backstep strike dealt the wrong damage.")
	TEST_ASSERT(victim.get_bleed_rate() > 0, "The opening backstab did not cause bleeding.")

	victim.setDir(NORTH)
	sleep(0.45 SECONDS + world.tick_lag)
	TEST_ASSERT_EQUAL(length(strike_damage), 1, "A turn away from the wielder triggered a follow-up.")
	TEST_ASSERT_EQUAL(wielder.loc, east_landing, "The wielder jumped without the target turning toward them.")

	victim.face_atom(wielder)
	deadline = world.time + 0.75 SECONDS
	UNTIL(length(strike_damage) >= 2 || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(strike_damage), 2, "The first turn toward the wielder did not trigger one follow-up.")
	TEST_ASSERT_EQUAL(wielder.loc, west_landing, "The second jump did not use the target's new rear tile.")
	TEST_ASSERT_EQUAL(strike_damage[2], 18, "The second Backstep strike dealt the wrong damage.")

	victim.face_atom(wielder)
	deadline = world.time + 0.75 SECONDS
	UNTIL(length(strike_damage) >= 3 || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(strike_damage), 3, "The second turn toward the wielder did not trigger one follow-up.")
	TEST_ASSERT_EQUAL(wielder.loc, east_landing, "The third jump did not land behind the target.")
	TEST_ASSERT_EQUAL(strike_damage[3], 18, "The third Backstep strike dealt the wrong damage.")
	TEST_ASSERT_EQUAL(length(jump_origins), 3, "Backstep did not play exactly one cue per jump.")
	TEST_ASSERT_EQUAL(length(impact_origins), 3, "Backstep did not play exactly one cue per impact.")
	TEST_ASSERT_EQUAL(jump_origins[1], east_landing, "The opening cue did not come from the landing.")
	TEST_ASSERT_EQUAL(jump_origins[2], west_landing, "The first follow-up cue did not come from the landing.")
	TEST_ASSERT_EQUAL(jump_origins[3], east_landing, "The final cue did not come from the landing.")
	for(var/turf/impact as anything in impact_origins)
		TEST_ASSERT_EQUAL(impact, target_tile, "A Backstep hit played outside the target's tile.")
	TEST_ASSERT(!length(ordinary_hits), "Backstep doubled its impact cue with the ordinary saber sound.")
	victim.face_atom(wielder)
	sleep(0.45 SECONDS + world.tick_lag)
	TEST_ASSERT_EQUAL(length(strike_damage), 3, "Backstep allowed a fourth strike.")

	var/mob/living/carbon/human/consistent/second_victim = allocate(/mob/living/carbon/human/consistent, west_landing)
	victim.forceMove(get_step(target_tile, NORTH))
	second_victim.setDir(WEST)
	wielder.forceMove(origin)
	backstep.ResetCooldown()
	RegisterSignal(second_victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(record_strike))
	TEST_ASSERT(backstep.Trigger(wielder, target = second_victim), "Could not start the disarm test.")
	second_victim.forceMove(target_tile)
	deadline = world.time + 1 SECONDS
	UNTIL(length(strike_damage) >= 4 || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(strike_damage), 4, "The disarm test did not land the first strike.")
	second_victim.face_atom(wielder)
	TEST_ASSERT(wielder.dropItemToGround(sword), "Could not disarm the wielder after the target turned.")
	sleep(0.45 SECONDS + world.tick_lag)
	TEST_ASSERT_EQUAL(length(strike_damage), 4, "The queued follow-up landed after disarmament.")
	TEST_ASSERT_EQUAL(wielder.loc, east_landing, "The queued jump moved the wielder after disarmament.")

/datum/unit_test/legendary_sword_liar_four_faces
	var/datum/turf_reservation/arena
	var/list/decoys = list()
	var/list/strike_damage = list()
	var/list/copy_damage = list()
	var/list/swing_sources = list()

/datum/unit_test/legendary_sword_liar_four_faces/Destroy()
	QDEL_LIST(decoys)
	QDEL_NULL(arena)
	return ..()

/datum/unit_test/legendary_sword_liar_four_faces/proc/record_strike(datum/source, damage_dealt, damage_type, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(istype(attacking_item, /obj/item/dualsaber/legendary_saber/liar))
		strike_damage += damage_dealt
	else if(attacking_item in decoys)
		copy_damage += round(damage_dealt, DAMAGE_PRECISION)

/datum/unit_test/legendary_sword_liar_four_faces/proc/record_swing(datum/source, atom/movable/swinger)
	SIGNAL_HANDLER
	swing_sources += swinger

/datum/unit_test/legendary_sword_liar_four_faces/proc/block_strike()
	SIGNAL_HANDLER
	return SUCCESSFUL_BLOCK

/datum/unit_test/legendary_sword_liar_four_faces/proc/block_sword_and_one_copy(datum/source, atom/hit_by)
	SIGNAL_HANDLER
	return (istype(hit_by, /obj/item/dualsaber/legendary_saber/liar) || hit_by == decoys[2]) ? SUCCESSFUL_BLOCK : NONE

/datum/unit_test/legendary_sword_liar_four_faces/proc/click_when_ready(mob/living/wielder, mob/living/victim)
	sleep(max(world.tick_lag, max(wielder.next_move, wielder.next_click) - world.time + world.tick_lag))
	wielder.ClickOn(victim)

/datum/unit_test/legendary_sword_liar_four_faces/Run()
	arena = SSmapping.request_turf_block_reservation(7, 3, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(arena, "Could not reserve the Four Faces arena.")
	var/turf/corner = arena.bottom_left_turfs[1]
	var/turf/start = get_step(get_step(corner, EAST), NORTH)
	var/turf/target_tile = get_ranged_target_turf(start, EAST, 3)
	var/mob/living/carbon/human/consistent/wielder = allocate(/mob/living/carbon/human/consistent, start)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, target_tile)
	var/mob/living/carbon/human/consistent/dark_star_audio_listener/listener = allocate(/mob/living/carbon/human/consistent/dark_star_audio_listener, start)
	var/obj/item/dualsaber/legendary_saber/liar/sword = EASY_ALLOCATE()
	wielder.mind_initialize()
	wielder.mind.centcom_role = LIAR_TEST_OFFICER_ROLE
	sword.bond_meditation_time = LIAR_TEST_TIME_TO_FULL_BOND
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Liar.")
	sword.attack_self(wielder)
	wielder.set_combat_mode(TRUE)
	sword.force = 20
	sword.wound_bonus = CANT_WOUND
	var/list/cast_origins = listener.track_sound('modular_bandastation/weapon/sound/melee/lz_four_faces_cast.ogg')
	var/list/impact_origins = listener.track_sound('modular_bandastation/weapon/sound/melee/lz_four_faces_hit.ogg')
	var/list/ordinary_hits = listener.track_sound(sword.hit_wield)
	RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(record_strike))
	RegisterSignal(sword, COMSIG_ITEM_ATTACK_ANIMATION, PROC_REF(record_swing))

	var/datum/action/cooldown/legendary_sword/liar_four_faces/likeness = locate() in sword.actions
	ADD_TRAIT(wielder, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!likeness?.Trigger(wielder, target = victim), "Four Faces activated while the wielder was immobilized.")
	TEST_ASSERT_EQUAL(wielder.loc, start, "Four Faces moved an immobilized wielder.")
	REMOVE_TRAIT(wielder, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	var/start_time = world.time
	TEST_ASSERT(likeness?.Trigger(wielder, target = victim), "Could not activate Four Faces.")
	TEST_ASSERT_EQUAL(length(cast_origins), 1, "Four Faces did not play one appearance cue.")
	TEST_ASSERT_EQUAL(cast_origins[1], target_tile, "The appearance sound reveals the real Liar's position.")
	TEST_ASSERT(wielder.Adjacent(victim) && wielder.loc != target_tile, "Liar did not land next to the target.")
	var/list/occupied = list(wielder.loc)
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion in range(1, target_tile))
		decoys += illusion
		TEST_ASSERT(illusion.loc != target_tile && !(illusion.loc in occupied), "A likeness shares another figure's tile.")
		occupied += illusion.loc
		TEST_ASSERT_EQUAL(illusion.name, wielder.name, "A likeness reveals itself by name.")
		TEST_ASSERT_EQUAL(illusion.dir, get_dir(illusion, victim), "A likeness did not face the target.")
		TEST_ASSERT_EQUAL(illusion.light_on, sword.light_on, "A likeness reveals itself by having an unlit blade.")
		TEST_ASSERT_EQUAL(illusion.light_range, sword.light_range, "A likeness does not match the blade's light range.")
		TEST_ASSERT_EQUAL(illusion.light_power, sword.light_power, "A likeness does not match the blade's light power.")
		TEST_ASSERT_EQUAL(illusion.light_color, sword.light_color, "A likeness does not match the blade's light color.")
		TEST_ASSERT_EQUAL(length(illusion.underlays), length(wielder.underlays), "A likeness duplicated the held blade's light mask.")
	TEST_ASSERT_EQUAL(length(decoys), 3, "Four Faces did not create three distinct likenesses.")

	var/obj/item/clothing/head/beret/hat = EASY_ALLOCATE()
	TEST_ASSERT(wielder.equip_to_slot_if_possible(hat, ITEM_SLOT_HEAD), "Could not equip the test beret.")
	var/mutable_appearance/hat_overlay = wielder.overlays_standing[HEAD_LAYER]
	TEST_ASSERT_NOTNULL(hat_overlay, "The wielder did not display the beret.")
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion as anything in decoys)
		TEST_ASSERT(hat_overlay.appearance in illusion.overlays, "A likeness did not display the newly equipped beret.")
	TEST_ASSERT(wielder.dropItemToGround(hat), "Could not remove the test beret.")
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion as anything in decoys)
		TEST_ASSERT(!(hat_overlay.appearance in illusion.overlays), "A likeness kept the removed beret.")

	sleep(1 SECONDS)
	TEST_ASSERT(!length(strike_damage) && !length(copy_damage) && !length(swing_sources), "Four Faces attacked before a manual sword swing.")
	var/list/figures = decoys + wielder
	for(var/attack in 1 to 3)
		if(attack == 2)
			var/obj/effect/temp_visual/decoy/legendary_liar/distant_copy = decoys[1]
			distant_copy.forceMove(corner)
			sword.force = 30
			RegisterSignal(victim, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(block_sword_and_one_copy))
		if(attack == 3)
			UnregisterSignal(victim, COMSIG_LIVING_CHECK_BLOCK)
			RegisterSignal(victim, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(block_strike))
		var/previous_swings = length(swing_sources)
		click_when_ready(wielder, victim)
		var/list/this_attack = swing_sources.Copy(previous_swings + 1)
		TEST_ASSERT_EQUAL(length(this_attack), 4, "Each manual swing, including a blocked one, should animate four figures.")
		for(var/atom/movable/figure as anything in figures)
			TEST_ASSERT(figure in this_attack, "A figure did not mirror a manual swing.")
		TEST_ASSERT(wielder.next_move > world.time, "Four Faces removed the ordinary click cooldown.")
		if(attack == 1)
			TEST_ASSERT_EQUAL(length(copy_damage), 3, "Each of the three adjacent copies should land one hit.")
			for(var/damage in copy_damage)
				TEST_ASSERT_EQUAL(damage, 1, "A likeness should deal 5% of a 20-force swing.")
		if(attack == 2)
			TEST_ASSERT_EQUAL(length(impact_origins), 2, "Four Faces should play one sound per swing.")
			TEST_ASSERT_EQUAL(length(strike_damage), 1, "The real sword bypassed its parry.")
			TEST_ASSERT_EQUAL(length(copy_damage), 4, "The nearby, unblocked likeness should deal damage even when the real sword is parried.")
			TEST_ASSERT_EQUAL(copy_damage[4], 1.5, "The surviving hit did not follow the new 30-force swing.")
	UnregisterSignal(victim, COMSIG_LIVING_CHECK_BLOCK)
	TEST_ASSERT_EQUAL(length(impact_origins), 3, "Four Faces did not play one cue per mirrored swing.")
	TEST_ASSERT(!length(ordinary_hits), "Four Faces doubled its blend with the ordinary hit sound.")
	TEST_ASSERT_EQUAL(length(strike_damage), 1, "Only the first manual attack should bypass the shield.")
	TEST_ASSERT_EQUAL(strike_damage[1], 20, "Four Faces changed the first manual hit.")
	TEST_ASSERT_EQUAL(length(copy_damage), 4, "A likeness bypassed the full block.")
	for(var/turf/origin as anything in impact_origins)
		TEST_ASSERT_EQUAL(origin, target_tile, "The hit sound reveals the real Liar's position.")

	sleep(max(world.tick_lag, start_time + 4.8 SECONDS - world.time))
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion as anything in decoys)
		TEST_ASSERT(!QDELETED(illusion), "A likeness vanished before five seconds.")
	TEST_ASSERT_EQUAL(length(swing_sources), 12, "A likeness swung independently of the wielder.")
	sleep(max(world.tick_lag, start_time + 5.3 SECONDS - world.time))
	for(var/obj/effect/temp_visual/decoy/legendary_liar/illusion as anything in decoys)
		TEST_ASSERT(QDELETED(illusion), "A likeness remained after its lifetime.")
	click_when_ready(wielder, victim)
	TEST_ASSERT_EQUAL(length(swing_sources), 13, "The expired ability still mirrored a sword swing.")
	TEST_ASSERT_EQUAL(length(strike_damage), 2, "The sword could not attack normally after the ability expired.")
	TEST_ASSERT_EQUAL(length(copy_damage), 4, "The expired ability still dealt damage through its likenesses.")
	TEST_ASSERT_EQUAL(length(impact_origins), 3, "The expired ability still played its swing cue.")
	TEST_ASSERT_EQUAL(length(ordinary_hits), 1, "Liar did not resume its ordinary sound after Four Faces expired.")

#undef LIAR_TEST_TIME_TO_FULL_BOND
#undef LIAR_TEST_TIME_TO_50_PERCENT
#undef LIAR_TEST_OFFICER_ROLE
