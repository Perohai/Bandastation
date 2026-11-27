/datum/stationtrauma_overmap/space
	/// Nearby worms visible on this hull's flight deck, indexed by their sector counterparts.
	var/list/worm_projections

/** Project only nearby worms into open space around this ship. */
/datum/stationtrauma_overmap/space/proc/update_worm_projection(datum/stationtrauma_space_worm/worm, cx, cy, rotation)
	var/obj/structure/stationtrauma_space_worm/body = worm_projections?[worm]
	var/dx = worm.pos_x - pos_x
	var/dy = worm.pos_y - pos_y
	var/turf/tile
	if(dx ** 2 + dy ** 2 <= (radius + 30) ** 2)
		tile = exterior_contact_turf(cx, cy, rotation, dx, dy)
	if(!tile || tile.is_transition_turf())
		if(body)
			qdel(body)
		return
	if(!body)
		body = new(tile, src, worm)
		LAZYSET(worm_projections, worm, body)
	else if(body.loc != tile)
		body.forceMove(tile)
	var/angle = WRAP(worm.course - rotation, 0, 360)
	if(body.heading != angle)
		body.heading = angle
		body.transform = matrix().Turn(angle)

/** Remove this deck's projections before moving it to another location. */
/datum/stationtrauma_overmap/space/proc/clear_worm_projections()
	var/list/old_projections = worm_projections
	worm_projections = null
	QDEL_LIST_ASSOC_VAL(old_projections)

/** A close-range view of the sector animal which can be hit from this flight deck. */
/obj/structure/stationtrauma_space_worm
	name = "космический глист"
	desc = "Между пластинами панциря пульсируют зелёные железы. У зубчатой пасти пузырится кислота."
	icon = 'modular_bandastation/space_overmap/icons/space_worm.dmi'
	icon_state = "space_worm"
	pixel_x = -32
	base_pixel_x = -32
	pixel_y = -80
	base_pixel_y = -80
	density = TRUE
	anchored = TRUE
	/// The space animal owns the hit points shared by all decks.
	var/datum/stationtrauma_space_worm/worm
	/// Navigation that owns this physical projection.
	var/datum/stationtrauma_overmap/space/owner
	/// Last heading relative to the ship's physical bow.
	var/heading = 0

/obj/structure/stationtrauma_space_worm/Initialize(mapload, datum/stationtrauma_overmap/space/owner, datum/stationtrauma_space_worm/worm)
	. = ..()
	if(QDELETED(owner) || QDELETED(worm))
		return INITIALIZE_HINT_QDEL
	src.owner = owner
	src.worm = worm
	RegisterSignal(worm, COMSIG_QDELETING, PROC_REF(on_worm_deleted))
	RegisterSignal(src, COMSIG_ATOM_TAKE_DAMAGE, PROC_REF(on_body_hit))
	if(worm.health > 0)
		RegisterSignal(worm, COMSIG_SPACE_WORM_DEATH, PROC_REF(show_carcass))
	else
		show_carcass(worm)

/obj/structure/stationtrauma_space_worm/Destroy()
	if(owner)
		LAZYREMOVE(owner.worm_projections, worm)
	owner = null
	worm = null
	return ..()

/** The limp body stays visible and examinable without intercepting fire at other contacts. */
/obj/structure/stationtrauma_space_worm/proc/show_carcass(datum/source)
	SIGNAL_HANDLER
	var/static/icon/carcass = icon(/obj/structure/stationtrauma_space_worm::icon, /obj/structure/stationtrauma_space_worm::icon_state, frame = 1)
	name = "труп космического глиста"
	desc = "Мёртвый глист застыл с раскрытой пастью. Пластины панциря потускнели, кислотные железы обмякли."
	icon = carcass
	icon_state = ""
	color = COLOR_MATRIX_GRAYSCALE
	set_density(FALSE)

/obj/structure/stationtrauma_space_worm/proc/on_worm_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/obj/structure/stationtrauma_space_worm/proc/on_body_hit(datum/source, damage_amount)
	SIGNAL_HANDLER
	worm.take_damage(damage_amount)
	return COMPONENT_NO_TAKE_DAMAGE
