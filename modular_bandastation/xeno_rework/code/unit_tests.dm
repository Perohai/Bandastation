#include "defines/evacuation.dm"

/datum/unit_test/xeno_rework_melee/Run()
	var/mob/living/carbon/alien/adult/banda/sentinel/xeno = allocate(/mob/living/carbon/alien/adult/banda/sentinel)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	xeno.set_combat_mode(TRUE)
	xeno.zone_selected = BODY_ZONE_CHEST
	xeno.melee_damage_lower = 20
	xeno.melee_damage_upper = 20
	var/old_damage = victim.get_brute_loss()
	TEST_ASSERT(victim.attack_alien(xeno, list()), "A valid claw strike failed")
	TEST_ASSERT_EQUAL(victim.get_brute_loss() - old_damage, xeno.melee_damage_upper, "One claw strike did not deal exactly one hit of damage")
	ADD_TRAIT(xeno, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	old_damage = victim.get_brute_loss()
	victim.attack_alien(xeno, list())
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), old_damage, "Reworked attacks bypassed native pacifism checks")
	var/obj/item/held = allocate(/obj/item)
	TEST_ASSERT(victim.put_in_active_hand(held), "The target could not hold an item before the attack")
	var/old_stamina = victim.get_stamina_loss()
	victim.attack_alien(xeno, list(RIGHT_CLICK = TRUE))
	TEST_ASSERT_EQUAL(victim.get_stamina_loss() - old_stamina, xeno.melee_damage_upper * 1.5, "Reworked disarm dealt stamina damage more than once")
	var/mob/living/carbon/alien/adult/hunter/native_xeno = allocate(/mob/living/carbon/alien/adult/hunter)
	var/mob/living/carbon/human/native_victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/native_held = allocate(/obj/item)
	TEST_ASSERT(native_victim.put_in_active_hand(native_held), "The native attack target could not hold an item")
	native_victim.attack_alien(native_xeno, list(RIGHT_CLICK = TRUE))
	TEST_ASSERT(!native_victim.is_holding(native_held), "Native aliens lost their normal disarm")

/datum/unit_test/xeno_rework_spray_airlock/Run()
	var/mob/living/carbon/alien/adult/banda/sentinel/xeno = allocate(/mob/living/carbon/alien/adult/banda/sentinel)
	var/datum/action/cooldown/alien/banda/acid_spray/spray = locate() in xeno.actions
	var/turf/door_turf = get_step(xeno, NORTH)
	var/turf/target = get_step(door_turf, NORTH)
	var/obj/machinery/door/airlock/glass/door = allocate(/obj/machinery/door/airlock/glass, door_turf)
	door.set_density(TRUE)
	TEST_ASSERT(!spray.spray_tile(target), "Acid passed through a closed glass airlock")
	TEST_ASSERT(!(locate(/obj/effect/xeno_acid_pool/spray) in target), "Blocked acid created a pool behind an airlock")
	door.set_density(FALSE)
	TEST_ASSERT(spray.spray_tile(target), "An open airlock still blocked acid")
	TEST_ASSERT(locate(/obj/effect/xeno_acid_pool/spray) in target, "Acid did not reach the floor behind an open airlock")

/datum/unit_test/xeno_rework_boiler_aim
	/// Records the actual projectile impact, rather than checking projectile configuration.
	var/turf/impact_turf

/datum/unit_test/xeno_rework_boiler_aim/Run()
	var/mob/living/carbon/alien/adult/banda/final_caste/boiler/boiler = allocate(/mob/living/carbon/alien/adult/banda/final_caste/boiler)
	var/turf/destination = get_ranged_target_turf(boiler, NORTH, 3)
	TEST_ASSERT(isopenturf(destination), "The artillery test target must be an empty floor")
	for(var/corrosive in list(FALSE, TRUE))
		impact_turf = null
		var/obj/projectile/xeno_boiler/glob = allocate(/obj/projectile/xeno_boiler, boiler.loc)
		glob.corrosive = corrosive
		glob.aim_projectile(destination, boiler, list())
		glob.firer = boiler
		RegisterSignal(glob, COMSIG_PROJECTILE_SELF_ON_HIT, PROC_REF(on_glob_hit))
		glob.fire()
		sleep(2 SECONDS)
		TEST_ASSERT_EQUAL(impact_turf, destination, "Boiler's [corrosive ? "acid" : "neurotoxin"] glob missed the selected empty floor")
	impact_turf = null

/datum/unit_test/xeno_rework_boiler_aim/proc/on_glob_hit(obj/projectile/source, atom/firer, atom/target)
	SIGNAL_HANDLER
	impact_turf = get_turf(source)

/datum/unit_test/xeno_rework_evacuation_arrival/Run()
	var/mob/living/carbon/alien/adult/banda/drone/xeno = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/datum/xeno_evacuation/event = GLOB.xeno_evacuation
	sleep(1.1 SECONDS)
	TEST_ASSERT(!event.check_queued, "An old population check was still pending")
	var/destination_z = xeno.z == 1 ? world.maxz : 1
	xeno.forceMove(locate(1, 1, destination_z))
	TEST_ASSERT(event.check_queued, "Crossing z-levels did not queue an evacuation population check")
	xeno.forceMove(run_loc_floor_bottom_left)

/datum/unit_test/xeno_rework_organs/Run()
	for(var/caste_type in valid_subtypesof(/mob/living/carbon/alien/adult/banda))
		var/mob/living/carbon/alien/adult/banda/xeno = allocate(caste_type)
		var/obj/item/organ/stomach/alien/stomach = xeno.get_organ_slot(ORGAN_SLOT_STOMACH)
		TEST_ASSERT(istype(stomach), "[caste_type] cannot use the adult devour proc with its stomach")
		var/vessels = 0
		for(var/obj/item/organ/alien/plasmavessel/vessel in xeno.organs)
			vessels++
		TEST_ASSERT_EQUAL(vessels, 1, "[caste_type] must have exactly one plasma vessel")

