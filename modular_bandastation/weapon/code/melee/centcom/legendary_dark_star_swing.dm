/datum/status_effect/dark_star_sequence/judgment_cut
	/// The drawn blade shares the windup's lifetime, including interruptions.
	var/obj/effect/dark_star_swing/swing_visual

/datum/status_effect/dark_star_sequence/judgment_cut/proc/begin_swing(turf/target)
	swing_visual = new(owner, saber, target)

/datum/status_effect/dark_star_sequence/judgment_cut/proc/end_swing()
	QDEL_NULL(swing_visual)

/// Point the held blade as the phantom blades launch.
/obj/item/dualsaber/legendary_saber/dark_star/proc/command_star_blade(mob/living/wielder, atom/target)
	wielder.face_atom(target)
	new /obj/effect/dark_star_swing/command(wielder, src, target)

/// Displayed on the caster so movement and deletion cannot leave a blade on the previous tile.
/obj/effect/dark_star_swing
	name = "взмах Тёмной Звезды"
	icon = 'modular_bandastation/weapon/icons/melee/dark_star_swing.dmi'
	layer = ABOVE_MOB_LAYER
	vis_flags = VIS_INHERIT_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	pixel_x = -16
	pixel_y = -16
	/// Prefix shared by the left- and right-handed animations.
	var/pose = "swing"
	var/obj/item/dualsaber/legendary_saber/saber

/obj/effect/dark_star_swing/Initialize(mapload, obj/item/dualsaber/legendary_saber/saber, atom/target)
	. = ..()
	var/mob/living/wielder = loc
	if(!istype(wielder) || QDELETED(saber) || !target)
		return INITIALIZE_HINT_QDEL
	var/hand_index = wielder.get_held_index_of_item(saber)
	if(!hand_index)
		return INITIALIZE_HINT_QDEL
	for(var/obj/effect/dark_star_swing/previous in wielder.vis_contents)
		if(previous.saber == saber)
			qdel(previous)
	src.saber = saber
	icon_state = IS_LEFT_INDEX(hand_index) ? "[pose]_left" : "[pose]_right"
	setDir(get_dir(wielder, target) || wielder.dir)
	if(iscarbon(wielder))
		var/mob/living/carbon/bearer = wielder
		// The normal hand appearance already accounts for stature, extra arms and limb offsets.
		var/list/held = bearer.get_held_overlays()
		var/appearance_index = bearer.get_active_held_indexes().Find(hand_index)
		var/mutable_appearance/grip = LAZYACCESS(held, appearance_index)
		if(grip)
			pixel_w += grip.pixel_w
			pixel_z += grip.pixel_z
	RegisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS, PROC_REF(hide_resting_blade))
	RegisterSignals(saber, list(COMSIG_TWOHANDED_UNWIELD, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(lose_blade))
	wielder.update_held_items()
	wielder.vis_contents += src
	flick(icon_state, src)

/obj/effect/dark_star_swing/proc/hide_resting_blade(obj/item/source, list/overlays, mutable_appearance/draw_target, isinhands)
	SIGNAL_HANDLER
	if(isinhands && source.loc == loc)
		draw_target.icon = null
		overlays.Cut()

/obj/effect/dark_star_swing/proc/lose_blade()
	SIGNAL_HANDLER
	qdel(src)

/obj/effect/dark_star_swing/Destroy()
	var/mob/living/wielder = loc
	if(saber)
		UnregisterSignal(saber, list(COMSIG_ITEM_GET_WORN_OVERLAYS, COMSIG_TWOHANDED_UNWIELD, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		saber = null
		if(istype(wielder) && !QDELETED(wielder))
			wielder.vis_contents -= src
			wielder.update_held_items()
	return ..()

/obj/effect/dark_star_swing/command
	name = "командный жест Тёмной Звезды"
	pose = "command"

/obj/effect/dark_star_swing/command/Initialize(mapload, obj/item/dualsaber/legendary_saber/saber, atom/target)
	. = ..()
	if(. != INITIALIZE_HINT_QDEL)
		QDEL_IN(src, 0.3 SECONDS)

/// The blade retracts while the rift pulls, independently of the saber's wielded state.
/obj/effect/dark_star_swing/void_slash
	name = "пространственный взмах Тёмной Звезды"
	pose = "void"
