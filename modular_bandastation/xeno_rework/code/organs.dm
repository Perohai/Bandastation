/// An alien organ that allows the owner to build resin structures.
/obj/item/organ/alien/resinspinner_banda
	parent_type = /obj/item/organ/alien/resinspinner
	name = "resin spinner"
	desc = "Железа, выделяющая смолу для возведения построек улья."
	icon_state = "spinner-x"
	zone = BODY_ZONE_PRECISE_MOUTH
	slot = ORGAN_SLOT_XENO_RESINSPINNER
	actions_types = list(
		/datum/action/cooldown/alien/select_resin_structure,
		/datum/action/cooldown/alien/build_resin_structure
	)

/// An alien stomach organ that can hold and digest contents, preventing attacks from within.
/obj/item/organ/stomach/alien_banda
	parent_type = /obj/item/organ/stomach/alien
	name = "alien stomach"
	desc = "Вместительный желудок, способный удерживать и переваривать самое разное содержимое."
	icon_state = "stomach-x"
	w_class = WEIGHT_CLASS_BULKY
	actions_types = list(/datum/action/cooldown/alien/regurgitate_banda, /datum/action/cooldown/alien/hive_swallow)
	organ_traits = list(TRAIT_STRONG_STOMACH)

	/// Tracks when each mob in the stomach started resisting (world.time).
	var/list/resist_times = list()
	/// Per-victim resistance callbacks, cancelled when occupants leave.
	var/list/resist_timers = list()

/// Returns the acid damage dealt to contents (none in this case).
/obj/item/organ/stomach/alien_banda/stomach_acid_power(atom/movable/nomnom)
	return 0 // No acid damage

/// Handles consumption of an atom, applying effects and signals for living contents.
/obj/item/organ/stomach/alien_banda/consume_thing(atom/movable/thing)
	if(isliving(thing))
		var/mob/living/prey = thing
		if(prey.stat == DEAD)
			to_chat(owner, span_warning("[prey] выглядит невкусно."))
			return FALSE
	. = ..()
	if (!.)
		return
	if (isliving(thing))
		var/mob/living/victim = thing
		RegisterSignal(victim, COMSIG_MOB_CLICKON, PROC_REF(block_attack_from_inside))
		RegisterSignal(victim, COMSIG_MOB_ITEM_ATTACK, PROC_REF(block_attack_from_inside))
		RegisterSignal(victim, COMSIG_MOB_ATTACK_RANGED, PROC_REF(block_attack_from_inside))
		RegisterSignal(victim, COMSIG_MOB_ATTACK_HAND, PROC_REF(block_attack_from_inside))
		RegisterSignal(victim, COMSIG_MOB_TRYING_TO_FIRE_GUN, PROC_REF(block_gunfire))
		victim.apply_status_effect(/datum/status_effect/temporary_blindness, STATUS_EFFECT_PERMANENT, "alien_stomach")

/// Handles movement of contents, cleaning up signals and effects when moved out.
// Signal-handler annotations are inherited; DreamChecker rejects repeating them on overrides.
/obj/item/organ/stomach/alien_banda/content_moved(atom/movable/source)
	. = ..()
	if (source.loc == src || source.loc == owner)
		return
	if (isliving(source))
		var/mob/living/victim = source
		UnregisterSignal(victim, list(
			COMSIG_LIVING_DEATH,
			COMSIG_MOB_CLICKON,
			COMSIG_MOB_ITEM_ATTACK,
			COMSIG_MOB_ATTACK_RANGED,
			COMSIG_MOB_ATTACK_HAND,
			COMSIG_MOB_TRYING_TO_FIRE_GUN
		))
		victim.remove_status_effect(/datum/status_effect/temporary_blindness, "alien_stomach")
		clear_resistance(victim)

/obj/item/organ/stomach/alien_banda/content_deleted(atom/movable/source)
	clear_resistance(source)
	return ..()

/// Transport never processes bodies: the hive must secure them in a nest.
/obj/item/organ/stomach/alien_banda/content_died(mob/living/source)
	if (QDELETED(src))
		return
	clear_resistance(source)
	UnregisterSignal(source, list(
		COMSIG_LIVING_DEATH,
		COMSIG_MOB_CLICKON,
		COMSIG_MOB_ITEM_ATTACK,
		COMSIG_MOB_ATTACK_RANGED,
		COMSIG_MOB_ATTACK_HAND,
		COMSIG_MOB_TRYING_TO_FIRE_GUN
	))
	source.remove_status_effect(/datum/status_effect/temporary_blindness, "alien_stomach")

