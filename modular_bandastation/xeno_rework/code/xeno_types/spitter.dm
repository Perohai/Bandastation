/// banda MODULE banda_XENO_REDO

/mob/living/carbon/alien/adult/banda/spitter
	name = "alien spitter"
	desc = "Довольно массивный чужой с выраженными кислотными железами, из его рта капает... то ли токсин, то ли кислота."
	caste = "spitter"
	maxHealth = 360
	health = 360
	icon_state = "alienspitter"
	melee_damage_lower = 20
	melee_damage_upper = 20
	alien_speed = -0.6
	tgmc_combat = TRUE

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/tgmc/spitter,
		ORGAN_SLOT_XENO_NEUROTOXINGLAND = /obj/item/organ/alien/neurotoxin/tgmc_spitter,
	)

/mob/living/carbon/alien/adult/banda/spitter/Initialize(mapload)
	. = ..()
	set_tgmc_armor("caste", new /datum/armor/xeno_tgmc_spitter)

/mob/living/carbon/alien/adult/banda/spitter/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/janna)
