/** One installed physical core. Moving or deleting it destroys unused weak brood. */
/obj/structure/xeno_hive_core
	name = "hive core"
	desc = "Живое сердце улья — огромный маточный мешок с выводковой горловиной и запасами биомассы. Если его уничтожить, рост потомства остановится, а невостребованные яйца погибнут."
	icon = 'modular_bandastation/xeno_rework/icons/brood/brood_core.dmi'
	icon_state = "core"
	bound_width = 64
	bound_height = 64
	anchored = TRUE
	density = TRUE
	max_integrity = 250
	/// One destructible shell per passive place, all released on core loss.
	var/list/obj/structure/xeno_hive_egg/brood_eggs = list()
	/// Crew recount is sampled every ten seconds by this single processing core.
	var/crew_sample_time = 0
	/// Crew population used between samples, not a cap on active brood.
	var/cached_crew = 0

/obj/structure/xeno_hive_core/Initialize(mapload)
	. = ..()
	var/datum/xeno_hive/hive = get_xeno_hive()
	if(!is_installed() || hive.core)
		return INITIALIZE_HINT_QDEL
	hive.core = src
	hive.core_arrived()
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(core_moved))
	START_PROCESSING(SSobj, src)

/obj/structure/xeno_hive_core/Destroy()
	STOP_PROCESSING(SSobj, src)
	for(var/obj/structure/xeno_hive_egg/egg as anything in brood_eggs.Copy())
		qdel(egg)
	brood_eggs.Cut()
	if(GLOB.xeno_hive?.core == src)
		GLOB.xeno_hive.core = null
		GLOB.xeno_hive.brood_points = 0
		GLOB.xeno_hive.core_removed()
	return ..()

/obj/structure/xeno_hive_core/proc/core_moved()
	SIGNAL_HANDLER
	qdel(src)

/obj/structure/xeno_hive_core/proc/is_installed()
	if(!isturf(loc) || !(locate(/obj/structure/alien/weeds) in loc))
		return FALSE
	var/turf/far_corner = locate(x + 1, y + 1, z)
	if(!far_corner)
		return FALSE
	for(var/turf/location as anything in block(loc, far_corner))
		if(!isopenturf(location) || isspaceturf(location))
			return FALSE
	return TRUE

/** Egg ownership follows the whole footprint rather than distance to its southwest anchor. */
/obj/structure/xeno_hive_core/proc/next_to_core(atom/target)
	if(QDELETED(target) || target.z != z)
		return FALSE
	return target.x >= x - 1 && target.x <= x + 2 && target.y >= y - 1 && target.y <= y + 2 && !(target.x >= x && target.x <= x + 1 && target.y >= y && target.y <= y + 1)

/** Native click reach only checks loc; expose every tile of this large body to rescuers. */
/obj/structure/xeno_hive_core/CheckReachableAdjacency(atom/movable/reacher, reacher_range)
	for(var/turf/location as anything in locs)
		if(location.Adjacent(reacher, target = src, mover = reacher))
			return TRUE
	return ..()

/obj/structure/xeno_hive_core/process(seconds_per_tick)
	if(world.time >= crew_sample_time)
		cached_crew = GLOB.xeno_hive.count_crew()
		crew_sample_time = world.time + 10 SECONDS
	GLOB.xeno_hive.advance_brood(seconds_per_tick, cached_crew)

/** Prefer an empty neighboring floor; stacking eggs never caps unclaimed places. */
/obj/structure/xeno_hive_core/proc/egg_spawn_turf()
	var/list/empty = list()
	var/list/occupied = list()
	var/turf/bottom_left = locate(max(1, x - 1), max(1, y - 1), z)
	var/turf/top_right = locate(min(world.maxx, x + 2), min(world.maxy, y + 2), z)
	var/list/large_neighbors = list()
	for(var/obj/structure/xeno_biomass_generator/generator in range(3, src))
		large_neighbors += generator
	for(var/turf/open/location in block(bottom_left, top_right))
		if(!next_to_core(location) || isspaceturf(location))
			continue
		if(location.is_blocked_turf(exclude_mobs = TRUE))
			continue
		var/blocked = FALSE
		for(var/obj/structure/xeno_biomass_generator/generator as anything in large_neighbors)
			if(location.x >= generator.x && location.x <= generator.x + 1 && location.y >= generator.y && location.y <= generator.y + 1)
				blocked = TRUE
				break
		if(blocked)
			continue
		if(locate(/obj/structure/xeno_hive_egg) in location)
			occupied += location
		else
			empty += location
	if(length(empty))
		return pick(empty)
	if(length(occupied))
		return pick(occupied)
	return null