/datum/unit_test/xeno_rework_stomach/Run()
	var/mob/living/carbon/alien/adult/banda/drone/xeno = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other_victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/stomach/alien_banda/stomach = xeno.get_organ_slot(ORGAN_SLOT_STOMACH)
	TEST_ASSERT(stomach.consume_thing(victim), "Failed to swallow a living victim")
	TEST_ASSERT(stomach.consume_thing(other_victim), "Failed to swallow a second victim")
	TEST_ASSERT_EQUAL(get_turf(victim), get_turf(xeno), "Swallowed prey was moved into nullspace")
	stomach.relaymove(victim, NORTH)
	TEST_ASSERT_NOTNULL(stomach.resist_timers[victim], "Resistance did not start an automatic escape timer")
	TEST_ASSERT_EQUAL(stomach.stomach_acid_power(victim), 0, "Living prey must not passively digest")
	stomach.resist_times[victim] = world.time - 90 SECONDS
	stomach.relaymove(victim, NORTH)
	TEST_ASSERT_EQUAL(victim.loc, xeno.loc, "Prey must escape after 90 seconds of resistance")
	TEST_ASSERT(!(victim in stomach.stomach_contents), "Escaped prey is still tracked")
	TEST_ASSERT_NULL(stomach.resist_times[victim], "Resistance reference survived escape")
	TEST_ASSERT_NULL(stomach.resist_timers[victim], "Escape did not release the pending callback")
	TEST_ASSERT(other_victim in stomach.stomach_contents, "One prey escaping ejected unrelated prey")
	stomach.resist_times[other_victim] = world.time
	other_victim.forceMove(xeno.loc)
	TEST_ASSERT_NULL(stomach.resist_times[other_victim], "Moving out did not release resistance reference")

/datum/unit_test/xeno_rework_building/Run()
	var/mob/living/carbon/alien/adult/banda/drone/xeno = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/obj/item/organ/alien/plasmavessel/vessel = xeno.get_organ_slot(ORGAN_SLOT_XENO_PLASMAVESSEL)
	vessel.plasma_rate = 0 // Isolate construction costs from Life() running during do_after.
	var/datum/action/cooldown/alien/build_resin_structure/build = locate() in xeno.actions
	TEST_ASSERT_NOTNULL(build, "Drone has no resin building action")
	var/turf/location = get_step(xeno, NORTH)
	TEST_ASSERT(!build.can_build(location, /obj/structure/alien/resin/door), "Building without weeds was allowed")
	var/obj/structure/alien/weeds/weeds = allocate(/obj/structure/alien/weeds, location)
	TEST_ASSERT(build.can_build(location, /obj/structure/alien/resin/door), "Adjacent weeded turf rejected")
	TEST_ASSERT(!build.can_build(location, /obj/structure/alien/weeds), "Unlisted structure type accepted")
	var/obj/structure/bed/nest/nest = allocate(/obj/structure/bed/nest, location)
	TEST_ASSERT(!build.can_build(location, /obj/structure/alien/resin/door), "Overlapping resin structures accepted")
	qdel(nest)
	qdel(weeds)
	TEST_ASSERT(!build.can_build(location, /obj/structure/alien/resin/door), "Removed weeds still permit construction")
	weeds = allocate(/obj/structure/alien/weeds, location)
	xeno.selected_resin_structure = /obj/structure/alien/resin/door
	xeno.adjustPlasma(xeno.get_max_plasma())
	var/starting_plasma = xeno.getPlasma()
	build.build_time = 0
	TEST_ASSERT(build.PreActivate(location), "Valid construction failed")
	TEST_ASSERT_EQUAL(xeno.getPlasma(), starting_plasma - 55, "Construction must charge plasma exactly once")
	var/obj/structure/alien/resin/door/door = locate() in location
	TEST_ASSERT_NOTNULL(door, "Construction made no door")
	qdel(door)
	starting_plasma = xeno.getPlasma()
	build.build_time = 0.2 SECONDS
	QDEL_IN(weeds, 0.1 SECONDS)
	TEST_ASSERT(!build.PreActivate(location), "Construction succeeded after weeds disappeared during do_after")
	TEST_ASSERT_EQUAL(xeno.getPlasma(), starting_plasma, "Interrupted construction charged plasma")

/datum/unit_test/xeno_rework_evolution/Run()
	var/mob/living/carbon/alien/adult/banda/spitter/spitter = allocate(/mob/living/carbon/alien/adult/banda/spitter)
	var/mob/living/carbon/alien/adult/banda/sentinel/sentinel = allocate(/mob/living/carbon/alien/adult/banda/sentinel)
	TEST_ASSERT(spitter.can_evolve(), "An existing sentinel must not block another T2 evolution")
	TEST_ASSERT(sentinel.can_evolve(), "Vacant T3 slot should permit evolution")
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = allocate(/mob/living/carbon/alien/adult/banda/warrior)
	TEST_ASSERT(!sentinel.can_evolve(), "Warrior must occupy the same T3 slot as praetorian")
	qdel(warrior)
	TEST_ASSERT(sentinel.can_evolve(), "Deleting a T3 must free its slot")
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/stomach/alien_banda/old_stomach = spitter.get_organ_slot(ORGAN_SLOT_STOMACH)
	old_stomach.consume_thing(prey)
	var/obj/item/organ/brain/old_brain = spitter.get_organ_slot(ORGAN_SLOT_BRAIN)
	spitter.identifier = 321
	spitter.name = "alien spitter (321)"
	spitter.alien_evolve(sentinel)
	var/obj/item/organ/stomach/alien_banda/new_stomach = sentinel.get_organ_slot(ORGAN_SLOT_STOMACH)
	TEST_ASSERT(prey in new_stomach.stomach_contents, "Evolution lost swallowed prey")
	TEST_ASSERT_EQUAL(sentinel.get_organ_slot(ORGAN_SLOT_BRAIN), old_brain, "Evolution lost the original brain")
	TEST_ASSERT(sentinel.has_evolved_recently, "Evolution did not apply its cooldown")
	TEST_ASSERT_EQUAL(sentinel.identifier, 321, "Evolution lost the numerical identifier")
	TEST_ASSERT_EQUAL(sentinel.name, "alien sentinel (321)", "Evolution retained the old caste's name")

