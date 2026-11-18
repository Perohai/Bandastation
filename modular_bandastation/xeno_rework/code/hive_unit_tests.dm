/** Each economy test gets isolated round state, restored even after an assertion fails. */
/datum/unit_test/xeno_rework_hive
	abstract_type = /datum/unit_test/xeno_rework_hive
	/// Restored after teardown so these tests never leave round state in other tests.
	var/datum/xeno_hive/saved_hive
	/// Test-owned state, deleted after its allocated mobs have been destroyed.
	var/datum/xeno_hive/hive

/datum/unit_test/xeno_rework_hive/New()
	. = ..()
	saved_hive = GLOB.xeno_hive
	hive = new
	GLOB.xeno_hive = hive

/datum/unit_test/xeno_rework_hive/Destroy()
	. = ..()
	QDEL_NULL(hive)
	GLOB.xeno_hive = saved_hive
	saved_hive = null

/datum/unit_test/xeno_rework_hive/tree_tiers/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	hive.biomass = 10000
	hive.purchase_time = 0
	TEST_ASSERT_NULL(hive.upgrades["hunter"], "Ordinary Hunter still requires a hive purchase")
	TEST_ASSERT(!hive.can_buy(queen, "claws") && !hive.can_buy(queen, "crusher"), "A tree prerequisite was bypassed")
	var/list/unresolved = hive.upgrades.Copy()
	var/list/resolved = list()
	var/list/icons = list()
	for(var/id in hive.upgrades)
		var/datum/xeno_hive_upgrade/upgrade = hive.upgrades[id]
		TEST_ASSERT(length(upgrade.icon), "A tree node has no readable icon")
		TEST_ASSERT(!(upgrade.icon in icons), "Different unlocks share the same icon")
		icons += upgrade.icon
		TEST_ASSERT(upgrade.category in list("Эволюция", "Биоструктуры", "Популяция", "Выводок"), "Unknown category for [id]")
	while(length(unresolved))
		var/previous_length = length(unresolved)
		for(var/id in unresolved.Copy())
			var/datum/xeno_hive_upgrade/upgrade = unresolved[id]
			if(length(upgrade.requires - resolved))
				continue
			resolved += id
			unresolved -= id
		TEST_ASSERT(length(unresolved) < previous_length, "Missing or cyclic prerequisites: [unresolved.Join(", ")]")
	for(var/id in list("carapace", "claws", "tier3", "tier4"))
		TEST_ASSERT(hive.buy(queen, id), "A valid tier adaptation failed")
	TEST_ASSERT(hive.can_buy(queen, "crusher") && hive.can_buy(queen, "boiler"), "T3 adaptation did not open its specializations")
	for(var/caste_type in valid_subtypesof(/mob/living/carbon/alien/adult/banda))
		var/mob/living/carbon/alien/adult/banda/member = allocate(caste_type)
		var/expected_health = 0
		var/expected_claws = 0
		if(!istype(member, /mob/living/carbon/alien/adult/banda/queen))
			for(var/id in hive.purchased)
				var/datum/xeno_hive_upgrade/upgrade = hive.upgrades[id]
				if(upgrade.target_tier == member.evolution_tier)
					expected_health += upgrade.health_bonus
					expected_claws += upgrade.claw_bonus
		TEST_ASSERT_EQUAL(member.maxHealth, initial(member.maxHealth) + expected_health, "Wrong tier health on [caste_type]")
		TEST_ASSERT_EQUAL(member.melee_damage_upper, initial(member.melee_damage_upper) + expected_claws, "Wrong tier claw damage on [caste_type]")
		hive.apply_upgrades(member)
		TEST_ASSERT_EQUAL(member.maxHealth, initial(member.maxHealth) + expected_health, "Reapplying tier health stacked it")

