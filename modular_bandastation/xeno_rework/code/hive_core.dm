/** One installed physical core. Moving or deleting it destroys unused weak brood. */
/obj/structure/xeno_hive_core
	name = "hive core"
	desc = "Пульсирующее ядро роя. Его уничтожение прерывает рост слабого потомства и уничтожает невостребованную кладку."
	icon = 'modular_bandastation/xeno_rework/icons/brood/hive_core.dmi'
	icon_state = "core"
	pixel_x = -16
	pixel_y = -12
	anchored = TRUE
	density = FALSE
	max_integrity = 250
	/// Owned physical clutch; created only when the first place is earned.
	var/obj/structure/xeno_hive_egg/clutch
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
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(core_moved))
	START_PROCESSING(SSobj, src)

/obj/structure/xeno_hive_core/Destroy()
	STOP_PROCESSING(SSobj, src)
	QDEL_NULL(clutch)
	if(GLOB.xeno_hive?.core == src)
		GLOB.xeno_hive.core = null
		GLOB.xeno_hive.brood_points = 0
	return ..()

/obj/structure/xeno_hive_core/proc/core_moved()
	SIGNAL_HANDLER
	qdel(src)

/obj/structure/xeno_hive_core/proc/is_installed()
	return isturf(loc) && (locate(/obj/structure/alien/weeds) in loc)

/obj/structure/xeno_hive_core/process(seconds_per_tick)
	if(world.time >= crew_sample_time)
		cached_crew = GLOB.xeno_hive.count_crew()
		crew_sample_time = world.time + 10 SECONDS
	GLOB.xeno_hive.advance_brood(seconds_per_tick, cached_crew)

/obj/structure/xeno_hive_core/proc/add_brood(places)
	if(QDELETED(clutch))
		clutch = new(loc, src)
	clutch.spawner.uses += places
	if(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER)
		INVOKE_ASYNC(clutch.spawner, TYPE_PROC_REF(/obj/effect/mob_spawn/ghost_role/xeno_hive, notify_available), "В кладке роя доступно мест: [clutch.spawner.uses].", "Слабое потомство улья")

/** Reusable destructible shell for both weak brood and purchased full larvae. */
/obj/structure/xeno_hive_egg
	name = "hive clutch"
	desc = "Слабое потомство ждёт пробуждения. Уничтожение кладки уничтожит все невостребованные места."
	icon = 'icons/effects/effects.dmi'
	icon_state = "eggs"
	anchored = TRUE
	density = FALSE
	max_integrity = 60
	/// Shell-owned role entry; deleted with the shell.
	var/obj/effect/mob_spawn/ghost_role/xeno_hive/spawner
	/// Only passive clutches are tied to the core lifecycle.
	var/obj/structure/xeno_hive_core/core
	/// Passive clutch and paid egg use different native role entries.
	var/spawner_type = /obj/effect/mob_spawn/ghost_role/xeno_hive

/obj/structure/xeno_hive_egg/Initialize(mapload, obj/structure/xeno_hive_core/core)
	. = ..()
	src.core = core
	spawner = new spawner_type(src)
	spawner.egg = src

/obj/structure/xeno_hive_egg/Destroy()
	if(core?.clutch == src)
		core.clutch = null
	core = null
	QDEL_NULL(spawner)
	return ..()

/obj/structure/xeno_hive_egg/attack_ghost(mob/user)
	spawner?.attack_ghost(user)
	return ..()

/obj/structure/xeno_hive_egg/examine(mob/user)
	. = ..()
	. += span_notice("Невостребованных мест: [spawner?.uses || 0].")

/obj/structure/xeno_hive_egg/larva
	name = "larval egg"
	desc = "Крупное яйцо с полноценной личинкой. При уничтожении биомасса не возвращается."
	spawner_type = /obj/effect/mob_spawn/ghost_role/xeno_hive/larva

/** Native ghost-role reservation handles simultaneous claims before any input. */
/obj/effect/mob_spawn/ghost_role/xeno_hive
	name = "Выводок улья"
	prompt_name = "помощником улья"
	mob_type = /mob/living/carbon/alien/brood
	uses = 0
	deletes_on_zero_uses_left = FALSE
	prompt_ghost = FALSE
	role_ban = ROLE_ALIEN
	spawner_job_path = /datum/job/xenomorph
	you_are_text = "Вы — бруд, помощник улья."
	flavour_text = "Микродрон разводит траву и чинит смолу, разведчик отмечает добычу, переносчик быстро эвакуирует тела. Общайтесь через :a."
	important_text = "Вы не можете эволюционировать и не добываете биомассу. После смерти можно снова занять свободное место."
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
	return !QDELETED(egg.core) && egg.core == GLOB.xeno_hive?.core && egg.loc == egg.core.loc && egg.core.is_installed() && GLOB.xeno_hive.living_queen()

/** Each observer's selection is stored separately until the synchronous creation step. */
/obj/effect/mob_spawn/ghost_role/xeno_hive/pre_ghost_take(mob/dead/observer/user)
	reservations[REF(user)] = TRUE
	if(larval_egg)
		var/accepted = tgui_alert(user, "Стать полноценной личинкой? После входа прежнее тело нельзя будет воскресить.", "Улей", list("Да", "Нет"), 10 SECONDS) == "Да"
		return accepted && !QDELETED(src) && !QDELETED(user) && allow_spawn(user)
	var/list/options = list("Микродрон" = /mob/living/carbon/alien/brood)
	if(GLOB.xeno_hive.purchased["brood_scout"])
		options["Разведчик"] = /mob/living/carbon/alien/brood/scout
	if(GLOB.xeno_hive.purchased["brood_carrier"])
		options["Переносчик"] = /mob/living/carbon/alien/brood/carrier
	var/choice = tgui_input_list(user, "Выберите слабое потомство. После входа прежнее тело нельзя будет воскресить.", "Улей", options)
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
		if(!ispath(chosen_type, /mob/living/carbon/alien/brood))
			return CANCEL_SPAWN
		mob_type = chosen_type
	// Native create/special/check_uses do not sleep, so mob_type cannot race here.
	return ..()

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
	flavour_text = "Растите и эволюционируйте. Королева потратила на ваше яйцо биомассу нескольких жертв. Общайтесь через :a."
	important_text = "После вылупления яйцо исчезнет."

/obj/effect/mob_spawn/ghost_role/xeno_hive/larva/check_uses()
	. = ..()
	if(uses <= 0)
		qdel(egg)
