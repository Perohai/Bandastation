///  MODULE _XENO_REDO

/mob/living/carbon/alien/adult/banda
	abstract_type = /mob/living/carbon/alien/adult/banda
	name = "rare bugged alien"
	icon = 'modular_bandastation/xeno_rework/icons/big_xenos.dmi'
	rotate_on_lying = FALSE
	base_pixel_x = -16 //All of the xeno sprites are 64x64, and we want them to be level with the tile they are on, much like oversized quirk users
	base_pixel_y = -4 //Same for y, change this for better transform scale
	mob_size = MOB_SIZE_HUMAN
	layer = LARGE_MOB_LAYER //above most mobs, but below speechbubbles
	plane = ABOVE_GAME_PLANE
	maptext_height = 64
	maptext_width = 64
	pressure_resistance = 200

	/// What icon file update_held_items will look for when making inhands for xenos
	var/alt_inhands_file = 'modular_bandastation/xeno_rework/icons/big_xenos.dmi'
	/// Setting this will give a xeno generic_evolve set to evolve them into this type
	var/evolution_tier = 1
	var/next_evolution
	/// Keeps track of if a xeno has evolved recently, if so then we prevent them from evolving until that time is up
	var/has_evolved_recently = FALSE
	/// How long xenos should be unable to evolve after recently evolving
	var/evolution_cooldown_time = 90 SECONDS
	/// Determines if a xeno is unable to use abilities
	var/unable_to_use_abilities = FALSE
	/// Pixel X shifting of the on fire overlay
	var/on_fire_pixel_x = 16
	/// Pixel Y shifting of the on fire overlay
	var/on_fire_pixel_y = 16
	/// visual-only sprite scale for this xeno
	var/sprite_scale = 0.9
	/// visual offset to re-center the sprite after scaling
	var/sprite_pixel_y_offset = -4

/mob/living/carbon/alien/adult/banda/Initialize(mapload)
	. = ..()

	update_xeno_sprite_scale()

	AddComponent(/datum/component/seethrough_mob, 100, 0.5 SECONDS, TRUE)

	addtimer(CALLBACK(src, PROC_REF(patch_seethrough_for_xeno)), 0)

	GRANT_ACTION(/datum/action/cooldown/alien/banda/sleepytime)
	if(next_evolution)
		GRANT_ACTION(/datum/action/cooldown/alien/banda/generic_evolve)

	pixel_x = -16

	ADD_TRAIT(src, TRAIT_XENO_HEAL_AURA, TRAIT_XENO_INNATE)
	ADD_TRAIT(src, TRAIT_SLEEPIMMUNE, TRAIT_XENO_INNATE)

/mob/living/carbon/alien/adult/banda/proc/patch_seethrough_for_xeno()
	var/datum/component/seethrough_mob/C = GetComponent(/datum/component/seethrough_mob)
	if(!C)
		return

	if(C.render_source_atom)
		C.render_source_atom.appearance_flags |= RESET_TRANSFORM

//Transform for better size select
/mob/living/carbon/alien/adult/banda/proc/update_xeno_sprite_scale()
	var/matrix/M = matrix()
	M.Scale(sprite_scale, sprite_scale)
	transform = M
	pixel_y = initial(pixel_y) + sprite_pixel_y_offset

/// Called when a larva or xeno evolves, adds a configurable timer on evolving again to the xeno
/mob/living/carbon/alien/adult/banda/proc/has_just_evolved()
	if(has_evolved_recently)
		return
	has_evolved_recently = TRUE
	addtimer(CALLBACK(src, PROC_REF(can_evolve_once_again)), evolution_cooldown_time)

/// Allows xenos to evolve again if they are currently unable to
/mob/living/carbon/alien/adult/banda/proc/can_evolve_once_again()
	if(!has_evolved_recently)
		return
	has_evolved_recently = FALSE

