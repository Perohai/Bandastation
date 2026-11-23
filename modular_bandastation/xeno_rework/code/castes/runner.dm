
/** Невысокий чужой с гладким красным хитином, явно следующий теореме «красный значит быстрый» и почти всегда передвигающийся на четырёх лапах. */
/mob/living/carbon/alien/adult/banda/runner
	name = "alien runner"
	desc = "Небольшой ксеноморф с красным хитином. Передвигается на четырёх лапах."
	caste = "runner"
	shove_stamina_damage = 25
	maxHealth = 120
	health = 120
	icon_state = "alienrunner"
	hud_sprite_height = 22

	/// Holds the ability to be granted to the runner later
	var/datum/action/cooldown/alien/banda/pounce_runner/pounce_ability
	/// Owned runner evasion action, deleted with the mob.
	var/datum/action/cooldown/alien/banda/evade/evade_ability

	melee_damage_lower = 8
	melee_damage_upper = 8
	next_evolution = /mob/living/carbon/alien/adult/banda/final_caste/hunter
	on_fire_pixel_y = 0

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/banda/tiny,
	)

/mob/living/carbon/alien/adult/banda/runner/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/hide)

	if(!evade_ability)
		evade_ability = new
		evade_ability.Grant(src)

	if(!pounce_ability)
		pounce_ability = new
		pounce_ability.Grant(src)

	add_movespeed_modifier(/datum/movespeed_modifier/alien_quick)

/mob/living/carbon/alien/adult/banda/runner/Destroy()
	QDEL_NULL(evade_ability)
	QDEL_NULL(pounce_ability)
	return ..()

/mob/living/carbon/alien/adult/banda/runner/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/wendy)

/mob/living/carbon/alien/adult/banda/runner/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(evade_ability)
		var/datum/action/cooldown/alien/banda/evade/evasion = evade_ability
		var/evade_result = evasion.on_projectile_hit(hitting_projectile)
		if(evade_result != BULLET_ACT_HIT)
			return evade_result

	return ..()