/// Registers signals when the stomach is inserted into a mob.
/obj/item/organ/stomach/alien_banda/on_mob_insert(mob/living/carbon/stomach_owner, special, movement_flags)
	. = ..()
	RegisterSignal(stomach_owner, COMSIG_LIVING_DEATH, PROC_REF(owner_died))

/// Unregisters signals and cleans up contents when the stomach is removed.
/obj/item/organ/stomach/alien_banda/on_mob_remove(mob/living/carbon/stomach_owner, special, movement_flags)
	. = ..()
	UnregisterSignal(stomach_owner, list(
		COMSIG_ATOM_RELAYMOVE,
		COMSIG_LIVING_DEATH
	))
	for (var/mob/living/victim in stomach_contents)
		UnregisterSignal(victim, list(
			COMSIG_LIVING_DEATH,
			COMSIG_MOB_CLICKON,
			COMSIG_MOB_ITEM_ATTACK,
			COMSIG_MOB_ATTACK_RANGED,
			COMSIG_MOB_ATTACK_HAND,
			COMSIG_MOB_TRYING_TO_FIRE_GUN
		))
		victim.remove_status_effect(/datum/status_effect/temporary_blindness, "alien_stomach")
		clear_resistance(victim)

/// Handles the owner's death, ejecting all stomach contents.
/obj/item/organ/stomach/alien_banda/proc/owner_died(mob/living/carbon/stomach_owner)
	SIGNAL_HANDLER
	if (QDELETED(src))
		return
	empty_contents(chance = 100)

/// Handles movement attempts by contents, triggering resistance.
/obj/item/organ/stomach/alien_banda/something_moved(mob/living/source, mob/living/user, direction)
	relaymove(user, direction)
	return COMSIG_BLOCK_RELAYMOVE

/// Direct attacks on the owner must go through the resistance damage path.
/obj/item/organ/stomach/alien_banda/proc/block_attack_from_inside(datum/source, atom/target, mob/living/user, list/modifiers)
	SIGNAL_HANDLER
	if (QDELETED(src))
		return
	var/mob/living/attacker = ismob(source) ? source : user
	if (!attacker)
		return
	if ((attacker in stomach_contents) && target == owner)
		to_chat(attacker, span_warning("Из желудка нельзя атаковать ксеноморфа напрямую! Используйте клавиши движения, чтобы сопротивляться."))
		return COMPONENT_CANCEL_ATTACK_CHAIN

/** Block weapon firing from a swallowed occupant. */
/obj/item/organ/stomach/alien_banda/proc/block_gunfire(mob/living/source)
	SIGNAL_HANDLER
	if(source in stomach_contents)
		return COMPONENT_CANCEL_GUN_FIRE

/// Melee resistance uses the normal damage path, including armor and temporary shields.
/obj/item/organ/stomach/alien_banda/proc/attack_from_within(mob/living/attacker, obj/item/weapon)
	if(QDELETED(owner) || !weapon || !(attacker in stomach_contents) || weapon != attacker.get_active_held_item() || isgun(weapon) || weapon.force <= 0)
		return
	owner.apply_damage(weapon.force, BRUTE, BODY_ZONE_CHEST, blocked = owner.getarmor(BODY_ZONE_CHEST, MELEE), attacking_item = weapon)
	attacker.do_attack_animation(owner)
	if(weapon.hitsound)
		playsound(owner, weapon.hitsound, 50, TRUE)

