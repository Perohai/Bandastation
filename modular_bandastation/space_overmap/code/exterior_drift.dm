/area/space/stationtrauma_space_home
	/// Navigation of the hull whose flight level this area covers.
	var/datum/weakref/navigation_ref

/area/space/stationtrauma_space_home/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	catch_drifter(arrived)

/** Like native hyperspace: whoever leaves a hull under way clings to it or is swept away astern. */
/area/space/stationtrauma_space_home/proc/catch_drifter(atom/movable/drifter)
	var/datum/stationtrauma_overmap/space/navigation = navigation_ref?.resolve()
	if(!navigation?.parallax_direction || QDELETED(drifter) || drifter.anchored || iseffect(drifter) || istype(drifter, /obj/projectile) || HAS_TRAIT(drifter, TRAIT_HYPERSPACED))
		return
	drifter.AddComponent(/datum/component/shuttle_cling/stationtrauma, REVERSE_DIR(navigation.parallax_direction), navigation)

/datum/stationtrauma_overmap/space/update_parallax()
	var/was_moving = parallax_direction
	. = ..()
	if(was_moving || !parallax_direction || !exterior || QDELETED(vessel))
		return
	// Whoever is already outside when the hull gets under way is left behind as well.
	var/list/bounds = vessel.return_coords()
	var/border = SHUTTLE_TRANSIT_BORDER
	var/turf/low = locate(max(1, min(bounds[1], bounds[3]) - border), max(1, min(bounds[2], bounds[4]) - border), vessel.z)
	var/turf/high = locate(min(world.maxx, max(bounds[1], bounds[3]) + border), min(world.maxy, max(bounds[2], bounds[4]) + border), vessel.z)
	for(var/turf/open/space/tile in block(low, high))
		if(tile.loc != exterior)
			continue
		for(var/atom/movable/drifter in tile)
			exterior.catch_drifter(drifter)

/**
 * Sweep a drifter left far behind onto the open-space level of this loss, tumbling across it away from the hull.
 *
 * Arguments:
 * * drifter - Movable past the transit border of the flight level
 * * direction - Astern, the way the drift carried it
 */
/datum/stationtrauma_overmap/space/proc/strand(atom/movable/drifter, direction)
	var/datum/stationtrauma_overmap_sector/space/departure_sector = sector
	var/datum/stationtrauma_lost_space/loss = lost_space()
	// Creating a level can wait on another one: the drifter may have been caught meanwhile.
	if(!loss?.level || QDELETED(src) || !departure_sector || sector != departure_sector || QDELETED(drifter) || !exterior || get_area(drifter) != exterior)
		return FALSE
	// Enter at the far side, so the throw crosses the whole level while a nearby wreck loads.
	var/margin = TRANSITIONEDGE + 8
	var/entry_x = direction == EAST ? margin : direction == WEST ? world.maxx - margin : rand(margin * 4, world.maxx - margin * 4)
	var/entry_y = direction == NORTH ? margin : direction == SOUTH ? world.maxy - margin : rand(margin * 4, world.maxy - margin * 4)
	var/turf/entry = locate(entry_x, entry_y, loss.level.z_value)
	drifter.forceMove(entry)
	loss.track_casualties(drifter)
	if(isliving(drifter))
		var/mob/living/lost = drifter
		shake_camera(lost, 3 SECONDS, 2)
		to_chat(lost, span_userdanger("Корабль уходит, а вас закручивает и уносит в открытый космос!"))
	drifter.safe_throw_at(get_edge_target_turf(entry, direction), world.maxx, 1, spin = TRUE, force = MOVE_FORCE_EXTREMELY_STRONG)
	loss.refresh_signal()
	return TRUE

/** The loss this hull is having now, or an idle open-space level claimed for a new one, or a new level. */
/datum/stationtrauma_overmap/space/proc/lost_space()
	return stationtrauma_open_space(sector, pos_x, pos_y, src)

