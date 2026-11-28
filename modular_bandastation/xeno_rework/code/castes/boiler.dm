/** Siege caste with stockpiled corrosive/neurotoxin globs and stationary bombardment. */
/mob/living/carbon/alien/adult/banda/final_caste/boiler
	name = "alien boiler"
	previous_evolution = /mob/living/carbon/alien/adult/banda/spitter
	desc = "Осадная каста ксеноморфов. Накапливает сгустки газа и обстреливает врагов из неподвижной позиции."
	caste = "boiler"
	inhand_caste = "sentinel"
	icon = 'modular_bandastation/xeno_rework/icons/castes/boiler.dmi'
	icon_state = "alienboiler"
	hud_sprite_height = 42
	health = 320
	maxHealth = 320
	melee_damage_lower = 16
	melee_damage_upper = 16
	/// Selected ammunition, shared by creation and firing actions.
	var/corrosive = FALSE
	/// Stockpiled globs of each type; total capacity is seven.
	var/acid_globs = 0
	/// Stockpiled neurotoxin globs, sharing the seven-glob capacity.
	var/neuro_globs = 0

/mob/living/carbon/alien/adult/banda/final_caste/boiler/add_tts_component()
	AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/anivia)

/mob/living/carbon/alien/adult/banda/final_caste/boiler/Initialize(mapload)
	default_organ_types_by_slot = default_organ_types_by_slot.Copy()
	default_organ_types_by_slot[ORGAN_SLOT_XENO_PLASMAVESSEL] = /obj/item/organ/alien/plasmavessel/banda/large/boiler
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/banda/boiler_toggle)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/boiler_create)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/boiler_bombard)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/boiler_shroud)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/boiler_sight)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/boiler_well)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/acid_spray/boiler)
	GRANT_ACTION(/datum/action/cooldown/alien/acid/corrosion)
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	add_movespeed_modifier(/datum/movespeed_modifier/alien_heavy)

/** Boiler's artillery reservoir, sized for seven stockpiled globs and active abilities. */
/obj/item/organ/alien/plasmavessel/banda/large/boiler
	max_plasma = 1000
	plasma_rate = 15

/** Common icon source for the artillery controls. */
/datum/action/cooldown/alien/banda/boiler_toggle
	name = "Выбрать тип газа"
	desc = "Меняет тип газа, из которого создаются снаряды: едкий или нейротоксичный. Запас снарядов каждого вида хранится отдельно."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/boiler.dmi'
	button_icon_state = "corrosive_glob"

/datum/action/cooldown/alien/banda/boiler_toggle/Activate()
	var/mob/living/carbon/alien/adult/banda/final_caste/boiler/boiler = owner
	boiler.corrosive = !boiler.corrosive
	to_chat(boiler, span_notice("Выбран [boiler.corrosive ? "коррозионный" : "нейротоксичный"] газ. Снарядов: кислотных — [boiler.acid_globs], нейротоксичных — [boiler.neuro_globs]."))
	return TRUE

/** Create ammunition without allowing concurrent channelled creation. */
/datum/action/cooldown/alien/banda/boiler_create
	name = "Создать газовый шар"
	desc = "За 250 плазмы создаёт за две секунды газовый шар выбранного типа. Можно хранить до семи шаров."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/boiler.dmi'
	button_icon_state = "create_bomb"
	plasma_cost = 250
	/// Prevents simultaneous stockpiling with the same action.
	var/preparing = FALSE

/datum/action/cooldown/alien/banda/boiler_create/Activate()
	var/mob/living/carbon/alien/adult/banda/final_caste/boiler/boiler = owner
	if(preparing || boiler.acid_globs + boiler.neuro_globs >= 7)
		return FALSE
	preparing = TRUE
	var/ready = do_after(boiler, 2 SECONDS, target = boiler)
	preparing = FALSE
	if(!ready || QDELETED(src) || QDELETED(boiler) || !IsAvailable() || boiler.acid_globs + boiler.neuro_globs >= 7)
		return FALSE
	if(boiler.corrosive)
		boiler.acid_globs++
	else
		boiler.neuro_globs++
	return TRUE

/** Stationary artillery; ammunition is consumed only after both preparation phases. */
/datum/action/cooldown/alien/banda/boiler_bombard
	name = "Бомбардировка"
	desc = "Для обстрела нужно три секунды на подготовку и ещё две секунды на выстрел. Дальность — 5–20 клеток, облако держится 12 секунд. Газ распространяется по проходам, но не проходит сквозь стены."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/boiler.dmi'
	button_icon_state = "bombard"
	cooldown_time = 40 SECONDS
	click_to_activate = TRUE
	/// Holds the action busy across its preparation and firing delay.
	var/preparing = FALSE

