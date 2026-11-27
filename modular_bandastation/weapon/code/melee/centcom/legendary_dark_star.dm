#define DARK_STAR_CUT_WINDUP (0.7 SECONDS)
#define DARK_STAR_BLADES_WINDUP (1 SECONDS)

/// Marks one living target and follows it through the windup.
/datum/action/cooldown/legendary_sword/star_judgment_cut
	name = "Звёздный разрез"
	desc = "Выберите живую цель в пределах пяти клеток и сохраняйте стойку. Через 0,7 секунды клинок рассечёт цель, если она всё ещё видна и в пределах досягаемости. Попадание резко замедляет цель на 3 секунды, а разрез плоти вызывает сильное кровотечение."
	button_icon = 'modular_bandastation/weapon/icons/melee/dark_star_cut.dmi'
	button_icon_state = "star_judgment_cut"
	click_to_activate = TRUE
	cooldown_time = 12 SECONDS

/datum/action/cooldown/legendary_sword/star_judgment_cut/Activate(atom/target)
	var/mob/living/user = owner
	if(!isliving(target) || !saber?.can_use_legendary_ability(user, required_bond))
		return FALSE
	if(!user.apply_status_effect(/datum/status_effect/dark_star_sequence/judgment_cut, saber, required_bond, target))
		return FALSE
	StartCooldown()
	return TRUE

/// The shared sword sequence cancels the windup on disarm, incapacitation or loss of the blade.
/datum/status_effect/dark_star_sequence/judgment_cut
	tick_interval = STATUS_EFFECT_NO_TICK
	/// Removed immediately if the wielder breaks their stance.
	var/obj/effect/temp_visual/dark_star_cut/mark
	/// The body part that took damage after the target's defenses resolved.
	var/obj/item/bodypart/struck_limb

/datum/status_effect/dark_star_sequence/judgment_cut/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond, mob/living/victim)
	if(!..() || !can_target(victim))
		return FALSE
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/datum/status_effect/legendary_sword_sequence, stop_sequence))
	owner.face_atom(victim)
	begin_swing(get_turf(victim))
	mark = new(victim)
	playsound(owner, saber.unwieldsound, 30, FALSE)
	addtimer(CALLBACK(src, PROC_REF(release_cut), victim), DARK_STAR_CUT_WINDUP, TIMER_DELETE_ME)
	return TRUE

/datum/status_effect/dark_star_sequence/judgment_cut/on_remove()
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	struck_limb = null
	end_swing()
	QDEL_NULL(mark)
	return ..()

/datum/status_effect/dark_star_sequence/judgment_cut/proc/release_cut(mob/living/victim)
	if(!can_continue() || !can_target(victim))
		qdel(src)
		return
	new /obj/effect/temp_visual/dark_star_cut/hit(victim)
	RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(record_cut_limb))
	var/damage_done = strike_marked_target(victim, list(FORCE_OVERRIDE = 25), 'modular_bandastation/weapon/sound/melee/ds_judgment_cut.ogg')
	if(!QDELETED(victim))
		UnregisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE)
	if(damage_done > 0 && !QDELETED(victim) && victim.stat != DEAD)
		victim.apply_status_effect(/datum/status_effect/tired_post_charge/dark_star_cut)
		victim.balloon_alert(victim, "движения замедлились")
		if(!QDELETED(struck_limb) && struck_limb.owner == victim && struck_limb.can_bleed())
			struck_limb.force_wound_upwards(/datum/wound/slash/flesh/severe, wound_source = saber)
			var/datum/wound/slash/flesh/cut = locate() in struck_limb.wounds
			if(cut?.severity >= WOUND_SEVERITY_SEVERE && cut.blood_flow < WOUND_MAX_BLOODFLOW)
				cut.set_blood_flow(WOUND_MAX_BLOODFLOW)
	qdel(src)

/datum/status_effect/dark_star_sequence/judgment_cut/proc/record_cut_limb(datum/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, obj/item/attacking_item)
	SIGNAL_HANDLER
	if(damage_dealt > 0 && attacking_item == saber && isbodypart(def_zone))
		struck_limb = def_zone

