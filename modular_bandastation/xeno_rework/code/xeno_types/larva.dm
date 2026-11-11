/datum/action/cooldown/alien/larva_evolve/Activate(atom/target)
	if(!IsAvailable())
		return FALSE
	var/static/list/caste_options = list(
		"Runner" = /mob/living/carbon/alien/adult/banda/runner,
		"Spitter" = /mob/living/carbon/alien/adult/banda/spitter,
		"Defender" = /mob/living/carbon/alien/adult/banda/defender,
		"Drone" = /mob/living/carbon/alien/adult/banda/drone,
	)
	var/list/choices = list()
	for(var/caste_name in caste_options)
		var/mob/caste_type = caste_options[caste_name]
		var/datum/radial_menu_choice/choice = new()
		choice.name = caste_name
		choice.image = image(icon = initial(caste_type.icon), icon_state = initial(caste_type.icon_state))
		choice.info = initial(caste_type.desc)
		choices[caste_name] = choice
	var/alien_caste = show_radial_menu(owner, owner, choices, radius = 38, require_near = TRUE, tooltips = TRUE)
	if(QDELETED(src) || QDELETED(owner) || !IsAvailable() || !(alien_caste in caste_options))
		return FALSE
	var/mob/living/carbon/alien/larva/larva = owner
	var/caste_type = caste_options[alien_caste]
	var/mob/living/carbon/alien/adult/banda/new_xeno = new caste_type(larva.loc)
	new_xeno.has_just_evolved()
	larva.alien_evolve(new_xeno)
	return TRUE
