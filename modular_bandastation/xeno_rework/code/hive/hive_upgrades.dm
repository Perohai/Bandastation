/** One definition drives purchases, effects, icons and the visible upgrade tree. */
/datum/xeno_hive_upgrade
	/// Stable server purchase key.
	var/id
	/// Readable title and exact effect.
	var/name
	/// Full description shown beside the selected node.
	var/desc
	/// Tab in the evolution UI. Prerequisites may belong to any tab.
	var/category
	/// FontAwesome symbol from the existing TGUI icon set.
	var/icon = "dna"
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
	category = "Эволюция"
	name = "Адаптация T1"
	desc = "Все боевые касты T1 получают +15 здоровья и +2 к урону когтей. Королева и выводок не получают усиления."
	cost = 150
	icon = "dna"
	target_tier = 1
	health_bonus = 15
	claw_bonus = 2

/datum/xeno_hive_upgrade/claws
	id = "claws"
	category = "Эволюция"
	name = "Адаптация T2"
	desc = "Все касты T2 получают +25 здоровья и +3 к урону когтей."
	cost = 200
	icon = "shield-halved"
	requires = list("carapace")
	target_tier = 2
	health_bonus = 25
	claw_bonus = 3

/datum/xeno_hive_upgrade/tier3
	id = "tier3"
	category = "Эволюция"
	name = "Адаптация T3"
	desc = "Все касты T3 получают +35 здоровья и +4 к урону когтей."
	cost = 250
	icon = "hand-fist"
	requires = list("claws")
	target_tier = 3
	health_bonus = 35
	claw_bonus = 4

/datum/xeno_hive_upgrade/tier4
	id = "tier4"
	category = "Эволюция"
	name = "Адаптация T4"
	desc = "Все особые касты T4 получают +40 здоровья и +5 к урону когтей."
	cost = 300
	icon = "crown"
	requires = list("tier3")
	target_tier = 4
	health_bonus = 40
	claw_bonus = 5

/datum/xeno_hive_upgrade/crusher
	id = "crusher"
	category = "Эволюция"
	name = "Крушитель"
	desc = "Открывает Воину эволюцию в Крушителя. В улье может быть один Крушитель."
	cost = 300
	icon = "meteor"
	requires = list("tier3")

/datum/xeno_hive_upgrade/hunter
	id = "hunter"
	category = "Эволюция"
	name = "Охотник (T2)"
	desc = "Открывает Бегуну эволюцию в Охотника. Базовый лимит — один Охотник."
	cost = 200
	icon = "eye"
	requires = list("claws")

/datum/xeno_hive_upgrade/boiler
	id = "boiler"
	category = "Эволюция"
	name = "Кислотная артиллерия"
	desc = "Позволяет плевуну эволюционировать в Бойлера. Одновременно может существовать только один."
	cost = 350
	icon = "flask"
	requires = list("tier3")

/datum/xeno_hive_upgrade/ravager
	id = "ravager"
	category = "Эволюция"
	name = "Разоритель (T4)"
	desc = "Открывает Бегуну эволюцию в Разорителя. В улье может быть один Разоритель."
	cost = 300
	icon = "khanda"
	requires = list("tier3")

/datum/xeno_hive_upgrade/larva
	id = "larva"
	category = "Популяция"
	name = "Вырастить личинку"
	desc = "Создаёт у ядра уязвимое яйцо с полноценной личинкой. Стоимость — 400 биомассы, возврата нет. Адаптацию можно покупать повторно."
	cost = 400
	icon = "egg"
	max_level = INFINITY

/datum/xeno_hive_upgrade/warrior_slot
	id = "warrior_slot"
	category = "Популяция"
	name = "Резерв воинов"
	desc = "Добавляет одно место для воина. Можно открыть до трёх дополнительных мест; каждое следующее обходится дороже."
	cost = 180
	icon = "people-group"
	max_level = 3
	scaling_cost = TRUE
	slot_type = /mob/living/carbon/alien/adult/banda/warrior

