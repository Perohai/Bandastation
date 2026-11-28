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

/** Runner can evolve into Hunter at T2 or buy the Ravager branch. */
/mob/living/carbon/alien/adult/banda/runner
	final_evolution = /mob/living/carbon/alien/adult/banda/ravager

/mob/living/carbon/alien/adult/banda/drone
	final_evolution = /mob/living/carbon/alien/adult/banda/carrier

/// Any unlocked branch and the immediate predecessor of the current caste.
/mob/living/carbon/alien/adult/banda/proc/get_evolution_options()
	var/list/options = list()
	var/list/purchases = GLOB.xeno_hive?.purchased
	if(next_evolution)
		var/mob/living/carbon/alien/adult/banda/next_caste = next_evolution
		var/next_tier = initial(next_caste.evolution_tier)
		if((next_tier != 2 || purchases?["claws"]) && (next_tier != 3 || purchases?["tier3"]))
			options += next_evolution
	var/static/list/unlocks = list(
		/mob/living/carbon/alien/adult/banda/final_caste/crusher = "crusher",
		/mob/living/carbon/alien/adult/banda/final_caste/boiler = "boiler",
		/mob/living/carbon/alien/adult/banda/ravager = "ravager",
		/mob/living/carbon/alien/adult/banda/carrier = "claws",
	)
	if(final_evolution && purchases?[unlocks[final_evolution]])
		options += final_evolution
	if(previous_evolution)
		options += previous_evolution
	return options
