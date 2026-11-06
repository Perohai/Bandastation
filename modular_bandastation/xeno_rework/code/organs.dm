/// These organs are used only by the module's own mobs.
/obj/item/organ/alien/resinspinner_banda
	name = "resin spinner"
	desc = "An organ that secretes resin for constructing alien structures."
	icon_state = "spinner-x"
	zone = BODY_ZONE_PRECISE_MOUTH
	slot = ORGAN_SLOT_XENO_RESINSPINNER
	actions_types = list(/datum/action/cooldown/alien/select_resin_structure, /datum/action/cooldown/alien/build_resin_structure)

/// A transport stomach, deliberately separate from TG's /stomach/alien.
/obj/item/organ/stomach/alien_banda
	name = "alien stomach"
	desc = "A stomach adapted for transporting captured prey."
	icon_state = "stomach-x"
	w_class = WEIGHT_CLASS_BULKY
	actions_types = list(/datum/action/cooldown/alien/regurgitate_banda)
	organ_traits = list(TRAIT_STRONG_STOMACH)
	var/escape_time = 90 SECONDS
	var/resist_interval = 1.5 SECONDS
	var/resist_grace = 3 SECONDS
	var/unarmed_resist_damage = 2
	/// Replaces the old 20% full-force lottery with deterministic scaled damage.
	var/weapon_resist_multiplier = 0.2
	var/turf/last_safe_turf
	var/releasing = FALSE

/obj/item/organ/stomach/alien_banda/stomach_acid_power(atom/movable/nomnom, seconds_per_tick)
	return 0

/obj/item/organ/stomach/alien_banda/on_mob_insert(mob/living/carbon/stomach_owner, special, movement_flags)
	. = ..()
	last_safe_turf = get_turf(stomach_owner)
	RegisterSignal(stomach_owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
	RegisterSignal(stomach_owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_moved))

/obj/item/organ/stomach/alien_banda/proc/on_owner_moved()
	SIGNAL_HANDLER
	var/turf/current_turf = get_turf(owner)
	if(current_turf)
		last_safe_turf = current_turf

/obj/item/organ/stomach/alien_banda/proc/on_owner_death()
	SIGNAL_HANDLER
	empty_contents()

/obj/item/organ/stomach/alien_banda/on_mob_remove(mob/living/carbon/stomach_owner, special, movement_flags)
	// owner is already null here; the former owner is supplied as an argument.
	var/turf/former_turf = get_turf(stomach_owner)
	if(former_turf)
		last_safe_turf = former_turf
	empty_contents()
	UnregisterSignal(stomach_owner, list(COMSIG_LIVING_DEATH, COMSIG_MOVABLE_MOVED))
	return ..()

/obj/item/organ/stomach/alien_banda/Destroy()
	// Parent stomach destruction qdels anything still in stomach_contents.
	empty_contents()
	return ..()

/obj/item/organ/stomach/alien_banda/consume_thing(atom/movable/thing)
	if(QDELETED(thing) || !isliving(thing) || !istype(owner, /mob/living/carbon/alien/adult/banda))
		return FALSE
	var/turf/location = get_turf(owner)
	if(!location || thing == owner || (thing in stomach_contents) || thing.GetComponent(/datum/component/banda_swallowed))
		return FALSE
	last_safe_turf = location
	. = ..()
	if(!.)
		return FALSE
	thing.forceMove(src)
	var/mob/living/victim = thing
	if(victim.stat != DEAD)
		victim.AddComponent(/datum/component/banda_swallowed, src)
		var/datum/component/banda_swallowed/state = victim.GetComponent(/datum/component/banda_swallowed)
		to_chat(victim, span_userdanger("ПРОГЛОЧЕН! МОЖНО СОПРОТИВЛЯТЬСЯ!"))
		to_chat(victim, span_boldnotice("[state.resist_prompt()] Либо двигайся клавишами движения. Шкала выхода находится внизу экрана; на неё тоже можно нажимать."))
		to_chat(victim, span_warning("Для выхода требуется [stomach_escape_seconds()] секунд активной борьбы. Пауза более [resist_grace / (1 SECONDS)] секунд сбрасывает прогресс. Частые нажатия не ускоряют выход. Стрельба недоступна."))
	return TRUE

