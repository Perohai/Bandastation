GLOBAL_DATUM(xeno_hive, /datum/xeno_hive)

/** Round-owned state: a replacement queen inherits the same hive. */
/proc/get_xeno_hive()
	if(!GLOB.xeno_hive)
		GLOB.xeno_hive = new
	return GLOB.xeno_hive

/** Economy parameters are kept together for testmerge tuning through VV. */
/datum/xeno_hive
	/// Earned from prey, first occupation of station floors, and purchased generators.
	var/biomass = 0
	/// Shared spawn gate prevents observers bypassing the final minion cooldown.
	var/next_baneling_at = 0
	/// Time between successful baneling claims, independent of the claiming ghost.
	var/baneling_interval = 120 SECONDS
	/// The admin resource checkbox is a one-time operation for this round.
	var/debug_used = FALSE
	/// Total reward for one physical human body.
	var/human_reward = 100
	/// Monkeys, including round-created monkeys, have a smaller budget.
	var/monkey_reward = 20
	/// Fractions of the body budget paid before full processing.
	var/infection_fraction = 0.2
	/// Birth pays this fraction once; processing always pays the remaining budget.
	var/birth_fraction = 0.3
	/// Corpse processing takes this long after birth or removal of an embryo.
	var/processing_time = 150 SECONDS
	/// Time spent securing prey to a prepared nest.
	var/cocoon_time = 6 SECONDS
	/// Passive currency, exclusively for weak brood.
	var/brood_points = 0
	/// Points per living crew member per minute, capped below.
	var/brood_per_crew = 1
	/// Maximum passive points per minute, irrespective of population.
	var/brood_max_per_minute = 60
	/// Passive point cost of one unclaimed weak brood place.
	var/brood_slot_cost = 100
	/// Completed purchases, keyed by upgrade id.
	var/list/purchased = list()
	/// Authoritative upgrade definitions, keyed by id.
	var/list/datum/xeno_hive_upgrade/upgrades = list()
	/// Members unregister on deletion; dead members stay eligible for upgrades on revival.
	var/list/mob/living/carbon/alien/adult/banda/members = list()
	/// Only one queen may channel a purchase or core operation at a time.
	var/purchase_busy = FALSE
	/// Successful damaging events interrupt the current channel even if immediately healed.
	var/purchase_interrupted = FALSE
	/// Channel duration before revalidation and atomic payment.
	var/purchase_time = 5 SECONDS
	/// Physical core; its teardown clears the unused brood and fractional points.
	var/obj/structure/xeno_hive_core/core
	/// Weak reference avoids retaining a deleted queen.
	var/datum/weakref/queen_ref

/datum/xeno_hive/New()
	. = ..()
	for(var/upgrade_type in subtypesof(/datum/xeno_hive_upgrade))
		var/datum/xeno_hive_upgrade/upgrade = new upgrade_type
		upgrades[upgrade.id] = upgrade

/datum/xeno_hive/Destroy()
	QDEL_NULL(core)
	QDEL_NULL(packed_core)
	update_core_blockade()
	QDEL_NULL(hivemind_anchor)
	QDEL_LIST_ASSOC_VAL(rally_points)
	for(var/mob/living/carbon/alien/adult/banda/member as anything in members.Copy())
		UnregisterSignal(member, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))
	members.Cut()
	claimed_territory.Cut()
	QDEL_LIST_ASSOC_VAL(upgrades)
	queen_ref = null
	return ..()

/** Register once, then apply the same purchased effects to existing and future adults. */
/datum/xeno_hive/proc/add_member(mob/living/carbon/alien/adult/banda/member)
	if(member in members)
		return
	members += member
	RegisterSignal(member, COMSIG_QDELETING, PROC_REF(remove_member))
	if(istype(member, /mob/living/carbon/alien/adult/banda/queen))
		queen_ref = WEAKREF(member)
		RegisterSignal(member, COMSIG_LIVING_DEATH, PROC_REF(queen_died))
	apply_upgrades(member)

