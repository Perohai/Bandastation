/datum/unit_test/xeno_rework_hive/proc/create_hivemind()
	allocate(/obj/structure/alien/weeds/node)
	allocate(/obj/structure/xeno_hivemind_anchor)
	return allocate(/mob/living/carbon/alien/hivemind)

/datum/unit_test/xeno_rework_hive/hivemind_purchase/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	queen.setDir(NORTH)
	var/turf/origin = hive.hivemind_location(queen)
	allocate(/obj/structure/alien/weeds/node, origin)
	hive.purchase_time = 0
	hive.biomass = 1000
	TEST_ASSERT(!hive.can_buy(queen, "hivemind"), "Hivemind bypasses coordination prerequisite")
	hive.purchased["coordination"] = 1
	TEST_ASSERT(hive.buy(queen, "hivemind"), "Paid Hivemind anchor was not created")
	TEST_ASSERT_EQUAL(hive.biomass, 700, "Hivemind does not cost exactly 300")
	TEST_ASSERT_EQUAL(hive.hivemind_anchor.loc, origin, "Anchor was not placed ahead of queen")
	TEST_ASSERT_NOTNULL(hive.hivemind_anchor.spawner, "Anchor has no native ghost role")
	TEST_ASSERT_EQUAL(hive.hivemind_anchor.spawner.role_ban, ROLE_ALIEN, "Hivemind has wrong ban category")
	TEST_ASSERT(!hive.can_buy(queen, "hivemind") && !hive.buy(queen, "hivemind"), "An unclaimed role did not reserve the unique slot")
	qdel(hive.hivemind_anchor)
	TEST_ASSERT(hive.buy(queen, "hivemind"), "Destroyed anchor permanently blocks a paid resummon")
	TEST_ASSERT_EQUAL(hive.biomass, 400, "Second anchor was refunded or free")

/datum/unit_test/xeno_rework_hive/hivemind_revalidation/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	queen.setDir(NORTH)
	var/turf/origin = hive.hivemind_location(queen)
	allocate(/obj/structure/alien/weeds/node, origin)
	hive.purchased["coordination"] = 1
	hive.biomass = 1000
	hive.purchase_time = 0.3 SECONDS
	INVOKE_ASYNC(hive, TYPE_PROC_REF(/datum/xeno_hive, buy), queen, "hivemind")
	sleep(0.1 SECONDS)
	TEST_ASSERT(hive.purchase_busy, "Hivemind purchase skipped its channel")
	allocate(/obj/structure/alien/resin/wall, origin)
	sleep(0.4 SECONDS)
	TEST_ASSERT_NULL(hive.hivemind_anchor, "Occupied destination passed post-channel placement")
	TEST_ASSERT_EQUAL(hive.biomass, 1000, "Failed placement spent biomass")

/datum/unit_test/xeno_rework_hive/hivemind_lifecycle/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/obj/structure/xeno_hivemind_anchor/anchor = hive.hivemind_anchor
	var/obj/effect/mob_spawn/ghost_role/xeno_hivemind/spawner = anchor.spawner
	TEST_ASSERT_EQUAL(anchor.hivemind_ref.resolve(), hivemind, "Anchor does not track occupancy")
	TEST_ASSERT(HAS_TRAIT(hivemind, TRAIT_GODMODE) && !hivemind.manifested, "Hivemind did not start as a spirit")
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/alien/banda/generic_evolve) in hivemind.actions, "T0 support has adult evolution")
	TEST_ASSERT(!(hivemind in hive.members), "T0 support entered the adult hive registry")
	TEST_ASSERT(!istype(hivemind, /mob/living/carbon/alien/adult/banda), "Hivemind counts as an adult in finale")
	hive.biomass = 500
	qdel(anchor)
	TEST_ASSERT(QDELETED(hivemind) && QDELETED(spawner), "Destroyed anchor left body or role alive")
	TEST_ASSERT_NULL(hive.hivemind_anchor, "Destroyed anchor retained unique slot")
	TEST_ASSERT_EQUAL(hive.biomass, 500, "Hivemind death applied queen's biomass penalty")