/datum/unit_test/xeno_rework_intoxication/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.apply_status_effect(/datum/status_effect/stacking/xeno_intoxication, 5)
	victim.apply_status_effect(/datum/status_effect/stacking/xeno_intoxication, 5)
	var/datum/status_effect/stacking/xeno_intoxication/intoxication = victim.has_status_effect(/datum/status_effect/stacking/xeno_intoxication)
	TEST_ASSERT_NOTNULL(intoxication, "Intoxication was not applied")
	TEST_ASSERT_EQUAL(intoxication.stacks, 10, "Repeated hits did not add stacks")
	var/toxin_damage = victim.get_tox_loss()
	intoxication.tick(2)
	TEST_ASSERT_EQUAL(victim.get_tox_loss() - toxin_damage, 2, "Intoxication damage must scale with elapsed seconds")
	var/datum/reagents/water = allocate(/datum/reagents, 10)
	water.add_reagent(/datum/reagent/water, 5)
	water.expose(victim, TOUCH)
	TEST_ASSERT_NULL(victim.has_status_effect(/datum/status_effect/stacking/xeno_intoxication), "Water did not wash away intoxication")
	victim.apply_status_effect(/datum/status_effect/stacking/xeno_intoxication, 30)
	SEND_SIGNAL(victim, COMSIG_LIVING_RESIST)
	TEST_ASSERT_NULL(victim.has_status_effect(/datum/status_effect/stacking/xeno_intoxication), "Resistance did not clear intoxication")
	var/mob/living/carbon/alien/adult/banda/spitter/spitter = allocate(/mob/living/carbon/alien/adult/banda/spitter)
	TEST_ASSERT_NULL(spitter.apply_status_effect(/datum/status_effect/stacking/xeno_intoxication, 5), "Xenomorphs must be immune to intoxication")

