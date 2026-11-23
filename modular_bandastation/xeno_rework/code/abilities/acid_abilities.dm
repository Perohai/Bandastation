/** Выплёвывает нейротоксин. Режим кислоты наносит ожоговый урон. */
/datum/action/cooldown/alien/banda/spit
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "neuro_spit"
	name = "Плевок"
	desc = "Выплёвывает сгусток нейротоксина. Переключившись на кислоту, можно обжигать противников."
	plasma_cost = 40
	click_to_activate = TRUE
	unset_after_click = FALSE
	/// Whether spit uses acid instead of neurotoxin.
	var/acid_mode = FALSE
	/// Projectile subtype selected when acid mode is active.
	var/acid_projectile = /obj/projectile/neurotoxin/banda/acid/standard
	/// Prices belong to the gland, so toggling never restores another caste's price.
	var/neuro_plasma_cost = 40
	/// Acid-mode price for this gland.
	var/acid_plasma_cost = 100

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

/datum/action/cooldown/alien/banda/spit/spitter
	acid_projectile = /obj/projectile/neurotoxin/banda/acid/standard/spitter
	plasma_cost = 20
	neuro_plasma_cost = 20
	acid_plasma_cost = 40

/** Praetorian spit selects its caste-specific acid projectile. */
/datum/action/cooldown/alien/banda/spit/praetorian
	acid_projectile = /obj/projectile/neurotoxin/banda/acid/standard/praetorian

/** Stamina-damaging neurotoxin without the upstream paralysis payload. */
/obj/projectile/neurotoxin/banda
	name = "neurotoxin spit"
	damage = 30
	paralyze = 0
	damage_type = STAMINA
	armor_flag = BIO

/** Burn-damaging acid projectile family. */
/obj/projectile/neurotoxin/banda/acid
	name = "acid spit"
	icon_state = "toxin"
	damage_type = BURN

/** Standard direct acid spit. */
/obj/projectile/neurotoxin/banda/acid/standard
	damage = 15

/obj/projectile/neurotoxin/banda/acid/standard/turret
	damage = 10

/** Caste-specific direct acid damage. */
/obj/projectile/neurotoxin/banda/acid/standard/praetorian
	damage = 14

/obj/projectile/neurotoxin/banda/acid/standard/spitter
	damage = 12

/** Переключает нейротоксин и кислоту. Текущая цена указана на кнопке плевка. */
/datum/action/cooldown/alien/banda/toggle_spit
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "toggle_spit"
	name = "Сменить тип плевка"
	desc = "Переключает плевок с нейротоксина на кислоту и обратно. Стоимость указана на кнопке способности."

/datum/action/cooldown/alien/banda/toggle_spit/Activate()
	var/datum/action/cooldown/alien/banda/spit/spit = locate() in owner.actions
	if(!spit)
		return FALSE
	spit.acid_mode = !spit.acid_mode
	spit.plasma_cost = spit.acid_mode ? spit.acid_plasma_cost : spit.neuro_plasma_cost
	spit.button_icon_state = spit.acid_mode ? "acid_spit" : "neuro_spit"
	spit.name = "[spit.acid_mode ? "Плевок кислотой" : "Нейротоксин"] ([spit.plasma_cost]P)"
	spit.build_all_button_icons(UPDATE_BUTTON_STATUS)
	return TRUE

/** После короткой подготовки выпускает три кислотных снаряда, оставляющих лужи на две секунды. */
/datum/action/cooldown/alien/banda/acid_volley
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "acid_volley"
	name = "Залп кислотой"
	desc = "После короткой подготовки выпускает три сгустка кислоты. На месте попадания каждого остаётся лужа, исчезающая через две секунды."
	plasma_cost = 100
	cooldown_time = 15 SECONDS
	click_to_activate = TRUE
	/// Guards overlapping channelled activations.
	var/preparing = FALSE

/datum/action/cooldown/alien/banda/acid_volley/Activate(atom/target)
	var/turf/location = get_turf(target)
	if(preparing || !isturf(owner.loc) || !location || owner.z != location.z || get_dist(owner, location) > 7)
		return FALSE
	preparing = TRUE
	playsound(owner, 'sound/effects/bubbles/bubbles.ogg', 40, TRUE)
	var/ready = do_after(owner, 0.5 SECONDS, target = location)
	preparing = FALSE
	if(!ready || QDELETED(src) || QDELETED(owner) || !IsAvailable() || !isturf(owner.loc) || owner.z != location.z || get_dist(owner, location) > 7)
		return FALSE
	var/obj/item/ammo_casing/xeno_acid_volley/casing = new(owner.loc)
	casing.fire_casing(location, owner, null, null, null, BODY_ZONE_CHEST, 0, owner)
	qdel(casing)
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_spitacid.ogg', 75, TRUE)
	owner.do_attack_animation(location)
	StartCooldown()
	return TRUE

/** Three-projectile casing used by the scattered acid volley. */
/obj/item/ammo_casing/xeno_acid_volley
	projectile_type = /obj/projectile/neurotoxin/banda/acid/pool
	pellets = 3
	variance = 8

/** Acid projectile which leaves a short-lived pool on impact or expiry. */
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

#define ACID_SPRAY_STEP (0.1 SECONDS)

/** Выпускает быструю волну кислоты, сбивая врагов с ног и гася огонь на союзниках. */
/datum/action/cooldown/alien/banda/acid_spray
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "acid_line"
	name = "Струя кислоты"
	desc = "Выпускает волну кислоты на расстояние до трёх клеток в сторону курсора. Сбивает врагов с ног и тушит горящих союзников."
	plasma_cost = 300
	cooldown_time = 40 SECONDS
	click_to_activate = TRUE
	/// Maximum length of the line or straight cone.
	var/spray_length = 3

