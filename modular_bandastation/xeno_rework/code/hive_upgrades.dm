/** One definition drives purchases, effects, icons and the visible upgrade tree. */
/datum/xeno_hive_upgrade
	/// Stable server purchase key.
	var/id
	/// Readable title and exact effect.
	var/name
	/// Full description shown beside the selected node.
	var/desc
	/// The three freely mixable development branches.
	var/branch = "Функциональность"
	/// FontAwesome symbol from the existing TGUI icon set.
	var/icon = "dna"
	/// Column within this branch, increasing along prerequisite edges.
	var/tree_x = 0
	/// Row within this branch.
	var/tree_y = 0
	/// Biomass before repeatable level scaling.
	var/cost = 100
	/// INFINITY is reserved for purchased larval eggs.
	var/max_level = 1
	/// All prerequisites must be owned before and after the purchase channel.
	var/list/requires = list()
	/// Slot purchases become progressively more expensive.
	var/scaling_cost = FALSE
	/// Exact evolution_tier receiving stat bonuses; zero denotes a functional node.
	var/target_tier = 0
	/// Added maximum health for the matching tier.
	var/health_bonus = 0
	/// Added claw damage for the matching tier.
	var/claw_bonus = 0
	/// Extra simultaneous slot for exactly this caste.
	var/slot_type

/datum/xeno_hive_upgrade/proc/price(level)
	return cost * (scaling_cost ? level + 1 : 1)

/datum/xeno_hive_upgrade/carapace
	id = "carapace"
	name = "Адаптация T1"
	desc = "Все боевые касты T1: +15 здоровья и +2 урона когтей. Королева и потомство не затрагиваются."
	branch = "Качество"
	cost = 150
	icon = "dna"
	tree_x = 0
	tree_y = 1
	target_tier = 1
	health_bonus = 15
	claw_bonus = 2

/datum/xeno_hive_upgrade/claws
	id = "claws"
	name = "Адаптация T2"
	desc = "Все касты T2: +25 здоровья и +3 урона когтей."
	branch = "Качество"
	cost = 200
	icon = "shield-halved"
	tree_x = 1
	tree_y = 1
	requires = list("carapace")
	target_tier = 2
	health_bonus = 25
	claw_bonus = 3

/datum/xeno_hive_upgrade/tier3
	id = "tier3"
	name = "Адаптация T3"
	desc = "Все касты T3: +35 здоровья и +4 урона когтей."
	branch = "Качество"
	cost = 250
	icon = "hand-fist"
	tree_x = 2
	tree_y = 1
	requires = list("claws")
	target_tier = 3
	health_bonus = 35
	claw_bonus = 4

/datum/xeno_hive_upgrade/tier4
	id = "tier4"
	name = "Адаптация T4"
	desc = "Все специальные касты T4: +40 здоровья и +5 урона когтей."
	branch = "Качество"
	cost = 300
	icon = "crown"
	tree_x = 3
	tree_y = 1
	requires = list("tier3")
	target_tier = 4
	health_bonus = 40
	claw_bonus = 5

/datum/xeno_hive_upgrade/crusher
	id = "crusher"
	name = "Крушитель · Crusher"
	desc = "Воин может эволюционировать в Крушителя. Один одновременный слот; сама покупка не создаёт касту."
	branch = "Качество"
	cost = 300
	icon = "meteor"
	tree_x = 3
	tree_y = 0
	requires = list("tier3")

/datum/xeno_hive_upgrade/boiler
	id = "boiler"
	name = "Кислотная артиллерия · Boiler"
	desc = "Страж может эволюционировать в Бойлера. Один одновременный слот."
	branch = "Качество"
	cost = 350
	icon = "flask"
	tree_x = 3
	tree_y = 2
	requires = list("tier3")

/datum/xeno_hive_upgrade/mech
	id = "mech"
	name = "Разрыв брони мехов"
	desc = "Взрослые получают совместную атаку по мехам. Для пробития нужны разные ксеноморфы; управление и ремонт меха сохраняются."
	branch = "Качество"
	cost = 250
	icon = "gears"
	tree_x = 2
	tree_y = 0
	requires = list("claws")