/// A separate modifier lets other movement penalties expire independently of the cut.
/datum/status_effect/tired_post_charge/dark_star_cut
	id = "dark_star_cut_slow"
	duration = 3 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH
	tired_movespeed = /datum/movespeed_modifier/status_effect/dark_star_cut

/datum/movespeed_modifier/status_effect/dark_star_cut
	multiplicative_slowdown = 4.5

/// The target carries the effect even when another mob occupies the same turf.
/obj/effect/temp_visual/dark_star_target
	randomdir = FALSE
	vis_flags = VIS_INHERIT_PLANE

/obj/effect/temp_visual/dark_star_target/Initialize(mapload)
	. = ..()
	var/mob/living/victim = loc
	if(!istype(victim))
		return INITIALIZE_HINT_QDEL
	victim.vis_contents += src
	flick(icon_state, src)

/obj/effect/temp_visual/dark_star_cut
	parent_type = /obj/effect/temp_visual/dark_star_target
	icon = 'modular_bandastation/weapon/icons/melee/dark_star_cut.dmi'
	icon_state = "cut_mark"
	duration = DARK_STAR_CUT_WINDUP

/obj/effect/temp_visual/dark_star_cut/hit
	icon_state = "cut_hit"
	duration = 0.5 SECONDS

/// Four summoned blades converge on the selected opponent.
/datum/action/cooldown/legendary_sword/star_phantom_blades
	name = "Призрачные клинки"
	desc = "Выберите противника в пределах пяти клеток. Четыре клинка окружат его и через секунду ударят разом. По силе залп равен четырём обычным ударам Тёмной Звезды. Удерживайте цель в поле зрения и в пределах досягаемости до удара."
	button_icon = 'modular_bandastation/weapon/icons/melee/dark_star_blades_action.dmi'
	button_icon_state = "star_phantom_blades"
	click_to_activate = TRUE
	required_bond = 50
	cooldown_time = 45 SECONDS

/datum/action/cooldown/legendary_sword/star_phantom_blades/Activate(atom/target)
	var/mob/living/user = owner
	if(!isliving(target) || !saber?.can_use_legendary_ability(user, required_bond))
		return FALSE
	if(!user.apply_status_effect(/datum/status_effect/dark_star_sequence/phantom_blades, saber, required_bond, target))
		return FALSE
	StartCooldown()
	return TRUE

/obj/effect/temp_visual/dark_star_blades
	parent_type = /obj/effect/temp_visual/dark_star_target
	icon = 'modular_bandastation/weapon/icons/melee/dark_star_blades.dmi'
	icon_state = "ring"
	pixel_x = -32
	pixel_y = -32
	duration = DARK_STAR_BLADES_WINDUP

/obj/effect/temp_visual/dark_star_blades/strike
	icon_state = "strike"
	duration = 0.4 SECONDS

/datum/status_effect/dark_star_sequence
	parent_type = /datum/status_effect/legendary_sword_sequence
	id = "dark_star_sequence"

/datum/status_effect/dark_star_sequence/proc/can_target(mob/living/victim)
	return !QDELETED(victim) && victim != owner && victim.stat != DEAD && isopenturf(victim.loc) && (victim in view(saber.reach, owner))

/// Use the sword's normal armor and block resolution at range without starting its dash.
/datum/status_effect/dark_star_sequence/proc/strike_marked_target(mob/living/victim, list/modifiers, hit_sound, volume = 50)
	if(!modifiers[SILENCE_HITSOUND])
		playsound(victim, hit_sound || saber.hit_wield, volume, FALSE)
	modifiers[MELEE_EFFECT_ORIGIN] = owner
	modifiers[LEGENDARY_ABILITY_STRIKE] = TRUE
	modifiers[SILENCE_HITSOUND] = TRUE
	modifiers[REPLACE_MELEE_HIT_EFFECTS] = TRUE
	victim.attackby(saber, owner, null, modifiers)
	return modifiers[DAMAGE_DONE]

/datum/status_effect/dark_star_sequence/phantom_blades
	tick_interval = STATUS_EFFECT_NO_TICK
	/// The ring is removed immediately if either participant interrupts the cast.
	var/obj/effect/temp_visual/dark_star_blades/ring

