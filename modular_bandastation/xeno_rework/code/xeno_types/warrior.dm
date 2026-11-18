
/** Если среди чужих и есть ходячие танки, то этот — один из них, с тяжёлой бронёй и мощными руками, подтверждающими этот статус. */
/mob/living/carbon/alien/adult/banda/warrior
	name = "alien warrior"
	desc = "Если среди Чужих есть живые танки, то перед вами один из них: толстая броня и могучие лапы не оставляют сомнений."
	caste = "warrior"
	mob_size = MOB_SIZE_LARGE
	evolution_tier = 3
	maxHealth = 250
	health = 250
	icon_state = "alienwarrior"
	hud_sprite_height = 47
	melee_damage_lower = 15
	melee_damage_upper = 15

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/banda,
	)

	/// режим ловкости
	var/agility = FALSE
	/// захват был начат именно через выпад
	var/lunging = FALSE

/// ---------- configurable balance ----------
	var/warrior_throw_range = 5
	/// Warrior throw range large penalty.
	var/warrior_throw_range_large_penalty = 1
	/// Warrior throw speed.
	var/warrior_throw_speed = 2
	/// Warrior throw knockdown.
	var/warrior_throw_knockdown = 0.8 SECONDS

	/// Warrior fling range.
	var/warrior_fling_range = 3
	/// Warrior fling range large penalty.
	var/warrior_fling_range_large_penalty = 1
	/// Warrior fling speed.
	var/warrior_fling_speed = 2
	/// Warrior fling knockdown.
	var/warrior_fling_knockdown = 1 SECONDS
	/// Warrior fling stagger.
	var/warrior_fling_stagger = 1
	/// Warrior fling slowdown.
	var/warrior_fling_slowdown = 1

	/// Warrior lunge range.
	var/warrior_lunge_range = 4
	/// Warrior lunge step delay.
	var/warrior_lunge_step_delay = 0.05 SECONDS
	/// Warrior lunge knockdown.
	var/warrior_lunge_knockdown = 2 SECONDS
	/// Warrior lunge stun.
	var/warrior_lunge_stun = 2 SECONDS

	/// Warrior punch brute.
	var/warrior_punch_brute = 15
	/// Warrior punch stamina.
	var/warrior_punch_stamina = 50
	/// Warrior punch knockdown.
	var/warrior_punch_knockdown = 1 SECONDS
	/// Warrior punch grab multiplier.
	var/warrior_punch_grab_multiplier = 1.5
	/// Warrior punch grab knockdown.
	var/warrior_punch_grab_knockdown = 2 SECONDS

/mob/living/carbon/alien/adult/banda/warrior/Initialize(mapload)
	. = ..()
	var/static/list/innate_actions = list(
		/datum/action/cooldown/alien/banda/warrior_agility,
		/datum/action/cooldown/alien/banda/warrior_lunge,
		/datum/action/cooldown/alien/banda/warrior_throw,
		/datum/action/cooldown/alien/banda/warrior_fling,
		/datum/action/cooldown/alien/banda/warrior_punch,
	)
	grant_actions_by_list(innate_actions)

	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	add_movespeed_modifier(/datum/movespeed_modifier/alien_big)

	RegisterSignal(src, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_warrior_after_apply_damage))

/mob/living/carbon/alien/adult/banda/warrior/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/barbarian)

/mob/living/carbon/alien/adult/banda/warrior/Destroy()
	UnregisterSignal(src, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	return ..()

/mob/living/carbon/alien/adult/banda/warrior/update_icons()
	. = ..()
	if(agility && !IS_UNCONSCIOUS_OR_CRIT(src) && !IsParalyzed() && body_position != LYING_DOWN)
		icon_state = "alien[caste]_mobility"

/** Enable Warrior agility and its movement modifier. */
/mob/living/carbon/alien/adult/banda/warrior/proc/enter_agility()
	if(agility)
		return
	agility = TRUE
	break_warrior_grab(show_message = FALSE)
	icon_state = "alien[caste]_mobility"
	add_movespeed_modifier(/datum/movespeed_modifier/warrior_agility)
	playsound(src, 'modular_bandastation/xeno_rework/sound/alien_hiss.ogg', 45, TRUE)
	new /obj/effect/temp_visual/decoy/fading/halfsecond(loc, src, 100)
	balloon_alert(src, "Режим ловкости включён.")

/mob/living/carbon/alien/adult/banda/warrior/start_pulling(atom/movable/pulled_atom, state, force = pull_force, supress_message = FALSE)
	if(agility && isliving(pulled_atom))
		return FALSE
	return ..()

/** Disable agility and release its movement modifier. */
/mob/living/carbon/alien/adult/banda/warrior/proc/exit_agility()
	if(!agility)
		return
	agility = FALSE
	icon_state = "alien[caste]"
	remove_movespeed_modifier(/datum/movespeed_modifier/warrior_agility)
	playsound(src, 'modular_bandastation/xeno_rework/sound/alien_resin_move1.ogg', 35, TRUE)
	balloon_alert(src, "Режим ловкости выключен.")

/** Return the Warrior-held living victim if the grab is still valid. */
/mob/living/carbon/alien/adult/banda/warrior/proc/get_warrior_grab_target()
	if(isliving(pulling))
		return pulling
	return null

/** Release the Warrior grip and any associated movement penalty. */
/mob/living/carbon/alien/adult/banda/warrior/proc/break_warrior_grab(show_message = TRUE)
	lunging = FALSE
	remove_movespeed_modifier(/datum/movespeed_modifier/warrior_drag)

	if(show_message && isliving(pulling))
		visible_message(
			span_warning("[src] теряет [src.p_their()] хватку!"),
			span_alertalien("Боль заставляет нас отпустить добычу!"),
		)

	if(isliving(pulling))
		stop_pulling()

/mob/living/carbon/alien/adult/banda/warrior/stop_pulling()
	lunging = FALSE
	remove_movespeed_modifier(/datum/movespeed_modifier/warrior_drag)
	return ..()

/** Break the special Warrior grip when its owner takes damage. */
/mob/living/carbon/alien/adult/banda/warrior/proc/on_warrior_after_apply_damage(datum/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER

	if(damage <= 0)
		return
	if(!get_warrior_grab_target())
		return
	break_warrior_grab(TRUE)

/mob/living/carbon/alien/adult/banda/warrior/get_incoming_damage_modifier(damage = 0, damagetype = BRUTE, def_zone = null, sharpness = NONE, attack_direction = null, attacking_item)
	. = ..()
	if(agility)
		. *= 1.5