/datum/unit_test/xeno_rework_hive/hivemind_body_cleanup/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/obj/structure/xeno_hivemind_anchor/anchor = hive.hivemind_anchor
	qdel(hivemind)
	TEST_ASSERT(QDELETED(anchor), "Deleted Hivemind left an unusable paid anchor")
	TEST_ASSERT_NULL(hive.hivemind_anchor, "Deleted body retained the unique slot")

/datum/unit_test/xeno_rework_hive/hivemind_movement/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/turf/destination = get_step(hivemind, NORTH)
	TEST_ASSERT(!hivemind.Move(destination, NORTH), "Spirit walked off weeds")
	allocate(/obj/structure/alien/weeds, destination)
	var/obj/structure/alien/resin/wall/wall = allocate(/obj/structure/alien/resin/wall, destination)
	TEST_ASSERT(hivemind.Move(destination, NORTH), "Spirit cannot pass resin on weeds")
	TEST_ASSERT_EQUAL(hivemind.loc, destination, "Spirit movement did not change turf")
	qdel(wall)
	TEST_ASSERT(hivemind.return_to_core(), "Spirit could not return to its anchor")
	TEST_ASSERT_EQUAL(hivemind.loc, hive.hivemind_anchor.loc, "Return used brood core instead of own anchor")
	hivemind.channeling = TRUE
	TEST_ASSERT(!hivemind.Move(destination, NORTH), "Movement bypassed a support channel")
	hivemind.channeling = FALSE

/datum/unit_test/xeno_rework_hive/hivemind_form/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/datum/action/cooldown/alien/hivemind/form/form = locate() in hivemind.actions
	TEST_ASSERT_EQUAL(hivemind.reformation_time, 210 SECONDS, "Physical defeat does not impose a 3.5-minute reformation delay")
	form.form_time = 0.3 SECONDS
	INVOKE_ASYNC(form, TYPE_PROC_REF(/datum/action/cooldown/alien/hivemind/form, PreActivate))
	sleep(0.1 SECONDS)
	TEST_ASSERT(hivemind.channeling && !hivemind.manifested, "Manifestation was immediate")
	TEST_ASSERT(!form.Activate(), "A parallel form change was accepted")
	sleep(0.4 SECONDS)
	TEST_ASSERT(hivemind.manifested && !HAS_TRAIT(hivemind, TRAIT_GODMODE), "Finished manifestation remains invulnerable")
	hivemind.apply_damage(100, BRUTE)
	TEST_ASSERT(!QDELETED(hivemind) && !hivemind.manifested, "Physical defeat killed Hivemind instead of dispersing")
	TEST_ASSERT_EQUAL(hivemind.health, hivemind.maxHealth, "Dispersed body remains critically damaged")
	TEST_ASSERT(!form.Activate(), "Physical defeat has no reformation cooldown")
	COOLDOWN_RESET(hivemind, reformation_cooldown)
	form.form_time = 0
	TEST_ASSERT(form.PreActivate(), "Hivemind could not reform after cooldown")
	hivemind.gib()
	TEST_ASSERT(!QDELETED(hivemind) && !hivemind.manifested, "Gib bypassed support-shell defeat")

/datum/unit_test/xeno_rework_hive/hivemind_support/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/mob/living/carbon/alien/adult/banda/drone/ally = allocate(/mob/living/carbon/alien/adult/banda/drone, get_step(hivemind, NORTH))
	var/datum/action/cooldown/alien/hivemind/heal/heal = locate() in hivemind.actions
	var/datum/action/cooldown/alien/hivemind/plasma/share = locate() in hivemind.actions
	TEST_ASSERT(!heal.IsAvailable() && !share.IsAvailable(), "Spirit can affect physical allies")
	hivemind.set_manifestation(TRUE)
	ally.adjust_brute_loss(40)
	ally.adjust_fire_loss(30)
	heal.channel_time = 0
	var/before = hivemind.getPlasma()
	TEST_ASSERT(heal.PreActivate(ally), "Physical Hivemind cannot heal an ally")
	TEST_ASSERT_EQUAL(ally.get_brute_loss(), 0, "Healing did not prioritize brute")
	TEST_ASSERT_EQUAL(ally.get_fire_loss(), 20, "Healing exceeded the total 50-damage budget")
	TEST_ASSERT_EQUAL(hivemind.getPlasma(), before - 150, "Healing paid the wrong plasma cost")
	ally.adjustPlasma(-ally.getPlasma())
	share.channel_time = 0
	before = hivemind.getPlasma()
	TEST_ASSERT(share.PreActivate(ally), "Plasma transfer failed")
	TEST_ASSERT_EQUAL(ally.getPlasma(), 200, "Transfer did not deliver 200 plasma")
	TEST_ASSERT_EQUAL(hivemind.getPlasma(), before - 200, "Transfer created plasma")

