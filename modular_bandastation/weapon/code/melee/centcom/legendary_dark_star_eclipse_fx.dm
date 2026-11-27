/// A visual copy rides at the wielder's shoulder. Each pending echo owns its photographed pose and tile.
/obj/effect/dark_star_eclipse_double
	name = "Двойник затмения"
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	appearance_flags = KEEP_TOGETHER
	vis_flags = VIS_INHERIT_PLANE
	layer = BELOW_MOB_LAYER
	var/mob/living/wielder
	var/obj/item/dualsaber/legendary_saber/saber
	var/obj/effect/overlay/shoulder
	var/list/echoes = list()

/obj/effect/dark_star_eclipse_double/Initialize(mapload, obj/item/dualsaber/legendary_saber/saber)
	. = ..()
	var/mob/living/bearer = loc
	if(!istype(bearer) || QDELETED(saber) || !bearer.is_holding(saber))
		return INITIALIZE_HINT_QDEL
	wielder = bearer
	src.saber = saber
	shoulder = make_avatar(src, wielder.dir)
	vis_contents += shoulder
	wielder.vis_contents += src
	place_shoulder(wielder, null, wielder.dir)
	RegisterSignal(wielder, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(place_shoulder))
	alpha = 0
	animate(src, alpha = 215, time = 0.35 SECONDS)

