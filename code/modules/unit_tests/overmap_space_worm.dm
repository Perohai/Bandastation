/** The same drive switch used by the helm allows the worm to find a hull before sonar can see it. */
/datum/unit_test/overmap_space_worm
	parent_type = /datum/unit_test/overmap_docking

/datum/unit_test/overmap_space_worm/Run()
	navigation.sites.Cut()
	navigation.selected_destination = null
	navigation.prepared_site = null
	var/datum/stationtrauma_overmap_sector/space/sector = allocate(__IMPLIED_TYPE__)
	sector.ready = TRUE
	TEST_ASSERT(sector.register(ship.shuttle_id, navigation), "The hull must be in its own sector for the hunt.")
	var/datum/stationtrauma_space_worm/worm = allocate(__IMPLIED_TYPE__, sector, navigation.pos_x + navigation.sensor_range + 1, navigation.pos_y)
	var/initial_x = worm.pos_x
	worm.process(1)
	TEST_ASSERT_EQUAL(worm.pos_x, initial_x, "The worm must ignore the nearby ship with its engines shut down.")
	TEST_ASSERT(navigation.scan_sector(), "The active scanner must be available in free flight.")
	TEST_ASSERT_EQUAL(length(navigation.ship_echo_data()), 0, "The worm outside sonar range must stay off the crew's chart.")

	TEST_ASSERT(navigation.set_engines_running(TRUE), "The working engine must start from the helm.")
	navigation.pos_x -= navigation.sensor_range
	worm.process(1)
	TEST_ASSERT_EQUAL(worm.pos_x, initial_x, "A distant engine must stay beyond the worm's reach.")
	navigation.pos_x += navigation.sensor_range
	worm.process(1)
	TEST_ASSERT(worm.pos_x < initial_x, "A running engine just beyond sonar range must draw the worm toward the ship.")
	TEST_ASSERT(navigation.set_engines_running(FALSE), "The helm must accept the order to cut the engine.")
	var/stopped_x = worm.pos_x
	worm.process(1)
	TEST_ASSERT_EQUAL(worm.pos_x, stopped_x, "Cutting the engine must stop the pursuit.")

	navigation.pos_x = stopped_x - navigation.sensor_range + 1
	navigation.next_scan = world.time
	TEST_ASSERT(navigation.scan_sector(), "A fresh sonar pulse must cover the new position.")
	var/list/echoes = navigation.ship_echo_data()
	TEST_ASSERT_EQUAL(length(echoes), 1, "Crossing the sonar boundary must yield one fauna contact.")
	var/list/echo = echoes[1]
	var/list/fauna = echo["fauna"]
	TEST_ASSERT(islist(fauna) && fauna["kind"] == "worm" && fauna["name"] == "Космический глист", "The sonar contact must identify the worm species and its display name.")
	TEST_ASSERT(echo["mode"] == "active" && echo["x"] == stopped_x, "The active contact must report the worm at its measured position.")

	// Align chart east with deck east so the shot enters through this wall at the centre of the hull's east face.
	navigation.course = dir2angle(ship.preferred_direction)
	navigation.pos_x = stopped_x - 75
	var/turf/hull_edge = locate(ship.x + 1, ship.y + 1, ship.z)
	hull_edge = hull_edge.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(navigation.set_engines_running(TRUE), "Restarting the engine in spitting range must attract the worm again.")
	worm.process(1)
	TEST_ASSERT_EQUAL(length(sector.kinetic_shots), 1, "The worm must launch a shot onto the sector map.")
	TEST_ASSERT(navigation.set_engines_running(FALSE), "The target must be able to cut its engine after the shot.")
	var/deadline = world.time + 12 SECONDS
	UNTIL(hull_edge.GetComponent(/datum/component/acid) || world.time >= deadline)
	TEST_ASSERT(hull_edge.GetComponent(/datum/component/acid), "The launched glob must reach and corrode actual hull plating after engine shutdown.")

	worm.take_damage(worm.health)
	navigation.next_scan = world.time
	TEST_ASSERT(navigation.scan_sector(), "The scanner must sample the worm again after the lethal hit.")
	echoes = navigation.ship_echo_data()
	TEST_ASSERT(length(echoes) == 1 && echoes[1]["id"] == echo["id"] && echoes[1]["fauna"]["dead"], "The same sonar contact must now identify the worm as dead.")