/obj/structure/xeno_hive_core/proc/available_brood()
	var/places = 0
	for(var/obj/structure/xeno_hive_egg/egg as anything in brood_eggs)
		places += max(egg.spawner?.uses, 0)
	return places

/obj/structure/xeno_hive_core/proc/add_brood(places)
	var/created = 0
	var/obj/structure/xeno_hive_egg/last_egg
	for(var/index in 1 to places)
		var/turf/location = egg_spawn_turf()
		if(!location)
			break
		last_egg = new(location, src)
		eject_egg(last_egg)
		created++
	if(created)
		flick("core_birth", src)
		playsound(src, 'sound/mobs/non-humanoids/alien/alien_eat.ogg', 45, TRUE)
	if(created && (GLOB.ghost_role_flags & GHOSTROLE_SPAWNER))
		INVOKE_ASYNC(last_egg.spawner, TYPE_PROC_REF(/obj/effect/mob_spawn/ghost_role/xeno_hive, notify_available), "Свободных мест в яйцах рядом с ядром: [available_brood()].", "Слабое потомство улья")
	return created

/** Only the visual crosses tiles; the role and its final location exist synchronously. */
/obj/structure/xeno_hive_core/proc/eject_egg(obj/structure/xeno_hive_egg/egg)
	var/landing_x = egg.pixel_x
	var/landing_y = egg.pixel_y
	egg.pixel_x = (x - egg.x) * world.icon_size + 16
	egg.pixel_y = (y - egg.y) * world.icon_size + 8
	egg.alpha = 0
	animate(egg, alpha = 0, time = 0.45 SECONDS)
	animate(alpha = 255, time = 0.15 SECONDS)
	animate(pixel_x = landing_x, pixel_y = landing_y, alpha = 255, time = 0.55 SECONDS, easing = QUAD_EASING)

/obj/structure/xeno_hive_core/examine(mob/user)
	. = ..()
	if(isalien(user) || isobserver(user))
		. += span_notice("Запасы улья: [round(GLOB.xeno_hive?.biomass || 0, 0.1)] биомассы. Доступных яиц выводка: [available_brood()].")

/** Reusable destructible shell for both weak brood and purchased full larvae. */
/obj/structure/xeno_hive_egg
	name = "brood egg"
	desc = "Внутри яйца дремлет представитель младшего выводка. Призрак может выбрать доступный вид существа. Если яйцо уничтожат, одно место в выводке будет потеряно."
	icon = 'icons/effects/effects.dmi'
	icon_state = "eggs"
	anchored = TRUE
	density = FALSE
	max_integrity = 60
	/// Shell-owned single-use role entry; deleted with the shell.
	var/obj/effect/mob_spawn/ghost_role/xeno_hive/spawner
	/// Only passive clutches are tied to the core lifecycle.
	var/obj/structure/xeno_hive_core/core
	/// Passive clutch and paid egg use different native role entries.
	var/spawner_type = /obj/effect/mob_spawn/ghost_role/xeno_hive

/obj/structure/xeno_hive_egg/Initialize(mapload, obj/structure/xeno_hive_core/core)
	. = ..()
	pixel_x = base_pixel_x + rand(-3, 3)
	pixel_y = base_pixel_y + rand(-3, 3)
	src.core = core
	core?.brood_eggs.Add(src)
	spawner = new spawner_type(src)
	spawner.egg = src

/obj/structure/xeno_hive_egg/Destroy()
	core?.brood_eggs.Remove(src)
	core = null
	QDEL_NULL(spawner)
	return ..()

