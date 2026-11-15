GLOBAL_DATUM(xeno_evacuation, /datum/xeno_evacuation)

ADMIN_VERB(start_xeno_evacuation_test, R_DEBUG, "Ксеноморфы: начать финал (тест)", "Запускает финальную эвакуацию роя без проверки его численности.", ADMIN_CATEGORY_DEBUG)
	if(!SSticker.IsRoundInProgress())
		to_chat(user, span_warning("Финал роя можно запустить только во время раунда."))
		return
	if(!GLOB.xeno_evacuation)
		GLOB.xeno_evacuation = new
	if(!GLOB.xeno_evacuation.begin_evacuation())
		to_chat(user, span_warning("Финал уже запущен или завершён, либо эвакуационный шаттл недоступен для запуска сценария."))
		return
	log_admin("[key_name(user)] started the xeno evacuation finale for testing, bypassing population requirements.")
	message_admins("[key_name_admin(user)] запустил финальную эвакуацию ксеноморфов для теста без проверки численности роя.")
	to_chat(user, span_notice("Финал роя запущен. После стыковки шаттла начнётся оборона на десять минут; ксеноморфы могут взломать его навигационную консоль."))
	BLACKBOX_LOG_ADMIN_VERB("Start Xeno Evacuation Test")

/// One evacuation finale per round. Population checks are debounced off login/death events.
/datum/xeno_evacuation
	/// Minimum connected station xenos required to start evacuation.
	var/minimum_xenos = 15
	/// Required ratio of connected station xenos to surviving crew.
	var/crew_ratio = 0.5
	/// Duration of the docked defense phase, in deciseconds.
	var/defense_duration = 10 MINUTES
	/// Uninterrupted time needed for one navigation hacking stage.
	var/hack_duration = 30 SECONDS
	/// Launch countdown after the finale is decided.
	var/departure_delay = 10 SECONDS
	/// Optional /datum/map_template/shuttle subtype; null keeps the currently selected emergency shuttle.
	var/shuttle_template
	/// Whether the evacuation finale has started this round.
	var/active = FALSE
	/// Guards the asynchronous custom-shuttle replacement.
	var/starting = FALSE
	/// Whether the emergency shuttle has docked for the defense phase.
	var/defending = FALSE
	/// Prevents a second result or a late hacking completion.
	var/resolved = FALSE
	/// Winning side, or null until the finale is resolved.
	var/outcome
	/// Absolute world.time when the defense succeeds.
	var/defense_deadline = 0
	/// Last minute broadcast to suppress duplicate radio alarms.
	var/last_announced_minute = -1
	/// Completed shared navigation stages, from zero through four.
	var/hack_stage = 0
	/// Whether a xeno currently owns the hacking channel.
	var/hack_busy = FALSE
	/// Debounces global population-change signals.
	var/check_queued = FALSE
	/// Weak references to unused ERT roles owned by this finale.
	var/list/datum/weakref/ert_spawners = list()
	/// Registered result callback, released from the ticker on teardown.
	var/datum/callback/roundend_callback

/datum/xeno_evacuation/New()
	. = ..()
	RegisterSignals(SSdcs, list(COMSIG_GLOB_MOB_DEATH, COMSIG_GLOB_PLAYER_LOGIN, COMSIG_GLOB_PLAYER_LOGOUT), PROC_REF(queue_population_check))
	roundend_callback = CALLBACK(src, PROC_REF(roundend_report))
	SSticker.OnRoundend(roundend_callback)

/datum/xeno_evacuation/Destroy()
	UnregisterSignal(SSdcs, list(COMSIG_GLOB_MOB_DEATH, COMSIG_GLOB_PLAYER_LOGIN, COMSIG_GLOB_PLAYER_LOGOUT))
	LAZYREMOVE(SSticker.round_end_events, roundend_callback)
	roundend_callback = null
	clear_spawners()
	return ..()

/** Debounce population events into one delayed recount. */
/datum/xeno_evacuation/proc/queue_population_check()
	SIGNAL_HANDLER
	if(check_queued || active || starting || resolved)
		return
	check_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(check_population)), 1 SECONDS)

