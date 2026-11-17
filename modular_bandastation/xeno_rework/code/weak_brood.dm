/** Player-controlled, deliberately weakened TGMC minions. They never become adult castes. */
/mob/living/carbon/alien/brood
	name = "hive beetle"
	desc = "Маленький жук выводка. Умеет кусаться и таскать тела; таран открывает королева."
	icon = 'modular_bandastation/xeno_rework/icons/brood/beetle.dmi'
	icon_state = "beetle"
	rotate_on_lying = FALSE
	hud_type = /datum/hud/larva
	maxHealth = 35
	health = 35
	hardcrit_threshold = HEALTH_THRESHOLD_CRIT
	melee_damage_lower = 3
	melee_damage_upper = 3
	mob_size = MOB_SIZE_SMALL
	density = FALSE
	pass_flags = PASSTABLE | PASSMOB
	combat_mode = TRUE
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
	/// A vigor purchase changes an existing mob once, without healing it.
	var/brood_upgraded = FALSE
	/// The Beetle's native throw is dangerous only during its unlocked charge.
	var/charging = FALSE
	/// Restore only our temporary collision change when a charge lands.
	var/charge_had_pass_mob = FALSE

/mob/living/carbon/alien/brood/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/banda/sleepytime)
	RegisterSignal(src, COMSIG_LIVING_RESTING, PROC_REF(on_hive_rest))
	RegisterSignal(src, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_hive_stand))
	apply_hive_upgrade()

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
	var/datum/xeno_hive/hive = get_xeno_hive()
	if(!brood_upgraded && hive.purchased["brood_vigor"])
		brood_upgraded = TRUE
		maxHealth += 15
		melee_damage_lower += 2
		melee_damage_upper += 2
		updatehealth()
	var/ability_type
	var/capacity = 100
	var/regeneration = 1
	if(type == /mob/living/carbon/alien/brood && hive.purchased["beetle_charge"])
		ability_type = /datum/action/cooldown/alien/brood_charge
		capacity = 320
		regeneration = 10
	else if(istype(src, /mob/living/carbon/alien/brood/mantis) && hive.purchased["mantis_ravage"])
		ability_type = /datum/action/cooldown/alien/brood_ravage
		capacity = 600
		regeneration = 20
	else if(istype(src, /mob/living/carbon/alien/brood/scorpion))
		ability_type = /datum/action/cooldown/alien/brood_spit
		capacity = 500
		regeneration = hive.purchased["scorpion_spit"] ? 10 : 1
	else if(istype(src, /mob/living/carbon/alien/brood/baneling) && hive.purchased["brood_baneling"])
		ability_type = /datum/action/cooldown/alien/brood_detonate
	if(ability_type && !(locate(ability_type) in actions))
		grant_actions_by_list(list(ability_type))
	var/obj/item/organ/alien/plasmavessel/vessel = get_organ_slot(ORGAN_SLOT_XENO_PLASMAVESSEL)
	if(vessel)
		vessel.max_plasma = capacity
		vessel.plasma_rate = regeneration

/mob/living/carbon/alien/brood/can_unarmed_attack()
	return !resting && !incapacitated

/mob/living/carbon/alien/brood/resolve_unarmed_attack(atom/attack_target, list/modifiers)
	if(resting || incapacitated || !isliving(attack_target) || !Adjacent(attack_target) || attack_target == src || !combat_mode || HAS_TRAIT(src, TRAIT_PACIFISM))
		return
	var/mob/living/victim = attack_target
	if(isalien(victim) || victim.check_block(src, melee_damage_upper, name, attack_type = UNARMED_ATTACK))
		return
	changeNext_move(CLICK_CD_MELEE)
	do_attack_animation(victim, ATTACK_EFFECT_BITE)
	playsound(victim, 'sound/items/weapons/bite.ogg', 55, TRUE)
	victim.visible_message(span_danger("[src] кусает [victim]!"), span_userdanger("[src] кусает вас!"))
	victim.apply_damage(melee_damage_upper, BRUTE, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, MELEE))
	log_combat(src, victim, "bit")

/mob/living/carbon/alien/brood/resolve_right_click_attack(atom/target, list/modifiers)
	return SECONDARY_ATTACK_CALL_NORMAL

/mob/living/carbon/alien/brood/start_pulling(atom/movable/pulled_atom, state, force = pull_force, supress_message = FALSE)
	if(!isliving(pulled_atom) || resting)
		return FALSE
	return ..()

/mob/living/carbon/alien/brood/proc/end_minion_charge()
	charging = FALSE
	remove_filter("minion_charge")
	if(charge_had_pass_mob)
		pass_flags |= PASSMOB
	charge_had_pass_mob = FALSE

/mob/living/carbon/alien/brood/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	if(charging && isliving(hit_atom) && !isalien(hit_atom) && !incapacitated && !resting)
		var/mob/living/victim = hit_atom
		victim.apply_damage(15, BRUTE, BODY_ZONE_CHEST, blocked = victim.getarmor(BODY_ZONE_CHEST, MELEE))
		victim.Knockdown(1 SECONDS)
		log_combat(src, victim, "minion charged")
	charging = FALSE
	return ..()

/obj/item/organ/alien/plasmavessel/brood
	max_plasma = 100
	stored_plasma = 100
	plasma_rate = 1
	heal_rate = 0.25
	actions_types = list()

/mob/living/carbon/alien/brood/mantis
	name = "hive mantis"
	desc = "Маленький богомол выводка. Размашистый удар серпами открывает королева."
	icon = 'modular_bandastation/xeno_rework/icons/brood/mantis.dmi'
	icon_state = "mantis"
	maxHealth = 25
	health = 25
	melee_damage_lower = 4
	melee_damage_upper = 4

/mob/living/carbon/alien/brood/scorpion
	name = "hive scorpion"
	desc = "Маленький скорпион выводка. Плюётся слабой кислотой; королева усиливает плевок."
	icon = 'modular_bandastation/xeno_rework/icons/brood/scorpion.dmi'
	icon_state = "scorpion"
	maxHealth = 25
	health = 25
	melee_damage_lower = 2
	melee_damage_upper = 2

/mob/living/carbon/alien/brood/baneling
	name = "hive baneling"
	desc = "Раздутый кислотой банелинг. После запуска подрыва десять секунд громко предупреждает о взрыве и продолжает двигаться."
	icon = 'modular_bandastation/xeno_rework/icons/brood/baneling.dmi'
	icon_state = "baneling"
	maxHealth = 40
	health = 40
	melee_damage_lower = 1
	melee_damage_upper = 1