/datum/unit_test/xeno_rework_fruit/Run()
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/alien/adult/banda/defender/target = allocate(/mob/living/carbon/alien/adult/banda/defender)
	var/obj/item/xeno_fruit/unstable/fruit = allocate(/obj/item/xeno_fruit/unstable, drone.loc)
	fruit.attack_alien(drone)
	TEST_ASSERT(!drone.is_holding(fruit), "Unripe fruit was harvested")
	fruit.ripen()
	fruit.attack_alien(target)
	TEST_ASSERT(!target.is_holding(fruit), "Non-drone harvested a fruit")
	fruit.attack_alien(drone)
	TEST_ASSERT(drone.is_holding(fruit), "Drone could not harvest a ripe fruit")
	fruit.attack(target, drone)
	TEST_ASSERT(QDELETED(fruit), "Consumed fruit was not deleted")
	var/datum/status_effect/xeno_overshield/shield = target.has_status_effect(/datum/status_effect/xeno_overshield)
	TEST_ASSERT_NOTNULL(shield, "Unstable fruit did not give a shield")
	TEST_ASSERT_EQUAL(shield.remaining, 75, "Shield must be capped at 30% of max health")
	target.apply_damage(100, BRUTE, BODY_ZONE_CHEST, blocked = 50, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(shield.remaining, 25, "Shield must absorb damage after armor")
	TEST_ASSERT_EQUAL(target.get_brute_loss(), 0, "Shielded damage reached the body")
	target.apply_damage(50, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(target.get_brute_loss(), 25, "Excess damage did not pass through the shield")
	TEST_ASSERT_NULL(target.has_status_effect(/datum/status_effect/xeno_overshield), "Depleted shield was not removed")

/datum/unit_test/xeno_rework_ability_cost/Run()
	var/mob/living/carbon/alien/adult/banda/spitter/spitter = allocate(/mob/living/carbon/alien/adult/banda/spitter)
	spitter.adjustPlasma(spitter.get_max_plasma())
	var/starting_plasma = spitter.getPlasma()
	var/datum/action/cooldown/alien/banda/toxic_claws/claws = locate() in spitter.actions
	TEST_ASSERT_NOTNULL(claws, "Spitter was not granted toxic claws")
	TEST_ASSERT(claws.PreActivate(spitter), "Toxic claws failed to activate")
	TEST_ASSERT_EQUAL(spitter.getPlasma(), starting_plasma - 100, "Toxic claws charged the wrong plasma cost")
	TEST_ASSERT(claws.next_use_time >= world.time + 20 SECONDS, "Toxic claws did not start their cooldown")
	TEST_ASSERT(!claws.IsAvailable(), "Toxic claws can be reused during cooldown")

/datum/unit_test/xeno_rework_door/Run()
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/alien/resin/door/door = allocate(/obj/structure/alien/resin/door, get_step(drone, NORTH))
	door.close_delay = 100 SECONDS
	door.try_to_operate(human)
	TEST_ASSERT(!door.is_operating, "Human without a hive node opened the door")
	door.try_to_operate(drone)
	sleep(0.3 SECONDS)
	TEST_ASSERT(door.is_operating && door.density, "Resin door skipped the second half of its animation")
	sleep(0.4 SECONDS)
	TEST_ASSERT(door.state_open && !door.density && !door.opacity, "Door failed to open after its animation")
	human.forceMove(door.loc)
	door.operate()
	TEST_ASSERT(!door.is_operating, "Door started closing on an occupant")
	human.forceMove(drone.loc)
	door.operate()
	human.forceMove(door.loc)
	sleep(door.operation_time + 0.1 SECONDS)
	TEST_ASSERT(door.state_open && !door.density, "Door closed on a mob that entered during the animation")
	human.forceMove(drone.loc)
	door.operate()
	sleep(door.operation_time + 0.1 SECONDS)
	TEST_ASSERT(!door.state_open && door.density && door.opacity, "Unobstructed door failed to close")
	TEST_ASSERT(door.icon_state in icon_states(door.icon), "Smoothing selected a missing door sprite")

/datum/unit_test/xeno_rework_icons/Run()
	for(var/caste_type in valid_subtypesof(/mob/living/carbon/alien/adult/banda))
		var/mob/living/carbon/alien/adult/banda/xeno = allocate(caste_type)
		var/list/states = icon_states(xeno.icon)
		for(var/suffix in list("", "_sleep", "_unconscious", "_dead", "_husked"))
			TEST_ASSERT("alien[xeno.caste][suffix]" in states, "[caste_type] has no sprite for [suffix]")
		for(var/datum/action/action as anything in xeno.actions)
			if(!(action.button_icon_state in icon_states(action.button_icon)))
				TEST_FAIL("[caste_type]: [action.type] references missing icon [action.button_icon_state] in [action.button_icon]")
	for(var/fruit_type in subtypesof(/obj/item/xeno_fruit))
		var/obj/item/xeno_fruit/fruit = allocate(fruit_type)
		TEST_ASSERT(fruit.icon_state in icon_states(fruit.icon), "[fruit_type] has no immature sprite")
		fruit.ripen()
		TEST_ASSERT(fruit.icon_state in icon_states(fruit.icon), "[fruit_type] has no ripe sprite")
		TEST_ASSERT("[fruit.inhand_icon_state]drone_l" in icon_states(fruit.lefthand_file), "[fruit_type] has no left inhand sprite")
		TEST_ASSERT("[fruit.inhand_icon_state]drone_r" in icon_states(fruit.righthand_file), "[fruit_type] has no right inhand sprite")

/datum/unit_test/xeno_rework_queen_limit/Run()
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	TEST_ASSERT(drone.can_evolve(), "Drone cannot evolve with no queen present")
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	TEST_ASSERT(isalienqueen(queen) && isalienroyal(queen), "Existing game helpers do not recognize the new queen")
	TEST_ASSERT(!drone.can_evolve(), "A living queen without a client did not occupy the queen slot")

/datum/unit_test/xeno_rework_defender/Run()
	var/mob/living/carbon/alien/adult/banda/defender/defender = allocate(/mob/living/carbon/alien/adult/banda/defender)
	var/old_armor = defender.getarmor(BODY_ZONE_CHEST, BULLET)
	defender.enter_fortify()
	TEST_ASSERT(defender.getarmor(BODY_ZONE_CHEST, BULLET) > old_armor, "Fortify does not reduce ranged damage")
	defender.Knockdown(1 SECONDS)
	TEST_ASSERT(!defender.IsKnockdown(), "Fortified defender was knocked down")
	defender.update_icons()
	TEST_ASSERT_EQUAL(defender.icon_state, "defender_fortify", "Icon update lost the fortified pose")
	TEST_ASSERT(!defender.anchored, "Fortify must slow the defender without anchoring it")
	defender.exit_fortify(TRUE)
	TEST_ASSERT_EQUAL(defender.getarmor(BODY_ZONE_CHEST, BULLET), old_armor, "Fortify armor survived deactivation")

/datum/unit_test/xeno_rework_acid/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/xeno_acid_pool/pool = allocate(/obj/effect/xeno_acid_pool, victim.loc)
	pool.affect(victim, 2)
	pool.affect(victim, 0.5)
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 12.5, "Acid damage must scale with elapsed seconds")
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	pool.affect(drone, 2)
	TEST_ASSERT_EQUAL(drone.get_fire_loss(), 0, "Acid damaged an allied xenomorph")

/datum/unit_test/xeno_rework_empower/Run()
	var/mob/living/carbon/alien/adult/banda/ravager/ravager = allocate(/mob/living/carbon/alien/adult/banda/ravager)
	var/obj/item/organ/alien/plasmavessel/vessel = ravager.get_organ_slot(ORGAN_SLOT_XENO_PLASMAVESSEL)
	vessel.plasma_rate = 0 // The second activation waits long enough for Life() to regenerate plasma.
	for(var/enemy in 1 to 3)
		allocate(/mob/living/carbon/human/consistent)
	ravager.adjustPlasma(ravager.get_max_plasma())
	var/old_plasma = ravager.getPlasma()
	var/datum/action/cooldown/alien/banda/ravager_empower/empower = locate() in ravager.actions
	TEST_ASSERT(empower.PreActivate(ravager), "First empower activation failed")
	TEST_ASSERT_EQUAL(ravager.getPlasma(), old_plasma - 50, "Empower did not charge exactly 50 plasma")
	sleep(0.5 SECONDS)
	TEST_ASSERT(empower.PreActivate(ravager), "Second empower activation failed")
	TEST_ASSERT_EQUAL(ravager.getPlasma(), old_plasma - 50, "Empower charged for its second activation")
	TEST_ASSERT(ravager.has_status_effect(/datum/status_effect/xeno_super_empowered), "Three nearby enemies did not trigger super empowerment")
	TEST_ASSERT(empower.next_use_time >= world.time + 22 SECONDS, "Empower did not start its cooldown")

/datum/unit_test/xeno_rework_evade/Run()
	var/mob/living/carbon/alien/adult/banda/runner/runner = allocate(/mob/living/carbon/alien/adult/banda/runner)
	var/datum/action/cooldown/alien/banda/evade/evade = runner.evade_ability
	TEST_ASSERT(evade.PreActivate(runner), "Evade failed to activate")
	var/obj/projectile/bullet/bullet = allocate(/obj/projectile/bullet)
	TEST_ASSERT_EQUAL(evade.on_projectile_hit(bullet), BULLET_ACT_FORCE_PIERCE, "First projectile was not evaded")
	TEST_ASSERT_EQUAL(evade.on_projectile_hit(bullet), BULLET_ACT_FORCE_PIERCE, "A second projectile bypassed the same evade window")
	sleep(0.7 SECONDS)
	TEST_ASSERT(evade.IsAvailable(), "A successful dodge did not reset the cooldown")

/datum/unit_test/xeno_rework_stomach_weapons/Run()
	var/mob/living/carbon/alien/adult/banda/drone/xeno = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/stomach/alien_banda/stomach = xeno.get_organ_slot(ORGAN_SLOT_STOMACH)
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	victim.put_in_active_hand(gun)
	TEST_ASSERT_NOTNULL(gun.chambered, "Test pistol has no chambered round")
	stomach.consume_thing(victim)
	var/old_ammo = gun.get_ammo()
	gun.fire_gun(xeno, victim, TRUE, null)
	TEST_ASSERT_EQUAL(gun.get_ammo(), old_ammo, "Gun fired from inside a xenomorph")
	victim.drop_all_held_items()
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	victim.put_in_active_hand(knife)
	var/old_damage = xeno.get_brute_loss()
	stomach.attack_from_within(victim, knife)
	TEST_ASSERT(xeno.get_brute_loss() > old_damage, "Melee resistance did not damage the xenomorph")
	victim.forceMove(xeno.loc)
	TEST_ASSERT(!(SEND_SIGNAL(victim, COMSIG_MOB_TRYING_TO_FIRE_GUN, gun, xeno, TRUE, null) & COMPONENT_CANCEL_GUN_FIRE), "Gun restriction survived leaving the stomach")

/datum/unit_test/xeno_rework_screech/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	var/mob/living/carbon/human/hearing = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/deaf = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/protected = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(deaf, TRAIT_DEAF, TRAIT_SOURCE_UNIT_TESTS)
	protected.equip_to_slot_if_possible(allocate(/obj/item/clothing/ears/earmuffs), ITEM_SLOT_EARS)
	queen.adjustPlasma(queen.get_max_plasma())
	var/datum/action/cooldown/alien/banda/queen_screech/screech = locate() in queen.actions
	TEST_ASSERT(screech.PreActivate(queen), "Queen could not screech")
	TEST_ASSERT(hearing.IsKnockdown(), "Screech did not knock down a hearing target")
	TEST_ASSERT(!deaf.IsKnockdown(), "Screech affected a deaf target")
	TEST_ASSERT(!protected.IsKnockdown(), "Screech affected a target wearing earmuffs")
	TEST_ASSERT(screech.next_use_time >= world.time + 180 SECONDS, "Screech did not start its cooldown")

/datum/unit_test/xeno_rework_sting/Run()
	var/mob/living/carbon/alien/adult/banda/spitter/spitter = allocate(/mob/living/carbon/alien/adult/banda/spitter)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	spitter.adjust_brute_loss(50)
	victim.apply_status_effect(/datum/status_effect/stacking/xeno_intoxication, 30)
	var/datum/action/cooldown/alien/banda/toxic_sting/sting = locate() in spitter.actions
	TEST_ASSERT(sting.Activate(victim), "Sting could not affect an intoxicated target")
	TEST_ASSERT_EQUAL(victim.AmountKnockdown(), 2 SECONDS, "30 stacks should knock down for two seconds")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), 36, "Sting dealt the wrong damage")
	TEST_ASSERT_EQUAL(spitter.get_brute_loss(), 0, "Sting did not heal the attacker")
	TEST_ASSERT(spitter.has_status_effect(/datum/status_effect/xeno_sting_armor), "Critical intoxication did not grant armor")
	var/datum/status_effect/stacking/xeno_intoxication/intoxication = victim.has_status_effect(/datum/status_effect/stacking/xeno_intoxication)
	TEST_ASSERT_EQUAL(intoxication.stacks, 21, "Sting did not consume 30% of stacks")

