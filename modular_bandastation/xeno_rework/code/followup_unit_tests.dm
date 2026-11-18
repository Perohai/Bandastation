/datum/unit_test/xeno_rework_hive/support_gates/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	var/mob/living/carbon/alien/adult/banda/praetorian/praetorian = allocate(/mob/living/carbon/alien/adult/banda/praetorian)
	var/mob/living/carbon/alien/adult/banda/carrier/carrier = allocate(/mob/living/carbon/alien/adult/banda/carrier)
	for(var/mob/living/carbon/alien/adult/banda/member as anything in list(queen, praetorian, carrier))
		TEST_ASSERT_NULL(locate(/datum/action/cooldown/alien/banda/hive_pheromones) in member.actions, "[member.type] has innate healing")
		if(member == queen)
			continue
		TEST_ASSERT_NULL(member.get_organ_slot(ORGAN_SLOT_XENO_RESINSPINNER), "[member.type] still has a resin spinner")
		var/datum/action/cooldown/alien/build_resin_structure/forged = allocate(/datum/action/cooldown/alien/build_resin_structure)
		forged.Grant(member)
		TEST_ASSERT(!forged.IsAvailable(), "Forged construction bypassed [member.type]'s restriction")
		var/datum/action/cooldown/alien/make_structure/resin/native_resin = allocate(/datum/action/cooldown/alien/make_structure/resin)
		native_resin.Grant(member)
		TEST_ASSERT(!native_resin.IsAvailable(), "A native resin spinner bypassed [member.type]'s restriction")
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/alien/make_structure/plant_weeds) in praetorian.actions, "Praetorian lost its agreed weed planting")
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/alien/make_structure/lay_egg) in carrier.actions, "Carrier lost its agreed egg laying")
	hive.purchased["coordination"] = 1
	hive.biomass = 180
	hive.purchase_time = 0
	TEST_ASSERT(hive.buy(queen, "pheromones"), "Healing upgrade could not be purchased")
	for(var/mob/living/carbon/alien/adult/banda/member as anything in list(queen, praetorian, carrier))
		var/datum/action/cooldown/alien/banda/hive_pheromones/healing = locate() in member.actions
		TEST_ASSERT_NOTNULL(healing, "Purchased healing missed an existing [member.type]")
		TEST_ASSERT(healing.IsAvailable(), "Purchased healing remains unusable on [member.type]")
	var/mob/living/carbon/alien/adult/banda/praetorian/future = allocate(/mob/living/carbon/alien/adult/banda/praetorian)
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/alien/banda/hive_pheromones) in future.actions, "Future support caste did not inherit healing")
	var/mob/living/carbon/alien/adult/banda/runner/runner = allocate(/mob/living/carbon/alien/adult/banda/runner)
	var/datum/action/cooldown/alien/banda/hive_pheromones/forged_healing = allocate(/datum/action/cooldown/alien/banda/hive_pheromones)
	forged_healing.Grant(runner)
	TEST_ASSERT(!forged_healing.IsAvailable() && !forged_healing.Activate(), "A non-support caste bypassed the healing gate")
	for(var/mob/living/carbon/alien/adult/banda/member as anything in list(queen, praetorian, carrier, runner))
		TEST_ASSERT_EQUAL(member.sprite_scale, 0.9, "Previous visual scale was not restored")
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = allocate(/mob/living/carbon/alien/adult/banda/final_caste/hunter)
	TEST_ASSERT_EQUAL(hunter.get_cached_width(), 32, "Hunter is not a one-tile sprite")
	TEST_ASSERT_EQUAL(hunter.sprite_scale, 1, "Native 32x32 Hunter was shrunk a second time")

