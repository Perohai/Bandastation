// The fork's role defines are loaded after the base unit-test includes.
#define DARK_STAR_TEST_OFFICER_ROLE "centcom_role_officer"

/datum/unit_test/legendary_sword_dark_star_registry/Run()
	var/obj/item/dualsaber/legendary_saber/dark_star/sword = EASY_ALLOCATE()
	var/list/bond_by_action = list(
		/datum/action/cooldown/legendary_sword/star_judgment_cut = 0,
		/datum/action/cooldown/legendary_sword/star_phantom_blades = 50,
		/datum/action/cooldown/legendary_sword/star_void_slash = 50,
		/datum/action/cooldown/legendary_sword/star_deep_stinger = 100,
		/datum/action/cooldown/legendary_sword/star_eclipse_double = 100,
	)
	TEST_ASSERT_EQUAL(length(sword.actions), length(bond_by_action), "Dark Star should grant five actions.")
	TEST_ASSERT_EQUAL(sword.reach, 5, "Dark Star lost its five-tile reach.")
	TEST_ASSERT_EQUAL(sword.attack_spin_chance, 50, "Dark Star lost its ordinary spin chance.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(45 SECONDS), 25, "First Dark Star bond milestone has the wrong timing.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(135 SECONDS), 50, "Second Dark Star bond milestone has the wrong timing.")
	TEST_ASSERT_EQUAL(sword.get_legendary_bond(315 SECONDS), 100, "Final Dark Star bond milestone has the wrong timing.")
	for(var/slot in 1 to length(bond_by_action))
		var/expected = bond_by_action[slot]
		var/datum/action/cooldown/legendary_sword/action = locate(expected) in sword.actions
		TEST_ASSERT_NOTNULL(action, "Dark Star did not grant [expected].")
		TEST_ASSERT_EQUAL(sword.legendary_abilities[slot], expected, "Wrong Dark Star ability in slot [slot].")
		TEST_ASSERT_EQUAL(action.required_bond, bond_by_action[expected], "Incorrect bond tier for [expected].")
		TEST_ASSERT(action.button_icon_state in icon_states(action.button_icon), "Missing icon for [expected].")

/// Record each selected cue at the turf supplied by the spatial sound dispatcher.
/mob/living/carbon/human/consistent/dark_star_audio_listener
	var/list/tracked_sounds

/mob/living/carbon/human/consistent/dark_star_audio_listener/proc/track_sound(sound_file)
	if(!tracked_sounds)
		tracked_sounds = list()
		enable_client_mobs_in_contents()
	var/list/origins = list()
	tracked_sounds["[sound_file]"] = origins
	return origins

/mob/living/carbon/human/consistent/dark_star_audio_listener/playsound_local(turf/turf_source, soundin, vol as num, vary, frequency, falloff_exponent = SOUND_FALLOFF_EXPONENT, channel = 0, pressure_affected = TRUE, sound/sound_to_use, max_distance, falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE, distance_multiplier = 1, use_reverb = TRUE, wait = FALSE, datum/preference/numeric/volume/volume_preference = null, min_volume = 5)
	var/list/origins = tracked_sounds?["[soundin]"]
	origins?.Add(turf_source)
	return ..()

/mob/living/carbon/human/consistent/dark_star_audio_listener/Destroy()
	if(tracked_sounds)
		clear_important_client_contents()
	return ..()

/datum/unit_test/legendary_sword_judgment_cut
	var/datum/turf_reservation/lane
	var/list/hit_targets = list()
	var/first_hit_time
	var/hit_direction
	var/obj/item/bodypart/last_hit_limb
	var/initial_wound_flow

/datum/unit_test/legendary_sword_judgment_cut/Destroy()
	QDEL_LIST(allocated)
	QDEL_NULL(lane)
	return ..()

