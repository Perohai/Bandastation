/datum/action/cooldown/alien/banda/spit
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "neuro_spit"
	name = "Плевок ксеноморфа"
	desc = "Выплёвывает нейротоксин. Режим кислоты наносит ожоговый урон."
	plasma_cost = 40
	click_to_activate = TRUE
	unset_after_click = FALSE
	var/acid_mode = FALSE
	var/acid_projectile = /obj/projectile/neurotoxin/banda/acid/standard

/datum/action/cooldown/alien/banda/spit/Activate(atom/target)
	if(!target || !isturf(owner.loc) || target.z != owner.z || get_dist(owner, target) > 7)
		return FALSE
	var/projectile_type = acid_mode ? acid_projectile : /obj/projectile/neurotoxin/banda
	var/obj/projectile/projectile = new projectile_type(owner.loc)
	projectile.aim_projectile(target, owner, list())
	projectile.firer = owner
	projectile.fire()
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_spitacid.ogg', 70, TRUE)
	return TRUE

/datum/action/cooldown/alien/banda/spit/praetorian
	acid_projectile = /obj/projectile/neurotoxin/banda/acid/standard/praetorian

/obj/projectile/neurotoxin/banda
	name = "neurotoxin spit"
	damage = 30
	paralyze = 0
	damage_type = STAMINA
	armor_flag = BIO

/obj/projectile/neurotoxin/banda/acid
	name = "acid spit"
	icon_state = "toxin"
	damage_type = BURN

/obj/projectile/neurotoxin/banda/acid/standard
	damage = 15

/obj/projectile/neurotoxin/banda/acid/standard/praetorian
	damage = 10

/datum/action/cooldown/alien/banda/toggle_spit
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "toggle_spit"
	name = "Переключить плевок"
	desc = "Переключает между нейротоксином за 40 плазмы и кислотой за 100 плазмы."

/datum/action/cooldown/alien/banda/toggle_spit/Activate()
	var/datum/action/cooldown/alien/banda/spit/spit = locate() in owner.actions
	if(!spit)
		return FALSE
	spit.acid_mode = !spit.acid_mode
	spit.plasma_cost = spit.acid_mode ? 100 : 40
	spit.button_icon_state = spit.acid_mode ? "acid_spit" : "neuro_spit"
	spit.name = "[spit.acid_mode ? "Кислотный плевок" : "Нейротоксин"] ([spit.plasma_cost]P)"
	spit.build_all_button_icons(UPDATE_BUTTON_STATUS)
	return TRUE

/datum/action/cooldown/alien/banda/acid_volley
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "acid_volley"
	name = "Разбросанный плевок"
	desc = "После короткой подготовки выпускает три кислотных снаряда, оставляющих лужи на две секунды."
	plasma_cost = 280
	cooldown_time = 15 SECONDS
	click_to_activate = TRUE
	var/preparing = FALSE

/datum/action/cooldown/alien/banda/acid_volley/Activate(atom/target)
	var/turf/location = get_turf(target)
	if(preparing || !isturf(owner.loc) || !location || owner.z != location.z || get_dist(owner, location) > 7)
		return FALSE
	preparing = TRUE
	var/ready = do_after(owner, 0.5 SECONDS, target = location)
	preparing = FALSE
	if(!ready || QDELETED(src) || QDELETED(owner) || !IsAvailable() || !isturf(owner.loc) || owner.z != location.z || get_dist(owner, location) > 7)
		return FALSE
	var/obj/item/ammo_casing/xeno_acid_volley/casing = new(owner.loc)
	casing.fire_casing(location, owner, null, null, null, BODY_ZONE_CHEST, 0, owner)
	qdel(casing)
	StartCooldown()
	return TRUE

/obj/item/ammo_casing/xeno_acid_volley
	projectile_type = /obj/projectile/neurotoxin/banda/acid/pool
	pellets = 3
	variance = 20

/obj/projectile/neurotoxin/banda/acid/pool
	damage = 10
	range = 7

/obj/projectile/neurotoxin/banda/acid/pool/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/turf/location = get_turf(target)
	if(isopenturf(location))
		new /obj/effect/xeno_acid_pool(location)

/obj/projectile/neurotoxin/banda/acid/pool/on_range()
	if(isopenturf(loc))
		new /obj/effect/xeno_acid_pool(loc)
	return ..()

/datum/action/cooldown/alien/banda/acid_spray
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "acid_line"
	name = "Кислотный спрей"
	desc = "Покрывает семь клеток перед собой кислотой, сбивающей врагов с ног и гасящей огонь на союзниках."
	plasma_cost = 300
	cooldown_time = 40 SECONDS
	click_to_activate = TRUE
	var/cone = FALSE

/datum/action/cooldown/alien/banda/acid_spray/Activate(atom/target)
	var/turf/target_turf = get_turf(target)
	if(!isturf(owner.loc) || !target_turf || owner.z != target_turf.z || target_turf == owner.loc)
		return FALSE
	var/direction = get_dir(owner, target_turf)
	if(cone)
		var/turf/center = get_turf(owner)
		for(var/row in 1 to 5)
			center = get_step(center, direction)
			if(!center || isclosedturf(center))
				break
			for(var/side in -1 to 1)
				var/turf/location = side ? get_step(center, turn(direction, side * 90)) : center
				spray_tile(location)
	else
		var/turf/destination = get_ranged_target_turf(owner, direction, 7)
		for(var/turf/location as anything in get_line(owner, destination))
			if(location != owner.loc && !spray_tile(location))
				break
	StartCooldown()
	return TRUE

/// Acid must not pass through walls or dense structures, including the sides of the cone.
/datum/action/cooldown/alien/banda/acid_spray/proc/spray_tile(turf/location)
	if(!location)
		return FALSE
	for(var/turf/path_tile as anything in get_line(owner, location))
		if(isclosedturf(path_tile))
			return FALSE
		for(var/obj/structure/blocker in path_tile)
			if(blocker.density)
				return FALSE
	new /obj/effect/xeno_acid_pool/spray(location)
	return TRUE

/datum/action/cooldown/alien/banda/acid_spray/cone
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "acid_cone"
	desc = "Покрывает область 3×5 клеток кислотой, опрокидывающей и обжигающей врагов."
	cooldown_time = 60 SECONDS
	cone = TRUE

/obj/effect/xeno_acid_pool
	name = "xenomorph acid"
	icon = 'modular_bandastation/xeno_rework/icons/xeno_effects.dmi'
	icon_state = "acid_pool"
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/lifetime = 2 SECONDS
	var/knockdown_time = 0
	var/static/list/loc_connections = list(COMSIG_ATOM_ENTERED = PROC_REF(on_entered))

/obj/effect/xeno_acid_pool/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/connect_loc, loc_connections)
	START_PROCESSING(SSfastprocess, src)
	QDEL_IN(src, lifetime)

/obj/effect/xeno_acid_pool/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	return ..()

/obj/effect/xeno_acid_pool/process(seconds_per_tick)
	for(var/mob/living/victim in loc)
		affect(victim, seconds_per_tick)

/obj/effect/xeno_acid_pool/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(isliving(arrived))
		affect(arrived, 0)

/obj/effect/xeno_acid_pool/proc/affect(mob/living/victim, seconds_per_tick)
	if(isalien(victim))
		victim.extinguish_mob()
		return
	victim.apply_damage(5 * seconds_per_tick, BURN, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, BIO), wound_bonus = CANT_WOUND)
	if(knockdown_time)
		victim.Knockdown(knockdown_time)

/obj/effect/xeno_acid_pool/spray
	lifetime = 5 SECONDS
	knockdown_time = 0.5 SECONDS
