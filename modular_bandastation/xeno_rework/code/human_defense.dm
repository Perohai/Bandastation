/// Combat originates from the module's own mob. No human/attack_alien override.
/mob/living/carbon/alien/adult/banda/resolve_unarmed_attack(atom/attack_target, list/modifiers)
	if(!combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK) || !isliving(attack_target))
		return ..()
	if(tgmc_combat)
		return tgmc_melee_hit(attack_target)
	if(!ishuman(attack_target))
		return ..()
	return banda_slash(attack_target)

/mob/living/carbon/alien/adult/banda/proc/banda_slash(mob/living/carbon/human/victim)
	if(QDELETED(victim) || !Adjacent(victim) || HAS_TRAIT(src, TRAIT_PACIFISM))
		return FALSE
	var/damage = rand(melee_damage_lower, melee_damage_upper)
	if(victim.check_block(src, damage, "удар когтями", UNARMED_ATTACK, 10, BRUTE))
		return FALSE
	SEND_SIGNAL(victim, COMSIG_MOB_ATTACK_ALIEN, src, null)
	var/obj/item/bodypart/part = victim.get_bodypart(get_random_valid_zone(zone_selected))
	if(!part)
		part = victim.get_bodypart(BODY_ZONE_CHEST)
	var/armor = victim.run_armor_check(part, MELEE, armour_penetration = 10)
	do_attack_animation(victim)
	playsound(victim, 'sound/items/weapons/slice.ogg', 30, TRUE)
	visible_message(span_danger("[src] наносит [victim] удар когтями!"))
	victim.apply_damage(damage, BRUTE, part, armor, sharpness = SHARP_EDGED)
	log_combat(src, victim, "slashed")
	return TRUE

/mob/living/carbon/alien/adult/banda/resolve_right_click_attack(atom/target, list/modifiers)
	if(!ishuman(target))
		return ..()
	var/mob/living/carbon/human/victim = target
	if(!Adjacent(victim) || victim.check_block(src, 0, "попытку опрокинуть", UNARMED_ATTACK, 0, BRUTE))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	SEND_SIGNAL(victim, COMSIG_MOB_ATTACK_ALIEN, src, modifiers)
	var/obj/item/held = victim.get_active_held_item()
	if(held)
		victim.dropItemToGround(held)
	victim.Knockdown(held ? 3 SECONDS : 1 SECONDS)
	victim.apply_damage(rand(melee_damage_lower, melee_damage_upper) * 1.5, STAMINA)
	do_attack_animation(victim, ATTACK_EFFECT_DISARM)
	log_combat(src, victim, "tackled")
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
