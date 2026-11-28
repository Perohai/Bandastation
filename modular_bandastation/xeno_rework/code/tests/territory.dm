/** Give only this test room station status, without changing any production level. */
/datum/unit_test/xeno_rework_hive/territory
	abstract_type = /datum/unit_test/xeno_rework_hive/territory
	normal_floor_required = TRUE
	/// Original mapping metadata restored after all test turfs/objects have been cleaned.
	var/datum/space_level/test_level
	/// Preserve the actual shared traits list, modify only a copy.
	var/list/saved_level_traits
	/// Preserve the cached station lookup for this z-level.
	var/saved_station_cache

/datum/unit_test/xeno_rework_hive/territory/New()
	. = ..()
	test_level = SSmapping.z_list[run_loc_floor_bottom_left.z]
	saved_level_traits = test_level.traits
	test_level.traits = saved_level_traits.Copy()
	test_level.traits[ZTRAIT_STATION] = TRUE
	if(length(GLOB.station_levels_cache) < test_level.z_value)
		GLOB.station_levels_cache.len = test_level.z_value
	saved_station_cache = GLOB.station_levels_cache[test_level.z_value]
	GLOB.station_levels_cache[test_level.z_value] = TRUE

/datum/unit_test/xeno_rework_hive/territory/Destroy()
	// Floor teardown must still see station status, including after a failed exclusion assertion.
	test_level.traits[ZTRAIT_STATION] = TRUE
	GLOB.station_levels_cache[test_level.z_value] = TRUE
	. = ..()
	test_level.traits = saved_level_traits
	GLOB.station_levels_cache[test_level.z_value] = saved_station_cache
	test_level = null
	saved_level_traits = null

