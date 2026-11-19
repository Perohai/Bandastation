
/** Исполинская тварь с устрашающей аурой. Пора действовать, а не глазеть. */
/mob/living/carbon/alien/adult/banda/queen
	name = "alien queen"
	desc = "Исполинская тварь, внушающая ужас одним своим видом. Лучше действовать, чем стоять и глазеть."
	caste = "queen"
	mob_size = MOB_SIZE_LARGE
	maxHealth = 300
	health = 300
	icon_state = "alienqueen"
	melee_damage_lower = 20
	melee_damage_upper = 20

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_XENO_ACIDGLAND = /obj/item/organ/alien/acid,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/banda/queen,
		ORGAN_SLOT_XENO_RESINSPINNER = /obj/item/organ/alien/resinspinner_banda,
		ORGAN_SLOT_XENO_NEUROTOXINGLAND = /obj/item/organ/alien/neurotoxin/queen,
		ORGAN_SLOT_XENO_EGGSAC = /obj/item/organ/alien/eggsac,
	)

/mob/living/carbon/alien/adult/banda/queen/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/make_structure/plant_weeds)
	GRANT_ACTION(/datum/action/cooldown/alien/hive_development)
	var/datum/component/itempicky/picky = GetComponent(/datum/component/itempicky)
	var/static/list/packed_core_types = typecacheof(/obj/item/packed_xeno_hive_core)
	picky.whitelist = picky.whitelist | packed_core_types
	var/static/list/innate_actions = list(
		/datum/action/cooldown/alien/banda/queen_screech,
	)
	grant_actions_by_list(innate_actions)

	ADD_TRAIT(src, TRAIT_NOFIRE, INNATE_TRAIT)
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

	add_movespeed_modifier(/datum/movespeed_modifier/alien_big)

/mob/living/carbon/alien/adult/banda/queen/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/alexstraza)

/mob/living/carbon/alien/adult/banda/queen/alien_talk(message, list/spans = list(), list/message_mods = list(), shown_name = name, big_voice = TRUE)
	..(message, spans, message_mods, shown_name, TRUE)

/** Organ granting the Queen's ranged neurotoxin action. */
/obj/item/organ/alien/neurotoxin/queen
	name = "neurotoxin gland"
	icon_state = "neurotox"
	zone = BODY_ZONE_PRECISE_MOUTH
	slot = ORGAN_SLOT_XENO_NEUROTOXINGLAND
	actions_types = list(
		/datum/action/cooldown/alien/banda/spit,
		/datum/action/cooldown/alien/banda/toggle_spit,
	)
/mob/living/carbon/alien/adult/banda/queen/death(gibbed)
	if(stat == DEAD)
		return

	for(var/mob/living/carbon/carbon_mob in GLOB.alive_mob_list)
		if(carbon_mob == src)
			continue

		var/obj/item/organ/alien/hivenode/node = carbon_mob.get_organ_by_type(/obj/item/organ/alien/hivenode)

		if(istype(node))
			node.queen_death()

	return ..()

/** Create the Queen shriek visual around the current mob. */
/mob/living/carbon/alien/adult/banda/proc/create_shriekwave()
	remove_overlay(HALO_LAYER)
	overlays_standing[HALO_LAYER] = image("icon" = 'modular_bandastation/xeno_rework/icons/big_xenos.dmi', "icon_state" = "shriek_waves") //Ehh, suit layer's not being used.
	apply_overlay(HALO_LAYER)
	addtimer(CALLBACK(src, PROC_REF(remove_shriekwave)), 3 SECONDS)

/** Remove the Queen shriek visual after its animation. */
/mob/living/carbon/alien/adult/banda/proc/remove_shriekwave()
	remove_overlay(HALO_LAYER)