/datum/unit_test/legendary_sword_judgment_cut/proc/record_hit(datum/source, damage, damage_type, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(damage > 0 && istype(attacking_item, /obj/item/dualsaber/legendary_saber/dark_star))
		hit_targets += source
		first_hit_time ||= world.time
		hit_direction = attack_direction
		last_hit_limb = def_zone

/// Sample the wound at impact, before a mob life tick can clot it.
/datum/unit_test/legendary_sword_judgment_cut/proc/record_wound_flow()
	SIGNAL_HANDLER
	var/datum/wound/slash/flesh/severe/gash = locate() in last_hit_limb?.wounds
	initial_wound_flow = gash?.blood_flow

/datum/unit_test/legendary_sword_judgment_cut/Run()
	// The shared test room is only five tiles wide.
	lane = SSmapping.request_turf_block_reservation(7, 2, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(lane, "Could not reserve the range test lane.")
	var/turf/origin = lane.bottom_left_turfs[1]
	var/turf/fifth_tile = get_ranged_target_turf(origin, EAST, 5)
	var/turf/sixth_tile = get_step(fifth_tile, EAST)
	var/turf/side_tile = get_step(fifth_tile, NORTH)
	var/mob/living/carbon/human/consistent/dark_star_audio_listener/wielder = allocate(/mob/living/carbon/human/consistent/dark_star_audio_listener, origin)
	var/list/cut_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_judgment_cut.ogg')
	var/mob/living/carbon/human/consistent/runner = allocate(/mob/living/carbon/human/consistent, fifth_tile)
	var/mob/living/carbon/human/consistent/replacement = allocate(/mob/living/carbon/human/consistent, origin)
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, side_tile)
	var/mob/living/carbon/human/consistent/corpse = allocate(/mob/living/carbon/human/consistent, fifth_tile)
	corpse.death()
	var/obj/item/dualsaber/legendary_saber/dark_star/sword = allocate(/obj/item/dualsaber/legendary_saber/dark_star, origin)
	sword.wound_bonus = CANT_WOUND // A random leg wound adds its own slowdown.
	wielder.mind_initialize()
	wielder.mind.centcom_role = DARK_STAR_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Dark Star.")
	sword.attack_self(wielder)
	var/datum/action/cooldown/legendary_sword/star_judgment_cut/cut = locate() in sword.actions
	TEST_ASSERT_NOTNULL(cut, "Dark Star did not grant Judgment Cut.")
	TEST_ASSERT(!cut.Trigger(wielder, target = fifth_tile), "Judgment Cut accepted a bare tile.")
	TEST_ASSERT(!cut.Trigger(wielder, target = wielder), "Judgment Cut accepted its own wielder.")
	TEST_ASSERT(!cut.Trigger(wielder, target = corpse), "Judgment Cut accepted a dead target.")
	runner.forceMove(sixth_tile)
	TEST_ASSERT(!cut.Trigger(wielder, target = runner), "Judgment Cut accepted a target six tiles away.")
	var/turf/closed_tile = get_step(origin, NORTH)
	closed_tile = closed_tile.ChangeTurf(/turf/closed/indestructible)
	runner.forceMove(closed_tile)
	TEST_ASSERT(!cut.Trigger(wielder, target = runner), "Judgment Cut accepted a target inside a solid wall.")
	runner.forceMove(fifth_tile)
	var/obj/structure/falsewall/screen = allocate(/obj/structure/falsewall, get_step(origin, EAST))
	TEST_ASSERT(!cut.Trigger(wielder, target = runner), "Judgment Cut targeted someone hidden behind a wall.")
	qdel(screen)

	for(var/mob/living/participant as anything in list(wielder, runner, replacement, bystander, corpse))
		RegisterSignal(participant, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_hit))
	var/run_delay = runner.cached_multiplicative_slowdown
	var/bystander_delay = bystander.cached_multiplicative_slowdown
	var/started_at = world.time
	TEST_ASSERT(cut.Trigger(wielder, target = runner), "Could not mark a target five tiles away at zero bond.")
	TEST_ASSERT_EQUAL(length(cut_sounds), 0, "Judgment Cut played its release sound during windup.")
	var/obj/effect/dark_star_swing/swing = locate() in wielder.vis_contents
	TEST_ASSERT_NOTNULL(swing, "The wielder did not show the blade swing.")
	RegisterSignal(swing, COMSIG_QDELETING, PROC_REF(record_wound_flow))
	var/right_hand = wielder.get_hand_zone_of_item(sword) == BODY_ZONE_R_ARM
	TEST_ASSERT_EQUAL(swing.icon_state, right_hand ? "swing_right" : "swing_left", "The swing used the wrong hand.")
	TEST_ASSERT(swing.icon_state in icon_states(swing.icon), "The swing has no frames for the wielder's hand.")
	TEST_ASSERT_EQUAL(swing.dir, EAST, "The wielder swung away from the selected target.")
	var/hand_file = right_hand ? sword.righthand_file : sword.lefthand_file
	var/mutable_appearance/held_blade = sword.build_worn_icon(default_icon_file = hand_file, isinhands = TRUE)
	TEST_ASSERT_NULL(held_blade.icon, "The stationary blade overlapped the swing.")
	var/obj/effect/temp_visual/dark_star_cut/mark = locate() in runner.vis_contents
	TEST_ASSERT_NOTNULL(mark, "The selected runner did not display the warning.")
	runner.forceMove(side_tile)
	replacement.forceMove(fifth_tile)
	TEST_ASSERT(mark in runner.vis_contents, "Moving detached the warning from the selected runner.")
	var/deadline = started_at + 3 SECONDS
	UNTIL(length(hit_targets) || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(hit_targets), 1, "The cut should hit only one target, even with bystanders on both tiles.")
	TEST_ASSERT_EQUAL(hit_targets[1], runner, "The cut hit someone other than the marked runner.")
	TEST_ASSERT_EQUAL(hit_direction, get_dir(wielder, runner), "Projected damage must arrive from the wielder's direction.")
	TEST_ASSERT(length(cut_sounds) == 1 && cut_sounds[1] == side_tile, "Judgment Cut did not play once on the runner's new tile.")
	TEST_ASSERT_EQUAL(last_hit_limb?.owner, runner, "The cut did not damage a limb belonging to its target.")
	TEST_ASSERT_EQUAL(initial_wound_flow, WOUND_MAX_BLOODFLOW, "The damaged limb did not receive a severe cut with maximum initial blood flow.")
	TEST_ASSERT(last_hit_limb.cached_bleed_rate >= BLEED_OVERLAY_GUSH, "The struck limb was not bleeding heavily.")
	TEST_ASSERT_EQUAL(bystander.get_bleed_rate() + replacement.get_bleed_rate(), 0, "The cut caused someone on the old or new tile to bleed.")
	var/blood_after_hit = runner.get_blood_volume()
	TEST_ASSERT(locate(/obj/effect/temp_visual/dark_star_cut/hit) in runner.vis_contents, "The cut effect did not appear on the runner.")
	TEST_ASSERT(first_hit_time >= started_at + 0.7 SECONDS, "The cut landed before its warning elapsed.")
	TEST_ASSERT_EQUAL(wielder.loc, origin, "The ranged cut moved its wielder.")
	TEST_ASSERT(QDELETED(swing), "The swing stayed on the wielder after the cut landed.")
	held_blade = sword.build_worn_icon(default_icon_file = hand_file, isinhands = TRUE)
	TEST_ASSERT_EQUAL(held_blade.icon, hand_file, "The stationary blade did not return after the cut.")
	var/slow_modifier = /datum/movespeed_modifier/status_effect/dark_star_cut
	TEST_ASSERT(runner.has_movespeed_modifier(slow_modifier), "The damaging cut did not apply its movement penalty.")
	var/expected_delay = run_delay + 3 * CONFIG_GET(number/movedelay/run_delay)
	TEST_ASSERT(abs(runner.cached_multiplicative_slowdown - expected_delay) < 0.02, "The struck runner's step delay was [runner.cached_multiplicative_slowdown], expected [expected_delay].")
	TEST_ASSERT(!bystander.has_movespeed_modifier(slow_modifier), "The cut applied its movement penalty to a bystander.")
	TEST_ASSERT_EQUAL(bystander.cached_multiplicative_slowdown, bystander_delay, "The cut slowed someone sharing the target's tile.")
	deadline = first_hit_time + 4 SECONDS
	UNTIL(!runner.has_movespeed_modifier(slow_modifier) || world.time >= deadline)
	TEST_ASSERT(!runner.has_movespeed_modifier(slow_modifier), "The movement penalty outlasted its three-second window.")
	TEST_ASSERT_EQUAL(runner.cached_multiplicative_slowdown, run_delay, "The runner's regular speed did not return after three seconds.")
	TEST_ASSERT(world.time >= first_hit_time + 3 SECONDS - SSfastprocess.wait, "The runner recovered before the three-second slow expired.")
	deadline = world.time + 3 SECONDS
	UNTIL(runner.get_blood_volume() < blood_after_hit || world.time >= deadline)
	TEST_ASSERT(runner.get_blood_volume() < blood_after_hit, "The bleeding wound did not drain blood after impact.")

	cut.ResetCooldown()
	TEST_ASSERT(cut.Trigger(wielder, target = runner), "Could not mark the runner before they left range.")
	runner.forceMove(sixth_tile)
	sleep(0.7 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hit_targets), 1, "The cut hit after its target left range.")
	TEST_ASSERT(!runner.has_movespeed_modifier(slow_modifier), "The missed cut slowed the runner.")

	cut.ResetCooldown()
	runner.forceMove(fifth_tile)
	TEST_ASSERT(cut.Trigger(wielder, target = runner), "Could not mark the runner before they took cover.")
	screen = allocate(/obj/structure/falsewall, get_step(origin, EAST))
	sleep(0.7 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hit_targets), 1, "The cut hit through cover raised during the windup.")
	TEST_ASSERT_EQUAL(length(cut_sounds), 1, "Judgment Cut played its release after the mark left range or sight.")
	qdel(screen)

	cut.ResetCooldown()
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot, side_tile)
	shield.block_chance = 150
	TEST_ASSERT(bystander.put_in_active_hand(shield), "Could not equip the blocking target.")
	var/shielded_delay = bystander.cached_multiplicative_slowdown
	TEST_ASSERT(cut.Trigger(wielder, target = bystander), "Could not mark the shielded target.")
	deadline = world.time + 3 SECONDS
	UNTIL(shield.get_integrity() < shield.max_integrity || world.time >= deadline)
	TEST_ASSERT(shield.get_integrity() < shield.max_integrity, "The shield did not intercept the cut.")
	TEST_ASSERT_EQUAL(length(hit_targets), 1, "The parried cut still damaged its target.")
	TEST_ASSERT(!bystander.has_movespeed_modifier(slow_modifier), "The parried cut applied its movement penalty.")
	TEST_ASSERT_EQUAL(bystander.cached_multiplicative_slowdown, shielded_delay, "The parried cut slowed its target.")
	TEST_ASSERT_EQUAL(bystander.get_bleed_rate(), 0, "The parried cut made the shield bearer bleed.")

	// Melee chooses a hit zone, so every possible zone must start with the existing critical wound.
	for(var/obj/item/bodypart/limb as anything in replacement.get_bodyparts())
		limb.force_wound_upwards(/datum/wound/slash/flesh/critical)
	cut.ResetCooldown()
	TEST_ASSERT(cut.Trigger(wielder, target = replacement), "Could not mark the already wounded target.")
	deadline = world.time + 3 SECONDS
	UNTIL(length(hit_targets) == 2 || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(hit_targets), 2, "The cut missed the already wounded target.")
	TEST_ASSERT(locate(/datum/wound/slash/flesh/critical) in last_hit_limb.wounds, "The cut downgraded the critical wound on the damaged limb.")

	replacement.set_species(/datum/species/android)
	cut.ResetCooldown()
	TEST_ASSERT(cut.Trigger(wielder, target = replacement), "Could not mark a target with mechanical limbs.")
	deadline = world.time + 3 SECONDS
	UNTIL(length(hit_targets) == 3 || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(hit_targets), 3, "The cut did not damage the mechanical target.")
	TEST_ASSERT((last_hit_limb.bodytype & BODYTYPE_ROBOTIC) && last_hit_limb.owner == replacement, "The cut did not strike a real mechanical bodypart.")
	TEST_ASSERT_NULL(locate(/datum/wound/slash/flesh) in last_hit_limb.wounds, "The struck mechanical part received a flesh wound.")
	TEST_ASSERT_EQUAL(last_hit_limb.cached_bleed_rate, 0, "The struck mechanical part bled.")

	cut.ResetCooldown()
	var/sounds_before_disarm = length(cut_sounds)
	TEST_ASSERT(cut.Trigger(wielder, target = runner), "Could not mark a target before dropping the sword.")
	swing = locate() in wielder.vis_contents
	TEST_ASSERT_NOTNULL(swing, "A second cut did not restart the swing.")
	wielder.dropItemToGround(sword)
	TEST_ASSERT(QDELETED(swing), "Dropping the sword left its swing on the wielder.")
	sleep(0.7 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hit_targets), 3, "The cut still landed after the wielder dropped Dark Star.")
	TEST_ASSERT_EQUAL(length(cut_sounds), sounds_before_disarm, "Disarming Judgment Cut did not silence its pending release.")