/obj/structure/xeno_hive_egg/attack_ghost(mob/user)
	spawner?.attack_ghost(user)
	return ..()

/obj/structure/xeno_hive_egg/examine(mob/user)
	. = ..()
	. += span_notice("Свободных мест: [spawner?.uses || 0].")

/obj/structure/xeno_hive_egg/larva
	name = "larval egg"
	icon = 'icons/mob/nonhuman-player/alien.dmi'
	icon_state = "egg"
	desc = "Крупное яйцо с полноценной личинкой. Если его уничтожить, потраченная биомасса не вернётся."
	spawner_type = /obj/effect/mob_spawn/ghost_role/xeno_hive/larva

/** Native ghost-role reservation handles simultaneous claims before any input. */
/obj/effect/mob_spawn/ghost_role/xeno_hive
	name = "Выводок улья"
	prompt_name = "помощником улья"
	mob_type = /mob/living/carbon/alien/brood
	uses = 1
	deletes_on_zero_uses_left = FALSE
	prompt_ghost = FALSE
	role_ban = ROLE_ALIEN
	spawner_job_path = /datum/job/xenomorph
	you_are_text = "Вы — младший помощник улья."
	flavour_text = "Младший выводок служит улью с первых минут жизни. Королева открывает новые виды и способности в дереве развития. Для общения используйте :a."
	important_text = "Младшее потомство не эволюционирует и не добывает биомассу. После смерти можно занять новое свободное место."
	/// Physical owner; released when either side is destroyed.
	var/obj/structure/xeno_hive_egg/egg
	/// Full larvae are independent of subsequent core loss.
	var/larval_egg = FALSE
	/// Observer id -> FALSE during native eligibility checks, TRUE after native reservation.
	var/list/reservations = list()
	/// Server-approved caste selections, keyed by observer ref strings without owning observers.
	var/list/choices = list()

/obj/effect/mob_spawn/ghost_role/xeno_hive/Destroy()
	egg = null
	reservations.Cut()
	choices.Cut()
	return ..()

/** Preserve native reservation and ckey locking, then release per-observer choice state. */
/obj/effect/mob_spawn/ghost_role/xeno_hive/attack_ghost(mob/dead/observer/user)
	if(QDELETED(user) || !isobserver(user) || !user.client)
		return FALSE
	var/observer_id = REF(user)
	if(observer_id in reservations)
		return FALSE
	reservations[observer_id] = FALSE
	. = ..()
	if(!QDELETED(src))
		reservations -= observer_id
		choices -= observer_id

/** Ban lookups may yield; keep them out of SSobj processing and native synchronous notifications. */
/obj/effect/mob_spawn/ghost_role/xeno_hive/proc/notify_available(message, header)
	for(var/mob/dead/observer/ghost in GLOB.player_list)
		if(QDELETED(src))
			return
		var/ghost_ckey = ghost.ckey
		if(is_banned_from(ghost_ckey, role_ban))
			continue
		if(QDELETED(src) || QDELETED(egg) || uses <= 0)
			return
		if(QDELETED(ghost) || !ghost.client || ghost.ckey != ghost_ckey || !allow_spawn(ghost) || !(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER))
			continue
		ghost.spawners_menu?.update_static_data(ghost)
		notify_ghosts(message, source = src, header = header, click_interact = TRUE, ignore_key = POLL_IGNORE_ALIEN_LARVA, notify_flags = NOTIFY_CATEGORY_NOFLASH, recipients = list(ghost))

/obj/effect/mob_spawn/ghost_role/xeno_hive/allow_spawn(mob/user, silent = FALSE)
	. = ..()
	if(!. || QDELETED(user) || !isobserver(user) || !user.client || QDELETED(egg) || loc != egg || !isturf(egg.loc))
		return FALSE
	// The native ban lookup can sleep before reserving uses. Recheck the last place
	// here, while still allowing its owner through the post-selection validation.
	if(uses <= 0 && !reservations[REF(user)])
		return FALSE
	if(larval_egg)
		return TRUE
	return !QDELETED(egg.core) && egg.core == GLOB.xeno_hive?.core && (egg in egg.core.brood_eggs) && egg.core.next_to_core(egg) && egg.core.is_installed() && GLOB.xeno_hive.living_queen()

