/// banda MODULE banda_XENO_REDO

/mob/living/carbon/alien/adult/banda/ravager
	name = "alien ravager"
	desc = "Чужой с ярко-красным, словно разъярённым, хитином и устрашающими клинковыми когтями вместо обычных рук. Острый хвост выглядит так, будто удар им будет крайне болезненным."
	caste = "ravager"
	maxHealth = 400
	health = 400
	icon_state = "alienravager"
	melee_damage_lower = 25
	melee_damage_upper = 25
	alien_speed = -1.0
	tgmc_combat = TRUE
	tgmc_melee_penetration = 15
	var/tgmc_next_fire_fury = 0
	#ifndef STABLE
	var/tgmc_legacy_dead_threshold = HEALTH_THRESHOLD_DEAD
	#endif

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/tgmc/ravager,
	)

/mob/living/carbon/alien/adult/banda/ravager/Initialize(mapload)
	. = ..()
	set_tgmc_armor("caste", new /datum/armor/xeno_tgmc_ravager)
	RegisterSignal(src, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(tgmc_on_damage))
	var/static/list/innate_actions = list(
		/datum/action/cooldown/alien/banda/tgmc/ravage,
		/datum/action/cooldown/alien/banda/tgmc/endure,
		/datum/action/cooldown/alien/banda/tgmc/rage,
		/datum/action/cooldown/alien/banda/tgmc/ravager_charge,
	)
	grant_actions_by_list(innate_actions)

	ADD_TRAIT(src, TRAIT_NOFIRE, INNATE_TRAIT)
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

/mob/living/carbon/alien/adult/banda/ravager/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/zarya)

/mob/living/carbon/alien/adult/banda/ravager/proc/tgmc_get_dead_threshold()
	#ifdef STABLE
	return dead_threshold
	#else
	return tgmc_legacy_dead_threshold
	#endif

/mob/living/carbon/alien/adult/banda/ravager/proc/tgmc_set_dead_threshold(value)
	#ifdef STABLE
	dead_threshold = value
	#else
	tgmc_legacy_dead_threshold = value
	#endif

#ifndef STABLE
// Old /carbon/update_stat hardcodes HEALTH_THRESHOLD_DEAD. Keep its entire stat
// and HUD chain, suppressing only that health check inside Endure's extra range.
/mob/living/carbon/alien/adult/banda/ravager/update_stat()
	var/guard_health_death = stat != DEAD && health <= HEALTH_THRESHOLD_DEAD && health > tgmc_legacy_dead_threshold
	var/had_guard = HAS_TRAIT_FROM(src, TRAIT_NODEATH, XENO_TGMC_ENDURE_SOURCE)
	if(guard_health_death && !had_guard)
		ADD_TRAIT(src, TRAIT_NODEATH, XENO_TGMC_ENDURE_SOURCE)
	. = ..()
	if(guard_health_death && !had_guard)
		REMOVE_TRAIT(src, TRAIT_NODEATH, XENO_TGMC_ENDURE_SOURCE)
#endif