/datum/unit_test/xeno_rework_hive/brood_support/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	var/mob/living/carbon/alien/brood/beetle = allocate(/mob/living/carbon/alien/brood)
	var/mob/living/carbon/alien/brood/mantis/mantis = allocate(/mob/living/carbon/alien/brood/mantis)
	var/mob/living/carbon/alien/brood/scorpion/scorpion = allocate(/mob/living/carbon/alien/brood/scorpion)
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/alien/brood_charge) in beetle.actions, "Basic beetle starts with its full ability")
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/alien/brood_ravage) in mantis.actions, "Basic mantis starts with its full ability")
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/alien/brood_spit) in scorpion.actions, "Basic scorpion has no weak spit")
	hive.purchase_time = 0
	hive.biomass = 5000
	for(var/id in list("construction", "brood_vigor", "brood_mantis", "brood_scorpion", "beetle_charge", "mantis_ravage", "scorpion_spit", "brood_baneling"))
		TEST_ASSERT(hive.buy(queen, id), "Minion tree purchase [id] failed")
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/alien/brood_charge) in beetle.actions, "Existing beetle missed its unlocked charge")
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/alien/brood_ravage) in mantis.actions, "Existing mantis missed its unlocked ravage")
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/alien/brood_spit) in scorpion.actions, "Existing scorpion missed its unlocked spit")
	var/mob/living/carbon/alien/brood/baneling/baneling = allocate(/mob/living/carbon/alien/brood/baneling)
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/alien/brood_detonate) in baneling.actions, "Future baneling missed its detonation")
	TEST_ASSERT(hive.brood_type_available(baneling.type), "Unlocked baneling is unavailable")
	hive.next_baneling_at = world.time + hive.baneling_interval
	TEST_ASSERT(!hive.brood_type_available(baneling.type), "A second observer can bypass the shared cooldown")
	TEST_ASSERT(!("Банелинг" in hive.brood_options()), "Cooling-down baneling remains in the choice list")
	hive.next_baneling_at = world.time
	TEST_ASSERT(hive.brood_type_available(baneling.type), "Baneling did not unlock at the cooldown boundary")
	TEST_ASSERT(!hive.brood_type_available(/mob/living/carbon/alien/adult/banda/queen), "Forged minion type was accepted")

/datum/unit_test/xeno_rework_hive/body_rewards/Run()
	var/mob/living/carbon/human/captured = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/xeno_biomass_body/body = get_xeno_biomass_body(captured)
	TEST_ASSERT_EQUAL(body.pay("infection"), 20, "Wrong infection reward")
	TEST_ASSERT_EQUAL(body.pay("infection"), 0, "Repeated infection paid again")
	TEST_ASSERT_EQUAL(body.pay("birth"), 30, "Wrong birth reward")
	captured.death()
	captured.revive(ADMIN_HEAL_ALL)
	TEST_ASSERT_EQUAL(get_xeno_biomass_body(captured), body, "Resurrection replaced body history")
	TEST_ASSERT_EQUAL(body.pay("birth"), 0, "Resurrected body paid for a second birth")
	TEST_ASSERT_EQUAL(body.pay("processing"), 50, "Processing did not pay the exact remainder")
	TEST_ASSERT_EQUAL(body.pay("processing"), 0, "A processed body paid twice")
	TEST_ASSERT_EQUAL(body.pay("infection"), 0, "Late infection bypassed the cap")
	TEST_ASSERT_EQUAL(hive.biomass, 100, "An infected body exceeded its lifetime budget")
	var/mob/living/carbon/human/corpse = allocate(/mob/living/carbon/human/consistent)
	corpse.death()
	var/datum/component/xeno_biomass_body/corpse_body = get_xeno_biomass_body(corpse)
	TEST_ASSERT_EQUAL(corpse_body.pay("processing"), body.paid, "An ordinary corpse has a different full reward")
	TEST_ASSERT_EQUAL(corpse_body.pay("infection"), 0, "Processing did not exhaust the body's budget")
	var/mob/living/carbon/human/monkey = allocate(/mob/living/carbon/human/consistent)
	monkey.set_species(/datum/species/monkey)
	var/datum/component/xeno_biomass_body/monkey_body = get_xeno_biomass_body(monkey)
	TEST_ASSERT_EQUAL(monkey_body.reward_limit, 20, "A round-created monkey got a human budget")
	monkey.humanize(instant = TRUE)
	TEST_ASSERT_EQUAL(get_xeno_biomass_body(monkey), monkey_body, "Humanization replaced the physical body's history")
	TEST_ASSERT_EQUAL(monkey_body.pay("processing"), 20, "Changing species increased a known body's budget")
	TEST_ASSERT_EQUAL(body.reward_limit, 100, "A second body's species change altered another budget")
	var/mob/living/carbon/alien/brood/brood = allocate(/mob/living/carbon/alien/brood)
	TEST_ASSERT_NULL(get_xeno_biomass_body(brood), "Weak brood can be farmed as a prey body")

