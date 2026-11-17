/datum/unit_test/xeno_rework_hive/rally_empty_target/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	hive.purchased["coordination"] = 1
	hive.apply_upgrades(queen)
	hive.purchase_busy = TRUE
	var/datum/action/cooldown/alien/banda/hive_rally_track/follow = locate() in queen.actions
	TEST_ASSERT(follow.PreActivate(), "Following an unset rally point during a purchase failed")
	var/datum/status_effect/agent_pinpointer/xeno_rally/tracker = queen.has_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
	TEST_ASSERT_NULL(tracker.linked_alert, "Rally pointer remains a corner HUD alert")
	TEST_ASSERT_EQUAL(tracker.direction_arrow.alpha, 0, "Empty rally target shows a stray arrow")
	TEST_ASSERT(follow.PreActivate(), "Empty rally tracker could not be removed")
	TEST_ASSERT_NULL(queen.alternate_appearances?["xeno_rally_direction"], "Removed arrow retained its personal HUD")
	hive.purchase_busy = FALSE

/datum/unit_test/xeno_rework_hive/rally_permissions/Run()
	hive.purchased["coordination"] = 1
	for(var/caste_type in valid_subtypesof(/mob/living/carbon/alien/adult/banda))
		var/mob/living/carbon/alien/adult/banda/member = allocate(caste_type)
		var/allowed = istype(member, /mob/living/carbon/alien/adult/banda/queen) || member.evolution_tier == 4
		TEST_ASSERT_EQUAL(hive.can_set_rally(member), allowed, "Wrong rally permission for [caste_type]")
		TEST_ASSERT_EQUAL(!!(locate(/datum/action/cooldown/alien/banda/hive_rally) in member.actions), allowed, "Wrong rally button for [caste_type]")
		if(!allowed)
			var/datum/action/cooldown/alien/banda/hive_rally/forged = allocate(/datum/action/cooldown/alien/banda/hive_rally)
			forged.Grant(member)
			TEST_ASSERT(!forged.Activate(get_step(member, NORTH)), "Forged action bypassed rally caste permission")
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	TEST_ASSERT(hive.can_set_rally(hivemind), "Spirit Hivemind cannot coordinate the hive")

/datum/unit_test/xeno_rework_hive/hivemind_repeat_form/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/datum/action/cooldown/alien/hivemind/form/form = locate() in hivemind.actions
	var/obj/item/organ/alien/plasmavessel/hivemind/vessel = hivemind.get_organ_slot(ORGAN_SLOT_XENO_PLASMAVESSEL)
	form.form_time = 0
	TEST_ASSERT_EQUAL(vessel.max_plasma, 400, "Hivemind retained its old reservoir")
	for(var/iteration in 1 to 3)
		TEST_ASSERT(form.PreActivate(), "Hivemind could not manifest on cycle [iteration]")
		hivemind.adjust_brute_loss(10)
		TEST_ASSERT(form.PreActivate(), "Injured Hivemind could not voluntarily disperse")
		TEST_ASSERT(!form.IsAvailable(), "Injured spirit can immediately manifest")
		vessel.on_life(2)
		TEST_ASSERT_EQUAL(hivemind.health, hivemind.maxHealth, "GODMODE prevented spirit recovery")
	TEST_ASSERT(form.PreActivate(), "Recovered spirit remained locked after repeated transitions")

/datum/unit_test/xeno_rework_hive/hivemind_examine/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/list/examination = hive.hivemind_anchor.examine(hivemind)
	TEST_ASSERT(length(examination), "Occupied anchor has no examination text")
	var/datum/atom_hud/alternate_appearance/basic/marker = hivemind.alternate_appearances["hivemind_spirit"]
	TEST_ASSERT_EQUAL(marker.image.pixel_x, 0, "Spirit marker inherits the physical sprite's horizontal offset")
	TEST_ASSERT_EQUAL(marker.image.pixel_y, 0, "Spirit marker inherits the physical sprite's vertical offset")
	hive.hivemind_anchor.take_damage(1000, BRUTE, MELEE)
	TEST_ASSERT(QDELETED(hivemind), "Destroyed occupied anchor retained Hivemind")

/** Drive the real SSobj queue, rather than calling advance_brood by hand. */
/datum/unit_test/xeno_rework_hive/brood_background/Run()
	allocate(/mob/living/carbon/alien/adult/banda/queen)
	allocate(/obj/structure/alien/weeds/node)
	var/obj/structure/xeno_hive_core/core = allocate(/obj/structure/xeno_hive_core)
	core.cached_crew = 60
	core.crew_sample_time = INFINITY
	hive.brood_slot_cost = 2
	TEST_ASSERT(core in SSobj.processing, "Installed brood core never entered SSobj processing")
	var/deadline = world.time + 10 SECONDS
	while(!core.available_brood() && world.time < deadline)
		sleep(0.5 SECONDS)
	TEST_ASSERT(core.available_brood() > 0, "SSobj did not accumulate points and create a brood egg")
	TEST_ASSERT_EQUAL(hive.biomass, 0, "Passive brood income generated biomass")