/** Each observer's selection is stored separately until the synchronous creation step. */
/obj/effect/mob_spawn/ghost_role/xeno_hive/pre_ghost_take(mob/dead/observer/user)
	reservations[REF(user)] = TRUE
	if(larval_egg)
		var/accepted = tgui_alert(user, "Стать полноценной личинкой? Прежнее тело после переселения уже нельзя будет воскресить.", "Улей", list("Да", "Нет"), 10 SECONDS) == "Да"
		return accepted && !QDELETED(src) && !QDELETED(user) && allow_spawn(user)
	var/list/options = GLOB.xeno_hive.brood_options()
	var/choice = tgui_input_list(user, "Выберите существо младшего выводка. После переселения прежнее тело нельзя будет воскресить.", "Улей", options)
	if(QDELETED(src) || QDELETED(user) || !user.client || !allow_spawn(user) || !(choice in options))
		return FALSE
	// String keys do not retain observers across a cancelled prompt.
	choices[REF(user)] = options[choice]
	return TRUE

/obj/effect/mob_spawn/ghost_role/xeno_hive/create(mob/mob_possessor, newname, apply_prefs)
	if(!allow_spawn(mob_possessor))
		return CANCEL_SPAWN
	if(!larval_egg)
		var/chosen_type = choices[REF(mob_possessor)]
		choices -= REF(mob_possessor)
		if(!GLOB.xeno_hive.brood_type_available(chosen_type))
			return CANCEL_SPAWN
		mob_type = chosen_type
	// Native create/special/check_uses do not sleep, so the shared gate commits atomically.
	. = ..()
	if(ismob(.) && mob_type == /mob/living/carbon/alien/brood/baneling)
		GLOB.xeno_hive.next_baneling_at = world.time + GLOB.xeno_hive.baneling_interval

/obj/effect/mob_spawn/ghost_role/xeno_hive/Topic(href, list/href_list)
	. = ..()
	if(. || !href_list["activate"] || !isobserver(usr))
		return
	attack_ghost(usr)

/obj/effect/mob_spawn/ghost_role/xeno_hive/larva
	name = "Полноценная личинка улья"
	prompt_name = "полноценной личинкой"
	mob_type = /mob/living/carbon/alien/larva
	uses = 1
	larval_egg = TRUE
	you_are_text = "Вы — полноценная личинка улья."
	flavour_text = "Растите и эволюционируйте! На создание яйца королева потратила биомассу нескольких жертв. Для общения используйте :a."
	important_text = "После вылупления яйцо исчезнет."

/obj/effect/mob_spawn/ghost_role/xeno_hive/check_uses()
	. = ..()
	if(uses <= 0)
		qdel(egg)

/** All choices are revalidated at creation; an open prompt cannot reserve a baneling cooldown. */
/datum/xeno_hive/proc/brood_type_available(brood_type)
	switch(brood_type)
		if(/mob/living/carbon/alien/brood)
			return TRUE
		if(/mob/living/carbon/alien/brood/mantis)
			return !!purchased["brood_mantis"]
		if(/mob/living/carbon/alien/brood/scorpion)
			return !!purchased["brood_scorpion"]
		if(/mob/living/carbon/alien/brood/baneling)
			return purchased["brood_baneling"] && world.time >= next_baneling_at
	return FALSE

/datum/xeno_hive/proc/brood_options()
	var/list/options = list("Жук" = /mob/living/carbon/alien/brood)
	if(brood_type_available(/mob/living/carbon/alien/brood/mantis))
		options["Богомол"] = /mob/living/carbon/alien/brood/mantis
	if(brood_type_available(/mob/living/carbon/alien/brood/scorpion))
		options["Скорпион"] = /mob/living/carbon/alien/brood/scorpion
	if(brood_type_available(/mob/living/carbon/alien/brood/baneling))
		options["Банелинг"] = /mob/living/carbon/alien/brood/baneling
	return options