/datum/unit_test/xeno_rework_hive/territory/accounting/Run()
	var/list/floors = list()
	for(var/turf/open/floor/location in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		floors += location
		if(length(floors) == 20)
			break
	TEST_ASSERT_EQUAL(length(floors), 20, "Territory test needs twenty distinct floors")
	for(var/index in 1 to 19)
		TEST_ASSERT(hive.claim_territory(floors[index]), "New station floor was rejected")
	TEST_ASSERT_EQUAL(hive.biomass, 0, "Incomplete tile batch paid biomass")
	TEST_ASSERT_EQUAL(hive.territory_pending_tiles, 19, "Tile remainder was not preserved")
	hive.claim_territory(floors[20])
	TEST_ASSERT_EQUAL(hive.biomass, 1, "Twenty floors did not pay exactly one biomass")
	TEST_ASSERT_EQUAL(hive.territory_pending_tiles, 0, "Completed batches retained a remainder")
	for(var/turf/location as anything in floors)
		TEST_ASSERT(!hive.claim_territory(location), "A coordinate was paid twice")
	var/turf/replaced = floors[5]
	var/turf/closed/wall/wall = replaced.ChangeTurf(/turf/closed/wall)
	var/turf/rebuilt = wall.ChangeTurf(/turf/open/floor/plating)
	TEST_ASSERT(!hive.claim_territory(rebuilt), "Rebuilding a floor reset its territory history")
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	hive.biomass = 10
	queen.death()
	TEST_ASSERT_EQUAL(hive.biomass, 8.5, "Territory income bypassed the queen death penalty")
	qdel(queen)
	allocate(/mob/living/carbon/alien/adult/banda/queen)
	TEST_ASSERT(!hive.claim_territory(rebuilt), "A replacement queen reset territory history")
	TEST_ASSERT_EQUAL(hive.territory_biomass_earned, 1, "Spending or death changed historical territory income")

/datum/unit_test/xeno_rework_hive/territory/exclusions/Run()
	var/turf/location = run_loc_floor_bottom_left
	GLOB.station_levels_cache[test_level.z_value] = FALSE
	TEST_ASSERT(!hive.claim_territory(location), "Off-station floors paid territory income")
	GLOB.station_levels_cache[test_level.z_value] = TRUE
	var/turf/space = location.ChangeTurf(/turf/open/space)
	TEST_ASSERT(!hive.claim_territory(space), "Space paid territory income")
	var/turf/floor = space.ChangeTurf(/turf/open/floor/plating)
	TEST_ASSERT(hive.claim_territory(floor), "Rejected terrain consumed the coordinate's first valid claim")
	var/turf/shuttle_floor = get_step(floor, NORTH)
	var/area/original_area = get_area(shuttle_floor)
	var/area/shuttle/shuttle_area = new
	shuttle_floor.change_area(original_area, shuttle_area)
	var/shuttle_paid = hive.claim_territory(shuttle_floor)
	shuttle_floor.change_area(shuttle_area, original_area)
	qdel(shuttle_area)
	TEST_ASSERT(!shuttle_paid, "A shuttle floor on station z paid expansion income")
	hive.territory_tiles_per_biomass = 0
	TEST_ASSERT(!hive.claim_territory(get_step(floor, NORTH)), "Zero batch size did not disable income safely")

/datum/unit_test/xeno_rework_hive/territory/native_growth/Run()
	var/obj/structure/alien/weeds/node/wild = allocate(/obj/structure/alien/weeds/node)
	STOP_PROCESSING(SSobj, wild)
	wild.record_hive_expansion()
	TEST_ASSERT_EQUAL(length(hive.claimed_territory), 0, "Wild weeds generated hive income")
	qdel(wild)
	var/mob/living/carbon/alien/adult/banda/drone/drone = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/datum/action/cooldown/alien/make_structure/plant_weeds/plant = locate() in drone.actions
	TEST_ASSERT(plant.PreActivate(drone), "Drone could not plant an owned hive node")
	var/obj/structure/alien/weeds/node/banda/node = locate() in drone.loc
	TEST_ASSERT_NOTNULL(node, "Planting retained the unowned native node type")
	STOP_PROCESSING(SSobj, node)
	TEST_ASSERT_EQUAL(length(hive.claimed_territory), 1, "New planted floor was not recorded")
	var/turf/origin = get_turf(node)
	origin.immediate_calculate_adjacent_turfs()
	node.try_expand()
	TEST_ASSERT(length(hive.claimed_territory) > 1, "Native natural growth did not record its newly covered floors")
	var/list/adjacent = origin.get_atmos_adjacent_turfs()
	var/turf/destination = adjacent[1]
	var/obj/structure/alien/weeds/child = locate() in destination
	TEST_ASSERT_NOTNULL(child, "Native node did not create a neighboring weed")
	TEST_ASSERT_EQUAL(child.parent_node, node, "Native growth lost source provenance")
	var/claimed_before = length(hive.claimed_territory)
	qdel(child)
	node.try_expand()
	TEST_ASSERT_EQUAL(length(hive.claimed_territory), claimed_before, "Regrowth after clearing weeds farmed territory")
	TEST_ASSERT_EQUAL(hive.biomass, 0, "A few naturally grown tiles completed a twenty-tile batch")
	var/list/data = hive.ui_data(drone)
	TEST_ASSERT_EQUAL(data["territoryTiles"], claimed_before, "Queen UI data lost territory progress")

/datum/unit_test/xeno_rework_hive/territory/infestation_count/Run()
	var/mob/living/carbon/human/crew = allocate(/mob/living/carbon/human/consistent)
	crew.mind_initialize()
	crew.mind.set_assigned_role(SSjob.get_job_type(/datum/job/assistant))
	var/obj/item/organ/body_egg/alien_embryo/embryo = allocate(/obj/item/organ/body_egg/alien_embryo)
	embryo.Insert(crew)
	var/datum/xeno_evacuation/event = GLOB.xeno_evacuation
	TEST_ASSERT_NOTNULL(event, "A qualifying station infection did not initialize the infestation counter")
	TEST_ASSERT_EQUAL(event.infections, 1, "The first station crew infection did not count")
	embryo.Remove(crew)
	embryo.Insert(crew)
	TEST_ASSERT_EQUAL(event.infections, 1, "Reinfection counted the same crew body twice")
	var/mob/living/carbon/human/other_crew = allocate(/mob/living/carbon/human/consistent)
	other_crew.mind_initialize()
	other_crew.mind.set_assigned_role(SSjob.get_job_type(/datum/job/assistant))
	GLOB.station_levels_cache[test_level.z_value] = FALSE
	var/obj/item/organ/body_egg/alien_embryo/other_embryo = allocate(/obj/item/organ/body_egg/alien_embryo)
	other_embryo.Insert(other_crew)
	TEST_ASSERT_EQUAL(event.infections, 1, "An off-station infection counted toward the station warning")

/datum/unit_test/xeno_rework_hive/territory/deployed_core/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	queen.setDir(NORTH)
	var/turf/location = get_step(queen, NORTH)
	allocate(/obj/structure/alien/weeds/node, location)
	hive.biomass = 200
	TEST_ASSERT(hive.place_core(queen), "The Queen could not deploy a core on her grass")
	TEST_ASSERT_EQUAL(hive.biomass, 100, "The installed core did not charge 100 biomass")
	TEST_ASSERT(hive.core_blockade_registered && xeno_shuttle_call_block_reason(), "The installed station core did not block evacuation")
	hive.core.update_integrity(150)
	hive.purchased["construction"] = 1
	TEST_ASSERT(hive.pack_core(queen), "The Queen could not fold her damaged core")
	var/obj/item/packed_xeno_hive_core/packed = hive.packed_core
	TEST_ASSERT_NOTNULL(packed, "Folding created no portable core")
	TEST_ASSERT_EQUAL(packed.get_integrity(), 150, "Folding reset core integrity")
	TEST_ASSERT(!hive.core_blockade_registered && !xeno_shuttle_call_block_reason(), "The folded core still blocked evacuation")
	TEST_ASSERT(hive.place_core(queen), "The Queen could not redeploy the folded core")
	TEST_ASSERT_EQUAL(hive.biomass, 0, "Redeployment did not charge 100 biomass")
	TEST_ASSERT_EQUAL(hive.core.get_integrity(), 150, "Redeployment repaired the core")
	qdel(hive.core)
	TEST_ASSERT(!hive.core_blockade_registered && !xeno_shuttle_call_block_reason(), "Destroying the deployed core retained the shuttle blockade")

/datum/unit_test/xeno_rework_hive/territory/carried_core/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	var/obj/item/packed_xeno_hive_core/packed = allocate(/obj/item/packed_xeno_hive_core)
	hive.packed_core = packed
	TEST_ASSERT(queen.put_in_hands(packed), "The Queen could not carry a packed core")
	hive.update_core_blockade()
	TEST_ASSERT(!hive.core_blockade_registered, "Carrying a folded core on station blocked evacuation")
	var/turf/return_location = get_turf(queen)
	var/other_z = return_location.z == 1 ? 2 : 1
	var/turf/space = locate(1, 1, other_z)
	TEST_ASSERT(isspaceturf(space), "The carry test needs a space tile on a different level")
	queen.forceMove(space)
	hive.update_core_blockade()
	TEST_ASSERT(!hive.core_blockade_registered && !xeno_shuttle_call_block_reason(), "Moving the folded core to space on another Z-level blocked evacuation")
	queen.forceMove(return_location)
	queen.death()
	hive.update_core_blockade()
	TEST_ASSERT(!hive.core_blockade_registered, "The death of a Queen carrying a folded core blocked evacuation")
	qdel(packed)
	TEST_ASSERT(!hive.packed_core && !hive.core_blockade_registered, "Destroying the folded core retained a reference or a blockade")