/datum/unit_test/xeno_rework_hive/fruit_pacing/Run()
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/datum/action/cooldown/alien/banda/grow_fruit/grow = locate() in drone.actions
	drone.adjustPlasma(199 - drone.getPlasma())
	TEST_ASSERT(!grow.IsAvailable(), "A fruit can be planted for less than 200 plasma")
	drone.adjustPlasma(1)
	TEST_ASSERT(grow.IsAvailable(), "A drone with 200 plasma cannot plant a fruit")
	var/obj/item/xeno_fruit/unstable/fruit = allocate(/obj/item/xeno_fruit/unstable)
	TEST_ASSERT_EQUAL(fruit.growth_time, 90 SECONDS, "Fruit maturation was not lengthened to 90 seconds")
	TEST_ASSERT(!fruit.ripe && !fruit.pheromones, "Fresh fruit is immediately usable")

/datum/unit_test/xeno_rework_hive/egg_landing_visibility/Run()
	allocate(/mob/living/carbon/alien/adult/banda/queen)
	allocate(/obj/structure/alien/weeds/node)
	var/obj/structure/xeno_hive_core/core = allocate(/obj/structure/xeno_hive_core)
	STOP_PROCESSING(SSobj, core)
	TEST_ASSERT_EQUAL(core.add_brood(1), 1, "No brood egg was created for the ejection test")
	var/obj/structure/xeno_hive_egg/egg = core.brood_eggs[1]
	sleep(1.3 SECONDS)
	TEST_ASSERT_EQUAL(egg.alpha, 255, "Landed brood egg remained invisible")
	TEST_ASSERT(abs(egg.pixel_x) <= 3 && abs(egg.pixel_y) <= 3, "Egg retained its ejection offset")
	TEST_ASSERT(core.next_to_core(egg) && egg.spawner.uses == 1, "Ejection moved or consumed the native role")

/datum/unit_test/xeno_rework_hive/hivemind_physical_return/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/datum/action/cooldown/alien/hivemind/return_core/return_action = locate() in hivemind.actions
	var/turf/destination = get_step(hivemind, NORTH)
	allocate(/obj/structure/alien/weeds, destination)
	hivemind.forceMove(destination)
	hivemind.set_manifestation(TRUE)
	TEST_ASSERT(!return_action.IsAvailable() && !return_action.Activate(), "Physical Hivemind can use Return to anchor")
	TEST_ASSERT(!hivemind.return_to_core(), "Direct return bypassed the physical-form restriction")
	TEST_ASSERT_EQUAL(hivemind.loc, destination, "Rejected return still moved Hivemind")
	hivemind.disperse()
	TEST_ASSERT_EQUAL(hivemind.loc, hive.hivemind_anchor.loc, "Defeated shell cannot return as a spirit")
	TEST_ASSERT(return_action.IsAvailable(), "Spirit return remained blocked by reformation cooldown")

/datum/unit_test/xeno_rework_hive/hunter_last_slot/Run()
	hive.purchased["ravager"] = 1
	var/mob/living/carbon/alien/adult/banda/runner/runner = allocate(/mob/living/carbon/alien/adult/banda/runner)
	var/datum/action/cooldown/alien/banda/generic_evolve/evolve = locate() in runner.actions
	var/hunter_type = /mob/living/carbon/alien/adult/banda/final_caste/hunter
	var/before = runner.getPlasma()
	evolve.evolution_time = 0.3 SECONDS
	INVOKE_ASYNC(evolve, TYPE_PROC_REF(/datum/action/cooldown/alien/banda/generic_evolve, evolve_into), hunter_type)
	sleep(0.1 SECONDS)
	TEST_ASSERT(evolve.evolving, "Hunter evolution did not start its channel")
	allocate(hunter_type)
	sleep(0.4 SECONDS)
	TEST_ASSERT(!QDELETED(runner), "Evolution consumed an occupied Hunter slot after the channel")
	TEST_ASSERT_EQUAL(runner.getPlasma(), before, "Rejected Hunter evolution consumed plasma")
	TEST_ASSERT(!evolve.evolving, "Rejected evolution retained its lock")

