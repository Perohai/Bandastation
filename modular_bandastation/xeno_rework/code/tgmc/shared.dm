/// TGMC base-caste port. Source revision and engine differences: README_TGMC.md.
#define XENO_TGMC_SLASH_SOURCE "xeno_tgmc_slash"
#define XENO_TGMC_ENDURE_SOURCE "xeno_tgmc_endure"
#define XENO_TGMC_RAGE_SOURCE "xeno_tgmc_rage"
#define XENO_TGMC_ACID_COOLDOWN "xeno_tgmc_acid_contact"

/mob/living/carbon/alien/adult/banda
	/// Only the three ported castes use the scoped melee implementation below.
	var/tgmc_combat = FALSE
	var/tgmc_melee_penetration = 0
	/// Source-keyed armor, owned by module mobs on both supported TG revisions.
	var/list/tgmc_armors

/mob/living/carbon/alien/adult/banda/proc/set_tgmc_armor(source, datum/armor/armor)
	if(!tgmc_armors)
		tgmc_armors = list()
	tgmc_armors[source] = armor

/mob/living/carbon/alien/adult/banda/proc/remove_tgmc_armor(source)
	LAZYREMOVE(tgmc_armors, source)

/mob/living/carbon/alien/adult/banda/getarmor(def_zone, type)
	. = ..()
	var/bonus_rating = 0
	for(var/source in tgmc_armors)
		var/datum/armor/armor = tgmc_armors[source]
		bonus_rating += armor.get_rating(type)
	// Preserve upstream armor, then apply the module's combined intrinsic layer.
	return 100 - (100 - .) * (1 - clamp(bonus_rating / 100, 0, 1))

/// Shared by normal claws, Charge and Ravage. Returns actual damage dealt.
/// Never feeds fury / Toxic Slash from a corpse, ally, blocked hit or object.
/mob/living/carbon/alien/adult/banda/proc/tgmc_melee_hit(mob/living/victim, multiplier = 1)
	if(QDELETED(victim) || victim == src || victim.stat == DEAD || isalien(victim))
		return 0
	if(HAS_TRAIT(src, TRAIT_PACIFISM) || !Adjacent(victim))
		return 0
	var/damage = rand(melee_damage_lower, melee_damage_upper) * multiplier
	if(victim.check_block(src, damage, "удар когтями", UNARMED_ATTACK, tgmc_melee_penetration, BRUTE))
		return 0
	SEND_SIGNAL(victim, COMSIG_MOB_ATTACK_ALIEN, src, null)
	var/zone = zone_selected
	if(ishuman(victim))
		var/mob/living/carbon/human/human_victim = victim
		zone = human_victim.get_bodypart(get_random_valid_zone(zone_selected))
		if(!zone)
			zone = human_victim.get_bodypart(BODY_ZONE_CHEST)
	var/armor = victim.run_armor_check(zone, MELEE, armour_penetration = tgmc_melee_penetration)
	do_attack_animation(victim)
	playsound(victim, 'modular_bandastation/xeno_rework/sound/bloodyslice.ogg', 40, TRUE)
	visible_message(span_danger("[src] рассекает [victim] когтями!"))
	var/dealt = victim.apply_damage(damage, BRUTE, zone, armor, sharpness = SHARP_EDGED)
	log_combat(src, victim, "slashed with TGMC claws")
	if(dealt > 0)
		tgmc_on_slash(victim, dealt)
	return dealt

/mob/living/carbon/alien/adult/banda/proc/tgmc_on_slash(mob/living/victim, damage)
	return

/// Conservative traversal: no walls, closed doors, dense structures or diagonal
/// corner cutting. Living occupants are handled by the relevant ability.
/mob/living/carbon/alien/adult/banda/proc/tgmc_clear_step(turf/origin_turf, turf/destination_turf, allow_tables = FALSE)
	if(!origin_turf || !destination_turf || origin_turf.z != destination_turf.z || destination_turf.density || !origin_turf.Adjacent(destination_turf))
		return FALSE
	for(var/obj/blocker in destination_turf)
		if(!blocker.density)
			continue
		if(allow_tables && istype(blocker, /obj/structure/table))
			continue
		return FALSE
	return TRUE

