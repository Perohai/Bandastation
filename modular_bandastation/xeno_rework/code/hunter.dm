/** Mobile ambusher with stealth, pounce, marked prey and disposable mirages. */
/mob/living/carbon/alien/adult/banda/final_caste/hunter
	name = "alien hunter"
	desc = "Охотник роя: маскируется, выслеживает отмеченную жертву и нападает из засады."
	caste = "hunter"
	evolution_tier = 2
	inhand_caste = "runner"
	icon = 'modular_bandastation/xeno_rework/icons/tgmc/hunter_adapted.dmi'
	icon_state = "alienhunter"
	base_pixel_x = 0
	base_pixel_y = 0
	pixel_x = 0
	pixel_y = 0
	sprite_scale = 1
	sprite_pixel_y_offset = 0
	maptext_width = 32
	maptext_height = 32
	hud_sprite_height = 30
	health = 310
	maxHealth = 310
	melee_damage_lower = 25
	melee_damage_upper = 25
	/// Weak reference avoids retaining deleted prey.
	var/datum/weakref/marked_prey
	/// True only while a pounce throw is in flight.
	var/pouncing = FALSE

/mob/living/carbon/alien/adult/banda/final_caste/hunter/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/banda/hunter_stealth)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/hunter_pounce)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/hunter_mark)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/hunter_trace)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/hunter_mirage)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/hunter_silence)
	add_movespeed_modifier(/datum/movespeed_modifier/alien_quick)

/mob/living/carbon/alien/adult/banda/final_caste/hunter/Destroy()
	marked_prey = null
	return ..()

/mob/living/carbon/alien/adult/banda/final_caste/hunter/resolve_unarmed_attack(atom/target, list/modifiers)
	var/datum/status_effect/xeno_hunter_stealth/stealth = has_status_effect(/datum/status_effect/xeno_hunter_stealth)
	var/ready = stealth && world.time - stealth.entered_stealth >= 2 SECONDS
	var/mob/living/victim = isliving(target) ? target : null
	var/old_damage = victim ? victim.get_brute_loss() + victim.get_fire_loss() : 0
	remove_status_effect(/datum/status_effect/xeno_hunter_stealth)
	. = ..()
	if(ready && victim && !QDELETED(victim) && !isalien(victim) && Adjacent(victim) && victim.get_brute_loss() + victim.get_fire_loss() > old_damage)
		victim.Paralyze(1 SECONDS)

/** Ends the pounce on arrival or obstruction. */
/mob/living/carbon/alien/adult/banda/final_caste/hunter/proc/end_pounce()
	pouncing = FALSE
	remove_status_effect(/datum/status_effect/xeno_hunter_stealth)

/mob/living/carbon/alien/adult/banda/final_caste/hunter/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	if(pouncing && isliving(hit_atom) && !isalien(hit_atom) && !incapacitated)
		var/mob/living/victim = hit_atom
		var/blocked = FALSE
		if(ishuman(victim))
			var/mob/living/carbon/human/human = victim
			blocked = human.check_block(src, 0, name, attack_type = LEAP_ATTACK)
		if(!blocked)
			victim.Knockdown(2 SECONDS)
	end_pounce()
	return ..()

/** Toggle camouflage; plasma upkeep follows movement rather than polling the map. */
/datum/action/cooldown/alien/banda/hunter_stealth
	name = "Маскировка — Stealth"
	desc = "Вход в маскировку занимает 3 секунды: движение, урон или потеря сознания прерывают подготовку. Прозрачность как у ниндзя; движение расходует плазму. После двух секунд маскировки удар парализует на секунду. Урон раскрывает охотника."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc/hunter_actions.dmi'
	button_icon_state = "hunter_invisibility"
	plasma_cost = 10
	cooldown_time = 5 SECONDS
	/// Serializes entry channels, including repeated direct activations.
	var/preparing = FALSE
	/// Camouflage is earned by an uninterrupted exposed preparation.
	var/entry_time = 3 SECONDS
	/// Damage interrupts even when healed before the next do_after check.
	var/entry_interrupted = FALSE

/datum/action/cooldown/alien/banda/hunter_stealth/proc/can_enter(mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter)
	return !QDELETED(src) && !QDELETED(hunter) && owner == hunter && !entry_interrupted && !hunter.has_status_effect(/datum/status_effect/xeno_hunter_stealth) && IsAvailable() && isturf(hunter.loc)

/datum/action/cooldown/alien/banda/hunter_stealth/proc/on_entry_damage(datum/source, damage)
	SIGNAL_HANDLER
	if(damage > 0)
		entry_interrupted = TRUE

