/** T2 support branch from Drone; native eggs and facehuggers retain TG infection rules. */
/mob/living/carbon/alien/adult/banda/carrier
	name = "alien carrier"
	desc = "Носитель роя. Выращивает и переносит до четырёх лицехватов, бросает их в противников и поддерживает собратьев феромонами."
	caste = "carrier"
	inhand_caste = "drone"
	icon = 'modular_bandastation/xeno_rework/icons/tgmc/carrier_adapted.dmi'
	icon_state = "aliencarrier"
	hud_sprite_height = 51
	evolution_tier = 2
	maxHealth = 220
	health = 220
	melee_damage_lower = 12
	melee_damage_upper = 12
	default_organ_types_by_slot = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/alien,
		ORGAN_SLOT_XENO_HIVENODE = /obj/item/organ/alien/hivenode,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/alien,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes/alien,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/alien,
		ORGAN_SLOT_EARS = /obj/item/organ/ears,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/alien_banda,
		ORGAN_SLOT_XENO_PLASMAVESSEL = /obj/item/organ/alien/plasmavessel/carrier,
	)
	/// Actual owned items, not a regenerating abstract ammunition counter.
	var/list/obj/item/clothing/mask/facehugger/stored_huggers = list()
	/// Native TGMC baseline capacity.
	var/hugger_capacity = 4

/mob/living/carbon/alien/adult/banda/carrier/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/banda/carrier_hugger)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/carrier_spawn_hugger)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/carrier_trap)
	GRANT_ACTION(/datum/action/cooldown/alien/make_structure/lay_egg/carrier)

/datum/action/cooldown/alien/make_structure/lay_egg/carrier
	name = "Отложить яйцо"
	desc = "Откладывает яйцо за 3 секунды. Стоимость — 100 плазмы."
	plasma_cost = 100

/mob/living/carbon/alien/adult/banda/carrier/Destroy()
	release_huggers()
	return ..()

/mob/living/carbon/alien/adult/banda/carrier/death(gibbed)
	. = ..()
	if(.)
		release_huggers()

/mob/living/carbon/alien/adult/banda/carrier/proc/store_hugger(obj/item/clothing/mask/facehugger/hugger)
	if(QDELETED(hugger) || length(stored_huggers) >= hugger_capacity || !isturf(hugger.loc) || !Adjacent(hugger) || hugger.facehugger_state == /obj/item/clothing/mask/facehugger/dead::facehugger_state)
		return FALSE
	hugger.forceMove(src)
	stored_huggers += hugger
	RegisterSignals(hugger, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED), PROC_REF(on_hugger_changed))
	update_icons()
	return TRUE

/mob/living/carbon/alien/adult/banda/carrier/proc/on_hugger_changed(obj/item/clothing/mask/facehugger/source)
	SIGNAL_HANDLER
	if(QDELETED(source) || source.loc != src)
		stored_huggers -= source
		UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		update_icons()

