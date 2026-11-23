/datum/action/cooldown/alien/banda/dig_tunnel
	name = "Вырыть вход в тоннель"
	desc = "Укажите траву рядом с собой. Первый вход стоит 200 плазмы. Второй вход соединяет пару и запускает перезарядку на 120 секунд."
	button_icon = 'icons/mob/actions/actions_xeno.dmi'
	button_icon_state = "alien_resin"
	click_to_activate = TRUE
	unset_after_click = FALSE
	cooldown_time = 120 SECONDS
	/// Only the unpaired entrance belongs to the builder's action.
	var/datum/weakref/pending_entrance
	var/digging = FALSE

/datum/action/cooldown/alien/banda/dig_tunnel/IsAvailable(feedback = FALSE)
	return !!GLOB.xeno_hive?.purchased["tunnels"] && istype(owner, /mob/living/carbon/alien/adult/banda/drone) && ..()

/datum/action/cooldown/alien/banda/dig_tunnel/proc/can_dig(turf/site)
	return !QDELETED(owner) && isopenturf(site) && is_station_level(site.z) && !isspaceturf(site) && !istype(get_area(site), /area/shuttle) && isturf(owner.loc) && site.z == owner.z && (site in view(1, owner)) && (locate(/obj/structure/alien/weeds) in site) && !(locate(/obj/structure/alien/hive_tunnel) in site) && !site.is_blocked_turf(exclude_mobs = TRUE)

/datum/action/cooldown/alien/banda/dig_tunnel/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/drone/drone = owner
	var/turf/site = get_turf(target)
	if(digging || !IsAvailable() || !can_dig(site))
		return FALSE
	var/obj/structure/alien/hive_tunnel/first = pending_entrance?.resolve()
	if(first && first.z != site.z)
		drone.balloon_alert(drone, "Входы должны быть на одном уровне")
		return FALSE
	if(!first && drone.getPlasma() < 200)
		drone.balloon_alert(drone, "Нужно 200 плазмы")
		return FALSE
	digging = TRUE
	var/turf/origin = drone.loc
	var/ready = do_after(drone, 3 SECONDS, target = site)
	digging = FALSE
	if(!ready || QDELETED(src) || QDELETED(drone) || owner != drone || drone.loc != origin || !IsAvailable() || !can_dig(site))
		return FALSE
	if(first)
		if(QDELETED(first) || pending_entrance?.resolve() != first || first.z != site.z || !first.is_open_entrance())
			return FALSE
	else if(drone.getPlasma() < 200)
		return FALSE
	var/obj/structure/alien/hive_tunnel/entrance = new(site)
	if(!first)
		drone.adjustPlasma(-200)
		pending_entrance = WEAKREF(entrance)
		drone.balloon_alert(drone, "Готов первый вход")
		return TRUE
	first.other_end = entrance
	entrance.other_end = first
	pending_entrance = null
	StartCooldown()
	drone.balloon_alert(drone, "Тоннель соединён")
	return TRUE

/datum/action/cooldown/alien/banda/dig_tunnel/Remove(mob/living/remove_from)
	var/obj/structure/alien/hive_tunnel/unfinished = pending_entrance?.resolve()
	pending_entrance = null
	qdel(unfinished)
	return ..()

/obj/structure/alien/hive_tunnel
	name = "смоляной тоннель"
	desc = "Вход в проход под полом. Сварка может разрушить его."
	icon = 'icons/obj/fluff/general.dmi'
	icon_state = "gelmound"
	color = "#675482"
	anchored = TRUE
	layer = LOW_OBJ_LAYER
	max_integrity = 140
	var/obj/structure/alien/hive_tunnel/other_end

/obj/structure/alien/hive_tunnel/Destroy()
	var/obj/structure/alien/hive_tunnel/partner = other_end
	other_end = null
	if(!QDELETED(partner) && partner.other_end == src)
		partner.other_end = null
		qdel(partner)
	return ..()

/obj/structure/alien/hive_tunnel/proc/is_open_entrance()
	return !QDELETED(src) && isopenturf(loc) && is_station_level(z) && !isspaceturf(loc) && !istype(get_area(src), /area/shuttle) && (locate(/obj/structure/alien/weeds) in loc)

/obj/structure/alien/hive_tunnel/attack_larva(mob/user, list/modifiers)
	var/mob/living/carbon/alien/larva/larva = user
	if(!istype(larva) || larva.combat_mode)
		return ..()
	return attack_alien(larva, modifiers)

/obj/structure/alien/hive_tunnel/attack_alien(mob/living/carbon/alien/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	if(!user.get_organ_slot(ORGAN_SLOT_XENO_HIVENODE) || user.incapacitated || user.buckled || LAZYACCESS(modifiers, RIGHT_CLICK) || !isturf(user.loc) || !user.Adjacent(src) || !is_open_entrance())
		return
	var/obj/structure/alien/hive_tunnel/destination = other_end
	if(QDELETED(destination) || destination.other_end != src || !destination.is_open_entrance() || destination.z != z)
		balloon_alert(user, "Проход недоступен")
		return
	var/turf/origin = user.loc
	if(!do_after(user, 2 SECONDS, target = src))
		return
	if(QDELETED(src) || QDELETED(user) || user.combat_mode || user.incapacitated || user.buckled || !user.get_organ_slot(ORGAN_SLOT_XENO_HIVENODE) || user.loc != origin || !user.Adjacent(src) || !is_open_entrance() || QDELETED(destination) || other_end != destination || destination.other_end != src || !destination.is_open_entrance() || destination.z != z)
		return
	var/turf/exit_turf = destination.loc
	if(exit_turf.is_blocked_turf(exclude_mobs = TRUE))
		balloon_alert(user, "Выход загорожен")
		return
	user.forceMove(exit_turf)
	return TRUE

/obj/structure/alien/hive_tunnel/welder_act(mob/living/user, obj/item/tool)
	return sear_xeno_structure(src, user, tool, 35)