/datum/unit_test/legendary_sword_phantom_blades
	var/datum/turf_reservation/lane
	var/list/hits = list()
	var/last_hit_time
	var/last_damage
	var/obj/effect/dark_star_swing/command/release_gesture

/datum/unit_test/legendary_sword_phantom_blades/Destroy()
	QDEL_LIST(allocated)
	QDEL_NULL(lane)
	return ..()

/datum/unit_test/legendary_sword_phantom_blades/proc/record_hit(datum/source, damage, damage_type, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(istype(attacking_item, /obj/item/dualsaber/legendary_saber/dark_star))
		hits += source
		last_damage = damage
		last_hit_time = world.time
		if(length(hits) == 1)
			var/mob/living/wielder = attacking_item.loc
			release_gesture = locate() in wielder.vis_contents

/datum/unit_test/legendary_sword_phantom_blades/Run()
	lane = SSmapping.request_turf_block_reservation(7, 2, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(lane, "Could not reserve the Phantom Blades test lane.")
	var/turf/origin = lane.bottom_left_turfs[1]
	var/turf/caster_destination = get_step(origin, NORTH)
	var/turf/fifth_tile = get_ranged_target_turf(origin, EAST, 5)
	var/turf/target_destination = get_step(fifth_tile, NORTH)
	var/turf/sixth_tile = get_step(target_destination, EAST)
	var/mob/living/carbon/human/consistent/dark_star_audio_listener/wielder = allocate(/mob/living/carbon/human/consistent/dark_star_audio_listener, origin)
	var/list/volley_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_phantom_volley.ogg')
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, fifth_tile)
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, target_destination)
	var/obj/item/dualsaber/legendary_saber/dark_star/sword = allocate(/obj/item/dualsaber/legendary_saber/dark_star, origin)
	wielder.mind_initialize()
	wielder.mind.centcom_role = DARK_STAR_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Dark Star.")
	sword.attack_self(wielder)
	sword.wound_bonus = CANT_WOUND
	var/datum/action/cooldown/legendary_sword/star_phantom_blades/blades = locate() in sword.actions
	TEST_ASSERT_NOTNULL(blades, "Dark Star did not grant Phantom Blades.")
	TEST_ASSERT_EQUAL(sword.legendary_abilities[2], blades.type, "Phantom Blades did not occupy the second slot.")
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS - 1
	TEST_ASSERT(!blades.Trigger(wielder, target = victim), "Phantom Blades activated below 50% bond.")
	sword.bond_meditation_time++
	TEST_ASSERT(!blades.Trigger(wielder, target = fifth_tile), "Phantom Blades accepted a bare tile.")
	TEST_ASSERT(!blades.Trigger(wielder, target = wielder), "Phantom Blades targeted their own wielder.")
	for(var/mob/living/participant as anything in list(wielder, victim, bystander))
		RegisterSignal(participant, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_hit))

	// A modified blade detects fixed damage. Resistance keeps both hits below any limb's cap.
	sword.force = 28
	victim.damage_resistance = 75
	wielder.set_combat_mode(TRUE)
	victim.forceMove(get_step(origin, EAST))
	sword.melee_attack_chain(wielder, victim)
	TEST_ASSERT_EQUAL(length(hits), 1, "The comparison melee attack did not land once.")
	var/ordinary_damage = last_damage
	TEST_ASSERT_EQUAL(ordinary_damage, 7, "The comparison attack did not use the wielded blade's current force.")
	hits.Cut()
	victim.forceMove(fifth_tile)
	var/start_time = world.time
	var/health_before = victim.health
	TEST_ASSERT(blades.Trigger(wielder, target = victim), "Could not mark the fifth tile's occupant at 50% bond.")
	TEST_ASSERT_EQUAL(length(volley_sounds), 0, "Phantom Blades played its volley sound before convergence.")
	TEST_ASSERT_EQUAL(blades.next_use_time, start_time + 45 SECONDS, "Phantom Blades started the wrong cooldown.")
	var/obj/effect/temp_visual/dark_star_blades/ring = locate() in victim.vis_contents
	TEST_ASSERT_NOTNULL(ring, "The marked target did not display the blade ring.")
	TEST_ASSERT(wielder.Move(caster_destination, NORTH), "The caster could not walk during the windup.")
	victim.forceMove(target_destination)
	TEST_ASSERT(ring in victim.vis_contents, "Moving detached the ring from the selected target.")
	var/deadline = world.time + 3 SECONDS
	UNTIL(length(hits) || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(hits), 1, "Four convergence blades should resolve as one hit.")
	TEST_ASSERT_EQUAL(hits[1], victim, "The blades struck someone other than the marked target.")
	TEST_ASSERT(length(volley_sounds) == 1 && volley_sounds[1] == target_destination, "The four converging blades should play once on the marked enemy's new tile.")
	TEST_ASSERT_EQUAL(last_damage, 4 * ordinary_damage, "The joint hit should deal four times this blade's ordinary melee damage.")
	TEST_ASSERT(victim.health < health_before, "The unshielded target lost no health to the blades.")
	TEST_ASSERT_NOTNULL(release_gesture, "The wielder did not display a command gesture as the blades hit.")
	var/expected_pose = wielder.get_hand_zone_of_item(sword) == BODY_ZONE_R_ARM ? "command_right" : "command_left"
	TEST_ASSERT_EQUAL(release_gesture.icon_state, expected_pose, "The command gesture used the wrong hand.")
	TEST_ASSERT(expected_pose in icon_states(release_gesture.icon), "The command gesture has no sprite for the wielding hand.")
	TEST_ASSERT_EQUAL(release_gesture.dir, EAST, "The command gesture did not point at the target.")
	TEST_ASSERT(last_hit_time >= start_time + 1 SECONDS, "The blades converged before the warning ended.")
	TEST_ASSERT_EQUAL(wielder.loc, caster_destination, "The ranged hit moved its caster.")
	TEST_ASSERT(QDELETED(ring), "The warning ring survived the hit.")
	TEST_ASSERT(locate(/obj/effect/temp_visual/dark_star_blades/strike) in victim.vis_contents, "The convergence animation missed the moving target.")

	blades.ResetCooldown()
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot, target_destination)
	shield.block_chance = 200
	TEST_ASSERT(bystander.put_in_active_hand(shield), "Could not equip the shield bearer.")
	TEST_ASSERT(blades.Trigger(wielder, target = bystander), "Could not target the shield bearer.")
	deadline = world.time + 3 SECONDS
	UNTIL(QDELETED(shield) || shield.get_integrity() < shield.max_integrity || world.time >= deadline)
	TEST_ASSERT(QDELETED(release_gesture), "The first command gesture remained on the wielder through the next volley.")
	TEST_ASSERT(QDELETED(shield) || shield.get_integrity() < shield.max_integrity, "The shield failed to intercept the blades.")
	TEST_ASSERT_EQUAL(length(hits), 1, "The blocked hit still damaged the shield bearer.")

	blades.ResetCooldown()
	TEST_ASSERT(blades.Trigger(wielder, target = victim), "Could not mark a target about to leave range.")
	victim.forceMove(sixth_tile)
	sleep(1 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hits), 1, "The blades hit after the target left range.")

	blades.ResetCooldown()
	TEST_ASSERT(!blades.Trigger(wielder, target = victim), "Phantom Blades accepted a target six tiles away.")
	victim.forceMove(target_destination)
	TEST_ASSERT(blades.Trigger(wielder, target = victim), "Could not mark a target about to take cover.")
	var/obj/structure/falsewall/screen = allocate(/obj/structure/falsewall, get_step(caster_destination, EAST))
	sleep(1 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hits), 1, "The blades struck through cover.")
	qdel(screen)

	blades.ResetCooldown()
	TEST_ASSERT(blades.Trigger(wielder, target = victim), "Could not mark a target about to disappear.")
	ring = locate() in victim.vis_contents
	qdel(victim)
	sleep(1 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT(QDELETED(ring) && length(hits) == 1, "A deleted target left a ring or redirected the attack.")

	blades.ResetCooldown()
	if(!QDELETED(shield))
		bystander.dropItemToGround(shield)
	TEST_ASSERT(blades.Trigger(wielder, target = bystander), "Could not mark a target before disarm.")
	ring = locate() in bystander.vis_contents
	wielder.dropItemToGround(sword)
	TEST_ASSERT(QDELETED(ring), "Dropping the sword left the blade ring on its target.")
	sleep(1 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hits), 1, "The blades hit after their wielder dropped the sword.")
	TEST_ASSERT_EQUAL(length(volley_sounds), 2, "Only the released volleys against the target and shield should be audible.")