/datum/unit_test/xeno_rework_hive/hunter_entry/Run()
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = allocate(/mob/living/carbon/alien/adult/banda/final_caste/hunter)
	// Keep the cancellation assertion independent of the native organ processing tick.
	var/obj/item/organ/alien/plasmavessel/vessel = hunter.get_organ_slot(ORGAN_SLOT_XENO_PLASMAVESSEL)
	vessel.plasma_rate = 0
	var/datum/action/cooldown/alien/banda/hunter_stealth/stealth = locate() in hunter.actions
	TEST_ASSERT_EQUAL(stealth.entry_time, 3 SECONDS, "Hunter default preparation is not three seconds")
	stealth.entry_time = 0.3 SECONDS
	var/before = hunter.getPlasma()
	INVOKE_ASYNC(stealth, TYPE_PROC_REF(/datum/action/cooldown/alien/banda/hunter_stealth, PreActivate), hunter)
	sleep(0.1 SECONDS)
	TEST_ASSERT(stealth.preparing, "Hunter did not enter a preparation channel")
	TEST_ASSERT_NULL(hunter.has_status_effect(/datum/status_effect/xeno_hunter_stealth), "Camouflage applied instantly")
	TEST_ASSERT(!stealth.Activate(), "Parallel camouflage entry was accepted")
	hunter.forceMove(get_step(hunter, NORTH))
	sleep(0.4 SECONDS)
	TEST_ASSERT(!stealth.preparing && !hunter.has_status_effect(/datum/status_effect/xeno_hunter_stealth), "Movement did not cancel camouflage")
	TEST_ASSERT_EQUAL(hunter.getPlasma(), before, "Cancelled camouflage spent plasma")
	INVOKE_ASYNC(stealth, TYPE_PROC_REF(/datum/action/cooldown/alien/banda/hunter_stealth, PreActivate), hunter)
	sleep(0.1 SECONDS)
	hunter.apply_damage(1, BRUTE)
	hunter.adjust_brute_loss(-1)
	sleep(0.4 SECONDS)
	TEST_ASSERT_NULL(hunter.has_status_effect(/datum/status_effect/xeno_hunter_stealth), "Healed damage failed to interrupt camouflage")
	stealth.entry_time = 0
	TEST_ASSERT(stealth.PreActivate(hunter), "Uninterrupted Hunter could not enter camouflage")
	TEST_ASSERT_NOTNULL(hunter.has_status_effect(/datum/status_effect/xeno_hunter_stealth), "Successful channel did not camouflage")

/datum/unit_test/xeno_rework_hive/adult_evolution_channel/Run()
	var/mob/living/carbon/alien/adult/banda/sentinel/sentinel = allocate(/mob/living/carbon/alien/adult/banda/sentinel)
	sentinel.adjustPlasma(sentinel.get_max_plasma())
	var/datum/action/cooldown/alien/banda/generic_evolve/evolution = locate() in sentinel.actions
	TEST_ASSERT_EQUAL(evolution.evolution_time, 5 SECONDS, "Adult evolution is not five seconds")
	evolution.evolution_time = 0.3 SECONDS
	INVOKE_ASYNC(evolution, TYPE_PROC_REF(/datum/action/cooldown/alien/banda/generic_evolve, PreActivate), sentinel)
	sleep(0.1 SECONDS)
	TEST_ASSERT(evolution.evolving && !QDELETED(sentinel), "Adult evolution happened instantly")
	TEST_ASSERT_NOTNULL(sentinel.get_filter("xeno_evolution"), "Adult evolution has no animation")
	TEST_ASSERT(!evolution.evolve_into(/mob/living/carbon/alien/adult/banda/spitter), "Concurrent evolution was accepted")
	sentinel.forceMove(get_step(sentinel, NORTH))
	sleep(0.4 SECONDS)
	TEST_ASSERT(!QDELETED(sentinel) && !evolution.evolving, "Movement failed to cancel adult evolution")
	TEST_ASSERT_NULL(sentinel.get_filter("xeno_evolution"), "Cancelled evolution retained its glow")
	TEST_ASSERT(!evolution.evolve_into(/mob/living/carbon/alien/adult/banda/queen), "Adult accepted an unlisted caste")
	var/mob/living/carbon/alien/adult/banda/spitter/spitter = allocate(/mob/living/carbon/alien/adult/banda/spitter)
	spitter.adjustPlasma(spitter.get_max_plasma())
	var/datum/action/cooldown/alien/banda/generic_evolve/tier3 = locate() in spitter.actions
	tier3.evolution_time = 0.3 SECONDS
	INVOKE_ASYNC(tier3, TYPE_PROC_REF(/datum/action/cooldown/alien/banda/generic_evolve, PreActivate), spitter)
	sleep(0.1 SECONDS)
	var/mob/living/carbon/alien/adult/banda/praetorian/blocker = allocate(/mob/living/carbon/alien/adult/banda/praetorian)
	sleep(0.4 SECONDS)
	TEST_ASSERT(!QDELETED(spitter), "Evolution ignored a slot occupied during its channel")
	qdel(blocker)
	tier3.evolution_time = 0
	TEST_ASSERT(tier3.PreActivate(spitter), "Adult could not retry after the slot became free")
	TEST_ASSERT(QDELETED(spitter), "Successful adult evolution retained the old body")
	var/mob/living/carbon/alien/adult/banda/praetorian/evolved = locate() in hive.members
	TEST_ASSERT_NOTNULL(evolved, "No adult was created after shedding")
	TEST_ASSERT(evolved.has_evolved_recently, "Adult evolution lost the existing 90-second gate")
	TEST_ASSERT_NULL(evolved.get_filter("xeno_evolution"), "Evolution glow leaked to the new body")