/datum/xeno_hive/proc/remove_member(mob/living/carbon/alien/adult/banda/source)
	SIGNAL_HANDLER
	members -= source
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))

/datum/xeno_hive/proc/queen_died(mob/living/carbon/alien/adult/banda/queen/source)
	SIGNAL_HANDLER
	biomass *= 0.5
	purchase_interrupted = TRUE

/** A dead queen may be revived; deleting her never retains the body. */
/datum/xeno_hive/proc/living_queen()
	var/mob/living/carbon/alien/adult/banda/queen/queen = queen_ref?.resolve()
	return queen?.stat != DEAD ? queen : null

/** Shared crew definition with the evacuation finale; no client requirement for crew. */
/datum/xeno_hive/proc/count_crew()
	var/count = 0
	for(var/mob/living/member in GLOB.alive_mob_list)
		if(!isalien(member) && (member.mind?.assigned_role?.job_flags & JOB_CREW_MEMBER))
			count++
	return count

/datum/xeno_hive/proc/brood_rate(crew)
	return clamp(crew * brood_per_crew, 0, brood_max_per_minute)

/** Called only by the installed core. A destroyed clutch loses places, not fractional points. */
/datum/xeno_hive/proc/advance_brood(seconds_per_tick, crew)
	if(!living_queen() || QDELETED(core) || !core.is_installed())
		return
	brood_points += brood_rate(crew) * seconds_per_tick / 60
	if(brood_slot_cost <= 0)
		return
	var/places = FLOOR(brood_points / brood_slot_cost, 1)
	if(places <= 0)
		return
	// Fully enclosed cores retain points until an adjacent spawning turf becomes available.
	var/created = core.add_brood(places)
	brood_points -= created * brood_slot_cost

/** Ordinary resurrection keeps this component; a newly created mob is a new body. */
/proc/get_xeno_biomass_body(mob/living/carbon/body)
	if(QDELETED(body) || !ishuman(body))
		return null
	var/datum/component/xeno_biomass_body/existing = body.GetComponent(/datum/component/xeno_biomass_body)
	if(existing)
		return existing
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	if(!chest || !IS_ORGANIC_LIMB(chest))
		return null
	return body.LoadComponent(/datum/component/xeno_biomass_body)

/** Stores reward history on the physical mob, never on a mind or embryo. */
/datum/component/xeno_biomass_body
	/// Budget is fixed at first use, so later species changes cannot increase it.
	var/reward_limit
	/// Total already credited to the hive, including credits before a rescue.
	var/paid = 0
	/// Persistent idempotency keys for the physical body.
	var/list/paid_stages = list()

/datum/component/xeno_biomass_body/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/carbon/body = parent
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	if(!chest || !IS_ORGANIC_LIMB(chest))
		return COMPONENT_INCOMPATIBLE
	var/datum/xeno_hive/hive = get_xeno_hive()
	reward_limit = ismonkey(body) ? hive.monkey_reward : hive.human_reward

/** Idempotent stage payments; processing pays only the remainder of the body budget. */
/datum/component/xeno_biomass_body/proc/pay(stage)
	if(stage in paid_stages)
		return 0
	var/datum/xeno_hive/hive = get_xeno_hive()
	var/reward = 0
	switch(stage)
		if("infection")
			reward = round(reward_limit * hive.infection_fraction)
		if("birth")
			reward = round(reward_limit * hive.birth_fraction)
		if("processing")
			reward = reward_limit - paid
		else
			return 0
	reward = clamp(reward, 0, max(0, reward_limit - paid))
	paid_stages += stage
	paid += reward
	hive.biomass += reward
	return reward

/** Embryo insertion retains all native organ and surgical behavior. */
/obj/item/organ/body_egg/alien_embryo/on_mob_insert(mob/living/carbon/egg_owner, special, movement_flags)
	. = ..()
	var/datum/component/xeno_biomass_body/body = get_xeno_biomass_body(egg_owner)
	body?.pay("infection")

