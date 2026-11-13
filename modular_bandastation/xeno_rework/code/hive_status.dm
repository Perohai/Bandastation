/// Read-only roster of the current Banda xeno hive.
/datum/xeno_rework_hive_status

/datum/xeno_rework_hive_status/ui_interact(mob/user, datum/tgui/ui)
	if(!istype(user, /mob/living/carbon/alien/adult/banda))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoHiveStatus")
		ui.open()

/datum/xeno_rework_hive_status/ui_state(mob/user)
	return GLOB.always_state

/datum/xeno_rework_hive_status/ui_status(mob/user, datum/ui_state/state)
	if(!istype(user, /mob/living/carbon/alien/adult/banda) || user.stat == DEAD)
		return UI_CLOSE
	return ..()

/datum/xeno_rework_hive_status/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !istype(ui.user, /mob/living/carbon/alien/adult/banda))
		return
	if(action == "refresh")
		return TRUE

/datum/xeno_rework_hive_status/ui_data(mob/user)
	var/list/members = list()
	for(var/mob/living/carbon/alien/adult/banda/xeno in GLOB.alive_mob_list)
		var/status = "В строю"
		if(!xeno.client)
			status = "Нет связи"
		else if(IS_UNCONSCIOUS(xeno))
			status = "Без сознания"
		var/caste_name = xeno.caste
		members += list(list(
			"name" = xeno.name,
			"caste" = caste_name,
			"status" = status,
			"health" = xeno.maxHealth > 0 ? clamp(round(xeno.health / xeno.maxHealth * 100), 0, 100) : 0,
		))
	return list("members" = members, "count" = length(members))

/mob/living/carbon/alien/adult/banda/verb/hive_status()
	set name = "Состав улья"
	set category = "Alien"
	if(!hive_status_panel)
		hive_status_panel = new
	hive_status_panel.ui_interact(src)