/datum/xeno_hive_upgrade/praetorian_slot
	id = "praetorian_slot"
	category = "Популяция"
	name = "Резерв преторианцев"
	desc = "Добавляет одно место для преторианца. Можно открыть до трёх дополнительных мест; каждое следующее обходится дороже."
	cost = 180
	icon = "chess-rook"
	max_level = 3
	scaling_cost = TRUE
	slot_type = /mob/living/carbon/alien/adult/banda/praetorian

/datum/xeno_hive_upgrade/construction
	id = "construction"
	category = "Биоструктуры"
	name = "Живая смола"
	desc = "Сокращает время строительства смолы дроном и королевой на 20%. Сворачивание ядра занимает 10 секунд вместо 15."
	cost = 100
	icon = "trowel"

/datum/xeno_hive_upgrade/brood_vigor
	id = "brood_vigor"
	category = "Выводок"
	name = "Крепкий выводок"
	desc = "Младшее потомство получает +15 здоровья и +2 к урону когтей. Усиление действует на существующих и будущих особей. Эволюция во взрослые касты недоступна."
	cost = 100
	icon = "heart-pulse"
	requires = list("construction")

/datum/xeno_hive_upgrade/brood_mantis
	id = "brood_mantis"
	category = "Выводок"
	name = "Выводок богомолов"
	desc = "Открывает младшего Богомола с 25 здоровья и 4 урона когтей. Взмах серпами приобретается отдельно."
	cost = 80
	icon = "scissors"
	requires = list("brood_vigor")

/datum/xeno_hive_upgrade/brood_scorpion
	id = "brood_scorpion"
	category = "Выводок"
	name = "Выводок скорпионов"
	desc = "Открывает младшего Скорпиона с 25 здоровья и 2 урона когтей. Плевок кислотой приобретается отдельно."
	cost = 80
	icon = "locust"
	requires = list("brood_vigor")

/datum/xeno_hive_upgrade/beetle_charge
	id = "beetle_charge"
	category = "Выводок"
	name = "Таран жука"
	desc = "Жуки получают таранный рывок на четыре клетки: 15 урона и опрокидывание на секунду. Подготовка — 0,5 секунды, стоимость — 80 плазмы, перезарядка — 30 секунд. Максимум плазмы — 320, восстановление — 10."
	cost = 120
	icon = "angles-right"
	requires = list("brood_vigor")

/datum/xeno_hive_upgrade/mantis_ravage
	id = "mantis_ravage"
	category = "Выводок"
	name = "Взмах серпами богомола"
	desc = "Богомолы получают удар по трём клеткам перед собой: 12 урона. Подготовка — 0,5 секунды, стоимость — 200 плазмы, перезарядка — 30 секунд. Максимум плазмы — 600, восстановление — 20."
	cost = 120
	icon = "fan"
	requires = list("brood_mantis")

/datum/xeno_hive_upgrade/scorpion_spit
	id = "scorpion_spit"
	category = "Выводок"
	name = "Плевок скорпиона"
	desc = "Скорпионы получают плевок кислотой на расстояние до 7 клеток: 10 ожогового урона. Стоимость — 75 плазмы, перезарядка — 1,8 секунды. Улучшает базовый плевок с 5 до 10 урона. Максимум плазмы — 500, восстановление — 10."
	cost = 120
	icon = "droplet"
	requires = list("brood_scorpion")

/datum/xeno_hive_upgrade/brood_baneling
	id = "brood_baneling"
	category = "Выводок"
	name = "Банелинг"
	desc = "Открывает банелинга — живую кислотную бомбу. Перед самоподрывом банелинг замирает на 1,5 секунды, мигает и рычит. Взрыв наносит 100/75/50/25 ожогового урона в зависимости от расстояния (до трёх клеток) и кислотной защиты. Одно появление каждые 120 секунд на весь улей; требуется свободное место в яйце."
	cost = 350
	icon = "burst"
	requires = list("beetle_charge", "mantis_ravage", "scorpion_spit")

