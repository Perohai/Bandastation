/** Stacked intoxication which can be removed by resisting or washing. */
/datum/status_effect/stacking/xeno_intoxication
	id = "xeno_intoxication"
	status_type = STATUS_EFFECT_REFRESH
	max_stacks = 30
	stack_threshold = 20
	stack_decay = 0
	consumed_on_threshold = FALSE
	on_remove_on_mob_delete = TRUE
	/// Owned visual representation of intoxication stacks.
	var/mutable_appearance/stack_display
	/// Alternating visibility of the critical intoxication warning.
	var/blink = FALSE

/datum/status_effect/stacking/xeno_intoxication/can_have_status()
	return !isalien(owner) && ..()

/datum/status_effect/stacking/xeno_intoxication/on_apply()
	if(!..())
		return FALSE
	RegisterSignal(owner, COMSIG_LIVING_RESIST, PROC_REF(clear_intoxication))
	RegisterSignal(owner, COMSIG_ATOM_EXPOSE_REAGENTS, PROC_REF(wash_intoxication))
	RegisterSignal(owner, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(append_overlay))
	stack_display = mutable_appearance('modular_bandastation/xeno_rework/icons/xeno_effects.dmi', "intox_low", appearance_flags = RESET_COLOR|RESET_TRANSFORM)
	stack_display.maptext_width = 32
	stack_display.maptext_height = 16
	stack_display.maptext_y = -7
	stack_display.pixel_y = -12
	return TRUE

/datum/status_effect/stacking/xeno_intoxication/refresh(effect, new_stacks)
	add_stacks(new_stacks)

/datum/status_effect/stacking/xeno_intoxication/add_stacks(stacks_added)
	. = ..()
	if(!QDELETED(src))
		update_display()

/** Rebuild the intoxication warning for the current stack count. */
/datum/status_effect/stacking/xeno_intoxication/proc/update_display()
	stack_display.icon_state = stacks >= 20 ? "intox_critical" : stacks >= 15 ? "intox_high" : stacks >= 10 ? "intox_medium" : "intox_low"
	stack_display.maptext = MAPTEXT("<center><font color='#89ff40'>[stacks]</font></center>")
	stack_display.alpha = stacks >= stack_threshold && blink ? 80 : 255
	owner.update_appearance(UPDATE_OVERLAYS)

/datum/status_effect/stacking/xeno_intoxication/tick(seconds_between_ticks)
	if(!can_have_status())
		qdel(src)
		return
	owner.adjust_tox_loss(stacks * 0.1 * seconds_between_ticks)
	if(stacks >= stack_threshold)
		blink = !blink
		update_display()

