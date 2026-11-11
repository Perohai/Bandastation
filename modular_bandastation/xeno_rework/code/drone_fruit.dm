/datum/action/cooldown/alien/banda/grow_fruit
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "grow_fruit"
	name = "Вырастить смоляной фрукт"
	desc = "Выращивает на траве плод для поддержки улья. Только дроны могут собирать плоды и кормить ими союзников."
	plasma_cost = 100
	click_to_activate = TRUE
	var/static/list/fruit_types = list(
		"Нестабильный" = /obj/item/xeno_fruit/unstable,
		"Большой" = /obj/item/xeno_fruit/greater,
		"Споровый" = /obj/item/xeno_fruit/spore,
		"Алакрита" = /obj/item/xeno_fruit/alacrity,
		"Круора" = /obj/item/xeno_fruit/cruor,
	)

/datum/action/cooldown/alien/banda/grow_fruit/proc/can_grow(turf/location)
	return istype(owner, /mob/living/carbon/alien/adult/banda/drone) && isturf(owner.loc) && isopenturf(location) && owner.Adjacent(location) && (locate(/obj/structure/alien/weeds) in location) && !(locate(/obj/item/xeno_fruit) in location)

/datum/action/cooldown/alien/banda/grow_fruit/Activate(atom/target)
	var/turf/location = get_turf(target)
	if(!can_grow(location))
		return FALSE
	var/choice = tgui_input_list(owner, "Выберите плод", name, fruit_types)
	if(QDELETED(src) || QDELETED(owner) || !IsAvailable() || !can_grow(location) || !(choice in fruit_types))
		return FALSE
	var/fruit_type = fruit_types[choice]
	new fruit_type(location)
	return TRUE

/obj/item/xeno_fruit
	abstract_type = /obj/item/xeno_fruit
	name = "resin fruit"
	desc = "Питательный плод из смолы ксеноморфов."
	icon = 'modular_bandastation/xeno_rework/icons/resin_fruits.dmi'
	icon_state = "unstable_immature"
	inhand_icon_state = "unstable"
	lefthand_file = 'modular_bandastation/xeno_rework/icons/fruit_inhands.dmi'
	righthand_file = 'modular_bandastation/xeno_rework/icons/fruit_inhands.dmi'
	anchored = TRUE
	alpha = 140
	w_class = WEIGHT_CLASS_SMALL
	var/ripe = FALSE
	var/growth_time = 30 SECONDS
	var/datum/component/aura_healing/pheromones

/obj/item/xeno_fruit/Initialize(mapload)
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(ripen)), growth_time)

/obj/item/xeno_fruit/Destroy()
	QDEL_NULL(pheromones)
	return ..()

/obj/item/xeno_fruit/proc/ripen()
	ripe = TRUE
	icon_state = inhand_icon_state
	alpha = 255
	if(istype(src, /obj/item/xeno_fruit/spore) && isturf(loc))
		pheromones = AddComponent(/datum/component/aura_healing, range = 3, brute_heal = 0.5, burn_heal = 0.5, limit_to_trait = TRAIT_XENO_HEAL_AURA)

/obj/item/xeno_fruit/attack_hand(mob/user, list/modifiers)
	if(!istype(user, /mob/living/carbon/alien/adult/banda/drone) || !ripe)
		return
	anchored = FALSE
	return ..()

/obj/item/xeno_fruit/attack_alien(mob/living/carbon/alien/user, list/modifiers)
	return attack_hand(user, modifiers)

/obj/item/xeno_fruit/attempt_pickup(mob/living/user, skip_grav = FALSE)
	if(!ripe || !istype(user, /mob/living/carbon/alien/adult/banda/drone))
		return TRUE
	return ..()

/obj/item/xeno_fruit/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(!isturf(loc))
		QDEL_NULL(pheromones)

/obj/item/xeno_fruit/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ripe || !istype(user, /mob/living/carbon/alien/adult/banda/drone) || !istype(target, /mob/living/carbon/alien/adult/banda) || !user.is_holding(src) || !user.Adjacent(target))
		return
	feed(target)
	qdel(src)

/obj/item/xeno_fruit/attack_self(mob/user, list/modifiers)
	return attack(user, user, modifiers)

/obj/item/xeno_fruit/proc/feed(mob/living/carbon/alien/adult/banda/target)
	return

/obj/item/xeno_fruit/unstable
	icon_state = "unstable_immature"
	inhand_icon_state = "unstable"
	name = "unstable resin fruit"
	growth_time = 45 SECONDS

/obj/item/xeno_fruit/unstable/feed(mob/living/carbon/alien/adult/banda/target)
	target.apply_status_effect(/datum/status_effect/xeno_overshield, min(200, target.maxHealth * 0.3))
	target.apply_status_effect(/datum/status_effect/xeno_fruit_regen, 5, 0, 15 SECONDS)

/obj/item/xeno_fruit/greater
	icon_state = "greater_immature"
	inhand_icon_state = "greater"
	name = "greater resin fruit"
	growth_time = 30 SECONDS

/obj/item/xeno_fruit/greater/feed(mob/living/carbon/alien/adult/banda/target)
	target.heal_ordered_damage(75, list(BRUTE, BURN))
	target.apply_status_effect(/datum/status_effect/xeno_fruit_regen, 20, 0, 5 SECONDS)