/datum/xeno_hive_upgrade/capture
	id = "capture"
	category = "Биоструктуры"
	name = "Быстрое пленение"
	desc = "Кокон создаётся за 3 секунды вместо 6."
	cost = 100
	icon = "link"

/datum/xeno_hive_upgrade/processing
	id = "processing"
	category = "Биоструктуры"
	name = "Переработка добычи"
	desc = "Тело перерабатывается за 120 секунд вместо 150. Общая награда в биомассе не меняется."
	cost = 150
	icon = "recycle"
	requires = list("capture")

/datum/xeno_hive_upgrade/coordination
	id = "coordination"
	category = "Эволюция"
	name = "Связь охотников"
	desc = "В составе улья можно выбрать ксеноморфа или точку сбора для личного указателя. Королева, ксеноморфы T4 и Разум улья могут поставить по одной точке сбора."
	cost = 80
	icon = "location-crosshairs"

/datum/xeno_hive_upgrade/pheromones
	id = "pheromones"
	category = "Эволюция"
	name = "Восстановительные феромоны"
	desc = "Королева, Преторианец и Носитель получают восстановительные феромоны: союзники в радиусе 5 клеток исцеляют по 5 единиц ушибов и ожогов. Стоимость — 100 плазмы, перезарядка — 30 секунд."
	cost = 180
	icon = "wind"
	requires = list("coordination")

/datum/xeno_hive_upgrade/carrier
	id = "carrier"
	category = "Эволюция"
	name = "Носитель (T2)"
	desc = "Открывает дрону эволюцию в носителя T2. Носитель выращивает, переносит и метает до четырёх лицехватов, а также откладывает яйца. Феромоны приобретаются отдельно. Носитель не возводит смоляные постройки и не выращивает траву. Базовый лимит — один Носитель."
	cost = 200
	icon = "bugs"
	requires = list("claws")

/datum/xeno_hive_upgrade/hunter_slot
	id = "hunter_slot"
	category = "Популяция"
	name = "Резерв охотников"
	desc = "Добавляет одно место для Охотника. Можно купить до трёх дополнительных мест, каждое следующее стоит дороже."
	cost = 180
	icon = "user-plus"
	max_level = 3
	scaling_cost = TRUE
	slot_type = /mob/living/carbon/alien/adult/banda/final_caste/hunter
	requires = list("hunter")

/datum/xeno_hive_upgrade/carrier_slot
	id = "carrier_slot"
	category = "Популяция"
	name = "Резерв носителей"
	desc = "Добавляет одно место для Носителя. Можно открыть до трёх дополнительных мест; каждое следующее обходится дороже."
	cost = 180
	icon = "users"
	max_level = 3
	scaling_cost = TRUE
	slot_type = /mob/living/carbon/alien/adult/banda/carrier
	requires = list("carrier")

/datum/xeno_hive_upgrade/generator
	id = "generator"
	category = "Биоструктуры"
	name = "Генератор биомассы"
	desc = "Создаёт перед Королевой непроходимый генератор биомассы размером 2×2 клетки. Стоимость — 600 биомассы, производство — 1 в секунду, окупаемость — 10 минут. Прочность — 350. Генератор шумит, количество построек не ограничено. Для строительства нужны четыре свободные клетки."
	cost = 600
	icon = "industry"
	max_level = INFINITY

/datum/xeno_hive_upgrade/hivemind
	id = "hivemind"
	category = "Биоструктуры"
	name = "Разум улья"
	desc = "Позволяет вырастить на траве перед королевой узел, к которому сможет привязаться призрак. Разум улья T0 перемещается по траве в форме духа и воплощается, чтобы строить, лечить и передавать плазму на расстоянии. Запас плазмы — 400. В улье может быть лишь один такой узел; его разрушение убивает Разум улья. Стоимость каждого призыва — 300."
	cost = 300
	icon = "brain"
	requires = list("coordination")
	max_level = INFINITY

