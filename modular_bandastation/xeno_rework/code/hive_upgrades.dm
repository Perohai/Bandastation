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
	/// Repeatable purchases use INFINITY.
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
	desc = "Плеватель может эволюционировать в Бойлера. Один одновременный слот."
	branch = "Качество"
	cost = 350
	icon = "flask"
	tree_x = 3
	tree_y = 2
	requires = list("tier3")

/datum/xeno_hive_upgrade/ravager
	id = "ravager"
	name = "Разоритель · Ravager T4"
	desc = "Открывает Runner выбор Ravager T4 вместо обычного Hunter T2. Один одновременный слот; покупка не превращает ксеноморфа автоматически."
	branch = "Качество"
	cost = 300
	icon = "khanda"
	tree_x = 3
	tree_y = 3
	requires = list("tier3")

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

/datum/xeno_hive_upgrade/construction
	id = "construction"
	name = "Живая смола"
	desc = "Строительство смолы вдвое быстрее; сворачивание ядра за 3 секунды вместо 10."
	branch = "Функциональность"
	cost = 100
	icon = "trowel"
	tree_x = 1
	tree_y = 0

/datum/xeno_hive_upgrade/brood_vigor
	id = "brood_vigor"
	name = "Крепкий выводок"
	desc = "+15 здоровья и +2 урона когтей живому и будущему выводку. Эволюции во взрослых нет."
	branch = "Функциональность"
	cost = 100
	icon = "heart-pulse"
	tree_x = 1
	tree_y = 1
	requires = list("construction")

/datum/xeno_hive_upgrade/brood_mantis
	id = "brood_mantis"
	name = "Выводок богомолов"
	desc = "Открывает слабого богомола: 25 здоровья, 4 урона когтей. Размах открывается отдельно."
	cost = 80
	icon = "scissors"
	tree_x = 1
	tree_y = 2
	requires = list("brood_vigor")

/datum/xeno_hive_upgrade/brood_scorpion
	id = "brood_scorpion"
	name = "Выводок скорпионов"
	desc = "Открывает слабого скорпиона: 25 здоровья, 2 урона когтей. Кислотный плевок открывается отдельно."
	cost = 80
	icon = "locust"
	tree_x = 2
	tree_y = 2
	requires = list("brood_vigor")

/datum/xeno_hive_upgrade/beetle_charge
	id = "beetle_charge"
	name = "Жук: таран"
	desc = "Жуки получают рывок на 4 клетки: 15 урона и опрокидывание на секунду. Подготовка 0,5 секунды; 80 плазмы, перезарядка 30 секунд. Запас плазмы 320, восстановление 10."
	cost = 120
	icon = "angles-right"
	tree_x = 0
	tree_y = 3
	requires = list("brood_vigor")

/datum/xeno_hive_upgrade/mantis_ravage
	id = "mantis_ravage"
	name = "Богомол: размах"
	desc = "Богомолы получают удар по трём клеткам перед собой: 12 урона. Подготовка 0,5 секунды; 200 плазмы, перезарядка 30 секунд. Запас плазмы 600, восстановление 20."
	cost = 120
	icon = "fan"
	tree_x = 1
	tree_y = 3
	requires = list("brood_mantis")

/datum/xeno_hive_upgrade/scorpion_spit
	id = "scorpion_spit"
	name = "Скорпион: кислота"
	desc = "Скорпионы получают кислотный плевок на 7 клеток: 10 ожогов. 75 плазмы, перезарядка 1,8 секунды. Усиливает базовый плевок с 5 до 10 урона. Запас плазмы 500, восстановление 10."
	cost = 120
	icon = "droplet"
	tree_x = 2
	tree_y = 3
	requires = list("brood_scorpion")

/datum/xeno_hive_upgrade/brood_baneling
	id = "brood_baneling"
	name = "Банелинг"
	desc = "Финальный выводок: подвижный отсчёт 5 секунд с громкими предупреждениями, затем самоподрыв на 100/75/50/25 ожогов до 3 клеток с учётом кислотной брони. Один вход каждые 120 секунд для всего улья; требуется место в яйце."
	cost = 350
	icon = "burst"
	tree_x = 1
	tree_y = 4
	requires = list("beetle_charge", "mantis_ravage", "scorpion_spit")

/datum/xeno_hive_upgrade/capture
	id = "capture"
	name = "Быстрое пленение"
	desc = "Подготовка кокона за 3 секунды вместо 6."
	branch = "Функциональность"
	cost = 100
	icon = "link"
	tree_x = 0
	tree_y = 0

/datum/xeno_hive_upgrade/processing
	id = "processing"
	name = "Переработка добычи"
	desc = "Обработка тела за 120 секунд вместо 150. Общая награда тела не увеличивается."
	branch = "Функциональность"
	cost = 150
	icon = "recycle"
	tree_x = 0
	tree_y = 1
	requires = list("capture")

