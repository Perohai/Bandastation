/// Base Sentinel, excluding Retrograde and Primordial mutations.
/datum/action/cooldown/alien/banda/tgmc/toxic_spit
	name = "Toxic Spit"
	desc = "Токсичный плевок с дальностью 8 клеток: ожоги и 5 уровней интоксикации."
	button_icon_state = "neurospit_0"
	plasma_cost = 30
	/// 1s caste delay + inherited 0.5s acid-ammo delay.
	cooldown_time = 1.5 SECONDS

/datum/action/cooldown/alien/banda/tgmc/toxic_spit/Activate(atom/target)
	return fire_spit(target, /obj/projectile/xeno_tgmc_acid/toxic)

/obj/projectile/xeno_tgmc_acid/toxic
	name = "toxic spit"
	icon_state = "neurotoxin"
	damage = 23.2 // 16 base + 45% normal-caste spit bonus.

/obj/projectile/xeno_tgmc_acid/toxic/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(blocked < 100 && iscarbon(target) && !isalien(target))
		xeno_tgmc_intoxicate(target, 5)

/proc/xeno_tgmc_intoxicate(mob/living/carbon/victim, amount)
	if(QDELETED(victim) || victim.stat == DEAD || isalien(victim) || HAS_TRAIT(victim, TRAIT_XENO_IMMUNE) || HAS_TRAIT(victim, TRAIT_GODMODE))
		return
	var/datum/status_effect/xeno_tgmc_intoxicated/intoxication = victim.has_status_effect(/datum/status_effect/xeno_tgmc_intoxicated)
	if(intoxication)
		intoxication.change_stacks(amount)
	else
		victim.apply_status_effect(/datum/status_effect/xeno_tgmc_intoxicated, amount)

/datum/status_effect/xeno_tgmc_intoxicated
	id = "xeno_tgmc_intoxicated"
	alert_type = null
	tick_interval = 2 SECONDS
	remove_on_fullheal = TRUE
	var/stacks = 0
	var/max_stacks = 30
	var/resisting = FALSE

/datum/status_effect/xeno_tgmc_intoxicated/on_creation(mob/living/new_owner, amount = 5)
	stacks = clamp(amount, 1, max_stacks)
	return ..()

/datum/status_effect/xeno_tgmc_intoxicated/on_apply()
	if(!iscarbon(owner) || isalien(owner) || owner.stat == DEAD)
		return FALSE
	RegisterSignal(owner, COMSIG_LIVING_RESIST, PROC_REF(on_resist))
	owner.balloon_alert(owner, "интоксикация!")
	owner.add_filter(id, 2, outline_filter(1, "#7DCC00"))
	return TRUE

/datum/status_effect/xeno_tgmc_intoxicated/get_examine_text(mob/examiner)
	return span_warning("На коже заметны следы едкого токсина ксеноморфов.")

/datum/status_effect/xeno_tgmc_intoxicated/proc/change_stacks(amount)
	stacks = clamp(stacks + amount, 0, max_stacks)
	if(stacks <= 0)
		qdel(src)

/datum/status_effect/xeno_tgmc_intoxicated/tick(seconds_between_ticks)
	if(owner.stat == DEAD || HAS_TRAIT(owner, TRAIT_XENO_IMMUNE))
		qdel(src)
		return
	var/decay = owner.getarmor(null, BIO) >= 65 ? 2 : 1
	change_stacks(-decay)
	if(QDELETED(src))
		return
	owner.adjust_fire_loss(1 + round(stacks / 10))
	if(stacks >= 20)
		owner.apply_status_effect(/datum/status_effect/staggered, 1 SECONDS)

/datum/status_effect/xeno_tgmc_intoxicated/proc/on_resist()
	SIGNAL_HANDLER
	if(!resisting)
		INVOKE_ASYNC(src, PROC_REF(resist_toxin))

/datum/status_effect/xeno_tgmc_intoxicated/proc/resist_toxin()
	if(resisting)
		return
	resisting = TRUE
	while(!QDELETED(src) && owner && owner.stat == BANDA_XENO_AWAKE_STAT && stacks > 0)
		if(!do_after(owner, 5 SECONDS, target = owner))
			break
		if(QDELETED(src))
			return
		change_stacks(-8)
		if(QDELETED(src))
			return
	resisting = FALSE

/datum/status_effect/xeno_tgmc_intoxicated/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_RESIST)
	owner.remove_filter(id)

/datum/action/cooldown/alien/banda/tgmc/toxic_slash
	name = "Toxic Slash"
	desc = "На 4 секунды насыщает когти токсином. Три успешных удара добавляют по 5 уровней интоксикации."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc_sentinel_actions.dmi'
	button_icon_state = "neuroclaws_off"
	click_to_activate = FALSE
	plasma_cost = 100
	cooldown_time = 10 SECONDS

