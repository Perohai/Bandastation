/** A pulsing glow following the owner's silhouette, shared by fruit buffs and empowerment. */
/datum/status_effect/xeno_aura
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// Color of this buff's glow, including the outside of the current mob sprite.
	var/aura_color = "#68467a"

/datum/status_effect/xeno_aura/on_apply()
	if(!isalien(owner))
		return FALSE
	owner.add_filter("xeno_aura_[id]", 2, drop_shadow_filter(size = 2, offset = 1, color = aura_color))
	owner.transition_filter_chain(
		"xeno_aura_[id]", INDEFINITE,
		filter_chain_step(list("size" = 2.5), 0.8 SECONDS, SINE_EASING),
		filter_chain_step(list("size" = 1.5), 0.8 SECONDS, SINE_EASING),
	)
	return TRUE

/datum/status_effect/xeno_aura/on_remove()
	owner.remove_filter("xeno_aura_[id]")

/** Выращивает на траве плод для поддержки улья. Только дроны могут собирать плоды и кормить ими союзников. */
/datum/action/cooldown/alien/banda/grow_fruit
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "grow_fruit"
	name = "Вырастить смоляной плод"
	desc = "Выращивает плод за 200 плазмы. Он созревает через 90 секунд. Собирать плоды и кормить ими союзников могут только дроны."
	plasma_cost = 200
	click_to_activate = TRUE
	/// Player-facing fruit choices and their server-side type allowlist.
	var/static/list/fruit_types = list(
		"Нестабильный" = /obj/item/xeno_fruit/unstable,
		"Крупный" = /obj/item/xeno_fruit/greater,
		"Споровый" = /obj/item/xeno_fruit/spore,
		"Стремительности" = /obj/item/xeno_fruit/alacrity,
		"Крови" = /obj/item/xeno_fruit/cruor,
	)

/** Validate the selected weeded turf against overlapping fruit growth. */
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
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_resin_move2.ogg', 50, TRUE)
	return TRUE

/** Питательный плод из смолы ксеноморфов. */
/obj/item/xeno_fruit
	abstract_type = /obj/item/xeno_fruit
	name = "resin fruit"
	desc = "Питательный плод, выращенный из смолы ксеноморфов."
	icon = 'modular_bandastation/xeno_rework/icons/items/resin_fruits.dmi'
	icon_state = "unstable_immature"
	inhand_icon_state = "unstable"
	lefthand_file = 'modular_bandastation/xeno_rework/icons/items/fruit_inhands.dmi'
	righthand_file = 'modular_bandastation/xeno_rework/icons/items/fruit_inhands.dmi'
	anchored = TRUE
	alpha = 140
	w_class = WEIGHT_CLASS_SMALL
	/// Whether the fruit can be harvested or consumed.
	var/ripe = FALSE
	/// Delay between planting and ripening.
	var/growth_time = 90 SECONDS
	/// Owned healing component, removed when the fruit leaves its turf.
	var/datum/component/aura_healing/pheromones
	/// Prevents simultaneous consumption of one fruit.
	var/being_consumed = FALSE

/obj/item/xeno_fruit/Initialize(mapload)
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(ripen)), growth_time)

/obj/item/xeno_fruit/Destroy()
	QDEL_NULL(pheromones)
	return ..()

/** Mature the fruit and enable any stationary pheromone component. */
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
	if(being_consumed || !ripe || !istype(user, /mob/living/carbon/alien/adult/banda/drone) || !istype(target, /mob/living/carbon/alien/adult/banda) || !user.is_holding(src) || !user.Adjacent(target))
		return
	being_consumed = TRUE
	user.visible_message(span_notice("[user] подносит [src] к [target], собираясь накормить."), span_notice("Вы подносите [src] к [target], собираясь накормить."))
	if(!do_after(user, 2 SECONDS, target = target) || QDELETED(src))
		if(!QDELETED(src))
			being_consumed = FALSE
		return
	if(!ripe || !istype(user, /mob/living/carbon/alien/adult/banda/drone) || !istype(target, /mob/living/carbon/alien/adult/banda) || !user.is_holding(src) || !user.Adjacent(target))
		being_consumed = FALSE
		return
	user.do_attack_animation(target, ATTACK_EFFECT_BOOP)
	apply_fruit(target)
	playsound(target, 'sound/mobs/non-humanoids/alien/alien_eat.ogg', 45, TRUE)
	qdel(src)

/obj/item/xeno_fruit/attack_self(mob/user, list/modifiers)
	return attack(user, user, modifiers)

/** Apply the subtype-specific fruit benefit to a validated recipient. */
/obj/item/xeno_fruit/proc/feed(mob/living/carbon/alien/adult/banda/target)
	return

/** Remove previous fruit benefits before applying this fruit. */
/obj/item/xeno_fruit/proc/apply_fruit(mob/living/carbon/alien/adult/banda/target)
	for(var/datum/status_effect/effect as anything in target.status_effects?.Copy())
		if(istype(effect, /datum/status_effect/xeno_fruit_effect) || istype(effect, /datum/status_effect/xeno_overshield/fruit))
			qdel(effect)
	feed(target)

/** Fruit granting an overshield and brief regeneration. */
/obj/item/xeno_fruit/unstable
	icon_state = "unstable_immature"
	inhand_icon_state = "unstable"
	name = "unstable resin fruit"

