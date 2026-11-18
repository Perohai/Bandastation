/** Adult specializations unlocked by irreversible hive purchases. */
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
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/banda/large,
	)

/** Warrior retains its purchased Crusher branch after the finale ends. */
/mob/living/carbon/alien/adult/banda/warrior
	final_evolution = /mob/living/carbon/alien/adult/banda/final_caste/crusher

/** Spitter may choose either Praetorian or the purchased Boiler specialization. */
/mob/living/carbon/alien/adult/banda/spitter
	final_evolution = /mob/living/carbon/alien/adult/banda/final_caste/boiler

/** Runner always has Hunter; a purchased Ravager adds a choice instead of replacing it. */
/mob/living/carbon/alien/adult/banda/runner
	final_evolution = /mob/living/carbon/alien/adult/banda/ravager

/mob/living/carbon/alien/adult/banda/drone
	final_evolution = /mob/living/carbon/alien/adult/banda/carrier

/** Return the purchased specialization, or the ordinary branch if none is unlocked. */
/mob/living/carbon/alien/adult/banda/proc/get_evolution_type()
	var/static/list/unlocks = list(
		/mob/living/carbon/alien/adult/banda/final_caste/crusher = "crusher",
		/mob/living/carbon/alien/adult/banda/final_caste/boiler = "boiler",
		/mob/living/carbon/alien/adult/banda/ravager = "ravager",
		/mob/living/carbon/alien/adult/banda/carrier = "carrier",
	)
	if(final_evolution && GLOB.xeno_hive?.purchased[unlocks[final_evolution]])
		return final_evolution
	return next_evolution

/// The ordinary branch remains available when a specialization is bought.
/mob/living/carbon/alien/adult/banda/proc/get_evolution_options()
	var/list/options = list()
	if(next_evolution)
		options += next_evolution
	var/purchased_branch = get_evolution_type()
	if(purchased_branch)
		options |= purchased_branch
	return options
