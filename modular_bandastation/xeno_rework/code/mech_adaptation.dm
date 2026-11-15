/** Temporary cooperative opening, attached only to a mech actually attacked with the adaptation. */
/datum/component/xeno_mech_rend
	/// Number of armor points ignored per helper after the first, with a hard cap.
	var/penetration_per_helper = 15
	/// Limits penetration independently of swarm size.
	var/maximum_penetration = 30
	/// Each participant must have rended recently and still be alive and adjacent.
	var/contribution_duration = 8 SECONDS
	/// Observer strings do not retain mobs; weakrefs are resolved at the moment of damage.
	var/list/contributors = list()
	/// Stoppable timeout owned by this component.
	var/expiry_timer

/datum/component/xeno_mech_rend/Initialize()
	if(!istype(parent, /obj/vehicle/sealed/mecha))
		return COMPONENT_INCOMPATIBLE

/datum/component/xeno_mech_rend/Destroy()
	deltimer(expiry_timer)
	var/obj/vehicle/sealed/mecha/mech = parent
	mech.remove_filter("xeno_mech_rend")
	contributors.Cut()
	return ..()

/datum/component/xeno_mech_rend/proc/contribute(mob/living/carbon/alien/adult/banda/xeno)
	var/obj/vehicle/sealed/mecha/mech = parent
	contributors[REF(xeno)] = list("ref" = WEAKREF(xeno), "expires" = world.time + contribution_duration)
	deltimer(expiry_timer)
	expiry_timer = addtimer(CALLBACK(src, PROC_REF(expire)), contribution_duration, TIMER_STOPPABLE)
	mech.add_filter("xeno_mech_rend", 2, drop_shadow_filter(size = 2, color = "#b8dc52"))
	to_chat(mech.occupants, span_userdanger("Ксеноморф разрывает бронесочленения! Совместные атаки пробивают броню. Отступите от роя!"))
	mech.visible_message(span_warning("Бронесочленения [mech] покрываются светящейся едкой смолой!"))

/datum/component/xeno_mech_rend/proc/expire()
	expiry_timer = null
	qdel(src)

/** Losing proximity, death and expiry all immediately remove a participant's contribution. */
/datum/component/xeno_mech_rend/proc/penetration()
	var/obj/vehicle/sealed/mecha/mech = parent
	var/helpers = 0
	for(var/id in contributors.Copy())
		var/list/contribution = contributors[id]
		var/datum/weakref/member_ref = contribution["ref"]
		var/mob/living/carbon/alien/adult/banda/member = member_ref.resolve()
		if(QDELETED(member) || member.stat == DEAD || member.incapacitated || !member.Adjacent(mech) || world.time >= contribution["expires"])
			contributors -= id
			continue
		helpers++
	return clamp((helpers - 1) * penetration_per_helper, 0, maximum_penetration)

/** Shared by native claw attacks and the bought action; affects only reworked adults on mechs. */
/obj/vehicle/sealed/mecha/proc/xeno_rend_penetration(mob/living/user)
	if(!istype(user, /mob/living/carbon/alien/adult/banda) || !GLOB.xeno_hive?.purchased["mech"])
		return 0
	var/datum/component/xeno_mech_rend/rend = GetComponent(/datum/component/xeno_mech_rend)
	return rend?.penetration() || 0

/datum/action/cooldown/alien/banda/mech_rend
	name = "Разрыв бронесочленений"
	desc = "Две секунды у соседнего меха. В течение восьми секунд разные взрослые ксеноморфы совместно пробивают до 30 пунктов брони. Пилот сохраняет управление и может отступить."
	button_icon_state = "evolution"
	plasma_cost = 30
	cooldown_time = 12 SECONDS
	click_to_activate = TRUE
	/// Preparation requires adjacency throughout and revalidation at impact.
	var/rend_time = 2 SECONDS
	/// Ordinary armor-checked damage, not structural damage multiplication.
	var/rend_damage = 15

/datum/action/cooldown/alien/banda/mech_rend/proc/can_rend(obj/vehicle/sealed/mecha/mech)
	return !QDELETED(src) && !QDELETED(owner) && istype(mech) && !QDELETED(mech) && IsAvailable() && GLOB.xeno_hive?.purchased["mech"] && isturf(owner.loc) && owner.Adjacent(mech) && !HAS_TRAIT(owner, TRAIT_PACIFISM)

/datum/action/cooldown/alien/banda/mech_rend/Activate(atom/target)
	var/obj/vehicle/sealed/mecha/mech = target
	if(!can_rend(mech))
		return FALSE
	owner.visible_message(span_warning("[owner] готовится разорвать бронесочленения [mech]!"))
	if(!do_after(owner, rend_time, target = mech, extra_checks = CALLBACK(src, PROC_REF(can_rend), mech)) || !can_rend(mech))
		return FALSE
	var/datum/component/xeno_mech_rend/rend = mech.LoadComponent(/datum/component/xeno_mech_rend)
	rend.contribute(owner)
	owner.do_attack_animation(mech)
	mech.attack_generic(owner, rend_damage, BRUTE, MELEE, TRUE, rend.penetration())
	StartCooldown()
	return TRUE