/** A targeted admin spawn must give the selected hull a new sonar contact, even inside a nebula. */
/datum/unit_test/overmap_space_worm_targeted_spawn
	parent_type = /datum/unit_test/overmap_docking

/datum/unit_test/overmap_space_worm_targeted_spawn/Run()
	var/datum/stationtrauma_overmap_sector/space/sector = allocate(__IMPLIED_TYPE__)
	sector.ready = TRUE
	navigation.sites -= site.id
	sector.sites[site.id] = site
	TEST_ASSERT(sector.register(ship.shuttle_id, navigation), "The selected hull must start in the spawn sector.")
	navigation.pos_x = 2400
	navigation.pos_y = -1400
	var/clear_range = navigation.sensor_range
	sector.zones += new /datum/stationtrauma_overmap_zone("Test nebula", "nebula", navigation.pos_x, navigation.pos_y, 200)
	navigation.process_encounters()
	TEST_ASSERT(navigation.sensor_range < clear_range, "The nebula must reduce the selected ship's actual sensor range.")

	var/datum/stationtrauma_space_worm/worm = sector.spawn_space_worm(navigation)
	TEST_ASSERT(worm && (worm in sector.space_worms), "Targeted spawning must place a worm in the selected ship's sector.")
	var/separation = sqrt((worm.pos_x - navigation.pos_x) ** 2 + (worm.pos_y - navigation.pos_y) ** 2)
	TEST_ASSERT(separation > navigation.radius + worm.radius && separation <= navigation.sensor_range, "The new animal must be clear of the hull and inside its current sonar range.")
	TEST_ASSERT(navigation.scan_sector(), "The ship's active sonar must be ready to report the nearby spawn.")
	var/list/echoes = navigation.ship_echo_data()
	TEST_ASSERT_EQUAL(length(echoes), 1, "The sonar should report the single spawned animal.")
	var/list/echo = echoes[1]
	var/list/fauna = echo["fauna"]
	TEST_ASSERT(fauna?["kind"] == "worm" && echo["mode"] == "active" && echo["x"] == worm.pos_x && echo["y"] == worm.pos_y, "The sonar fix must identify the spawned worm at its actual coordinates.")

	var/datum/stationtrauma_overmap_sector/space/other_sector = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(sector.unregister(navigation) && other_sector.register(ship.shuttle_id, navigation), "Move the selected ship to another sector before using its stale selection.")
	TEST_ASSERT_NULL(sector.spawn_space_worm(navigation), "A ship which left the chosen sector must invalidate a targeted spawn.")
	TEST_ASSERT_EQUAL(length(sector.space_worms), 1, "A stale selection must not spawn an extra animal at random.")
	var/datum/stationtrauma_space_worm/random_worm = sector.spawn_space_worm()
	TEST_ASSERT(random_worm && random_worm != worm && (random_worm in sector.space_worms), "An explicit untargeted spawn must still work in a sector without ships.")

/** A stranded container produces one sonar fix and one physical rescue destination per person inside. */
/datum/unit_test/overmap_biosignature_rescue
	parent_type = /datum/unit_test/overmap_docking/evacuation_then_virtual_dock
	var/datum/stationtrauma_overmap_sector/space/rescue_sector
	var/datum/stationtrauma_lost_space/loss
	var/list/prior_losses

/datum/unit_test/overmap_biosignature_rescue/Destroy()
	if(rescue_sector)
		SSstationtrauma_space_voyage.sectors -= rescue_sector.id
	if(prior_losses)
		// A real open-space level cannot be deleted. Leave the empty level available for reuse.
		prior_losses += GLOB.stationtrauma_lost_spaces
		GLOB.stationtrauma_lost_spaces = prior_losses
		prior_losses = null
	return ..()