/datum/xeno_hive_upgrade/larva
	id = "larva"
	name = "Вырастить личинку"
	desc = "У ядра создаётся разрушаемое яйцо полноценной личинки. 400 биомассы, возврата нет. Повторяемая покупка."
	branch = "Количество"
	cost = 400
	icon = "egg"
	tree_x = 0
	tree_y = 0
	max_level = INFINITY

/datum/xeno_hive_upgrade/warrior_slot
	id = "warrior_slot"
	name = "Резерв воинов"
	desc = "+1 одновременный слот Warrior. До трёх дополнительных слотов; цена растёт."
	branch = "Количество"
	cost = 180
	icon = "people-group"
	tree_x = 2
	tree_y = 0
	max_level = 3
	scaling_cost = TRUE
	slot_type = /mob/living/carbon/alien/adult/banda/warrior

/datum/xeno_hive_upgrade/praetorian_slot
	id = "praetorian_slot"
	name = "Резерв преторианцев"
	desc = "+1 одновременный слот Praetorian. До трёх дополнительных слотов; цена растёт."
	branch = "Количество"
	cost = 180
	icon = "chess-rook"
	tree_x = 0
	tree_y = 2
	max_level = 3
	scaling_cost = TRUE
	slot_type = /mob/living/carbon/alien/adult/banda/praetorian

/datum/xeno_hive_upgrade/ravager_slot
	id = "ravager_slot"
	name = "Резерв разорителей"
	desc = "+1 одновременный слот Ravager. До трёх дополнительных слотов; цена растёт."
	branch = "Количество"
	cost = 180
	icon = "khanda"
	tree_x = 2
	tree_y = 2
	max_level = 3
	scaling_cost = TRUE
	slot_type = /mob/living/carbon/alien/adult/banda/ravager

/datum/xeno_hive_upgrade/construction
	id = "construction"
	name = "Живая смола"
	desc = "Строительство смолы вдвое быстрее; сворачивание ядра за 3 секунды вместо 10."
	branch = "Функциональность"
	cost = 100
	icon = "trowel"
	tree_x = 0
	tree_y = 0

/datum/xeno_hive_upgrade/brood_vigor
	id = "brood_vigor"
	name = "Крепкий выводок"
	desc = "+20 здоровья живым и будущим брудам. Открывает развитие специализированного потомства. Эволюции во взрослых нет."
	branch = "Функциональность"
	cost = 100
	icon = "heart-pulse"
	tree_x = 1
	tree_y = 0
	requires = list("construction")

/datum/xeno_hive_upgrade/brood_scout
	id = "brood_scout"
	name = "Выводок разведчиков"
	desc = "Открывает разведчика: 45 здоровья, быстрый бег, укрытие, проход под дверями и феромонная метка добычи."
	branch = "Функциональность"
	cost = 80
	icon = "binoculars"
	tree_x = 2
	tree_y = 0
	requires = list("brood_vigor")

/datum/xeno_hive_upgrade/brood_carrier
	id = "brood_carrier"
	name = "Выводок переносчиков"
	desc = "Открывает переносчика: 90 здоровья, быстрый бег и перенос лежащих тел без обычного замедления."
	branch = "Функциональность"
	cost = 80
	icon = "truck-fast"
	tree_x = 2
	tree_y = 1
	requires = list("brood_vigor")

/datum/xeno_hive_upgrade/capture
	id = "capture"
	name = "Быстрое пленение"
	desc = "Подготовка кокона за 3 секунды вместо 6."
	branch = "Функциональность"
	cost = 100
	icon = "link"
	tree_x = 0
	tree_y = 1

/datum/xeno_hive_upgrade/processing
	id = "processing"
	name = "Переработка добычи"
	desc = "Обработка тела за 120 секунд вместо 150. Общая награда тела не увеличивается."
	branch = "Функциональность"
	cost = 150
	icon = "recycle"
	tree_x = 1
	tree_y = 1
	requires = list("capture")

/datum/xeno_hive_upgrade/coordination
	id = "coordination"
	name = "Связь охотников"
	desc = "Взрослые получают указание точки сбора с сообщением области в связь улья."
	branch = "Функциональность"
	cost = 80
	icon = "location-crosshairs"
	tree_x = 0
	tree_y = 2

