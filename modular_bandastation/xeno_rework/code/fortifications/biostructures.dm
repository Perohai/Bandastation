/// The existing resin builder owns placement, payment and async validation.
/proc/hive_structure_spec(structure_type)
	switch(structure_type)
		if(/obj/structure/alien/acid_mine)
			return list("upgrade" = "acid_mines", "plasma" = 150, "time" = 6 SECONDS)
		if(/obj/structure/alien/acid_turret)
			return list("upgrade" = "acid_turrets", "plasma" = 250, "time" = 20 SECONDS)
		if(/obj/structure/alien/resin/wall/reinforced)
			return list("upgrade" = "reinforced_resin", "plasma" = 250, "time" = 15 SECONDS)

/proc/can_build_hive_structure(mob/user, structure_type)
	var/list/spec = hive_structure_spec(structure_type)
	return !spec || (is_hive_resin_builder(user) && GLOB.xeno_hive?.purchased[spec["upgrade"]])

/obj/structure/alien/resin/wall/reinforced
	name = "укреплённая смоляная стена"
	max_integrity = 300
	color = "#555e76"

/obj/structure/alien/acid_mine
	name = "кислотная мина"
	desc = "Раздутый мешок кислоты в переплетении смолы."
	icon = 'modular_bandastation/xeno_rework/icons/structures/hive_fortifications.dmi'
	icon_state = "acid_mine"
	layer = LOW_OBJ_LAYER
	anchored = TRUE
	max_integrity = 5
	var/triggered = FALSE
	var/static/list/mine_connections = list(COMSIG_ATOM_ENTERED = PROC_REF(on_entered))

/obj/structure/alien/acid_mine/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/connect_loc, mine_connections)

/obj/structure/alien/acid_mine/proc/on_entered(datum/source, atom/movable/entrant)
	SIGNAL_HANDLER
	if(ishuman(entrant) && !triggered)
		detonate()

/obj/structure/alien/acid_mine/proc/detonate()
	if(triggered)
		return
	triggered = TRUE
	for(var/mob/living/carbon/human/victim in range(1, src))
		if(!(victim in view(1, src)))
			continue
		victim.apply_damage(30, BURN, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, BIO), wound_bonus = CANT_WOUND)
	for(var/turf/open/site in range(1, src))
		if(site in view(1, src))
			new /obj/effect/xeno_acid_pool(site)
	playsound(src, 'modular_bandastation/xeno_rework/sound/alien_spitacid2.ogg', 60, TRUE)
	qdel(src)

/obj/structure/alien/acid_mine/atom_destruction(damage_flag)
	detonate()
	return ..()

/obj/structure/alien/acid_turret
	name = "кислотная турель"
	desc = "Неподвижная железа, выплёвывающая кислоту во врагов улья."
	icon = 'modular_bandastation/xeno_rework/icons/structures/hive_fortifications.dmi'
	icon_state = "acid_turret"
	anchored = TRUE
	density = TRUE
	max_integrity = 150
	/// Processing checks a small local area only when the turret can fire.
	var/next_shot = 0

/obj/structure/alien/acid_turret/Initialize(mapload)
	. = ..()
	setDir(EAST)
	START_PROCESSING(SSobj, src)

/obj/structure/alien/acid_turret/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/alien/acid_turret/process(seconds_per_tick)
	if(world.time < next_shot)
		return
	next_shot = world.time + 2 SECONDS
	if(!(locate(/obj/structure/alien/weeds) in loc))
		return
	for(var/mob/living/carbon/human/victim in view(5, src))
		if(victim.stat == DEAD || istype(victim.get_organ_slot(ORGAN_SLOT_PARASITE_EGG), /obj/item/organ/body_egg/alien_embryo))
			continue
		setDir(get_dir(src, victim) || dir)
		var/obj/projectile/neurotoxin/banda/acid/standard/turret/shot = new(loc)
		shot.aim_projectile(victim, src, list())
		shot.firer = src
		shot.fire()
		playsound(src, 'modular_bandastation/xeno_rework/sound/alien_spitacid.ogg', 45, TRUE)
		break