/datum/unit_test/xeno_rework_hive/infection_surgery/Run()
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/body_egg/alien_embryo/embryo = allocate(/obj/item/organ/body_egg/alien_embryo, prey)
	TEST_ASSERT_EQUAL(hive.biomass, 20, "Native embryo insertion did not pay the infection stage")
	embryo.Remove(prey)
	TEST_ASSERT(!HAS_TRAIT(prey, TRAIT_XENO_HOST), "Surgical removal retained host traits")
	TEST_ASSERT_EQUAL(hive.biomass, 20, "Rescue refunded an earned reward")
	embryo.Insert(prey)
	TEST_ASSERT_EQUAL(hive.biomass, 20, "Reinserting the same embryo farmed biomass")
	embryo.Remove(prey)
	var/obj/item/organ/body_egg/alien_embryo/another = allocate(/obj/item/organ/body_egg/alien_embryo, prey)
	TEST_ASSERT_EQUAL(hive.biomass, 20, "A new embryo reset the existing body's reward history")
	another.Remove(prey)
	TEST_ASSERT(!QDELETED(prey) && prey.stat != DEAD, "Removing an embryo killed its host")

/datum/unit_test/xeno_rework_hive/cocoons/Run()
	var/mob/living/carbon/alien/adult/banda/drone/adult = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/bed/nest/banda/nest = allocate(/obj/structure/bed/nest/banda)
	hive.cocoon_time = 0
	TEST_ASSERT(nest.user_buckle_mob(prey, adult), "Adult failed to secure prey")
	var/obj/structure/xeno_cocoon/shell = nest.cocoon
	TEST_ASSERT_NOTNULL(shell, "Securing prey made no destructible cocoon")
	shell.process(300)
	TEST_ASSERT(!QDELETED(prey) && hive.biomass == 0, "Living prey was processed")
	prey.death()
	shell.process(100)
	nest.unbuckle_mob(prey)
	TEST_ASSERT(QDELETED(shell), "Rescuing prey retained its cocoon")
	TEST_ASSERT(!QDELETED(prey) && hive.biomass == 0, "Incomplete processing destroyed or paid for prey")
	TEST_ASSERT(nest.user_buckle_mob(prey, adult), "An ordinary corpse could not be secured again")
	shell = nest.cocoon
	TEST_ASSERT_EQUAL(shell.processed_time, 0, "Recocooning retained processing progress")
	shell.process(149)
	TEST_ASSERT(!QDELETED(prey), "A fresh cocoon reused the previous processing time")
	shell.process(1)
	TEST_ASSERT(shell.dissolving && !QDELETED(prey), "There was no rescuable dissolution animation")
	qdel(shell)
	TEST_ASSERT(!prey.buckled && !QDELETED(prey), "Destroying the cocoon failed to free its corpse")
	TEST_ASSERT_EQUAL(prey.alpha, 255, "Rescue left the body invisible")
	TEST_ASSERT(nest.user_buckle_mob(prey, adult), "Freed corpse could not be cocooned")
	nest.cocoon.process(150)
	nest.cocoon.process(2)
	TEST_ASSERT(QDELETED(prey), "Finished processing did not consume the body")
	TEST_ASSERT_EQUAL(hive.biomass, 100, "Finished ordinary corpse gave the wrong reward")

