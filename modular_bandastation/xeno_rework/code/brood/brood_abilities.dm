/datum/action/cooldown/alien/brood_charge
	name = "Таран жука"
	desc = "Рывок на четыре клетки без точного прицеливания. При попадании наносит 15 урона и сбивает цель с ног на секунду."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "beetle_charge"
	plasma_cost = 80
	cooldown_time = 30 SECONDS
	click_to_activate = TRUE
	/// TGMC minion windup, serialized before yielding.
	var/preparing = FALSE
	/// Both the warning marker and the channel use this duration.
	var/windup_time = 0.5 SECONDS

/datum/action/cooldown/alien/brood_charge/proc/can_charge(turf/destination)
	return !QDELETED(src) && istype(owner, /mob/living/carbon/alien/brood) && owner.type == /mob/living/carbon/alien/brood && !QDELETED(destination) && isturf(owner.loc) && destination.z == owner.z && GLOB.xeno_hive?.purchased["beetle_charge"] && !HAS_TRAIT(owner, TRAIT_PACIFISM) && IsAvailable()

/datum/action/cooldown/alien/brood_charge/Activate(atom/target)
	var/mob/living/carbon/alien/brood/beetle = owner
	var/turf/destination = get_turf(target)
	if(preparing || !can_charge(destination) || beetle.charging)
		return FALSE
	preparing = TRUE
	beetle.setDir(get_dir(beetle, destination))
	var/obj/effect/temp_visual/warning = new /obj/effect/temp_visual/telegraphing/exclamation(get_turf(beetle), windup_time)
	warning.pixel_y = 20
	warning.layer = ABOVE_ALL_MOB_LAYER
	warning.plane = ABOVE_GAME_PLANE
	beetle.visible_message(span_warning("[beetle] прижимается к полу, готовясь к тарану!"))
	playsound(beetle, 'modular_bandastation/xeno_rework/sound/alien_hiss.ogg', 55, TRUE)
	var/ready = do_after(beetle, windup_time, target = beetle, extra_checks = CALLBACK(src, PROC_REF(can_charge), destination))
	qdel(warning)
	if(QDELETED(src))
		return FALSE
	preparing = FALSE
	if(!ready || QDELETED(beetle) || owner != beetle || !can_charge(destination))
		return FALSE
	beetle.charging = TRUE
	new /obj/effect/temp_visual/decoy/fading/halfsecond(beetle.loc, beetle)
	beetle.add_filter("minion_charge", 2, motion_blur_filter(clamp(destination.x - beetle.x, -1, 1) * 2, clamp(destination.y - beetle.y, -1, 1) * 2))
	// Native throwing ignores intermediate mobs with PASSMOB; the beetle aims at a turf.
	beetle.charge_had_pass_mob = beetle.pass_flags & PASSMOB
	beetle.pass_flags &= ~PASSMOB
	if(!beetle.throw_at(destination, 4, 1, beetle, spin = FALSE, callback = CALLBACK(beetle, TYPE_PROC_REF(/mob/living/carbon/alien/brood, end_minion_charge))))
		beetle.end_minion_charge()
		return FALSE
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/brood_ravage
	name = "Взмах серпами"
	desc = "Взмахом серпов поражает цели по дуге шириной три клетки перед собой. Каждая получает 12 урона."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "scissor_cut"
	plasma_cost = 200
	cooldown_time = 30 SECONDS
	click_to_activate = TRUE
	/// Slow Ravage gives the target half a second to escape.
	var/preparing = FALSE
	/// Exposed for focused cancellation and hit-area tests.
	var/windup_time = 0.5 SECONDS

/datum/action/cooldown/alien/brood_ravage/proc/can_ravage(atom/target)
	return !QDELETED(src) && istype(owner, /mob/living/carbon/alien/brood/mantis) && !QDELETED(target) && GLOB.xeno_hive?.purchased["mantis_ravage"] && owner.Adjacent(target) && target != owner && !HAS_TRAIT(owner, TRAIT_PACIFISM) && IsAvailable()