/datum/unit_test/legendary_sword_void_slash
	var/list/hits = list()
	var/list/hit_amounts = list()
	var/list/pull_times = list()
	var/first_hit_time
	var/first_pose_dir
	var/last_hit_time

/datum/unit_test/legendary_sword_void_slash/proc/record_hit(datum/source, damage, damage_type, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(!istype(attacking_item, /obj/item/dualsaber/legendary_saber/dark_star))
		return
	if(!length(hits))
		first_hit_time = world.time
		var/mob/living/wielder = attacking_item.loc
		var/obj/effect/dark_star_swing/void_slash/pose = locate() in wielder.vis_contents
		first_pose_dir = pose?.dir
	hits += source
	hit_amounts += damage
	last_hit_time = world.time

/datum/unit_test/legendary_sword_void_slash/proc/record_pull_step()
	SIGNAL_HANDLER
	pull_times += world.time

/datum/unit_test/legendary_sword_void_slash/Run()
	var/turf/origin = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/turf/front_tile = get_ranged_target_turf(origin, EAST, 3)
	var/turf/edge_tile = get_ranged_target_turf(origin, NORTHEAST, 2)
	var/turf/guard_tile = get_step(get_step(origin, EAST), SOUTHEAST)
	var/turf/rear_tile = get_step(origin, WEST)
	var/mob/living/carbon/human/consistent/dark_star_audio_listener/wielder = allocate(/mob/living/carbon/human/consistent/dark_star_audio_listener, origin)
	var/list/open_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_void_open.ogg')
	var/list/collapse_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_void_collapse.ogg')
	var/mob/living/carbon/human/consistent/front = allocate(/mob/living/carbon/human/consistent, front_tile)
	var/mob/living/carbon/human/consistent/edge = allocate(/mob/living/carbon/human/consistent, edge_tile)
	var/mob/living/carbon/human/consistent/adjacent = allocate(/mob/living/carbon/human/consistent, get_step(origin, SOUTHEAST))
	var/mob/living/carbon/human/consistent/out_of_range = allocate(/mob/living/carbon/human/consistent, get_step(edge_tile, NORTHEAST))
	var/mob/living/carbon/human/consistent/guard = allocate(/mob/living/carbon/human/consistent, guard_tile)
	var/mob/living/carbon/human/consistent/latecomer = allocate(/mob/living/carbon/human/consistent, rear_tile)
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot, guard_tile)
	shield.block_chance = 150
	TEST_ASSERT(guard.put_in_active_hand(shield), "Could not equip the defender's shield.")
	var/obj/item/dualsaber/legendary_saber/dark_star/sword = allocate(/obj/item/dualsaber/legendary_saber/dark_star, origin)
	wielder.mind_initialize()
	wielder.mind.centcom_role = DARK_STAR_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Dark Star.")
	sword.attack_self(wielder)
	wielder.set_combat_mode(TRUE)
	sword.force = 12
	sword.wound_bonus = CANT_WOUND
	var/datum/action/cooldown/legendary_sword/star_void_slash/slash = locate() in sword.actions
	TEST_ASSERT_NOTNULL(slash, "Dark Star did not grant Void Slash.")
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS - 1
	TEST_ASSERT(!slash.Trigger(wielder, target = front_tile), "Void Slash activated below 50% bond.")
	sword.bond_meditation_time++
	for(var/mob/living/participant as anything in list(front, edge, adjacent, out_of_range, guard, latecomer, wielder))
		RegisterSignal(participant, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_hit))
	for(var/mob/living/target as anything in list(front, edge, adjacent, guard))
		target.damage_resistance = 50
	front.forceMove(get_step(origin, EAST))
	sword.melee_attack_chain(wielder, front)
	TEST_ASSERT_EQUAL(length(hits), 1, "The ordinary comparison attack did not land once.")
	var/ordinary_damage = hit_amounts[1]
	TEST_ASSERT_EQUAL(ordinary_damage, 6, "The comparison attack did not use the modified sword force and target resistance.")
	hits.Cut()
	hit_amounts.Cut()
	front.forceMove(front_tile)

	var/start_time = world.time
	TEST_ASSERT(slash.Trigger(wielder, target = front_tile), "Could not aim Void Slash at a floor tile at 50% bond.")
	TEST_ASSERT_EQUAL(length(open_sounds), 0, "The rift played its opening sound during the stance.")
	TEST_ASSERT_EQUAL(slash.next_use_time, start_time + 25 SECONDS, "Void Slash started the wrong cooldown.")
	var/deadline = start_time + 2 SECONDS
	UNTIL(length(hits) || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(hits), 3, "The opening should hit the three unshielded targets in its arc once each.")
	TEST_ASSERT((front in hits) && (edge in hits) && (adjacent in hits), "The sector missed its rim or hit someone outside it.")
	for(var/amount in hit_amounts)
		TEST_ASSERT_EQUAL(amount, ordinary_damage, "The opening did not deal one ordinary hit per target.")
	TEST_ASSERT(first_hit_time >= start_time + 0.5 SECONDS, "The slash hit before the stance ended.")
	TEST_ASSERT_EQUAL(first_pose_dir, EAST, "The wielder did not swing in the chosen direction.")
	var/obj/effect/temp_visual/dark_star_void_slash/rift = locate() in origin
	TEST_ASSERT_NOTNULL(rift, "The open slash did not appear on the wielder's tile.")
	TEST_ASSERT(length(open_sounds) == 1 && open_sounds[1] == origin && !length(collapse_sounds), "Opening the rift on several targets should play one opening sound at the wielder.")
	var/slow = /datum/movespeed_modifier/status_effect/dark_star_void
	TEST_ASSERT(front.has_movespeed_modifier(slow) && edge.has_movespeed_modifier(slow), "Someone damaged by the slash was not slowed.")
	var/shield_damage = shield.max_integrity - shield.get_integrity()
	TEST_ASSERT(shield_damage > 0, "The shield did not intercept the slash.")
	TEST_ASSERT(!guard.has_movespeed_modifier(slow) && !latecomer.has_movespeed_modifier(slow), "The slash slowed a blocked or rear target.")

	// Only the diagonal target's return path is closed after the opening strike.
	var/list/walls = list()
	for(var/direction in list(WEST, SOUTHWEST, SOUTH))
		walls += allocate(/obj/structure/falsewall, get_step(edge_tile, direction))
	latecomer.forceMove(guard_tile)
	RegisterSignal(front, COMSIG_MOVABLE_MOVED, PROC_REF(record_pull_step))
	deadline = first_hit_time + 3 SECONDS
	UNTIL(get_dist(front, wielder) == 1 || world.time >= deadline)
	UnregisterSignal(front, COMSIG_MOVABLE_MOVED)
	TEST_ASSERT_EQUAL(front.loc, get_step(origin, EAST), "The furthest target did not stop next to the wielder.")
	TEST_ASSERT_EQUAL(length(pull_times), 2, "The furthest target should be pulled in two ordinary steps.")
	TEST_ASSERT(pull_times[1] >= first_hit_time + 1.3 SECONDS && pull_times[2] >= pull_times[1] + 0.2 SECONDS, "The pull started early or skipped the interval between steps.")
	TEST_ASSERT(get_dist(edge, wielder) >= 2, "The diagonal target was pulled through a solid wall.")
	TEST_ASSERT(guard.loc == guard_tile && latecomer.loc == guard_tile, "The collapse pulled a blocked target or a late arrival.")
	TEST_ASSERT(!front.has_movespeed_modifier(slow) && !edge.has_movespeed_modifier(slow), "The slow survived the collapse.")
	deadline = world.time + 1 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/dark_star_sequence/void_slash) || world.time >= deadline)
	TEST_ASSERT(QDELETED(rift), "The open slash survived its collapse.")
	TEST_ASSERT(length(collapse_sounds) == 1 && collapse_sounds[1] == origin, "The rift should play one collapse sound at the wielder across both pull steps.")
	TEST_ASSERT_EQUAL(length(hits), 4, "Only the target that actually moved should take one additional hit across both pull steps.")
	TEST_ASSERT_EQUAL(hits[4], front, "The collapse damaged a blocked, adjacent, or unmarked target.")
	TEST_ASSERT_EQUAL(hit_amounts[4], ordinary_damage, "The pull did not deal one ordinary hit.")
	TEST_ASSERT_EQUAL(last_hit_time, pull_times[1], "The second hit should land with the first successful pull step.")
	QDEL_LIST(walls)
	for(var/mob/living/bystander as anything in list(edge, adjacent, latecomer))
		bystander.forceMove(rear_tile)

	front.forceMove(edge_tile)
	guard.forceMove(front_tile)
	TEST_ASSERT(guard.dropItemToGround(shield), "Could not lower the shield before the next opening.")
	slash.ResetCooldown()
	TEST_ASSERT(slash.Trigger(wielder, target = front_tile), "Could not start the second two-target pull.")
	deadline = world.time + 2 SECONDS
	UNTIL(guard.has_movespeed_modifier(slow) || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(hits), 6, "The second opening should wound both targets.")
	TEST_ASSERT(guard.put_in_active_hand(shield), "Could not raise the shield between the opening and collapse.")
	var/shield_before_pull = shield.get_integrity()
	deadline = world.time + 3 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/dark_star_sequence/void_slash) || world.time >= deadline)
	TEST_ASSERT_EQUAL(guard.loc, get_step(origin, EAST), "The shield bearer did not traverse both pull steps.")
	TEST_ASSERT_EQUAL(shield_before_pull - shield.get_integrity(), shield_damage, "The pull should strike the shield once across both steps.")
	TEST_ASSERT_EQUAL(length(hits), 7, "The protected pull should damage only the other target.")
	TEST_ASSERT(hits[7] == front && hit_amounts[7] == ordinary_damage, "Blocking one pull prevented the other target from taking its ordinary hit.")
	guard.forceMove(rear_tile)

	for(var/drop_sword in list(FALSE, TRUE))
		wielder.forceMove(origin)
		front.forceMove(front_tile)
		var/hits_before_cast = length(hits)
		slash.ResetCooldown()
		TEST_ASSERT(slash.Trigger(wielder, target = front), "Aiming at a character did not start another slash.")
		deadline = world.time + 2 SECONDS
		UNTIL(front.has_movespeed_modifier(slow) || world.time >= deadline)
		TEST_ASSERT(front.has_movespeed_modifier(slow), "The slash did not open before the interruption.")
		rift = locate() in origin
		TEST_ASSERT_NOTNULL(rift, "The interrupted cast never displayed its slash.")
		if(drop_sword)
			wielder.dropItemToGround(sword)
		else
			TEST_ASSERT(wielder.Move(get_step(origin, NORTH), NORTH), "The wielder could not leave the stance.")
		TEST_ASSERT(QDELETED(rift) && !front.has_movespeed_modifier(slow), "Interrupting Void Slash left its visual or slowdown active.")
		sleep(1.5 SECONDS + 2 * world.tick_lag)
		TEST_ASSERT_EQUAL(front.loc, front_tile, "An interrupted slash still pulled its target.")
		TEST_ASSERT_EQUAL(length(hits), hits_before_cast + 1, "An interrupted slash should deal only the opening hit.")
		TEST_ASSERT_EQUAL(length(collapse_sounds), 2, "An interrupted rift played a collapse sound.")