/datum/xeno_hive_upgrade/pheromones
	id = "pheromones"
	name = "Восстановительные феромоны"
	desc = "Королева лечит по 5 ушибов и ожогов союзникам в view(5). 100 плазмы; перезарядка 30 секунд."
	branch = "Функциональность"
	cost = 180
	icon = "wind"
	tree_x = 1
	tree_y = 2
	requires = list("coordination")

/datum/xeno_hive_upgrade/hunter
	id = "hunter"
	name = "Диверсант · Hunter"
	desc = "Бегун может эволюционировать в Охотника. Один отдельный слот; доступ покупается в любое время."
	branch = "Функциональность"
	cost = 150
	icon = "user-ninja"
	tree_x = 3
	tree_y = 2

/** Independent caste limits; purchasing access never creates or evolves a mob. */
/datum/xeno_hive/proc/slot_limit(caste_type)
	var/limit = 1
	for(var/id in purchased)
		var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
		if(upgrade?.slot_type == caste_type)
			limit += purchased[id]
	return limit

/datum/xeno_hive/proc/slot_available(caste_type)
	var/count = 0
	for(var/mob/living/carbon/alien/adult/banda/member as anything in members)
		if(member.stat != DEAD && istype(member, caste_type))
			count++
	return count < slot_limit(caste_type)

/** Delta application preserves damage, mode changes, fruit buffs and admin adjustments. */
/datum/xeno_hive/proc/apply_upgrades(mob/living/carbon/alien/adult/banda/member)
	var/health_bonus = 0
	var/claw_bonus = 0
	for(var/id in purchased)
		var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
		if(!upgrade || !upgrade.target_tier || member.evolution_tier != upgrade.target_tier || istype(member, /mob/living/carbon/alien/adult/banda/queen))
			continue
		health_bonus += upgrade.health_bonus * purchased[id]
		claw_bonus += upgrade.claw_bonus * purchased[id]
	member.maxHealth += health_bonus - member.hive_health_bonus
	member.melee_damage_lower += claw_bonus - member.hive_claw_bonus
	member.melee_damage_upper += claw_bonus - member.hive_claw_bonus
	member.hive_health_bonus = health_bonus
	member.hive_claw_bonus = claw_bonus
	if(health_bonus || claw_bonus)
		member.add_filter("hive_adaptation", 1, outline_filter(size = 1, color = "#89966a80"))
	member.updatehealth()
	if(purchased["mech"] && !(locate(/datum/action/cooldown/alien/banda/mech_rend) in member.actions))
		member.grant_actions_by_list(list(/datum/action/cooldown/alien/banda/mech_rend))
	if(purchased["coordination"] && !(locate(/datum/action/cooldown/alien/banda/hive_rally) in member.actions))
		member.grant_actions_by_list(list(/datum/action/cooldown/alien/banda/hive_rally))
	if(istype(member, /mob/living/carbon/alien/adult/banda/queen) && purchased["pheromones"] && !(locate(/datum/action/cooldown/alien/banda/hive_pheromones) in member.actions))
		member.grant_actions_by_list(list(/datum/action/cooldown/alien/banda/hive_pheromones))

/mob/living/carbon/alien/adult/banda
	/// Previously applied deltas, preventing reapplication from stacking bonuses.
	var/hive_health_bonus = 0
	/// Already applied claw damage, separate from temporary caste modes.
	var/hive_claw_bonus = 0

/mob/living/carbon/alien/adult/banda/examine(mob/user)
	. = ..()
	if(hive_health_bonus)
		. += span_warning("Хитин выглядит особенно плотным и утолщённым.")
	if(hive_claw_bonus)
		. += span_warning("Когти покрыты дополнительными режущими зазубринами.")

/datum/xeno_hive/proc/can_manage(mob/living/carbon/alien/adult/banda/queen/queen)
	return istype(queen) && !QDELETED(queen) && queen == living_queen() && !IS_UNCONSCIOUS(queen) && !queen.incapacitated