/datum/status_effect/dark_star_sequence/phantom_blades/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond, mob/living/victim)
	if(!..() || !can_target(victim))
		return FALSE
	owner.face_atom(victim)
	ring = new(victim)
	RegisterSignals(victim, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), TYPE_PROC_REF(/datum/status_effect/legendary_sword_sequence, stop_sequence))
	playsound(victim, saber.wieldsound, 35, FALSE)
	addtimer(CALLBACK(src, PROC_REF(release_blades), victim), DARK_STAR_BLADES_WINDUP, TIMER_DELETE_ME)
	return TRUE

/datum/status_effect/dark_star_sequence/phantom_blades/on_remove()
	QDEL_NULL(ring)
	return ..()

/datum/status_effect/dark_star_sequence/phantom_blades/proc/release_blades(mob/living/victim)
	if(!can_continue() || !can_target(victim))
		qdel(src)
		return
	var/obj/item/dualsaber/legendary_saber/dark_star/star = saber
	star.command_star_blade(owner, victim)
	new /obj/effect/temp_visual/dark_star_blades/strike(victim)
	strike_marked_target(victim, list(FORCE_MULTIPLIER = 4), 'modular_bandastation/weapon/sound/melee/ds_phantom_volley.ogg')
	qdel(src)

/// The dash wards off direct attacks while environmental and periodic damage still apply.
/datum/status_effect/dark_star_sequence/protected_dash
	/// Stun signals have no attack source, so use the tick of the preceding direct hit.
	var/last_direct_attack = -1

/datum/status_effect/dark_star_sequence/protected_dash/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond)
	if(!..())
		return FALSE
	RegisterSignals(owner, list(COMSIG_LIVING_CHECK_BLOCK, COMSIG_ATOM_BULLET_ACT), PROC_REF(note_direct_attack))
	RegisterSignal(owner, COMSIG_MOB_APPLY_DAMAGE_MODIFIERS, PROC_REF(reduce_direct_damage))
	RegisterSignal(owner, COMSIG_LIVING_GENERIC_STUN_CHECK, PROC_REF(block_attack_stun))
	RegisterSignal(owner, COMSIG_LIVING_STATUS_UNCONSCIOUS, PROC_REF(block_attack_unconsciousness))
	return TRUE

/datum/status_effect/dark_star_sequence/protected_dash/on_remove()
	UnregisterSignal(owner, list(
		COMSIG_LIVING_CHECK_BLOCK,
		COMSIG_ATOM_BULLET_ACT,
		COMSIG_MOB_APPLY_DAMAGE_MODIFIERS,
		COMSIG_LIVING_GENERIC_STUN_CHECK,
		COMSIG_LIVING_STATUS_UNCONSCIOUS,
	))
	return ..()

/datum/status_effect/dark_star_sequence/protected_dash/proc/note_direct_attack()
	SIGNAL_HANDLER
	last_direct_attack = world.time

/datum/status_effect/dark_star_sequence/protected_dash/proc/reduce_direct_damage(datum/source, list/damage_modifiers, damage, damage_type, def_zone, sharpness, attack_direction, atom/attacking_item)
	SIGNAL_HANDLER
	if(isprojectile(attacking_item) || !isnull(attack_direction) || (last_direct_attack == world.time && (damage_type == BRUTE || damage_type == STAMINA)))
		damage_modifiers.Add(0.05)

/datum/status_effect/dark_star_sequence/protected_dash/proc/block_attack_stun()
	SIGNAL_HANDLER
	if(last_direct_attack == world.time)
		return COMPONENT_NO_STUN

/datum/status_effect/dark_star_sequence/protected_dash/proc/block_attack_unconsciousness(datum/source, duration, ignore_canstun)
	SIGNAL_HANDLER
	if(last_direct_attack == world.time && duration > 0 && !ignore_canstun)
		return COMPONENT_NO_STUN

#undef DARK_STAR_CUT_WINDUP
#undef DARK_STAR_BLADES_WINDUP
