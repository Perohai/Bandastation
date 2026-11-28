/// An articulated view of the wielder and their equipment during one pass.
/// Gameplay moves the real mob; these three appearances ride along in its vis_contents.
/obj/effect/dark_star_stinger_pose
	name = "полёт Тёмной Звезды"
	var/mob/living/wielder
	var/obj/item/dualsaber/legendary_saber/saber
	var/obj/effect/overlay/blade
	var/obj/effect/overlay/drill
	var/heading
	var/filter_name

/obj/effect/dark_star_stinger_pose/Initialize(mapload, obj/item/dualsaber/legendary_saber/saber, heading)
	. = ..()
	var/mob/living/bearer = loc
	if(!istype(bearer) || QDELETED(saber) || !bearer.is_holding(saber) || !(heading in GLOB.alldirs))
		return INITIALIZE_HINT_QDEL
	wielder = bearer
	src.saber = saber
	src.heading = heading
	RegisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS, PROC_REF(hide_held_blade))
	RegisterSignals(saber, list(COMSIG_TWOHANDED_UNWIELD, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(end_pose))
	RegisterSignal(wielder, COMSIG_QDELETING, PROC_REF(end_pose))
	wielder.update_held_items()
	// Capture the equipped character before masking the upright sprite. KEEP_APART
	// leaves the moving double outside that mask. Its click target is still the mob.
	appearance = wielder.appearance
	appearance_flags |= KEEP_APART | KEEP_TOGETHER
	vis_flags = VIS_INHERIT_ID | VIS_INHERIT_LAYER | VIS_INHERIT_PLANE
	mouse_opacity = MOUSE_OPACITY_ICON
	render_target = null
	pixel_w = 0
	pixel_z = 0
	pixel_x = 0
	pixel_y = 0
	setDir((heading & WEST) ? WEST : EAST)
	filter_name = "dark_star_stinger_[REF(src)]"
	var/list/mask = COLOR_MATRIX_IDENTITY
	mask[16] = 0
	wielder.add_filter(filter_name, 100, color_matrix_filter(mask))
	wielder.vis_contents += src
	blade = attach_visual('modular_bandastation/weapon/icons/melee/dark_star_stinger_blade.dmi', -48, ABOVE_MOB_LAYER)
	drill = attach_visual('modular_bandastation/weapon/icons/melee/dark_star_stinger.dmi', -64, ABOVE_MOB_LAYER + 0.01)
	// Roll about the blade's longitudinal axis, with the foreshortened side
	// views changing sides at a finite thickness. One turn takes two ticks.
	transform = flight_transform(1)
	animate(src, transform = flight_transform(0.35), time = 0.5, loop = -1, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(transform = flight_transform(-0.35), time = 0, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(transform = flight_transform(-1), time = 0.5, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(transform = flight_transform(-0.35), time = 0.5, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(transform = flight_transform(0.35), time = 0, flags = ANIMATION_LINEAR_TRANSFORM)
	animate(transform = flight_transform(1), time = 0.5, flags = ANIMATION_LINEAR_TRANSFORM)

/obj/effect/dark_star_stinger_pose/proc/attach_visual(icon_file, offset, visual_layer)
	var/obj/effect/overlay/visual = new(src)
	visual.icon = icon_file
	visual.icon_state = "pass"
	visual.setDir(heading)
	visual.pixel_x = offset
	visual.pixel_y = offset
	visual.layer = visual_layer
	visual.appearance_flags = KEEP_APART
	visual.vis_flags = VIS_INHERIT_PLANE
	visual.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	wielder.vis_contents += visual
	flick("pass", visual)
	return visual

/obj/effect/dark_star_stinger_pose/proc/flight_transform(roll)
	var/side = (heading & WEST) ? -1 : 1
	var/matrix/pose = matrix()
	pose.Turn(side * 78)
	pose.Scale(1, roll)
	pose.Translate(side * 6, 1)
	pose.Turn(dir2angle(heading) - (side > 0 ? 90 : 270))
	return pose

/// The drill collapses on impact. The double returns to the ordinary grip as it stands up.
/obj/effect/dark_star_stinger_pose/proc/finish()
	if(!blade || !drill)
		return
	wielder.vis_contents -= blade
	QDEL_NULL(blade)
	animate(drill, alpha = 0, time = 0.1 SECONDS)
	UnregisterSignal(saber, COMSIG_ITEM_GET_WORN_OVERLAYS)
	if(iscarbon(wielder))
		var/mob/living/carbon/bearer = wielder
		var/hand_index = bearer.get_held_index_of_item(saber)
		var/list/held = bearer.get_held_overlays()
		var/mutable_appearance/grip = LAZYACCESS(held, bearer.get_active_held_indexes().Find(hand_index))
		if(grip)
			add_overlay(grip)
	setDir(wielder.dir)
	animate(src, transform = matrix(), time = 0.35 SECONDS, easing = SINE_EASING, flags = ANIMATION_END_NOW | ANIMATION_LINEAR_TRANSFORM)

/obj/effect/dark_star_stinger_pose/proc/hide_held_blade(obj/item/source, list/overlays, mutable_appearance/held, isinhands)
	SIGNAL_HANDLER
	if(isinhands && source.loc == wielder)
		held.icon = null
		overlays.Cut()

/obj/effect/dark_star_stinger_pose/proc/end_pose()
	SIGNAL_HANDLER
	qdel(src)

/obj/effect/dark_star_stinger_pose/Destroy()
	if(saber)
		UnregisterSignal(saber, list(COMSIG_ITEM_GET_WORN_OVERLAYS, COMSIG_TWOHANDED_UNWIELD, COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		saber = null
	if(wielder)
		UnregisterSignal(wielder, COMSIG_QDELETING)
		wielder.vis_contents -= list(src, blade, drill)
		wielder.remove_filter(filter_name)
		if(!QDELETED(wielder))
			wielder.update_held_items()
		wielder = null
	QDEL_NULL(blade)
	QDEL_NULL(drill)
	return ..()
