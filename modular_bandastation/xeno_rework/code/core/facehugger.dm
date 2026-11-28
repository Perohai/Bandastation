/obj/item/clothing/mask/facehugger/on_thrown(mob/living/carbon/user, atom/target)
	if(real && !sterile && facehugger_state != /obj/item/clothing/mask/facehugger/dead::facehugger_state)
		to_chat(user, span_warning("Только Носитель может метнуть живого лицехвата своей способностью."))
		return null
	return ..()