/datum/unit_test/xeno_rework_hive/rally_navigation/Run()
	var/mob/living/carbon/alien/adult/banda/runner/runner = allocate(/mob/living/carbon/alien/adult/banda/runner)
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/alien/banda/hive_rally_track) in runner.actions, "Rally tracking is available before purchase")
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	hive.purchased["coordination"] = 1
	hive.apply_upgrades(queen)
	hive.apply_upgrades(runner)
	var/datum/action/cooldown/alien/banda/hive_rally/rally = locate() in queen.actions
	var/datum/action/cooldown/alien/banda/hive_rally_track/follow = locate() in runner.actions
	TEST_ASSERT_NOTNULL(rally, "Purchase missed the rally placement action")
	TEST_ASSERT_NOTNULL(follow, "Purchase missed the rally tracking action")
	TEST_ASSERT(rally.PreActivate(get_step(runner, NORTH)), "Visible rally point could not be placed")
	TEST_ASSERT(follow.PreActivate(), "Rally tracking could not be toggled on")
	var/datum/status_effect/agent_pinpointer/xeno_rally/tracker = runner.has_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
	TEST_ASSERT_NOTNULL(tracker, "Tracking did not create a native pinpointer")
	TEST_ASSERT_EQUAL(tracker.scan_target, hive.rally_points[REF(queen)], "Pinpointer lost the shared marker")
	TEST_ASSERT_EQUAL(tracker.direction_arrow.dir, NORTH, "Pinpointer points away from the rally point")
	rally.ResetCooldown()
	TEST_ASSERT(rally.PreActivate(get_step(runner, EAST)), "Rally point could not be relocated")
	tracker.tick(0)
	TEST_ASSERT_EQUAL(tracker.direction_arrow.dir, EAST, "Active tracking ignored rally relocation")
	qdel(hive.rally_points[REF(queen)])
	TEST_ASSERT_NULL(tracker.scan_target, "Deleted marker remains strongly referenced")
	tracker.tick(0)
	TEST_ASSERT_EQUAL(tracker.direction_arrow.alpha, 0, "Deleted marker still shows a direction")
	TEST_ASSERT(follow.PreActivate(), "Rally tracking could not be toggled off")
	TEST_ASSERT_NULL(runner.has_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally), "Tracking remains after toggle-off")
	TEST_ASSERT(hive.set_rally_point(queen, get_step(runner, NORTH)), "The queen could not set a marker")
	var/mob/living/carbon/alien/adult/banda/final_caste/crusher/crusher = allocate(/mob/living/carbon/alien/adult/banda/final_caste/crusher)
	TEST_ASSERT(hive.set_rally_point(crusher, get_step(runner, EAST)), "The crusher could not set a separate marker")
	TEST_ASSERT_EQUAL(length(hive.rally_points), 2, "Setters overwrote each other's markers")
	TEST_ASSERT(hive.set_rally_point(crusher, get_step(runner, NORTHEAST)), "The crusher could not relocate its marker")
	TEST_ASSERT_EQUAL(length(hive.rally_points), 2, "Relocation left the previous marker in the roster")
	TEST_ASSERT(hive.follow_rally_target(runner, queen), "The roster could not follow a living xeno")
	tracker = runner.has_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
	queen.forceMove(get_step(runner, NORTH))
	tracker.tick(0)
	TEST_ASSERT_EQUAL(tracker.direction_arrow.dir, NORTH, "The pointer did not follow a moving xeno")
	qdel(queen)
	TEST_ASSERT_NULL(tracker.scan_target, "Deleted xeno remains targeted")
	TEST_ASSERT_EQUAL(length(hive.rally_points), 1, "The setter's old marker remains in the roster")

