/// Normal TGMC Spitter: acid spatter, Scatter Spit, line Spray Acid.
/datum/action/cooldown/alien/banda/tgmc/acid_spit
	name = "Acid Spit"
	desc = "Одиночный кислотный плевок. Дальность — 8 клеток."
	button_icon_state = "acidspit_0"
	plasma_cost = 50
	/// 0.5s caste delay + 0.5s ammo delay in TGMC.
	cooldown_time = 1 SECONDS

/datum/action/cooldown/alien/banda/tgmc/acid_spit/Activate(atom/target)
	return fire_spit(target, /obj/projectile/xeno_tgmc_acid)

/obj/projectile/xeno_tgmc_acid
	name = "acid spatter"
	icon_state = "toxin"
	/// 35 base + 45% normal-caste spit bonus, as in TGMC.
	damage = 50.75
	damage_type = BURN
	armor_flag = ACID
	armour_penetration = 0
	range = 8
	var/leaves_puddle = FALSE

/obj/projectile/xeno_tgmc_acid/prehit_pierce(atom/target)
	if(isalien(target))
		return PROJECTILE_PIERCE_PHASE
	return ..()

/obj/projectile/xeno_tgmc_acid/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(leaves_puddle)
		leave_acid_puddle()

/obj/projectile/xeno_tgmc_acid/on_range()
	if(leaves_puddle)
		leave_acid_puddle()
	return ..()

/obj/projectile/xeno_tgmc_acid/proc/leave_acid_puddle()
	var/turf/location = get_turf(src)
	if(location && !location.density && !isspaceturf(location))
		xeno_tgmc_create_acid(location, 1 SECONDS + rand(0, 2 SECONDS), 14, firer)

/obj/projectile/xeno_tgmc_acid/scatter
	name = "scattered acid"
	damage = 20
	leaves_puddle = TRUE

/datum/action/cooldown/alien/banda/tgmc/scatter_spit
	name = "Scatter Spit"
	desc = "После подготовки в полсекунды выпускает семь кислотных снарядов, оставляющих лужи."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc_spitter_actions.dmi'
	button_icon_state = "scatter_spit"
	plasma_cost = 280
	cooldown_time = 5 SECONDS
	var/cast_time = 0.5 SECONDS
	var/casting = FALSE

/datum/action/cooldown/alien/banda/tgmc/scatter_spit/Activate(atom/target)
	if(casting)
		return FALSE
	casting = TRUE
	var/turf/aimed_turf = get_turf(target)
	var/completed = do_after(owner, cast_time, target = aimed_turf)
	casting = FALSE
	if(!completed || QDELETED(src) || QDELETED(owner) || !IsAvailable(TRUE) || QDELETED(target))
		return FALSE
	for(var/index in 1 to 7)
		var/obj/projectile/xeno_tgmc_acid/scatter/projectile = new(get_turf(owner))
		projectile.firer = owner
		projectile.fired_from = src
		if(index == 1)
			projectile.damage = 29 // Only the primary gets TGMC's 45% bonus.
		projectile.aim_projectile(target, owner)
		var/extra_index = index - 1
		var/offset = extra_index ? 2 * (extra_index % 2 ? -(extra_index + 1) * 0.5 : extra_index * 0.5) : 0
		projectile.fire(projectile.angle + offset)
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_spitacid2.ogg', 60, TRUE)
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/banda/tgmc/spray_acid
	name = "Spray Acid"
	desc = "Создаёт линию кислоты длиной до 8 клеток. Кислота задерживается на полу; стены и закрытые двери останавливают струю."
	button_icon_state = "acidspit_1"
	plasma_cost = 250
	cooldown_time = 30 SECONDS
	var/cast_time = 0.5 SECONDS
	var/spray_range = 8
	var/casting = FALSE
	var/list/turf/spray_path
	var/datum/weakref/caster_ref
	var/spray_timer

/datum/action/cooldown/alien/banda/tgmc/spray_acid/Activate(atom/target)
	if(casting || spray_path)
		return FALSE
	casting = TRUE
	var/turf/aimed_turf = get_turf(target)
	var/completed = do_after(owner, cast_time, target = aimed_turf)
	casting = FALSE
	if(!completed || QDELETED(src) || QDELETED(owner) || !IsAvailable(TRUE))
		return FALSE
	var/mob/living/carbon/alien/adult/banda/caster = owner
	var/turf/origin = get_turf(caster)
	if(origin == aimed_turf || origin.z != aimed_turf.z)
		return FALSE
	caster.face_atom(aimed_turf)
	spray_path = get_line(origin, aimed_turf)
	spray_path -= origin
	if(length(spray_path) > spray_range)
		spray_path.Cut(spray_range + 1)
	caster_ref = WEAKREF(caster)
	advance_spray(origin)
	playsound(caster, 'modular_bandastation/xeno_rework/sound/alien_spitacid2.ogg', 60, TRUE)
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/banda/tgmc/spray_acid/proc/advance_spray(turf/previous)
	spray_timer = null
	var/mob/living/carbon/alien/adult/banda/caster = caster_ref?.resolve()
	if(!caster || caster != owner || caster.stat != BANDA_XENO_AWAKE_STAT || !isturf(caster.loc) || !length(spray_path))
		cleanup_spray()
		return
	var/turf/next = spray_path[1]
	spray_path.Cut(1, 2)
	if(isspaceturf(next) || !caster.tgmc_clear_step(previous, next))
		// Damage exposed cover, but never spray through it or around a corner.
		if(!next.density && previous.Adjacent(next))
			for(var/obj/obstacle in next)
				if(obstacle.density && (istype(obstacle, /obj/structure) || istype(obstacle, /obj/machinery/door)))
					obstacle.take_damage(45, BURN, ACID)
		cleanup_spray()
		return
	var/obj/effect/xeno_tgmc_acid/puddle = xeno_tgmc_create_acid(next, 10 SECONDS, 20, caster)
	if(puddle)
		for(var/mob/living/victim in next)
			puddle.burn_victim(victim, 45)
		for(var/obj/structure/structure in next)
			if(!istype(structure, /obj/structure/alien))
				structure.take_damage(45, BURN, ACID)
	if(length(spray_path))
		spray_timer = addtimer(CALLBACK(src, PROC_REF(advance_spray), next), 0.2 SECONDS, TIMER_STOPPABLE)
	else
		cleanup_spray()

