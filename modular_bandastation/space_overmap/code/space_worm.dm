/// Emitted once when a space worm dies and its sector body becomes a carcass.
#define COMSIG_SPACE_WORM_DEATH "space_worm_death"

/// Hunting reach relative to the target's current active sensor range.
#define SPACE_WORM_DETECTION_MULTIPLIER 1.1
/// Metres per second. Fast ships can pull away at full power.
#define SPACE_WORM_SPEED 7
/// Closest distance in metres from the worm's centre to the hunted hull's plating.
#define SPACE_WORM_HULL_CLEARANCE 4
/// Distance from exposed plating at which a worm starts spitting.
#define SPACE_WORM_SPIT_RANGE 140

/** A sector predator drawn to powered engines, including an idling drive. */
/datum/stationtrauma_space_worm
	/// Sector which owns this animal.
	var/datum/stationtrauma_overmap_sector/space/sector
	/// Current easting in sector metres.
	var/pos_x
	/// Current northing in sector metres.
	var/pos_y
	/// Bearing of the mouth, clockwise from north.
	var/course = 0
	/// Radius in metres for swept hits from naval weapons.
	var/radius = 5
	/// Remaining health shared by sector hits and flight-deck projections.
	var/health = 240
	/// Time and velocity of the latest movement sample for sector projectile collision.
	var/last_update
	/// Eastward velocity in metres per second.
	var/velocity_x = 0
	/// Northward velocity in metres per second.
	var/velocity_y = 0
	/// Time between acid volleys.
	COOLDOWN_DECLARE(spit_cooldown)

/datum/stationtrauma_space_worm/New(datum/stationtrauma_overmap_sector/space/sector, x, y)
	..()
	if(QDELETED(sector))
		qdel(src)
		return
	src.sector = sector
	pos_x = x
	pos_y = y
	last_update = world.time
	sector.space_worms += src
	START_PROCESSING(SSprocessing, src)

/datum/stationtrauma_space_worm/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	sector?.space_worms -= src
	sector = null
	return ..()

/** Apply a hit to the animal itself regardless of which nearby ship saw it. */
/datum/stationtrauma_space_worm/proc/take_damage(amount)
	SHOULD_CALL_PARENT(TRUE)
	if(health <= 0 || amount <= 0)
		return
	health = max(0, health - amount)
	if(health)
		return
	STOP_PROCESSING(SSprocessing, src)
	velocity_x = 0
	velocity_y = 0
	SEND_SIGNAL(src, COMSIG_SPACE_WORM_DEATH)

/** Each second, pick the nearest hull with a live drive and close to just outside its plating. */
/datum/stationtrauma_space_worm/process(seconds_per_tick)
	if(health <= 0)
		return PROCESS_KILL
	last_update = world.time
	velocity_x = 0
	velocity_y = 0
	var/datum/stationtrauma_overmap/space/target
	var/closest_squared = INFINITY
	for(var/id in sector.ships)
		var/datum/stationtrauma_overmap/space/ship = sector.ships[id]
		if(!ship.kinetic_exposed() || !ship.vessel.engines_running)
			continue
		var/distance_squared = (ship.pos_x - pos_x) ** 2 + (ship.pos_y - pos_y) ** 2
		if(distance_squared >= closest_squared || distance_squared > (ship.sensor_range * SPACE_WORM_DETECTION_MULTIPLIER) ** 2 || ship.engine_fraction() <= 0)
			continue
		target = ship
		closest_squared = distance_squared
	if(!target || seconds_per_tick <= 0)
		return
	var/distance = sqrt(closest_squared)
	if(distance)
		course = delta_to_angle(target.pos_x - pos_x, target.pos_y - pos_y)
	var/direction_x = sin(course)
	var/direction_y = cos(course)
	var/move_limit = SPACE_WORM_SPEED * seconds_per_tick
	var/travel = clamp(distance - target.radius - SPACE_WORM_HULL_CLEARANCE, -move_limit, move_limit)
	velocity_x = direction_x * travel / seconds_per_tick
	velocity_y = direction_y * travel / seconds_per_tick
	pos_x += direction_x * travel
	pos_y += direction_y * travel
	var/hull_distance = distance - travel - target.radius
	if(hull_distance <= 0 || hull_distance > SPACE_WORM_SPIT_RANGE || !COOLDOWN_FINISHED(src, spit_cooldown))
		return
	COOLDOWN_START(src, spit_cooldown, 8 SECONDS)
	var/datum/stationtrauma_kinetic_shot/shot = new
	shot.projectile_type = /obj/projectile/bullet/stationtrauma_kinetic/worm_acid
	shot.sector_ref = WEAKREF(sector)
	shot.source_ref = WEAKREF(src)
	shot.pos_x = pos_x
	shot.pos_y = pos_y
	shot.direction_x = direction_x
	shot.direction_y = direction_y
	shot.remaining = SPACE_WORM_SPIT_RANGE
	shot.start_sector_travel(sector)

/** A glob that keeps its bearing in space and corrodes the first exposed surface it strikes. */
/obj/projectile/bullet/stationtrauma_kinetic/worm_acid
	name = "сгусток едкой желчи"
	icon = /obj/projectile/bileworm_acid::icon
	icon_state = /obj/projectile/bileworm_acid::icon_state
	damage = 18
	damage_type = BURN
	armor_flag = ACID
	shrapnel_type = null
	embed_type = null
	wound_falloff_tile = 0
	embed_falloff_tile = 0
	sector_speed = 36
	shield_impact = 15 KILO JOULES
	plot_color = COLOR_LIME
	hitsound = 'sound/items/weapons/sear.ogg'
	hitsound_wall = 'sound/items/weapons/effects/searwall.ogg'
	impact_effect_type = null

/obj/projectile/bullet/stationtrauma_kinetic/worm_acid/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(. == BULLET_ACT_HIT && blocked < 100 && !QDELETED(target))
		target.acid_act(ACID_POWER_MELT_TURF, 50 * impact_strength * (1 - blocked / 100))

/obj/projectile/bullet/stationtrauma_kinetic/worm_acid/damage_wall(turf/closed/wall/wall)
	// on_hit applies native acid corrosion to plating as well as to crew and fixtures.
	return

#undef SPACE_WORM_DETECTION_MULTIPLIER
#undef SPACE_WORM_SPEED
#undef SPACE_WORM_HULL_CLEARANCE
#undef SPACE_WORM_SPIT_RANGE
