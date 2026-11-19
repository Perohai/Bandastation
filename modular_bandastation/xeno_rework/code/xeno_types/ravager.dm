
/** Чужой с ярко-красным, словно разъярённым, хитином и устрашающими клинковыми когтями вместо обычных рук. Острый хвост выглядит так, будто удар им будет крайне болезненным. */
/mob/living/carbon/alien/adult/banda/ravager
	name = "alien ravager"
	desc = "Чужой с багровым хитином и огромными когтями, острыми, словно клинки. На хвост достаточно взглянуть один раз, чтобы не захотеть испытать его в деле."
	caste = "ravager"
	mob_size = MOB_SIZE_LARGE
	evolution_tier = 4
	maxHealth = 330
	health = 330
	icon_state = "alienravager"
	hud_sprite_height = 57
	melee_damage_lower = 22
	melee_damage_upper = 22

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

/mob/living/carbon/alien/adult/banda/ravager/Initialize(mapload)
	. = ..()
	var/static/list/innate_actions = list(
		/datum/action/cooldown/alien/banda/ravager_empower,
		/datum/action/cooldown/alien/banda/ravager_charge,
		/datum/action/cooldown/alien/banda/ravager_cut,
	)
	grant_actions_by_list(innate_actions)

	ADD_TRAIT(src, TRAIT_NOFIRE, INNATE_TRAIT)
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

/mob/living/carbon/alien/adult/banda/ravager/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/zarya)