/datum/unit_test/xeno_rework_hive/hivemind_support_cancel/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	hivemind.set_manifestation(TRUE)
	var/mob/living/carbon/alien/adult/banda/drone/ally = allocate(/mob/living/carbon/alien/adult/banda/drone, get_step(hivemind, NORTH))
	var/datum/action/cooldown/alien/hivemind/heal/heal = locate() in hivemind.actions
	var/datum/action/cooldown/alien/hivemind/plasma/share = locate() in hivemind.actions
	heal.channel_time = 0.3 SECONDS
	ally.adjust_brute_loss(30)
	var/before = hivemind.getPlasma()
	INVOKE_ASYNC(heal, TYPE_PROC_REF(/datum/action/cooldown/alien/hivemind/heal, PreActivate), ally)
	sleep(0.1 SECONDS)
	TEST_ASSERT(!share.Activate(ally), "Different support button bypassed the shared channel lock")
	ally.forceMove(get_ranged_target_turf(hivemind, NORTH, 5))
	sleep(0.4 SECONDS)
	TEST_ASSERT_EQUAL(ally.get_brute_loss(), 30, "Out-of-range ally was healed")
	TEST_ASSERT_EQUAL(hivemind.getPlasma(), before, "Cancelled healing spent plasma")
	TEST_ASSERT(!hivemind.channeling, "Cancelled support retained its channel lock")

/datum/unit_test/xeno_rework_hive/hivemind_building/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/datum/action/cooldown/alien/build_resin_structure/hivemind/build = locate() in hivemind.actions
	TEST_ASSERT(!build.IsAvailable(), "Spirit can build resin")
	hivemind.set_manifestation(TRUE)
	hivemind.selected_resin_structure = /obj/structure/alien/resin/wall
	var/turf/location = get_ranged_target_turf(hivemind, NORTH, 4)
	allocate(/obj/structure/alien/weeds, location)
	build.build_time = 0
	TEST_ASSERT(build.PreActivate(location), "Hivemind cannot build on visible weeds four tiles away")
	TEST_ASSERT_NOTNULL(locate(/obj/structure/alien/resin/wall) in location, "Ranged construction created no wall")
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/alien/hivemind/pheromones) in hivemind.actions, "Hivemind has innate restorative pheromones")
	hive.purchased["pheromones"] = 1
	hivemind.apply_hive_upgrades()
	var/datum/action/cooldown/alien/hivemind/pheromones/pheromones = locate() in hivemind.actions
	TEST_ASSERT(pheromones.IsAvailable(), "Purchased pheromones did not reach existing Hivemind")
	hivemind.set_manifestation(FALSE)
	TEST_ASSERT(!pheromones.IsAvailable(), "Spirit released physical pheromones")