/datum/action/cooldown/alien/banda/acid_spray/Activate(atom/target)
	var/turf/origin = owner?.loc
	var/turf/target_turf = get_turf(target)
	if(!isturf(origin) || !target_turf || origin.z != target_turf.z || target_turf == origin || !IsAvailable())
		return FALSE
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_spitacid2.ogg', 75, TRUE)
	owner.do_attack_animation(target_turf)
	StartCooldown()
	release_spray(origin, target_turf)
	return TRUE

/// The released spray starts at the cast position even if the caster moves.
/datum/action/cooldown/alien/banda/acid_spray/proc/release_spray(turf/origin, turf/target_turf)
	set waitfor = FALSE
	var/list/line = get_line(origin, target_turf)
	var/distance = min(spray_length, length(line) - 1)
	var/list/shield_results = list()
	for(var/step in 1 to distance)
		var/turf/location = line[step + 1]
		if(QDELETED(src) || !can_cover(location))
			break
		new /obj/effect/xeno_acid_pool/spray(location, shield_results)
		if(step < distance)
			sleep(ACID_SPRAY_STEP)

/// Walls and dense objects stop the part of the wave that reaches them.
/datum/action/cooldown/alien/banda/acid_spray/proc/can_cover(turf/location)
	if(!location || isclosedturf(location))
		return FALSE
	for(var/obj/blocker in location)
		if(blocker.density)
			return FALSE
	return TRUE

/datum/action/cooldown/alien/banda/acid_spray/spitter
	plasma_cost = 120
	cooldown_time = 30 SECONDS

/datum/action/cooldown/alien/banda/acid_spray/cone
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "acid_cone"
	desc = "Выплёвывает волну кислоты конусом 1–3–5 клеток в сторону курсора. Кислота разъедает полевые баррикады."
	plasma_cost = 220
	cooldown_time = 45 SECONDS
	spray_length = 3

/datum/action/cooldown/alien/banda/acid_spray/cone/release_spray(turf/origin, turf/target_turf)
	set waitfor = FALSE
	var/facing = angle2dir(delta_to_angle(target_turf.x - origin.x, target_turf.y - origin.y))
	owner.setDir(facing)
	var/turf/center = origin
	var/wing_angle = ISDIAGONALDIR(facing) ? 135 : 90
	var/list/previous_row = list(center)
	var/list/shield_results = list()
	for(var/row in 1 to spray_length)
		if(QDELETED(src))
			break
		center = get_step(center, facing)
		if(!center)
			break
		var/list/hit_row = list()
		for(var/offset in (1 - row) to (row - 1))
			var/turf/location = get_ranged_target_turf(center, turn(facing, offset < 0 ? -wing_angle : wing_angle), abs(offset))
			if(!location || (offset && get_dist(center, location) != abs(offset)))
				continue
			for(var/turf/previous as anything in previous_row)
				if(get_dist(previous, location) != 1)
					continue
				for(var/obj/structure/railing/folding/barrier in location)
					barrier.acid_act(50, 20)
				if(can_cover(location))
					hit_row += location
					new /obj/effect/xeno_acid_pool/spray(location, shield_results)
				break
		if(!length(hit_row) || row == spray_length)
			break
		previous_row = hit_row
		sleep(ACID_SPRAY_STEP)

#undef ACID_SPRAY_STEP

/** Timed acid pool with location exposure and frame-independent damage. */
/obj/effect/xeno_acid_pool
	name = "xenomorph acid"
	icon = 'modular_bandastation/xeno_rework/icons/effects/xeno_effects.dmi'
	icon_state = "acid_pool"
	color = "#899364"
	alpha = 145
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// Lifetime before this temporary effect is deleted.
	var/lifetime = 2 SECONDS
	/// Knockdown duration applied to hostile entrants.
	var/knockdown_time = 0
	/// Location signals routed by the connect_loc element.
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

/** Apply the pool to a living entrant without sleeping in the location signal. */
/obj/effect/xeno_acid_pool/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(isliving(arrived))
		affect(arrived, 0)

/** Apply this pool effect using elapsed seconds rather than processing frequency. */
/obj/effect/xeno_acid_pool/proc/affect(mob/living/victim, seconds_per_tick)
	if(isalien(victim))
		victim.extinguish_mob()
		return
	victim.apply_damage(5 * seconds_per_tick, BURN, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, BIO), wound_bonus = CANT_WOUND)
	if(knockdown_time)
		victim.Knockdown(knockdown_time)

/** Persistent spray pool which repeatedly knocks down exposed enemies. */
/obj/effect/xeno_acid_pool/spray
	lifetime = 5 SECONDS
	knockdown_time = 0.5 SECONDS

	/// Pools in one wave share the result. String refs avoid keeping victims alive.
	var/list/shield_results

/obj/effect/xeno_acid_pool/spray/Initialize(mapload, list/wave_results)
	shield_results = islist(wave_results) ? wave_results : list()
	return ..()

/obj/effect/xeno_acid_pool/spray/Destroy()
	shield_results = null
	return ..()

/obj/effect/xeno_acid_pool/spray/affect(mob/living/victim, seconds_per_tick)
	if(ishuman(victim))
		var/key = REF(victim)
		if(!(key in shield_results))
			var/mob/living/carbon/human/human = victim
			shield_results[key] = human.deflect_xeno_attack(src, "кислотную волну")
		if(shield_results[key])
			return
	return ..()