/datum/xeno_hive/proc/can_buy(mob/living/carbon/alien/adult/banda/queen/queen, id)
	if(!can_manage(queen) || !istext(id))
		return FALSE
	var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
	if(!upgrade || purchased[id] >= upgrade.max_level || biomass < upgrade.price(purchased[id] || 0))
		return FALSE
	for(var/requirement in upgrade.requires)
		if(!purchased[requirement])
			return FALSE
	if(id == "larva" && (QDELETED(core) || !core.is_installed()))
		return FALSE
	return TRUE

/datum/xeno_hive/proc/on_purchase_damage(datum/source, damage_type, amount)
	SIGNAL_HANDLER
	if(amount > 0)
		purchase_interrupted = TRUE

/datum/xeno_hive/proc/can_channel(mob/living/carbon/alien/adult/banda/queen/queen, atom/origin)
	return !purchase_interrupted && can_manage(queen) && queen.loc == origin

/** One shared channel prevents overlapping purchases and core operations. */
/datum/xeno_hive/proc/channel(mob/living/carbon/alien/adult/banda/queen/queen, duration)
	if(purchase_busy || !can_manage(queen))
		return FALSE
	purchase_busy = TRUE
	purchase_interrupted = FALSE
	var/atom/origin = queen.loc
	RegisterSignals(queen, COMSIG_LIVING_ADJUST_ALL_DAMAGE_TYPES, PROC_REF(on_purchase_damage))
	queen.add_filter("hive_purchase", 2, drop_shadow_filter(size = 2, color = "#b070e8"))
	queen.transition_filter_chain("hive_purchase", INDEFINITE,
		filter_chain_step(list("size" = 5), 0.5 SECONDS, SINE_EASING),
		filter_chain_step(list("size" = 2), 0.5 SECONDS, SINE_EASING))
	var/ready = do_after(queen, duration, target = queen, extra_checks = CALLBACK(src, PROC_REF(can_channel), queen, origin))
	UnregisterSignal(queen, COMSIG_LIVING_ADJUST_ALL_DAMAGE_TYPES)
	if(!QDELETED(queen))
		queen.remove_filter("hive_purchase")
	purchase_busy = FALSE
	return ready && can_channel(queen, origin)

/datum/xeno_hive/proc/buy(mob/living/carbon/alien/adult/banda/queen/queen, id)
	if(purchase_busy || !can_buy(queen, id))
		return FALSE
	var/obj/structure/xeno_hive_core/original_core = core
	if(!channel(queen, purchase_time) || !can_buy(queen, id))
		return FALSE
	if(id == "larva" && core != original_core)
		return FALSE
	var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
	biomass -= upgrade.price(purchased[id] || 0)
	purchased[id] = (purchased[id] || 0) + 1
	if(id == "larva")
		var/obj/structure/xeno_hive_egg/egg = new /obj/structure/xeno_hive_egg/larva(get_turf(core))
		if(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER)
			INVOKE_ASYNC(egg.spawner, TYPE_PROC_REF(/obj/effect/mob_spawn/ghost_role/xeno_hive, notify_available), "Улей вырастил яйцо полноценной личинки.", "Личинка улья")
	for(var/mob/living/carbon/alien/adult/banda/member as anything in members)
		apply_upgrades(member)
	if(id == "brood_vigor")
		for(var/mob/living/carbon/alien/brood/brood in GLOB.mob_living_list)
			brood.apply_hive_upgrade()
	log_game("[key_name(queen)] purchased hive upgrade [id] for hive level [purchased[id]]. Remaining biomass: [biomass].")
	return TRUE

/datum/xeno_hive/proc/can_place_core(mob/living/carbon/alien/adult/banda/queen/queen)
	return can_manage(queen) && !core && isopenturf(queen.loc) && !isspaceturf(queen.loc) && (locate(/obj/structure/alien/weeds) in queen.loc)

/datum/xeno_hive/proc/place_core(mob/living/carbon/alien/adult/banda/queen/queen)
	if(!can_place_core(queen) || !channel(queen, 5 SECONDS) || !can_place_core(queen))
		return FALSE
	new /obj/structure/xeno_hive_core(queen.loc)
	return TRUE

