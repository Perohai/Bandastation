/// Read-only roster of the current Banda xeno hive.
/datum/xeno_rework_hive_status

/datum/xeno_rework_hive_status/proc/can_view(mob/user)
	return !QDELETED(user) && user.stat != DEAD && (istype(user, /mob/living/carbon/alien/adult/banda) || istype(user, /mob/living/carbon/alien/hivemind))

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
	if(action == "refresh")
		return TRUE

/datum/xeno_rework_hive_status/ui_data(mob/user)
	var/list/members = list()
	for(var/mob/living/carbon/alien/xeno in GLOB.alive_mob_list)
		if(!istype(xeno, /mob/living/carbon/alien/adult/banda) && !istype(xeno, /mob/living/carbon/alien/hivemind))
			continue
		var/status = "В строю"
		if(!xeno.client)
			status = "Нет связи"
		else if(IS_UNCONSCIOUS(xeno))
			status = "Без сознания"
		var/caste_name = "Hivemind · T0"
		if(istype(xeno, /mob/living/carbon/alien/adult/banda))
			var/mob/living/carbon/alien/adult/banda/adult = xeno
			caste_name = adult.caste
		members += list(list(
			"name" = xeno.name,
			"caste" = caste_name,
			"status" = status,
			"health" = xeno.maxHealth > 0 ? clamp(round(xeno.health / xeno.maxHealth * 100), 0, 100) : 0,
		))
	return list("members" = members, "count" = length(members))