/datum/unit_test/xeno_rework_warrior/Run()
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = allocate(/mob/living/carbon/alien/adult/banda/warrior)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(warrior, NORTH))
	warrior.adjustPlasma(warrior.get_max_plasma())
	var/normal_move_delay = warrior.cached_multiplicative_slowdown
	warrior.enter_agility()
	TEST_ASSERT(warrior.cached_multiplicative_slowdown < normal_move_delay, "Agility did not speed up the warrior")
	warrior.apply_damage(20, BRUTE)
	TEST_ASSERT_EQUAL(warrior.get_brute_loss(), 30, "Agility must increase incoming damage by 50%")
	var/datum/action/cooldown/alien/banda/warrior_lunge/lunge = locate() in warrior.actions
	TEST_ASSERT(lunge.PreActivate(victim), "Warrior could not lunge at an adjacent enemy")
	TEST_ASSERT(!warrior.agility, "Lunge did not end agility")
	TEST_ASSERT(warrior.cached_multiplicative_slowdown >= normal_move_delay, "Lunge retained the agility speed bonus")
	TEST_ASSERT(warrior.lunging && warrior.get_warrior_grab_target() == victim, "Lunge did not grab its target")
	TEST_ASSERT(victim.IsParalyzed(), "Lunge did not stun its target")
	warrior.apply_damage(1, BRUTE)
	TEST_ASSERT_NULL(warrior.get_warrior_grab_target(), "Taking damage did not release the lunge grab")
	TEST_ASSERT(!warrior.lunging, "Taking damage left the warrior in its dragging state")
	lunge.ResetCooldown()
	TEST_ASSERT(lunge.PreActivate(victim), "Warrior could not grab its target again")
	warrior.apply_damage(1, BRUTE)
	TEST_ASSERT_NULL(warrior.get_warrior_grab_target(), "A second hit in the same tick did not release a new grab")
	lunge.ResetCooldown()
	TEST_ASSERT(lunge.PreActivate(victim), "Warrior could not prepare a combo")
	var/datum/action/cooldown/alien/banda/warrior_punch/punch = locate() in warrior.actions
	TEST_ASSERT(punch.PreActivate(victim), "Warrior could not punch its grabbed target")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), round(warrior.warrior_punch_brute * 1.5), "Grab combo did not multiply punch damage")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/staggered), "Punch did not stagger its target")
	TEST_ASSERT_NULL(warrior.get_warrior_grab_target(), "Combo punch did not release its grab")
	lunge.ResetCooldown()
	TEST_ASSERT(lunge.PreActivate(victim), "Warrior could not prepare a throw")
	var/datum/action/cooldown/alien/banda/warrior_throw/throw_action = locate() in warrior.actions
	var/datum/action/cooldown/alien/banda/warrior_fling/fling = locate() in warrior.actions
	TEST_ASSERT(throw_action.PreActivate(get_step(warrior, SOUTH)), "Warrior could not throw its grabbed target")
	TEST_ASSERT(!fling.IsAvailable(), "Throw and fling did not share their cooldown")

/datum/unit_test/xeno_rework_larva_preparation/Run()
	var/mob/living/carbon/alien/larva/larva = allocate(/mob/living/carbon/alien/larva)
	larva.amount_grown = XENOMORPH_MAX_GROWTH
	var/datum/action/cooldown/alien/larva_evolve/evolution = locate() in larva.actions
	TEST_ASSERT_EQUAL(evolution.evolution_time, 5 SECONDS, "Larva preparation must take five seconds")
	INVOKE_ASYNC(evolution, TYPE_PROC_REF(/datum/action/cooldown/alien/larva_evolve, evolve_into), "Drone")
	sleep(0.5 SECONDS)
	TEST_ASSERT(evolution.evolving && !QDELETED(larva), "Larva evolved immediately instead of preparing")
	TEST_ASSERT_NOTNULL(larva.get_filter("xeno_evolution"), "Evolution has no pulsing visual")
	TEST_ASSERT(!evolution.evolve_into("Runner"), "A second evolution started during the first preparation")
	larva.forceMove(get_step(larva, NORTH))
	sleep(0.5 SECONDS)
	TEST_ASSERT(!QDELETED(larva) && !evolution.evolving, "Movement did not cancel evolution")
	TEST_ASSERT_NULL(larva.get_filter("xeno_evolution"), "Cancelled evolution left its glow behind")
	TEST_ASSERT(!evolution.evolve_into("invalid caste"), "Evolution accepted an unlisted caste")
	var/turf/location = larva.loc
	TEST_ASSERT(evolution.evolve_into("Drone"), "Larva could not retry its evolution")
	var/mob/living/carbon/alien/adult/banda/drone/adult = locate() in location
	TEST_ASSERT(QDELETED(larva) && adult, "Completed preparation did not create the selected caste")
	TEST_ASSERT_NULL(adult.get_filter("xeno_evolution"), "Adult inherited the preparation glow")