/datum/unit_test/xeno_rework_hive/stomach_death/Run()
	var/mob/living/carbon/alien/adult/banda/drone/adult = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/stomach/alien_banda/stomach = adult.get_organ_slot(ORGAN_SLOT_STOMACH)
	TEST_ASSERT(stomach.consume_thing(prey), "Failed to swallow prey")
	prey.death()
	TEST_ASSERT(!QDELETED(prey), "Death in transport deleted the body")
	TEST_ASSERT_EQUAL(hive.biomass, 0, "The stomach generated biomass")
	stomach.empty_contents()
	TEST_ASSERT(isturf(prey.loc) && !(prey in stomach.stomach_contents), "The transported corpse could not be regurgitated")

/datum/unit_test/xeno_rework_hive/passive_brood/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	allocate(/obj/structure/alien/weeds/node)
	var/obj/structure/xeno_hive_core/core = allocate(/obj/structure/xeno_hive_core)
	STOP_PROCESSING(SSobj, core)
	TEST_ASSERT_EQUAL(hive.brood_rate(10000), 60, "Passive generation has no rate ceiling")
	TEST_ASSERT_EQUAL(hive.brood_rate(0), 0, "An empty station generates passive brood")
	hive.advance_brood(60, 50)
	TEST_ASSERT_EQUAL(hive.brood_points, 50, "Passive income did not scale with population and seconds")
	hive.advance_brood(60, 50)
	TEST_ASSERT_EQUAL(core.available_brood(), 1, "Enough points did not produce one persistent role")
	TEST_ASSERT_EQUAL(hive.biomass, 0, "Passive brood generated biomass")
	var/obj/structure/xeno_hive_egg/clutch = core.brood_eggs[1]
	qdel(clutch)
	TEST_ASSERT_EQUAL(length(core.brood_eggs), 0, "Egg destruction retained the core's reference")
	hive.advance_brood(600, 60)
	TEST_ASSERT_EQUAL(core.available_brood(), 6, "The clutch silently capped unclaimed places")
	hive.brood_points = 20
	queen.death()
	hive.advance_brood(60, 60)
	TEST_ASSERT_EQUAL(hive.brood_points, 20, "Brood accumulated without a living queen")
	TEST_ASSERT_EQUAL(core.available_brood(), 6, "Queen death destroyed stored brood")
	qdel(core)
	TEST_ASSERT_NULL(hive.core, "Core destruction retained the active core")
	TEST_ASSERT_EQUAL(hive.brood_points, 0, "Core destruction retained fractional brood points")
	TEST_ASSERT(QDELETED(clutch), "Destroyed clutch remained usable")

