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
	TEST_ASSERT_EQUAL(hive.biomass, 5, "Territory income bypassed the queen death penalty")
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