/datum/unit_test/xeno_rework_spray_footprint/Run()
	var/mob/living/carbon/alien/adult/banda/praetorian/praetorian = allocate(/mob/living/carbon/alien/adult/banda/praetorian)
	praetorian.adjustPlasma(praetorian.get_max_plasma())
	var/datum/action/cooldown/alien/banda/acid_spray/cone/spray = locate() in praetorian.actions
	TEST_ASSERT(spray.PreActivate(get_ranged_target_turf(praetorian, NORTH, 3)), "Praetorian could not spray acid")
	var/turf/center = get_turf(praetorian)
	for(var/row in 1 to 3)
		center = get_step(center, NORTH)
		TEST_ASSERT(locate(/obj/effect/xeno_acid_pool/spray) in center, "Acid spray is missing row [row]")
		TEST_ASSERT(locate(/obj/effect/xeno_acid_pool/spray) in get_step(center, EAST), "Acid spray is missing its second column")
		TEST_ASSERT(!(locate(/obj/effect/xeno_acid_pool/spray) in get_step(center, WEST)), "Acid spray still has a third column")
	TEST_ASSERT(!(locate(/obj/effect/xeno_acid_pool/spray) in get_step(center, NORTH)), "Acid spray extends beyond three rows")

/datum/unit_test/xeno_rework_hive_panel/Run()
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/datum/xeno_rework_hive_status/panel = allocate(/datum/xeno_rework_hive_status)
	var/baseline_count = panel.ui_data(drone)["count"]
	GLOB.alive_mob_list += drone
	var/list/data = panel.ui_data(drone)
	GLOB.alive_mob_list -= drone
	TEST_ASSERT_EQUAL(data["count"], baseline_count + 1, "Hive roster did not include exactly the added xeno")
	var/found_drone = FALSE
	for(var/list/member as anything in data["members"])
		if(member["caste"] == "drone")
			found_drone = TRUE
	TEST_ASSERT(found_drone, "Hive roster reported the wrong caste")

/datum/unit_test/xeno_rework_buff_auras/Run()
	for(var/fruit_type in subtypesof(/obj/item/xeno_fruit))
		var/obj/item/xeno_fruit/fruit = allocate(fruit_type)
		var/mob/living/carbon/alien/adult/banda/drone/target = allocate(/mob/living/carbon/alien/adult/banda/drone)
		fruit.feed(target)
		target.update_icons()
		var/aura_count = 0
		for(var/datum/status_effect/xeno_aura/aura in target.status_effects.Copy())
			aura_count++
			var/filter_name = "xeno_aura_[aura.id]"
			TEST_ASSERT_NOTNULL(target.get_filter(filter_name), "[fruit_type] did not add an aura surviving icon updates")
			var/list/filter_data = target.get_filter_data(filter_name)
			TEST_ASSERT_EQUAL(filter_data["color"], aura.aura_color, "Fruit aura has the wrong color")
			qdel(aura)
			TEST_ASSERT_NULL(target.get_filter(filter_name), "Expired fruit buff left its aura behind")
		TEST_ASSERT(aura_count > 0, "[fruit_type] granted no colored aura")
	var/mob/living/carbon/alien/adult/banda/drone/fruit_target = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/obj/item/xeno_fruit/greater/healing_fruit = allocate(/obj/item/xeno_fruit/greater)
	var/obj/item/xeno_fruit/alacrity/speed_fruit = allocate(/obj/item/xeno_fruit/alacrity)
	healing_fruit.apply_fruit(fruit_target)
	TEST_ASSERT_NOTNULL(fruit_target.has_status_effect(/datum/status_effect/xeno_fruit_regen), "Healing fruit did not apply")
	speed_fruit.apply_fruit(fruit_target)
	TEST_ASSERT_NULL(fruit_target.has_status_effect(/datum/status_effect/xeno_fruit_regen), "A previous fruit remained active")
	TEST_ASSERT_NOTNULL(fruit_target.has_status_effect(/datum/status_effect/xeno_fruit_speed), "The newest fruit effect did not apply")
	var/obj/item/xeno_fruit/unstable/shield_fruit = allocate(/obj/item/xeno_fruit/unstable)
	shield_fruit.apply_fruit(fruit_target)
	TEST_ASSERT_NULL(fruit_target.has_status_effect(/datum/status_effect/xeno_fruit_speed), "Unstable fruit retained the previous speed bonus")
	TEST_ASSERT(istype(fruit_target.has_status_effect(/datum/status_effect/xeno_overshield), /datum/status_effect/xeno_overshield/fruit), "Unstable fruit did not own its shield")
	speed_fruit.apply_fruit(fruit_target)
	TEST_ASSERT_NULL(fruit_target.has_status_effect(/datum/status_effect/xeno_overshield), "A different fruit retained the unstable fruit shield")
	TEST_ASSERT_NULL(fruit_target.has_status_effect(/datum/status_effect/xeno_fruit_regen), "Replacing unstable fruit skipped its regeneration effect")
	var/datum/status_effect/xeno_overshield/ravager/innate_shield = fruit_target.apply_status_effect(/datum/status_effect/xeno_overshield/ravager, 50)
	healing_fruit.apply_fruit(fruit_target)
	TEST_ASSERT_EQUAL(fruit_target.has_status_effect(/datum/status_effect/xeno_overshield), innate_shield, "Changing fruit removed the Ravager ability shield")
	var/mob/living/carbon/alien/adult/banda/ravager/ravager = allocate(/mob/living/carbon/alien/adult/banda/ravager)
	ravager.apply_status_effect(/datum/status_effect/xeno_overshield/ravager, 50)
	TEST_ASSERT(ravager.has_status_effect(/datum/status_effect/xeno_overshield), "Ravager shield no longer participates in damage absorption")
	ravager.apply_status_effect(/datum/status_effect/xeno_super_empowered)
	TEST_ASSERT_NOTNULL(ravager.get_filter("xeno_aura_xeno_super_empowered"), "Super empowerment has no aura")
	ravager.remove_status_effect(/datum/status_effect/xeno_super_empowered)
	TEST_ASSERT_NULL(ravager.get_filter("xeno_aura_xeno_super_empowered"), "Super empowerment left its aura behind")
	TEST_ASSERT_NOTNULL(ravager.get_filter("xeno_aura_xeno_overshield"), "Removing super empowerment removed the remaining shield aura")