/datum/unit_test/xeno_rework_hive/purchases/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	var/mob/living/carbon/alien/adult/banda/runner/runner = allocate(/mob/living/carbon/alien/adult/banda/runner)
	hive.biomass = 1000
	hive.purchase_time = 0.5 SECONDS
	INVOKE_ASYNC(hive, TYPE_PROC_REF(/datum/xeno_hive, buy), queen, "carapace")
	sleep(0.1 SECONDS)
	TEST_ASSERT(hive.purchase_busy, "Purchase did not enter its interruptible channel")
	TEST_ASSERT(!hive.buy(queen, "claws"), "A parallel purchase bypassed the shared lock")
	queen.adjust_brute_loss(1)
	queen.adjust_brute_loss(-1)
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(hive.biomass, 1000, "Interrupted purchase spent biomass")
	TEST_ASSERT(!hive.purchased["carapace"], "Damage followed by healing did not interrupt the purchase")
	TEST_ASSERT_NULL(queen.get_filter("hive_purchase"), "Cancelled purchase left its visual behind")
	TEST_ASSERT(hive.buy(queen, "carapace"), "A valid purchase failed")
	TEST_ASSERT_EQUAL(hive.biomass, 850, "A successful purchase charged incorrectly")
	TEST_ASSERT_EQUAL(runner.maxHealth, initial(runner.maxHealth) + 15, "Existing member missed the upgrade")
	hive.apply_upgrades(runner)
	TEST_ASSERT_EQUAL(runner.maxHealth, initial(runner.maxHealth) + 15, "Reapplying an upgrade stacked it")
	var/mob/living/carbon/alien/adult/banda/runner/newborn = allocate(/mob/living/carbon/alien/adult/banda/runner)
	TEST_ASSERT_EQUAL(newborn.maxHealth, runner.maxHealth, "A future member missed the upgrade")
	TEST_ASSERT(!hive.buy(queen, "carapace"), "An irreversible single-level upgrade was bought twice")
	TEST_ASSERT(!hive.can_buy(runner, "claws"), "A non-queen may buy upgrades")
	TEST_ASSERT(!hive.can_buy(queen, "bogus"), "Unknown upgrade accepted")
	INVOKE_ASYNC(hive, TYPE_PROC_REF(/datum/xeno_hive, buy), queen, "claws")
	sleep(0.1 SECONDS)
	queen.forceMove(get_step(queen, NORTH))
	sleep(0.6 SECONDS)
	TEST_ASSERT(!hive.purchased["claws"] && hive.biomass == 850, "Movement did not interrupt the purchase")
	queen.death()
	TEST_ASSERT_EQUAL(hive.biomass, 425, "Queen death did not remove exactly half the biomass")
	TEST_ASSERT(hive.purchased["carapace"], "Queen death erased purchased upgrades")
	TEST_ASSERT(!hive.can_buy(queen, "claws"), "A dead queen could buy an upgrade")
	qdel(queen)
	var/mob/living/carbon/alien/adult/banda/queen/replacement = allocate(/mob/living/carbon/alien/adult/banda/queen)
	TEST_ASSERT(hive.can_buy(replacement, "claws"), "A replacement queen did not inherit hive management")
	TEST_ASSERT_EQUAL(replacement.maxHealth, initial(replacement.maxHealth), "A T1 adaptation incorrectly affected the queen")

/datum/unit_test/xeno_rework_hive/specializations/Run()
	var/mob/living/carbon/alien/adult/banda/runner/runner = allocate(/mob/living/carbon/alien/adult/banda/runner)
	var/hunter_type = /mob/living/carbon/alien/adult/banda/final_caste/hunter
	var/ravager_type = /mob/living/carbon/alien/adult/banda/ravager
	TEST_ASSERT(runner.can_evolve(hunter_type), "Ordinary Hunter is locked")
	TEST_ASSERT(!runner.can_evolve(ravager_type), "Unpurchased Ravager was available")
	var/mob/living/carbon/alien/adult/banda/hunter = allocate(hunter_type)
	TEST_ASSERT(!runner.can_evolve(hunter_type), "A living Hunter did not reserve its separate slot")
	hive.purchased["ravager"] = 1
	TEST_ASSERT(runner.can_evolve(ravager_type) && !runner.can_evolve(hunter_type), "Ravager unlock bypassed the occupied Hunter slot")
	hunter.death()
	TEST_ASSERT(runner.can_evolve(hunter_type), "A dead Hunter did not release its slot")
	allocate(ravager_type)
	TEST_ASSERT(!runner.can_evolve(ravager_type) && runner.can_evolve(hunter_type), "Occupied Ravager slot blocked ordinary Hunter")
	var/mob/living/carbon/alien/adult/banda/defender/defender = allocate(/mob/living/carbon/alien/adult/banda/defender)
	allocate(/mob/living/carbon/alien/adult/banda/warrior)
	TEST_ASSERT(!defender.can_evolve(), "A Warrior did not occupy the Warrior slot")
	hive.purchased["warrior_slot"] = 1
	TEST_ASSERT(defender.can_evolve(), "A bought Warrior slot had no effect")
	TEST_ASSERT(!defender.can_evolve(/mob/living/carbon/alien/adult/banda/queen), "A forged evolution bypassed the caste allowlist")
	TEST_ASSERT_EQUAL(hive.slot_limit(ravager_type), 1, "Ordinary slots expanded Ravager availability")
	TEST_ASSERT_NULL(hive.upgrades["ravager_slot"], "T4 Ravager retained cheap additional slots")

