/// banda MODULE banda_XENO_REDO

/mob/living/carbon/alien/adult/banda/defender
	name = "alien defender"
	desc = "Тяжелый на вид чужой с хвостом, похожим на ядро тарана — получить удар таким было бы больно."
	caste = "defender"
	maxHealth = 300
	health = 300
	icon_state = "aliendefender"
	melee_damage_lower = 10
	melee_damage_upper = 15
	next_evolution = /mob/living/carbon/alien/adult/banda/warrior

	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/small,
	)

	/// ---------- state ----------
	var/fortified = FALSE
	var/defender_base_icon_state = "aliendefender"
	var/defender_fortify_icon_state = "defender_fortify"

	/// ---------- configurable balance ----------
	var/defender_fortify_cooldown = 5 SECONDS
	var/defender_fortify_burn_multiplier = 0.5
	var/defender_fortify_brute_multiplier = 1
	var/defender_fortify_explosive_multiplier = 0.35
	var/defender_fortify_anchor = TRUE
	var/defender_fortify_move_resist = MOVE_FORCE_OVERPOWERING
	var/defender_fortify_grant_stun_immunity = FALSE

	var/defender_tail_sweep_plasma_cost = 10
	var/defender_tail_sweep_cooldown = 10 SECONDS
	var/defender_tail_sweep_brute = 10
	var/defender_tail_sweep_radius = 1
	var/defender_tail_sweep_throw_range = 2
	var/defender_tail_sweep_throw_speed = 2
	var/defender_tail_sweep_knockdown = 1 SECONDS
	var/defender_tail_sweep_stagger = 0
	var/defender_tail_sweep_small_item_weight_class = WEIGHT_CLASS_SMALL


/mob/living/carbon/alien/adult/banda/defender/Initialize(mapload)
	. = ..()
	var/static/list/innate_actions = list(
		/datum/action/cooldown/alien/banda/defender_fortify,
		/datum/action/cooldown/alien/banda/defender_tail_sweep,
	)
	grant_actions_by_list(innate_actions)

	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	add_movespeed_modifier(/datum/movespeed_modifier/alien_heavy)

	RegisterSignal(src, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(on_defender_apply_damage_modifiers))

/mob/living/carbon/alien/adult/banda/defender/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/sejuani)

/mob/living/carbon/alien/adult/banda/defender/proc/enter_fortify()
	if(fortified)
		return

	fortified = TRUE
	icon_state = defender_fortify_icon_state
	add_movespeed_modifier(/datum/movespeed_modifier/defender_fortify)

	if(defender_fortify_anchor)
		anchored = TRUE

	move_resist = defender_fortify_move_resist

	if(defender_fortify_grant_stun_immunity)
		ADD_TRAIT(src, TRAIT_STUNIMMUNE, TRAIT_XENO_ABILITY_GIVEN)

	visible_message(
		span_warning("[src] braces into a fortified stance!"),
		span_warning("Мы занимаем укреплённую позицию."),
	)
	playsound(src, 'sound/effects/stonedoor_openclose.ogg', 30, TRUE)

/mob/living/carbon/alien/adult/banda/defender/proc/on_defender_apply_damage_modifiers(datum/source, list/damage_mods, damage, damagetype, def_zone, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER

	if(!fortified)
		return

	if(!islist(damage_mods))
		return

	switch(damagetype)
		if(BURN)
			damage_mods += defender_fortify_burn_multiplier
		if(BRUTE)
			damage_mods += defender_fortify_brute_multiplier

/mob/living/carbon/alien/adult/banda/defender/proc/exit_fortify(silent = FALSE)
	if(!fortified)
		return

	fortified = FALSE
	icon_state = defender_base_icon_state
	remove_movespeed_modifier(/datum/movespeed_modifier/defender_fortify)

	if(defender_fortify_anchor)
		anchored = FALSE

	move_resist = initial(move_resist)
	REMOVE_TRAIT(src, TRAIT_STUNIMMUNE, TRAIT_XENO_ABILITY_GIVEN)

	if(!silent)
		visible_message(
			span_warning("[src] relaxes out of its fortified stance."),
			span_warning("Мы выходим из укреплённой позиции."),
		)
		playsound(src, 'sound/effects/stonedoor_openclose.ogg', 30, TRUE)
