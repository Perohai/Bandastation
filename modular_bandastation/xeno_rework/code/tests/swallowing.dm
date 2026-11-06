#define BANDA_ASSERT(condition, message) if(!(condition)) { return Fail(message, __FILE__, __LINE__) }
#define BANDA_EQUAL(actual, expected, message) if((actual) != (expected)) { return Fail(message, __FILE__, __LINE__) }

/datum/unit_test/banda_stomach_blindness_cleanup/Run()
	var/mob/living/carbon/alien/adult/banda/drone/host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/organ/stomach/alien_banda/stomach = host.get_organ_slot(ORGAN_SLOT_STOMACH)
	victim.become_blind("outside_test_source")
	BANDA_ASSERT(stomach.consume_thing(victim), "Module stomach refused a valid victim")
	var/datum/component/banda_swallowed/state = victim.GetComponent(/datum/component/banda_swallowed)
	BANDA_ASSERT(state, "Victim did not receive isolated custody state")
	var/source = state.blindness_source
	BANDA_ASSERT(victim.is_blind_from(source), "Stomach blindness was not applied")
	BANDA_ASSERT(stomach.release_victim(victim), "Release failed")
	BANDA_ASSERT(!victim.GetComponent(/datum/component/banda_swallowed), "Release retained custody interception")
	BANDA_ASSERT(!victim.is_blind_from(source), "Stomach blindness survived release")
	BANDA_ASSERT(victim.is_blind_from("outside_test_source"), "Release removed an unrelated blindness source")
	BANDA_EQUAL(get_turf(victim), get_turf(host), "Victim was not released onto the host turf")

/datum/unit_test/banda_stomach_continuous_escape/Run()
	var/mob/living/carbon/alien/adult/banda/sentinel/host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/mob/living/carbon/human/consistent/other = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, NORTH))
	var/obj/item/organ/stomach/alien_banda/stomach = host.get_organ_slot(ORGAN_SLOT_STOMACH)
	stomach.consume_thing(victim)
	stomach.consume_thing(other)
	var/datum/component/banda_swallowed/state = victim.GetComponent(/datum/component/banda_swallowed)
	BANDA_ASSERT(state.struggle(), "Initial struggle was rejected")
	BANDA_ASSERT(!state.struggle(), "Keyboard spam bypassed the per-victim cooldown")
	state.next_resist_time = world.time
	state.last_resist_time = world.time - stomach.resist_grace - 1
	state.resist_progress = 80 SECONDS
	state.struggle()
	BANDA_EQUAL(state.resist_progress, 0, "An idle pause did not reset continuous resistance")
	state.next_resist_time = world.time
	state.last_resist_time = world.time - stomach.resist_interval
	state.resist_progress = stomach.escape_time - stomach.resist_interval
	state.struggle()
	BANDA_EQUAL(get_turf(victim), get_turf(host), "A completed struggle did not release the victim")
	BANDA_EQUAL(other.loc, stomach, "One escape incorrectly released another victim")

/datum/unit_test/banda_stomach_weapons_and_fists/Run()
	var/mob/living/carbon/alien/adult/banda/ravager/host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/weapon = allocate(__IMPLIED_TYPE__)
	weapon.force = 20
	weapon.hitsound = null
	var/obj/item/organ/stomach/alien_banda/stomach = host.get_organ_slot(ORGAN_SLOT_STOMACH)
	stomach.consume_thing(victim)
	var/before = host.get_brute_loss()
	stomach.damage_from_inside(victim, weapon)
	BANDA_ASSERT(host.get_brute_loss() > before, "A silent weapon caused no resistance damage")
	before = host.get_brute_loss()
	stomach.damage_from_inside(victim, null)
	BANDA_ASSERT(host.get_brute_loss() > before, "Unarmed resistance caused no damage")
	BANDA_EQUAL(victim.loc, stomach, "A normal struggle unexpectedly released the victim")

/datum/unit_test/banda_stomach_death_and_removal/Run()
	var/mob/living/carbon/alien/adult/banda/drone/host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/mob/living/carbon/human/consistent/other = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, NORTH))
	var/obj/item/organ/stomach/alien_banda/stomach = host.get_organ_slot(ORGAN_SLOT_STOMACH)
	stomach.consume_thing(victim)
	victim.death()
	BANDA_ASSERT(!QDELETED(victim), "Death inside the module stomach deleted the corpse")
	BANDA_EQUAL(victim.loc, stomach, "Corpse was lost from the stomach")
	stomach.consume_thing(other)
	host.death()
	BANDA_ASSERT(!length(stomach.stomach_contents), "Host death did not release all contents")
	BANDA_ASSERT(!QDELETED(victim) && !QDELETED(other), "Host death deleted a prisoner")
	BANDA_EQUAL(get_turf(other), get_turf(host), "Living prisoner was not safely released")