/datum/unit_test/xeno_rework_evacuation_population/Run()
	var/datum/xeno_evacuation/event = allocate(/datum/xeno_evacuation)
	var/datum/admin_verb/test_button = SSadmin_verbs.admin_verbs_by_type[/datum/admin_verb/start_xeno_evacuation_test]
	TEST_ASSERT_NOTNULL(test_button, "The xeno finale test button was not registered")
	TEST_ASSERT_EQUAL(test_button.permissions, R_DEBUG, "The finale test button does not require debug rights")
	TEST_ASSERT_EQUAL(test_button.category, ADMIN_CATEGORY_DEBUG, "The finale test button is missing from the debug category")
	TEST_ASSERT(!event.population_qualifies(14, 10), "Finale triggered below its minimum xeno population")
	TEST_ASSERT(!event.population_qualifies(15, 31), "Finale triggered below its population ratio")
	TEST_ASSERT(event.population_qualifies(15, 30), "Finale did not trigger at exactly 50 percent")
	TEST_ASSERT(event.population_qualifies(15, 0), "No remaining crew prevented the finale")

/datum/unit_test/xeno_rework_evacuation_hack
	normal_floor_required = TRUE

/datum/unit_test/xeno_rework_evacuation_hack/Run()
	var/datum/xeno_evacuation/event = allocate(/datum/xeno_evacuation)
	var/mob/living/carbon/human/survivor = allocate(/mob/living/carbon/human/consistent)
	survivor.mind_initialize()
	survivor.mind.set_assigned_role(SSjob.get_job_type(/datum/job/assistant))
	GLOB.alive_mob_list |= survivor
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	var/obj/machinery/computer/emergency_shuttle/console = allocate(/obj/machinery/computer/emergency_shuttle)
	var/obj/docking_port/mobile/emergency/original_shuttle = SSshuttle.emergency
	var/obj/docking_port/mobile/emergency/shuttle = allocate(/obj/docking_port/mobile/emergency, console.loc)
	shuttle.shuttle_areas[get_area(console)] = TRUE
	shuttle.calculate_docking_port_information()
	shuttle.register()
	var/list/defense_areas = shuttle.shuttle_areas
	shuttle.mode = SHUTTLE_DOCKED
	var/old_round_state = SSticker.current_state
	SSticker.current_state = GAME_STATE_PLAYING
	var/started_without_population = event.begin_evacuation()
	var/repeated_start_blocked = !event.begin_evacuation()
	SSticker.current_state = old_round_state
	event.defense_deadline = world.time + 5 SECONDS
	event.update_shuttle(shuttle)
	var/held_ignition = shuttle.timeLeft(1) > ENGINE_START_TIME
	event.defense_deadline = world.time + 1 MINUTES
	var/default_duration = event.hack_duration
	event.hack_duration = 0.1 SECONDS
	var/successes = 0
	for(var/stage in 1 to 4)
		if(event.hack(drone, console) && event.hack_stage == stage)
			successes++
	var/drone_won = event.outcome == XENO_EVAC_XENOS && shuttle.hijack_status == HIJACK_COMPLETED
	var/launch_delay = shuttle.timeLeft(1)
	event.resolved = FALSE
	event.outcome = null
	event.hack_stage = 0
	// Each outcome starts a new defense; the previous result may have started native ignition.
	shuttle.mode = SHUTTLE_DOCKED
	shuttle.setTimer(1 MINUTES)
	var/queen_completed = event.hack(queen, console) && event.hack_stage == 4 && event.resolved
	event.resolved = FALSE
	event.outcome = null
	shuttle.mode = SHUTTLE_DOCKED
	event.defense_deadline = world.time
	event.update_shuttle(shuttle)
	var/crew_won = event.resolved && event.outcome == XENO_EVAC_CREW
	survivor.mind.set_assigned_role(SSjob.get_job_type(/datum/job/ert))
	var/ert_counts_as_survivor = event.has_survivors(shuttle)
	survivor.death()
	event.resolved = FALSE
	event.outcome = null
	shuttle.mode = SHUTTLE_DOCKED
	event.update_shuttle(shuttle)
	var/no_survivors_lost = event.resolved && event.outcome == XENO_EVAC_XENOS
	GLOB.alive_mob_list -= survivor
	event.deploy_ert(shuttle)
	var/ert_slots = length(event.ert_spawners)
	var/ert_aboard = TRUE
	for(var/datum/weakref/reference as anything in event.ert_spawners)
		if(!(get_area(reference.resolve()) in defense_areas))
			ert_aboard = FALSE
	event.clear_spawners()
	SSshuttle.emergency = original_shuttle
	qdel(shuttle, force = TRUE)
	TEST_ASSERT(started_without_population, "The test entry point could not start the finale without a populated hive")
	TEST_ASSERT(repeated_start_blocked, "Repeated activation started the finale twice")
	TEST_ASSERT_EQUAL(default_duration, 30 SECONDS, "A hack stage must take thirty seconds")
	TEST_ASSERT(held_ignition, "Native ignition closed hacking before the defense deadline")
	TEST_ASSERT_EQUAL(successes, 4, "An ordinary xeno did not need exactly four successful stages")
	TEST_ASSERT(drone_won, "A completed hack did not award the xeno victory")
	TEST_ASSERT(launch_delay <= 10 SECONDS && launch_delay > 9 SECONDS, "A hijacked shuttle did not receive the ten second launch countdown")
	TEST_ASSERT(queen_completed, "A queen could not complete the hack in one stage")
	TEST_ASSERT(crew_won, "Survivors did not win when the defense deadline elapsed")
	TEST_ASSERT(ert_counts_as_survivor, "An ERT responder did not count as a surviving defender")
	TEST_ASSERT(no_survivors_lost, "A shuttle without living defenders awarded a crew victory")
	TEST_ASSERT_EQUAL(ert_slots, 3, "The shuttle did not receive exactly three ERT roles")
	TEST_ASSERT(ert_aboard, "ERT roles were placed outside the shuttle")
