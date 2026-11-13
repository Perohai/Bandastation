/** Adult combat evolutions unlocked by the evacuation finale. */
/mob/living/carbon/alien/adult/banda/final_caste
	abstract_type = /mob/living/carbon/alien/adult/banda/final_caste
	evolution_tier = 4
	mob_size = MOB_SIZE_LARGE
	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/large,
	)

/** Warrior gains a Crusher branch during the evacuation finale. */
/mob/living/carbon/alien/adult/banda/warrior
	final_evolution = /mob/living/carbon/alien/adult/banda/final_caste/crusher

/** Sentinel gains a Boiler branch without replacing normal pre-finale evolution. */
/mob/living/carbon/alien/adult/banda/sentinel
	final_evolution = /mob/living/carbon/alien/adult/banda/final_caste/boiler

/** Ravager gains a Hunter branch during the evacuation finale. */
/mob/living/carbon/alien/adult/banda/ravager
	final_evolution = /mob/living/carbon/alien/adult/banda/final_caste/hunter

/** Keep the normal evolution tree until the evacuation finale unlocks its branch. */
/mob/living/carbon/alien/adult/banda/proc/get_evolution_type()
	if(final_evolution && GLOB.xeno_evacuation?.active && !GLOB.xeno_evacuation.resolved)
		return final_evolution
	return next_evolution
