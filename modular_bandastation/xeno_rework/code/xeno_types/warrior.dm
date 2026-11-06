/// banda MODULE banda_XENO_REDO

/mob/living/carbon/alien/adult/banda/warrior
	name = "alien warrior"
	desc = "Если среди чужих и есть ходячие танки, то этот — один из них, с тяжёлой бронёй и мощными руками, подтверждающими этот статус."
	caste = "warrior"
	maxHealth = 400
	health = 400
	icon_state = "alienwarrior"
	melee_damage_lower = 15
	melee_damage_upper = 20

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel,
	)

	/// режим ловкости
	var/agility = FALSE
	/// захват был начат именно через выпад
	var/lunging = FALSE
	/// защита от повторного break_grab в тот же тик/почти тот же тик
	var/last_grab_break_time = 0

/// ---------- configurable balance ----------
	var/warrior_throw_range = 5
	var/warrior_throw_range_large_penalty = 1
	var/warrior_throw_speed = 2
	var/warrior_throw_knockdown = 0.8 SECONDS

	var/warrior_fling_range = 4
	var/warrior_fling_range_large_penalty = 1
	var/warrior_fling_speed = 2
	var/warrior_fling_knockdown = 1 SECONDS
	var/warrior_fling_stagger = 1
	var/warrior_fling_slowdown = 1

	var/warrior_lunge_range = 4
	var/warrior_lunge_step_delay = 0.05 SECONDS
	var/warrior_lunge_knockdown = 2 SECONDS
	var/warrior_lunge_stun = 2 SECONDS

	var/warrior_punch_brute = 15
	var/warrior_punch_stamina = 50
	var/warrior_punch_knockdown = 1 SECONDS
	var/warrior_punch_grab_multiplier = 1.5
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

/mob/living/carbon/alien/adult/banda/warrior/proc/enter_agility()
	if(agility)
		return
	agility = TRUE
	icon_state = "alien[caste]_mobility"
	add_movespeed_modifier(/datum/movespeed_modifier/warrior_agility)
	balloon_alert(src, "agility active")

/mob/living/carbon/alien/adult/banda/warrior/proc/exit_agility()
	if(!agility)
		return
	agility = FALSE
	icon_state = "alien[caste]"
	remove_movespeed_modifier(/datum/movespeed_modifier/warrior_agility)
	balloon_alert(src, "agility ended")

/mob/living/carbon/alien/adult/banda/warrior/proc/get_warrior_grab_target()
	if(isliving(pulling))
		return pulling
	return null

/mob/living/carbon/alien/adult/banda/warrior/proc/break_warrior_grab(show_message = TRUE)
	lunging = FALSE
	remove_movespeed_modifier(/datum/movespeed_modifier/warrior_drag)

	if(show_message && isliving(pulling))
		visible_message(
			span_warning("[src] loses [src.p_their()] grip!"),
			span_alertalien("Pain forces us to release our prey!"),
		)

	if(isliving(pulling))
		stop_pulling()

/mob/living/carbon/alien/adult/banda/warrior/stop_pulling()
	lunging = FALSE
	remove_movespeed_modifier(/datum/movespeed_modifier/warrior_drag)
	return ..()

/mob/living/carbon/alien/adult/banda/warrior/proc/on_warrior_after_apply_damage(datum/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER

	if(damage <= 0)
		return
	if(!get_warrior_grab_target())
		return
	if(world.time <= last_grab_break_time + 1)
		return

	last_grab_break_time = world.time
	break_warrior_grab(TRUE)
