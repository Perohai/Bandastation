/// Living bodies shown in the roster and available as targets.
/proc/is_hive_roster_member(atom/candidate)
	if(!isliving(candidate) || QDELETED(candidate))
		return FALSE
	var/mob/living/member = candidate
	return member.stat != DEAD && (istype(member, /mob/living/carbon/alien/adult/banda) || istype(member, /mob/living/carbon/alien/hivemind) || istype(member, /mob/living/carbon/alien/larva) || istype(member, /mob/living/carbon/alien/brood))

/// Roster of the current Banda xeno hive and its navigation targets.
/datum/xeno_rework_hive_status

/datum/xeno_rework_hive_status/proc/can_view(mob/user)
	return is_hive_roster_member(user)

/datum/xeno_rework_hive_status/ui_interact(mob/user, datum/tgui/ui)
	if(!can_view(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoHiveStatus")
		ui.open()

/datum/xeno_rework_hive_status/ui_state(mob/user)
	return GLOB.always_state

/datum/xeno_rework_hive_status/ui_status(mob/user, datum/ui_state/state)
	if(!can_view(user))
		return UI_CLOSE
	return ..()

/datum/xeno_rework_hive_status/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !can_view(ui.user))
		return
	switch(action)
		if("refresh")
			return TRUE
		if("follow")
			var/datum/xeno_hive/hive = GLOB.xeno_hive
			if(!hive?.purchased["coordination"] || !istext(params["id"]))
				return FALSE
			var/atom/target = locate(params["id"]) in hive.roster_members
			if(is_hive_roster_member(target))
				return hive.follow_rally_target(ui.user, target)
			for(var/key in hive.rally_points)
				var/obj/effect/xeno_rally_point/point = hive.rally_points[key]
				if(!QDELETED(point) && REF(point) == params["id"])
					return hive.follow_rally_target(ui.user, point)
	return FALSE

/datum/xeno_rework_hive_status/ui_data(mob/user)
	var/list/members = list()
	var/datum/xeno_hive/hive = GLOB.xeno_hive
	var/can_follow = !!hive?.purchased["coordination"]
	var/datum/status_effect/agent_pinpointer/xeno_rally/tracker = user.has_status_effect(/datum/status_effect/agent_pinpointer/xeno_rally)
	for(var/mob/living/carbon/alien/xeno as anything in hive?.roster_members)
		if(xeno == user || !is_hive_roster_member(xeno))
			continue
		var/status = "В строю"
		if(!xeno.client)
			status = "Нет связи"
		else if(IS_UNCONSCIOUS(xeno))
			status = "Без сознания"
		var/caste_name = istype(xeno, /mob/living/carbon/alien/larva) ? "larva" : "Выводок"
		if(istype(xeno, /mob/living/carbon/alien/hivemind))
			caste_name = "Hivemind · T0"
		if(istype(xeno, /mob/living/carbon/alien/adult/banda))
			var/mob/living/carbon/alien/adult/banda/adult = xeno
			caste_name = adult.caste
		members += list(list(
			"id" = REF(xeno),
			"canFollow" = can_follow,
			"following" = tracker?.scan_target == xeno,
			"name" = xeno.name,
			"caste" = caste_name,
			"status" = status,
			"health" = xeno.maxHealth > 0 ? clamp(round(xeno.health / xeno.maxHealth * 100), 0, 100) : 0,
		))
	var/list/points = list()
	if(can_follow)
		for(var/key in hive.rally_points)
			var/obj/effect/xeno_rally_point/point = hive.rally_points[key]
			var/mob/living/setter = point.setter_ref?.resolve()
			var/turf/site = get_turf(point)
			if(!setter || !site)
				continue
			points += list(list(
				"id" = REF(point),
				"name" = setter.name,
				"location" = "[get_area(site)] ([site.x], [site.y])",
				"following" = tracker?.scan_target == point,
			))
	return list("members" = members, "count" = length(members) + 1, "canFollow" = can_follow, "points" = points)
