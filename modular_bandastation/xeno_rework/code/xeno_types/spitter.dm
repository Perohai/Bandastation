
/** Довольно массивный чужой с выраженными кислотными железами, из его рта капает... то ли токсин, то ли кислота. */
/mob/living/carbon/alien/adult/banda/spitter
	name = "alien spitter"
	desc = "Довольно массивный чужой с выраженными кислотными железами, из его рта капает... то ли токсин, то ли кислота."
	caste = "spitter"
	next_evolution = /mob/living/carbon/alien/adult/banda/sentinel
	maxHealth = 200
	health = 200
	icon_state = "alienspitter"
	melee_damage_lower = 10
	melee_damage_upper = 10

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel,
		ORGAN_SLOT_XENO_NEUROTOXINGLAND = /obj/item/organ/alien/neurotoxin/spitter,
	)

/mob/living/carbon/alien/adult/banda/spitter/Initialize(mapload)
	. = ..()

	add_movespeed_modifier(/datum/movespeed_modifier/alien_heavy)

	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

/mob/living/carbon/alien/adult/banda/spitter/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/janna)

/** Organ granting the Spitter-specific toxic combat abilities. */
/obj/item/organ/alien/neurotoxin/spitter
	actions_types = list(
		/datum/action/cooldown/alien/banda/toxic_spit,
		/datum/action/cooldown/alien/banda/toxic_claws,
		/datum/action/cooldown/alien/banda/toxic_sting,
	)