/datum/unit_test/xeno_rework_final_evolution/Run()
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = allocate(/mob/living/carbon/alien/adult/banda/warrior)
	var/mob/living/carbon/alien/adult/banda/sentinel/sentinel = allocate(/mob/living/carbon/alien/adult/banda/sentinel)
	var/event_active = GLOB.xeno_evacuation.active
	var/event_resolved = GLOB.xeno_evacuation.resolved
	GLOB.xeno_evacuation.active = FALSE
	var/normal_branch = sentinel.get_evolution_type()
	var/locked_branch = warrior.get_evolution_type()
	GLOB.xeno_evacuation.active = TRUE
	GLOB.xeno_evacuation.resolved = FALSE
	var/final_warrior = warrior.get_evolution_type()
	var/final_sentinel = sentinel.get_evolution_type()
	var/can_evolve = warrior.can_evolve()
	GLOB.xeno_evacuation.resolved = TRUE
	var/closed_branch = warrior.get_evolution_type()
	GLOB.xeno_evacuation.active = event_active
	GLOB.xeno_evacuation.resolved = event_resolved
	TEST_ASSERT_EQUAL(normal_branch, /mob/living/carbon/alien/adult/banda/praetorian, "The normal sentinel evolution was replaced before the finale")
	TEST_ASSERT_NULL(locked_branch, "Warrior's final evolution was available before the finale")
	TEST_ASSERT_EQUAL(final_warrior, /mob/living/carbon/alien/adult/banda/final_caste/crusher, "Warrior did not unlock Crusher")
	TEST_ASSERT_EQUAL(final_sentinel, /mob/living/carbon/alien/adult/banda/final_caste/boiler, "Sentinel did not unlock Boiler")
	TEST_ASSERT(can_evolve, "The old T3 slot limit blocked a final evolution")
	TEST_ASSERT_NULL(closed_branch, "Evolution remained unlocked after the finale resolved")

/datum/unit_test/xeno_rework_final_combat/Run()
	var/mob/living/carbon/alien/adult/banda/final_caste/crusher/crusher = allocate(/mob/living/carbon/alien/adult/banda/final_caste/crusher)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/alien/banda/crusher_stomp/stomp = locate() in crusher.actions
	stomp.Activate()
	TEST_ASSERT(victim.get_brute_loss() > 0, "Crusher stomp did not damage its target")
	TEST_ASSERT_EQUAL(crusher.get_brute_loss(), 0, "Crusher stomp damaged its owner")
	var/mob/living/carbon/alien/adult/banda/final_caste/boiler/boiler = allocate(/mob/living/carbon/alien/adult/banda/final_caste/boiler)
	var/datum/action/cooldown/alien/banda/boiler_create/create = locate() in boiler.actions
	boiler.acid_globs = 4
	boiler.neuro_globs = 3
	TEST_ASSERT(!create.Activate(), "Boiler exceeded its seven-glob capacity")
	TEST_ASSERT_EQUAL(boiler.get_max_plasma(), 1000, "Boiler does not have its artillery reservoir")
	var/obj/effect/particle_effect/fluid/smoke/xeno_boiler/acid/cloud = allocate(/obj/effect/particle_effect/fluid/smoke/xeno_boiler/acid)
	var/old_burn = victim.get_fire_loss()
	cloud.smoke_mob(victim, 0.5)
	cloud.smoke_mob(victim, 1.5)
	cloud.smoke_mob(boiler, 2)
	TEST_ASSERT_EQUAL(victim.get_fire_loss() - old_burn, 12, "Boiler cloud damage is not frame independent")
	TEST_ASSERT_EQUAL(boiler.get_fire_loss(), 0, "Boiler cloud damaged an allied xeno")

/datum/unit_test/xeno_rework_hunter_tools/Run()
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = allocate(/mob/living/carbon/alien/adult/banda/final_caste/hunter)
	var/old_alpha = hunter.alpha
	hunter.apply_status_effect(/datum/status_effect/xeno_hunter_stealth)
	TEST_ASSERT(hunter.alpha <= 128, "Hunter stealth did not camouflage its owner")
	hunter.apply_damage(5, BRUTE)
	TEST_ASSERT_NULL(hunter.has_status_effect(/datum/status_effect/xeno_hunter_stealth), "Damage did not break Hunter stealth")
	TEST_ASSERT_EQUAL(hunter.alpha, old_alpha, "Hunter stealth did not restore the original alpha")
	hunter.apply_status_effect(/datum/status_effect/xeno_hunter_stealth)
	hunter.pouncing = TRUE
	hunter.end_pounce()
	TEST_ASSERT_NULL(hunter.has_status_effect(/datum/status_effect/xeno_hunter_stealth), "A missed pounce did not reveal the Hunter")
	var/datum/action/cooldown/alien/banda/hunter_mirage/mirage = locate() in hunter.actions
	mirage.Activate(hunter)
	TEST_ASSERT_EQUAL(length(mirage.decoys), 3, "Mirage did not create three decoys")
	var/datum/weakref/reference = mirage.decoys[1]
	var/obj/effect/temp_visual/decoy/illusion = reference.resolve()
	TEST_ASSERT_NOTNULL(illusion, "Mirage immediately lost its decoy")
	TEST_ASSERT_EQUAL(illusion.mouse_opacity, MOUSE_OPACITY_ICON, "Mirage cannot be clicked for swapping")
	var/turf/destination = illusion.loc
	TEST_ASSERT(mirage.Activate(illusion), "Hunter could not swap with its visible owned mirage")
	TEST_ASSERT_EQUAL(hunter.loc, destination, "Mirage swap did not move the Hunter")
	TEST_ASSERT_EQUAL(length(mirage.decoys), 0, "Used mirages retained their references")
