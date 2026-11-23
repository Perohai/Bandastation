
/** Настолько обычный, насколько может быть чужой с бронированным черным хитином и огромными когтями. */
/mob/living/carbon/alien/adult/banda/drone
	name = "alien drone"
	desc = "Ксеноморф с чёрным хитином и широкими когтями. Плетёт стены, мембраны и гнёзда из смолы."
	caste = "drone"
	shove_stamina_damage = 25
	maxHealth = 200
	health = 200
	icon_state = "aliendrone"
	hud_sprite_height = 36
	melee_damage_lower = 10
	melee_damage_upper = 10
	next_evolution = /mob/living/carbon/alien/adult/banda/queen

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/banda,
		ORGAN_SLOT_XENO_RESINSPINNER = /obj/item/organ/alien/resinspinner_banda,
	)

/mob/living/carbon/alien/adult/banda/drone/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/make_structure/plant_weeds)
	var/datum/component/itempicky/picky = GetComponent(/datum/component/itempicky)
	var/static/list/fruit_types = typecacheof(/obj/item/xeno_fruit)
	picky.whitelist = picky.whitelist | fruit_types
	GRANT_ACTION(/datum/action/cooldown/alien/banda/grow_fruit)

/mob/living/carbon/alien/adult/banda/drone/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/annah)
