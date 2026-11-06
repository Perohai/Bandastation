/// TG's devour implementation and organ type checks remain untouched.
/mob/living/carbon/alien/adult/banda/devour_lad(atom/movable/candidate, devour_time = 13.5 SECONDS)
	if(QDELETED(candidate) || !isliving(candidate) || !isturf(loc) || !Adjacent(candidate))
		return FALSE
	setDir(get_dir(src, candidate))
	if(!can_consume(candidate))
		return FALSE
	var/obj/item/organ/stomach/alien_banda/stomach = get_organ_slot(ORGAN_SLOT_STOMACH)
	if(!istype(stomach))
		return FALSE
	visible_message(span_danger("[src] пытается проглотить [candidate]!"))
	if(!do_after(src, devour_time, target = candidate, extra_checks = CALLBACK(src, PROC_REF(can_consume), candidate)))
		return TRUE
	if(QDELETED(candidate) || !can_consume(candidate) || !Adjacent(candidate) || !isturf(loc))
		return TRUE
	if(QDELETED(stomach) || stomach.owner != src || get_organ_slot(ORGAN_SLOT_STOMACH) != stomach)
		return TRUE
	if(stomach.consume_thing(candidate))
		stop_pulling()
		log_combat(src, candidate, "devoured into banda stomach")
		playsound(src, 'sound/mobs/non-humanoids/alien/alien_eat.ogg', 70)
	return TRUE

/mob/living/carbon/alien/adult/banda/proc/release_swallowed()
	var/obj/item/organ/stomach/alien_banda/stomach = get_organ_slot(ORGAN_SLOT_STOMACH)
	if(istype(stomach))
		stomach.empty_contents()

/mob/living/carbon/alien/adult/banda/Destroy()
	release_swallowed()
	tgmc_armors = null
	return ..()