/datum/xeno_hive_upgrade/tunnels
	id = "tunnels"
	category = "Биоструктуры"
	name = "Смоляные тоннели"
	desc = "Дрон может вырыть пару входов на траве на одном уровне станции. Пара стоит 200 плазмы, КД 120 секунд после соединения. Проход занимает 2 секунды."
	cost = 200
	icon = "arrows-left-right"
	requires = list("construction")

/datum/xeno_hive_upgrade/acid_mines
	id = "acid_mines"
	category = "Биоструктуры"
	name = "Кислотные мины"
	desc = "Дрон и королева могут строить кислотные мины: 150 плазмы, 6 секунд."
	icon = "bomb"
	cost = 200
	requires = list("construction")

/datum/xeno_hive_upgrade/reinforced_resin
	id = "reinforced_resin"
	category = "Биоструктуры"
	name = "Укреплённая смола"
	desc = "Открывает укреплённые стены с 300 прочности: 250 плазмы, 15 секунд строительства."
	icon = "dungeon"
	cost = 300
	requires = list("construction")

/datum/xeno_hive_upgrade/acid_turrets
	id = "acid_turrets"
	category = "Биоструктуры"
	name = "Кислотные турели"
	desc = "Открывает турель со 150 прочности: 250 плазмы, 20 секунд. Раз в 2 секунды стреляет по незаражённым людям в радиусе 5 клеток, нанося 10 ожогового урона."
	icon = "crosshairs"
	cost = 450
	requires = list("acid_mines", "reinforced_resin")

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
	if(purchased["tunnels"] && istype(member, /mob/living/carbon/alien/adult/banda/drone) && !(locate(/datum/action/cooldown/alien/banda/dig_tunnel) in member.actions))
		var/datum/action/cooldown/alien/banda/dig_tunnel/dig = new
		dig.Grant(member)
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
		. += span_warning("Хитиновый панцирь выглядит необычайно толстым и прочным.")
	if(hive_claw_bonus)
		. += span_warning("Когти усеяны острыми режущими зазубринами.")

/datum/xeno_hive/proc/can_manage(mob/living/carbon/alien/adult/banda/queen/queen)
	return istype(queen) && !QDELETED(queen) && queen == living_queen() && !IS_UNCONSCIOUS(queen) && !queen.incapacitated && !queen.resting

/datum/xeno_hive/proc/can_buy(mob/living/carbon/alien/adult/banda/queen/queen, id, has_egg_space = null)
	if(!can_manage(queen) || !istext(id))
		return FALSE
	var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
	if(!upgrade || purchased[id] >= upgrade.max_level || biomass < upgrade.price(purchased[id] || 0))
		return FALSE
	for(var/requirement in upgrade.requires)
		if(!purchased[requirement])
			return FALSE
	if(id == "larva" && (QDELETED(core) || !core.is_installed() || !(isnull(has_egg_space) ? core.egg_spawn_turf(check_only = TRUE) : has_egg_space)))
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
			INVOKE_ASYNC(egg.spawner, TYPE_PROC_REF(/obj/effect/mob_spawn/ghost_role/xeno_hive, notify_available), "Улей вырастил яйцо с полноценной личинкой.", "Личинка улья")
	var/static/list/adult_action_upgrades = list("tunnels", "coordination", "pheromones")
	if(upgrade.target_tier || (id in adult_action_upgrades))
		for(var/mob/living/carbon/alien/adult/banda/member as anything in members)
			if(!upgrade.target_tier || member.evolution_tier == upgrade.target_tier)
				apply_upgrades(member)
	var/static/list/brood_upgrades = list("brood_vigor", "beetle_charge", "mantis_ravage", "scorpion_spit", "brood_baneling")
	if(id in brood_upgrades)
		for(var/mob/living/carbon/alien/brood/brood in roster_members)
			brood.apply_hive_upgrade()
	if(id == "pheromones")
		var/mob/living/carbon/alien/hivemind/hivemind = hivemind_anchor?.hivemind_ref?.resolve()
		hivemind?.apply_hive_upgrades()
	log_game("[key_name(queen)] purchased hive upgrade [id] for hive level [purchased[id]]. Remaining biomass: [biomass].")
	return TRUE

