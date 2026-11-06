/// banda MODULE banda_XENO_REDO

/mob/living/carbon/alien/adult/banda/sentinel
	name = "alien sentinel"
	desc = "Чужой, который был бы неприметным, если бы не яркая окраска и видимые кислотные железы, покрывающие его тело."
	caste = "sentinel"
	maxHealth = 370
	health = 370
	icon_state = "aliensentinel"
	melee_damage_lower = 18
	melee_damage_upper = 18
	alien_speed = -0.9
	tgmc_combat = TRUE
	next_evolution = /mob/living/carbon/alien/adult/banda/spitter

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/tgmc/sentinel,
		ORGAN_SLOT_XENO_RESINSPINNER = /obj/item/organ/alien/resinspinner,
		ORGAN_SLOT_XENO_NEUROTOXINGLAND = /obj/item/organ/alien/neurotoxin/tgmc_sentinel,
	)

/mob/living/carbon/alien/adult/banda/sentinel/Initialize(mapload)
	. = ..()
	set_tgmc_armor("caste", new /datum/armor/xeno_tgmc_sentinel)

/mob/living/carbon/alien/adult/banda/sentinel/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/tracer)
