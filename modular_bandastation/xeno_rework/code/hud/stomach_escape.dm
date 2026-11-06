/// Lower-centre overlay, deliberately independent of /datum/hud and blindness.
/atom/movable/screen/banda_stomach_escape
	name = "Сопротивляться и выбраться"
	desc = "Нажимать клавишу сопротивления, клавиши движения или эту панель."
	icon = 'modular_bandastation/xeno_rework/icons/stomach_escape.dmi'
	icon_state = "panel"
	screen_loc = "CENTER-6:16,SOUTH+3"
	plane = ABOVE_HUD_PLANE
	layer = 1
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	mouse_over_pointer = MOUSE_HAND_POINTER
	clear_with_screen = FALSE
	maptext_x = 20
	maptext_y = 106
	maptext_width = 344
	maptext_height = 30
	maptext = "<div align='center'><font face='Arial' size='3' color='#f4eee5'><b>БОРИСЬ ЗА ЖИЗНЬ</b></font></div>"

/atom/movable/screen/banda_stomach_escape/Click()
	var/datum/component/banda_swallowed/state = master_ref?.resolve()
	if(!state || usr != state.parent || !state.get_stomach())
		return
	var/mob/living/victim = usr
	victim.resist()

/// Transparent labels must not intercept the panel's clicks.
/atom/movable/screen/banda_stomach_escape/readout
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = 3
	maptext_y = 70
	maptext_height = 28
	maptext = null

/atom/movable/screen/banda_stomach_escape/instructions
	icon = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = 3
	maptext_y = 6
	maptext_height = 38
	maptext = null

/// A single white pixel, scaled with a fixed left edge instead of recreating icons.
/atom/movable/screen/banda_stomach_escape/fill
	icon_state = "pixel"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = 2
	pixel_x = 24
	pixel_y = 48
	maptext = null

/atom/movable/screen/banda_stomach_escape/fill/Initialize(mapload)
	. = ..()
	var/icon/pixel = icon(icon, icon_state)
	pixel.Crop(1, 1, 1, 1)
	icon = pixel

/atom/movable/screen/banda_stomach_escape/fill/proc/set_progress(fraction, fill_color)
	var/bar_width = max(1, round(336 * clamp(fraction, 0, 1)))
	var/matrix/bar_transform = matrix()
	bar_transform.Scale(bar_width, 8)
	bar_transform.Translate((bar_width - 1) / 2, 3.5)
	transform = bar_transform
	color = fill_color
	alpha = fraction > 0 ? 255 : 0

/datum/component/banda_swallowed/proc/create_hud()
	if(escape_hud)
		return
	var/atom/movable/screen/banda_stomach_escape/panel = new
	panel.master_ref = WEAKREF(src)
	escape_hud = list(panel, new /atom/movable/screen/banda_stomach_escape/readout, new /atom/movable/screen/banda_stomach_escape/instructions, new /atom/movable/screen/banda_stomach_escape/fill)

/datum/component/banda_swallowed/proc/on_login()
	SIGNAL_HANDLER
	hide_hud()
	var/mob/living/victim = parent
	if(!victim.client || !get_stomach())
		return
	create_hud()
	hud_client = victim.client
	hud_client.screen |= escape_hud
	START_PROCESSING(SSfastprocess, src)
	update_hud()

/datum/component/banda_swallowed/proc/on_logout()
	SIGNAL_HANDLER
	STOP_PROCESSING(SSfastprocess, src)
	hide_hud()

/datum/component/banda_swallowed/proc/hide_hud()
	if(hud_client)
		hud_client.screen -= escape_hud
	hud_client = null

/datum/component/banda_swallowed/process(seconds_per_tick)
	if(!get_stomach())
		qdel(src)
		return PROCESS_KILL
	reset_idle_progress()
	update_hud()

/// Reads current preferences, including an intentionally unbound Resist action.
/datum/component/banda_swallowed/proc/resist_prompt()
	var/mob/living/victim = parent
	var/list/keys = victim.client?.prefs?.key_bindings["resist"]
	if(!length(keys))
		return "Резист не назначен — нажимай на панель."
	return "Нажимай [html_encode(keys[1])] — сопротивляться."

/datum/component/banda_swallowed/proc/update_hud()
	if(!escape_hud || !hud_client)
		return
	var/obj/item/organ/stomach/alien_banda/stomach = get_stomach()
	if(!stomach)
		return
	var/mob/living/victim = parent
	var/fraction = clamp(resist_progress / max(stomach.escape_time, 1), 0, 1)
	var/seconds_done = round(resist_progress / (1 SECONDS), 0.1)
	var/seconds_total = stomach.stomach_escape_seconds()
	var/panel_state = "panel"
	var/fill_color = "#eee5d5"
	var/feedback = "Двигайся или нажимай на панель. Частить не нужно."
	if(victim.stat != BANDA_XENO_AWAKE_STAT || victim.incapacitated)
		feedback = "Сейчас сопротивляться невозможно."
		panel_state = "warning"
		fill_color = "#9c9690"
	else if(!isnull(last_resist_time) && world.time - last_resist_time > stomach.resist_grace - (1 SECONDS))
		feedback = "Продолжай! Пауза сбросит прогресс."
		panel_state = "warning"
		fill_color = "#edb45e"
	else if(!isnull(progress_reset_at) && world.time - progress_reset_at < 3 SECONDS)
		feedback = "Слишком долгая пауза — прогресс сброшен."
		panel_state = "warning"
	else if(!isnull(last_resist_time) && world.time - last_resist_time < 0.5 SECONDS)
		feedback = "Сопротивление засчитано! Продолжай."
		panel_state = "active"
		fill_color = "#d95b51"
	var/atom/movable/screen/banda_stomach_escape/panel = escape_hud[1]
	panel.icon_state = panel_state
	var/atom/movable/screen/banda_stomach_escape/readout/readout = escape_hud[2]
	readout.maptext = "<div align='center'><font face='Arial' size='2' color='#eee5d5'><b>ВЫХОД: [round(fraction * 100)]% · [seconds_done] / [seconds_total] с</b></font></div>"
	var/atom/movable/screen/banda_stomach_escape/instructions/instructions = escape_hud[3]
	instructions.maptext = "<div align='center'><font face='Arial' size='2' color='#ffffff'><b>[resist_prompt()]</b></font><br><font face='Arial' size='1' color='#c6bbb3'>[feedback]</font></div>"
	var/atom/movable/screen/banda_stomach_escape/fill/fill = escape_hud[4]
	fill.set_progress(fraction, fill_color)