/** Evaluate the minimum population and relative crew threshold. */
/datum/xeno_evacuation/proc/population_qualifies(xenos, crew)
	return xenos >= minimum_xenos && xenos >= crew * crew_ratio

/** Count connected station xenos and surviving crew before starting the finale. */
/datum/xeno_evacuation/proc/check_population()
	check_queued = FALSE
	if(active || starting || resolved || !SSticker.IsRoundInProgress())
		return
	var/xenos = 0
	var/crew = 0
	for(var/mob/living/member in GLOB.alive_mob_list)
		if(istype(member, /mob/living/carbon/alien/adult/banda) && member.client && is_station_level(member.z))
			xenos++
		else if(!isalien(member) && (member.mind?.assigned_role?.job_flags & JOB_CREW_MEMBER))
			crew++
	if(population_qualifies(xenos, crew))
		begin_evacuation()

/** Start the one-shot evacuation finale and optionally replace an idle shuttle. */
/datum/xeno_evacuation/proc/begin_evacuation()
	var/obj/docking_port/mobile/emergency/shuttle = SSshuttle.emergency
	if(active || starting || resolved || !shuttle || !(shuttle.mode in list(SHUTTLE_IDLE, SHUTTLE_RECALL, SHUTTLE_CALL, SHUTTLE_DOCKED)))
		return FALSE
	starting = TRUE
	if(shuttle_template && shuttle.mode == SHUTTLE_IDLE)
		var/datum/map_template/shuttle/template = new shuttle_template
		SSshuttle.existing_shuttle = shuttle
		SSshuttle.action_load(template, replace = TRUE)
		shuttle = SSshuttle.emergency
		qdel(template)
	starting = FALSE
	if(!shuttle || !SSticker.IsRoundInProgress())
		return FALSE
	active = TRUE
	priority_announce("Ксеноморфная угроза вышла из-под контроля. Начата заключительная эвакуация. После стыковки удерживайте шаттл десять минут. Не подпускайте ксеноморфов к навигационной консоли! На борту доступен отряд сопровождения.", "Протокол последнего рубежа", sound = 'sound/announcer/announcement/announce.ogg')
	if(shuttle.mode == SHUTTLE_IDLE || shuttle.mode == SHUTTLE_RECALL)
		SSshuttle.call_evac_shuttle("Критическая ксеноморфная угроза. Отзыв эвакуации заблокирован.")
	update_shuttle(shuttle)
	log_game("Xeno evacuation finale triggered.")
	return TRUE

/// Driven by the existing emergency shuttle check, including a check after docking.
/datum/xeno_evacuation/proc/update_shuttle(obj/docking_port/mobile/emergency/shuttle)
	if(!active || resolved || shuttle != SSshuttle.emergency)
		return
	if(shuttle.mode != SHUTTLE_DOCKED)
		return
	if(!defending)
		defending = TRUE
		defense_deadline = world.time + defense_duration
		deploy_ert(shuttle)
	if(world.time >= defense_deadline)
		if(has_survivors(shuttle))
			resolve(XENO_EVAC_CREW, shuttle)
		else
			priority_announce("На борту не осталось выживших членов экипажа или бойцов сопровождения. Эвакуация потеряна! Запуск через десять секунд.", "Последний рубеж")
			resolve(XENO_EVAC_XENOS, shuttle)
		return
	// Keep native ignition from closing the hacking window before the defense deadline.
	shuttle.setTimer(max(defense_deadline - world.time, ENGINE_START_TIME + 1 SECONDS))
	var/minutes_left = CEILING((defense_deadline - world.time) / (1 MINUTES), 1)
	if(minutes_left != last_announced_minute)
		last_announced_minute = minutes_left
		var/message = "Тревога! Оборона эвакуационного шаттла: до разблокировки запуска [minutes_left] мин. Защитите навигационную консоль!"
		priority_announce(message, "Последний рубеж", sound = 'sound/announcer/announcement/announce.ogg')
		for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
			var/obj/machinery/computer/emergency_shuttle/console = locate() in shuttle_area
			if(!console)
				continue
			var/obj/item/radio/radio = new(console)
			radio.talk_into(console, message, RADIO_CHANNEL_COMMON)
			QDEL_IN(radio, 2 SECONDS)
			break

