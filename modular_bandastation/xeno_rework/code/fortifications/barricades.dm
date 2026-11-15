/** A portable barrier retains its remaining integrity when folded and deployed. */
/obj/item/folding_barricade
	name = "folded field barricade"
	desc = "Складная полевая баррикада. Используйте в руке, чтобы установить перед собой; пустой рукой сложите установленную баррикаду."
	icon = 'modular_bandastation/xeno_rework/icons/fortifications/barricades.dmi'
	icon_state = "folding_3"
	w_class = WEIGHT_CLASS_BULKY
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4)
	/// Folding is transport, never free repair.
	var/stored_integrity = 180
	/// Serializes overlapping requests before do_after can yield.
	var/deploying = FALSE
	/// Shared by real use and focused interruption tests.
	var/deploy_time = 3 SECONDS

/** Revalidate physical ownership, floor and the selected border at the moment of deployment. */
/obj/item/folding_barricade/proc/can_deploy(mob/living/user, turf/location, direction)
	if(QDELETED(src) || QDELETED(user) || user.incapacitated || !ishuman(user) || !user.is_holding(src) || !isturf(user.loc) || !isfloorturf(location) || !user.Adjacent(location))
		return FALSE
	for(var/atom/movable/blocker in location)
		if(istype(blocker, /obj/structure/railing/folding))
			if(blocker.dir & direction)
				return FALSE
		else if(blocker.density && !(blocker.flags_1 & ON_BORDER_1))
			return FALSE
	return TRUE

/obj/item/folding_barricade/attack_self(mob/living/user)
	. = ..()
	if(deploying)
		return FALSE
	var/turf/location = get_step(user, user.dir)
	var/direction = user.dir
	if(!can_deploy(user, location, direction))
		return FALSE
	deploying = TRUE
	var/ready = do_after(user, deploy_time, target = location, extra_checks = CALLBACK(src, PROC_REF(can_deploy), user, location, direction))
	deploying = FALSE
	if(!ready || !can_deploy(user, location, direction))
		return FALSE
	var/obj/structure/railing/folding/barricade = new(location)
	barricade.setDir(direction)
	barricade.update_integrity(clamp(stored_integrity, 1, barricade.max_integrity))
	barricade.update_appearance()
	qdel(src)
	return TRUE

/** TG's railing supplies directional collision, projectiles passing overhead and climbing. */
/obj/structure/railing/folding
	name = "field barricade"
	desc = "Складная боевая баррикада. Останавливает движение через край клетки, но позволяет стрелять поверх и перелезать. Ремонтируется сваркой. Пустая рука — сложить."
	icon = 'modular_bandastation/xeno_rework/icons/fortifications/barricades.dmi'
	icon_state = "folding_0"
	max_integrity = 180
	armor_type = /datum/armor/folding_barricade
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4)
	/// Folding preserves integrity and does not produce raw materials.
	var/folding = FALSE
	/// Time spent dismantling into the portable form.
	var/fold_time = 3 SECONDS

/obj/structure/railing/folding/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_ATOM_INTEGRITY_CHANGED, PROC_REF(on_integrity_changed))

/obj/structure/railing/folding/proc/on_integrity_changed()
	SIGNAL_HANDLER
	update_appearance()

/datum/armor/folding_barricade
	melee = 20
	bullet = 30
	laser = 20
	energy = 20
	bomb = 20
	fire = 80
	acid = 30

/obj/structure/railing/folding/update_icon_state()
	. = ..()
	icon_state = "folding_[clamp(3 - CEILING(get_integrity() / max_integrity * 3, 1), 0, 2)]"

/obj/structure/railing/folding/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || folding || !can_fold(user))
		return
	folding = TRUE
	var/ready = do_after(user, fold_time, target = src, extra_checks = CALLBACK(src, PROC_REF(can_fold), user))
	folding = FALSE
	if(!ready || !can_fold(user))
		return
	var/obj/item/folding_barricade/folded = new(drop_location())
	folded.stored_integrity = get_integrity()
	qdel(src)
	user.put_in_hands(folded)
	return TRUE

/** Only a conscious adjacent human can pack a barrier; xenos still attack it normally. */
/obj/structure/railing/folding/proc/can_fold(mob/living/user)
	return !QDELETED(src) && !QDELETED(user) && ishuman(user) && !user.incapacitated && !user.combat_mode && user.Adjacent(src)

/obj/structure/railing/folding/welder_act(mob/living/user, obj/item/tool)
	if(user.combat_mode || get_integrity() >= max_integrity || !tool.tool_start_check(user, amount = 1))
		return ITEM_INTERACT_BLOCKING
	if(!tool.use_tool(src, user, 2.5 SECONDS, amount = 1, volume = 50))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || QDELETED(user) || QDELETED(tool) || user.incapacitated || !user.Adjacent(src) || !user.is_holding(tool))
		return ITEM_INTERACT_BLOCKING
	repair_damage(60)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/structure/railing/folding/wrench_act(mob/living/user, obj/item/tool)
	balloon_alert(user, "сначала сложите баррикаду")
	return ITEM_INTERACT_BLOCKING

/obj/structure/railing/folding/wirecutter_act(mob/living/user, obj/item/tool)
	balloon_alert(user, "сначала сложите баррикаду")
	return ITEM_INTERACT_BLOCKING

/obj/structure/railing/folding/atom_deconstruct(disassembled)
	return // The ruined barrier cannot yield both a portable barrier and raw materials.

/** The normal crafting system gates this recipe behind a learned instruction. */
/datum/crafting_recipe/folding_barricade
	name = "Складная полевая баррикада"
	result = /obj/item/folding_barricade
	reqs = list(/obj/item/stack/sheet/iron = 4)
	tool_behaviors = list(TOOL_WELDER, TOOL_WRENCH)
	time = 8 SECONDS
	category = CAT_FURNITURE
	crafting_flags = parent_type::crafting_flags | CRAFT_MUST_BE_LEARNED

/** Reusable field instruction, using the native book-granted recipe machinery. */
/obj/item/book/granter/crafting_recipe/folding_barricade
	name = "field barricade instruction"
	desc = "Листок с инструкцией по складным баррикадам. Прочтите, чтобы изучить рецепт: четыре листа стали, сварка и гаечный ключ."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper"
	pages_to_mastery = 1
	reading_time = 3 SECONDS
	uses = INFINITY
	crafting_recipe_types = list(/datum/crafting_recipe/folding_barricade)
	remarks = list("Четыре стальные пластины, шарнир, сварные швы и стопорный механизм.")

/** One shared initial stock per team; the reusable instruction permits later manufacture. */
/obj/structure/closet/crate/field_fortifications
	name = "field fortification supply crate"
	desc = "Общий запас отряда: 50 складных баррикад и инструкция по их изготовлению."
	storage_capacity = 51

/obj/structure/closet/crate/field_fortifications/PopulateContents()
	. = ..()
	for(var/index in 1 to 50)
		new /obj/item/folding_barricade(src)
	new /obj/item/book/granter/crafting_recipe/folding_barricade(src)