/obj/item/xeno_fruit/spore
	icon_state = "spore_immature"
	inhand_icon_state = "spore"
	name = "spore resin fruit"
	growth_time = 15 SECONDS

/obj/item/xeno_fruit/spore/feed(mob/living/carbon/alien/adult/banda/target)
	target.apply_status_effect(/datum/status_effect/xeno_fruit_haste)

/obj/item/xeno_fruit/alacrity
	icon_state = "alacrity_immature"
	inhand_icon_state = "alacrity"
	name = "alacrity resin fruit"
	growth_time = 35 SECONDS

/obj/item/xeno_fruit/alacrity/feed(mob/living/carbon/alien/adult/banda/target)
	target.apply_status_effect(/datum/status_effect/xeno_fruit_speed)

/obj/item/xeno_fruit/cruor
	icon_state = "cruor_immature"
	inhand_icon_state = "cruor"
	name = "cruor resin fruit"
	growth_time = 25 SECONDS

/obj/item/xeno_fruit/cruor/feed(mob/living/carbon/alien/adult/banda/target)
	target.apply_status_effect(/datum/status_effect/xeno_fruit_regen/plasma, 0, 16, 15 SECONDS)

/datum/status_effect/xeno_fruit_regen
	id = "xeno_fruit_regen"
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	var/health_per_second
	var/plasma_per_second

/datum/status_effect/xeno_fruit_regen/on_apply(health_rate, plasma_rate, effect_duration)
	health_per_second = health_rate
	plasma_per_second = plasma_rate
	duration = effect_duration
	return isalien(owner)

/datum/status_effect/xeno_fruit_regen/tick(seconds_between_ticks)
	owner.heal_ordered_damage(health_per_second * seconds_between_ticks, list(BRUTE, BURN))
	var/mob/living/carbon/alien/xeno = owner
	xeno.adjustPlasma(plasma_per_second * seconds_between_ticks)

/datum/status_effect/xeno_fruit_regen/plasma
	id = "xeno_fruit_plasma"

/datum/status_effect/xeno_fruit_speed
	id = "xeno_fruit_speed"
	duration = 15 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	on_remove_on_mob_delete = TRUE

/datum/status_effect/xeno_fruit_speed/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/xeno_fruit)
	return TRUE

/datum/status_effect/xeno_fruit_speed/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/xeno_fruit)

/datum/movespeed_modifier/xeno_fruit
	multiplicative_slowdown = -0.4

/datum/status_effect/xeno_fruit_haste
	id = "xeno_fruit_haste"
	duration = 90 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null

/mob/living/carbon/alien/adult/banda/resolve_unarmed_attack(atom/target, list/modifiers)
	if(!has_status_effect(/datum/status_effect/xeno_fruit_haste) || !isliving(target) || isalien(target))
		return ..()
	var/mob/living/victim = target
	var/old_damage = victim.get_brute_loss() + victim.get_fire_loss()
	. = ..()
	if(victim.get_brute_loss() + victim.get_fire_loss() <= old_damage)
		return
	for(var/datum/action/cooldown/action in actions)
		if(action.next_use_time > world.time)
			action.StartCooldownSelf((action.next_use_time - world.time) * 0.95)

/datum/status_effect/xeno_overshield
	id = "xeno_overshield"
	duration = 1 MINUTES
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	on_remove_on_mob_delete = TRUE
	var/remaining
	var/mutable_appearance/aura

/datum/status_effect/xeno_overshield/on_apply(shield_amount, effect_duration = 1 MINUTES)
	remaining = shield_amount
	duration = effect_duration
	if(!isalien(owner) || remaining <= 0)
		return FALSE
	aura = mutable_appearance('modular_bandastation/xeno_rework/icons/xeno_auras.dmi', "shield")
	RegisterSignal(owner, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(append_aura))
	owner.update_appearance(UPDATE_OVERLAYS)
	return TRUE

/datum/status_effect/xeno_overshield/proc/append_aura(datum/source, list/overlays)
	SIGNAL_HANDLER
	overlays += aura

/datum/status_effect/xeno_overshield/on_remove()
	UnregisterSignal(owner, COMSIG_ATOM_UPDATE_OVERLAYS)
	owner.update_appearance(UPDATE_OVERLAYS)
	QDEL_NULL(aura)

/mob/living/carbon/alien/adult/banda/apply_damage(damage = 0, damagetype = BRUTE, def_zone = null, blocked = 0, forced = FALSE, spread_damage = FALSE, wound_bonus = 0, exposed_wound_bonus = 0, sharpness = NONE, attack_direction = null, attacking_item, wound_clothing = TRUE)
	var/datum/status_effect/xeno_overshield/shield = has_status_effect(/datum/status_effect/xeno_overshield)
	if(shield && !forced && damage > 0 && (damagetype == BRUTE || damagetype == BURN) && !HAS_TRAIT(src, TRAIT_GODMODE))
		// shortcut: assumes xeno damage modifiers are independent of hit size; update absorption before adding a size-dependent modifier.
		var/modifier = max(0, (100 - blocked - damage_resistance) / 100) * get_incoming_damage_modifier(damage, damagetype, def_zone, sharpness, attack_direction, attacking_item)
		if(modifier > 0)
			var/absorbed = min(shield.remaining, damage * modifier)
			shield.remaining -= absorbed
			damage -= absorbed / modifier
			if(shield.remaining <= 0)
				qdel(shield)
	return ..()