/datum/action/cooldown/alien/banda/tgmc/toxic_slash/Activate(atom/target)
	var/mob/living/caster = owner
	if(caster.has_status_effect(/datum/status_effect/xeno_tgmc_toxic_claws))
		return FALSE
	caster.apply_status_effect(/datum/status_effect/xeno_tgmc_toxic_claws)
	StartCooldown()
	return TRUE

/datum/status_effect/xeno_tgmc_toxic_claws
	id = "xeno_tgmc_toxic_claws"
	alert_type = null
	duration = 4 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	var/remaining_slashes = 3

/datum/status_effect/xeno_tgmc_toxic_claws/on_apply()
	owner.add_filter(id, 2, outline_filter(1, "#7DCC00"))
	owner.balloon_alert(owner, "когти отравлены")
	return TRUE

/datum/status_effect/xeno_tgmc_toxic_claws/on_remove()
	owner.remove_filter(id)

/mob/living/carbon/alien/adult/banda/sentinel/tgmc_on_slash(mob/living/victim, damage)
	var/datum/status_effect/xeno_tgmc_toxic_claws/claws = has_status_effect(/datum/status_effect/xeno_tgmc_toxic_claws)
	if(!claws || !iscarbon(victim))
		return
	xeno_tgmc_intoxicate(victim, 5)
	claws.remaining_slashes--
	if(claws.remaining_slashes <= 0)
		qdel(claws)

/datum/action/cooldown/alien/banda/tgmc/drain_sting
	name = "Drain Sting"
	desc = "Поражает соседнюю отравленную цель. Интоксикация усиливает урон, лечение и восстановление плазмы; расходуется 70% уровней."
	button_icon = 'modular_bandastation/xeno_rework/icons/tgmc_sentinel_actions.dmi'
	button_icon_state = "neuro_sting"
	plasma_cost = 75
	cooldown_time = 25 SECONDS
	unset_after_click = TRUE

/datum/action/cooldown/alien/banda/tgmc/drain_sting/PreActivate(atom/target)
	if(!ishuman(target) || target == owner || !owner.Adjacent(target))
		return FALSE
	var/mob/living/carbon/human/victim = target
	if(victim.stat == DEAD || HAS_TRAIT(victim, TRAIT_XENO_IMMUNE) || !victim.has_status_effect(/datum/status_effect/xeno_tgmc_intoxicated))
		return FALSE
	return ..()

/datum/action/cooldown/alien/banda/tgmc/drain_sting/Activate(atom/target)
	var/mob/living/carbon/human/victim = target
	var/mob/living/carbon/alien/adult/banda/caster = owner
	var/datum/status_effect/xeno_tgmc_intoxicated/intoxication = victim.has_status_effect(/datum/status_effect/xeno_tgmc_intoxicated)
	if(!intoxication)
		return FALSE
	var/stacks = intoxication.stacks
	var/potency = stacks * 6
	victim.adjust_fire_loss(potency / 5)
	victim.Knockdown(max(0.1 SECONDS, stacks - 10))
	caster.tgmc_heal(potency)
	caster.adjustPlasma(potency * 3.5)
	if(stacks > 20)
		caster.apply_status_effect(/datum/status_effect/xeno_tgmc_drain_surge)
	intoxication.change_stacks(-round(stacks * 0.7))
	caster.do_attack_animation(victim)
	playsound(caster, 'modular_bandastation/xeno_rework/sound/alien_tail_swipe.ogg', 45, TRUE)
	log_combat(caster, victim, "used Drain Sting")
	StartCooldown()
	return TRUE

/datum/status_effect/xeno_tgmc_drain_surge
	id = "xeno_tgmc_drain_surge"
	alert_type = null
	duration = 10 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH

/datum/status_effect/xeno_tgmc_drain_surge/on_apply()
	var/mob/living/carbon/alien/adult/banda/caster = owner
	if(!istype(caster))
		return FALSE
	caster.set_tgmc_armor(id, new /datum/armor/xeno_tgmc_drain_surge)
	owner.add_filter(id, 2, outline_filter(2, "#7FFF00"))
	return TRUE

/datum/status_effect/xeno_tgmc_drain_surge/on_remove()
	var/mob/living/carbon/alien/adult/banda/caster = owner
	if(istype(caster))
		caster.remove_tgmc_armor(id)
	owner.remove_filter(id)

/obj/item/organ/alien/neurotoxin/tgmc_sentinel
	name = "sentinel toxic glands"
	actions_types = list(
		/datum/action/cooldown/alien/banda/tgmc/toxic_spit,
		/datum/action/cooldown/alien/banda/tgmc/toxic_slash,
		/datum/action/cooldown/alien/banda/tgmc/drain_sting,
		/datum/action/cooldown/alien/acid/corrosion,
	)