/datum/unit_test/overmap_biosignature_rescue/Run()
	rescue_sector = allocate(/datum/stationtrauma_overmap_sector/space)
	rescue_sector.ready = TRUE
	rescue_sector.id = "unit_test_biosignature_rescue"
	SSstationtrauma_space_voyage.sectors[rescue_sector.id] = rescue_sector
	navigation.sites -= site.id
	navigation.selected_destination = null
	navigation.prepared_site = null
	TEST_ASSERT(rescue_sector.register(ship.shuttle_id, navigation), "The rescue ship must have a working sector.")
	prior_losses = GLOB.stationtrauma_lost_spaces
	GLOB.stationtrauma_lost_spaces = list()
	var/obj/structure/closet/crate/box = allocate(/obj/structure/closet/crate, space.bottom_left_turfs[1])
	var/mob/living/carbon/human/consistent/survivor = allocate(/mob/living/carbon/human/consistent, box)
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent, box)
	var/mob/living/carbon/human/consistent/rescuer = allocate(/mob/living/carbon/human/consistent, get_turf(ship))
	ADD_TRAIT(survivor, TRAIT_GODMODE, TRAIT_SOURCE_UNIT_TESTS)
	navigation.pos_x = 315
	navigation.pos_y = -280
	TEST_ASSERT(navigation.strand(box, EAST), "A container lost overboard must land on a physical open-space level.")
	box.throwing?.finalize()
	qdel(box.drift_handler)
	loss = navigation.lost_space()
	TEST_ASSERT(loss.has_casualty(survivor) && loss.has_casualty(body) && !loss.has_casualty(rescuer), "Only the two people who went overboard should register.")
	var/turf/landing = locate(round(world.maxx / 2), round(world.maxy / 2), loss.level.z_value)
	box.forceMove(landing)
	survivor.forceMove(locate(landing.x + 12, landing.y + 8, landing.z))
	TEST_ASSERT_NULL(loss.signal, "A real castaway should not create an SOS transmitter.")
	var/datum/stationtrauma_overmap_sector/space/other_sector = allocate(__IMPLIED_TYPE__)
	other_sector.id = "unit_test_biosignature_neighbor"
	TEST_ASSERT(rescue_sector.unregister(navigation) && other_sector.register(ship.shuttle_id, navigation), "The search ship must enter the neighbouring sector.")
	TEST_ASSERT(navigation.scan_sector() && !length(navigation.ship_echo_data()), "Another sector must not receive either human contact at the same chart coordinates.")
	TEST_ASSERT(other_sector.unregister(navigation) && rescue_sector.register(ship.shuttle_id, navigation), "The search ship must return to the lost crew's sector.")
	navigation.next_scan = world.time
	TEST_ASSERT(navigation.scan_sector(), "The navigation sonar must scan the site of the loss.")
	var/list/echoes = navigation.ship_echo_data()
	TEST_ASSERT_EQUAL(length(echoes), 2, "Two silent castaways at one chart position must have distinct sonar echoes.")
	var/list/body_fix = navigation.ship_sensor_observation(WEAKREF(body))
	var/list/survivor_fix = navigation.ship_sensor_observation(WEAKREF(survivor))
	TEST_ASSERT(body_fix && survivor_fix && body_fix["id"] != survivor_fix["id"], "Each body needs its own stable crew contact number.")
	var/number = body_fix["id"]
	body.death()
	TEST_ASSERT(!body_fix["fauna"]["dead"], "A stored live sample must not change between sonar observations.")
	navigation.next_scan = world.time
	TEST_ASSERT(navigation.scan_sector(), "The next pulse must sample the person's new state.")
	echoes = navigation.ship_echo_data()
	var/list/body_echo
	for(var/list/echo as anything in echoes)
		if(echo["id"] == number)
			body_echo = echo
	TEST_ASSERT(body_echo && body_echo["fauna"]["kind"] == "human" && body_echo["fauna"]["dead"], "The same crew contact must now report a human body.")
	TEST_ASSERT(body_echo["x"] == loss.pos_x && body_echo["y"] == loss.pos_y, "A body in a container must retain the charted location of its loss.")
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The rescue helm must have real engine thrust.")
	navigation.throttle = 50
	body_fix = navigation.ship_sensor_observation(WEAKREF(body))
	body_fix["seen"] = world.time - 5 MINUTES
	TEST_ASSERT(!navigation.approach_biosignature(number), "An expired fix must not launch a rescue approach.")
	navigation.next_scan = world.time
	TEST_ASSERT(navigation.scan_sector(), "A recent fix must be available for the rescue.")
	body_fix = navigation.ship_sensor_observation(WEAKREF(body))
	number = body_fix["id"]
	navigation.record_contact_observation("ship_only", loss.pos_x, loss.pos_y, "active")
	TEST_ASSERT(!navigation.approach_biosignature(navigation.ship_observations["ship_only"]["id"]), "A ship's sensor fix must not launch a biological approach.")
	navigation.pos_x -= 80
	TEST_ASSERT(navigation.approach_biosignature(number), "The helm must accept a fresh human contact with its engines running.")
	var/datum/stationtrauma_overmap_site/space/distress/casualty/target = loss.rescue_site(body)
	TEST_ASSERT(navigation.autopilot && navigation.selected_docking_site() == target, "The helm must select this body's real destination and engage autopilot.")
	var/datum/stationtrauma_overmap_site/space/distress/casualty/other_target = loss.rescue_site(survivor)
	TEST_ASSERT(target && other_target && target != other_target, "People separated on the same level must have independent approaches.")
	other_target.load_map()
	TEST_ASSERT_EQUAL(other_target.entrance, get_turf(survivor), "A different person's rescue berth must open beside that person.")
	var/obj/item/stationtrauma_distress_beacon/beacon = allocate(/obj/item/stationtrauma_distress_beacon, get_turf(survivor))
	beacon.attack_self(survivor)
	TEST_ASSERT(loss.signal && loss.signal != target, "An independent distress beacon must have its own SOS route.")
	beacon.attack_self(survivor)
	TEST_ASSERT(!loss.signal && rescue_sector.sites[target.id] == target, "Switching off a beacon must preserve the active biological route.")
	qdel(survivor)
	TEST_ASSERT(length(loss.casualties) == 1 && !(other_target.id in rescue_sector.sites), "Deleting one survivor must withdraw just their berth.")
	loss.last_loss = world.time - 5 MINUTES
	TEST_ASSERT(loss.busy(), "A lone dead body in a container must hold the loss level for recovery even without a transmitting beacon.")
	var/ship_edge = navigation.connection.get_ship_edge(ship.return_coords(), 1, WEST)
	TEST_ASSERT_NOTNULL(ship_edge, "The rescue fixture must have a valid ship-side passage.")
	for(var/turf/tile as anything in block(locate(ship_edge, 1, ship.z), locate(ship_edge + 1, world.maxy, ship.z)))
		borrow_space(tile)
	for(var/tick in 1 to 240)
		navigation.last_update = world.time - 0.5 SECONDS
		navigation.advance()
		if(!navigation.helm_engaged)
			break
	TEST_ASSERT(!navigation.helm_engaged && navigation.in_arrival_range(target), "Autopilot must actually reach and stop beside the lost body.")
	TEST_ASSERT(navigation.dock(instant = TRUE), "Docking at the human contact must open the native map passage.")
	TEST_ASSERT(navigation.connection.active && target.entrance == landing && target.berth.z == landing.z, "The rescue passage must lead to the level and tile that contain the body.")
	TEST_ASSERT(box.Move(get_step(landing, EAST)), "The container holding the body must be able to enter the rescue passage.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(box.z == ship.z || world.time >= deadline)
	TEST_ASSERT(box.z == ship.z && !(body in loss.casualties), "A body carried aboard inside a container must leave the loss registry immediately.")
	TEST_ASSERT(!navigation.approach_biosignature(number), "An earlier measurement must not target the rescued passenger.")
	TEST_ASSERT(loss.busy() && navigation.docked == target && navigation.connection.active, "Recovery must keep the occupied rescue passage available for the crew.")
	TEST_ASSERT(!length(loss.casualties) && loss.busy(), "An occupied passage must hold its now empty level against reuse.")
	TEST_ASSERT(navigation.depart(instant = TRUE), "The crew must be able to cast off after bringing the body aboard.")
	TEST_ASSERT(!loss.busy(), "After the last person and ship have departed, the empty level must be reusable.")