/datum/action/cooldown/alien/banda/tgmc/spray_acid/proc/cleanup_spray()
	if(spray_timer)
		deltimer(spray_timer)
	spray_timer = null
	spray_path = null
	caster_ref = null

/datum/action/cooldown/alien/banda/tgmc/spray_acid/Remove(mob/removed_from)
	cleanup_spray()
	return ..()

/datum/action/cooldown/alien/banda/tgmc/spray_acid/Destroy()
	cleanup_spray()
	return ..()

/datum/status_effect/banda_acid_contact_cooldown
	id = "banda_acid_contact_cooldown"
	alert_type = null
	duration = 1 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK

/proc/xeno_tgmc_create_acid(turf/location, lifetime, damage, mob/living/creator)
	if(!location || location.density || isspaceturf(location))
		return null
	var/obj/effect/xeno_tgmc_acid/existing = locate() in location
	if(existing)
		existing.expires_at = max(existing.expires_at, world.time + lifetime)
		existing.contact_damage = max(existing.contact_damage, damage)
		return existing
	return new /obj/effect/xeno_tgmc_acid(location, lifetime, damage, creator)

/obj/effect/xeno_tgmc_acid
	name = "кислотная лужа"
	desc = "Едкая кислота ксеноморфов."
	icon = 'modular_bandastation/xeno_rework/icons/tgmc_acid.dmi'
	icon_state = "acid2"
	anchored = TRUE
	density = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = LOW_OBJ_LAYER
	var/expires_at
	var/contact_damage = 14
	var/datum/weakref/creator_ref
	var/turf/registered_turf

/obj/effect/xeno_tgmc_acid/Initialize(mapload, lifetime = 10 SECONDS, damage = 14, mob/living/creator)
	. = ..()
	expires_at = world.time + lifetime
	contact_damage = damage
	if(creator)
		creator_ref = WEAKREF(creator)
	registered_turf = get_turf(src)
	RegisterSignal(registered_turf, COMSIG_ATOM_ENTERED, PROC_REF(on_entered))
	START_PROCESSING(SSprocessing, src)

/obj/effect/xeno_tgmc_acid/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	if(registered_turf)
		UnregisterSignal(registered_turf, COMSIG_ATOM_ENTERED)
	registered_turf = null
	creator_ref = null
	return ..()

/obj/effect/xeno_tgmc_acid/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(isliving(arrived))
		INVOKE_ASYNC(src, PROC_REF(burn_victim), arrived)

/obj/effect/xeno_tgmc_acid/process(seconds_per_tick)
	if(world.time >= expires_at || !isturf(loc))
		qdel(src)
		return PROCESS_KILL
	for(var/mob/living/victim in loc)
		burn_victim(victim)

/obj/effect/xeno_tgmc_acid/proc/burn_victim(mob/living/victim, initial_damage)
	if(QDELETED(victim) || victim.stat == DEAD || isalien(victim) || victim.movement_type & (FLYING|FLOATING))
		return
	if(victim.has_status_effect(/datum/status_effect/banda_acid_contact_cooldown))
		return
	victim.apply_status_effect(/datum/status_effect/banda_acid_contact_cooldown)
	var/amount = isnull(initial_damage) ? contact_damage : initial_damage
	var/armor = victim.run_armor_check(BODY_ZONE_L_LEG, ACID, silent = TRUE)
	victim.apply_damage(amount, BURN, BODY_ZONE_L_LEG, armor)
	victim.apply_status_effect(/datum/status_effect/staggered, 1 SECONDS)
	var/mob/living/creator = creator_ref?.resolve()
	if(creator)
		log_combat(creator, victim, "burned with acid spray")

/obj/item/organ/alien/neurotoxin/tgmc_spitter
	name = "spitter acid glands"
	actions_types = list(
		/datum/action/cooldown/alien/banda/tgmc/acid_spit,
		/datum/action/cooldown/alien/banda/tgmc/scatter_spit,
		/datum/action/cooldown/alien/banda/tgmc/spray_acid,
		/datum/action/cooldown/alien/acid/corrosion,
	)