/datum/unit_test/xeno_rework_hive/boiler_spray_length
	normal_floor_required = TRUE

/datum/unit_test/xeno_rework_hive/boiler_spray_length/Run()
	var/mob/living/carbon/alien/adult/banda/final_caste/boiler/boiler = allocate(/mob/living/carbon/alien/adult/banda/final_caste/boiler)
	var/datum/action/cooldown/alien/banda/acid_spray/boiler/spray = locate() in boiler.actions
	TEST_ASSERT(spray.PreActivate(get_ranged_target_turf(boiler, NORTH, 5)), "Boiler could not spray four tiles")
	sleep(0.6 SECONDS)
	for(var/distance in 1 to 4)
		var/turf/location = get_ranged_target_turf(boiler, NORTH, distance)
		TEST_ASSERT_NOTNULL(locate(/obj/effect/xeno_acid_pool/spray) in location, "Boiler spray missed tile [distance]")
	var/turf/beyond = get_ranged_target_turf(boiler, NORTH, 5)
	TEST_ASSERT_NULL(locate(/obj/effect/xeno_acid_pool/spray) in beyond, "Boiler spray exceeded four tiles")
	var/mob/living/carbon/alien/adult/banda/spitter/spitter = allocate(/mob/living/carbon/alien/adult/banda/spitter)
	var/datum/action/cooldown/alien/banda/acid_spray/spitter/other_spray = locate() in spitter.actions
	TEST_ASSERT_EQUAL(other_spray.spray_length, 3, "Boiler tuning changed Spitter spray")

/datum/unit_test/xeno_rework_hive/minion_attack_visuals/Run()
	hive.purchased["mantis_ravage"] = 1
	var/mob/living/carbon/alien/brood/mantis/mantis = allocate(/mob/living/carbon/alien/brood/mantis, get_ranged_target_turf(run_loc_floor_bottom_left, NORTH, 2))
	var/mob/living/carbon/human/front = allocate(/mob/living/carbon/human/consistent, get_step(mantis, NORTH))
	var/mob/living/carbon/human/behind = allocate(/mob/living/carbon/human/consistent, get_step(mantis, SOUTH))
	var/datum/action/cooldown/alien/brood_ravage/ravage = locate() in mantis.actions
	mantis.adjustPlasma(mantis.get_max_plasma())
	ravage.windup_time = 0
	TEST_ASSERT(ravage.PreActivate(front), "Mantis ravage could not activate")
	TEST_ASSERT_EQUAL(front.get_brute_loss(), 12, "Mantis ravage did not damage its target")
	TEST_ASSERT_EQUAL(behind.get_brute_loss(), 0, "Mantis ravage damaged a target behind it")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/cleave) in get_step(mantis, NORTH), "Mantis sweep has no visible arc")
	front.forceMove(get_step(mantis, NORTH))
	ravage.ResetCooldown()
	ravage.windup_time = 0.3 SECONDS
	mantis.adjustPlasma(mantis.get_max_plasma())
	INVOKE_ASYNC(ravage, TYPE_PROC_REF(/datum/action/cooldown/alien/brood_ravage, PreActivate), front)
	sleep(0.1 SECONDS)
	var/mob/living/carbon/alien/brood/mantis/replacement = allocate(/mob/living/carbon/alien/brood/mantis, mantis.loc)
	replacement.adjustPlasma(replacement.get_max_plasma())
	ravage.Grant(replacement)
	sleep(0.4 SECONDS)
	TEST_ASSERT_EQUAL(front.get_brute_loss(), 12, "Ravage survived transfer to another owner during its windup")
	qdel(replacement)
	qdel(mantis)
	qdel(front)
	qdel(behind)
	hive.purchased["beetle_charge"] = 1
	var/mob/living/carbon/alien/brood/beetle = allocate(/mob/living/carbon/alien/brood)
	var/datum/action/cooldown/alien/brood_charge/charge = locate() in beetle.actions
	charge.windup_time = 0.3 SECONDS
	INVOKE_ASYNC(charge, TYPE_PROC_REF(/datum/action/cooldown/alien/brood_charge, PreActivate), get_ranged_target_turf(beetle, NORTH, 3))
	sleep(0.1 SECONDS)
	TEST_ASSERT(charge.preparing, "Beetle skipped its warning windup")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/telegraphing/exclamation) in beetle.loc, "Beetle has no exclamation before charging")
	sleep(1 SECONDS)
	TEST_ASSERT(!beetle.charging && (beetle.pass_flags & PASSMOB), "Completed beetle charge lost its collision cleanup")
	TEST_ASSERT_NULL(beetle.get_filter("minion_charge"), "Completed beetle charge retained its motion blur")