/datum/action/cooldown/alien/brood_ravage/Activate(atom/target)
	if(preparing || !can_ravage(target))
		return FALSE
	var/mob/living/carbon/alien/brood/mantis/mantis = owner
	preparing = TRUE
	owner.setDir(get_dir(owner, target))
	owner.visible_message(span_warning("[owner] заносит серповидные когти для широкого удара!"))
	var/ready = do_after(owner, windup_time, target = owner, extra_checks = CALLBACK(src, PROC_REF(can_ravage), target))
	if(QDELETED(src))
		return FALSE
	preparing = FALSE
	if(!ready || QDELETED(mantis) || owner != mantis || !can_ravage(target))
		return FALSE
	var/direction = get_dir(owner, target)
	owner.setDir(direction)
	var/list/arc = list(direction, turn(direction, 45), turn(direction, -45))
	for(var/arc_direction in arc)
		var/turf/location = get_step(owner, arc_direction)
		if(!location)
			continue
		var/obj/effect/temp_visual/slash = new /obj/effect/temp_visual/cleave(location)
		slash.setDir(arc_direction)
	owner.do_attack_animation(target, ATTACK_EFFECT_CLAW)
	playsound(owner, 'sound/items/weapons/slice.ogg', 65, TRUE)
	owner.visible_message(span_danger("[owner] с размаху рассекает воздух серповидными когтями!"))
	for(var/mob/living/victim in view(1, owner))
		if(isalien(victim) || !(get_dir(owner, victim) in arc))
			continue
		victim.apply_damage(12, BRUTE, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, MELEE))
		step_away(victim, owner)
		log_combat(owner, victim, "minion ravaged")
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/brood_spit
	name = "Плевок кислотой"
	desc = "Плевок кислотой на расстояние до семи клеток: наносит 5 ожогового урона, после улучшения — 10."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "neuro_spit"
	plasma_cost = 75
	cooldown_time = 1.8 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/alien/brood_spit/Activate(atom/target)
	if(!istype(owner, /mob/living/carbon/alien/brood/scorpion) || !target || !(target in view(7, owner)) || !isturf(owner.loc) || HAS_TRAIT(owner, TRAIT_PACIFISM))
		return FALSE
	var/obj/projectile/neurotoxin/banda/acid/standard/praetorian/projectile = new(owner.loc)
	projectile.damage = GLOB.xeno_hive?.purchased["scorpion_spit"] ? 10 : 5
	projectile.aim_projectile(target, owner, list())
	projectile.firer = owner
	projectile.fire()
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_spitacid.ogg', 60, TRUE)
	StartCooldown()
	return TRUE

/** The slot cooldown is shared by the hive; this one life can detonate only once. */
/datum/action/cooldown/alien/brood_detonate
	name = "Самоподрыв"
	desc = "Банелинг замирает на 1,5 секунды, мигает и рычит, предупреждая окружающих. Затем взрывается, разбрызгивая кислоту в радиусе трёх клеток, и погибает. Если банелинга убьют во время подготовки, взрыва не будет."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "emp"
	/// The live fuse cannot be restarted or extended by repeated clicks.
	var/primed = FALSE
	/// Adjustable warning interval.
	var/fuse_time = 1.5 SECONDS
	/// Absolute deadline is independent of movement, stuns and warning frequency.
	var/detonate_at = 0
	/// Cancelled when this action or its owner leaves play.
	var/explosion_timer
	/// Only one warning callback is pending at any moment.
	var/warning_timer

/datum/action/cooldown/alien/brood_detonate/proc/can_detonate()
	var/mob/living/living_owner = owner
	return !QDELETED(src) && istype(owner, /mob/living/carbon/alien/brood/baneling) && owner.stat != DEAD && !owner.incapacitated && !living_owner.resting && isturf(owner.loc) && !HAS_TRAIT(owner, TRAIT_PACIFISM) && GLOB.xeno_hive?.purchased["brood_baneling"]

