/datum/xeno_hive
	/// One paid physical anchor, including its unclaimed role, per round-owned hive.
	var/obj/structure/xeno_hivemind_anchor/hivemind_anchor

/** The former brood-core sprite becomes the vulnerable body of the Hivemind. */
/obj/structure/xeno_hivemind_anchor
	name = "hivemind core"
	desc = "Пульсирующий смоляной узел, к которому привязан Разум улья. Разрушение узла приведёт к гибели связанного с ним духа."
	icon = 'modular_bandastation/xeno_rework/icons/structures/hive_core.dmi'
	icon_state = "core"
	pixel_x = -16
	pixel_y = -12
	density = TRUE
	anchored = TRUE
	max_integrity = 450
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

/** TGMC support caste adapted to TG organs, movement, actions and ghost roles. */
/mob/living/carbon/alien/hivemind
	name = "alien hivemind"
	desc = "Физическая оболочка Разума улья. Её существование зависит от уязвимого смоляного узла."
	icon = 'modular_bandastation/xeno_rework/icons/castes/hivemind.dmi'
	icon_state = "Hivemind_"
	pixel_x = -8
	pixel_y = -8
	hud_type = /datum/hud/larva
	maxHealth = 100
	health = 100
	melee_damage_lower = 0
	melee_damage_upper = 0
	default_num_hands = 0
	default_num_legs = 1
	num_legs = 1
	usable_legs = 1
	rotate_on_lying = FALSE
	heat_protection = 1
	bodyparts = list(/obj/item/bodypart/chest/alien, /obj/item/bodypart/head/alien)
	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/hivemind,
		ORGAN_SLOT_XENO_RESINSPINNER = /obj/item/organ/alien/resinspinner_banda/hivemind,
	)
	/// Neither side owns the other's strong reference.
	var/datum/weakref/anchor_ref
	/// The spirit cannot affect physical objects; support and construction require a body.
	var/manifested = FALSE
	/// Serializes form transitions and channeled support across different action buttons.
	var/channeling = FALSE
	/// Losing the shell removes physical support for three and a half minutes.
	var/reformation_time = 210 SECONDS
	COOLDOWN_DECLARE(reformation_cooldown)
	/// Owned read-only roster UI.
	var/datum/xeno_rework_hive_status/hive_status_panel

/mob/living/carbon/alien/hivemind/Initialize(mapload)
	. = ..()
	var/obj/structure/xeno_hivemind_anchor/anchor = GLOB.xeno_hive?.hivemind_anchor
	if(QDELETED(anchor) || get_turf(anchor) != get_turf(src) || anchor.hivemind_ref?.resolve())
		return INITIALIZE_HINT_QDEL
	anchor_ref = WEAKREF(anchor)
	anchor.hivemind_ref = WEAKREF(src)
	get_xeno_hive().add_roster_member(src)
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	add_traits(list(TRAIT_NOFIRE, TRAIT_RESISTHEAT, TRAIT_NOBREATH, TRAIT_TOXIMMUNE, TRAIT_SPACEWALK), INNATE_TRAIT)
	grant_actions_by_list(list(
		/datum/action/cooldown/alien/hivemind/form,
		/datum/action/cooldown/alien/hivemind/return_core,
		/datum/action/cooldown/alien/hivemind/jump,
		/datum/action/cooldown/alien/hivemind/teleport,
		/datum/action/cooldown/alien/hivemind/plant,
		/datum/action/cooldown/alien/hivemind/heal,
		/datum/action/cooldown/alien/hivemind/plasma,
		/datum/action/cooldown/alien/hivemind/rally,
		/datum/action/cooldown/alien/banda/hive_rally_track,
		/datum/action/cooldown/alien/hive_roster,
	))
	apply_hive_upgrades()
	transform = matrix() * 0.9
	set_manifestation(FALSE)

/mob/living/carbon/alien/hivemind/Destroy()
	QDEL_NULL(hive_status_panel)
	var/obj/structure/xeno_hivemind_anchor/anchor = anchor_ref?.resolve()
	anchor_ref = null
	if(!QDELETED(anchor) && anchor.hivemind_ref == weak_reference)
		anchor.hivemind_ref = null
		qdel(anchor)
	return ..()

/mob/living/carbon/alien/hivemind/get_all_limbs()
	return list(BODY_ZONE_CHEST, BODY_ZONE_HEAD)

/mob/living/carbon/alien/hivemind/can_unarmed_attack()
	return FALSE

/mob/living/carbon/alien/hivemind/start_pulling(atom/movable/pulled_atom, state, force = pull_force, supress_message = FALSE)
	return FALSE

/mob/living/carbon/alien/hivemind/set_resting(new_resting, silent = TRUE, instant = FALSE)
	return FALSE

/mob/living/carbon/alien/hivemind/proc/operational()
	return !QDELETED(src) && stat != DEAD && !IS_UNCONSCIOUS(src) && !incapacitated && !resting && isturf(loc) && anchor_ref?.resolve()

/mob/living/carbon/alien/hivemind/proc/can_travel(turf/destination)
	var/obj/structure/xeno_hivemind_anchor/anchor = anchor_ref?.resolve()
	return !QDELETED(anchor) && isopenturf(destination) && !isspaceturf(destination) && destination.z == anchor.z && ((locate(/obj/structure/alien/weeds) in destination) || destination == get_turf(anchor))

