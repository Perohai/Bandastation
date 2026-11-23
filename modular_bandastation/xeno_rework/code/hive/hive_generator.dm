/** Expensive, noisy, destructible passive income. No extra subsystem or infrastructure chain. */
/obj/structure/xeno_biomass_generator
	name = "hive biomass generator"
	desc = "Громоздкий органический переработчик, заполняющий четыре клетки. Производит одну единицу биомассы в секунду и издаёт громкий шум."
	icon = 'modular_bandastation/xeno_rework/icons/structures/biomass_generator.dmi'
	icon_state = "generator"
	anchored = TRUE
	density = TRUE
	bound_width = 64
	bound_height = 64
	max_integrity = 350
	/// 600 biomass / 1 per second = exactly ten minutes of continuous operation.
	var/biomass_per_second = 1
	/// Loop owns its playback and releases the structure reference during teardown.
	var/datum/looping_sound/xeno_generator/soundloop
	/// Cosmetic vapor reuses the existing processing pass, with no atmospheric effect.
	COOLDOWN_DECLARE(vapor_cooldown)
	/// Prevent repeated destruction callbacks from applying the same burst twice.
	var/acid_released = FALSE
	/// One local burst, followed by the ordinary short-lived acid pools.
	var/burst_damage = 40
	var/burst_radius = 2

/obj/structure/xeno_biomass_generator/Initialize(mapload)
	. = ..()
	soundloop = new(src)
	soundloop.start()
	add_filter("xeno_generator_breath", 1, color_matrix_filter(COLOR_WHITE))
	transition_filter_chain("xeno_generator_breath", INDEFINITE,
		filter_chain_step(color_matrix_filter("#dedede"), 1.5 SECONDS, SINE_EASING),
		filter_chain_step(color_matrix_filter(COLOR_WHITE), 1.5 SECONDS, SINE_EASING))
	START_PROCESSING(SSobj, src)

/obj/structure/xeno_biomass_generator/Destroy()
	STOP_PROCESSING(SSobj, src)
	QDEL_NULL(soundloop)
	return ..()

/** Integrity destruction releases acid; administrative deletion does not. */
/obj/structure/xeno_biomass_generator/atom_destruction(damage_flag)
	if(!acid_released)
		acid_released = TRUE
		var/turf/center = get_turf(src)
		var/obj/effect/temp_visual/explosion/fast/burst = new(center)
		burst.color = "#a0b65a"
		playsound(center, 'sound/effects/explosion/explosion1.ogg', 75, TRUE)
		playsound(center, 'modular_bandastation/xeno_rework/sound/alien_spitacid2.ogg', 100, TRUE)
		visible_message(span_danger("[src] лопается, разбрызгивая кислоту!"))
		for(var/turf/location in view(burst_radius, src))
			if(!isopenturf(location))
				continue
			new /obj/effect/xeno_acid_pool(location)
			for(var/mob/living/victim in location)
				if(!isalien(victim))
					victim.apply_damage(burst_damage, BURN, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, ACID))
	return ..()

/obj/structure/xeno_biomass_generator/process(seconds_per_tick)
	var/datum/xeno_hive/hive = get_xeno_hive()
	hive.biomass += biomass_per_second * seconds_per_tick
	if(COOLDOWN_FINISHED(src, vapor_cooldown))
		new /obj/effect/temp_visual/xeno_generator_vapor(get_turf(src))
		COOLDOWN_START(src, vapor_cooldown, 2 SECONDS)

/datum/looping_sound/xeno_generator
	mid_sounds = list('sound/machines/sm/loops/calm.ogg' = 1)
	mid_length = 4 SECONDS
	volume = 60
	extra_range = 0
	falloff_distance = 3

/** Always place the 2x2 footprint entirely in front of the queen, not around her body. */
/datum/xeno_hive/proc/hive_structure_location(mob/living/carbon/alien/adult/banda/queen/queen)
	if(!can_manage(queen) || !(queen.dir in GLOB.cardinals))
		return null
	var/turf/origin = get_step(queen, queen.dir)
	if(queen.dir == SOUTH || queen.dir == WEST)
		origin = get_step(origin, queen.dir)
	return origin

/datum/xeno_hive/proc/can_place_generator(mob/living/carbon/alien/adult/banda/queen/queen, turf/origin)
	return can_manage(queen) && origin == hive_structure_location(queen) && clear_structure_footprint(origin)

/** Shared placement for the brood core, generators and one-tile Hivemind anchors. */
/datum/xeno_hive/proc/clear_structure_footprint(turf/origin, width = 2, height = 2, floors_only = TRUE)
	if(!origin)
		return FALSE
	var/turf/far_corner = locate(origin.x + width - 1, origin.y + height - 1, origin.z)
	if(!far_corner)
		return FALSE
	// Native large structures collide by bounds, but turf contents only contains their anchor.
	for(var/obj/structure/existing in range(2, origin))
		if(!istype(existing, /obj/structure/xeno_biomass_generator) && !istype(existing, /obj/structure/xeno_hive_core))
			continue
		if(existing.x <= far_corner.x && existing.x + 1 >= origin.x && existing.y <= far_corner.y && existing.y + 1 >= origin.y)
			return FALSE
	for(var/turf/location in block(origin, far_corner))
		if(!isopenturf(location) || isspaceturf(location) || (floors_only && !isfloorturf(location)) || location.is_blocked_turf(exclude_mobs = FALSE))
			return FALSE
		for(var/obj/structure/structure in location)
			if(!istype(structure, /obj/structure/alien/weeds))
				return FALSE
	return TRUE

/** A rising native smoke sprite leaves the resin shell perfectly stationary. */
/obj/effect/temp_visual/xeno_generator_vapor
	parent_type = /obj/effect/temp_visual/small_smoke
	duration = 3 SECONDS
	color = "#819f61"
	alpha = 120
	pixel_x = 16
	pixel_y = 18
	layer = ABOVE_ALL_MOB_LAYER
	plane = ABOVE_GAME_PLANE

/obj/effect/temp_visual/xeno_generator_vapor/Initialize(mapload)
	. = ..()
	animate(src, pixel_y = pixel_y + 30, alpha = 0, transform = matrix() * 1.4, time = duration)