/datum/action/cooldown/alien/brood_detonate/Activate()
	if(primed || !can_detonate())
		return FALSE
	primed = TRUE
	var/mob/living/carbon/alien/brood/baneling/baneling = owner
	baneling.visible_message(span_userdanger("[baneling] замирает и угрожающе раздувается — сейчас рванёт!"), span_userdanger("Вы замираете. Кислотные мешки разорвутся через 1,5 секунды!"))
	ADD_TRAIT(baneling, TRAIT_IMMOBILIZED, REF(src))
	detonate_at = world.time + fuse_time
	RegisterSignal(baneling, COMSIG_LIVING_DEATH, PROC_REF(on_baneling_death))
	baneling.add_filter("baneling_pulse", 2, color_matrix_filter(COLOR_WHITE))
	baneling.transition_filter_chain("baneling_pulse", INDEFINITE,
		filter_chain_step(color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.4, 0, 0)), 0.15 SECONDS),
		filter_chain_step(color_matrix_filter(COLOR_WHITE), 0.15 SECONDS))
	explosion_timer = addtimer(CALLBACK(src, PROC_REF(detonate)), fuse_time, TIMER_STOPPABLE)
	warn_detonation()
	return TRUE

/** Once armed, only death/removal or loss of a valid world position cancels the fuse. */
/datum/action/cooldown/alien/brood_detonate/proc/armed_and_alive()
	return primed && !QDELETED(src) && !QDELETED(owner) && istype(owner, /mob/living/carbon/alien/brood/baneling) && owner.stat != DEAD && get_turf(owner) && !HAS_TRAIT(owner, TRAIT_PACIFISM) && GLOB.xeno_hive?.purchased["brood_baneling"]

/datum/action/cooldown/alien/brood_detonate/proc/warn_detonation()
	warning_timer = null
	if(!armed_and_alive())
		clear_fuse(owner)
		return
	var/remaining = max(0, detonate_at - world.time)
	playsound(owner, remaining <= 1 SECONDS ? 'sound/effects/fuse.ogg' : 'modular_bandastation/xeno_rework/sound/alien_hiss.ogg', 90, TRUE)
	if(remaining > 1 SECONDS)
		warning_timer = addtimer(CALLBACK(src, PROC_REF(warn_detonation)), min(2 SECONDS, remaining - 1 SECONDS), TIMER_STOPPABLE)

/datum/action/cooldown/alien/brood_detonate/proc/on_baneling_death()
	SIGNAL_HANDLER
	clear_fuse(owner)

/datum/action/cooldown/alien/brood_detonate/proc/detonate()
	explosion_timer = null
	if(!armed_and_alive())
		clear_fuse(owner)
		return FALSE
	var/mob/living/carbon/alien/brood/baneling/baneling = owner
	clear_fuse(baneling)
	var/turf/impact = get_turf(baneling)
	new /obj/effect/temp_visual/explosion/fast(impact)
	playsound(impact, 'sound/effects/explosion/explosion1.ogg', 90, TRUE)
	for(var/mob/living/victim in view(3, impact))
		if(isalien(victim))
			continue
		var/damage = max(25, 100 - get_dist(impact, victim) * 25)
		victim.apply_damage(damage, BURN, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, ACID))
		log_combat(baneling, victim, "baneling acid burst")
	for(var/obj/structure/structure in range(1, impact))
		structure.take_damage(60, BURN, ACID)
	baneling.gib()
	return TRUE

/datum/action/cooldown/alien/brood_detonate/proc/clear_fuse(mob/living/baneling)
	deltimer(explosion_timer)
	deltimer(warning_timer)
	explosion_timer = null
	warning_timer = null
	primed = FALSE
	if(QDELETED(baneling))
		return
	UnregisterSignal(baneling, COMSIG_LIVING_DEATH)
	baneling.remove_filter("baneling_pulse")
	REMOVE_TRAIT(baneling, TRAIT_IMMOBILIZED, REF(src))

/datum/action/cooldown/alien/brood_detonate/Remove(mob/living/remove_from)
	clear_fuse(remove_from)
	return ..()

/datum/status_effect/xeno_evade_miss
	id = "xeno_evade_miss"
	duration = 1.5 SECONDS
	alert_type = null
	on_remove_on_mob_delete = TRUE

/datum/status_effect/xeno_evade_miss/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/xeno_evade_miss)
	return TRUE

/datum/status_effect/xeno_evade_miss/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/xeno_evade_miss)

/datum/movespeed_modifier/xeno_evade_miss
	multiplicative_slowdown = 2
