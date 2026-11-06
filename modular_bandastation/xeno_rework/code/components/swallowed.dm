/// Per-victim custody state. Vanilla mobs receive no new fields or overrides.
/datum/component/banda_swallowed
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/datum/weakref/stomach_ref
	var/resist_progress = 0
	var/last_resist_time
	var/next_resist_time = 0
	var/blindness_source
	/// Private screen objects; never added to the ordinary TG HUD datum.
	var/list/escape_hud
	var/client/hud_client
	var/progress_reset_at

/datum/component/banda_swallowed/Initialize(obj/item/organ/stomach/alien_banda/stomach)
	if(!isliving(parent) || !istype(stomach))
		return COMPONENT_INCOMPATIBLE
	stomach_ref = WEAKREF(stomach)
	blindness_source = REF(src)
	var/mob/living/victim = parent
	if(victim.stat != DEAD)
		victim.become_blind(blindness_source)
	return ..()

/datum/component/banda_swallowed/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(parent, COMSIG_MOB_CLICKON, PROC_REF(on_click))
	RegisterSignal(parent, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_item_attack))
	RegisterSignal(parent, COMSIG_MOB_ATTACK_RANGED, PROC_REF(on_ranged_attack))
	RegisterSignal(parent, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
	RegisterSignal(parent, COMSIG_MOB_TRYING_TO_FIRE_GUN, PROC_REF(on_fire_gun))
	RegisterSignal(parent, COMSIG_MOB_LOGIN, PROC_REF(on_login))
	RegisterSignal(parent, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))
	on_login()

/datum/component/banda_swallowed/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_MOB_CLICKON, COMSIG_MOB_ITEM_ATTACK, COMSIG_MOB_ATTACK_RANGED, COMSIG_LIVING_EARLY_UNARMED_ATTACK, COMSIG_MOB_TRYING_TO_FIRE_GUN, COMSIG_MOB_LOGIN, COMSIG_MOB_LOGOUT))

/datum/component/banda_swallowed/Destroy(force)
	STOP_PROCESSING(SSfastprocess, src)
	hide_hud()
	QDEL_LIST(escape_hud)
	var/mob/living/victim = parent
	if(victim && blindness_source)
		victim.cure_blind(blindness_source)
	stomach_ref = null
	return ..()

/datum/component/banda_swallowed/proc/get_stomach()
	RETURN_TYPE(/obj/item/organ/stomach/alien_banda)
	var/obj/item/organ/stomach/alien_banda/stomach = stomach_ref?.resolve()
	var/mob/living/victim = parent
	if(!stomach || !victim || victim.loc != stomach || !(victim in stomach.stomach_contents))
		return null
	return stomach

/datum/component/banda_swallowed/proc/on_moved()
	SIGNAL_HANDLER
	if(!get_stomach())
		qdel(src)

/datum/component/banda_swallowed/proc/on_death()
	SIGNAL_HANDLER
	// The corpse remains recoverable; only this victim's restrictions are removed.
	qdel(src)

/datum/component/banda_swallowed/proc/blocks_target(atom/target)
	var/obj/item/organ/stomach/alien_banda/stomach = get_stomach()
	return stomach && (target == stomach || target == stomach.owner)

/datum/component/banda_swallowed/proc/on_click(datum/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(blocks_target(target))
		return COMSIG_MOB_CANCEL_CLICKON

/datum/component/banda_swallowed/proc/on_item_attack(datum/source, mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(blocks_target(target))
		return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/component/banda_swallowed/proc/on_ranged_attack(datum/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(blocks_target(target))
		return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/component/banda_swallowed/proc/on_unarmed_attack(datum/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(blocks_target(target))
		return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/component/banda_swallowed/proc/on_fire_gun()
	SIGNAL_HANDLER
	if(get_stomach())
		return COMPONENT_CANCEL_GUN_FIRE

/// Called both by input and the HUD tick, so an idle bar never shows stale progress.
/datum/component/banda_swallowed/proc/reset_idle_progress()
	var/obj/item/organ/stomach/alien_banda/stomach = get_stomach()
	if(!stomach || isnull(last_resist_time) || world.time - last_resist_time <= stomach.resist_grace)
		return FALSE
	if(resist_progress > 0)
		progress_reset_at = world.time
	resist_progress = 0
	last_resist_time = null
	return TRUE

/// Rate limiting is per victim, independent of keyboard repeat and client delay.
/datum/component/banda_swallowed/proc/struggle()
	var/obj/item/organ/stomach/alien_banda/stomach = get_stomach()
	var/mob/living/victim = parent
	if(!stomach || victim.stat != BANDA_XENO_AWAKE_STAT || victim.incapacitated || world.time < next_resist_time)
		return FALSE
	next_resist_time = world.time + stomach.resist_interval
	reset_idle_progress()
	if(!isnull(last_resist_time))
		resist_progress += min(world.time - last_resist_time, stomach.resist_interval)
	last_resist_time = world.time
	progress_reset_at = null
	// Holding a gun does not prevent bodily resistance or the timed exit.
	var/obj/item/weapon = victim.get_active_held_item()
	if(isgun(weapon))
		weapon = null
	stomach.damage_from_inside(victim, weapon)
	if(QDELETED(src) || !get_stomach())
		return TRUE
	if(resist_progress >= stomach.escape_time)
		stomach.visible_message(span_warning("[victim] вырывается из желудка!"))
		stomach.release_victim(victim)
	else
		update_hud()
	return TRUE