/datum/unit_test/xeno_rework_hive/hunter_silence_balance/Run()
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = allocate(/mob/living/carbon/alien/adult/banda/final_caste/hunter)
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent, get_step(hunter, NORTH))
	var/mob/living/carbon/human/marked = allocate(/mob/living/carbon/human/consistent, get_step(hunter, EAST))
	var/datum/action/cooldown/alien/banda/hunter_silence/silence = locate() in hunter.actions
	var/datum/action/cooldown/alien/banda/hunter_pounce/pounce = locate() in hunter.actions
	TEST_ASSERT_EQUAL(pounce.plasma_cost, 75, "Hunter pounce does not cost 75 plasma")
	TEST_ASSERT_EQUAL(silence.cooldown_time, 100 SECONDS, "Hunter Silence has wrong cooldown")
	hunter.marked_prey = WEAKREF(marked)
	TEST_ASSERT(silence.Trigger(hunter), "Hunter could not cast Silence")
	var/obj/item/organ/ears/ordinary_ears = prey.get_organ_slot(ORGAN_SLOT_EARS)
	var/obj/item/organ/ears/marked_ears = marked.get_organ_slot(ORGAN_SLOT_EARS)
	var/datum/status_effect/silenced/ordinary_silence = prey.has_status_effect(/datum/status_effect/silenced)
	var/datum/status_effect/silenced/marked_silence = marked.has_status_effect(/datum/status_effect/silenced)
	TEST_ASSERT_EQUAL(ordinary_silence.duration, 5 SECONDS, "Unmarked prey received wrong speech suppression")
	TEST_ASSERT_EQUAL(marked_silence.duration, 10 SECONDS, "Marked prey received wrong speech suppression")
	TEST_ASSERT_EQUAL(ordinary_ears.temporary_deafness, 5 SECONDS, "Unmarked prey received wrong deafness")
	TEST_ASSERT_EQUAL(marked_ears.temporary_deafness, 10 SECONDS, "Marked prey received wrong deafness")
	TEST_ASSERT(!silence.Trigger(hunter), "Repeated Silence bypassed its cooldown")

/datum/unit_test/xeno_rework_hive/generator_acid_destruction/Run()
	var/obj/structure/xeno_biomass_generator/generator = allocate(/obj/structure/xeno_biomass_generator)
	var/turf/impact = get_turf(generator)
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent, get_step(generator, NORTH))
	var/mob/living/carbon/alien/adult/banda/drone/ally = allocate(/mob/living/carbon/alien/adult/banda/drone, get_step(generator, WEST))
	var/before = prey.get_fire_loss()
	generator.take_damage(1000, BRUTE, MELEE)
	TEST_ASSERT(QDELETED(generator), "Destroyed generator remains active")
	TEST_ASSERT(prey.get_fire_loss() > before, "Generator destruction has no acid burst damage")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/xeno_acid_pool) in impact, "Generator destruction left no acid")
	TEST_ASSERT_EQUAL(ally.get_fire_loss(), 0, "Xenomorph was burned by its own acid")
	var/turf/quiet = run_loc_floor_top_right
	var/obj/structure/xeno_biomass_generator/deleted = allocate(/obj/structure/xeno_biomass_generator, quiet)
	qdel(deleted)
	TEST_ASSERT_NULL(locate(/obj/effect/xeno_acid_pool) in quiet, "Administrative deletion caused a gameplay explosion")

/datum/unit_test/xeno_rework_hive/upgrade_hud_visuals/Run()
	hive.purchased["carapace"] = 1
	var/mob/living/carbon/alien/adult/banda/runner/runner = allocate(/mob/living/carbon/alien/adult/banda/runner)
	TEST_ASSERT_NULL(runner.get_filter("hive_adaptation"), "Caste upgrade still gives a permanent aura")
	var/image/health_image = runner.hud_list[HEALTH_HUD]
	TEST_ASSERT_EQUAL(health_image.pixel_z, runner.get_hud_y_offset(), "Medical HUD did not use the visible sprite height")
	TEST_ASSERT(runner.get_hud_y_offset() < 0, "Short Runner retains a canvas-height medical HUD")
	runner.update_transform(1.2)
	TEST_ASSERT_EQUAL(health_image.pixel_z, runner.get_hud_y_offset(), "Resizing left medical HUD at the previous position")
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = allocate(/mob/living/carbon/alien/adult/banda/final_caste/hunter)
	TEST_ASSERT_EQUAL(hunter.get_cached_width(), 32, "Hunter atlas is wider than one tile")
	TEST_ASSERT_EQUAL(hunter.get_cached_height(), 32, "Hunter atlas is taller than one tile")
	TEST_ASSERT_EQUAL(hunter.pixel_x, 0, "Hunter retained the large-atlas horizontal offset")
	TEST_ASSERT_EQUAL(hunter.pixel_y, 0, "Hunter retained the large-atlas vertical offset")