/** Reuse the rescue pipeline for a crew lost at a captured chart position. */
/proc/stationtrauma_open_space(datum/stationtrauma_overmap_sector/space/here, x, y, datum/stationtrauma_overmap/space/navigation)
	if(QDELETED(here))
		return null
	var/datum/stationtrauma_lost_space/idle
	for(var/datum/stationtrauma_lost_space/loss as anything in GLOB.stationtrauma_lost_spaces)
		if((navigation ? loss.navigation_ref?.resolve() == navigation : !loss.navigation_ref) && loss.sector_id == here.id && world.time - loss.last_loss < ST_LOST_SHARED_TIME && (loss.pos_x - x) ** 2 + (loss.pos_y - y) ** 2 <= ST_LOST_WRECK_RANGE ** 2)
			loss.last_loss = world.time
			return loss
		if(!idle && !loss.busy())
			idle = loss
	if(!idle)
		idle = new
		// Recorded first: a parallel loss must not claim it while the level is still being created.
		idle.last_loss = world.time
		GLOB.stationtrauma_lost_spaces += idle
		idle.level = SSmapping.add_new_zlevel("Открытый космос", ZTRAITS_AWAY)
		if(QDELETED(here) || (navigation && QDELETED(navigation)))
			return null
	idle.claim(here, x, y, navigation)
	return idle

/// Open-space levels of losses overboard; a z-level cannot be removed, so idle ones are claimed again.
GLOBAL_LIST_EMPTY(stationtrauma_lost_spaces)

/**
 * One loss overboard: the open-space level the lost are swept onto, where on the chart it happened, and the wreck its edges lead to.
 *
 * One hull at one place within a short time shares a level; another hull or place takes another level.
 */
/datum/stationtrauma_lost_space
	/// Open-space level of this loss.
	var/datum/space_level/level
	/// Hull the crew was lost from.
	var/datum/weakref/navigation_ref
	/// Sector of the loss.
	var/sector_id
	/// Chart position of the loss.
	var/pos_x
	/// Chart ordinate of the loss.
	var/pos_y
	/// world.time of the latest loss here; a recent loss holds the level before anyone arrives.
	var/last_loss = 0
	/// Increments on every claim, so a wreck load started for an earlier loss cannot retarget the edges.
	var/revision = 0
	/// Charted object whose level the edges lead into once it is loaded; null keeps the edges looping.
	var/datum/stationtrauma_overmap_site/space/wreck
	/// Distress destination charted while a beacon transmits on this level.
	var/datum/stationtrauma_overmap_site/space/distress/signal

	/// Stranded humans on this level, each mapped to their own lazily charted rescue approach.
	var/list/casualties = list()
	/// Includes sites kept alive by a docking manoeuvre after the person is recovered.
	var/list/rescue_sites = list()
	/// Monotonic chart ID for each individual rescue approach across reuses of the level.
	var/next_rescue_id = 0
	/// A rescue seam takes over the level borders once. Later beacons or castaways keep those passages intact.
	var/edge_destination
	/// Invalidates older cooperative border updates when a new destination takes over.
	var/edge_revision = 0
	/// Whether the latest border update is still in progress.
	var/setting_edges = FALSE

/datum/stationtrauma_lost_space/Destroy()
	GLOB.stationtrauma_lost_spaces -= src
	for(var/mob/living/carbon/human/person as anything in casualties.Copy())
		remove_casualty(person)
	drop_signal()
	for(var/datum/stationtrauma_overmap_site/space/distress/casualty/site as anything in rescue_sites)
		site.loss = null
	rescue_sites.Cut()
	level = null
	wreck = null
	navigation_ref = null
	return ..()

/** Only those actually swept away or landed in a lost capsule are castaways. */
/datum/stationtrauma_lost_space/proc/track_casualties(atom/movable/drifter)
	for(var/mob/living/carbon/human/person as anything in drifter.get_all_contents_type(/mob/living/carbon/human))
		if((person in casualties) || !on_loss_level(person))
			continue
		casualties += person
		person.become_area_sensitive(REF(src))
		RegisterSignal(person, COMSIG_QDELETING, PROC_REF(remove_casualty))
		RegisterSignals(person, list(COMSIG_MOVABLE_Z_CHANGED, COMSIG_ENTER_AREA), PROC_REF(casualty_moved))

/datum/stationtrauma_lost_space/proc/on_loss_level(mob/living/carbon/human/person)
	var/turf/tile = get_turf(person)
	return level && tile?.z == level.z_value && !istype(tile.loc, /area/shuttle)

