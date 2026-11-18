/** Healing is a hive purchase for all three support castes, never an innate action. */
/datum/xeno_hive/proc/can_use_pheromones(mob/living/carbon/alien/member)
	return purchased["pheromones"] && (istype(member, /mob/living/carbon/alien/adult/banda/queen) || istype(member, /mob/living/carbon/alien/adult/banda/praetorian) || istype(member, /mob/living/carbon/alien/adult/banda/carrier) || istype(member, /mob/living/carbon/alien/hivemind))

/datum/xeno_hive/proc/release_support_pheromones(mob/living/carbon/alien/member)
	for(var/mob/living/carbon/alien/ally in view(5, member))
		if(ally.stat == DEAD)
			continue
		ally.adjust_brute_loss(-5)
		ally.adjust_fire_loss(-5)
	playsound(member, 'modular_bandastation/xeno_rework/sound/alien_hiss.ogg', 50, TRUE)

/datum/action/cooldown/alien/banda/hive_pheromones
	name = "Восстановительные феромоны"
	desc = "После покупки адаптации восстанавливает союзникам в радиусе пяти клеток по 5 единиц урона от ушибов и ожогов."
	button_icon = 'modular_bandastation/xeno_rework/icons/hive_actions.dmi'
	button_icon_state = "pheromones"
	cooldown_time = 30 SECONDS
	plasma_cost = 100

/datum/action/cooldown/alien/banda/hive_pheromones/IsAvailable(feedback = FALSE)
	return GLOB.xeno_hive?.can_use_pheromones(owner) && ..()

/datum/action/cooldown/alien/banda/hive_pheromones/Activate()
	if(!IsAvailable())
		return FALSE
	GLOB.xeno_hive.release_support_pheromones(owner)
	StartCooldown()
	return TRUE

/datum/xeno_hive
	/// Each setter owns at most one rally point, indexed by the setter's ref.
	var/list/rally_points = list()

/** Invisible world anchor; only hive members enabling the HUD can locate it. */
/obj/effect/xeno_rally_point
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// Used to remove the precise entry on deletion, even if the active hive changes.
	var/datum/weakref/hive_ref
	var/datum/weakref/setter_ref
	var/setter_key

/obj/effect/xeno_rally_point/Initialize(mapload, datum/xeno_hive/hive, mob/living/carbon/alien/setter)
	. = ..()
	hive_ref = WEAKREF(hive)
	setter_ref = WEAKREF(setter)
	setter_key = REF(setter)
	RegisterSignals(setter, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH), PROC_REF(on_setter_gone))

/obj/effect/xeno_rally_point/proc/on_setter_gone()
	SIGNAL_HANDLER
	qdel(src)

/obj/effect/xeno_rally_point/Destroy()
	var/datum/xeno_hive/hive = hive_ref?.resolve()
	if(hive?.rally_points[setter_key] == src)
		hive.rally_points -= setter_key
	var/mob/living/setter = setter_ref?.resolve()
	if(setter)
		UnregisterSignal(setter, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))
	hive_ref = null
	setter_ref = null
	return ..()

/datum/action/cooldown/alien/banda/hive_rally
	name = "Точка сбора"
	desc = "Укажите видимую клетку в пределах семи клеток. Ваша точка появится в составе улья. Новая точка заменит вашу предыдущую."
	button_icon = 'modular_bandastation/xeno_rework/icons/brood_actions.dmi'
	button_icon_state = "rally"
	cooldown_time = 15 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/alien/banda/hive_rally/Activate(atom/target)
	var/turf/location = get_turf(target)
	if(!GLOB.xeno_hive?.purchased["coordination"] || !GLOB.xeno_hive.can_set_rally(owner) || !IsAvailable() || !location || !(location in view(7, owner)))
		return FALSE
	if(!GLOB.xeno_hive.set_rally_point(owner, location))
		return FALSE
	StartCooldown()
	return TRUE

/datum/xeno_hive/proc/set_rally_point(mob/living/carbon/alien/member, turf/location)
	if(!purchased["coordination"] || !can_set_rally(member) || !location || !(location in view(7, member)))
		return FALSE
	var/key = REF(member)
	var/obj/effect/xeno_rally_point/point = rally_points[key]
	if(QDELETED(point))
		point = new(location, src, member)
	else
		point.forceMove(location)
		rally_points -= key
	rally_points[key] = point
	member.alien_talk("Точка сбора: [get_area(location)], [location.x], [location.y]. Выберите точку в составе улья.")
	return TRUE

/datum/xeno_hive/proc/can_set_rally(mob/living/carbon/alien/member)
	if(QDELETED(member) || member.stat == DEAD || IS_UNCONSCIOUS(member) || member.incapacitated || member.resting)
		return FALSE
	if(istype(member, /mob/living/carbon/alien/hivemind))
		var/mob/living/carbon/alien/hivemind/hivemind = member
		return hivemind.operational()
	if(!istype(member, /mob/living/carbon/alien/adult/banda))
		return FALSE
	var/mob/living/carbon/alien/adult/banda/adult = member
	return istype(adult, /mob/living/carbon/alien/adult/banda/queen) || adult.evolution_tier == 4