/obj/effect/dark_star_eclipse_double/proc/place_shoulder(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	shoulder.setDir(new_dir)
	pixel_x = (new_dir & WEST) ? 14 : -14
	pixel_y = (new_dir & NORTH) ? 3 : 7

/obj/effect/dark_star_eclipse_double/proc/make_avatar(atom/parent, facing, swinging = FALSE)
	var/mutable_appearance/portrait = new(wielder.appearance)
	var/hand = wielder.get_held_index_of_item(saber)
	var/mutable_appearance/grip
	if(swinging && iscarbon(wielder) && hand)
		var/mob/living/carbon/bearer = wielder
		var/list/hands = bearer.overlays_standing[HANDS_LAYER]
		grip = LAZYACCESS(hands, bearer.get_active_held_indexes().Find(hand))
		if(grip)
			portrait.overlays -= grip
	var/obj/effect/overlay/avatar = new(parent)
	avatar.appearance = copy_appearance_filter_overlays(portrait)
	avatar.vis_contents.Cut()
	avatar.render_target = null
	avatar.filters = null
	avatar.appearance_flags = KEEP_TOGETHER
	avatar.vis_flags = VIS_INHERIT_PLANE
	avatar.layer = ABOVE_MOB_LAYER
	avatar.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	avatar.pixel_x = 0
	avatar.pixel_y = 0
	avatar.pixel_w = 0
	avatar.pixel_z = 0
	avatar.setDir(facing)
	// Map the owner's luminance to violet and pearl so dark clothing still has visible folds.
	avatar.color = list(0.25,0.22,0.24,0, 0.50,0.43,0.47,0, 0.10,0.08,0.09,0, 0,0,0,1, 0.10,0.055,0.18,0)
	avatar.add_filter("eclipse_rim", 1, outline_filter(1, "#a26ed8b5", OUTLINE_SHARP))
	if(!swinging)
		return avatar
	var/obj/effect/overlay/blade = new(avatar)
	blade.icon = 'modular_bandastation/weapon/icons/melee/dark_star_eclipse.dmi'
	blade.icon_state = IS_LEFT_INDEX(hand) ? "blade_left" : "blade_right"
	blade.setDir(facing)
	blade.layer = ABOVE_MOB_LAYER + 0.01
	blade.vis_flags = VIS_INHERIT_PLANE
	blade.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blade.pixel_x = -16
	blade.pixel_y = -16
	if(grip)
		blade.pixel_w = grip.pixel_w
		blade.pixel_z = grip.pixel_z
	avatar.vis_contents += blade
	flick(blade.icon_state, blade)
	return avatar

/obj/effect/dark_star_eclipse_double/proc/mark(turf/target)
	if(!target || QDELETED(wielder) || QDELETED(saber))
		return
	var/obj/effect/dark_star_eclipse_echo/echo = new(target, src)
	echoes += echo
	animate(src, alpha = 0, time = 0.1 SECONDS, flags = ANIMATION_END_NOW)
	return echo

/obj/effect/dark_star_eclipse_double/proc/release(obj/effect/dark_star_eclipse_echo/echo)
	echoes -= echo
	if(!length(echoes) && !QDELETED(src))
		animate(src, alpha = 0, time = 0.15 SECONDS, flags = ANIMATION_END_NOW)
		animate(alpha = 215, time = 0.2 SECONDS)

/obj/effect/dark_star_eclipse_double/Destroy()
	if(wielder)
		UnregisterSignal(wielder, COMSIG_ATOM_POST_DIR_CHANGE)
		wielder.vis_contents -= src
		wielder = null
	saber = null
	for(var/obj/effect/dark_star_eclipse_echo/echo as anything in echoes)
		echo.double = null
		qdel(echo)
	echoes = null
	QDEL_NULL(shoulder)
	return ..()

/// Stationary tile marker, with the attacker's image lunging inward from the far side.
/obj/effect/dark_star_eclipse_echo
	name = "эхо Тёмной Звезды"
	icon = null
	layer = ABOVE_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	var/obj/effect/dark_star_eclipse_double/double
	var/obj/effect/overlay/actor
	var/obj/effect/overlay/mark_visual
	var/offset_x
	var/offset_y

/obj/effect/dark_star_eclipse_echo/Initialize(mapload, obj/effect/dark_star_eclipse_double/double)
	. = ..()
	if(QDELETED(double))
		return INITIALIZE_HINT_QDEL
	src.double = double
	var/outward = get_dir(double.wielder, src) || double.wielder.dir
	var/reach = ISDIAGONALDIR(outward) ? 22 : 30
	offset_x = (outward & EAST ? reach : 0) - (outward & WEST ? reach : 0)
	offset_y = (outward & NORTH ? reach : 0) - (outward & SOUTH ? reach : 0)
	actor = double.make_avatar(src, REVERSE_DIR(outward), TRUE)
	actor.pixel_x = offset_x
	actor.pixel_y = offset_y
	actor.alpha = 55
	vis_contents += actor
	animate(actor, alpha = 240, time = 0.15 SECONDS)
	animate(pixel_x = round(offset_x * 0.63), pixel_y = round(offset_y * 0.63), time = 0.25 SECONDS, easing = QUAD_EASING | EASE_IN)
	mark_visual = new(src)
	mark_visual.icon = 'modular_bandastation/weapon/icons/melee/dark_star_eclipse.dmi'
	mark_visual.icon_state = "mark"
	mark_visual.pixel_x = -16
	mark_visual.pixel_y = -16
	mark_visual.layer = ABOVE_MOB_LAYER + 0.02
	mark_visual.vis_flags = VIS_INHERIT_PLANE
	mark_visual.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	vis_contents += mark_visual
	flick("mark", mark_visual)

/// A resolved echo finishes independently, including when the fifth charge ends the status.
/obj/effect/dark_star_eclipse_echo/proc/strike(is_fifth)
	if(QDELETED(double))
		return
	double.release(src)
	double = null
	QDEL_NULL(mark_visual)
	if(is_fifth)
		new /obj/effect/temp_visual/dark_star_eclipse_hit/cross(loc)
	else
		new /obj/effect/temp_visual/dark_star_eclipse_hit(loc)
	animate(actor, pixel_x = offset_x, pixel_y = offset_y, alpha = 0, time = 0.3 SECONDS, easing = QUAD_EASING | EASE_IN)
	QDEL_IN(src, 0.3 SECONDS)

/obj/effect/dark_star_eclipse_echo/Destroy()
	double?.release(src)
	double = null
	QDEL_NULL(mark_visual)
	QDEL_NULL(actor)
	return ..()

/obj/effect/temp_visual/dark_star_eclipse_hit
	name = "разрез затмения"
	icon = 'modular_bandastation/weapon/icons/melee/dark_star_eclipse.dmi'
	icon_state = "hit"
	pixel_x = -16
	pixel_y = -16
	base_pixel_x = -16
	base_pixel_y = -16
	duration = 0.4 SECONDS
	randomdir = FALSE
	layer = ABOVE_MOB_LAYER + 0.03
	blocks_emissive = EMISSIVE_BLOCK_NONE

/obj/effect/temp_visual/dark_star_eclipse_hit/Initialize(mapload)
	. = ..()
	flick(icon_state, src)

/obj/effect/temp_visual/dark_star_eclipse_hit/cross
	name = "крест затмения"
	icon_state = "cross"
