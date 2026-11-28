
/** Чужой, выглядящий как нечто среднее между королевой и дроном — и, вероятно, именно так оно и есть. */
/mob/living/carbon/alien/adult/banda/praetorian
	name = "alien praetorian"
	previous_evolution = /mob/living/carbon/alien/adult/banda/spitter
	desc = "Крупный ксеноморф с широким гребнем и кислотными железами."
	caste = "praetorian"
	mob_size = MOB_SIZE_LARGE
	maxHealth = 280
	health = 280
	icon_state = "alienpraetorian"
	hud_sprite_height = 55
	melee_damage_lower = 17
	melee_damage_upper = 17
	evolution_tier = 3

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_XENO_ACIDGLAND = /obj/item/organ/alien/acid,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/banda/large,
		ORGAN_SLOT_XENO_NEUROTOXINGLAND = /obj/item/organ/alien/neurotoxin/praetorian_banda,
	)

/mob/living/carbon/alien/adult/banda/praetorian/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/make_structure/plant_weeds)

	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

	add_movespeed_modifier(/datum/movespeed_modifier/alien_big)

/mob/living/carbon/alien/adult/banda/praetorian/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/tyrande_hs)

/** Organ granting the Praetorian's spit and cone-shaped acid spray. */
/obj/item/organ/alien/neurotoxin/praetorian_banda
	name = "large neurotoxin gland"
	icon_state = "neurotox"
	zone = BODY_ZONE_PRECISE_MOUTH
	slot = ORGAN_SLOT_XENO_NEUROTOXINGLAND
	actions_types = list(
		/datum/action/cooldown/alien/banda/spit/praetorian,
		/datum/action/cooldown/alien/banda/toggle_spit,
		/datum/action/cooldown/alien/banda/acid_spray/cone,
	)