/// Processes resistance attempts by contents, potentially ejecting them.
/obj/item/organ/stomach/alien_banda/relaymove(mob/living/user, direction)
	if (!(user in stomach_contents) || IS_UNCONSCIOUS_OR_CRIT(user))
		return

	// Track resistance start time
	if (isnull(resist_times[user]))
		resist_times[user] = world.time
		resist_timers[user] = addtimer(CALLBACK(src, PROC_REF(finish_resistance), user), 90 SECONDS, TIMER_STOPPABLE)
	if(world.time >= resist_times[user] + 90 SECONDS)
		finish_resistance(user)
		return
	if(world.time < user.next_move)
		return
	user.changeNext_move(CLICK_CD_MELEE)

	// Check for gun
	var/obj/item/pokie = user.get_active_held_item()
	if (pokie && isgun(pokie))
		to_chat(user, span_warning("Внутри желудка нельзя пользоваться огнестрельным оружием!"))
		return

	if (!prob(20))
		return

	var/atom/play_from = owner || src
	var/stomach_text = owner ? "желудка [owner.declent_ru(GENITIVE)]" : "[declent_ru(GENITIVE)]"

	// Slow down the victim's movement
	if (user.client)
		user.client.move_delay = world.time + 1.5 SECONDS

	// Handle resistance
	var/attack_name = ""
	var/attack_verb = ""
	if (pokie)
		attack_name = pokie.declent_ru(GENITIVE)
		var/list/attack_verbs = pokie.attack_verb_continuous
		attack_verb = length(attack_verbs) ? "[pick(attack_verbs)]" : "атакует"
		attack_from_within(user, pokie)
	else
		// Resistance with fists
		attack_name = "кулаков"
		attack_verb = "бьёт"

	// Notify players
	play_from.visible_message(span_danger("[capitalize(user.declent_ru(NOMINATIVE))] [attack_verb] стенки [stomach_text] с помощью [attack_name]!"), \
		span_userdanger("[capitalize(user.declent_ru(NOMINATIVE))] [attack_verb] стенки вашего желудка с помощью [attack_name]!"))

/// Cancel the callback as soon as its captive leaves or is deleted.
/obj/item/organ/stomach/alien_banda/proc/clear_resistance(atom/movable/victim)
	deltimer(resist_timers[victim])
	resist_timers -= victim
	resist_times -= victim

/** Release a swallowed occupant after its resistance delay. */
/obj/item/organ/stomach/alien_banda/proc/finish_resistance(mob/living/victim)
	if(QDELETED(victim) || !(victim in stomach_contents) || IS_UNCONSCIOUS_OR_CRIT(victim))
		return
	if(isnull(resist_times[victim]) || world.time < resist_times[victim] + 90 SECONDS)
		return
	var/atom/drop_as = owner || src
	victim.forceMove(drop_as.drop_location())

/obj/item/organ/stomach/alien_banda/Destroy()
	for(var/mob/living/victim as anything in resist_timers.Copy())
		clear_resistance(victim)
	return ..()

/// Ejects all stomach contents with a specified chance.
/obj/item/organ/stomach/alien_banda/empty_contents(chance = 100, damaging = FALSE, min_amount = 0)
	return eject_stomach(border_diamond_range_turfs(get_turf(src), 3), 3, 1, 1, 4)

/// Ejects contents when the owner vomits.
/obj/item/organ/stomach/alien_banda/on_vomit(mob/living/carbon/vomiter, distance, force)
	empty_contents(chance = 100)

/// Ejects stomach contents with acid particles to nearby turfs.
/obj/item/organ/stomach/alien_banda/eject_stomach(list/turf/targets, spit_range, content_speed, particle_delay, particle_count = 4)
	if(!length(stomach_contents))
		return 0
	var/atom/spit_as = owner || src
	var/ejected = length(stomach_contents)
	for (var/atom/movable/thing as anything in stomach_contents.Copy())
		thing.forceMove(spit_as.drop_location())
		if (isliving(thing))
			var/mob/living/victim = thing
			UnregisterSignal(victim, list(
				COMSIG_LIVING_DEATH,
				COMSIG_MOB_CLICKON,
				COMSIG_MOB_ITEM_ATTACK,
				COMSIG_MOB_ATTACK_RANGED,
				COMSIG_MOB_ATTACK_HAND,
				COMSIG_MOB_TRYING_TO_FIRE_GUN
			))
			victim.remove_status_effect(/datum/status_effect/temporary_blindness, "alien_stomach")
			clear_resistance(victim)
		if (length(targets))
			thing.throw_at(pick(targets), spit_range, content_speed, thrower = spit_as, spin = TRUE)

	for (var/a in 1 to particle_count)
		if (!length(targets))
			break
		var/obj/effect/particle_effect/water/extinguisher/stomach_acid/acid = new(get_turf(spit_as))
		var/turf/my_target = pick_n_take(targets)
		var/datum/reagents/acid_reagents = new /datum/reagents(5)
		acid.reagents = acid_reagents
		acid_reagents.my_atom = acid
		acid_reagents.add_reagent(/datum/reagent/toxin/acid, 30)
		acid.move_at(my_target, particle_delay, spit_range)

	return ejected