/** Personal native HUD image follows the character, rather than a corner alert. */
/datum/action/cooldown/alien/banda/hive_rally_track
	name = "К месту сбора"
	desc = "Включает указатель к последней точке сбора или выключает текущее слежение. Другие цели выбираются в составе улья."
	button_icon = 'modular_bandastation/xeno_rework/icons/rally_track.dmi'
	button_icon_state = "track"

/datum/action/cooldown/alien/banda/hive_rally_track/is_action_active(atom/movable/screen/movable/action_button/current_button)
	return !!owner?.has_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)

/datum/action/cooldown/alien/banda/hive_rally_track/Activate()
	if(!GLOB.xeno_hive?.purchased["coordination"] || (!istype(owner, /mob/living/carbon/alien/adult/banda) && !istype(owner, /mob/living/carbon/alien/hivemind)) || !IsAvailable())
		return FALSE
	var/mob/living/carbon/alien/member = owner
	if(member.has_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally))
		member.remove_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
	else
		var/list/points = GLOB.xeno_hive.rally_points
		var/atom/target = length(points) ? points[points[length(points)]] : null
		if(!GLOB.xeno_hive.follow_rally_target(member, target))
			return FALSE
	build_all_button_icons()
	return TRUE

/datum/action/cooldown/alien/banda/hive_rally_track/Remove(mob/living/remove_from)
	remove_from?.remove_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
	return ..()

/datum/status_effect/agent_pinpointer/xeno_rally
	id = "xeno_rally"
	tick_interval = 1 SECONDS
	minimum_range = 0
	range_fuzz_factor = 0
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// Owned by the native personal alternate appearance, visible only to its player.
	var/image/direction_arrow

/datum/status_effect/agent_pinpointer/xeno_rally/on_apply()
	if(!is_hive_roster_member(owner) || !GLOB.xeno_hive?.purchased["coordination"])
		return FALSE
	direction_arrow = image('modular_bandastation/xeno_rework/icons/rally_pointer.dmi', owner, "arrow", ABOVE_MOB_LAYER)
	direction_arrow.color = "#bd7af0"
	direction_arrow.alpha = 0
	direction_arrow.appearance_flags |= RESET_TRANSFORM | RESET_COLOR | RESET_ALPHA
	owner.add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/one_person, "xeno_rally_direction", direction_arrow, NONE, owner)
	return TRUE

/datum/status_effect/agent_pinpointer/xeno_rally/point_to_target()
	if(!direction_arrow)
		return
	var/turf/here = get_turf(owner)
	var/turf/there = get_turf(scan_target)
	if(!here || !there || here.z != there.z || here == there)
		direction_arrow.alpha = 0
		return
	var/delta_x = there.x - here.x
	var/delta_y = there.y - here.y
	var/distance = sqrt(delta_x ** 2 + delta_y ** 2)
	direction_arrow.pixel_x = round(delta_x / distance * 26)
	direction_arrow.pixel_y = round(delta_y / distance * 26)
	direction_arrow.dir = get_dir(here, there)
	direction_arrow.alpha = 220

/// Validate before changing the personal pointer, for both HUD and roster callers.
/datum/xeno_hive/proc/follow_rally_target(mob/living/carbon/alien/member, atom/target)
	if(!purchased["coordination"] || !is_hive_roster_member(member))
		return FALSE
	if(target && (target == member || (!is_hive_roster_member(target) && !owns_rally_point(target))))
		return FALSE
	var/datum/status_effect/agent_pinpointer/xeno_rally/tracker = member.has_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
	if(tracker && tracker.scan_target == target)
		member.remove_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
	else
		tracker ||= member.apply_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
		tracker?.set_follow_target(target)
	return TRUE

/datum/xeno_hive/proc/owns_rally_point(atom/target)
	if(!istype(target, /obj/effect/xeno_rally_point) || QDELETED(target))
		return FALSE
	var/obj/effect/xeno_rally_point/point = target
	return rally_points[point.setter_key] == point

/datum/status_effect/agent_pinpointer/xeno_rally/scan_for_target()
	return

/datum/status_effect/agent_pinpointer/xeno_rally/proc/set_follow_target(atom/target)
	if(scan_target)
		UnregisterSignal(scan_target, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))
	scan_target = target
	if(target)
		RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_target_gone))
		if(isliving(target))
			RegisterSignal(target, COMSIG_LIVING_DEATH, PROC_REF(on_target_gone))
	point_to_target()

/datum/status_effect/agent_pinpointer/xeno_rally/proc/on_target_gone()
	SIGNAL_HANDLER
	set_follow_target(null)

/datum/status_effect/agent_pinpointer/xeno_rally/on_remove()
	set_follow_target(null)
	owner?.remove_alt_appearance("xeno_rally_direction")
	direction_arrow = null
	return ..()
