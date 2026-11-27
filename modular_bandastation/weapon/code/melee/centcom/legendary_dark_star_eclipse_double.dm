#define ECLIPSE_DOUBLE_WINDOW (6 SECONDS)
#define ECLIPSE_ECHO_DELAY (0.4 SECONDS)
#define ECLIPSE_ECHO_COUNT 5

/datum/action/cooldown/legendary_sword/star_eclipse_double
	name = "Двойник затмения"
	desc = "Призовите двойника на 6 секунд. Он повторит до пяти ваших обычных попаданий Тёмной Звездой. Через 0,4 секунды после каждого попадания двойник ударит по отмеченной клетке с силой обычного удара мечом. Противник может уйти с клетки или заблокировать удар."
	button_icon = 'modular_bandastation/weapon/icons/melee/dark_star_eclipse_action.dmi'
	button_icon_state = "star_eclipse_double"
	required_bond = 100
	cooldown_time = 60 SECONDS

/datum/action/cooldown/legendary_sword/star_eclipse_double/Activate(atom/target)
	var/mob/living/user = owner
	if(!saber?.can_use_legendary_ability(user, required_bond))
		return FALSE
	if(!user.apply_status_effect(/datum/status_effect/dark_star_sequence/eclipse_double, saber, required_bond, src))
		return FALSE
	StartCooldown()
	return TRUE

/datum/status_effect/dark_star_sequence/eclipse_double
	id = "dark_star_eclipse_double"
	tick_interval = STATUS_EFFECT_NO_TICK
	locks_manual_attacks = FALSE
	var/obj/effect/dark_star_eclipse_double/double
	var/echoes_left = ECLIPSE_ECHO_COUNT
	var/pending_echoes = 0
	/// A mark placed before this deadline may still land after it.
	var/mark_deadline

/datum/status_effect/dark_star_sequence/eclipse_double/on_apply(obj/item/dualsaber/legendary_saber/saber, required_bond, datum/action/cooldown/legendary_sword/star_eclipse_double/ability)
	if(!..() || QDELETED(ability))
		return FALSE
	RegisterSignal(ability, COMSIG_ACTION_REMOVED, TYPE_PROC_REF(/datum/status_effect/legendary_sword_sequence, stop_sequence))
	double = new(owner, saber)
	if(QDELETED(double))
		return FALSE
	RegisterSignal(saber, COMSIG_ITEM_AFTERATTACK, PROC_REF(on_sword_hit))
	mark_deadline = world.time + ECLIPSE_DOUBLE_WINDOW
	addtimer(CALLBACK(src, PROC_REF(finish_if_done)), ECLIPSE_DOUBLE_WINDOW, TIMER_DELETE_ME)
	playsound(owner, 'modular_bandastation/weapon/sound/melee/ds_eclipse_summon.ogg', 40, FALSE)
	return TRUE

/datum/status_effect/dark_star_sequence/eclipse_double/on_remove()
	if(saber)
		UnregisterSignal(saber, COMSIG_ITEM_AFTERATTACK)
	QDEL_NULL(double)
	return ..()

/datum/status_effect/dark_star_sequence/eclipse_double/proc/on_sword_hit(datum/source, atom/victim, mob/living/user, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(user == owner && isliving(victim) && LAZYACCESS(attack_modifiers, DAMAGE_DONE) > 0 && !attack_modifiers[LEGENDARY_ABILITY_STRIKE])
		mark_swing(victim)

/datum/status_effect/dark_star_sequence/eclipse_double/proc/mark_swing(mob/living/victim)
	if(!can_continue() || QDELETED(double))
		qdel(src)
		return
	if(!echoes_left || world.time >= mark_deadline || !can_target(victim) || owner.has_ally(victim) || victim.has_ally(owner))
		return
	var/turf/marked_tile = victim.loc
	var/obj/effect/dark_star_eclipse_echo/echo = double.mark(marked_tile)
	echoes_left--
	pending_echoes++
	addtimer(CALLBACK(src, PROC_REF(repeat_swing), WEAKREF(victim), marked_tile, echo, !echoes_left), ECLIPSE_ECHO_DELAY, TIMER_DELETE_ME)

/datum/status_effect/dark_star_sequence/eclipse_double/proc/repeat_swing(datum/weakref/target_ref, turf/marked_tile, obj/effect/dark_star_eclipse_echo/echo, final_echo)
	if(!can_continue() || QDELETED(double))
		qdel(src)
		return
	var/mob/living/victim = target_ref.resolve()
	if(!QDELETED(echo))
		echo.strike(final_echo)
	var/echo_sound = final_echo ? 'modular_bandastation/weapon/sound/melee/ds_eclipse_cross.ogg' : 'modular_bandastation/weapon/sound/melee/ds_eclipse_echo.ogg'
	playsound(marked_tile, echo_sound, 45, FALSE)
	if(can_target(victim) && victim.loc == marked_tile && victim.IsReachableBy(owner, saber.reach) && !owner.has_ally(victim) && !victim.has_ally(owner))
		strike_marked_target(victim, list(AUTONOMOUS_MELEE_STRIKE = TRUE, SILENCE_HITSOUND = TRUE))
	if(QDELETED(src))
		return
	pending_echoes--
	finish_if_done()

/datum/status_effect/dark_star_sequence/eclipse_double/proc/finish_if_done()
	if(!pending_echoes && (!echoes_left || world.time >= mark_deadline))
		qdel(src)

#undef ECLIPSE_DOUBLE_WINDOW
#undef ECLIPSE_ECHO_DELAY
#undef ECLIPSE_ECHO_COUNT
