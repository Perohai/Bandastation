/// banda MODULE banda_XENO_REDO

/mob/living/carbon/alien/adult/banda/defender
	name = "alien defender"
	desc = "Тяжелый на вид чужой с хвостом, похожим на ядро тарана — получить удар таким было бы больно."
	caste = "defender"
	maxHealth = 250
	health = 250
	icon_state = "aliendefender"
	melee_damage_lower = 10
	melee_damage_upper = 10
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
	var/defender_fortify_anchor = FALSE
	var/defender_fortify_move_resist = MOVE_FORCE_OVERPOWERING
	var/defender_fortify_grant_stun_immunity = FALSE

	var/defender_tail_sweep_plasma_cost = 10
	var/defender_tail_sweep_cooldown = 10 SECONDS
	var/defender_tail_sweep_brute = 10
	var/defender_tail_sweep_radius = 1
	var/defender_tail_sweep_throw_range = 2
	var/defender_tail_sweep_throw_speed = 2
	var/defender_tail_sweep_knockdown = 1 SECONDS
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

	RegisterSignal(src, COMSIG_LIVING_STATUS_KNOCKDOWN, PROC_REF(block_fortified_knockdown))

/mob/living/carbon/alien/adult/banda/defender/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/sejuani)

/mob/living/carbon/alien/adult/banda/defender/update_icons()
	. = ..()
	if(fortified && !IS_UNCONSCIOUS_OR_CRIT(src) && !IsParalyzed() && body_position != LYING_DOWN)
		icon_state = defender_fortify_icon_state

/mob/living/carbon/alien/adult/banda/defender/proc/enter_fortify()
	if(fortified)
		return

	fortified = TRUE
	add_inner_armor(get_armor_by_type(/datum/armor/xeno_fortify))
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

/datum/armor/xeno_fortify
	bullet = 50
	laser = 50
	energy = 50
	bomb = 65

/mob/living/carbon/alien/adult/banda/defender/proc/block_fortified_knockdown(datum/source, amount, ignore_canstun)
	SIGNAL_HANDLER
	if(fortified && !ignore_canstun)
		return COMPONENT_NO_STUN

/mob/living/carbon/alien/adult/banda/defender/proc/exit_fortify(silent = FALSE)
	if(!fortified)
		return

	fortified = FALSE
	remove_inner_armor(get_armor_by_type(/datum/armor/xeno_fortify))
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
