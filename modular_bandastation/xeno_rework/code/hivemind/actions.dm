/datum/action/cooldown/alien/hivemind
	/// Spirit actions are travel and observation; physical effects require manifestation.
	var/requires_body = FALSE

/datum/action/cooldown/alien/hivemind/IsAvailable(feedback = FALSE)
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	return istype(hivemind) && hivemind.operational() && !hivemind.channeling && (!requires_body || hivemind.manifested) && ..()

/datum/action/cooldown/alien/hivemind/form
	name = "Воплотиться / вернуться в дух"
	desc = "Позволяет за секунду обрести физическую оболочку или вернуться в форму духа. Для воплощения необходимо полное здоровье. Дух может двигаться только по траве; физическая оболочка уязвима."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/hivemind.dmi'
	button_icon_state = "manifest"
	/// Native do_after keeps the transition cancellable and visibly timed.
	var/form_time = 1 SECONDS

/datum/action/cooldown/alien/hivemind/form/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	return hivemind.manifested || (hivemind.health >= hivemind.maxHealth && COOLDOWN_FINISHED(hivemind, reformation_cooldown))

/datum/action/cooldown/alien/hivemind/form/Activate()
	if(!IsAvailable())
		return FALSE
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	if(!hivemind.manifested && (hivemind.health < hivemind.maxHealth || !COOLDOWN_FINISHED(hivemind, reformation_cooldown) || !hivemind.can_travel(get_turf(hivemind))))
		return FALSE
	var/was_physical = hivemind.manifested
	hivemind.channeling = TRUE
	flick(was_physical ? "Hivemind__materialisation_reverse" : "Hivemind__materialisation", hivemind)
	var/ready = do_after(hivemind, form_time, target = hivemind)
	if(QDELETED(src) || QDELETED(hivemind))
		return FALSE
	hivemind.channeling = FALSE
	if(!ready || owner != hivemind || !IsAvailable() || hivemind.manifested != was_physical || !hivemind.can_travel(get_turf(hivemind)))
		return FALSE
	if(!was_physical && (hivemind.health < hivemind.maxHealth || !COOLDOWN_FINISHED(hivemind, reformation_cooldown)))
		return FALSE
	hivemind.set_manifestation(!was_physical)
	return TRUE

/datum/action/cooldown/alien/hivemind/return_core
	name = "Вернуться к узлу"
	desc = "Дух мгновенно возвращается к своему узлу. В физической оболочке способность недоступна."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/hivemind.dmi'
	button_icon_state = "lay_hivemind"
	cooldown_time = 5 SECONDS

/datum/action/cooldown/alien/hivemind/return_core/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	return !hivemind.manifested

/datum/action/cooldown/alien/hivemind/return_core/Activate()
	if(!IsAvailable())
		return FALSE
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	if(!hivemind.return_to_core())
		return FALSE
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/hivemind/jump
	name = "К союзнику"
	desc = "Дух перемещается к выбранному живому союзнику, находящемуся на траве того же уровня."
	button_icon_state = "alien_transfer"
	cooldown_time = 10 SECONDS

/datum/action/cooldown/alien/hivemind/jump/Activate()
	if(!IsAvailable())
		return FALSE
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	if(hivemind.manifested)
		return FALSE
	var/list/allies = list()
	for(var/mob/living/carbon/alien/ally in GLOB.alive_mob_list)
		if(ally != hivemind && isturf(ally.loc) && hivemind.can_travel(get_turf(ally)))
			allies += ally
	var/mob/living/carbon/alien/chosen = tgui_input_list(hivemind, "К кому переместиться?", name, allies, timeout = 10 SECONDS)
	if(QDELETED(src) || QDELETED(hivemind) || owner != hivemind || !IsAvailable() || hivemind.manifested || QDELETED(chosen) || !(chosen in allies) || chosen.stat == DEAD || !isturf(chosen.loc) || !hivemind.can_travel(get_turf(chosen)))
		return FALSE
	hivemind.forceMove(get_turf(chosen))
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/hivemind/teleport
	name = "Скольжение по траве"
	desc = "Дух перемещается к видимому участку травы на расстоянии до семи клеток."
	button_icon_state = "alien_plant"
	click_to_activate = TRUE
	cooldown_time = 3 SECONDS

/datum/action/cooldown/alien/hivemind/teleport/Activate(atom/target)
	if(!IsAvailable())
		return FALSE
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	var/turf/destination = get_turf(target)
	if(hivemind.manifested || !hivemind.can_travel(destination) || !(destination in view(7, owner)))
		return FALSE
	hivemind.forceMove(destination)
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/hivemind/plant
	name = "Посадить траву на расстоянии"
	desc = "В физической оболочке выращивает узел травы на видимой свободной клетке в пределах четырёх клеток. Стоимость — 75 плазмы."
	button_icon_state = "alien_plant"
	requires_body = TRUE
	plasma_cost = 75
	click_to_activate = TRUE
	cooldown_time = 5 SECONDS

/datum/action/cooldown/alien/hivemind/plant/Activate(atom/target)
	var/turf/location = get_turf(target)
	if(!IsAvailable() || !isopenturf(location) || isspaceturf(location) || !(location in view(4, owner)) || (locate(/obj/structure/alien/weeds/node) in location))
		return FALSE
	new /obj/structure/alien/weeds/node/banda(location)
	StartCooldown()
	return TRUE

/** One lock covers healing, transfer and form changes; payment follows final validation. */
/datum/action/cooldown/alien/hivemind/support
	requires_body = TRUE
	click_to_activate = TRUE
	/// Delay before the final actor, target and plasma checks.
	var/channel_time = 1 SECONDS
	/// The target may move during the channel, but must stay visible within this radius.
	var/support_range = 3