/datum/unit_test/legendary_sword_deep_stinger
	var/datum/turf_reservation/lane
	var/list/hit_targets = list()
	var/list/hit_amounts = list()
	var/list/hit_times = list()
	var/list/steps = list()
	var/list/step_times = list()
	var/knockdown_amount
	var/shield_hits = 0

/datum/unit_test/legendary_sword_deep_stinger/Destroy()
	QDEL_LIST(allocated)
	QDEL_NULL(lane)
	return ..()

/datum/unit_test/legendary_sword_deep_stinger/proc/record_hit(datum/source, damage, damage_type, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(istype(attacking_item, /obj/item/dualsaber/legendary_saber/dark_star))
		hit_targets += source
		hit_amounts += damage
		hit_times += world.time

/datum/unit_test/legendary_sword_deep_stinger/proc/record_step(atom/movable/source)
	SIGNAL_HANDLER
	steps += get_turf(source)
	step_times += world.time

/datum/unit_test/legendary_sword_deep_stinger/proc/record_knockdown(datum/source, amount)
	SIGNAL_HANDLER
	knockdown_amount = amount

/datum/unit_test/legendary_sword_deep_stinger/proc/record_block()
	SIGNAL_HANDLER
	shield_hits++

/datum/unit_test/legendary_sword_deep_stinger/Run()
	lane = SSmapping.request_turf_block_reservation(22, 7, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(lane, "Could not reserve the Deep Stinger lane.")
	var/turf/origin = get_ranged_target_turf(get_ranged_target_turf(lane.bottom_left_turfs[1], EAST, 2), NORTH, 3)
	var/turf/enemy_tile = get_ranged_target_turf(origin, EAST, 5)
	var/turf/impact_tile = get_ranged_target_turf(enemy_tile, EAST, 11)
	var/turf/wall = get_step(impact_tile, EAST)
	wall.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/consistent/dark_star_audio_listener/wielder = allocate(/mob/living/carbon/human/consistent/dark_star_audio_listener, origin)
	var/list/launch_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_stinger_launch.ogg')
	var/list/pulse_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_stinger_pulse.ogg')
	var/list/wall_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_stinger_wall.ogg')
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, get_step(origin, EAST))
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, get_step(enemy_tile, NORTH))
	var/obj/item/dualsaber/legendary_saber/dark_star/sword = allocate(/obj/item/dualsaber/legendary_saber/dark_star, origin)
	wielder.mind_initialize()
	wielder.mind.centcom_role = DARK_STAR_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Dark Star.")
	sword.attack_self(wielder)
	wielder.set_combat_mode(TRUE)
	var/datum/action/cooldown/legendary_sword/star_deep_stinger/stinger = locate() in sword.actions
	TEST_ASSERT_NOTNULL(stinger, "Dark Star did not grant Deep Stinger.")
	TEST_ASSERT_EQUAL(sword.legendary_abilities[4], stinger.type, "Deep Stinger did not occupy the fourth slot.")
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS + 3 MINUTES - 1
	TEST_ASSERT(!stinger.Trigger(wielder, target = victim), "Deep Stinger activated below full bond.")
	sword.bond_meditation_time++

	// Measure the equipped blade against this same target, below a limb's damage cap.
	sword.force = 12
	sword.wound_bonus = CANT_WOUND
	victim.damage_resistance = 75
	for(var/mob/living/participant as anything in list(victim, bystander))
		RegisterSignal(participant, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_hit))
	sword.melee_attack_chain(wielder, victim)
	TEST_ASSERT_EQUAL(length(hit_amounts), 1, "The comparison strike did not land once.")
	var/ordinary_damage = hit_amounts[1]
	TEST_ASSERT_EQUAL(ordinary_damage, 3, "The comparison strike did not use the sword's current force.")
	victim.forceMove(get_step(enemy_tile, EAST))
	TEST_ASSERT(!stinger.Trigger(wielder, target = victim), "Deep Stinger accepted an enemy six tiles away.")
	victim.forceMove(enemy_tile)
	TEST_ASSERT(!stinger.Trigger(wielder, target = enemy_tile), "Deep Stinger accepted an empty targeting coordinate.")
	TEST_ASSERT(!stinger.Trigger(wielder, target = wielder), "Deep Stinger accepted its wielder.")
	var/turf/bystander_start = bystander.loc
	victim.start_pulling(bystander)
	TEST_ASSERT_EQUAL(victim.pulling, bystander, "The target could not grab the bystander before the charge.")
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(record_step))
	RegisterSignal(victim, COMSIG_LIVING_STATUS_KNOCKDOWN, PROC_REF(record_knockdown))
	var/start_time = world.time
	TEST_ASSERT(stinger.Trigger(wielder, target = victim), "Deep Stinger failed to launch at full range.")
	TEST_ASSERT_EQUAL(length(launch_sounds), 0, "The launch played before Deep Stinger's windup ended.")
	TEST_ASSERT_EQUAL(stinger.next_use_time, start_time + 90 SECONDS, "Deep Stinger started the wrong cooldown.")
	var/datum/status_effect/dark_star_sequence/deep_stinger/sequence = wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger)
	TEST_ASSERT_NOTNULL(sequence, "The charge did not start.")

	var/direct_damage = wielder.apply_damage(20, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = WEST, attacking_item = sword)
	TEST_ASSERT_EQUAL(direct_damage, 1, "A direct attack bypassed Deep Stinger protection.")
	var/ongoing_damage = wielder.apply_damage(10, BURN, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(ongoing_damage, 10, "Deep Stinger reduced an ongoing burn.")
	var/deadline = world.time + 12 SECONDS
	UNTIL(QDELETED(sequence) || world.time >= deadline)
	TEST_ASSERT(QDELETED(sequence), "The charge failed to finish.")
	var/hits_after_wall = length(hit_targets)
	TEST_ASSERT(hits_after_wall >= 5, "The long drive needs an initial hit, repeated damage while moving, and a wall impact.")
	TEST_ASSERT(length(launch_sounds) == 1 && launch_sounds[1] == origin, "The drive should launch once from the wielder's starting tile.")
	TEST_ASSERT(length(pulse_sounds) == hits_after_wall - 2 && pulse_sounds[1] == enemy_tile, "Deep Stinger should pulse on contact and on each living damage pulse, independent of movement steps.")
	TEST_ASSERT(length(wall_sounds) == 1 && wall_sounds[1] == impact_tile, "The wall impact should play once at the victim's final tile.")
	for(var/contact in 2 to hits_after_wall)
		TEST_ASSERT_EQUAL(hit_targets[contact], victim, "Deep Stinger damaged a bystander.")
		if(contact == hits_after_wall)
			TEST_ASSERT_EQUAL(hit_amounts[contact], 4 * ordinary_damage, "The wall impact did not deal four times the ordinary damage.")
			break
		TEST_ASSERT_EQUAL(hit_amounts[contact], 2 * ordinary_damage, "The contact or periodic hit did not deal twice the ordinary damage.")
		if(contact > 2)
			var/interval = hit_times[contact] - hit_times[contact - 1]
			TEST_ASSERT(interval >= 0.4 SECONDS && interval <= 0.4 SECONDS + 0.15 SECONDS + 2 * world.tick_lag, "Periodic damage took [interval] deciseconds between hits.")
	TEST_ASSERT(hit_times[2] >= start_time + 0.4 SECONDS, "Deep Stinger hit before the windup ended.")
	TEST_ASSERT_EQUAL(length(steps), 11, "The push failed to cover the entire lane one tile at a time.")
	var/turf/previous = enemy_tile
	for(var/index in 1 to length(steps))
		TEST_ASSERT_EQUAL(steps[index], get_step(previous, EAST), "The target left the original push direction or skipped a tile.")
		if(index > 1)
			var/interval = step_times[index] - step_times[index - 1]
			TEST_ASSERT(interval >= 0.15 SECONDS && interval <= 0.15 SECONDS + 2 * world.tick_lag, "A push step took [interval] deciseconds.")
		previous = steps[index]
	UnregisterSignal(victim, COMSIG_MOVABLE_MOVED)
	TEST_ASSERT_EQUAL(victim.loc, impact_tile, "The victim did not stop against the closed wall.")
	TEST_ASSERT_EQUAL(bystander.loc, bystander_start, "The victim dragged a bystander along with the blade.")
	TEST_ASSERT_EQUAL(wielder.loc, get_step(impact_tile, WEST), "The wielder did not follow directly behind the victim.")
	var/impact_delay = hit_times[hits_after_wall] - step_times[length(steps)]
	TEST_ASSERT(impact_delay >= 0.15 SECONDS && impact_delay <= 0.15 SECONDS + 2 * world.tick_lag, "The wall impact took [impact_delay] deciseconds after the last tile move.")
	TEST_ASSERT_EQUAL(knockdown_amount, 3 SECONDS, "Wall impact requested the wrong knockdown duration.")
	TEST_ASSERT(victim.IsKnockdown() && !bystander.IsKnockdown(), "The wall impact did not knock down just the victim.")
	deadline = world.time + 5 SECONDS
	UNTIL(!victim.IsKnockdown() || world.time >= deadline)
	TEST_ASSERT(!victim.IsKnockdown(), "The target never recovered from the wall impact.")

	// The first charge exercised zero gravity. Run the remaining encounters under station gravity.
	for(var/mob/living/participant as anything in list(wielder, victim, bystander))
		participant.AddElement(/datum/element/forced_gravity, STANDARD_GRAVITY)
	wielder.forceMove(origin)
	victim.forceMove(enemy_tile)
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot, enemy_tile)
	shield.block_chance = 200
	TEST_ASSERT(victim.put_in_active_hand(shield), "Could not equip the defender's shield.")
	RegisterSignal(shield, COMSIG_ATOM_TAKE_DAMAGE, PROC_REF(record_block))
	stinger.ResetCooldown()
	TEST_ASSERT(stinger.Trigger(wielder, target = victim), "Could not charge the shield bearer.")
	deadline = world.time + 12 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger) || world.time >= deadline)
	TEST_ASSERT_EQUAL(shield_hits, 1, "Only the initial contact should reach the shield.")
	TEST_ASSERT_EQUAL(length(pulse_sounds), hits_after_wall - 1, "The blocked capture should play exactly one contact pulse.")
	TEST_ASSERT_EQUAL(length(hit_targets), hits_after_wall, "The blocked contact damaged a mob.")
	TEST_ASSERT(victim.loc == enemy_tile && !victim.IsKnockdown(), "Blocking the charge did not prevent the push and knockdown.")

	wielder.forceMove(origin)
	stinger.ResetCooldown()
	TEST_ASSERT(stinger.Trigger(wielder, target = victim), "Could not start the obstructed charge.")
	var/obj/structure/window/reinforced/fulltile/barrier = allocate(/obj/structure/window/reinforced/fulltile, get_ranged_target_turf(origin, EAST, 2))
	deadline = world.time + 3 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger) || world.time >= deadline)
	TEST_ASSERT(!wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger) && wielder.x < barrier.x, "The charge crossed a closed window or failed to stop.")
	TEST_ASSERT_EQUAL(shield_hits, 1, "The charge reached the target through a closed window.")
	qdel(barrier)

	wielder.forceMove(origin)
	TEST_ASSERT(victim.dropItemToGround(shield), "Could not remove the shield for the moving-target charge.")
	stinger.ResetCooldown()
	TEST_ASSERT(stinger.Trigger(wielder, target = victim), "Could not mark the enemy about to move.")
	bystander.forceMove(enemy_tile)
	var/turf/new_target_tile = get_step(enemy_tile, NORTH)
	TEST_ASSERT(victim.Move(new_target_tile, NORTH), "The marked enemy could not leave the bystander's tile.")
	deadline = world.time + 3 SECONDS
	UNTIL(victim.loc != new_target_tile || world.time >= deadline)
	TEST_ASSERT(victim.loc != new_target_tile, "The first hit failed to carry the marked enemy away.")
	TEST_ASSERT_EQUAL(length(hit_targets), hits_after_wall + 1, "Expected one initial hit on the moving enemy.")
	TEST_ASSERT_EQUAL(hit_targets[hits_after_wall + 1], victim, "The charge struck the replacement on the old tile.")
	TEST_ASSERT(wielder.dropItemToGround(sword), "Could not disarm the wielder after the first contact.")
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger), "Disarming the wielder left the charge active.")
	var/sidestep = turn(get_dir(wielder, victim), 90)
	TEST_ASSERT(!victim.IsKnockdown() && victim.Move(get_step(victim, sidestep), sidestep), "The released target could not walk away.")
	var/turf/escaped_tile = victim.loc
	sleep(1 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(victim.loc, escaped_tile, "The charge kept pushing after the target escaped.")
	TEST_ASSERT_EQUAL(length(hit_targets), hits_after_wall + 1, "The drive kept dealing damage after disarmament.")

	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Dark Star again.")
	sword.attack_self(wielder)
	wielder.forceMove(origin)
	var/turf/fatal_contact = get_ranged_target_turf(origin, EAST, 3)
	var/turf/corpse_stop = get_ranged_target_turf(fatal_contact, EAST, 3)
	var/turf/corpse_wall = get_step(corpse_stop, EAST)
	corpse_wall.ChangeTurf(/turf/closed/wall)
	victim.forceMove(fatal_contact)
	bystander.forceMove(get_step(fatal_contact, NORTH))
	victim.damage_resistance = 0
	victim.adjust_tox_loss(victim.health - victim.dead_threshold - 10, forced = TRUE)
	TEST_ASSERT(victim.stat != DEAD, "The injured target died before the charge.")
	stinger.ResetCooldown()
	TEST_ASSERT(stinger.Trigger(wielder, target = victim), "Could not target the critically injured enemy.")
	deadline = world.time + 3 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger) || world.time >= deadline)
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "The first charge contact did not kill its target.")
	TEST_ASSERT_EQUAL(victim.loc, corpse_stop, "The charge failed to carry the intact body to the wall.")
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger), "The drive remained active after the body reached the wall.")
	TEST_ASSERT_EQUAL(length(hit_targets), hits_after_wall + 2, "The fatal charge struck more than once or failed to register.")
	TEST_ASSERT_EQUAL(hit_targets[hits_after_wall + 2], victim, "The fatal contact hit the bystander.")
	direct_damage = wielder.apply_damage(20, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = WEST, attacking_item = sword)
	TEST_ASSERT_EQUAL(direct_damage, 20, "The fatal pass left the wielder protected after emerging.")

	wielder.forceMove(origin)
	bystander.forceMove(get_step(origin, EAST))
	stinger.ResetCooldown()
	var/launches_before_death = length(launch_sounds)
	TEST_ASSERT(stinger.Trigger(wielder, target = bystander), "Could not start the pre-contact death scenario.")
	bystander.death()
	sleep(1 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(wielder.loc, origin, "The wielder charged after the target died during windup.")
	TEST_ASSERT_EQUAL(length(launch_sounds), launches_before_death, "A charge cancelled during windup still played its launch.")
	TEST_ASSERT_EQUAL(length(hit_targets), hits_after_wall + 2, "The charge hit after its target died during windup.")

	var/turf/pinned_tile = get_step(origin, WEST)
	var/turf/close_wall = get_step(pinned_tile, WEST)
	var/mob/living/carbon/human/consistent/last_enemy = allocate(/mob/living/carbon/human/consistent, pinned_tile)
	last_enemy.damage_resistance = 75
	sword.force = 12
	RegisterSignal(last_enemy, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(record_hit))
	RegisterSignal(last_enemy, COMSIG_MOVABLE_MOVED, PROC_REF(record_step))
	steps.Cut()
	var/before_contact = length(hit_targets)
	var/impacts_before_closet = length(wall_sounds)
	var/obj/structure/closet/obstacle = allocate(/obj/structure/closet, close_wall)
	stinger.ResetCooldown()
	TEST_ASSERT(stinger.Trigger(wielder, target = last_enemy), "Could not charge an enemy backed against a closet.")
	deadline = world.time + 3 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger) || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(hit_targets), before_contact + 1, "A closet caused a wall impact or prolonged the hold.")
	TEST_ASSERT_EQUAL(length(wall_sounds), impacts_before_closet, "A closet played the wall-impact sound.")
	TEST_ASSERT(!length(steps) && !last_enemy.IsKnockdown() && !HAS_TRAIT(last_enemy, TRAIT_IMMOBILIZED), "The closet failed to release the target standing in place.")
	qdel(obstacle)
	close_wall.ChangeTurf(/turf/closed/wall)
	before_contact = length(hit_targets)
	stinger.ResetCooldown()
	TEST_ASSERT(stinger.Trigger(wielder, target = last_enemy), "Could not charge an enemy already against the wall.")
	deadline = world.time + 3 SECONDS
	UNTIL(!wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger) || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(hit_targets), before_contact + 2, "An enemy already against the wall should receive exactly the contact and impact.")
	TEST_ASSERT_EQUAL(hit_amounts[before_contact + 1], 2 * ordinary_damage, "The pinned enemy took the wrong contact damage.")
	TEST_ASSERT_EQUAL(hit_amounts[before_contact + 2], 4 * ordinary_damage, "The pinned enemy took the wrong impact damage.")
	TEST_ASSERT_EQUAL(hit_times[before_contact + 1], hit_times[before_contact + 2], "The pinned enemy's wall impact was delayed.")
	TEST_ASSERT(!length(steps) && last_enemy.loc == pinned_tile && last_enemy.IsKnockdown(), "The pinned enemy moved or escaped knockdown.")

	stinger.ResetCooldown()
	TEST_ASSERT(stinger.Trigger(wielder, target = last_enemy), "Could not start the interruptible charge.")
	wielder.set_stat(SOFT_CRIT)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/dark_star_sequence/deep_stinger), "Entering soft critical did not end the charge immediately.")
	direct_damage = wielder.apply_damage(20, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, attack_direction = WEST, attacking_item = sword)
	TEST_ASSERT_EQUAL(direct_damage, 20, "The damage modifier survived the interrupted charge.")