/datum/action/cooldown/alien/banda
	button_icon = 'modular_bandastation/xeno_rework/icons/xeno_actions.dmi'
	/// Some xeno abilities block other abilities from being used, this allows them to get around that in cases where it is needed
	var/can_be_used_always = FALSE

/datum/action/cooldown/alien/banda/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE

	if(can_be_used_always)
		return TRUE

	var/mob/living/carbon/alien/adult/banda/owner_alien = owner
	if(!istype(owner_alien) || owner_alien.unable_to_use_abilities)
		return FALSE

/datum/movespeed_modifier/alien_quick
	multiplicative_slowdown = -0.5

/datum/movespeed_modifier/alien_slow
	multiplicative_slowdown = 0.5

/datum/movespeed_modifier/alien_heavy
	multiplicative_slowdown = 1

/datum/movespeed_modifier/alien_big
	multiplicative_slowdown = 2

/mob/living/carbon/alien/adult/banda/update_held_items()
	..()
	remove_overlay(HANDS_LAYER)
	var/list/hands = list()

	var/obj/item/l_hand = get_item_for_held_index(1)
	if(l_hand)
		var/itm_state = l_hand.inhand_icon_state
		if(!itm_state)
			itm_state = l_hand.icon_state
		var/mutable_appearance/l_hand_item = mutable_appearance(istype(l_hand, /obj/item/xeno_fruit) ? l_hand.lefthand_file : alt_inhands_file, "[itm_state][caste]_l", -HANDS_LAYER)
		if(l_hand.blocks_emissive != EMISSIVE_BLOCK_NONE)
			l_hand_item.overlays += emissive_blocker(l_hand_item.icon, l_hand_item.icon_state, src, alpha = l_hand_item.alpha)
		hands += l_hand_item

	var/obj/item/r_hand = get_item_for_held_index(2)
	if(r_hand)
		var/itm_state = r_hand.inhand_icon_state
		if(!itm_state)
			itm_state = r_hand.icon_state
		var/mutable_appearance/r_hand_item = mutable_appearance(istype(r_hand, /obj/item/xeno_fruit) ? r_hand.righthand_file : alt_inhands_file, "[itm_state][caste]_r", -HANDS_LAYER)
		if(r_hand.blocks_emissive != EMISSIVE_BLOCK_NONE)
			r_hand_item.overlays += emissive_blocker(r_hand_item.icon, r_hand_item.icon_state, src, alpha = r_hand_item.alpha)
		hands += r_hand_item

	overlays_standing[HANDS_LAYER] = hands
	apply_overlay(HANDS_LAYER)

/mob/living/carbon/alien/adult/banda/update_worn_handcuffs()
	. = ..()
	remove_overlay(HANDCUFF_LAYER)
	if(!handcuffed)
		return
	var/cuff_state = isalienqueen(src) ? "aliencuff_q" : "aliencuff_p"
	var/mutable_appearance/cuffs = mutable_appearance('icons/mob/nonhuman-player/alienqueen.dmi', cuff_state, -HANDCUFF_LAYER)
	if(handcuffed.blocks_emissive != EMISSIVE_BLOCK_NONE)
		cuffs += emissive_blocker(cuffs.icon, cuffs.icon_state, src, alpha = handcuffed.alpha)
	overlays_standing[HANDCUFF_LAYER] = cuffs
	apply_overlay(HANDCUFF_LAYER)

/mob/living/carbon/proc/get_max_plasma()
	var/obj/item/organ/alien/plasmavessel/vessel = get_organ_by_type(/obj/item/organ/alien/plasmavessel)
	if(!vessel)
		return -1
	return vessel.max_plasma

/mob/living/carbon/alien/adult/banda/alien_evolve(mob/living/carbon/alien/new_xeno)
	if(istype(new_xeno, /mob/living/carbon/alien/adult/banda))
		var/mob/living/carbon/alien/adult/banda/new_adult = new_xeno
		new_adult.has_just_evolved()
	return ..()

/mob/living/carbon/alien/adult/banda/queen/findQueen()
	return