/// A defended shuttle must still carry a living crew member or an ERT responder.
/datum/xeno_evacuation/proc/has_survivors(obj/docking_port/mobile/emergency/shuttle)
	for(var/mob/living/survivor in GLOB.alive_mob_list)
		if(isalien(survivor) || !(get_area(survivor) in shuttle.shuttle_areas))
			continue
		if((survivor.mind?.assigned_role?.job_flags & JOB_CREW_MEMBER) || istype(survivor.mind?.assigned_role, /datum/job/ert))
			return TRUE
	return FALSE

/** Revalidate the live adjacent xeno, console ownership and defense phase. */
/datum/xeno_evacuation/proc/can_hack(mob/living/carbon/alien/adult/banda/xeno, obj/machinery/computer/emergency_shuttle/console)
	return active && defending && !resolved && istype(xeno) && !QDELETED(xeno) && !QDELETED(console) && !xeno.incapacitated && isturf(xeno.loc) && xeno.Adjacent(console) && SSshuttle.emergency?.mode == SHUTTLE_DOCKED && (get_area(console) in SSshuttle.emergency.shuttle_areas) && world.time < defense_deadline

/** Channel one shared navigation stage and resolve a completed takeover. */
/datum/xeno_evacuation/proc/hack(mob/living/carbon/alien/adult/banda/xeno, obj/machinery/computer/emergency_shuttle/console)
	if(hack_busy || !can_hack(xeno, console))
		return FALSE
	hack_busy = TRUE
	xeno.add_filter("xeno_shuttle_hack", 2, drop_shadow_filter(size = 2, color = "#70428b"))
	xeno.transition_filter_chain("xeno_shuttle_hack", INDEFINITE,
		filter_chain_step(list("size" = 4), 0.5 SECONDS),
		filter_chain_step(list("size" = 2), 0.5 SECONDS))
	priority_announce("Обнаружено ксеноморфное вмешательство в навигацию! Защитите консоль шаттла!", "Тревога эвакуации")
	to_chat(xeno, span_notice("Начат взлом навигации: этап [hack_stage + 1]/4. Не двигайтесь 30 секунд."))
	var/ready = do_after(xeno, hack_duration, target = console)
	if(!QDELETED(xeno))
		xeno.remove_filter("xeno_shuttle_hack")
	hack_busy = FALSE
	if(!ready || !can_hack(xeno, console))
		return FALSE
	hack_stage = istype(xeno, /mob/living/carbon/alien/adult/banda/queen) ? 4 : hack_stage + 1
	playsound(console, 'sound/machines/terminal/terminal_alert.ogg', 60, FALSE)
	priority_announce("Нарушение навигации шаттла: [hack_stage]/4. [hack_stage >= 4 ? "Управление потеряно! Отправление через 10 секунд." : "Остановите ксеноморфов у консоли!"]", "Тревога эвакуации")
	if(hack_stage >= 4)
		resolve(XENO_EVAC_XENOS, SSshuttle.emergency)
	return TRUE

/** Record one result, remove unused ERT roles and start the launch countdown. */
/datum/xeno_evacuation/proc/resolve(winner, obj/docking_port/mobile/emergency/shuttle)
	if(resolved)
		return
	resolved = TRUE
	outcome = winner
	clear_spawners()
	if(winner == XENO_EVAC_XENOS)
		shuttle.hijack_status = HIJACK_COMPLETED
	else
		priority_announce("Оборона завершена. Экипаж удержал шаттл! Запуск через десять секунд.", "Последний рубеж")
	shuttle.setTimer(departure_delay)
	log_game("Xeno evacuation finale result: [winner].")

/** Announce the finale result before the normal roundend report. */
/datum/xeno_evacuation/proc/roundend_report()
	clear_spawners()
	if(!active)
		return
	var/result = outcome == XENO_EVAC_XENOS ? "Победа ксеноморфов: эвакуационный шаттл захвачен." : outcome == XENO_EVAC_CREW ? "Победа выживших: эвакуационный шаттл удержан." : "Оборона шаттла была прервана до определения победителя."
	to_chat(world, span_boldannounce(result))

