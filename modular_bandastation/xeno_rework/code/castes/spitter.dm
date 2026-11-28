
/** Довольно массивный чужой с выраженными кислотными железами, из его рта капает... то ли токсин, то ли кислота. */
/mob/living/carbon/alien/adult/banda/spitter
	name = "alien spitter"
	previous_evolution = /mob/living/carbon/alien/adult/banda/sentinel
	desc = "Ксеноморф с выступающими кислотными железами. Из пасти капает кислота."
	caste = "spitter"
	evolution_tier = 2
	next_evolution = /mob/living/carbon/alien/adult/banda/praetorian
	maxHealth = 230
	health = 230
	icon_state = "alienspitter"
	hud_sprite_height = 48
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
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/banda/large,
		ORGAN_SLOT_XENO_NEUROTOXINGLAND = /obj/item/organ/alien/neurotoxin/spitter,
	)

/mob/living/carbon/alien/adult/banda/spitter/Initialize(mapload)
	. = ..()

	add_movespeed_modifier(/datum/movespeed_modifier/alien_heavy)

	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

/mob/living/carbon/alien/adult/banda/spitter/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/janna)

/** Organ granting the Spitter acid spit, volley and spray abilities. */
/obj/item/organ/alien/neurotoxin/spitter
	actions_types = list(
		/datum/action/cooldown/alien/banda/spit/spitter,
		/datum/action/cooldown/alien/banda/toggle_spit,
		/datum/action/cooldown/alien/banda/acid_volley,
		/datum/action/cooldown/alien/banda/acid_spray/spitter,
	)