/datum/unit_test/xeno_rework_hive/corpse_swallow_gate/Run()
	var/mob/living/carbon/alien/adult/banda/drone/eater = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/stomach/alien_banda/stomach = eater.get_organ_slot(ORGAN_SLOT_STOMACH)
	var/datum/action/cooldown/alien/hive_swallow/swallow = locate() in eater.actions
	prey.death()
	TEST_ASSERT(!swallow.PreActivate(prey), "Dedicated skill swallowed a corpse")
	TEST_ASSERT(!eater.can_consume(prey), "Grab path accepted a corpse")
	TEST_ASSERT(!stomach.consume_thing(prey), "Direct consumption bypassed the corpse gate")
	TEST_ASSERT(!(prey in stomach.stomach_contents), "Rejected corpse entered stomach bookkeeping")
	prey.revive(ADMIN_HEAL_ALL, force_grab_ghost = FALSE)
	swallow.swallow_time = 0.3 SECONDS
	INVOKE_ASYNC(swallow, TYPE_PROC_REF(/datum/action/cooldown/alien/hive_swallow, PreActivate), prey)
	sleep(0.1 SECONDS)
	prey.death()
	sleep(0.4 SECONDS)
	TEST_ASSERT(!(prey in stomach.stomach_contents), "Prey dying during the channel was swallowed")
	var/obj/structure/xeno_hive_egg/larva/egg = allocate(/obj/structure/xeno_hive_egg/larva)
	TEST_ASSERT(egg.icon_state in icon_states(egg.icon), "Larval egg refers to a nonexistent sprite state")


/datum/unit_test/xeno_rework_hive/carrier_traps/Run()
	var/mob/living/carbon/alien/adult/banda/carrier/carrier = allocate(/mob/living/carbon/alien/adult/banda/carrier)
	TEST_ASSERT_EQUAL(carrier.get_max_plasma(), 250, "Carrier plasma cap is wrong")
	var/turf/site = carrier.loc
	allocate(/obj/structure/alien/weeds, site)
	var/obj/item/clothing/mask/facehugger/hugger = allocate(/obj/item/clothing/mask/facehugger, site)
	TEST_ASSERT(carrier.store_hugger(hugger), "Cannot store test hugger")
	carrier.adjustPlasma(250)
	var/datum/action/cooldown/alien/banda/carrier_trap/trap_action = locate() in carrier.actions
	TEST_ASSERT(trap_action.PreActivate(), "Cannot build loaded trap")
	var/obj/structure/alien/carrier_trap/trap = locate() in site
	TEST_ASSERT(trap && trap.hugger == hugger, "Trap lost its hugger")
	TEST_ASSERT_EQUAL(length(carrier.stored_huggers), 0, "Carrier kept the placed hugger")
	trap.take_damage(100, BRUTE, MELEE)
	TEST_ASSERT(!QDELETED(hugger) && hugger.loc == site, "Destruction did not release the hugger")

/datum/unit_test/xeno_rework_hive/warrior_agility_pull/Run()
	var/mob/living/carbon/alien/adult/banda/warrior/warrior = allocate(/mob/living/carbon/alien/adult/banda/warrior)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(warrior.start_pulling(victim), "Warrior cannot pull normally")
	warrior.enter_agility()
	TEST_ASSERT_NULL(warrior.pulling, "Agility kept the existing grab")
	TEST_ASSERT(!warrior.start_pulling(victim), "Agility allowed another grab")
	warrior.exit_agility()
	TEST_ASSERT(warrior.start_pulling(victim), "Leaving agility did not restore pulling")

/datum/unit_test/xeno_rework_hive/biostructure_gates/Run()
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/alien/adult/banda/spitter/spitter = allocate(/mob/living/carbon/alien/adult/banda/spitter)
	TEST_ASSERT(!can_build_hive_structure(drone, /obj/structure/alien/acid_turret), "Locked turret was buildable")
	hive.purchased["acid_turrets"] = 1
	TEST_ASSERT(can_build_hive_structure(drone, /obj/structure/alien/acid_turret), "Unlocked turret stayed locked")
	TEST_ASSERT(!can_build_hive_structure(spitter, /obj/structure/alien/acid_turret), "Non-builder could place turret")
	TEST_ASSERT_EQUAL(hive_structure_spec(/obj/structure/alien/acid_turret)["plasma"], 250, "Turret price exceeds drone capacity")