/datum/unit_test/banda_stomach_organ_destroy/Run()
	var/mob/living/carbon/alien/adult/banda/drone/host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/organ/stomach/alien_banda/stomach = host.get_organ_slot(ORGAN_SLOT_STOMACH)
	stomach.consume_thing(victim)
	qdel(stomach)
	BANDA_ASSERT(!QDELETED(victim), "Deleting the stomach deleted a living prisoner")
	BANDA_EQUAL(get_turf(victim), get_turf(host), "Deleting the stomach did not safely release its prisoner")
	BANDA_ASSERT(!victim.GetComponent(/datum/component/banda_swallowed), "Organ deletion retained custody effects")

/datum/unit_test/banda_stomach_evolution/Run()
	var/mob/living/carbon/alien/adult/banda/drone/old_host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/organ/stomach/alien_banda/stomach = old_host.get_organ_slot(ORGAN_SLOT_STOMACH)
	stomach.consume_thing(victim)
	var/mob/living/carbon/alien/adult/banda/praetorian/new_host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	old_host.alien_evolve(new_host)
	BANDA_ASSERT(!QDELETED(victim), "Evolution deleted a swallowed prisoner")
	BANDA_EQUAL(get_turf(victim), get_turf(new_host), "Evolution failed to release the prisoner")
	BANDA_ASSERT(!victim.GetComponent(/datum/component/banda_swallowed), "Evolution retained custody effects")

/datum/unit_test/banda_larva_isolation/Run()
	var/mob/living/carbon/alien/larva/vanilla = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/alien/larva/banda/custom = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/vanilla_evolve = FALSE
	var/custom_evolve = FALSE
	for(var/datum/action/action in vanilla.actions)
		if(action.type == /datum/action/cooldown/alien/larva_evolve)
			vanilla_evolve = TRUE
		BANDA_ASSERT(!istype(action, /datum/action/cooldown/alien/larva_evolve/banda), "Vanilla larva received module evolution")
	for(var/datum/action/action in custom.actions)
		if(action.type == /datum/action/cooldown/alien/larva_evolve/banda)
			custom_evolve = TRUE
		BANDA_ASSERT(action.type != /datum/action/cooldown/alien/larva_evolve, "Module larva retained vanilla evolution")
	BANDA_ASSERT(vanilla_evolve && custom_evolve, "Larva actions were not isolated by subtype")
	var/datum/action/hide = locate(/datum/action/cooldown/alien/hide) in custom.actions
	BANDA_ASSERT(hide, "Replacing evolution removed the unrelated Hide action")

/datum/unit_test/banda_stomach_resist_action/Run()
	var/mob/living/carbon/alien/adult/banda/drone/host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/organ/stomach/alien_banda/stomach = host.get_organ_slot(ORGAN_SLOT_STOMACH)
	stomach.consume_thing(victim)
	var/datum/component/banda_swallowed/state = victim.GetComponent(/datum/component/banda_swallowed)
	var/before = host.get_brute_loss()
	victim.next_move = world.time
	victim.execute_resist()
	BANDA_EQUAL(state.last_resist_time, world.time, "The ordinary Resist action did not reach stomach resistance")
	BANDA_ASSERT(host.get_brute_loss() > before, "Resist key caused no struggle damage")
	before = host.get_brute_loss()
	stomach.container_resist_act(victim)
	BANDA_EQUAL(host.get_brute_loss(), before, "Mixing Resist inputs bypassed the shared cooldown")
	state.resist_progress = 40 SECONDS
	state.last_resist_time = world.time - stomach.resist_grace - 1
	state.process(0.2)
	BANDA_EQUAL(state.resist_progress, 0, "HUD tick retained stale idle progress until the next input")
	BANDA_EQUAL(state.progress_reset_at, world.time, "HUD received no feedback for an idle reset")
	stomach.release_victim(victim)
	before = host.get_brute_loss()
	victim.next_move = world.time
	victim.execute_resist()
	BANDA_EQUAL(host.get_brute_loss(), before, "Resist still hurt the former host after release")

/datum/unit_test/banda_stomach_escape_hud_cleanup/Run()
	var/mob/living/carbon/alien/adult/banda/drone/host = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/organ/stomach/alien_banda/stomach = host.get_organ_slot(ORGAN_SLOT_STOMACH)
	stomach.consume_thing(victim)
	var/datum/component/banda_swallowed/state = victim.GetComponent(/datum/component/banda_swallowed)
	state.create_hud()
	var/list/parts = state.escape_hud.Copy()
	BANDA_EQUAL(length(parts), 4, "Escape HUD did not create its panel, labels and bar")
	stomach.release_victim(victim)
	for(var/atom/movable/screen/part as anything in parts)
		BANDA_ASSERT(QDELETED(part), "Escape left a HUD screen object alive")

#undef BANDA_ASSERT
#undef BANDA_EQUAL