/datum/xeno_hive/proc/pack_core(mob/living/carbon/alien/adult/banda/queen/queen)
	var/obj/structure/xeno_hive_core/original_core = core
	if(!can_manage(queen) || QDELETED(original_core) || !queen.Adjacent(original_core))
		return FALSE
	if(!channel(queen, purchased["construction"] ? 3 SECONDS : 10 SECONDS))
		return FALSE
	if(!can_manage(queen) || QDELETED(original_core) || core != original_core || !queen.Adjacent(original_core))
		return FALSE
	qdel(core)
	return TRUE

/datum/xeno_hive/ui_interact(mob/user, datum/tgui/ui)
	if(!can_manage(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoHiveEvolution")
		ui.open()

/datum/xeno_hive/ui_state(mob/user)
	return GLOB.always_state

/datum/xeno_hive/ui_status(mob/user, datum/ui_state/state)
	return can_manage(user) ? UI_INTERACTIVE : UI_CLOSE

/datum/xeno_hive/ui_data(mob/user)
	var/list/nodes = list()
	for(var/id in upgrades)
		var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
		nodes += list(list(
			"id" = id,
			"name" = upgrade.name,
			"description" = upgrade.desc,
			"branch" = upgrade.branch,
			"icon" = upgrade.icon,
			"x" = upgrade.tree_x,
			"y" = upgrade.tree_y,
			"cost" = upgrade.price(purchased[id] || 0),
			"level" = purchased[id] || 0,
			"maxLevel" = upgrade.max_level == INFINITY ? null : upgrade.max_level,
			"requires" = upgrade.requires,
			"available" = !purchase_busy && can_buy(user, id),
		))
	return list(
		"biomass" = biomass,
		"broodPoints" = round(brood_points, 0.1),
		"broodCost" = brood_slot_cost,
		"broodPlaces" = core?.clutch?.spawner?.uses || 0,
		"core" = !!core,
		"busy" = purchase_busy,
		"canPlace" = !purchase_busy && can_place_core(user),
		"canPack" = !purchase_busy && core && user.Adjacent(core),
		"nodes" = nodes,
	)

/datum/xeno_hive/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !can_manage(ui.user))
		return
	switch(action)
		if("buy")
			if(!istext(params["id"]) || !(params["id"] in upgrades))
				return FALSE
			INVOKE_ASYNC(src, PROC_REF(buy), ui.user, params["id"])
		if("place_core")
			INVOKE_ASYNC(src, PROC_REF(place_core), ui.user)
		if("pack_core")
			INVOKE_ASYNC(src, PROC_REF(pack_core), ui.user)
		else
			return FALSE
	return TRUE

/mob/living/carbon/alien/adult/banda/queen/verb/hive_evolution()
	set name = "Развитие улья"
	set category = "Alien"
	var/datum/xeno_hive/hive = get_xeno_hive()
	hive.ui_interact(src)

/datum/action/cooldown/alien/banda/hive_pheromones
	name = "Феромоны поддержки"
	desc = "Лечит по 5 ушибов и ожогов союзникам в радиусе пяти клеток."
	button_icon_state = "screech"
	cooldown_time = 30 SECONDS
	plasma_cost = 100

/datum/action/cooldown/alien/banda/hive_pheromones/Activate()
	if(!istype(owner, /mob/living/carbon/alien/adult/banda/queen) || !GLOB.xeno_hive?.purchased["pheromones"])
		return FALSE
	for(var/mob/living/carbon/alien/ally in view(5, owner))
		if(ally.stat == DEAD)
			continue
		ally.adjust_brute_loss(-5)
		ally.adjust_fire_loss(-5)
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_hiss.ogg', 50, TRUE)
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/banda/hive_rally
	name = "Точка сбора"
	desc = "Укажите видимую клетку в пределах семи клеток, чтобы сообщить рою место сбора."
	button_icon_state = "evolution"
	cooldown_time = 15 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/alien/banda/hive_rally/Activate(atom/target)
	var/turf/location = get_turf(target)
	if(!GLOB.xeno_hive?.purchased["coordination"] || !location || !(location in view(7, owner)))
		return FALSE
	var/mob/living/carbon/alien/adult/banda/xeno = owner
	xeno.alien_talk("Место сбора: [get_area(location)], [location.x], [location.y].")
	StartCooldown()
	return TRUE