/mob/living/carbon/alien/adult/banda/proc/tgmc_heal(amount)
	var/brute_healed = min(get_brute_loss(), amount)
	adjust_brute_loss(-brute_healed)
	adjust_fire_loss(-max(0, amount - brute_healed))

/// TGMC uses a 0.5 life multiplier; gains are converted to points per second.
/// Keep TG's healing on weeds, replace only plasma regeneration.
/obj/item/organ/alien/plasmavessel/tgmc
	plasma_rate = 0
	var/tgmc_regen_per_second = 0
	var/tgmc_regen_limit = 1
	var/tgmc_innate_regen = FALSE

/obj/item/organ/alien/plasmavessel/tgmc/on_life(seconds_per_tick)
	. = ..()
	if(!owner || owner.stat == DEAD || !isturf(owner.loc))
		return
	if(!tgmc_innate_regen && !(locate(/obj/structure/alien/weeds) in owner.loc))
		return
	var/remaining = max_plasma * tgmc_regen_limit - stored_plasma
	if(remaining <= 0)
		return
	var/regen = tgmc_regen_per_second * seconds_per_tick
	if(owner.resting)
		regen *= 2
	owner.adjustPlasma(min(remaining, regen))

/obj/item/organ/alien/plasmavessel/tgmc/sentinel
	max_plasma = 600
	stored_plasma = 300
	tgmc_regen_per_second = 10

/obj/item/organ/alien/plasmavessel/tgmc/spitter
	max_plasma = 925
	stored_plasma = 462.5
	tgmc_regen_per_second = 20

/obj/item/organ/alien/plasmavessel/tgmc/ravager
	name = "fury vessel"
	max_plasma = 800
	stored_plasma = 400
	tgmc_regen_per_second = 7.5
	tgmc_regen_limit = 0.5
	tgmc_innate_regen = TRUE

/datum/armor/xeno_tgmc_sentinel
	melee = 30
	bullet = 30
	laser = 30
	energy = 30
	bomb = 10
	bio = 30
	fire = 30
	acid = 30

/datum/armor/xeno_tgmc_spitter
	melee = 25
	bullet = 35
	laser = 35
	energy = 35
	bio = 20
	fire = 35
	acid = 20

/datum/armor/xeno_tgmc_ravager
	melee = 50
	bullet = 55
	laser = 50
	energy = 50
	bomb = 10
	bio = 40
	fire = 70
	acid = 40

/datum/armor/xeno_tgmc_endure
	bomb = 20

/datum/armor/xeno_tgmc_drain_surge
	melee = 20
	bullet = 20
	laser = 20
	energy = 20
	bomb = 20
	bio = 20
	fire = 20
	acid = 20

/datum/action/cooldown/alien/banda/tgmc
	/// Aim without consuming plasma; alien/PreActivate pays after Activate succeeds.
	click_to_activate = TRUE
	unset_after_click = FALSE
	click_cd_override = 0

/datum/action/cooldown/alien/banda/tgmc/IsAvailable(feedback = FALSE)
	return ..() && isturf(owner.loc)

/datum/action/cooldown/alien/banda/tgmc/PreActivate(atom/target)
	if(!IsAvailable(TRUE) || !target || !isturf(target.loc) && !isturf(target))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf || target_turf.z != owner.z)
		return FALSE
	return ..()

/// Contained actors may never become a projectile's original target.
/datum/action/cooldown/alien/banda/tgmc/proc/fire_spit(atom/target, projectile_type)
	var/obj/projectile/projectile = new projectile_type(get_turf(owner))
	projectile.firer = owner
	projectile.fired_from = src
	projectile.aim_projectile(target, owner)
	projectile.fire()
	playsound(owner, 'modular_bandastation/xeno_rework/sound/alien_spitacid.ogg', 50, TRUE)
	StartCooldown()
	return TRUE