/mob/living/carbon/alien/hivemind/Move(atom/newloc, direct, glide_size_override, update_dir = TRUE)
	if(channeling)
		return FALSE
	if(manifested)
		return ..()
	if(!operational() || !isturf(newloc) || get_dist(src, newloc) > 1 || !can_travel(newloc))
		return FALSE
	if(update_dir)
		setDir(direct)
	return forceMove(newloc)

/mob/living/carbon/alien/hivemind/proc/return_to_core()
	var/obj/structure/xeno_hivemind_anchor/anchor = anchor_ref?.resolve()
	if(manifested || QDELETED(anchor))
		return FALSE
	return forceMove(get_turf(anchor))

/mob/living/carbon/alien/hivemind/proc/set_manifestation(physical)
	manifested = physical
	remove_alt_appearance("hivemind_spirit")
	density = physical
	invisibility = physical ? 0 : INVISIBILITY_OBSERVER
	if(physical)
		REMOVE_TRAIT(src, TRAIT_GODMODE, "hivemind_spirit")
	else
		ADD_TRAIT(src, TRAIT_GODMODE, "hivemind_spirit")
		var/image/marker = image(icon, src, "hivemind_marker")
		marker.invisibility = 0
		// The marker's visible 32x32 area already occupies the tile's southwest corner.
		marker.pixel_x = 0
		marker.pixel_y = 0
		marker.appearance_flags |= RESET_TRANSFORM | RESET_COLOR
		add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/one_person, "hivemind_spirit", marker, NONE, src)
	update_action_buttons()

/mob/living/carbon/alien/hivemind/proc/disperse()
	set_manifestation(FALSE)
	COOLDOWN_START(src, reformation_cooldown, reformation_time)
	heal_overall_damage(INFINITY, INFINITY, forced = TRUE)
	set_oxy_loss(0, updating_health = FALSE, forced = TRUE)
	set_tox_loss(0, updating_health = FALSE, forced = TRUE)
	set_health(maxHealth)
	SetAllImmobility(0)
	return_to_core()
	to_chat(src, span_userdanger("Оболочка уничтожена! Дух возвращается к узлу. Повторное воплощение станет доступно через [reformation_time / (1 SECONDS)] секунд."))

/mob/living/carbon/alien/hivemind/updatehealth()
	if(manifested && get_brute_loss() + get_fire_loss() + get_tox_loss() + get_oxy_loss() >= maxHealth)
		// Damage setters call this before native critical/death processing.
		disperse()
		return
	. = ..()
	// Native GODMODE skips health updates, including healing an injured spirit.
	if(!manifested)
		set_health(maxHealth - get_brute_loss() - get_fire_loss() - get_tox_loss() - get_oxy_loss())
		update_health_hud()

/mob/living/carbon/alien/hivemind/death(gibbed)
	if(anchor_ref?.resolve())
		disperse()
		return FALSE
	return ..()

/mob/living/carbon/alien/hivemind/gib(drop_bitflags = NONE)
	if(anchor_ref?.resolve())
		if(manifested)
			disperse()
		return
	return ..()

/mob/living/carbon/alien/hivemind/proc/anchor_destroyed()
	anchor_ref = null
	to_chat(src, span_userdanger("Узел Разума улья уничтожен!"))
	ghostize()
	qdel(src)

/mob/living/carbon/alien/hivemind/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(QDELETED(src))
		return
	if(!anchor_ref?.resolve())
		anchor_destroyed()
		return
	if(!can_travel(get_turf(src)))
		if(manifested)
			adjust_brute_loss(20 * seconds_per_tick)
		else
			return_to_core()

/mob/living/carbon/alien/hivemind/proc/apply_hive_upgrades()
	if(GLOB.xeno_hive?.purchased["pheromones"] && !(locate(/datum/action/cooldown/alien/hivemind/pheromones) in actions))
		grant_actions_by_list(list(/datum/action/cooldown/alien/hivemind/pheromones))

/obj/item/organ/alien/plasmavessel/hivemind
	max_plasma = 400
	stored_plasma = 400
	plasma_rate = 0
	heal_rate = 0
	actions_types = list()

/obj/item/organ/alien/plasmavessel/hivemind/on_life(seconds_per_tick)
	. = ..()
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	if(!istype(hivemind) || !hivemind.anchor_ref?.resolve())
		return
	hivemind.adjustPlasma(60 * seconds_per_tick)
	if(hivemind.can_travel(get_turf(hivemind)))
		hivemind.heal_overall_damage(3 * seconds_per_tick, 3 * seconds_per_tick, forced = TRUE)

/obj/item/organ/alien/resinspinner_banda/hivemind
	actions_types = list(/datum/action/cooldown/alien/select_resin_structure, /datum/action/cooldown/alien/build_resin_structure/hivemind)

/datum/action/cooldown/alien/build_resin_structure/hivemind
	name = "Строительство на расстоянии"
	desc = "В физической оболочке возводит выбранную смоляную постройку на видимой траве в пределах четырёх клеток."
	build_range = 4