/datum/xeno_hive
	/// The one physical core may be installed or carried.
	var/obj/item/packed_xeno_hive_core/packed_core
	var/core_announcement_timer
	var/core_revealed = FALSE
	var/core_blockade_registered = FALSE

/datum/xeno_hive/proc/can_unfold_core(mob/living/carbon/alien/adult/banda/queen/queen)
	if(QDELETED(packed_core))
		return TRUE
	return queen.is_holding(packed_core) || (isturf(packed_core.loc) && queen.Adjacent(packed_core))

/datum/xeno_hive/proc/core_arrived()
	if(!core_revealed && !core_announcement_timer)
		core_announcement_timer = addtimer(CALLBACK(src, PROC_REF(reveal_core)), 10 MINUTES, TIMER_STOPPABLE)
	update_core_blockade()

/datum/xeno_hive/proc/core_removed()
	if(!QDELETED(core) || !QDELETED(packed_core))
		return
	if(core_announcement_timer)
		deltimer(core_announcement_timer)
		core_announcement_timer = null
	core_revealed = FALSE
	update_core_blockade()

/datum/xeno_hive/proc/reveal_core()
	core_announcement_timer = null
	var/atom/current_core = QDELETED(core) ? packed_core : core
	if(QDELETED(current_core) || !get_turf(current_core))
		return
	core_revealed = TRUE
	priority_announce("Обнаружено ядро выводка. Последний сигнал: [get_area_name(current_core)]. Ядро может задержать обычную эвакуацию.", "Биологическая угроза")

/datum/xeno_hive/proc/update_core_blockade()
	if(QDELETED(SSshuttle?.emergency))
		if(core_blockade_registered && SSshuttle)
			SSshuttle.hostile_environments -= src
		core_blockade_registered = FALSE
		return
	var/atom/current_core = QDELETED(core) ? packed_core : core
	var/turf/core_location = get_turf(current_core)
	var/should_block = !QDELETED(src) && !GLOB.xeno_evacuation?.active && core_location && is_station_level(core_location.z) && !isspaceturf(core_location)
	if(should_block == core_blockade_registered)
		return
	core_blockade_registered = should_block
	if(should_block)
		SSshuttle.registerHostileEnvironment(src)
	else
		SSshuttle.clearHostileEnvironment(src)

/obj/item/packed_xeno_hive_core
	name = "свёрнутое ядро выводка"
	desc = "Сжатый маточный мешок. Королева может снова развернуть его на траве."
	icon = 'icons/mob/nonhuman-player/alien.dmi'
	icon_state = "egg"
	color = "#9e86b6"
	w_class = WEIGHT_CLASS_NORMAL
	uses_integrity = TRUE
	max_integrity = 250

/obj/item/packed_xeno_hive_core/Destroy()
	if(GLOB.xeno_hive?.packed_core == src)
		GLOB.xeno_hive.packed_core = null
		GLOB.xeno_hive.core_removed()
	return ..()

/// Welding lets crew attack the objective without a weapon.
/proc/sear_xeno_structure(obj/target, mob/living/user, obj/item/tool, damage)
	if(!target.CheckReachableAdjacency(user, 1) || !tool.tool_start_check(user, amount = 1) || !tool.use_tool(target, user, 2 SECONDS, amount = 1, volume = 50))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(target) || QDELETED(user) || QDELETED(tool) || user.incapacitated || !target.CheckReachableAdjacency(user, 1) || !user.is_holding(tool))
		return ITEM_INTERACT_BLOCKING
	target.take_damage(damage, BURN, FIRE)
	return ITEM_INTERACT_SUCCESS

/obj/structure/xeno_hive_core/welder_act(mob/living/user, obj/item/tool)
	return sear_xeno_structure(src, user, tool, 20)

/obj/item/packed_xeno_hive_core/welder_act(mob/living/user, obj/item/tool)
	return sear_xeno_structure(src, user, tool, 20)