/datum/stationtrauma_lost_space/proc/has_casualty(mob/living/carbon/human/person)
	return !QDELETED(person) && (person in casualties) && on_loss_level(person)

/datum/stationtrauma_lost_space/proc/casualty_moved(mob/living/carbon/human/person)
	SIGNAL_HANDLER
	if(!on_loss_level(person))
		remove_casualty(person)

/datum/stationtrauma_lost_space/proc/remove_casualty(mob/living/carbon/human/person)
	SIGNAL_HANDLER
	UnregisterSignal(person, list(COMSIG_QDELETING, COMSIG_MOVABLE_Z_CHANGED, COMSIG_ENTER_AREA))
	person.lose_area_sensitivity(REF(src))
	var/datum/stationtrauma_overmap_site/space/distress/casualty/site = casualties[person]
	casualties -= person
	withdraw_site(site)

/// Release the chart entry immediately; keep a reserved berth until docking or departure finishes.
/datum/stationtrauma_lost_space/proc/withdraw_site(datum/stationtrauma_overmap_site/space/distress/site)
	if(!site)
		return
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
	if(sector?.sites[site.id] == site)
		sector.sites -= site.id
	site.failed = TRUE
	// Departure releases an orphaned dock after dismantling its real passage.
	if(!site.docking_owner)
		qdel(site)
	else if(site.docking_owner.docked != site)
		INVOKE_ASYNC(site, TYPE_PROC_REF(/datum/stationtrauma_overmap_site/space/distress, finish_cancelled_docking))

/** Chart an approach to this particular person. A beacon elsewhere must retain its own berth. */
/datum/stationtrauma_lost_space/proc/rescue_site(mob/living/carbon/human/person)
	if(!has_casualty(person))
		return null
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
	if(QDELETED(sector))
		return null
	var/datum/stationtrauma_overmap_site/space/distress/casualty/site = casualties[person]
	if(!QDELETED(site))
		if(site.berth && !site.docking_owner && site.entrance != get_turf(person))
			qdel(site.berth, force = TRUE)
			site.berth = null
			site.map_loader = CALLBACK(src, PROC_REF(place_rescue_berth), site)
		return site
	site = new
	site.loss = src
	site.person_ref = WEAKREF(person)
	site.id = "rescue_[GLOB.stationtrauma_lost_spaces.Find(src)]_[++next_rescue_id]"
	site.pos_x = pos_x
	site.pos_y = pos_y
	site.map_loader = CALLBACK(src, PROC_REF(place_rescue_berth), site)
	casualties[person] = site
	rescue_sites += site
	sector.sites[site.id] = site
	return site

/** Whether anyone still needs this level: a fresh loss, the living, a transmitting beacon or a rescue in progress. */
/datum/stationtrauma_lost_space/proc/busy()
	if(!level || world.time - last_loss < ST_LOST_SHARED_TIME || signal?.docking_owner)
		return TRUE
	for(var/mob/living/carbon/human/person as anything in casualties)
		if(has_casualty(person))
			return TRUE
		remove_casualty(person)
	for(var/datum/stationtrauma_overmap_site/space/distress/casualty/site as anything in rescue_sites)
		if(site.docking_owner)
			return TRUE
		if(site.failed)
			qdel(site)
	if(length(stationtrauma_distress_callsigns(level.z_value)))
		return TRUE
	for(var/mob/living/lost as anything in GLOB.mob_living_list)
		if(lost.z == level.z_value && lost.stat != DEAD)
			return TRUE
	return FALSE

