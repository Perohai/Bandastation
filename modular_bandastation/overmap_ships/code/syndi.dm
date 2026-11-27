/** The main passage and powered compartments of the Syndicate assault shuttle. */
/area/shuttle/stationtrauma_space/syndi
	name = "Шершень: центральный коридор"
	icon = 'modular_bandastation/space_overmap/icons/nt_patrol_areas.dmi'
	icon_state = "passage"
	requires_power = TRUE

/area/shuttle/stationtrauma_space/syndi/bridge
	name = "Шершень: рубка"
	icon_state = "bridge"

/area/shuttle/stationtrauma_space/syndi/medical
	name = "Шершень: медотсек"
	icon_state = "medbay"

/area/shuttle/stationtrauma_space/syndi/crew
	name = "Шершень: жилой отсек"
	icon_state = "barracks"

/area/shuttle/stationtrauma_space/syndi/armory
	name = "Шершень: оружейная"
	icon_state = "armory"

/area/shuttle/stationtrauma_space/syndi/engineering
	name = "Шершень: машинное отделение"
	icon_state = "engineering"

/area/shuttle/stationtrauma_space/syndi/engineering/reactor
	name = "Шершень: реакторная"
	icon_state = "reactor"

/** Exposed hull plating and equipment travel with the pressurized compartments. */
/area/shuttle/stationtrauma_space/syndi/exterior
	name = "Шершень: наружная обшивка"
	icon_state = "exterior"
	monitored_compartment = FALSE
	requires_power = FALSE
	vacuum_by_design = TRUE

/** Keep the shuttle's identity on its removable registration board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/syndi
	build_path = /obj/machinery/computer/stationtrauma_transponder/syndi
	callsign = "Шершень"
	registration_faction = "Синдикат"

/obj/machinery/computer/stationtrauma_transponder/syndi
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/syndi
