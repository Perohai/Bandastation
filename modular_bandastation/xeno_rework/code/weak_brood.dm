/** Weak brood is deliberately outside adult and larva inheritance: no evolution or finale slot. */
/mob/living/carbon/alien/brood
	name = "hive microdrone"
	desc = "Рабочий выводка: распространяет траву, чинит смолу и перетаскивает добычу. Во взрослых не эволюционирует."
	icon = 'modular_bandastation/xeno_rework/icons/brood/microdrone.dmi'
	icon_state = "microdrone"
	rotate_on_lying = FALSE
	hud_type = /datum/hud/larva
	maxHealth = 65
	health = 65
	hardcrit_threshold = HEALTH_THRESHOLD_CRIT
	melee_damage_lower = 5
	melee_damage_upper = 5
	mob_size = MOB_SIZE_SMALL
	density = FALSE
	pass_flags = PASSTABLE | PASSMOB
	default_num_hands = 0
	default_num_legs = 1
	num_legs = 1
	usable_legs = 1
	bodyparts = list(/obj/item/bodypart/chest/larva, /obj/item/bodypart/head/larva)
	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/brood,
	)
	/// Incremental upgrades must not heal a brood on every menu refresh.
	var/brood_upgraded = FALSE

/mob/living/carbon/alien/brood/Initialize(mapload)
	. = ..()
	apply_hive_upgrade()
	if(type == /mob/living/carbon/alien/brood)
		GRANT_ACTION(/datum/action/cooldown/alien/brood_repair)

/** Brood use larval placeholder anatomy, so healing must not grow human arms and legs. */
/mob/living/carbon/alien/brood/get_all_limbs()
	return list(BODY_ZONE_CHEST, BODY_ZONE_HEAD)

/mob/living/carbon/alien/brood/update_icons()
	icon_state = "[initial(icon_state)][stat == DEAD ? "_dead" : (IS_UNCONSCIOUS(src) || resting ? "_sleep" : "")]"

/mob/living/carbon/alien/brood/death(gibbed)
	. = ..()
	update_icons()

/mob/living/carbon/alien/brood/revive(full_heal_flags = NONE, excess_healing = 0, force_grab_ghost = FALSE)
	. = ..()
	update_icons()

/mob/living/carbon/alien/brood/proc/apply_hive_upgrade()
	if(brood_upgraded || !GLOB.xeno_hive?.purchased["brood_vigor"])
		return
	brood_upgraded = TRUE
	maxHealth += 20
	updatehealth()

/mob/living/carbon/alien/brood/can_unarmed_attack()
	return TRUE

/** Small bites use normal armor and blocking; no adult disarm, dismemberment or structure damage. */
/mob/living/carbon/alien/brood/resolve_unarmed_attack(atom/attack_target, list/modifiers)
	if(!isliving(attack_target) || !combat_mode || HAS_TRAIT(src, TRAIT_PACIFISM))
		return
	var/mob/living/victim = attack_target
	if(isalien(victim) || victim.check_block(src, melee_damage_upper, name, attack_type = UNARMED_ATTACK))
		return
	do_attack_animation(victim, ATTACK_EFFECT_BITE)
	victim.apply_damage(melee_damage_upper, BRUTE, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, MELEE))
	log_combat(src, victim, "bit")

/mob/living/carbon/alien/brood/resolve_right_click_attack(atom/target, list/modifiers)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/** No carrying machinery, holding prey in a stomach, or securing prey for rewards. */
/mob/living/carbon/alien/brood/start_pulling(atom/movable/pulled_atom, state, force = pull_force, supress_message = FALSE)
	if(!isliving(pulled_atom))
		return FALSE
	return ..()

/obj/item/organ/alien/plasmavessel/brood
	max_plasma = 100
	stored_plasma = 100
	plasma_rate = 2
	heal_rate = 0.75
	actions_types = list(/datum/action/cooldown/alien/make_structure/plant_weeds)

/mob/living/carbon/alien/brood/scout
	name = "hive scout"
	desc = "Разведчик выводка: скрывается, пролезает под дверями и отмечает добычу для роя."
	maxHealth = 45
	health = 45
	melee_damage_lower = 3
	melee_damage_upper = 3
	icon = 'modular_bandastation/xeno_rework/icons/brood/scout.dmi'
	icon_state = "scout"