/datum/unit_test/legendary_sword_eclipse_double
	var/list/hits = list()
	var/list/amounts = list()
	var/list/hit_times = list()

/datum/unit_test/legendary_sword_eclipse_double/proc/record_hit(datum/source, damage, damage_type, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(damage > 0 && istype(attacking_item, /obj/item/dualsaber/legendary_saber/dark_star))
		hits += source
		amounts += damage
		hit_times += world.time

/// Use the normal click path and honour the equipped blade's own melee cooldown.
/datum/unit_test/legendary_sword_eclipse_double/proc/click_when_ready(mob/living/wielder, mob/living/target)
	if(wielder.next_move > world.time)
		sleep(wielder.next_move - world.time)
	wielder.ClickOn(target)

/datum/unit_test/legendary_sword_eclipse_double/Run()
	var/turf/origin = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/turf/target_tile = get_step(origin, EAST)
	var/mob/living/carbon/human/consistent/dark_star_audio_listener/wielder = allocate(/mob/living/carbon/human/consistent/dark_star_audio_listener, origin)
	var/list/summons = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_eclipse_summon.ogg')
	var/list/echo_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_eclipse_echo.ogg')
	var/list/cross_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_eclipse_cross.ogg')
	var/list/manual_sounds = wielder.track_sound('modular_bandastation/weapon/sound/melee/ds_saber_hit.ogg')
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, target_tile)
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, get_step(origin, WEST))
	var/obj/item/dualsaber/legendary_saber/dark_star/sword = allocate(/obj/item/dualsaber/legendary_saber/dark_star, origin)
	wielder.mind_initialize()
	wielder.mind.centcom_role = DARK_STAR_TEST_OFFICER_ROLE
	TEST_ASSERT(wielder.put_in_active_hand(sword), "Could not equip Dark Star.")
	sword.attack_self(wielder)
	wielder.set_combat_mode(TRUE)
	sword.force = 8
	sword.wound_bonus = CANT_WOUND
	for(var/mob/living/participant as anything in list(victim, bystander))
		participant.damage_resistance = 75
		RegisterSignal(participant, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(record_hit))
	click_when_ready(wielder, victim)
	TEST_ASSERT_EQUAL(length(hits), 1, "The ordinary comparison click did not land.")
	var/ordinary_damage = amounts[1]
	TEST_ASSERT_EQUAL(ordinary_damage, 2, "The comparison hit ignored the modified blade or the target's resistance.")
	var/datum/action/cooldown/legendary_sword/star_eclipse_double/double_action = locate() in sword.actions
	var/datum/action/cooldown/legendary_sword/star_phantom_blades/blades = locate() in sword.actions
	TEST_ASSERT_NOTNULL(double_action, "Dark Star did not grant Eclipse Double.")
	TEST_ASSERT_EQUAL(sword.legendary_abilities[5], double_action.type, "Eclipse Double did not occupy the fifth slot.")
	sword.bond_meditation_time = 45 SECONDS + 90 SECONDS + 3 MINUTES - 1
	TEST_ASSERT(!double_action.Trigger(wielder), "Eclipse Double activated below full bond.")
	sword.bond_meditation_time++
	sleep(wielder.next_move - world.time)

	// Exhaust the five attempts before expiry, then repeat with the fifth click just before expiry.
	for(var/late_fifth in list(FALSE, TRUE))
		victim.fully_heal(HEAL_DAMAGE)
		var/start = world.time
		var/summons_before = length(summons)
		var/echoes_before = length(echo_sounds)
		var/crosses_before = length(cross_sounds)
		double_action.ResetCooldown()
		TEST_ASSERT(double_action.Trigger(wielder), "Could not activate Eclipse Double on the wielder.")
		TEST_ASSERT(length(summons) == summons_before + 1 && summons[length(summons)] == origin, "Summoning the double should play once at the wielder.")
		TEST_ASSERT_NOTNULL(wielder.has_status_effect(/datum/status_effect/dark_star_sequence/eclipse_double), "The wielder did not receive the double.")
		var/obj/effect/dark_star_eclipse_double/avatar = locate() in wielder.vis_contents
		TEST_ASSERT(avatar?.loc == wielder && (avatar.shoulder in avatar.vis_contents), "The visible double was not attached to the wielder's shoulder.")
		TEST_ASSERT_EQUAL(double_action.next_use_time, start + 60 SECONDS, "Eclipse Double started the wrong cooldown.")
		if(late_fifth)
			var/before_volley = length(hits)
			TEST_ASSERT(blades?.Trigger(wielder, target = bystander), "Phantom Blades could not be used alongside the double.")
			sleep(1 SECONDS + 0.4 SECONDS + 2 * world.tick_lag)
			TEST_ASSERT_EQUAL(length(hits), before_volley + 1, "A Phantom Blades volley created an echo.")
			TEST_ASSERT(hits[before_volley + 1] == bystander && amounts[before_volley + 1] == 4 * ordinary_damage, "The genuine Phantom Blades hit failed to land.")
		for(var/strike in 1 to 6)
			if(late_fifth && strike == 5)
				sleep(start + 6 SECONDS - world.tick_lag - world.time)
			var/before = length(hits)
			var/manual_sounds_before = length(manual_sounds)
			click_when_ready(wielder, victim)
			TEST_ASSERT_EQUAL(length(hits), before + 1, "Ordinary click [strike] was blocked or immediately echoed.")
			TEST_ASSERT_EQUAL(length(echo_sounds) + length(cross_sounds), echoes_before + crosses_before + min(strike - 1, 5), "The double played its strike sound when the manual click landed.")
			if(strike <= 5)
				var/obj/effect/dark_star_eclipse_echo/mark = locate() in avatar.echoes
				TEST_ASSERT(mark?.loc == target_tile && (mark.mark_visual in mark.vis_contents), "The visual mark was not bound to the original victim's tile.")
			var/manual_time = hit_times[before + 1]
			if(strike == 5 || (!late_fifth && strike == 6))
				TEST_ASSERT(manual_time < start + 6 SECONDS, "The test missed the six-second recording window.")
			var/next_click_time = wielder.next_move
			sleep(0.4 SECONDS + 2 * world.tick_lag)
			TEST_ASSERT_EQUAL(length(manual_sounds), manual_sounds_before + 1, "The manual click should play the ordinary blade sound once, independently of the echo.")
			TEST_ASSERT_EQUAL(length(echo_sounds), echoes_before + min(strike, 4), "Only the first four delayed swings should play the echo sound.")
			TEST_ASSERT_EQUAL(length(cross_sounds), crosses_before + (strike >= 5), "Only the fifth delayed swing should play the cross sound.")
			if(strike <= 5)
				var/list/swing_sounds = strike == 5 ? cross_sounds : echo_sounds
				TEST_ASSERT_EQUAL(swing_sounds[length(swing_sounds)], target_tile, "The delayed swing did not sound at the marked tile.")
			TEST_ASSERT_EQUAL(wielder.next_move, next_click_time, "An autonomous echo extended the wielder's ordinary click cooldown.")
			if(strike == 6)
				TEST_ASSERT_EQUAL(length(hits), before + 1, "A sixth click or a previous echo generated an extra strike.")
				continue
			TEST_ASSERT_EQUAL(length(hits), before + 2, "Ordinary click [strike] should produce exactly one echo.")
			TEST_ASSERT(hits[before + 2] == victim && amounts[before + 2] == ordinary_damage, "An echo failed to reproduce the native hit on its original victim.")
			var/obj/effect/temp_visual/dark_star_eclipse_hit/cross/cross = locate() in target_tile
			TEST_ASSERT_EQUAL(!isnull(cross), strike == 5, "Only the fifth echo should display the cross on the marked tile.")
			var/echo_time = hit_times[before + 2]
			TEST_ASSERT(echo_time >= manual_time + 0.4 SECONDS && echo_time <= manual_time + 0.4 SECONDS + 2 * world.tick_lag, "The echo did not follow its original hit after 0.4 seconds.")
			if(late_fifth && strike == 5)
				TEST_ASSERT(echo_time > start + 6 SECONDS, "The fifth pending echo did not resolve after the window closed.")
		if(world.time < start + 6 SECONDS)
			sleep(start + 6 SECONDS - world.time + world.tick_lag)

	double_action.ResetCooldown()
	var/last_start = world.time
	TEST_ASSERT(double_action.Trigger(wielder), "Could not activate the double for the defensive cases.")
	TEST_ASSERT(wielder.Move(get_step(origin, NORTH), NORTH), "The double prevented the wielder from walking.")
	var/before = length(hits)
	var/echoes_before_miss = length(echo_sounds)
	click_when_ready(wielder, victim)
	TEST_ASSERT_EQUAL(length(hits), before + 1, "The moving-target comparison click did not land.")
	victim.forceMove(get_step(target_tile, NORTH))
	bystander.forceMove(target_tile)
	sleep(0.4 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hits), before + 1, "The echo followed a departing target or struck its replacement.")
	TEST_ASSERT(length(echo_sounds) == echoes_before_miss + 1 && echo_sounds[length(echo_sounds)] == target_tile, "A dodged echo should still sound at the abandoned mark.")
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot, get_turf(victim))
	shield.block_chance = 200
	TEST_ASSERT(victim.put_in_active_hand(shield), "Could not raise the shield before a manual click.")
	click_when_ready(wielder, victim)
	var/shield_after_click = shield.get_integrity()
	TEST_ASSERT(shield_after_click < shield.max_integrity, "The defender did not block the manual click.")
	TEST_ASSERT(victim.dropItemToGround(shield), "Could not lower the shield before a possible echo.")
	sleep(0.4 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hits), before + 1, "A blocked ordinary attack still produced an echo.")
	click_when_ready(wielder, victim)
	TEST_ASSERT(victim.put_in_active_hand(shield), "Could not raise the shield between the click and echo.")
	sleep(0.4 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT(shield.get_integrity() < shield_after_click, "The delayed echo never struck the newly raised shield.")
	TEST_ASSERT_EQUAL(length(hits), before + 2, "A blocked echo damaged the defender.")
	victim.dropItemToGround(shield)
	if(world.time < last_start + 6 SECONDS + world.tick_lag)
		sleep(last_start + 6 SECONDS + world.tick_lag - world.time)
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/dark_star_sequence/eclipse_double), "The double outlasted six seconds with charges remaining.")
	click_when_ready(wielder, victim)
	sleep(0.4 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hits), before + 3, "A click after expiry still echoed.")

	double_action.ResetCooldown()
	TEST_ASSERT(double_action.Trigger(wielder), "Could not start the interruptible double.")
	var/obj/effect/dark_star_eclipse_double/interrupted_avatar = locate() in wielder.vis_contents
	TEST_ASSERT_NOTNULL(interrupted_avatar, "The interruptible double was never displayed.")
	var/swings_before_disarm = length(echo_sounds) + length(cross_sounds)
	click_when_ready(wielder, victim)
	var/obj/effect/dark_star_eclipse_echo/interrupted_mark = locate() in interrupted_avatar.echoes
	TEST_ASSERT_EQUAL(interrupted_mark?.loc, get_turf(victim), "The interrupted swing did not mark the victim's tile.")
	TEST_ASSERT(wielder.dropItemToGround(sword), "Could not disarm the wielder before the echo.")
	TEST_ASSERT_NULL(wielder.has_status_effect(/datum/status_effect/dark_star_sequence/eclipse_double), "Disarming the wielder left the double active.")
	TEST_ASSERT(QDELETED(interrupted_avatar) && QDELETED(interrupted_mark), "Disarming the wielder left the shoulder double or its pending mark visible.")
	sleep(0.4 SECONDS + 2 * world.tick_lag)
	TEST_ASSERT_EQUAL(length(hits), before + 4, "A pending echo hit after disarmament.")
	TEST_ASSERT_EQUAL(length(echo_sounds) + length(cross_sounds), swings_before_disarm, "The cancelled echo still played after disarmament.")

#undef DARK_STAR_TEST_OFFICER_ROLE