/datum/controller/subsystem/dynamic/set_round_result()
	. = ..()
	if(GLOB.xeno_evacuation?.outcome && SSshuttle.emergency?.mode == SHUTTLE_ENDGAME && !GLOB.station_was_nuked)
		SSticker.mode_result = "xeno evacuation - [GLOB.xeno_evacuation.outcome] victory"
		SSticker.news_report = GLOB.xeno_evacuation.outcome == XENO_EVAC_XENOS ? SHUTTLE_HIJACK : STATION_EVACUATED

/** Place up to three ghost roles on unobstructed shuttle floors. */
/datum/xeno_evacuation/proc/deploy_ert(obj/docking_port/mobile/emergency/shuttle)
	var/remaining = 3
	for(var/turf/location as anything in shuttle.return_turfs())
		if(!(get_area(location) in shuttle.shuttle_areas) || !isfloorturf(location) || location.is_blocked_turf())
			continue
		var/obj/effect/mob_spawn/ghost_role/human/xeno_defense/spawner = new(location)
		ert_spawners += WEAKREF(spawner)
		remaining--
		if(!remaining)
			notify_ghosts("Три места ЕРТ для обороны эвакуационного шаттла доступны в меню ролей.", source = spawner, header = "Оборона шаттла", notify_flags = NOTIFY_CATEGORY_NOFLASH)
			break

	for(var/turf/location as anything in shuttle.return_turfs())
		if((get_area(location) in shuttle.shuttle_areas) && isfloorturf(location) && !location.is_blocked_turf())
			new /obj/structure/closet/crate/field_fortifications(location)
			break

/** Delete unused ERT roles and release their weak references. */
/datum/xeno_evacuation/proc/clear_spawners()
	for(var/datum/weakref/reference as anything in ert_spawners)
		var/obj/effect/mob_spawn/spawner = reference.resolve()
		if(spawner)
			qdel(spawner)
	ert_spawners.Cut()

/obj/docking_port/mobile/emergency/check()
	GLOB.xeno_evacuation?.update_shuttle(src)
	. = ..()
	GLOB.xeno_evacuation?.update_shuttle(src)

/obj/docking_port/mobile/emergency/cancel(area/signal_origin)
	if(GLOB.xeno_evacuation?.active && !GLOB.xeno_evacuation.resolved)
		return
	return ..()

/obj/machinery/computer/emergency_shuttle/process()
	if(GLOB.xeno_evacuation?.active && !GLOB.xeno_evacuation.resolved)
		return FALSE
	return ..()

/obj/machinery/computer/emergency_shuttle/attack_alien(mob/living/carbon/alien/user, list/modifiers)
	if(istype(user, /mob/living/carbon/alien/adult/banda) && GLOB.xeno_evacuation?.active)
		return GLOB.xeno_evacuation.hack(user, src)
	return ..()

/obj/machinery/computer/emergency_shuttle/attempt_hijack_stage(mob/living/user)
	if(GLOB.xeno_evacuation?.active && !GLOB.xeno_evacuation.resolved)
		to_chat(user, span_warning("Протокол последнего рубежа блокирует перепрограммирование навигации."))
		return
	return ..()

/** One-use heavily equipped ERT ghost role for the evacuation defense. */
/obj/effect/mob_spawn/ghost_role/human/xeno_defense
	name = "капсула ЕРТ — последний рубеж"
	prompt_name = "бойца ЕРТ сопровождения эвакуации"
	you_are_text = "Вы — боец ЕРТ сопровождения."
	flavour_text = "Защитите выживших и навигационную консоль до окончания обороны. Ксеноморфы попытаются захватить шаттл."
	spawner_job_path = /datum/job/ert
	outfit = /datum/outfit/centcom/ert/security/alert

/obj/effect/mob_spawn/ghost_role/human/xeno_defense/allow_spawn(mob/user, silent = FALSE)
	return GLOB.xeno_evacuation?.defending && !GLOB.xeno_evacuation.resolved && ..()
