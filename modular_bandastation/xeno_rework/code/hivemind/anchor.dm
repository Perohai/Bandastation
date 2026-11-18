/datum/xeno_hive
	/// One paid physical anchor, including its unclaimed role, per round-owned hive.
	var/obj/structure/xeno_hivemind_anchor/hivemind_anchor

/** The former brood-core sprite becomes the vulnerable body of the Hivemind. */
/obj/structure/xeno_hivemind_anchor
	name = "hivemind core"
	desc = "Пульсирующий смоляной узел, к которому привязан Разум улья. Разрушение узла приведёт к гибели связанного с ним духа."
	icon = 'modular_bandastation/xeno_rework/icons/brood/hive_core.dmi'
	icon_state = "core"
	pixel_x = -16
	pixel_y = -12
	density = TRUE
	anchored = TRUE
	max_integrity = 600
	/// The anchor owns the role; the mob is held weakly to avoid a deletion cycle.
	var/obj/effect/mob_spawn/ghost_role/xeno_hivemind/spawner
	/// Occupancy persists through disconnects and incorporeal/physical transitions.
	var/datum/weakref/hivemind_ref

/obj/structure/xeno_hivemind_anchor/Initialize(mapload)
	. = ..()
	var/datum/xeno_hive/hive = get_xeno_hive()
	if(hive.hivemind_anchor || !isturf(loc) || !(locate(/obj/structure/alien/weeds) in loc))
		return INITIALIZE_HINT_QDEL
	hive.hivemind_anchor = src
	new /obj/structure/alien/weeds/node/banda(loc)
	spawner = new(src)
	spawner.anchor = src
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_anchor_moved))

/obj/structure/xeno_hivemind_anchor/Destroy()
	if(GLOB.xeno_hive?.hivemind_anchor == src)
		GLOB.xeno_hive.hivemind_anchor = null
	QDEL_NULL(spawner)
	var/mob/living/carbon/alien/hivemind/hivemind = hivemind_ref?.resolve()
	hivemind_ref = null
	if(!QDELETED(hivemind))
		hivemind.anchor_destroyed()
	return ..()

/obj/structure/xeno_hivemind_anchor/proc/on_anchor_moved()
	SIGNAL_HANDLER
	qdel(src)

/obj/structure/xeno_hivemind_anchor/attack_ghost(mob/user)
	spawner?.attack_ghost(user)
	return ..()

/obj/structure/xeno_hivemind_anchor/examine(mob/user)
	. = ..()
	if(isalien(user) || isobserver(user))
		var/occupancy = hivemind_ref?.resolve() ? "Разум улья связан с этим узлом." : "Узел разума улья ожидает призрака."
		. += span_notice(occupancy)

/** Uses native bans, prompt, use reservation, job assignment and possession. */
/obj/effect/mob_spawn/ghost_role/xeno_hivemind
	name = "Разум улья"
	prompt_name = "разумом улья"
	mob_type = /mob/living/carbon/alien/hivemind
	uses = 1
	deletes_on_zero_uses_left = FALSE
	role_ban = ROLE_ALIEN
	spawner_job_path = /datum/job/xenomorph
	you_are_text = "Вы — Разум улья."
	flavour_text = "В форме духа перемещайтесь по траве. Воплощайтесь, чтобы возводить постройки и поддерживать улей; возвращайтесь к узлу или переноситесь к союзникам на траве. Для общения используйте :a."
	important_text = "Разрушение узла убьёт Разум улья. Эволюция недоступна. Разум улья не учитывается при подсчёте численности роя для финала и не может взламывать шаттл."
	/// Released during teardown; role and physical anchor have the same lifetime.
	var/obj/structure/xeno_hivemind_anchor/anchor

/obj/effect/mob_spawn/ghost_role/xeno_hivemind/Destroy()
	anchor = null
	return ..()

/obj/effect/mob_spawn/ghost_role/xeno_hivemind/allow_spawn(mob/user, silent = FALSE)
	return ..() && isobserver(user) && user.client && !QDELETED(anchor) && loc == anchor && isturf(anchor.loc) && anchor == GLOB.xeno_hive?.hivemind_anchor && !anchor.hivemind_ref?.resolve()

/obj/effect/mob_spawn/ghost_role/xeno_hivemind/create(mob/mob_possessor, newname, apply_prefs)
	if(!allow_spawn(mob_possessor))
		return CANCEL_SPAWN
	return ..()

/obj/effect/mob_spawn/ghost_role/xeno_hivemind/Topic(href, list/href_list)
	. = ..()
	if(. || !href_list["activate"] || !isobserver(usr))
		return
	attack_ghost(usr)

/** Ban queries run outside purchase/SSobj callbacks and are rechecked by native entry. */
/obj/effect/mob_spawn/ghost_role/xeno_hivemind/proc/notify_available()
	for(var/mob/dead/observer/ghost in GLOB.player_list)
		if(QDELETED(src) || QDELETED(anchor) || uses <= 0)
			return
		var/ghost_ckey = ghost.ckey
		if(is_banned_from(ghost_ckey, ROLE_ALIEN))
			continue
		if(QDELETED(src) || QDELETED(anchor) || uses <= 0)
			return
		if(QDELETED(ghost) || ghost.ckey != ghost_ckey || !allow_spawn(ghost) || !(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER))
			continue
		ghost.spawners_menu?.update_static_data(ghost)
		notify_ghosts("Улей вырастил узел разума. Роль Разума улья свободна!", source = src, header = "Hivemind", click_interact = TRUE, ignore_key = POLL_IGNORE_ALIEN_LARVA, notify_flags = NOTIFY_CATEGORY_NOFLASH, recipients = list(ghost))

/datum/xeno_hive/proc/hivemind_location(mob/living/carbon/alien/adult/banda/queen/queen)
	if(!can_manage(queen) || !(queen.dir in GLOB.cardinals))
		return null
	return get_step(queen, queen.dir)

/datum/xeno_hive/proc/can_place_hivemind(mob/living/carbon/alien/adult/banda/queen/queen, turf/origin)
	return !hivemind_anchor && can_manage(queen) && origin == hivemind_location(queen) && origin && (locate(/obj/structure/alien/weeds) in origin) && clear_structure_footprint(origin, 1, 1, floors_only = FALSE)