/// An action that allows the alien to regurgitate stomach contents.
/datum/action/cooldown/alien/regurgitate_banda
	name = "Изрыгнуть"
	desc = "Извергает всё содержимое желудка."
	button_icon_state = "alien_barf"
	/// Angle range for ejecting contents (degrees).
	var/angle_delta = 45
	/// Speed at which mobs are thrown.
	var/mob_speed = 1.5
	/// Speed at which particles are thrown.
	var/spit_speed = 1

/// Triggers regurgitation, ejecting stomach contents in a cone.
/datum/action/cooldown/alien/regurgitate_banda/Activate(atom/target)
	if (!iscarbon(owner))
		return
	var/mob/living/carbon/alien/adult/alieninated_owner = owner
	var/obj/item/organ/stomach/alien_banda/melting_pot = alieninated_owner.get_organ_slot(ORGAN_SLOT_STOMACH)
	if (!melting_pot)
		owner.visible_message(span_clown("[alieninated_owner] давится и выплёвывает немного фиолетовой жидкости. Фу-у-у!"), \
			span_alien("Вы чувствуете боль в... груди? Там ничего нет, ничего нет, нет, нет, н-"))
		return

	if (!length(melting_pot.stomach_contents))
		to_chat(owner, span_alien("Желудок пуст. Что именно вы собираетесь изрыгнуть?"))
		return
	owner.visible_message(span_danger("[owner] извергает содержимое своего желудка!"))
	var/dir_angle = dir2angle(owner.dir)

	playsound(owner, 'sound/mobs/non-humanoids/alien/alien_york.ogg', 100)
	melting_pot.eject_stomach(slice_off_turfs(owner, border_diamond_range_turfs(owner, 9), dir_angle - angle_delta, dir_angle + angle_delta), 4, mob_speed, spit_speed)

/** Keep the native vessel physiology without granting every reworked caste construction. */
/obj/item/organ/alien/plasmavessel/banda
	actions_types = list(/datum/action/cooldown/alien/transfer)

/obj/item/organ/alien/plasmavessel/banda/large
	max_plasma = 500
	stored_plasma = 200
	plasma_rate = 7.5

/obj/item/organ/alien/plasmavessel/banda/queen
	parent_type = /obj/item/organ/alien/plasmavessel/banda/large
	plasma_rate = 10

/obj/item/organ/alien/plasmavessel/banda/small
	max_plasma = 150
	stored_plasma = 100
	plasma_rate = 2.5

/obj/item/organ/alien/plasmavessel/banda/tiny
	parent_type = /obj/item/organ/alien/plasmavessel/banda/small
	max_plasma = 100

/datum/action/cooldown/alien/make_structure/plant_weeds/IsAvailable(feedback = FALSE)
	if(istype(owner, /mob/living/carbon/alien/brood))
		return FALSE
	if(!..())
		return FALSE
	if(istype(owner, /mob/living/carbon/alien/adult/banda))
		return istype(owner, /mob/living/carbon/alien/adult/banda/queen) || istype(owner, /mob/living/carbon/alien/adult/banda/drone) || istype(owner, /mob/living/carbon/alien/adult/banda/praetorian)
	return TRUE

/datum/action/cooldown/alien/acid/corrosion/IsAvailable(feedback = FALSE)
	if(istype(owner, /mob/living/carbon/alien/brood))
		return FALSE
	if(!..())
		return FALSE
	if(istype(owner, /mob/living/carbon/alien/adult/banda))
		return istype(owner, /mob/living/carbon/alien/adult/banda/queen) || istype(owner, /mob/living/carbon/alien/adult/banda/praetorian) || istype(owner, /mob/living/carbon/alien/adult/banda/final_caste/boiler)
	return TRUE