/datum/xeno_hive/proc/can_place_core(mob/living/carbon/alien/adult/banda/queen/queen)
	var/turf/origin = hive_structure_location(queen)
	return can_manage(queen) && !core && can_unfold_core(queen) && origin && (locate(/obj/structure/alien/weeds) in origin) && clear_structure_footprint(origin, floors_only = FALSE)

/datum/xeno_hive/proc/place_core(mob/living/carbon/alien/adult/banda/queen/queen)
	var/turf/origin = hive_structure_location(queen)
	var/obj/item/packed_xeno_hive_core/relocating = packed_core
	if(!can_place_core(queen) || !channel(queen, 5 SECONDS) || !can_place_core(queen))
		return FALSE
	if(origin != hive_structure_location(queen) || packed_core != relocating)
		return FALSE
	var/obj/structure/xeno_hive_core/installed = new(origin)
	if(QDELETED(installed) || core != installed)
		return FALSE
	if(relocating)
		installed.update_integrity(relocating.get_integrity())
		qdel(relocating)
	return TRUE

/datum/xeno_hive/proc/pack_core(mob/living/carbon/alien/adult/banda/queen/queen)
	var/obj/structure/xeno_hive_core/original_core = core
	if(!can_manage(queen) || QDELETED(original_core) || !original_core.next_to_core(queen) || !original_core.CheckReachableAdjacency(queen, 1))
		return FALSE
	if(!channel(queen, purchased["construction"] ? 10 SECONDS : 15 SECONDS))
		return FALSE
	if(!can_manage(queen) || QDELETED(original_core) || core != original_core || !original_core.next_to_core(queen) || !original_core.CheckReachableAdjacency(queen, 1))
		return FALSE
	var/obj/item/packed_xeno_hive_core/folded = new(get_turf(queen))
	packed_core = folded
	folded.update_integrity(original_core.get_integrity())
	qdel(original_core)
	queen.put_in_hands(folded)
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

/datum/xeno_hive/ui_static_data(mob/user)
	var/list/nodes = list()
	for(var/id in upgrades)
		var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
		nodes += list(list(
			"id" = id,
			"name" = upgrade.name,
			"description" = upgrade.desc,
			"category" = upgrade.category,
			"icon" = upgrade.icon,
			"maxLevel" = upgrade.max_level == INFINITY ? null : upgrade.max_level,
			"requires" = upgrade.requires,
		))
	return list("nodes" = nodes)

/datum/xeno_hive/ui_data(mob/user)
	var/has_egg_space = !!(!QDELETED(core) && core.egg_spawn_turf(check_only = TRUE))
	var/list/node_state = list()
	for(var/id in upgrades)
		var/datum/xeno_hive_upgrade/upgrade = upgrades[id]
		var/level = purchased[id] || 0
		node_state[id] = list(
			"cost" = upgrade.price(level),
			"level" = level,
			"available" = !purchase_busy && can_buy(user, id, has_egg_space),
		)
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
		"broodBlocked" = core && !has_egg_space,
		"core" = !!core,
		"packedCore" = !QDELETED(packed_core),
		"busy" = purchase_busy,
		"canPlace" = !purchase_busy && can_place_core(user),
		"canPack" = !purchase_busy && core && core.next_to_core(user) && core.CheckReachableAdjacency(user, 1),
		"nodeState" = node_state,
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