/** Take the level for a new loss of `navigation` at its current chart position. */
/datum/stationtrauma_lost_space/proc/claim(datum/stationtrauma_overmap_sector/space/sector, x, y, datum/stationtrauma_overmap/space/navigation)
	drop_signal()
	revision++
	navigation_ref = navigation ? WEAKREF(navigation) : null
	sector_id = sector.id
	pos_x = x
	pos_y = y
	last_loss = world.time
	wreck = null
	var/closest = ST_LOST_WRECK_RANGE
	for(var/id in sector.sites)
		var/datum/stationtrauma_overmap_site/space/site = sector.sites[id]
		if(!istype(site) || istype(site, /datum/stationtrauma_overmap_site/space/planet) || istype(site, /datum/stationtrauma_overmap_site/space/distress) || site.landing || site.physical_docking || site.failed)
			continue
		if(QDELETED(site.berth) && !site.awaits_map())
			continue
		var/distance = sqrt((site.pos_x - pos_x) ** 2 + (site.pos_y - pos_y) ** 2)
		if(distance <= closest)
			closest = distance
			wreck = site
	set_edges(level.z_value)
	if(wreck)
		INVOKE_ASYNC(src, PROC_REF(reach_wreck), revision)

/** Load the nearby wreck, then lead every edge of the level into its level: drifting or flying off the edge arrives there. */
/datum/stationtrauma_lost_space/proc/reach_wreck(expected)
	var/datum/stationtrauma_overmap_site/space/target = wreck
	target.load_map()
	UNTIL(!target.loading_map)
	if(revision != expected || wreck != target || target.failed || QDELETED(target.berth) || signal?.berth || signal?.loading_map)
		return
	for(var/datum/stationtrauma_overmap_site/space/distress/casualty/site as anything in rescue_sites)
		if(site.berth || site.loading_map)
			return
	set_edges(target.berth.z)

/**
 * Point every border tile of the level at the opposite side of `target_z`, as native cross-linked space does.
 *
 * Arguments:
 * * target_z - Receiving level; this level itself loops, null leaves plain borders
 */
/datum/stationtrauma_lost_space/proc/set_edges(target_z)
	var/update = ++edge_revision
	edge_destination = target_z
	setting_edges = TRUE
	var/z = level.z_value
	var/inner_max_x = world.maxx - TRANSITIONEDGE
	var/inner_max_y = world.maxy - TRANSITIONEDGE
	var/list/x_low = list(1, 1, inner_max_x, 1)
	var/list/y_low = list(inner_max_y, 1, 1 + TRANSITIONEDGE, 1 + TRANSITIONEDGE)
	var/list/x_high = list(world.maxx, world.maxx, world.maxx, 1 + TRANSITIONEDGE)
	var/list/y_high = list(world.maxy, 1 + TRANSITIONEDGE, inner_max_y, inner_max_y)
	var/list/x_arrival = list(0, 0, TRANSITIONEDGE + 2, inner_max_x - 1)
	var/list/y_arrival = list(TRANSITIONEDGE + 2, inner_max_y - 1, 0, 0)
	for(var/side in 1 to 4)
		if(update != edge_revision)
			return
		for(var/turf/open/tile in block(x_low[side], y_low[side], z, x_high[side], y_high[side], z))
			tile.destination_x = target_z ? (x_arrival[side] || tile.x) : null
			tile.destination_y = target_z ? (y_arrival[side] || tile.y) : null
			tile.destination_z = target_z
		CHECK_TICK
	if(update == edge_revision)
		setting_edges = FALSE

/** Chart or withdraw the distress destination as beacons on this level switch on and off. */
/datum/stationtrauma_lost_space/proc/refresh_signal()
	var/transmitting = length(stationtrauma_distress_callsigns(level.z_value))
	if(transmitting && !signal)
		var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		if(!sector)
			return
		signal = new
		signal.id = "distress_[GLOB.stationtrauma_lost_spaces.Find(src)]_[revision]"
		signal.loss = src
		signal.pos_x = pos_x
		signal.pos_y = pos_y
		signal.map_loader = CALLBACK(src, PROC_REF(place_rescue_berth), signal)
		sector.sites[signal.id] = signal
	else if(!transmitting && signal && !signal.docking_owner)
		drop_signal()

/** Withdraw the distress destination and its berth. */
/datum/stationtrauma_lost_space/proc/drop_signal()
	var/datum/stationtrauma_overmap_site/space/distress/old_signal = signal
	signal = null
	withdraw_site(old_signal)