/datum/unit_test/xeno_rework_hive/biostructure_damage/Run()
	var/turf/site = get_step(run_loc_floor_bottom_left, NORTH)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(site, EAST))
	var/obj/structure/alien/acid_mine/mine = allocate(/obj/structure/alien/acid_mine, site)
	mine.detonate()
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 30, "Acid mine did not damage its victim exactly once")
	TEST_ASSERT(QDELETED(mine), "Triggered mine remained alive")
	var/obj/structure/alien/acid_turret/turret = allocate(/obj/structure/alien/acid_turret, site)
	allocate(/obj/structure/alien/weeds, site)
	turret.process(1)
	TEST_ASSERT(turret.next_shot > world.time, "Turret did not start its shot interval")

/datum/unit_test/xeno_rework_hive/crusher_block_stun/Run()
	var/mob/living/carbon/alien/adult/banda/final_caste/crusher/crusher = allocate(/mob/living/carbon/alien/adult/banda/final_caste/crusher)
	crusher.setDir(NORTH)
	crusher.momentum = crusher.max_steps_buildup
	crusher.charge_direction = NORTH
	crusher.last_charge_step = world.time
	crusher.adjustPlasma(crusher.get_max_plasma())
	var/obj/structure/closet/blocker = allocate(/obj/structure/closet, get_step(crusher, NORTH))
	blocker.resistance_flags |= INDESTRUCTIBLE
	crusher.Bump(blocker)
	TEST_ASSERT(crusher.IsParalyzed(), "Indestructible obstacle did not stun the crusher")
	TEST_ASSERT_EQUAL(crusher.momentum, 0, "Blocked crusher kept its momentum")

/datum/unit_test/xeno_rework_hive/trap_protection/Run()
	var/mob/living/carbon/alien/adult/banda/carrier/carrier = allocate(/mob/living/carbon/alien/adult/banda/carrier)
	var/turf/site = carrier.loc
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(site, NORTH))
	var/obj/item/clothing/mask/breath/mask = allocate(/obj/item/clothing/mask/breath)
	victim.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK)
	for(var/attempt in 1 to 2)
		var/obj/item/clothing/mask/facehugger/hugger = allocate(/obj/item/clothing/mask/facehugger, site)
		var/obj/structure/alien/carrier_trap/trap = allocate(/obj/structure/alien/carrier_trap, site, hugger)
		trap.on_entered(site, victim)
		if(attempt == 1)
			TEST_ASSERT_EQUAL(mask.trap_hugger_protection, 0, "Trap hugger did not consume mask protection")
			TEST_ASSERT_EQUAL(victim.wear_mask, mask, "First trap hugger removed protected mask")
		else
			TEST_ASSERT_EQUAL(victim.wear_mask, hugger, "Second trap hugger failed to bypass spent protection")


/datum/unit_test/xeno_rework_hive/carrier_reserve/Run()
	var/carrier_type = /mob/living/carbon/alien/adult/banda/carrier
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	hive.purchased["carrier"] = 1
	TEST_ASSERT(drone.can_evolve(carrier_type), "Carrier unlock did not open the first slot")
	allocate(carrier_type)
	TEST_ASSERT(!drone.can_evolve(carrier_type), "Carrier limit was not enforced")
	hive.purchased["carrier_slot"] = 1
	TEST_ASSERT(drone.can_evolve(carrier_type), "Carrier reserve did not open another slot")

/datum/unit_test/xeno_rework_hive/shove_stamina_recovery/Run()
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.stamina_regen_time = 1 SECONDS
	victim.adjust_stamina_loss(victim.max_stamina)
	TEST_ASSERT_NOTNULL(victim.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Initial stamina damage did not exhaust the victim")
	sleep(0.6 SECONDS)
	victim.attack_banda_alien(drone, list(RIGHT_CLICK = TRUE))
	sleep(0.6 SECONDS)
	TEST_ASSERT_NOTNULL(victim.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Shove did not refresh recovery at the damage cap")
