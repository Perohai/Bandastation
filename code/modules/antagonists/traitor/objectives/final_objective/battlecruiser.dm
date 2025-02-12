/datum/traitor_objective/ultimate/battlecruiser
	name = "Сообщите координаты станции ближайшему боевому крейсеру Синдиката."
	description = "Используйте специальную карту загрузки на консоли коммуникаций, чтобы отправить координаты \
		станции на ближайший крейсер. Возможно, вы захотите сообщить о своей принадлежности Синдикату \
		экипажу крейсера, когда они прибудут - их целью будет уничтожение станции."

	/// Checks whether we have sent the card to the traitor yet.
	var/sent_accesscard = FALSE
	/// Battlecruiser team that we get assigned to
	var/datum/team/battlecruiser/team

/datum/traitor_objective/ultimate/battlecruiser/generate_objective(datum/mind/generating_for, list/possible_duplicates)
	// There's no empty space to load a battlecruiser in...
	if(SSmapping.is_planetary())
		return FALSE

	return TRUE

/datum/traitor_objective/ultimate/battlecruiser/on_objective_taken(mob/user)
	. = ..()
	team = new()
	var/obj/machinery/nuclearbomb/selfdestruct/nuke = locate() in SSmachines.get_machines_by_type(/obj/machinery/nuclearbomb/selfdestruct)
	if(nuke.r_code == NUKE_CODE_UNSET)
		nuke.r_code = random_nukecode()
	team.nuke = nuke
	team.update_objectives()
	handler.owner.add_antag_datum(/datum/antagonist/battlecruiser/ally, team)


/datum/traitor_objective/ultimate/battlecruiser/generate_ui_buttons(mob/user)
	var/list/buttons = list()
	if(!sent_accesscard)
		buttons += add_ui_button("", "Нажмите, чтобы материализовать карту загрузки, которую можно использовать на консоли коммуникаций, чтобы связаться с флотом.", "phone", "card")
	return buttons

/datum/traitor_objective/ultimate/battlecruiser/ui_perform_action(mob/living/user, action)
	. = ..()
	switch(action)
		if("card")
			if(sent_accesscard)
				return
			sent_accesscard = TRUE
			var/obj/item/card/emag/battlecruiser/emag_card = new()
			emag_card.team = team
			podspawn(list(
				"target" = get_turf(user),
				"path" = /obj/structure/closet/supplypod/teleporter/syndicate, // BANDASTATION EDIT - Original: "style" = /datum/pod_style/syndicate,
				"spawn" = emag_card,
			))
