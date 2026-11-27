/datum/stationtrauma_overmap/space
	/// Crew-local number of the biosignature chosen for approach.
	var/selected_biosignature
	/// Private sonar fix used by the autopilot when the contact has no physical berth.
	var/datum/stationtrauma_overmap_site/space/biosignature_waypoint

/** Sample the life state and position together, only when this ship's sensors reach the body. */
/datum/stationtrauma_overmap/space/proc/observe_biosignatures(reach, mode)
	var/datum/stationtrauma_overmap_sector/space/here = sector
	if(!here)
		return 0
	var/found = 0
	var/reach_squared = reach ** 2
	for(var/datum/stationtrauma_space_worm/worm as anything in here.space_worms)
		if((worm.pos_x - pos_x) ** 2 + (worm.pos_y - pos_y) ** 2 > reach_squared)
			continue
		var/datum/weakref/key = WEAKREF(worm)
		var/list/signature = list("kind" = "worm", "name" = "Космический глист", "dead" = worm.health <= 0)
		found += record_contact_observation(key, worm.pos_x, worm.pos_y, mode, fauna = signature)
		if(biosignature_waypoint && !selected_destination && ship_observations[key]["id"] == selected_biosignature)
			biosignature_waypoint.pos_x = worm.pos_x
			biosignature_waypoint.pos_y = worm.pos_y
			if(autopilot && length(autopilot_path))
				autopilot_path[length(autopilot_path)] = list(worm.pos_x, worm.pos_y)
	for(var/datum/stationtrauma_lost_space/loss as anything in GLOB.stationtrauma_lost_spaces)
		if(loss.sector_id != here.id || (loss.pos_x - pos_x) ** 2 + (loss.pos_y - pos_y) ** 2 > reach_squared)
			continue
		for(var/mob/living/carbon/human/person as anything in loss.casualties)
			if(!loss.has_casualty(person))
				continue
			var/list/signature = list("kind" = "human", "name" = "Человек за бортом", "dead" = person.stat == DEAD)
			found += record_contact_observation(WEAKREF(person), loss.pos_x, loss.pos_y, mode, fauna = signature)
	return found

/** The helm uses the normal engine and manoeuvre interlocks for a sonar approach. */
/datum/stationtrauma_overmap/space/proc/can_approach_biosignature()
	return is_operational() && !relocating && !planning && !arrival_pending && !approach_started && !jump_target && throttle > 0 && propulsion_available() && !carrier_busy()

/** Resolve a crew-local sensor fix, then fly to the animal or the real rescue berth. */
/datum/stationtrauma_overmap/space/proc/approach_biosignature(number)
	var/datum/stationtrauma_overmap_sector/space/here = sector
	if(!here || !isnum(number) || !can_approach_biosignature())
		return FALSE
	for(var/datum/weakref/key in ship_observations)
		var/list/record = ship_sensor_observation(key)
		if(!record || record["id"] != number || !record["fauna"])
			continue
		var/datum/source = key.resolve()
		if(ishuman(source))
			var/datum/stationtrauma_overmap_site/space/distress/casualty/rescue
			for(var/datum/stationtrauma_lost_space/loss as anything in GLOB.stationtrauma_lost_spaces)
				if(loss.sector_id == here.id && loss.pos_x == record["x"] && loss.pos_y == record["y"] && loss.has_casualty(source))
					rescue = loss.rescue_site(source)
					break
			if(QDELETED(rescue) || docked == rescue)
				return FALSE
			discover_site(rescue)
			if(!select_site(rescue.id))
				return FALSE
		else
			var/datum/stationtrauma_space_worm/worm = source
			if(!istype(worm) || worm.sector != sector)
				return FALSE
			clear_biosignature_course()
			cancel_station_docking()
			control_revision++
			autopilot = FALSE
			autopilot_path = null
			selected_destination = null
			biosignature_waypoint = new
			biosignature_waypoint.name = record["fauna"]["name"]
			biosignature_waypoint.id = "biosignature_[number]"
			// Stop outside the hull, close enough for the crew to see the body on its flight deck.
			biosignature_waypoint.radius = 6
			biosignature_waypoint.pos_x = record["x"]
			biosignature_waypoint.pos_y = record["y"]
			prepared_site = biosignature_waypoint
			trip_distance = distance_to(prepared_site)
			travelled = 0
		selected_biosignature = number
		return engage_autopilot()
	return FALSE

/datum/stationtrauma_overmap/space/flight_destination()
	RETURN_TYPE(/datum/stationtrauma_overmap_site/space)
	return selected_destination ? ..() : biosignature_waypoint

/** Drop this helm's private fix on retarget or sector transfer. */
/datum/stationtrauma_overmap/space/proc/clear_biosignature_course()
	selected_biosignature = null
	if(biosignature_waypoint && prepared_site == biosignature_waypoint)
		prepared_site = null
	QDEL_NULL(biosignature_waypoint)
