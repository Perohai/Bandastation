/** Armoured breacher; momentum, stomp and crest toss follow TGMC's Crusher role. */
/mob/living/carbon/alien/adult/banda/final_caste/crusher
	name = "alien crusher"
	desc = "Тяжёлый ксеноморф с бронированным гребнем. Разгоняется по прямой и проламывает оборону."
	caste = "crusher"
	inhand_caste = "warrior"
	icon = 'modular_bandastation/xeno_rework/icons/tgmc/crusher_adapted.dmi'
	icon_state = "aliencrusher"
	health = 445
	maxHealth = 445
	damage_resistance = 35
	melee_damage_lower = 25
	melee_damage_upper = 25
	/// Whether straight-line movement builds momentum.
	var/charge_enabled = FALSE
	/// Consecutive unforced steps in the same cardinal direction.
	var/momentum = 0
	/// Direction and timestamp used to discard interrupted runs.
	var/charge_direction = NONE
	/// Absolute timestamp of the last unforced charge step.
	var/last_charge_step = 0

/mob/living/carbon/alien/adult/banda/final_caste/crusher/Initialize(mapload)
	. = ..()
	GRANT_ACTION(/datum/action/cooldown/alien/banda/crusher_charge)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/crusher_stomp)
	GRANT_ACTION(/datum/action/cooldown/alien/banda/crusher_toss)
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)

/mob/living/carbon/alien/adult/banda/final_caste/crusher/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	var/was_fast = momentum >= 3
	if(!charge_enabled || forced || !(movement_dir in GLOB.cardinals) || incapacitated)
		momentum = 0
	else
		momentum = movement_dir == charge_direction && world.time - last_charge_step < 1 SECONDS ? min(momentum + 1, 5) : 1
	charge_direction = movement_dir
	last_charge_step = world.time
	if(momentum >= 3 && !was_fast)
		add_movespeed_modifier(/datum/movespeed_modifier/xeno_crusher_charge)
	else if(momentum < 3 && was_fast)
		remove_movespeed_modifier(/datum/movespeed_modifier/xeno_crusher_charge)

/mob/living/carbon/alien/adult/banda/final_caste/crusher/Bump(atom/obstacle)
	if(charge_enabled && momentum >= 3 && charge_direction == dir && world.time - last_charge_step < 1 SECONDS && !incapacitated && isturf(loc))
		if(isliving(obstacle) && !isalien(obstacle))
			var/mob/living/victim = obstacle
			victim.apply_damage(10 * momentum, BRUTE)
			victim.Knockdown(2 SECONDS)
			victim.throw_at(get_ranged_target_turf(src, dir, 3), 3, 2, src)
		else if(isobj(obstacle))
			var/obj/structure_target = obstacle
			structure_target.take_damage(30 * momentum, BRUTE, MELEE)
		momentum = 0
		remove_movespeed_modifier(/datum/movespeed_modifier/xeno_crusher_charge)
	return ..()

/** Movement bonus applied only while the Crusher has built momentum. */
/datum/movespeed_modifier/xeno_crusher_charge
	multiplicative_slowdown = -1

/** Toggle the Crusher's straight-line momentum mechanic. */
/datum/action/cooldown/alien/banda/crusher_charge
	name = "Разгон — Ready Charge"
	desc = "Движение по прямой разгоняет Crusher. После трёх шагов ускоряется и таранит врагов и конструкции; поворот, пауза и столкновение сбрасывают разгон."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc/crusher_actions.dmi'
	button_icon_state = "ready_charge"

/datum/action/cooldown/alien/banda/crusher_charge/Activate()
	var/mob/living/carbon/alien/adult/banda/final_caste/crusher/crusher = owner
	crusher.charge_enabled = !crusher.charge_enabled
	crusher.momentum = 0
	crusher.remove_movespeed_modifier(/datum/movespeed_modifier/xeno_crusher_charge)
	return TRUE

/** Area stomp, stronger against an enemy directly underneath the Crusher. */
/datum/action/cooldown/alien/banda/crusher_stomp
	name = "Топот — Stomp"
	desc = "Бьёт по земле: 60 урона и 3 секунды паралича врагу под вами; рядом — 30 урона, отбрасывание и 0,5 секунды паралича."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc/crusher_actions.dmi'
	button_icon_state = "stomp"
	plasma_cost = 100
	cooldown_time = 20 SECONDS

/datum/action/cooldown/alien/banda/crusher_stomp/Activate()
	playsound(owner, 'sound/effects/bang.ogg', 70, TRUE)
	owner.do_attack_animation(owner)
	for(var/mob/living/victim in view(1, owner))
		if(isalien(victim) || victim.stat == DEAD)
			continue
		var/same_tile = victim.loc == owner.loc
		victim.apply_damage(same_tile ? 60 : 30, BRUTE)
		victim.Paralyze(same_tile ? 3 SECONDS : 0.5 SECONDS)
		if(!same_tile)
			step_away(victim, owner)
	StartCooldown()
	return TRUE

/** Throw an adjacent creature over the crest, or forward in combat mode. */
/datum/action/cooldown/alien/banda/crusher_toss
	name = "Бросок гребнем — Crest Toss"
	desc = "Бросает соседнюю цель на шесть клеток: в боевом режиме вперёд, иначе за спину. Союзники не получают урон; враги получают 36 урона."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc/crusher_actions.dmi'
	button_icon_state = "cresttoss"
	plasma_cost = 75
	cooldown_time = 12 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/alien/banda/crusher_toss/Activate(atom/target)
	if(!isliving(target) || !owner.Adjacent(target) || !isturf(owner.loc))
		return FALSE
	var/mob/living/victim = target
	if(victim.anchored || victim.move_resist >= MOVE_FORCE_OVERPOWERING)
		return FALSE
	var/mob/living/carbon/alien/crusher = owner
	var/direction = crusher.combat_mode ? get_dir(owner, victim) : get_dir(victim, owner)
	if(!isalien(victim))
		victim.apply_damage(36, BRUTE)
	victim.throw_at(get_ranged_target_turf(owner, direction, 6), 6, 1, owner)
	owner.do_attack_animation(victim)
	StartCooldown()
	return TRUE