/datum/unit_test/xeno_rework_hive/core_footprint/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	queen.forceMove(get_ranged_target_turf(queen, NORTHEAST, 1))
	queen.setDir(NORTH)
	var/turf/origin = hive.hive_structure_location(queen)
	allocate(/obj/structure/alien/weeds/node, origin)
	TEST_ASSERT(hive.can_place_core(queen), "Free 2x2 core footprint was rejected")
	var/turf/far_corner = locate(origin.x + 1, origin.y + 1, origin.z)
	var/obj/structure/alien/resin/wall/wall = allocate(/obj/structure/alien/resin/wall, far_corner)
	TEST_ASSERT(!hive.can_place_core(queen), "Blocked fourth core tile was ignored")
	qdel(wall)
	var/obj/structure/xeno_hive_core/core = allocate(/obj/structure/xeno_hive_core, origin)
	STOP_PROCESSING(SSobj, core)
	TEST_ASSERT_EQUAL(core.bound_width, 64, "Brood core is not two tiles wide")
	TEST_ASSERT_EQUAL(core.bound_height, 64, "Brood core is not two tiles tall")
	TEST_ASSERT_EQUAL(length(core.locs), 4, "Native bounds do not cover all four core tiles")
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent, locate(origin.x + 2, origin.y + 1, origin.z))
	TEST_ASSERT(core.IsReachableBy(attacker), "Crew cannot hit the far side of the core")
	TEST_ASSERT(!hive.clear_structure_footprint(far_corner, 1, 1, FALSE), "Another anchor overlaps a non-anchor core tile")
	TEST_ASSERT(!core.next_to_core(far_corner), "Inner core tile was counted as an egg location")
	TEST_ASSERT(core.add_brood(20) == 20, "2x2 core capped its unlimited eggs")
	var/list/locations = list()
	for(var/obj/structure/xeno_hive_egg/egg as anything in core.brood_eggs)
		TEST_ASSERT(core.next_to_core(egg), "Egg appeared inside core footprint")
		locations |= egg.loc
	TEST_ASSERT_EQUAL(length(locations), 12, "Eggs did not fill the full 2x2 perimeter before stacking")

/datum/unit_test/xeno_rework_hive/hivemind_resources/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	TEST_ASSERT(!HAS_TRAIT(hivemind, TRAIT_VENTCRAWLER_ALWAYS), "Vents bypass the weed movement restriction")
	var/obj/item/organ/alien/plasmavessel/hivemind/vessel = hivemind.get_organ_slot(ORGAN_SLOT_XENO_PLASMAVESSEL)
	vessel.stored_plasma = 0
	vessel.on_life(0.5)
	TEST_ASSERT_EQUAL(hivemind.getPlasma(), 30, "Hivemind plasma regeneration is not frame independent")
	vessel.on_life(1)
	TEST_ASSERT_EQUAL(hivemind.getPlasma(), 90, "Hivemind plasma regeneration uses the wrong rate")
	for(var/datum/action/cooldown/alien/action as anything in hivemind.actions)
		TEST_ASSERT(action.button_icon_state in icon_states(action.button_icon), "Hivemind action [action.type] has an invisible icon")

/datum/unit_test/xeno_rework_hive/hivemind_form_anchor_loss/Run()
	var/mob/living/carbon/alien/hivemind/hivemind = create_hivemind()
	var/datum/action/cooldown/alien/hivemind/form/form = locate() in hivemind.actions
	form.form_time = 0.3 SECONDS
	INVOKE_ASYNC(form, TYPE_PROC_REF(/datum/action/cooldown/alien/hivemind/form, PreActivate))
	sleep(0.1 SECONDS)
	qdel(hive.hivemind_anchor)
	sleep(0.4 SECONDS)
	TEST_ASSERT(QDELETED(hivemind) && QDELETED(form), "A pending manifestation survived anchor destruction")
	TEST_ASSERT_NULL(hive.hivemind_anchor, "An asynchronous form change restored a destroyed anchor")

/** Simulate another ghost taking the last place while can_ghost_take yields on a ban query. */
/obj/effect/mob_spawn/ghost_role/xeno_hivemind/reservation_test/can_ghost_take(mob/dead/observer/user)
	uses = 0
	return TRUE

/datum/unit_test/xeno_rework_hive/ghost_role_reservation/Run()
	var/obj/effect/mob_spawn/ghost_role/xeno_hivemind/reservation_test/spawner = allocate(/obj/effect/mob_spawn/ghost_role/xeno_hivemind/reservation_test)
	var/mob/dead/observer/ghost = allocate(/mob/dead/observer)
	var/previous_state = SSticker.current_state
	SSticker.current_state = GAME_STATE_PLAYING
	spawner.attack_ghost(ghost)
	SSticker.current_state = previous_state
	TEST_ASSERT_EQUAL(spawner.uses, 0, "A competing ghost reserved an already exhausted place")