/// A ghost still connected to a living alien cannot take a second hive role.
/proc/can_claim_hive_larva(mob/dead/observer/ghost)
	if(!isobserver(ghost) || !ghost.client || ghost.client.mob != ghost)
		return FALSE
	var/mob/living/carbon/alien/body = ghost.mind?.current
	return !isalien(body) || body.stat == DEAD || !ghost.can_reenter_corpse

/// Run the hive role poll during the final seconds of gestation.
/obj/item/organ/body_egg/alien_embryo/proc/poll_hive_larva(poll_duration)
	var/mob/living/carbon/host = owner
	if(QDELETED(host) || bursting || stage < 5 || !host.GetComponent(/datum/component/xeno_biomass_body))
		return
	bursting = TRUE
	var/birth_time = world.time + poll_duration
	var/mob/dead/observer/candidate
	if(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER)
		candidate = SSpolling.poll_ghosts_for_target(
			question = "Хотите сыграть за личинку улья? Она скоро вылупится.",
			check_jobban = ROLE_ALIEN,
			poll_time = poll_duration,
			checked_target = src,
			ignore_category = POLL_IGNORE_ALIEN_LARVA,
			role_name_text = "Личинка улья",
			chat_text_border_icon = /mob/living/carbon/alien/larva,
			announce_chosen = FALSE,
		)
	if(world.time < birth_time)
		sleep(birth_time - world.time)
	// The stage timer can run on either side of the poll's last tick.
	if(!QDELETED(src) && stage == 5)
		sleep(world.tick_lag)
	if(QDELETED(src))
		return
	if(QDELETED(host) || owner != host || stage < 6)
		bursting = FALSE
		return
	on_poll_concluded(TRUE, candidate)

/** Module hook used after the ghost poll, without replacing infection or surgery. */
/obj/item/organ/body_egg/alien_embryo/proc/banda_birth(mob/dead/observer/ghost)
	var/mob/living/carbon/host = owner
	var/datum/component/xeno_biomass_body/body = host?.GetComponent(/datum/component/xeno_biomass_body)
	if(QDELETED(host) || !body)
		return FALSE
	var/mutable_appearance/burst_overlay = mutable_appearance('icons/mob/nonhuman-player/alien.dmi', "burst_lie")
	host.add_overlay(burst_overlay)
	sleep(0.6 SECONDS)
	var/ghost_ckey = ghost?.ckey
	var/candidate_valid = can_claim_hive_larva(ghost) && !is_banned_from(ghost_ckey, list(ROLE_ALIEN, ROLE_SYNDICATE))
	if(QDELETED(src) || QDELETED(host) || owner != host)
		if(!QDELETED(host))
			host.cut_overlay(burst_overlay)
		if(!QDELETED(src))
			bursting = FALSE
		return TRUE
	var/mob/living/carbon/alien/larva/larva = new(get_turf(host))
	if(candidate_valid && (GLOB.ghost_role_flags & GHOSTROLE_SPAWNER) && can_claim_hive_larva(ghost) && ghost.ckey == ghost_ckey)
		larva.PossessByPlayer(ghost.key)
	else
		// Birth and corpse processing must not stall forever when the poll has no candidates.
		larva.AddComponent(/datum/component/ghost_direct_control, ban_type = ROLE_ALIEN, poll_candidates = FALSE, extra_control_checks = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(can_claim_hive_larva)), joinable_mobs_title = "Личинка улья", assumed_control_message = "Вы — личинка улья. Растите и эволюционируйте!")
	host.cut_overlay(burst_overlay)
	playsound(larva, 'sound/effects/goresplat.ogg', 55, TRUE)
	larva.pixel_z += 8
	animate(larva, pixel_z = initial(larva.pixel_z), time = 0.3 SECONDS)
	larva.visible_message(span_danger("[larva] вырывается из груди [host]!"))
	host.log_message("was killed by an emerging alien larva; body preserved for rescue.", LOG_ATTACK)
	host.death()
	body.pay("birth")
	qdel(src)
	return TRUE
