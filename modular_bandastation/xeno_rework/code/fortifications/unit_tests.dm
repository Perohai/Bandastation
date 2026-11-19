/datum/unit_test/xeno_rework_expansion_assets/Run()
	for(var/brood_type in typesof(/mob/living/carbon/alien/brood))
		var/mob/living/carbon/alien/brood/brood = allocate(brood_type)
		var/icon/frame = icon(brood.icon, brood.icon_state, SOUTH)
		TEST_ASSERT(frame.Width() == 32 && frame.Height() == 32, "Brood was not packed into a small 32px game tile")
		for(var/suffix in list("", "_sleep", "_dead"))
			TEST_ASSERT("[initial(brood.icon_state)][suffix]" in icon_states(brood.icon), "Missing brood posture: [brood_type][suffix]")
		brood.death()
		TEST_ASSERT_EQUAL(brood.icon_state, "[initial(brood.icon_state)]_dead", "A dead brood retained its live sprite")
		brood.revive(ADMIN_HEAL_ALL)
		TEST_ASSERT_EQUAL(brood.icon_state, initial(brood.icon_state), "Revived brood retained its dead sprite")

/datum/unit_test/xeno_rework_barricade_stock/Run()
	var/obj/structure/closet/crate/field_fortifications/crate = allocate(/obj/structure/closet/crate/field_fortifications)
	TEST_ASSERT(crate.open(), "Could not open the lazy-populated supply crate")
	TEST_ASSERT(crate.close(), "The complete initial stock did not fit back in its crate")
	var/count = 0
	for(var/obj/item/folding_barricade/barricade in crate)
		count++
	TEST_ASSERT_EQUAL(count, 25, "The shared stock does not contain exactly twenty-five folded barricades")
	TEST_ASSERT(locate(/obj/item/book/granter/crafting_recipe/folding_barricade) in crate, "The supply crate has no reusable instruction")

/datum/unit_test/xeno_rework_barricade_cycle
	normal_floor_required = TRUE

/datum/unit_test/xeno_rework_barricade_cycle/Run()
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent/slow)
	engineer.setDir(NORTH)
	var/obj/item/folding_barricade/portable = allocate(/obj/item/folding_barricade)
	portable.deploy_time = 0
	portable.stored_integrity = 70
	TEST_ASSERT(engineer.put_in_active_hand(portable), "The engineer could not hold a folded barricade")
	var/turf/destination = get_step(engineer, NORTH)
	TEST_ASSERT(portable.attack_self(engineer), "A valid barricade could not be deployed")
	var/obj/structure/railing/folding/barricade = locate() in destination
	TEST_ASSERT_NOTNULL(barricade, "Deployment created no physical barricade")
	TEST_ASSERT_EQUAL(barricade.get_integrity(), 70, "Deployment repaired a previously damaged barricade")
	TEST_ASSERT(!barricade.CanPass(engineer, NORTH), "The barricade did not block its facing border")
	TEST_ASSERT(barricade.CanPass(engineer, EAST), "The barricade blocked an unrelated border")
	var/obj/projectile/bullet/bullet = allocate(/obj/projectile/bullet)
	TEST_ASSERT(barricade.CanPass(bullet, NORTH), "The low barricade incorrectly blocked shots overhead")
	barricade.fold_time = 0
	barricade.attack_hand(engineer, list())
	var/obj/item/folding_barricade/folded = locate() in engineer.get_held_items()
	TEST_ASSERT_NOTNULL(folded, "Folding lost the physical portable barricade")
	TEST_ASSERT(QDELETED(barricade), "Folding left a duplicate structure behind")
	TEST_ASSERT_EQUAL(folded.stored_integrity, 70, "Folding gave free repair")
	folded.deploy_time = 2 SECONDS
	INVOKE_ASYNC(folded, TYPE_PROC_REF(/obj/item, attack_self), engineer)
	sleep(0.1 SECONDS)
	TEST_ASSERT(folded.deploying, "The interrupted deployment was never started")
	TEST_ASSERT(!folded.attack_self(engineer), "A parallel deployment bypassed the item lock")
	TEST_ASSERT(engineer.dropItemToGround(folded), "The interruption fixture did not drop the barricade")
	sleep(2.1 SECONDS)
	TEST_ASSERT(!QDELETED(folded) && !(locate(/obj/structure/railing/folding) in destination), "Lost ownership still completed deployment")

/datum/unit_test/xeno_rework_barricade_instruction/Run()
	var/mob/living/carbon/human/engineer = allocate(/mob/living/carbon/human/consistent)
	engineer.mind_initialize()
	var/datum/component/personal_crafting/crafting = engineer.GetComponent(/datum/component/personal_crafting)
	var/datum/crafting_recipe/recipe = GLOB.crafting_recipes_by_typepath[/datum/crafting_recipe/folding_barricade]
	TEST_ASSERT_NOTNULL(recipe, "The barricade recipe was not registered")
	TEST_ASSERT(!(recipe in crafting.get_visible_recipes(engineer)), "The undiscovered recipe is shown as a default")
	var/obj/item/stack/sheet/iron/steel = allocate(/obj/item/stack/sheet/iron, engineer.loc, 6)
	var/obj/item/stack/sheet/plasteel/plasteel = allocate(/obj/item/stack/sheet/plasteel, engineer.loc, 2)
	allocate(/obj/item/weldingtool, engineer.loc)
	allocate(/obj/item/wrench, engineer.loc)
	var/unknown_result = crafting.construct_item(engineer, recipe)
	TEST_ASSERT(!isatom(unknown_result), "The server allowed crafting a recipe that was not learned")
	TEST_ASSERT_EQUAL(steel.amount, 6, "An unlearned recipe consumed materials")
	var/obj/item/book/granter/crafting_recipe/folding_barricade/instruction = allocate(/obj/item/book/granter/crafting_recipe/folding_barricade)
	instruction.pages_to_mastery = 0
	instruction.reading_time = 0
	TEST_ASSERT(engineer.put_in_active_hand(instruction), "Could not hold the instruction")
	TEST_ASSERT(instruction.attack_self(engineer), "Reading the instruction failed")
	TEST_ASSERT(engineer.mind.has_crafting_recipe(recipe.type), "The instruction did not teach the recipe")
	TEST_ASSERT(recipe in crafting.get_visible_recipes(engineer), "The taught recipe is still absent from crafting")
	crafting.ignored_flags |= CRAFT_IGNORE_DO_AFTER
	var/result = crafting.construct_item(engineer, recipe)
	TEST_ASSERT(istype(result, /obj/item/folding_barricade), "Learned recipe did not produce a folded barricade: [result]")
	TEST_ASSERT(QDELETED(steel) && QDELETED(plasteel), "Successful crafting did not consume all materials")