/datum/action/cooldown/alien/hivemind/support/proc/valid_support(mob/living/carbon/alien/hivemind/hivemind, mob/living/carbon/alien/ally)
	return !QDELETED(src) && owner == hivemind && !QDELETED(hivemind) && hivemind.operational() && hivemind.manifested && !QDELETED(ally) && istype(ally) && ally != hivemind && ally.stat != DEAD && isturf(ally.loc) && (ally in view(support_range, hivemind)) && hivemind.getPlasma() >= plasma_cost

/datum/action/cooldown/alien/hivemind/support/proc/channel_support(mob/living/carbon/alien/ally)
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	if(!IsAvailable() || !valid_support(hivemind, ally))
		return FALSE
	hivemind.channeling = TRUE
	var/ready = do_after(hivemind, channel_time, target = hivemind, extra_checks = CALLBACK(src, PROC_REF(valid_support), hivemind, ally))
	if(!QDELETED(hivemind))
		hivemind.channeling = FALSE
	return ready && valid_support(hivemind, ally) && IsAvailable()

/datum/action/cooldown/alien/hivemind/heal
	parent_type = /datum/action/cooldown/alien/hivemind/support
	name = "Смоляной бальзам"
	desc = "Восстанавливает союзнику в пределах трёх клеток до 30 единиц урона от ушибов, затем — от ожогов. Подготовка занимает секунду, стоимость — 150 плазмы."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "grow_fruit"
	plasma_cost = 150
	cooldown_time = 5 SECONDS

/datum/action/cooldown/alien/hivemind/heal/Activate(atom/target)
	var/mob/living/carbon/alien/ally = target
	if(!istype(ally) || !channel_support(ally))
		return FALSE
	var/heal_brute = min(30, ally.get_brute_loss())
	ally.heal_overall_damage(heal_brute, 30 - heal_brute)
	new /obj/effect/temp_visual/hivemind_support(get_turf(owner), ally, COLOR_PALE_GREEN_GRAY)
	playsound(ally, 'modular_bandastation/xeno_rework/sound/alien_resin_move2.ogg', 45, TRUE)
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/hivemind/plasma
	parent_type = /datum/action/cooldown/alien/hivemind/support
	name = "Передать плазму"
	desc = "За две секунды передаёт союзнику в пределах двух клеток до 120 плазмы."
	button_icon_state = "alien_transfer"
	channel_time = 2 SECONDS
	support_range = 2
	cooldown_time = 2 SECONDS

/datum/action/cooldown/alien/hivemind/plasma/Activate(atom/target)
	var/mob/living/carbon/alien/ally = target
	if(!istype(ally) || !channel_support(ally))
		return FALSE
	var/obj/item/organ/alien/plasmavessel/vessel = ally.get_organ_slot(ORGAN_SLOT_XENO_PLASMAVESSEL)
	var/mob/living/carbon/alien/hivemind/hivemind = owner
	if(!vessel)
		return FALSE
	var/amount = min(120, hivemind.getPlasma(), vessel.max_plasma - vessel.stored_plasma)
	if(amount <= 0)
		return FALSE
	hivemind.adjustPlasma(-amount)
	ally.adjustPlasma(amount)
	new /obj/effect/temp_visual/hivemind_support(get_turf(owner), ally, COLOR_PURPLE)
	StartCooldown()
	return TRUE

/// Cosmetic pulse. Its destination is sampled on a successful transfer.
/obj/effect/temp_visual/hivemind_support
	name = "hive support pulse"
	icon_state = "heal"
	layer = ABOVE_MOB_LAYER
	duration = 0.4 SECONDS

/obj/effect/temp_visual/hivemind_support/Initialize(mapload, atom/recipient, pulse_color)
	. = ..()
	if(QDELETED(recipient))
		return INITIALIZE_HINT_QDEL
	color = pulse_color
	animate(src, pixel_x = (recipient.x - x) * ICON_SIZE_X, pixel_y = (recipient.y - y) * ICON_SIZE_Y, time = 0.3 SECONDS)
	animate(alpha = 0, time = 0.1 SECONDS)

/datum/action/cooldown/alien/hivemind/pheromones
	name = "Восстановительные феромоны"
	desc = "Общая адаптация улья: восстанавливает союзникам в пределах пяти клеток по 5 единиц урона от ушибов и ожогов."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "pheromones"
	requires_body = TRUE
	plasma_cost = 100
	cooldown_time = 30 SECONDS

/datum/action/cooldown/alien/hivemind/pheromones/IsAvailable(feedback = FALSE)
	return GLOB.xeno_hive?.can_use_pheromones(owner) && ..()

/datum/action/cooldown/alien/hivemind/pheromones/Activate()
	if(!IsAvailable())
		return FALSE
	GLOB.xeno_hive.release_support_pheromones(owner)
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/hivemind/rally
	name = "Созвать улей"
	desc = "Назначить свою точку сбора на видимой клетке. После покупки связи охотников её можно выбрать в составе улья."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/hive_abilities.dmi'
	button_icon_state = "rally"
	click_to_activate = TRUE
	cooldown_time = 15 SECONDS

/datum/action/cooldown/alien/hivemind/rally/Activate(atom/target)
	var/turf/location = get_turf(target)
	if(!IsAvailable() || !location || !(location in view(7, owner)))
		return FALSE
	var/datum/xeno_hive/hive = get_xeno_hive()
	if(!hive.set_rally_point(owner, location))
		return FALSE
	StartCooldown()
	return TRUE
