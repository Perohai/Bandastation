/** Finite expansion income. Coordinates survive weed deletion and replacement of the turf. */
/datum/xeno_hive
	/// Only strings are retained: no references to replaceable turfs or areas.
	var/list/claimed_territory = list()
	/// Start conservatively: 2,000 unique floors equal one fully processed human.
	var/territory_tiles_per_biomass = 20
	/// Integer remainder prevents fractional-credit drift and survives queen replacement.
	var/territory_pending_tiles = 0
	/// Historical income, independent of purchases and the queen death penalty.
	var/territory_biomass_earned = 0

/** No polling: invoked synchronously only when owned weeds first occupy a location. */
/datum/xeno_hive/proc/claim_territory(turf/location)
	if(territory_tiles_per_biomass <= 0 || !isfloorturf(location) || !is_station_level(location.z) || istype(get_area(location), /area/shuttle))
		return FALSE
	var/coordinate = "[location.x]:[location.y]:[location.z]"
	if(claimed_territory[coordinate])
		return FALSE
	claimed_territory[coordinate] = TRUE
	territory_pending_tiles++
	var/payment = FLOOR(territory_pending_tiles / territory_tiles_per_biomass, 1)
	if(payment > 0)
		territory_pending_tiles -= payment * territory_tiles_per_biomass
		territory_biomass_earned += payment
		biomass += payment
	return TRUE

/** A planted hive node marks its descendants through the native parent_node relationship. */
/obj/structure/alien/weeds/node/banda

/obj/structure/alien/weeds/node/banda/Initialize(mapload)
	var/already_covered = FALSE
	for(var/obj/structure/alien/weeds/existing in loc)
		if(existing != src)
			already_covered = TRUE
			break
	. = ..()
	if(. != INITIALIZE_HINT_QDEL && !mapload && !already_covered)
		record_hive_expansion()

/** Wild/map weeds cannot generate income, even when processed by a nearby hive node. */
/obj/structure/alien/weeds/proc/record_hive_expansion()
	if(QDELETED(src) || !isturf(loc) || QDELETED(parent_node) || !istype(parent_node, /obj/structure/alien/weeds/node/banda))
		return
	var/datum/xeno_hive/hive = get_xeno_hive()
	hive.claim_territory(loc)

/datum/action/cooldown/alien/make_structure/plant_weeds/Grant(mob/grant_to)
	made_structure_type = istype(grant_to, /mob/living/carbon/alien/adult/banda) ? /obj/structure/alien/weeds/node/banda : initial(made_structure_type)
	return ..()