/datum/action/cooldown/alien/banda/hunter_stealth/Activate()
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = owner
	if(preparing || !istype(hunter) || !IsAvailable())
		return FALSE
	if(hunter.has_status_effect(/datum/status_effect/xeno_hunter_stealth))
		hunter.remove_status_effect(/datum/status_effect/xeno_hunter_stealth)
	else
		preparing = TRUE
		entry_interrupted = FALSE
		RegisterSignal(hunter, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_entry_damage))
		hunter.visible_message(span_warning("[hunter] замирает, сливаясь с окружением..."))
		var/ready = do_after(hunter, entry_time, target = hunter, extra_checks = CALLBACK(src, PROC_REF(can_enter), hunter))
		UnregisterSignal(hunter, COMSIG_MOB_AFTER_APPLY_DAMAGE)
		if(QDELETED(src))
			return FALSE
		preparing = FALSE
		if(!ready || !can_enter(hunter))
			return FALSE
		hunter.apply_status_effect(/datum/status_effect/xeno_hunter_stealth)
	StartCooldown()
	return TRUE

/datum/action/cooldown/alien/banda/hunter_stealth/Remove(mob/living/remove_from)
	entry_interrupted = TRUE
	UnregisterSignal(remove_from, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	return ..()

/** Camouflage stores its original alpha and releases all signals on teardown. */
/datum/status_effect/xeno_hunter_stealth
	id = "xeno_hunter_stealth"
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// Alpha before entering camouflage.
	var/original_alpha
	/// Preparation timestamp for the ambush bonus.
	var/entered_stealth

/datum/status_effect/xeno_hunter_stealth/on_apply()
	original_alpha = owner.alpha
	entered_stealth = world.time
	owner.alpha = min(original_alpha, /obj/item/mod/module/stealth/ninja::stealth_alpha)
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
	RegisterSignal(owner, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_damage))
	return TRUE

/** Consume plasma and expose a moving silhouette. */
/datum/status_effect/xeno_hunter_stealth/proc/on_move()
	SIGNAL_HANDLER
	var/mob/living/carbon/alien/xeno = owner
	xeno.adjustPlasma(-5)
	owner.alpha = min(original_alpha, /obj/item/mod/module/stealth/ninja::stealth_alpha)
	if(xeno.getPlasma() <= 0)
		qdel(src)

/** Damage breaks camouflage immediately. */
/datum/status_effect/xeno_hunter_stealth/proc/on_damage(datum/source, damage)
	SIGNAL_HANDLER
	if(damage > 0)
		qdel(src)

/datum/status_effect/xeno_hunter_stealth/tick(seconds_between_ticks)
	if(owner.incapacitated || owner.on_fire)
		qdel(src)
		return

/datum/status_effect/xeno_hunter_stealth/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_AFTER_APPLY_DAMAGE))
	owner.alpha = original_alpha
	return ..()

/** Leap using normal thrown-mob movement and collision. */
/datum/action/cooldown/alien/banda/hunter_pounce
	name = "Прыжок — Pounce"
	desc = "Прыжок на семь клеток. Попадание опрокидывает противника на две секунды и снимает маскировку."
	button_icon_state = "pounce"
	plasma_cost = 75
	cooldown_time = 10 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/alien/banda/hunter_pounce/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = owner
	var/turf/destination = get_turf(target)
	if(!destination || !isturf(hunter.loc) || destination.z != hunter.z || destination == hunter.loc || hunter.pouncing)
		return FALSE
	hunter.pouncing = TRUE
	if(!hunter.throw_at(destination, 7, 1, hunter, spin = FALSE, callback = CALLBACK(hunter, TYPE_PROC_REF(/mob/living/carbon/alien/adult/banda/final_caste/hunter, end_pounce))))
		hunter.end_pounce()
		return FALSE
	playsound(hunter, 'modular_bandastation/xeno_rework/sound/pounce.ogg', 60, TRUE)
	StartCooldown()
	return TRUE

/** Mark only visible living enemies; no raw player references are accepted. */
/datum/action/cooldown/alien/banda/hunter_mark
	name = "Метка охотника — Hunter's Mark"
	desc = "Отмечает видимого врага. Psychic Trace сообщает направление, расстояние, область и общее состояние жертвы. Метку можно сменить раз в минуту."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc/hunter_actions.dmi'
	button_icon_state = "hunter_mark"
	plasma_cost = 25
	cooldown_time = 1 MINUTES
	click_to_activate = TRUE

/datum/action/cooldown/alien/banda/hunter_mark/Activate(atom/target)
	if(!isliving(target) || isalien(target) || !(target in view(7, owner)))
		return FALSE
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = owner
	hunter.marked_prey = WEAKREF(target)
	StartCooldown()
	return TRUE

/** Read a weakly held mark without exposing player keys or remote z-level contents. */
/datum/action/cooldown/alien/banda/hunter_trace
	name = "Психический след — Psychic Trace"
	desc = "За одну плазму определяет направление, расстояние, местоположение и состояние отмеченной жертвы на текущем уровне."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc/hunter_actions.dmi'
	button_icon_state = "psychic_trace"
	plasma_cost = 1
	cooldown_time = 5 SECONDS

/datum/action/cooldown/alien/banda/hunter_trace/Activate()
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = owner
	var/mob/living/prey = hunter.marked_prey?.resolve()
	if(!prey || prey.z != hunter.z)
		return FALSE
	to_chat(hunter, span_notice("След: [dir2text(get_dir(hunter, prey))], [get_dist(hunter, prey)] клеток, [get_area_name(prey)]. [prey.stat == DEAD ? "Жертва мертва." : "Жертва жива."]"))
	StartCooldown()
	return TRUE