/mob/living/carbon/alien/brood/scout/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/hide)
	GRANT_ACTION(/datum/action/cooldown/alien/brood_mark)
	AddComponent(/datum/component/slide_under_doors, slide_in_delay = 3 SECONDS)
	add_movespeed_modifier(/datum/movespeed_modifier/alien_quick)

/mob/living/carbon/alien/brood/carrier
	name = "hive carrier"
	desc = "Переносчик выводка: быстро эвакуирует лежащих сородичей и доставляет добычу без обычного замедления."
	maxHealth = 90
	health = 90
	melee_damage_lower = 6
	melee_damage_upper = 6
	icon = 'modular_bandastation/xeno_rework/icons/brood/carrier.dmi'
	icon_state = "carrier"
	slowed_by_drag = FALSE

/mob/living/carbon/alien/brood/carrier/Initialize(mapload)
	. = ..()
	add_movespeed_modifier(/datum/movespeed_modifier/alien_quick)

/** Repairs support structures, never bodies, eggs, cocoons or the passive-income core. */
/datum/action/cooldown/alien/brood_repair
	name = "Восстановить смолу"
	desc = "Восстанавливает 40 прочности смоляной стены, двери или подготовленного гнезда за 3 секунды и 20 плазмы."
	button_icon_state = "alien_resin"
	plasma_cost = 20
	cooldown_time = 8 SECONDS
	click_to_activate = TRUE
	/// Prevents a second channel while the first has not yet spent plasma.
	var/repairing = FALSE
	/// Kept short in the focused interruption scenario.
	var/repair_time = 3 SECONDS

/datum/action/cooldown/alien/brood_repair/proc/can_repair(mob/living/carbon/alien/brood/worker, obj/structure/target)
	return !QDELETED(src) && !QDELETED(worker) && owner == worker && worker.type == /mob/living/carbon/alien/brood && !worker.incapacitated && worker.getPlasma() >= plasma_cost && !QDELETED(target) && (istype(target, /obj/structure/alien/resin) || istype(target, /obj/structure/bed/nest/banda)) && worker.Adjacent(target) && isturf(worker.loc) && target.get_integrity() < target.max_integrity

/datum/action/cooldown/alien/brood_repair/Activate(atom/target)
	var/mob/living/carbon/alien/brood/worker = owner
	if(repairing || !can_repair(worker, target))
		return FALSE
	repairing = TRUE
	var/ready = do_after(worker, repair_time, target = target, extra_checks = CALLBACK(src, PROC_REF(can_repair), worker, target))
	repairing = FALSE
	if(!ready || !can_repair(worker, target))
		return FALSE
	var/obj/structure/resin = target
	resin.repair_damage(40)
	worker.do_attack_animation(resin)
	StartCooldown()
	return TRUE

/** A visible, temporary mark supports coordination without revealing prey through walls. */
/datum/action/cooldown/alien/brood_mark
	name = "Феромонная метка"
	desc = "Отмечает живую добычу на 12 секунд и сообщает её область рою. Не раскрывает её через стены."
	button_icon_state = "alien_whisper"
	plasma_cost = 20
	cooldown_time = 15 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/alien/brood_mark/Activate(atom/target)
	if(!istype(owner, /mob/living/carbon/alien/brood/scout) || !isliving(target) || isalien(target) || !(target in view(6, owner)))
		return FALSE
	var/mob/living/prey = target
	if(prey.stat == DEAD)
		return FALSE
	prey.apply_status_effect(/datum/status_effect/xeno_brood_mark)
	var/mob/living/carbon/alien/scout = owner
	scout.alien_talk("Отмечена добыча: [prey.name]. Область: [get_area(prey)].")
	StartCooldown()
	return TRUE

/datum/status_effect/xeno_brood_mark
	id = "xeno_brood_mark"
	duration = 12 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	on_remove_on_mob_delete = TRUE

/datum/status_effect/xeno_brood_mark/on_apply()
	owner.add_filter("xeno_brood_mark", 2, outline_filter(size = 2, color = "#ef9655"))
	owner.balloon_alert(owner, "феромонная метка!")
	return TRUE

/datum/status_effect/xeno_brood_mark/on_remove()
	owner.remove_filter("xeno_brood_mark")