/mob/living/carbon/alien/adult/banda/carrier/proc/release_huggers()
	for(var/obj/item/clothing/mask/facehugger/hugger as anything in stored_huggers.Copy())
		UnregisterSignal(hugger, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		hugger.forceMove(drop_location())
	stored_huggers.Cut()
	if(!QDELETED(src))
		update_icons()

/mob/living/carbon/alien/adult/banda/carrier/examine(mob/user)
	. = ..()
	if(isalien(user) || isobserver(user))
		. += span_notice("Лицехватов: [length(stored_huggers)]/[hugger_capacity].")

/obj/item/organ/alien/plasmavessel/carrier
	actions_types = list(/datum/action/cooldown/alien/transfer)
	max_plasma = 250
	stored_plasma = 100
	plasma_rate = 8
	heal_rate = 1

/datum/action/cooldown/alien/banda/carrier_spawn_hugger
	name = "Вырастить лицехвата"
	desc = "Выращивает лицехвата и помещает его во внутреннее хранилище. Стоимость — 120 плазмы, перезарядка — 25 секунд. Одновременно можно переносить до четырёх лицехватов."
	button_icon = 'modular_bandastation/xeno_rework/icons/support_actions.dmi'
	button_icon_state = "grow_hugger"
	plasma_cost = 120
	cooldown_time = 25 SECONDS

/datum/action/cooldown/alien/banda/carrier_spawn_hugger/Activate()
	var/mob/living/carbon/alien/adult/banda/carrier/carrier = owner
	if(!istype(carrier) || !isturf(carrier.loc) || length(carrier.stored_huggers) >= carrier.hugger_capacity)
		return FALSE
	var/obj/item/clothing/mask/facehugger/hugger = new(carrier.loc)
	if(!carrier.store_hugger(hugger))
		qdel(hugger)
		return FALSE
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/banda/carrier_hugger
	name = "Подобрать / бросить лицехвата"
	desc = "Нажмите на лежащего рядом лицехвата, чтобы подобрать его, или укажите цель, чтобы метнуть одного из хранилища на расстояние до четырёх клеток."
	button_icon = 'modular_bandastation/xeno_rework/icons/hive_actions.dmi'
	button_icon_state = "carrier"
	click_to_activate = TRUE
	cooldown_time = 2.5 SECONDS

/datum/action/cooldown/alien/banda/carrier_hugger/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/carrier/carrier = owner
	if(!istype(carrier) || !isturf(carrier.loc) || !target)
		return FALSE
	if(istype(target, /obj/item/clothing/mask/facehugger))
		return carrier.store_hugger(target)
	if(!(target in view(4, carrier)) || !length(carrier.stored_huggers))
		return FALSE
	var/obj/item/clothing/mask/facehugger/hugger = carrier.stored_huggers[1]
	if(QDELETED(hugger) || hugger.loc != carrier || hugger.facehugger_state == /obj/item/clothing/mask/facehugger/dead::facehugger_state)
		return FALSE
	// Keep the hugger inert while moving it out of storage so only the impact triggers attachment.
	hugger.go_idle()
	hugger.forceMove(carrier.loc)
	hugger.go_active()
	if(!hugger.throw_at(target, 4, 1, carrier))
		return FALSE
	StartCooldown()
	return TRUE

/** Use the original directional TGMC clingers; posture and quantity stay visible. */
/mob/living/carbon/alien/adult/banda/carrier/update_icons()
	. = ..()
	var/posture = ""
	if(stat == DEAD || IS_UNCONSCIOUS_OR_CRIT(src) || IsParalyzed())
		posture = " Knocked Down"
	else if(body_position == LYING_DOWN)
		posture = " Sleeping"
	for(var/index in 1 to min(length(stored_huggers), 4))
		add_overlay("clinger_[index][posture]")

/datum/action/cooldown/alien/banda/carrier_trap
	name = "Ловушка с лицехватом"
	desc = "Устанавливает под собой на траве ловушку и помещает в неё одного лицехвата из запаса. Наступивший человек падает, а лицехват выскакивает. Разрушение ловушки выпускает лицехвата."
	button_icon = 'modular_bandastation/xeno_rework/icons/hive_fortifications.dmi'
	button_icon_state = "hugger_trap_action"
	plasma_cost = 150

/datum/action/cooldown/alien/banda/carrier_trap/Activate()
	var/mob/living/carbon/alien/adult/banda/carrier/carrier = owner
	if(!istype(carrier) || !IsAvailable() || !length(carrier.stored_huggers) || !isopenturf(carrier.loc) || isspaceturf(carrier.loc))
		return FALSE
	var/turf/site = carrier.loc
	if(!(locate(/obj/structure/alien/weeds) in site) || (locate(/obj/structure/alien/carrier_trap) in site))
		return FALSE
	for(var/obj/blocker in site)
		if(blocker.density)
			return FALSE
	var/obj/item/clothing/mask/facehugger/hugger = carrier.stored_huggers[1]
	if(QDELETED(hugger) || hugger.loc != carrier || hugger.facehugger_state == /obj/item/clothing/mask/facehugger/dead::facehugger_state)
		return FALSE
	new /obj/structure/alien/carrier_trap(site, hugger)
	return TRUE

/// TGMC's trap releases its one stored hugger when stepped on or destroyed by damage.
/obj/structure/alien/carrier_trap
	name = "ловушка с лицехватом"
	desc = "Ямка в смоле с взведённой мембраной."
	icon = 'modular_bandastation/xeno_rework/icons/hive_fortifications.dmi'
	icon_state = "hugger_trap"
	layer = LOW_OBJ_LAYER
	anchored = TRUE
	max_integrity = 5
	var/obj/item/clothing/mask/facehugger/hugger
	var/static/list/trap_connections = list(COMSIG_ATOM_ENTERED = PROC_REF(on_entered))

/obj/structure/alien/carrier_trap/Initialize(mapload, obj/item/clothing/mask/facehugger/inserted)
	. = ..()
	if(QDELETED(inserted))
		return INITIALIZE_HINT_QDEL
	hugger = inserted
	hugger.forceMove(src)
	RegisterSignals(hugger, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED), PROC_REF(on_hugger_removed))
	AddElement(/datum/element/connect_loc, trap_connections)

/obj/structure/alien/carrier_trap/proc/on_hugger_removed(obj/item/clothing/mask/facehugger/source)
	SIGNAL_HANDLER
	if(QDELETED(source) || source.loc != src)
		UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		hugger = null

/obj/structure/alien/carrier_trap/proc/on_entered(datum/source, atom/movable/entrant)
	SIGNAL_HANDLER
	if(!ishuman(entrant))
		return
	var/mob/living/carbon/human/victim = entrant
	if(victim.stat == DEAD || QDELETED(hugger))
		return
	victim.Paralyze(4 SECONDS)
	var/obj/item/clothing/mask/facehugger/released = hugger
	if(!released.valid_to_attach(victim))
		return
	released.go_idle()
	release_hugger()
	if(!QDELETED(released))
		released.go_active()
		released.leap_to(victim, use_protection_charges = TRUE)
	qdel(src)

/obj/structure/alien/carrier_trap/proc/release_hugger()
	var/obj/item/clothing/mask/facehugger/released = hugger
	if(!QDELETED(released))
		UnregisterSignal(released, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		hugger = null
		released.forceMove(drop_location())
		return released

/obj/structure/alien/carrier_trap/atom_destruction(damage_flag)
	release_hugger()
	return ..()

/obj/structure/alien/carrier_trap/fire_act(exposed_temperature, exposed_volume)
	release_hugger()
	return ..()

/obj/structure/alien/carrier_trap/Destroy()
	if(hugger)
		UnregisterSignal(hugger, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
	QDEL_NULL(hugger)
	return ..()


/obj/item/clothing
	/// Single protection charge against huggers thrown by a Carrier or released from a trap.
	var/trap_hugger_protection = 1

/obj/item/clothing/proc/absorb_trap_hugger()
	if(HAS_TRAIT(src, TRAIT_NODROP))
		return TRUE
	if(trap_hugger_protection <= 0)
		return FALSE
	trap_hugger_protection--
	visible_message(span_warning("Лицехват повреждает защиту [src]!"))
	return TRUE
