/// Opt-in reproduction chain. Standard TG eggs, huggers, embryos and larvae
/// continue using their upstream types and actions.
/obj/item/organ/alien/eggsac/banda
	actions_types = list(/datum/action/cooldown/alien/make_structure/lay_egg/banda)

/datum/action/cooldown/alien/make_structure/lay_egg/banda
	made_structure_type = /obj/structure/alien/egg/banda

/obj/structure/alien/egg/banda/Initialize(mapload)
	. = ..()
	if(child)
		QDEL_NULL(child)
		child = new /obj/item/clothing/mask/facehugger/banda(src)

/obj/item/clothing/mask/facehugger/banda/BANDA_XENO_IMPREGNATE_PROC(mob/living/target)
	var/had_embryo = target?.get_organ_by_type(/obj/item/organ/body_egg/alien_embryo)
	. = ..()
	if(had_embryo || QDELETED(target) || !iscarbon(target))
		return
	var/mob/living/carbon/host = target
	var/obj/item/organ/body_egg/alien_embryo/embryo = host.get_organ_by_type(/obj/item/organ/body_egg/alien_embryo)
	if(!embryo || istype(embryo, /obj/item/organ/body_egg/alien_embryo/banda))
		return
	// Preserve TG's implantation checks; replace only the newly implanted egg.
	embryo.Remove(host, special = TRUE)
	qdel(embryo)
	new /obj/item/organ/body_egg/alien_embryo/banda(host)

/// TG hardcodes the hatchling type in this proc. This local adapter is the
/// explicit integration seam to review when upstream changes embryo hatching.
/obj/item/organ/body_egg/alien_embryo/banda/on_poll_concluded(gib_on_success, mob/dead/observer/ghost)
	if(QDELETED(owner))
		return
	if(isnull(ghost))
		// The upstream retry path does not create a mob and can be reused as-is.
		return ..()
	var/mob/living/carbon/host = owner
	var/turf/location = get_turf(host)
	if(!location || !ghost.key)
		bursting = FALSE
		return
	var/mutable_appearance/burst_overlay = mutable_appearance('icons/mob/nonhuman-player/alien.dmi', "burst_lie")
	host.add_overlay(burst_overlay)
	var/mob/living/carbon/alien/larva/banda/larva = new(location)
	larva.PossessByPlayer(ghost.key)
	larva.add_traits(list(TRAIT_HANDS_BLOCKED, TRAIT_IMMOBILIZED, TRAIT_NO_TRANSFORM), type)
	larva.SetInvisibility(INVISIBILITY_MAXIMUM, id = type)
	sleep(0.6 SECONDS)
	if(QDELETED(larva))
		if(!QDELETED(host))
			host.cut_overlay(burst_overlay)
		if(!QDELETED(src))
			bursting = FALSE
		return
	if(QDELETED(src) || QDELETED(host))
		if(!QDELETED(host))
			host.cut_overlay(burst_overlay)
		if(!QDELETED(larva))
			larva.remove_traits(list(TRAIT_HANDS_BLOCKED, TRAIT_IMMOBILIZED, TRAIT_NO_TRANSFORM), type)
			larva.RemoveInvisibility(type)
		return
	larva.remove_traits(list(TRAIT_HANDS_BLOCKED, TRAIT_IMMOBILIZED, TRAIT_NO_TRANSFORM), type)
	larva.RemoveInvisibility(type)
	host.cut_overlay(burst_overlay)
	if(gib_on_success)
		host.investigate_log("has been gibbed by a banda alien larva.", INVESTIGATE_DEATHS)
		host.gib(DROP_ORGANS|DROP_BODYPARTS)
	else
		host.adjust_brute_loss(40)
	qdel(src)
