/// banda MODULE banda_XENO_REDO

/mob/living/carbon/alien/adult/banda/sentinel
	name = "alien sentinel"
	desc = "Чужой, который был бы неприметным, если бы не яркая окраска и видимые кислотные железы, покрывающие его тело."
	caste = "sentinel"
	evolution_tier = 2
	maxHealth = 250
	health = 250
	icon_state = "aliensentinel"
	melee_damage_lower = 15
	melee_damage_upper = 15
	next_evolution = /mob/living/carbon/alien/adult/banda/praetorian

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/large,
		ORGAN_SLOT_XENO_RESINSPINNER = /obj/item/organ/alien/resinspinner_banda,
		ORGAN_SLOT_XENO_NEUROTOXINGLAND = /obj/item/organ/alien/neurotoxin/sentinel,
	)

/mob/living/carbon/alien/adult/banda/sentinel/Initialize(mapload)
	. = ..()

	add_movespeed_modifier(/datum/movespeed_modifier/alien_slow)

/mob/living/carbon/alien/adult/banda/sentinel/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/tracer)

/obj/item/organ/alien/neurotoxin/sentinel
	name = "neurotoxin gland"
	icon_state = "neurotox"
	zone = BODY_ZONE_PRECISE_MOUTH
	slot = ORGAN_SLOT_XENO_NEUROTOXINGLAND
	actions_types = list(
		/datum/action/cooldown/alien/banda/spit,
		/datum/action/cooldown/alien/banda/toggle_spit,
		/datum/action/cooldown/alien/banda/acid_volley,
		/datum/action/cooldown/alien/banda/acid_spray,
	)