/obj/item/xeno_fruit/unstable/feed(mob/living/carbon/alien/adult/banda/target)
	target.apply_status_effect(/datum/status_effect/xeno_overshield/fruit, min(200, target.maxHealth * 0.3))
	target.apply_status_effect(/datum/status_effect/xeno_fruit_regen/unstable, 5, 0, 15 SECONDS)

/** Fruit granting immediate healing and a short regeneration effect. */
/obj/item/xeno_fruit/greater
	icon_state = "greater_immature"
	inhand_icon_state = "greater"
	name = "greater resin fruit"

/obj/item/xeno_fruit/greater/feed(mob/living/carbon/alien/adult/banda/target)
	target.heal_ordered_damage(75, list(BRUTE, BURN))
	target.apply_status_effect(/datum/status_effect/xeno_fruit_regen, 20, 0, 5 SECONDS)

/** Stationary healing fruit which grants a combat cooldown benefit when eaten. */
/obj/item/xeno_fruit/spore
	icon_state = "spore_immature"
	inhand_icon_state = "spore"
	name = "spore resin fruit"

/obj/item/xeno_fruit/spore/feed(mob/living/carbon/alien/adult/banda/target)
	target.apply_status_effect(/datum/status_effect/xeno_fruit_haste)

/** Fruit granting a temporary movement bonus. */
/obj/item/xeno_fruit/alacrity
	icon_state = "alacrity_immature"
	inhand_icon_state = "alacrity"
	name = "alacrity resin fruit"

/obj/item/xeno_fruit/alacrity/feed(mob/living/carbon/alien/adult/banda/target)
	target.apply_status_effect(/datum/status_effect/xeno_fruit_speed)

/** Fruit granting plasma regeneration. */
/obj/item/xeno_fruit/cruor
	icon_state = "cruor_immature"
	inhand_icon_state = "cruor"
	name = "cruor resin fruit"

/obj/item/xeno_fruit/cruor/feed(mob/living/carbon/alien/adult/banda/target)
	target.apply_status_effect(/datum/status_effect/xeno_fruit_regen/plasma, 0, 16, 15 SECONDS)

/** Common ancestry used to replace all benefits from a previous fruit. */
/datum/status_effect/xeno_fruit_effect
	parent_type = /datum/status_effect/xeno_aura

/** Frame-independent fruit regeneration with a silhouette aura. */
/datum/status_effect/xeno_fruit_regen
	parent_type = /datum/status_effect/xeno_fruit_effect
	id = "xeno_fruit_regen"
	aura_color = "#8f3b52"
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	/// Healing rate in health points per second.
	var/health_per_second
	/// Plasma restoration rate per second.
	var/plasma_per_second

/datum/status_effect/xeno_fruit_regen/on_apply(health_rate, plasma_rate, effect_duration)
	health_per_second = health_rate
	plasma_per_second = plasma_rate
	duration = effect_duration
	return ..()

/datum/status_effect/xeno_fruit_regen/tick(seconds_between_ticks)
	owner.heal_ordered_damage(health_per_second * seconds_between_ticks, list(BRUTE, BURN))
	var/mob/living/carbon/alien/xeno = owner
	xeno.adjustPlasma(plasma_per_second * seconds_between_ticks)

/** Purple healing aura associated with the unstable fruit. */
/datum/status_effect/xeno_fruit_regen/unstable
	aura_color = "#70428b"

/** Orange plasma-regeneration aura associated with the cruor fruit. */
/datum/status_effect/xeno_fruit_regen/plasma
	id = "xeno_fruit_plasma"
	aura_color = "#986132"

/** Temporary fruit movement bonus, released when the effect ends. */
/datum/status_effect/xeno_fruit_speed
	parent_type = /datum/status_effect/xeno_fruit_effect
	id = "xeno_fruit_speed"
	aura_color = "#8e7b32"
	duration = 15 SECONDS
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	on_remove_on_mob_delete = TRUE

/datum/status_effect/xeno_fruit_speed/on_apply()
	if(!..())
		return FALSE
	owner.add_movespeed_modifier(/datum/movespeed_modifier/xeno_fruit)
	return TRUE

/datum/status_effect/xeno_fruit_speed/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/xeno_fruit)
	return ..()

/** Movement modifier owned by the alacrity fruit benefit. */
/datum/movespeed_modifier/xeno_fruit
	multiplicative_slowdown = -0.4

/** Successful melee hits shorten active ability cooldowns while this fruit benefit lasts. */
/datum/status_effect/xeno_fruit_haste
	parent_type = /datum/status_effect/xeno_fruit_effect
	id = "xeno_fruit_haste"
	aura_color = "#587c32"
	duration = 90 SECONDS
	status_type = STATUS_EFFECT_REPLACE
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

/** Finite damage-absorbing overshield shared by fruit and Ravager abilities. */
/datum/status_effect/xeno_overshield
	parent_type = /datum/status_effect/xeno_aura
	id = "xeno_overshield"
	duration = 1 MINUTES
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// Remaining overshield absorption capacity.
	var/remaining

/datum/status_effect/xeno_overshield/on_apply(shield_amount, effect_duration = 1 MINUTES)
	remaining = shield_amount
	duration = effect_duration
	if(remaining <= 0)
		return FALSE
	return ..()

/** Orange-aura Ravager specialization of the shared overshield. */
/datum/status_effect/xeno_overshield/ravager
	aura_color = "#98562f"

/// Shares the overshield limit, but expires when another fruit is consumed.
/datum/status_effect/xeno_overshield/fruit

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