/datum/xeno_hive_upgrade/coordination
	id = "coordination"
	name = "Связь охотников"
	desc = "Все взрослые получают личный фиолетовый указатель вокруг персонажа. Назначать точку могут только Queen, T4 и Hivemind."
	branch = "Функциональность"
	cost = 80
	icon = "location-crosshairs"
	tree_x = 3
	tree_y = 0

/datum/xeno_hive_upgrade/pheromones
	id = "pheromones"
	name = "Восстановительные феромоны"
	desc = "Queen, Praetorian и Carrier получают восстановительные феромоны: по 5 ушибов и ожогов союзникам в view(5). 100 плазмы; перезарядка 30 секунд."
	branch = "Функциональность"
	cost = 180
	icon = "wind"
	tree_x = 3
	tree_y = 1
	requires = list("coordination")

/datum/xeno_hive_upgrade/carrier
	id = "carrier"
	name = "Носитель · Carrier T2"
	desc = "Трутень получает эволюцию в Носителя T2: хранилище четырёх хаггеров, выращивание и бросок хаггеров, кладка яиц. Феромоны требуют отдельной покупки. Смолу и траву не строит; отдельного лимита касты нет."
	cost = 200
	icon = "bugs"
	tree_x = 2
	tree_y = 0

/datum/xeno_hive_upgrade/generator
	id = "generator"
	name = "Генератор биомассы"
	desc = "Построить перед королевой непроходимый генератор 2×2. 600 биомассы; доход 1 в секунду, окупаемость 10 минут. 350 прочности, слышимый шум. Количество не ограничено; четыре клетки должны быть свободны."
	branch = "Количество"
	cost = 600
	icon = "industry"
	tree_x = 1
	tree_y = 3
	max_level = INFINITY

/datum/xeno_hive_upgrade/hivemind
	id = "hivemind"
	name = "Разум улья · Hivemind"
	desc = "Вырастить перед королевой на траве привязку для призрака. Hivemind T0 перемещается духом по траве, воплощается для удалённого строительства, лечения и передачи плазмы. Запас плазмы 400. Одна привязка одновременно; её уничтожение убивает Hivemind. Каждый призыв стоит 300."
	cost = 300
	icon = "brain"
	tree_x = 2
	tree_y = 1
	requires = list("coordination")
	max_level = INFINITY

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
	member.updatehealth()
	// Dead members also inherit their caste's button for a later revival.
	if(purchased["coordination"] && (istype(member, /mob/living/carbon/alien/adult/banda/queen) || member.evolution_tier == 4) && !(locate(/datum/action/cooldown/alien/banda/hive_rally) in member.actions))
		member.grant_actions_by_list(list(/datum/action/cooldown/alien/banda/hive_rally))
	if(purchased["coordination"] && !(locate(/datum/action/cooldown/alien/banda/hive_rally_track) in member.actions))
		member.grant_actions_by_list(list(/datum/action/cooldown/alien/banda/hive_rally_track))
	if(can_use_pheromones(member) && !(locate(/datum/action/cooldown/alien/banda/hive_pheromones) in member.actions))
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
	return istype(queen) && !QDELETED(queen) && queen == living_queen() && !IS_UNCONSCIOUS(queen) && !queen.incapacitated && !queen.resting

