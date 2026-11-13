/** Alien-owned resin construction selection. */
/mob/living/carbon/alien
	/// Structure chosen by the resin building action.
	var/obj/structure/selected_resin_structure = null

/mob/living/carbon/alien/adult/banda/queen/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/queen_walk, \
	possible_sounds = list(
		'modular_bandastation/xeno_rework/sound/alien_footstep_large1.ogg',
		'modular_bandastation/xeno_rework/sound/alien_footstep_large2.ogg',
		'modular_bandastation/xeno_rework/sound/alien_footstep_large3.ogg'
	), \
		sound_volume = 100, \
		sound_range = 7, \
		ignore_walls = TRUE, \
		sound_play_chance = 100)