/datum/action/cooldown/alien/banda/boiler_bombard/Activate(atom/target)
	var/mob/living/carbon/alien/adult/banda/final_caste/boiler/boiler = owner
	var/turf/destination = get_turf(target)
	if(preparing || !destination || !isturf(boiler.loc) || destination.z != boiler.z || get_dist(boiler, destination) < 5 || get_dist(boiler, destination) > 20)
		return FALSE
	var/corrosive = boiler.corrosive
	if(corrosive ? !boiler.acid_globs : !boiler.neuro_globs)
		return FALSE
	preparing = TRUE
	var/ready = do_after(boiler, 3 SECONDS, target = boiler) && do_after(boiler, 2 SECONDS, target = boiler)
	preparing = FALSE
	if(!ready || QDELETED(src) || QDELETED(boiler) || !IsAvailable() || !isturf(boiler.loc) || destination.z != boiler.z || get_dist(boiler, destination) > 20)
		return FALSE
	if(corrosive ? !boiler.acid_globs : !boiler.neuro_globs)
		return FALSE
	if(corrosive)
		boiler.acid_globs--
	else
		boiler.neuro_globs--
	var/obj/projectile/xeno_boiler/glob = new(boiler.loc)
	glob.corrosive = corrosive
	glob.aim_projectile(destination, boiler, list())
	glob.firer = boiler
	glob.fire()
	playsound(boiler, 'modular_bandastation/xeno_rework/sound/alien_spitacid.ogg', 75, TRUE)
	StartCooldown()
	return TRUE

/** Projectile which releases native, wall-aware smoke once. */
/obj/projectile/xeno_boiler
	name = "boiler glob"
	icon = 'icons/obj/weapons/guns/projectiles.dmi'
	icon_state = "toxin"
	damage = 0
	range = 20
	can_hit_turfs = TRUE
	/// Selects corrosive rather than neurotoxic smoke.
	var/corrosive = FALSE
	/// Guards against on_hit and on_range both releasing smoke.
	var/released = FALSE

/obj/projectile/xeno_boiler/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	release_gas()

/obj/projectile/xeno_boiler/on_range()
	release_gas()
	return ..()

/** Release an opaque gas cloud using the existing smoke propagation subsystem. */
/obj/projectile/xeno_boiler/proc/release_gas()
	if(released || !isopenturf(get_turf(src)))
		return
	released = TRUE
	do_smoke(range = 2, location = get_turf(src), effect_type = corrosive ? /obj/effect/particle_effect/fluid/smoke/xeno_boiler/acid : /obj/effect/particle_effect/fluid/smoke/xeno_boiler)

/** Neurotoxin cloud; native smoke protection and internals protect the respiratory tract. */
/obj/effect/particle_effect/fluid/smoke/xeno_boiler
	color = "#678443"
	lifetime = 12 SECONDS

/obj/effect/particle_effect/fluid/smoke/xeno_boiler/smoke_mob(mob/living/carbon/smoker, seconds_per_tick)
	if(!istype(smoker) || isalien(smoker) || smoker.internal || smoker.has_smoke_protection())
		return FALSE
	smoker.apply_damage(10 * seconds_per_tick, STAMINA, blocked = smoker.getarmor(null, BIO))
	return TRUE

/** Corrosive artillery smoke damages exposed targets; aliens remain immune. */
/obj/effect/particle_effect/fluid/smoke/xeno_boiler/acid
	color = "#94a640"

/obj/effect/particle_effect/fluid/smoke/xeno_boiler/acid/smoke_mob(mob/living/carbon/smoker, seconds_per_tick)
	if(isalien(smoker) || !istype(smoker))
		return FALSE
	smoker.apply_damage(5 * seconds_per_tick, BURN, blocked = smoker.getarmor(null, BIO))
	return TRUE

/** Local gas curtain shares bombardment's cooldown without consuming ammunition. */
/datum/action/cooldown/alien/banda/boiler_shroud
	name = "Завеса едкого газа"
	desc = "За 200 плазмы окутывает пространство вокруг себя облаком едкого газа. Запас снарядов не расходуется, но следующая бомбардировка станет доступна лишь через 40,5 секунды."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/boiler.dmi'
	button_icon_state = "acid_shroud"
	plasma_cost = 200
	cooldown_time = 32 SECONDS