/datum/unit_test/xeno_rework_hive/weak_brood/Run()
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent)
	for(var/brood_type in typesof(/mob/living/carbon/alien/brood))
		var/mob/living/carbon/alien/brood/brood = allocate(brood_type)
		TEST_ASSERT(!is_type_in_typecache(brood, typecacheof(list(/mob/living/carbon/alien/adult, /mob/living/carbon/alien/larva))), "Weak brood counts as an adult or full larva")
		TEST_ASSERT(!(locate(/datum/action/cooldown/alien/larva_evolve) in brood.actions), "Weak brood has free evolution")
		TEST_ASSERT_NOTNULL(brood.get_organ_slot(ORGAN_SLOT_XENO_HIVENODE), "Weak brood cannot communicate with its hive")
		TEST_ASSERT_NULL(brood.get_organ_slot(ORGAN_SLOT_STOMACH), "Weak brood can swallow prey")
		TEST_ASSERT(brood.start_pulling(prey), "[brood_type] cannot help carry prey")
		brood.stop_pulling()
		hive.purchased["brood_vigor"] = 1
		brood.apply_hive_upgrade()
		brood.apply_hive_upgrade()
		TEST_ASSERT_EQUAL(brood.maxHealth, initial(brood.maxHealth) + 15, "Brood upgrades stack or miss future brood")

/datum/unit_test/xeno_rework_hive/larval_eggs/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	hive.purchase_time = 0
	hive.biomass = 400
	TEST_ASSERT(!hive.buy(queen, "larva"), "Larval egg purchase succeeded without a core")
	allocate(/obj/structure/alien/weeds/node)
	var/obj/structure/xeno_hive_core/core = allocate(/obj/structure/xeno_hive_core)
	STOP_PROCESSING(SSobj, core)
	hive.brood_points = 75
	TEST_ASSERT(hive.buy(queen, "larva"), "A full larval egg could not be bought")
	TEST_ASSERT_EQUAL(hive.biomass, 0, "Full larva did not cost four complete human bodies")
	TEST_ASSERT_EQUAL(hive.brood_points, 75, "Buying a larva spent the passive currency")
	var/obj/structure/xeno_hive_egg/larva/egg = locate() in range(2, core)
	TEST_ASSERT_NOTNULL(egg, "Purchase created no physical egg")
	TEST_ASSERT_EQUAL(egg.spawner.mob_type, /mob/living/carbon/alien/larva, "Paid egg creates weak brood instead of a full larva")
	TEST_ASSERT_EQUAL(egg.spawner.uses, 1, "A single purchase created multiple larval places")
	qdel(core)
	TEST_ASSERT(!QDELETED(egg) && !QDELETED(egg.spawner), "Core loss destroyed an independent purchased egg")
	var/obj/effect/mob_spawn/ghost_role/xeno_hive/spawner = egg.spawner
	qdel(egg)
	TEST_ASSERT(QDELETED(spawner), "Destroyed egg left a ghost-role entry alive")
	TEST_ASSERT_EQUAL(hive.biomass, 0, "Destroying an egg refunded biomass")

