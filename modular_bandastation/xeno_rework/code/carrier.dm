/** T2 support branch from Drone; native eggs and facehuggers retain TG infection rules. */
/mob/living/carbon/alien/adult/banda/carrier
	name = "alien carrier"
	desc = "Носитель роя. Выращивает и переносит до четырёх хаггеров, бросает их и поддерживает улей феромонами."
	caste = "carrier"
	inhand_caste = "drone"
	icon = 'modular_bandastation/xeno_rework/icons/tgmc/carrier_adapted.dmi'
	icon_state = "aliencarrier"
	hud_sprite_height = 51
	evolution_tier = 2
	maxHealth = 250
	health = 250
	melee_damage_lower = 17
	melee_damage_upper = 17
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
	GRANT_ACTION(/datum/action/cooldown/alien/make_structure/lay_egg)

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
		. += span_notice("Хаггеры: [length(stored_huggers)]/[hugger_capacity].")

/obj/item/organ/alien/plasmavessel/carrier
	actions_types = list(/datum/action/cooldown/alien/transfer)
	max_plasma = 500
	stored_plasma = 100
	plasma_rate = 20
	heal_rate = 1

/datum/action/cooldown/alien/banda/carrier_spawn_hugger
	name = "Вырастить хаггера"
	desc = "Выращивает обычного хаггера TG и помещает в хранилище. 100 плазмы, перезарядка 20 секунд; вместимость 4."
	button_icon = 'modular_bandastation/xeno_rework/icons/hive_actions.dmi'
	button_icon_state = "carrier"
	plasma_cost = 100
	cooldown_time = 20 SECONDS

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
	name = "Хранить / бросить хаггера"
	desc = "Клик по соседнему хаггеру на полу — сохранить; клик по цели — бросить одного из хранилища до пяти клеток."
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
	if(!(target in view(5, carrier)) || !length(carrier.stored_huggers))
		return FALSE
	var/obj/item/clothing/mask/facehugger/hugger = carrier.stored_huggers[1]
	hugger.forceMove(carrier.loc)
	hugger.throw_at(target, 5, 1, carrier)
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