/datum/action/cooldown/alien/banda/boiler_shroud/Activate()
	do_smoke(range = 2, holder = owner, location = get_turf(owner), effect_type = /obj/effect/particle_effect/fluid/smoke/xeno_boiler/acid)
	var/datum/action/cooldown/alien/banda/boiler_bombard/bombard = locate() in owner.actions
	bombard?.StartCooldown(40.5 SECONDS)
	StartCooldown()
	return TRUE

/** Stationary expanded vision uses the client's existing view packet. */
/datum/action/cooldown/alien/banda/boiler_sight
	name = "Дальний обзор"
	desc = "Через секунду сосредоточения расширяет область обзора. Движение или повторное нажатие возвращает обычный обзор."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/boiler.dmi'
	button_icon_state = "toggle_long_range"
	plasma_cost = 20

/datum/action/cooldown/alien/banda/boiler_sight/Activate()
	var/mob/living/boiler = owner
	if(boiler.has_status_effect(/datum/status_effect/xeno_boiler_sight))
		boiler.remove_status_effect(/datum/status_effect/xeno_boiler_sight)
		return TRUE
	if(!do_after(owner, 1 SECONDS, target = owner) || QDELETED(src) || QDELETED(owner) || !IsAvailable() || !owner.client)
		return FALSE
	return !!boiler.apply_status_effect(/datum/status_effect/xeno_boiler_sight)

/** Expands sight until movement, logout or teardown; never holds a client reference. */
/datum/status_effect/xeno_boiler_sight
	id = "xeno_boiler_sight"
	alert_type = null
	on_remove_on_mob_delete = TRUE
	/// View packet is released on logout, movement and effect teardown.
	var/datum/view_data/view_packet
	/// Previous packet overrides; zero means to use the client's default dimensions.
	var/original_width = 0
	/// Previous vertical packet override, restored together with the width.
	var/original_height = 0

/datum/status_effect/xeno_boiler_sight/on_apply()
	if(!owner.client || owner.client.view_size.isZooming())
		return FALSE
	view_packet = owner.client.view_size
	original_width = view_packet.width
	original_height = view_packet.height
	view_packet.add(6)
	RegisterSignals(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_LOGOUT), PROC_REF(end_sight))
	return TRUE

/** Cancel sight without sleeping in movement/logout signals. */
/datum/status_effect/xeno_boiler_sight/proc/end_sight()
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/xeno_boiler_sight/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_LOGOUT))
	if(view_packet?.chief)
		view_packet.setBoth(original_width, original_height)
	view_packet = null
	return ..()

/** Boiler acid spray with the caste-specific cooldown. */
/datum/action/cooldown/alien/banda/acid_spray/boiler
	desc = "Выпускает волну кислоты по прямой на расстояние до четырёх клеток в сторону курсора."
	cooldown_time = 9 SECONDS
	plasma_cost = 100
	spray_length = 4

/** Resin well supporting allies; placed on weeds and limited to one well per turf. */
/datum/action/cooldown/alien/banda/boiler_well
	name = "Колодец с кислотой"
	desc = "Создаёт на траве колодец с кислотой. Он тушит загоревшихся ксеноморфов и выпускает защитное облако кислотного газа. Запас — один заряд."
	button_icon = 'modular_bandastation/xeno_rework/icons/actions/tgmc/boiler.dmi'
	button_icon_state = "acid_shroud"
	plasma_cost = 400
	cooldown_time = 2 MINUTES

/datum/action/cooldown/alien/banda/boiler_well/Activate()
	var/turf/location = get_turf(owner)
	if(!isturf(owner.loc) || !(locate(/obj/structure/alien/weeds) in location) || (locate(/obj/effect/xeno_acid_pool/well) in location))
		return FALSE
	new /obj/effect/xeno_acid_pool/well(location)
	StartCooldown()
	return TRUE

/** Fire suppression well; the local adaptation expires after one minute. */
/obj/effect/xeno_acid_pool/well
	name = "acid well"
	lifetime = 1 MINUTES
	/// Prevents multiple entrants from spending the same charge during teardown.
	var/spent = FALSE

/obj/effect/xeno_acid_pool/well/affect(mob/living/victim, seconds_per_tick)
	if(spent || !isalien(victim) || !victim.on_fire)
		return
	spent = TRUE
	victim.extinguish_mob()
	do_smoke(range = 0, location = get_turf(src), effect_type = /obj/effect/particle_effect/fluid/smoke/xeno_boiler/acid)
	qdel(src)