/** Silence affects a five-by-five visible area and lasts longer on the marked enemy. */
/datum/action/cooldown/alien/banda/hunter_silence
	name = "Безмолвие — Silence"
	desc = "Видимые враги в области 5×5 теряют речь и слух на 5 секунд; отмеченная жертва — на 10 секунд. Перезарядка 100 секунд."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc/hunter_actions.dmi'
	button_icon_state = "silence"
	plasma_cost = 50
	cooldown_time = 100 SECONDS

/datum/action/cooldown/alien/banda/hunter_silence/Activate()
	var/mob/living/carbon/alien/adult/banda/final_caste/hunter/hunter = owner
	playsound(hunter, 'modular_bandastation/xeno_rework/sound/hunter_silence.ogg', 85, TRUE)
	for(var/mob/living/carbon/victim in view(2, hunter))
		if(isalien(victim))
			continue
		var/duration = victim == hunter.marked_prey?.resolve() ? 10 SECONDS : 5 SECONDS
		victim.adjust_silence(duration)
		var/obj/item/organ/ears/ears = victim.get_organ_slot(ORGAN_SLOT_EARS)
		ears?.adjust_temporary_deafness(duration)
	StartCooldown()
	return TRUE

/** Three decoys with a validated swap to one of their visible positions. */
/datum/action/cooldown/alien/banda/hunter_mirage
	name = "Мираж — Mirage"
	desc = "Создаёт три иллюзии на десять секунд: они преследуют ближайших противников и наносят 2 урона за удар. Пока они существуют, повторный клик по своей иллюзии меняет вас с ней местами в пределах видимости."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc/hunter_actions.dmi'
	button_icon_state = "mirror_image"
	plasma_cost = 50
	cooldown_time = 33 SECONDS
	click_to_activate = TRUE
	/// Decoys are weakly held because their visual lifetime owns their deletion.
	var/list/datum/weakref/decoys = list()

/datum/action/cooldown/alien/banda/hunter_mirage/IsAvailable(feedback = FALSE)
	for(var/datum/weakref/reference as anything in decoys)
		if(reference.resolve())
			var/mob/living/carbon/alien/adult/banda/hunter = owner
			return hunter && !hunter.incapacitated && !hunter.resting && !HAS_TRAIT(hunter, TRAIT_IMMOBILIZED) && !hunter.unable_to_use_abilities && isturf(hunter.loc)
	return ..()

/datum/action/cooldown/alien/banda/hunter_mirage/Activate(atom/target)
	if(!isturf(owner.loc))
		return FALSE
	for(var/datum/weakref/reference as anything in decoys)
		var/mob/living/basic/illusion/xeno_mirage/illusion = reference.resolve()
		if(!illusion)
			continue
		var/turf/destination = get_turf(illusion)
		if(target != illusion || !isturf(owner.loc) || !(illusion in view(4, owner)) || !isopenturf(destination) || destination.is_blocked_turf())
			continue
		var/turf/old_location = get_turf(owner)
		owner.forceMove(illusion.loc)
		illusion.forceMove(old_location)
		clear_decoys()
		return TRUE
	for(var/datum/weakref/reference as anything in decoys)
		if(reference.resolve())
			return FALSE
	decoys.Cut()
	var/list/candidates = list()
	for(var/turf/open/location in view(3, owner))
		if(location != owner.loc && !location.is_blocked_turf())
			candidates += location
	if(!length(candidates))
		return FALSE
	for(var/index in 1 to min(3, length(candidates)))
		var/turf/location = pick_n_take(candidates)
		var/mob/living/basic/illusion/xeno_mirage/illusion = new(location, owner)
		decoys += WEAKREF(illusion)
	StartCooldown()
	return TRUE

/** Delete any remaining visuals when the action leaves its owner. */
/datum/action/cooldown/alien/banda/hunter_mirage/proc/clear_decoys()
	for(var/datum/weakref/reference as anything in decoys)
		var/mob/living/basic/illusion/illusion = reference.resolve()
		if(illusion)
			qdel(illusion)
	decoys.Cut()

/datum/action/cooldown/alien/banda/hunter_mirage/Remove(mob/living/remove_from)
	clear_decoys()
	return ..()

/** Native illusion AI acquires nearby enemies; fixed small damage cannot inherit Hunter claws. */
/mob/living/basic/illusion/xeno_mirage
	melee_damage_lower = 2
	melee_damage_upper = 2
	maxHealth = 15
	health = 15
	density = FALSE

/mob/living/basic/illusion/xeno_mirage/Initialize(mapload, mob/living/original)
	. = ..()
	if(!original)
		return INITIALIZE_HINT_QDEL
	full_setup(original, life = 10 SECONDS, hp = 15, damage = 2, replicate = 0)
	mouse_opacity = MOUSE_OPACITY_ICON
	pixel_x = original.pixel_x
	pixel_y = original.pixel_y
	transform = original.transform