/// Use the current physical target after clearing the edges, which can yield to movement or an entirely new loss.
/datum/stationtrauma_lost_space/proc/place_rescue_berth(datum/stationtrauma_overmap_site/space/distress/site)
	if(!isnull(edge_destination))
		set_edges(null)
	UNTIL(!setting_edges || QDELETED(site))
	var/turf/tile = site?.rescue_turf()
	if(QDELETED(site) || !tile)
		return FALSE
	var/margin = ST_LOST_BERTH_MARGIN
	site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(clamp(tile.x, margin, world.maxx - margin), clamp(tile.y, margin, world.maxy - margin), level.z_value))
	site.entrance = tile
	return TRUE

/** Distress destination at the chart point of a loss, listed while a beacon transmits on its open-space level. */
/datum/stationtrauma_overmap_site/space/distress
	name = "Сигнал бедствия"
	radius = 20
	discovered = FALSE
	needs_scan = TRUE
	approach_scene = "sos"
	/// Loss whose level this destination leads to.
	var/datum/stationtrauma_lost_space/loss

/// A target can leave while the docking code still owns its berth and is dismantling a partial passage.
/datum/stationtrauma_overmap_site/space/distress/proc/finish_cancelled_docking()
	UNTIL(QDELETED(src) || QDELETED(docking_owner) || docking_owner.docked == src)
	if(!QDELETED(src) && QDELETED(docking_owner))
		qdel(src)

/datum/stationtrauma_overmap_site/space/distress/Destroy()
	if(berth)
		qdel(berth, force = TRUE)
		berth = null
	loss = null
	return ..()

/datum/stationtrauma_overmap_site/space/distress/distress_callsigns()
	return loss?.level ? stationtrauma_distress_callsigns(loss.level.z_value) : list()

/datum/stationtrauma_overmap_site/space/distress/proc/rescue_turf()
	if(loss?.signal != src)
		return null
	for(var/obj/item/stationtrauma_distress_beacon/beacon as anything in GLOB.stationtrauma_distress_beacons)
		var/turf/tile = get_turf(beacon)
		if(beacon.active && tile?.z == loss.level.z_value)
			return tile
	return null

/datum/stationtrauma_overmap_site/space/distress/casualty
	name = "Человек за бортом"
	/// The specific body whose physical position supplies this berth when docking begins.
	var/datum/weakref/person_ref

/datum/stationtrauma_overmap_site/space/distress/casualty/rescue_turf()
	var/mob/living/carbon/human/person = person_ref?.resolve()
	return loss?.has_casualty(person) ? get_turf(person) : null

/datum/stationtrauma_overmap_site/space/distress/casualty/distress_callsigns()
	return list()

/datum/stationtrauma_overmap_site/space/distress/casualty/Destroy()
	if(loss)
		loss.rescue_sites -= src
	person_ref = null
	return ..()

/// Hull-relative drift on a flight level; past the native transit border the drifter is swept into open space.
/datum/component/shuttle_cling/stationtrauma
	/// Hull whose motion pulls; the drift ends once it stops.
	var/datum/weakref/navigation_ref
	/// Set once the drifter has been handed to the hull's stranding; it is not retried.
	var/stranding = FALSE

/datum/component/shuttle_cling/stationtrauma/Initialize(direction, datum/stationtrauma_overmap/space/navigation)
	// The parent checks the position at once, so the hull must be known first.
	navigation_ref = WEAKREF(navigation)
	return ..()

/datum/component/shuttle_cling/stationtrauma/is_on_hyperspace(atom/movable/clinger)
	var/datum/stationtrauma_overmap/space/navigation = navigation_ref?.resolve()
	var/turf/tile = clinger?.loc
	return navigation?.parallax_direction && navigation.exterior && isspaceturf(tile) && tile.loc == navigation.exterior

/datum/component/shuttle_cling/stationtrauma/update_state()
	var/datum/stationtrauma_overmap/space/navigation = navigation_ref?.resolve()
	var/atom/movable/clinger = parent
	// The exterior area lies on the hull's own level, so the distance is never across levels.
	if(!stranding && is_on_hyperspace(clinger) && !QDELETED(navigation.vessel) && get_dist(clinger, navigation.vessel) > max(navigation.vessel.width, navigation.vessel.height) + SHUTTLE_TRANSIT_BORDER)
		stranding = TRUE
		INVOKE_ASYNC(navigation, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, strand), clinger, direction)
	return ..()