/obj/item/organ/stomach/alien_banda/proc/stomach_escape_seconds()
	return escape_time / (1 SECONDS)

/obj/item/organ/stomach/alien_banda/content_moved(atom/movable/source)
	. = ..()
	if(source.loc == src || source.loc == owner)
		return
	remove_custody(source)

/obj/item/organ/stomach/alien_banda/proc/remove_custody(atom/movable/thing)
	var/datum/component/banda_swallowed/state = thing.GetComponent(/datum/component/banda_swallowed)
	if(state?.stomach_ref?.resolve() == src)
		qdel(state)

/obj/item/organ/stomach/alien_banda/relaymove(mob/living/user, direction)
	if(!(user in stomach_contents) || user.loc != src)
		return
	var/datum/component/banda_swallowed/state = user.GetComponent(/datum/component/banda_swallowed)
	state?.struggle()

// Both TG revisions route the ordinary Resist action to the current container.
/obj/item/organ/stomach/alien_banda/container_resist_act(mob/living/user)
	relaymove(user, NONE)

/obj/item/organ/stomach/alien_banda/proc/damage_from_inside(mob/living/victim, obj/item/weapon)
	var/mob/living/carbon/alien/adult/banda/host = owner
	if(!istype(host) || host.stat == DEAD || victim.loc != src)
		return
	var/damage = weapon ? max(0, weapon.force * weapon_resist_multiplier) : unarmed_resist_damage
	var/armor = host.run_armor_check(BODY_ZONE_CHEST, MELEE, silent = TRUE)
	if(damage > 0)
		host.apply_damage(damage, BRUTE, BODY_ZONE_CHEST, armor, wound_bonus = CANT_WOUND, attacking_item = weapon)
		log_combat(victim, host, "struggled from inside stomach", weapon)
	if(weapon?.hitsound)
		playsound(host, weapon.hitsound, 35, TRUE)
	else
		playsound(host, 'sound/items/weapons/punch1.ogg', 25, TRUE)
	victim.do_attack_animation(host)

/obj/item/organ/stomach/alien_banda/proc/release_victim(atom/movable/thing)
	if(QDELETED(thing) || !(thing in stomach_contents))
		return FALSE
	var/turf/destination = get_turf(owner) || get_turf(src) || last_safe_turf
	if(!destination)
		destination = locate(1, 1, 1)
	if(!destination)
		stack_trace("No safe turf while releasing [thing] from [src]")
		return FALSE
	remove_custody(thing)
	thing.forceMove(destination)
	LAZYREMOVE(stomach_contents, thing)
	return TRUE

/obj/item/organ/stomach/alien_banda/empty_contents(chance = 100, damaging = FALSE, min_amount = 0)
	if(releasing || !length(stomach_contents))
		return 0
	releasing = TRUE
	var/released = 0
	// Movement callbacks mutate the original list.
	for(var/atom/movable/thing as anything in stomach_contents.Copy())
		if(release_victim(thing))
			released++
	releasing = FALSE
	return released

/obj/item/organ/stomach/alien_banda/on_vomit(mob/living/carbon/vomiter, distance, force)
	empty_contents()

/datum/action/cooldown/alien/regurgitate_banda
	name = "Regurgitate"
	desc = "Безопасно освобождает всё содержимое желудка."
	button_icon_state = "alien_barf"

/datum/action/cooldown/alien/regurgitate_banda/IsAvailable(feedback = FALSE)
	return ..() && istype(owner, /mob/living/carbon/alien/adult/banda)

/datum/action/cooldown/alien/regurgitate_banda/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/host = owner
	var/obj/item/organ/stomach/alien_banda/stomach = host.get_organ_slot(ORGAN_SLOT_STOMACH)
	if(!istype(stomach) || !length(stomach.stomach_contents))
		return FALSE
	host.visible_message(span_warning("[host] извергает содержимое желудка!"))
	playsound(host, 'sound/mobs/non-humanoids/alien/alien_york.ogg', 70)
	return stomach.empty_contents() > 0
