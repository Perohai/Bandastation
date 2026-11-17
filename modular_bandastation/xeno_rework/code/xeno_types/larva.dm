/** Interruptible larval evolution into the server-validated caste allowlist. */
/datum/action/cooldown/alien/larva_evolve
	/// Prevents overlapping evolution preparations after radial menus resolve.
	var/evolving = FALSE
	/// Time spent shedding the larval body before becoming an adult.
	var/evolution_time = 5 SECONDS
	/// The first castes available to a fully grown larva.
	var/static/list/caste_options = list(
		"Runner" = /mob/living/carbon/alien/adult/banda/runner,
		"Sentinel" = /mob/living/carbon/alien/adult/banda/sentinel,
		"Defender" = /mob/living/carbon/alien/adult/banda/defender,
		"Drone" = /mob/living/carbon/alien/adult/banda/drone,
	)

/datum/action/cooldown/alien/larva_evolve/Activate(atom/target)
	if(evolving || !IsAvailable())
		return FALSE
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
	return evolve_into(alien_caste)

/** Prepares a selected caste, cancelling on movement, lost ownership or incapacitation. */
/datum/action/cooldown/alien/larva_evolve/proc/evolve_into(caste_name)
	if(evolving || !IsAvailable() || !(caste_name in caste_options) || !isturf(owner.loc))
		return FALSE
	var/mob/living/carbon/alien/larva/larva = owner
	var/turf/start = larva.loc
	evolving = TRUE
	larva.visible_message(span_notice("[larva] начинает сбрасывать личиночную оболочку."))
	larva.start_hive_evolution_visual()
	var/ready = do_after(larva, evolution_time, target = larva)
	if(!QDELETED(larva))
		larva.remove_filter("xeno_evolution")
	if(QDELETED(src))
		return FALSE
	evolving = FALSE
	if(!ready || QDELETED(larva) || owner != larva || !IsAvailable() || larva.loc != start)
		return FALSE
	var/caste_type = caste_options[caste_name]
	var/mob/living/carbon/alien/adult/banda/new_xeno = new caste_type(larva.loc)
	playsound(new_xeno, 'sound/mobs/non-humanoids/alien/alien_explode.ogg', 60, TRUE)
	new_xeno.has_just_evolved()
	larva.alien_evolve(new_xeno)
	return TRUE

/datum/action/cooldown/alien/larva_evolve/Remove(mob/living/remove_from)
	remove_from?.remove_filter("xeno_evolution")
	return ..()

/** One shedding visual for larval and adult evolution. */
/mob/living/carbon/alien/proc/start_hive_evolution_visual()
	playsound(src, 'sound/mobs/non-humanoids/alien/alien_organ_cut.ogg', 50, TRUE)
	add_filter("xeno_evolution", 2, drop_shadow_filter(size = 2, color = "#b070e8"))
	transition_filter_chain("xeno_evolution", INDEFINITE,
		filter_chain_step(list("size" = 5), 0.5 SECONDS, SINE_EASING),
		filter_chain_step(list("size" = 2), 0.5 SECONDS, SINE_EASING))
