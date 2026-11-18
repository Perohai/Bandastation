/** Rest locks voluntary movement until the mob has actually finished standing up. */
/mob/living/carbon/alien/proc/on_hive_rest(datum/source, is_resting)
	SIGNAL_HANDLER
	if(is_resting)
		ADD_TRAIT(src, TRAIT_IMMOBILIZED, "xeno_rest")
	else if(body_position == STANDING_UP)
		REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, "xeno_rest")

/mob/living/carbon/alien/proc/on_hive_stand(datum/source, new_position)
	SIGNAL_HANDLER
	if(new_position == STANDING_UP && !resting)
		REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, "xeno_rest")

/datum/action/cooldown/alien/hive_roster
	name = "Состав улья"
	desc = "Показывает всех живых взрослых ксеноморфов и их текущее состояние."
	button_icon = 'modular_bandastation/xeno_rework/icons/hive_actions.dmi'
	button_icon_state = "roster"

/datum/action/cooldown/alien/hive_roster/Activate()
	if(istype(owner, /mob/living/carbon/alien/hivemind))
		var/mob/living/carbon/alien/hivemind/hivemind = owner
		if(!hivemind.operational())
			return FALSE
		if(!hivemind.hive_status_panel)
			hivemind.hive_status_panel = new
		hivemind.hive_status_panel.ui_interact(hivemind)
		return TRUE
	var/mob/living/carbon/alien/adult/banda/xeno = owner
	if(!istype(xeno))
		return FALSE
	if(!xeno.hive_status_panel)
		xeno.hive_status_panel = new
	xeno.hive_status_panel.ui_interact(xeno)
	return TRUE

/datum/action/cooldown/alien/hive_development
	name = "Развитие улья"
	desc = "Открывает дерево адаптаций и экономику улья."
	button_icon = 'modular_bandastation/xeno_rework/icons/hive_actions.dmi'
	button_icon_state = "development"

/datum/action/cooldown/alien/hive_development/Activate()
	var/datum/xeno_hive/hive = get_xeno_hive()
	if(!hive.can_manage(owner))
		return FALSE
	hive.ui_interact(owner)
	return TRUE

/** The same stomach transport as before, with a channel instead of grab combinations. */
/datum/action/cooldown/alien/hive_swallow
	name = "Проглотить"
	desc = "Заглатывает стоящую рядом живую жертву за 13,5 секунды. Движение жертвы, её смерть или потеря сознания ксеноморфа прерывают процесс."
	button_icon = 'modular_bandastation/xeno_rework/icons/hive_actions.dmi'
	button_icon_state = "swallow"
	click_to_activate = TRUE
	cooldown_time = 5 SECONDS
	/// Serializes overlapping requests before the channel yields.
	var/swallowing = FALSE
	/// Exposed for focused cancellation tests.
	var/swallow_time = 13.5 SECONDS

/datum/action/cooldown/alien/hive_swallow/proc/can_swallow(mob/living/carbon/alien/adult/banda/eater, mob/living/prey, obj/item/organ/stomach/alien_banda/stomach)
	return !QDELETED(src) && !QDELETED(eater) && owner == eater && !eater.incapacitated && !eater.resting && isturf(eater.loc) && !QDELETED(prey) && prey.stat != DEAD && !isalien(prey) && !prey.anchored && !prey.buckled && isturf(prey.loc) && eater.Adjacent(prey) && !QDELETED(stomach) && eater.get_organ_slot(ORGAN_SLOT_STOMACH) == stomach && !HAS_TRAIT(eater, TRAIT_PACIFISM)

/datum/action/cooldown/alien/hive_swallow/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/eater = owner
	if(swallowing || !istype(eater) || !isliving(target))
		return FALSE
	var/mob/living/prey = target
	if(prey.stat == DEAD)
		to_chat(eater, span_warning("[prey] выглядит невкусно."))
		return FALSE
	var/obj/item/organ/stomach/alien_banda/stomach = eater.get_organ_slot(ORGAN_SLOT_STOMACH)
	if(!can_swallow(eater, prey, stomach))
		return FALSE
	swallowing = TRUE
	eater.visible_message(span_warning("[eater] раскрывает пасть, пытаясь проглотить [prey]!"))
	playsound(eater, 'sound/mobs/non-humanoids/alien/alien_eat.ogg', 70, TRUE)
	var/ready = do_after(eater, swallow_time, target = prey, extra_checks = CALLBACK(src, PROC_REF(can_swallow), eater, prey, stomach))
	swallowing = FALSE
	if(!ready || !can_swallow(eater, prey, stomach) || !stomach.consume_thing(prey))
		return FALSE
	eater.stop_pulling()
	log_combat(eater, prey, "swallowed using hive action")
	StartCooldown()
	return TRUE

/** The older grab/devour path must reject the same corpses as the dedicated action. */
/mob/living/carbon/alien/adult/banda/can_consume(atom/movable/prey)
	if(isliving(prey))
		var/mob/living/victim = prey
		if(victim.stat == DEAD)
			to_chat(src, span_warning("[victim] выглядит невкусно."))
			return FALSE
	return ..()
