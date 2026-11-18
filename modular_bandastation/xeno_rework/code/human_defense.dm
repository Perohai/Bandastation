/// Apply reworked attacks after the native attack_alien has validated blocks and pacifism.
/mob/living/carbon/human/proc/attack_banda_alien(mob/living/carbon/alien/adult/banda/user, list/modifiers)
	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		var/obj/item/mob_held_item = get_active_held_item()
		var/disarm_damage = rand(user.melee_damage_lower * 1.5, user.melee_damage_upper * 1.5)
		var/already_exhausted = has_status_effect(/datum/status_effect/incapacitating/stamcrit)
		apply_damage(disarm_damage, STAMINA)
		// Capped or diminished stamina damage does not fire the damage-change hook.
		if(already_exhausted && disarm_damage > 0 && !HAS_TRAIT(src, TRAIT_GODMODE))
			timed_stamina_reset()

		if(mob_held_item)
			playsound(loc, 'sound/items/weapons/thudswoosh.ogg', 25, TRUE, -1) //The sounds of these are changed so the xenos can actually hear they are being non-lethal
			Knockdown(3 SECONDS)
			visible_message(span_danger("[user] валит [src] на землю!"), \
				span_userdanger("[user] валит вас на землю!"), span_hear("Раздаётся торопливый топот когтистых лап, за которым следует тяжёлый глухой удар!"), null, user)
			to_chat(user, span_danger("Вы опрокидываете [src] на землю!"))
			return TRUE

		else
			playsound(loc, 'sound/effects/hit_kick.ogg', 25, TRUE, -1)
			log_combat(user, src, "tackled")
			visible_message(span_danger("[user] сбивает [src] с ног!"), \
							span_userdanger("[user] сбивает вас с ног!"), span_hear("Раздаётся торопливый топот когтистых лап!"), null, user)
			to_chat(user, span_danger("Вы валите [src] на землю!"))

		return TRUE

	if(user.combat_mode)
		if(w_uniform)
			w_uniform.add_fingerprint(user)

		var/damage = rand(user.melee_damage_lower, user.melee_damage_upper)
		var/obj/item/bodypart/affecting = get_bodypart(ran_zone(user.zone_selected))

		if(!affecting)
			affecting = get_bodypart(BODY_ZONE_CHEST)

		var/armor_block = run_armor_check(affecting, MELEE, "", "", 10)

		playsound(loc, 'sound/items/weapons/slice.ogg', 25, TRUE, -1)
		visible_message(span_danger("[user] полосует [src] когтями!"), \
						span_userdanger("[user] полосует вас когтями!"), span_hear("Слышится омерзительный звук рвущейся плоти!"), null, user)
		to_chat(user, span_danger("Вы полосуете [src] когтями!"))
		log_combat(user, src, "attacked")

		if(!dismembering_strike(user, user.zone_selected)) //Dismemberment successful
			return TRUE

		apply_damage(damage, BRUTE, affecting, armor_block)
		return TRUE