/datum/xeno_hive/proc/can_buy(mob/living/carbon/alien/adult/banda/queen/queen, id)
	if(!can_manage(queen) || !istext(id))
		return FALSE
	var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
	if(!upgrade || purchased[id] >= upgrade.max_level || biomass < upgrade.price(purchased[id] || 0))
		return FALSE
	for(var/requirement in upgrade.requires)
		if(!purchased[requirement])
			return FALSE
	if(id == "larva" && (QDELETED(core) || !core.is_installed() || !core.egg_spawn_turf()))
		return FALSE
	if(id == "generator" && !can_place_generator(queen, hive_structure_location(queen)))
		return FALSE
	if(id == "hivemind" && !can_place_hivemind(queen, hivemind_location(queen)))
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
	var/turf/generator_origin = id == "generator" ? hive_structure_location(queen) : null
	var/turf/hivemind_origin = id == "hivemind" ? hivemind_location(queen) : null
	if(!channel(queen, purchase_time) || !can_buy(queen, id))
		return FALSE
	if(id == "larva" && core != original_core)
		return FALSE
	if(id == "generator" && !can_place_generator(queen, generator_origin))
		return FALSE
	if(id == "hivemind" && !can_place_hivemind(queen, hivemind_origin))
		return FALSE
	var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
	biomass -= upgrade.price(purchased[id] || 0)
	purchased[id] = (purchased[id] || 0) + 1
	if(id == "generator")
		new /obj/structure/xeno_biomass_generator(generator_origin)
	if(id == "hivemind")
		var/obj/structure/xeno_hivemind_anchor/anchor = new(hivemind_origin)
		if(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER)
			INVOKE_ASYNC(anchor.spawner, TYPE_PROC_REF(/obj/effect/mob_spawn/ghost_role/xeno_hivemind, notify_available))
	if(id == "larva")
		var/obj/structure/xeno_hive_egg/egg = new /obj/structure/xeno_hive_egg/larva(core.egg_spawn_turf())
		core.eject_egg(egg)
		flick("core_birth", core)
		if(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER)
			INVOKE_ASYNC(egg.spawner, TYPE_PROC_REF(/obj/effect/mob_spawn/ghost_role/xeno_hive, notify_available), "Улей вырастил яйцо полноценной личинки.", "Личинка улья")
	for(var/mob/living/carbon/alien/adult/banda/member as anything in members)
		apply_upgrades(member)
	for(var/mob/living/carbon/alien/brood/brood in GLOB.mob_living_list)
		brood.apply_hive_upgrade()
	var/mob/living/carbon/alien/hivemind/hivemind = hivemind_anchor?.hivemind_ref?.resolve()
	hivemind?.apply_hive_upgrades()
	log_game("[key_name(queen)] purchased hive upgrade [id] for hive level [purchased[id]]. Remaining biomass: [biomass].")
	return TRUE

/datum/xeno_hive/proc/can_place_core(mob/living/carbon/alien/adult/banda/queen/queen)
	var/turf/origin = hive_structure_location(queen)
	return can_manage(queen) && !core && origin && (locate(/obj/structure/alien/weeds) in origin) && clear_structure_footprint(origin, floors_only = FALSE)

/datum/xeno_hive/proc/place_core(mob/living/carbon/alien/adult/banda/queen/queen)
	var/turf/origin = hive_structure_location(queen)
	if(!can_place_core(queen) || !channel(queen, 5 SECONDS) || !can_place_core(queen))
		return FALSE
	if(origin != hive_structure_location(queen))
		return FALSE
	new /obj/structure/xeno_hive_core(origin)
	return TRUE

/datum/xeno_hive/proc/pack_core(mob/living/carbon/alien/adult/banda/queen/queen)
	var/obj/structure/xeno_hive_core/original_core = core
	if(!can_manage(queen) || QDELETED(original_core) || !original_core.next_to_core(queen) || !original_core.CheckReachableAdjacency(queen, 1))
		return FALSE
	if(!channel(queen, purchased["construction"] ? 3 SECONDS : 10 SECONDS))
		return FALSE
	if(!can_manage(queen) || QDELETED(original_core) || core != original_core || !original_core.next_to_core(queen) || !original_core.CheckReachableAdjacency(queen, 1))
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
		"biomass" = round(biomass, 0.1),
		"territoryTiles" = length(claimed_territory),
		"territoryPending" = territory_pending_tiles,
		"territoryBatch" = territory_tiles_per_biomass,
		"territoryEarned" = territory_biomass_earned,
		"crew" = core?.cached_crew || 0,
		"broodRate" = core?.is_installed() && living_queen() ? brood_rate(core.cached_crew) : 0,
		"canDebug" = can_debug(user),
		"debugUsed" = debug_used,
		"broodPoints" = round(brood_points, 0.1),
		"broodCost" = brood_slot_cost,
		"broodPlaces" = core?.available_brood() || 0,
		"broodBlocked" = core && !core.egg_spawn_turf(),
		"core" = !!core,
		"busy" = purchase_busy,
		"canPlace" = !purchase_busy && can_place_core(user),
		"canPack" = !purchase_busy && core && core.next_to_core(user) && core.CheckReachableAdjacency(user, 1),
		"nodes" = nodes,
	)

/datum/xeno_hive/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !can_manage(ui.user))
		return
	switch(action)
		if("debug")
			return debug_resources(ui.user)
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

/** Admin-only resource grant. Never trust the checkbox or a client-supplied resource amount. */
/datum/xeno_hive/proc/can_debug(mob/user)
	return user?.client?.holder && check_rights_for(user.client, R_DEBUG)

/datum/xeno_hive/proc/debug_resources(mob/user)
	if(debug_used || !can_manage(user) || !can_debug(user))
		return FALSE
	debug_used = TRUE
	biomass = 99999
	log_admin("[key_name(user)] enabled hive economy debug: biomass set to 99999.")
	message_admins("[key_name_admin(user)] включил отладку экономики улья: 99999 биомассы.")
	return TRUE
