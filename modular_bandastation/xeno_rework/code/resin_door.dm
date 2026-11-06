/obj/structure/alien/resin/door
	name = "resin door"
	desc = "A thick resin secretion that can be parted by xenomorphs."
	icon = 'modular_bandastation/xeno_rework/icons/tgmc_resin_door.dmi'
	icon_state = "resin-door-0"
	base_icon_state = "resin-door"
	density = TRUE
	anchored = TRUE
	opacity = TRUE
	max_integrity = 60
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_ALIEN_WALLS + SMOOTH_GROUP_ALIEN_RESIN
	canSmoothWith = SMOOTH_GROUP_ALIEN_WALLS

	/// Whether the door is open (TRUE) or closed (FALSE).
	var/state_open = FALSE
	/// Whether the door is currently operating (opening/closing).
	var/is_operating = FALSE
	/// Delay before attempting to close the door automatically (in seconds).
	var/close_delay = 3 SECONDS
	/// Sound played when the door opens.
	var/open_sound = 'modular_bandastation/xeno_rework/sound/alien_resin_move1.ogg'
	/// Sound played when the door closes.
	var/close_sound = 'modular_bandastation/xeno_rework/sound/alien_resin_move2.ogg'

	/// Sum of the seven TGMC animation frame delays, in deciseconds.
	var/animation_time = 11

/// Initializes the door, updating its icon and air properties.
/obj/structure/alien/resin/door/Initialize(mapload)
	. = ..()
	update_icon()
	air_update_turf(TRUE, TRUE)

/// Cleans up overlays and air properties before destruction.
/obj/structure/alien/resin/door/Destroy()
	density = FALSE
	air_update_turf(TRUE, FALSE)
	return ..()

/// Updates air properties when the door moves.
/obj/structure/alien/resin/door/Move()
	var/turf/T = loc
	. = ..()
	move_update_air(T)
	update_icon()

/// Determines if atmosphere can pass through the door based on its density.
/obj/structure/alien/resin/door/proc/CanAtmosPass(turf/source, turf/target, air_group)
	return !density

/// Handles hand attacks to operate the door.
/obj/structure/alien/resin/door/attack_hand(mob/living/user, list/modifiers)
	return try_to_operate(user)

/// Handles paw attacks to operate the door.
/obj/structure/alien/resin/door/attack_paw(mob/living/user, list/modifiers)
	return attack_hand(user, modifiers)

/// Handles alien attacks, either to operate or destroy the door.
/obj/structure/alien/resin/door/attack_alien(mob/living/carbon/alien/user, list/modifiers)
	if (!user.combat_mode)
		return try_to_operate(user)
	to_chat(user, span_notice("You begin tearing down this resin structure."))
	if (!do_after(user, 4 SECONDS, target = src) || QDELETED(src))
		return
	qdel(src)

/// Attempts to open or close the door if the user has the required organ and is not handcuffed.
/obj/structure/alien/resin/door/proc/try_to_operate(mob/living/user, bumped_open = FALSE)
	if (is_operating || QDELETED(src))
		return
	if (!iscarbon(user))
		return
	var/mob/living/carbon/C = user
	if (C.get_organ_by_type(/obj/item/organ/alien/plasmavessel))
		if (!C.handcuffed)
			operate(bumped_open)
		return
	to_chat(user, span_notice("Your lack of connection to the hive prevents the resin door from opening."))

/// Starts the door opening or closing animation.
/obj/structure/alien/resin/door/proc/operate(bumped_open = FALSE)
	if (is_operating || QDELETED(src))
		return

	var/is_closing = state_open

	if (is_closing)
		var/mob/living/mob_present = locate(/mob/living) in get_turf(src)
		if (mob_present)
			if (state_open)
				addtimer(CALLBACK(src, PROC_REF(mobless_try_to_operate)), close_delay)
			return

	is_operating = TRUE
	var/anim_state = "resin-door-[smoothing_junction || 0]-[is_closing ? "closing" : "opening"]"

	flick(anim_state, src)

	// Play sound.
	playsound(loc, is_closing ? close_sound : open_sound, 50, TRUE)

	// Schedule update after animation.
	addtimer(CALLBACK(src, PROC_REF(operate_update), bumped_open), animation_time)

/// Updates door state, physics, and icon after animation.
/obj/structure/alien/resin/door/proc/operate_update(bumped_open)
	if (QDELETED(src))
		return

	// Update physics.
	density = !density
	opacity = !opacity
	state_open = !state_open

	air_update_turf(TRUE, TRUE)
	icon_state = "resin-door-[smoothing_junction || 0][state_open ? "-open" : ""]"
	if (smoothing_flags & SMOOTH_BITMASK)
		smooth_icon(src)

	is_operating = FALSE
	if (state_open && bumped_open)
		addtimer(CALLBACK(src, PROC_REF(mobless_try_to_operate)), close_delay)

/// Attempts to close the door automatically if no mobs are present.
/obj/structure/alien/resin/door/proc/mobless_try_to_operate()
	if (QDELETED(src))
		return

	if (!state_open)
		return

	if (is_operating)
		addtimer(CALLBACK(src, PROC_REF(mobless_try_to_operate)), close_delay)
		return

	var/mob/living/mob_present = locate(/mob/living) in get_turf(src)
	if (mob_present)
		addtimer(CALLBACK(src, PROC_REF(mobless_try_to_operate)), close_delay)
		return
	operate()

/obj/structure/alien/resin/door/update_icon()
	. = ..()
	// Set smoothed icon.
	icon_state = "resin-door-[smoothing_junction || 0][state_open ? "-open" : ""]"

/obj/structure/alien/resin/door/Bumped(atom/movable/user)
	. = ..()
	if (!state_open)
		return try_to_operate(user, TRUE)

/// Preserve the open state when a neighbouring resin structure changes smoothing.
/obj/structure/alien/resin/door/set_smoothed_icon_state(new_junction)
	. = ..()
	icon_state = "resin-door-[new_junction][state_open ? "-open" : ""]"