/datum/unit_test/xeno_rework_hive/revalidation/Run()
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	hive.purchased["carapace"] = 1
	hive.biomass = 1000
	hive.purchase_time = 0.5 SECONDS
	INVOKE_ASYNC(hive, TYPE_PROC_REF(/datum/xeno_hive, buy), queen, "claws")
	sleep(0.1 SECONDS)
	hive.biomass = 0
	sleep(0.6 SECONDS)
	TEST_ASSERT(!hive.purchased["claws"] && hive.biomass == 0, "Purchase bypassed resource revalidation")
	hive.biomass = 1000
	hive.purchased -= "carapace"
	INVOKE_ASYNC(hive, TYPE_PROC_REF(/datum/xeno_hive, buy), queen, "carapace")
	sleep(0.1 SECONDS)
	queen.Unconscious(1 SECONDS)
	sleep(1.1 SECONDS)
	TEST_ASSERT(!hive.purchased["carapace"] && hive.biomass == 1000, "Purchase survived loss of consciousness")
	hive.purchased["warrior_slot"] = 3
	TEST_ASSERT(!hive.can_buy(queen, "warrior_slot"), "A fourth additional Warrior slot bypassed the limit")
	var/datum/xeno_hive_upgrade/slot = hive.upgrades["warrior_slot"]
	TEST_ASSERT_EQUAL(slot.price(1), 360, "Repeatable slot price did not scale")

/datum/unit_test/xeno_rework_hive/core_movement/Run()
	allocate(/mob/living/carbon/alien/adult/banda/queen)
	allocate(/obj/structure/alien/weeds/node)
	var/obj/structure/xeno_hive_core/core = allocate(/obj/structure/xeno_hive_core)
	STOP_PROCESSING(SSobj, core)
	hive.advance_brood(120, 60)
	var/obj/structure/xeno_hive_egg/clutch = core.brood_eggs[1]
	var/obj/effect/mob_spawn/ghost_role/xeno_hive/spawner = clutch.spawner
	core.forceMove(get_step(core, NORTH))
	TEST_ASSERT(QDELETED(core) && QDELETED(clutch) && QDELETED(spawner), "Moving a core retained unused brood")
	TEST_ASSERT_NULL(hive.core, "A moved core remained installed")
	TEST_ASSERT_EQUAL(hive.brood_points, 0, "Moving the core preserved fractional progress")
	hive.advance_brood(60, 60)
	TEST_ASSERT_EQUAL(hive.brood_points, 0, "Brood accumulated after the core was lost")

/datum/unit_test/xeno_rework_hive/no_queen_emp/Run()
	TEST_ASSERT_NULL(hive.upgrades["mech"], "Removed EMP remains purchasable")
	var/mob/living/carbon/alien/adult/banda/queen/queen = allocate(/mob/living/carbon/alien/adult/banda/queen)
	for(var/datum/action/action as anything in queen.actions)
		TEST_ASSERT(!findtext("[action.type]", "queen_emp"), "Queen retained the removed EMP")

/datum/unit_test/xeno_rework_hive/cocoon_interruption/Run()
	var/mob/living/carbon/alien/adult/banda/drone/adult = allocate(/mob/living/carbon/alien/adult/banda/drone)
	var/mob/living/carbon/human/prey = allocate(/mob/living/carbon/human/consistent)
	var/obj/structure/bed/nest/banda/nest = allocate(/obj/structure/bed/nest/banda)
	hive.cocoon_time = 0.3 SECONDS
	INVOKE_ASYNC(nest, TYPE_PROC_REF(/atom/movable, user_buckle_mob), prey, adult)
	sleep(0.1 SECONDS)
	TEST_ASSERT(!nest.user_buckle_mob(prey, adult), "Parallel cocoon preparations were accepted")
	prey.forceMove(get_step(prey, NORTH))
	sleep(0.4 SECONDS)
	TEST_ASSERT(!prey.buckled && !nest.cocoon && !nest.preparing, "Moved prey was secured after the preparation")
	prey.forceMove(adult.loc)
	INVOKE_ASYNC(nest, TYPE_PROC_REF(/atom/movable, user_buckle_mob), prey, adult)
	sleep(0.1 SECONDS)
	qdel(nest)
	sleep(0.4 SECONDS)
	TEST_ASSERT(!prey.buckled && !QDELETED(prey), "A destroyed nest completed its pending cocoon")
