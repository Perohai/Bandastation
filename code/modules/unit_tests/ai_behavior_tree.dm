#define TEST_BB_BT_GATE "unit_test_bt_gate"

/datum/bt_node/ai_behavior/unit_test_abort_probe
	/// Number of times this leaf performed an action.
	var/perform_count = 0
	/// Number of times this leaf was finished or cancelled.
	var/finish_count = 0

/datum/bt_node/ai_behavior/unit_test_abort_probe/perform(seconds_per_tick, datum/ai_controller/controller)
	perform_count++
	return AI_BEHAVIOR_INSTANT

/datum/bt_node/ai_behavior/unit_test_abort_probe/finish_action(datum/ai_controller/controller, succeeded)
	finish_count++
	return ..()

/datum/bt_node/ai_behavior/unit_test_abort_probe/close_gate_on_setup/setup(datum/ai_controller/controller)
	controller.clear_blackboard_key(TEST_BB_BT_GATE)
	return TRUE

/datum/bt_node/ai_behavior/unit_test_abort_probe/open_gate_on_perform/perform(seconds_per_tick, datum/ai_controller/controller)
	..()
	controller.set_blackboard_key(TEST_BB_BT_GATE, TRUE)
	return AI_BEHAVIOR_SUCCEEDED

/// An abort-self observer must see the leaf that is being set up for the first time.
/datum/unit_test/ai_behavior_tree_abort_setup/Run()
	var/obj/item/pawn = allocate(/obj/item, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = allocate(/datum/ai_controller, pawn)
	controller.force_ai_off()
	controller.set_blackboard_key(TEST_BB_BT_GATE, TRUE)
	controller.replace_behavior_nodes(list(list(
		BT_DESC_TYPE = /datum/bt_node/decorator/bb_key_set,
		"key" = TEST_BB_BT_GATE,
		"observer_abort" = BT_ABORT_SELF,
		"child_typepath" = /datum/bt_node/ai_behavior/unit_test_abort_probe/close_gate_on_setup,
	)))
	var/datum/bt_node/decorator/bb_key_set/gate = controller.behavior_nodes[1]
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/probe = gate.child

	controller.SelectBehaviors(1)

	TEST_ASSERT_NULL(controller.blackboard[TEST_BB_BT_GATE], "Leaf setup did not close the gate")
	TEST_ASSERT_EQUAL(probe.perform_count, 0, "Leaf performed after its setup invalidated its branch")
	TEST_ASSERT_EQUAL(probe.finish_count, 1, "Cancelled setup did not clean up its leaf exactly once")
	TEST_ASSERT(!probe.has_active_descendants(), "Leaf remained active after its branch was cancelled")

/// A signal from a lower-priority leaf must terminate the tick even if the leaf returns success.
/datum/unit_test/ai_behavior_tree_abort_lower_priority/Run()
	var/obj/item/pawn = allocate(/obj/item, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = allocate(/datum/ai_controller, pawn)
	controller.force_ai_off()
	controller.replace_behavior_nodes(list(
		list(
			BT_DESC_TYPE = /datum/bt_node/composite/parallel,
			BT_DESC_CHILDREN = list(
				// This running branch sets the previous active index before the selector can tick.
				list(BT_DESC_TYPE = /datum/bt_node/ai_behavior/unit_test_abort_probe),
				list(
					BT_DESC_TYPE = /datum/bt_node/composite/selector,
					BT_DESC_CHILDREN = list(
						list(
							BT_DESC_TYPE = /datum/bt_node/decorator/bb_key_set,
							"key" = TEST_BB_BT_GATE,
							"observer_abort" = BT_ABORT_LOWER_PRIORITY,
							"child_typepath" = /datum/bt_node/ai_behavior/unit_test_abort_probe,
						),
						list(BT_DESC_TYPE = /datum/bt_node/ai_behavior/unit_test_abort_probe/open_gate_on_perform),
					),
				),
			),
		),
		/datum/bt_node/ai_behavior/unit_test_abort_probe,
	))
	var/datum/bt_node/composite/parallel/parallel = controller.behavior_nodes[1]
	var/datum/bt_node/composite/selector/selector = parallel.children[2]
	var/datum/bt_node/decorator/bb_key_set/gate = selector.children[1]
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/high_priority = gate.child
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/low_priority = selector.children[2]
	var/datum/bt_node/ai_behavior/unit_test_abort_probe/next_root = controller.behavior_nodes[2]

	controller.SelectBehaviors(1)

	TEST_ASSERT_EQUAL(low_priority.perform_count, 1, "Lower-priority leaf did not open the gate")
	TEST_ASSERT(controller.cancelled_during_tick, "Observer missed the new priority while another branch was active")
	TEST_ASSERT_EQUAL(low_priority.finish_count, 1, "Cancelled leaf finished more than once")
	TEST_ASSERT_EQUAL(next_root.perform_count, 0, "Controller ticked another root after the abort")
	TEST_ASSERT_EQUAL(high_priority.perform_count, 0, "Controller immediately restarted the tree during the aborted tick")

	controller.SelectBehaviors(1)

	TEST_ASSERT_EQUAL(high_priority.perform_count, 1, "Controller did not switch to the opened branch on the next tick")
	TEST_ASSERT_EQUAL(low_priority.perform_count, 1, "Controller resumed the cancelled branch instead of switching priority")

/// An uncommanded rat must reach its own combat targeting behavior.
/datum/unit_test/ai_behavior_tree_rat_combat/Run()
	var/mob/living/basic/mouse/rat/rat = allocate(/mob/living/basic/mouse/rat, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, NORTH))
	var/datum/ai_controller/controller = rat.ai_controller
	controller.force_ai_off()

	controller.SelectBehaviors(0)

	TEST_ASSERT_EQUAL(controller.blackboard[BB_CURRENT_TARGET], target, "Rat did not acquire the visible hostile target on its own")

/// The idle pickup branch should be available only to untamed monkeys.
/datum/unit_test/ai_behavior_tree_monkey_idle_pickup/Run()
	var/mob/living/carbon/human/species/monkey/monkey = allocate(/mob/living/carbon/human/species/monkey, run_loc_floor_bottom_left)
	var/obj/item/weapon = allocate(/obj/item/crowbar, run_loc_floor_top_right)
	var/datum/ai_controller/controller = monkey.ai_controller
	controller.force_ai_off()
	controller.replace_behavior_nodes(list(/datum/bt_node/subtree/monkey_shenanigans))
	controller.set_blackboard_key(BB_MONKEY_PICKUPTARGET, weapon)

	controller.SelectBehaviors(0)

	TEST_ASSERT_EQUAL(controller.ai_movement.moving_controllers[controller], weapon, "Untamed monkey did not approach the item it found")
	controller.cancel_current_plan()
	controller.set_blackboard_key(BB_MONKEY_TAMED, TRUE)
	controller.set_blackboard_key(BB_MONKEY_PICKUPTARGET, weapon)

	controller.SelectBehaviors(0)

	TEST_ASSERT(!controller.ai_movement.moving_controllers[controller], "Tamed monkey pursued a weapon while idle")

#undef TEST_BB_BT_GATE