/** Clear intoxication when the victim resists. */
/datum/status_effect/stacking/xeno_intoxication/proc/clear_intoxication(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/** Remove intoxication on direct exposure to water. */
/datum/status_effect/stacking/xeno_intoxication/proc/wash_intoxication(datum/source, list/reagents, datum/reagents/holder, methods)
	SIGNAL_HANDLER
	if(!(methods & (TOUCH|VAPOR)))
		return
	if(locate(/datum/reagent/water) in reagents)
		qdel(src)

/** Append the owned intoxication display during overlay rebuilds. */
/datum/status_effect/stacking/xeno_intoxication/proc/append_overlay(datum/source, list/overlays)
	SIGNAL_HANDLER
	overlays += stack_display

/datum/status_effect/stacking/xeno_intoxication/on_remove()
	UnregisterSignal(owner, list(COMSIG_LIVING_RESIST, COMSIG_ATOM_EXPOSE_REAGENTS, COMSIG_ATOM_UPDATE_OVERLAYS))
	owner.update_appearance(UPDATE_OVERLAYS)
	QDEL_NULL(stack_display)
	return ..()

/** Наносит 5 ожогового урона и добавляет 5 стаков интоксикации. */
/datum/action/cooldown/alien/banda/toxic_spit
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "toxic_spit"
	name = "Плевок токсином"
	desc = "Наносит 5 ожогового урона и добавляет 5 уровней интоксикации."
	plasma_cost = 30
	cooldown_time = 0.5 SECONDS
	click_to_activate = TRUE
	unset_after_click = FALSE

/datum/action/cooldown/alien/banda/toxic_spit/Activate(atom/target)
	if(!isturf(owner.loc) || !target || target.z != owner.z || get_dist(owner, target) > 7)
		return FALSE
	var/obj/projectile/neurotoxin/banda/intoxicating/spit = new(owner.loc)
	spit.aim_projectile(target, owner, list())
	spit.firer = owner
	spit.fire()
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_spitacid.ogg', 70, TRUE)
	StartCooldown()
	return TRUE

/** Spit projectile which applies intoxication on an unblocked hostile hit. */
/obj/projectile/neurotoxin/banda/intoxicating
	damage = 5
	damage_type = BURN

/obj/projectile/neurotoxin/banda/intoxicating/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(isliving(target) && !isalien(target) && blocked < 100)
		var/mob/living/victim = target
		victim.apply_status_effect(/datum/status_effect/stacking/xeno_intoxication, 5)

/** Следующие три удара в течение четырёх секунд добавляют по 5 стаков интоксикации. */
/datum/action/cooldown/alien/banda/toxic_claws
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "toxic_claws"
	name = "Удар с токсином"
	desc = "Следующие три удара за четыре секунды добавляют по 5 уровней интоксикации."
	plasma_cost = 100
	cooldown_time = 20 SECONDS

/datum/action/cooldown/alien/banda/toxic_claws/Activate()
	var/mob/living/xeno = owner
	xeno.apply_status_effect(/datum/status_effect/xeno_toxic_claws)
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_hiss.ogg', 55, TRUE)
	StartCooldown()
	return TRUE

/** Tracks the remaining empowered toxic claw hits. */
/datum/status_effect/xeno_toxic_claws
	id = "xeno_toxic_claws"
	duration = 4 SECONDS
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	/// Remaining empowered claw hits before expiration.
	var/hits_remaining = 3

/mob/living/carbon/alien/adult/banda/sentinel/resolve_unarmed_attack(atom/attack_target, list/modifiers)
	if(!isliving(attack_target))
		return ..()
	var/mob/living/victim = attack_target
	var/old_damage = victim.get_brute_loss() + victim.get_fire_loss()
	. = ..()
	var/datum/status_effect/xeno_toxic_claws/claws = has_status_effect(/datum/status_effect/xeno_toxic_claws)
	if(!claws || isalien(victim) || victim.get_brute_loss() + victim.get_fire_loss() <= old_damage)
		return
	victim.apply_status_effect(/datum/status_effect/stacking/xeno_intoxication, 5)
	claws.hits_remaining--
	if(claws.hits_remaining <= 0)
		qdel(claws)

/** Снимает 30% интоксикации, опрокидывает цель и восстанавливает здоровье и плазму. */
/datum/action/cooldown/alien/banda/toxic_sting
	button_icon = 'modular_bandastation/xeno_rework/icons/new_actions.dmi'
	button_icon_state = "toxic_sting"
	name = "Жалящий удар"
	desc = "Снимает 30% накопленной интоксикации, сбивает цель с ног и восстанавливает здоровье и плазму."
	click_to_activate = TRUE

/datum/action/cooldown/alien/banda/toxic_sting/Activate(atom/target)
	if(!isliving(target) || isalien(target) || !owner.Adjacent(target) || world.time < owner.next_move)
		return FALSE
	var/mob/living/victim = target
	var/datum/status_effect/stacking/xeno_intoxication/intoxication = victim.has_status_effect(/datum/status_effect/stacking/xeno_intoxication)
	if(!intoxication)
		return FALSE
	var/stacks = intoxication.stacks
	owner.changeNext_move(CLICK_CD_MELEE)
	owner.do_attack_animation(victim, ATTACK_EFFECT_CLAW)
	playsound(victim, 'modular_bandastation/xeno_rework/sound/bloodyslice.ogg', 60, TRUE)
	intoxication.add_stacks(-max(1, round(stacks * 0.3)))
	victim.apply_damage(stacks * 1.2, BRUTE)
	// The document's examples are 15 stacks = 0.5s and 30 stacks = 2s.
	victim.Knockdown(max(0.1, stacks / 10 - 1) SECONDS)
	var/mob/living/carbon/alien/xeno = owner
	xeno.heal_ordered_damage(stacks * 6, list(BRUTE, BURN))
	xeno.adjustPlasma(stacks * 21)
	if(stacks >= 20)
		xeno.apply_status_effect(/datum/status_effect/xeno_sting_armor)
	return TRUE

/** Temporary speed and armour benefit after consuming intoxication. */
/datum/armor/xeno_sting
	melee = 10
	bullet = 10
	laser = 10
	energy = 10
	bomb = 10
	bio = 10
	fire = 10
	acid = 10

/** Armour modifier associated with a successful toxic sting. */
/datum/status_effect/xeno_sting_armor
	id = "xeno_sting_armor"
	duration = 10 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	on_remove_on_mob_delete = TRUE

/datum/status_effect/xeno_sting_armor/on_apply()
	owner.add_inner_armor(get_armor_by_type(/datum/armor/xeno_sting))
	return TRUE

/datum/status_effect/xeno_sting_armor/on_remove()
	owner.remove_inner_armor(get_armor_by_type(/datum/armor/xeno_sting))
