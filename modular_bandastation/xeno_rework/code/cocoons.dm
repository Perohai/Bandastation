/** A prepared resin nest uses native buckling, rescue and embryo sustenance. */
/obj/structure/bed/nest/banda
	desc = "Подготовленное смоляное гнездо. Взрослый ксеноморф может заключить здесь добычу в кокон."
	/// Owned shell, released as soon as the prey is freed.
	var/obj/structure/xeno_cocoon/cocoon
	/// A second adult cannot replace the captive during preparation.
	var/preparing = FALSE

/obj/structure/bed/nest/banda/Destroy()
	QDEL_NULL(cocoon)
	return ..()

/** Validate both before and after preparing the shell, including the physical body. */
/obj/structure/bed/nest/banda/proc/can_cocoon(mob/living/carbon/prey, mob/living/carbon/alien/adult/banda/user)
	return !QDELETED(src) && !QDELETED(prey) && !QDELETED(user) && istype(user) && !user.incapacitated && isturf(user.loc) && user.Adjacent(src) && prey.loc == loc && !prey.buckled && !has_buckled_mobs() && ishuman(prey)

/obj/structure/bed/nest/banda/user_buckle_mob(mob/living/being_buckled, mob/user, check_loc = TRUE)
	if(preparing || !can_cocoon(being_buckled, user))
		return FALSE
	preparing = TRUE
	var/datum/xeno_hive/hive = get_xeno_hive()
	var/duration = hive.cocoon_time * (hive.purchased["capture"] ? 0.5 : 1)
	var/ready = do_after(user, duration, target = being_buckled, extra_checks = CALLBACK(src, PROC_REF(can_cocoon), being_buckled, user))
	preparing = FALSE
	if(!ready || !can_cocoon(being_buckled, user))
		return FALSE
	var/datum/component/xeno_biomass_body/body = get_xeno_biomass_body(being_buckled)
	if(!body || !buckle_mob(being_buckled))
		return FALSE
	cocoon = new(loc, src, being_buckled)
	return TRUE

/obj/structure/bed/nest/banda/post_unbuckle_mob(mob/living/being_unbuckled)
	. = ..()
	QDEL_NULL(cocoon)

/** The shell never owns the body: destroying it rescues the captive. */
/obj/structure/xeno_cocoon
	name = "resin cocoon"
	desc = "Смоляная оболочка удерживает тело на гнезде. Её можно разрушить или разорвать рукой, освободив пленника."
	icon = 'icons/mob/nonhuman-player/alien.dmi'
	icon_state = "nestoverlay"
	anchored = TRUE
	density = FALSE
	max_integrity = 100
	layer = ABOVE_MOB_LAYER
	/// Nest owns this shell; both references are released on teardown.
	var/obj/structure/bed/nest/banda/nest
	/// Captive stays on its turf, allowing normal facehuggers, surgery and rescue.
	var/mob/living/carbon/prey
	/// Processing is continuous only while a corpse remains secured without an embryo.
	var/processed_time = 0
	/// Final animation remains cancellable by unbuckling or revival.
	var/dissolving = FALSE
	/// Restored on rescue, including rescue during dissolution.
	var/prey_alpha

/obj/structure/xeno_cocoon/Initialize(mapload, obj/structure/bed/nest/banda/nest, mob/living/carbon/prey)
	. = ..()
	src.nest = nest
	src.prey = prey
	if(!nest || !prey)
		return INITIALIZE_HINT_QDEL
	prey_alpha = prey.alpha
	RegisterSignal(prey, COMSIG_QDELETING, PROC_REF(prey_deleted))
	START_PROCESSING(SSobj, src)

/obj/structure/xeno_cocoon/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(!QDELETED(prey))
		UnregisterSignal(prey, COMSIG_QDELETING)
		animate(prey, alpha = prey_alpha, time = 0)
	if(!QDELETED(nest))
		nest.cocoon = null
		if(prey?.buckled == nest)
			nest.unbuckle_mob(prey)
	prey = null
	nest = null
	return ..()

/obj/structure/xeno_cocoon/proc/prey_deleted(datum/source)
	SIGNAL_HANDLER
	prey = null
	qdel(src)

/obj/structure/xeno_cocoon/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || QDELETED(nest) || QDELETED(prey) || !user.Adjacent(src) || user.incapacitated)
		return
	return nest.user_unbuckle_mob(prey, user)

/** Rescuers can remove the body throughout the final dissolution animation. */
/obj/structure/xeno_cocoon/process(seconds_per_tick)
	if(QDELETED(nest) || QDELETED(prey) || prey.buckled != nest || prey.loc != loc || nest.loc != loc)
		qdel(src)
		return
	if(prey.stat != DEAD || prey.get_organ_by_type(/obj/item/organ/body_egg/alien_embryo))
		processed_time = 0
		dissolving = FALSE
		animate(prey, alpha = prey_alpha, time = 0)
		return
	var/datum/xeno_hive/hive = get_xeno_hive()
	var/duration = hive.processing_time * (hive.purchased["processing"] ? 0.8 : 1)
	processed_time += seconds_per_tick * 1 SECONDS
	if(processed_time < duration)
		return
	if(!dissolving)
		dissolving = TRUE
		animate(prey, alpha = 0, time = 2 SECONDS)
		return
	if(processed_time < duration + 2 SECONDS)
		return
	var/datum/component/xeno_biomass_body/body = prey.GetComponent(/datum/component/xeno_biomass_body)
	body?.pay("processing")
	prey.drop_all_held_items()
	for(var/obj/item/item as anything in prey.get_equipped_items())
		prey.dropItemToGround(item, force = TRUE)
	prey.visible_message(span_warning("Тело в [src] растворяется в смоле."))
	qdel(prey)
