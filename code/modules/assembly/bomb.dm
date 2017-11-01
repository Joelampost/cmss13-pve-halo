/obj/item/explosive/onetankbomb
	name = "bomb"
	icon = 'icons/obj/items/tank.dmi'
	item_state = "assembly"
	throwforce = 5
	w_class = 3.0
	throw_speed = 2
	throw_range = 4
	flags_atom = FPRINT|CONDUCT
	var/status = 0   //0 - not readied //1 - bomb finished with welder
	var/obj/item/device/assembly_holder/bombassembly = null   //The first part of the bomb is an assembly holder, holding an igniter+some device
	var/obj/item/tank/bombtank = null //the second part of the bomb is a phoron tank

/obj/item/explosive/onetankbomb/Dispose()
	if(bombassembly)
		cdel(bombassembly)
		bombassembly = null
	if(bombtank)
		cdel(bombtank)
		bombtank = null
	. = ..()

/obj/item/explosive/onetankbomb/examine(mob/user)
	..()
	bombtank.examine(user)

/obj/item/explosive/onetankbomb/update_icon()
	if(bombtank)
		icon_state = bombtank.icon_state
	if(bombassembly)
		overlays += bombassembly.icon_state
		overlays += bombassembly.overlays
		overlays += "bomb_assembly"

/obj/item/explosive/onetankbomb/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W, /obj/item/device/analyzer))
		bombtank.attackby(W, user)
		return
	if(istype(W, /obj/item/tool/wrench) && !status)	//This is basically bomb assembly code inverted. apparently it works.

		user << "<span class='notice'>You disassemble [src].</span>"

		bombassembly.loc = user.loc
		bombassembly.master = null
		bombassembly = null

		bombtank.loc = user.loc
		bombtank.master = null
		bombtank = null

		cdel(src)
		return
	if((istype(W, /obj/item/tool/weldingtool) && W:welding))
		if(!status)
			status = 1
			bombers += "[key_name(user)] welded a single tank bomb. Temp: [bombtank.air_contents.temperature-T0C]"
			message_admins("[key_name_admin(user)] welded a single tank bomb. Temp: [bombtank.air_contents.temperature-T0C]")
			user << "<span class='notice'>A pressure hole has been bored to [bombtank] valve. \The [bombtank] can now be ignited.</span>"
		else
			status = 0
			bombers += "[key_name(user)] unwelded a single tank bomb. Temp: [bombtank.air_contents.temperature-T0C]"
			user << "<span class='notice'>The hole has been closed.</span>"
	add_fingerprint(user)
	..()

/obj/item/explosive/onetankbomb/attack_self(mob/user as mob) //pressing the bomb accesses its assembly
	bombassembly.attack_self(user, 1)
	add_fingerprint(user)
	return

/obj/item/explosive/onetankbomb/receive_signal()	//This is mainly called by the sensor through sense() to the holder, and from the holder to here.
	visible_message("\icon[src] *beep* *beep*", "*beep* *beep*")
	sleep(10)
	if(!src)
		return
	if(status)
		bombtank.ignite()	//if its not a dud, boom (or not boom if you made shitty mix) the ignite proc is below, in this file
	else
		bombtank.release()

/obj/item/explosive/onetankbomb/HasProximity(atom/movable/AM as mob|obj)
	if(bombassembly)
		bombassembly.HasProximity(AM)

// ---------- Procs below are for tanks that are used exclusively in 1-tank bombs ----------

/obj/item/tank/proc/bomb_assemble(obj/item/device/assembly_holder/S,user)	//Bomb assembly proc. This turns assembly+tank into a bomb
	var/mob/M = user
	if(!S.secured)										//Check if the assembly is secured
		return
	if(isigniter(S.a_left) == isigniter(S.a_right))		//Check if either part of the assembly has an igniter, but if both parts are igniters, then fuck it
		return

	var/obj/item/explosive/onetankbomb/R = new /obj/item/explosive/onetankbomb(loc)

	M.drop_held_item()			//Remove the assembly from your hands
	M.temp_drop_inv_item(src)	//Remove the tank from your character,in case you were holding it
	M.put_in_hands(R)		//Equips the bomb if possible, or puts it on the floor.

	R.bombassembly = S	//Tell the bomb about its assembly part
	S.master = R		//Tell the assembly about its new owner
	S.loc = R			//Move the assembly out of the fucking way

	R.bombtank = src	//Same for tank
	master = R
	forceMove(R)
	R.update_icon()
	return

/obj/item/tank/proc/ignite()	//This happens when a bomb is told to explode
	var/fuel_moles = air_contents.gas["phoron"] + air_contents.gas["oxygen"] / 6
	var/strength = 1

	var/turf/ground_zero = get_turf(loc)
	loc = null

	if(air_contents.temperature > (T0C + 400))
		strength = (fuel_moles/15)

		if(strength >=1)
			explosion(ground_zero, round(strength,1), round(strength*2,1), round(strength*3,1), round(strength*4,1))
		else if(strength >=0.5)
			explosion(ground_zero, 0, 1, 2, 4)
		else if(strength >=0.2)
			explosion(ground_zero, -1, 0, 1, 2)
		else
			ground_zero.assume_air(air_contents)
			ground_zero.hotspot_expose(1000, 125)

	else if(air_contents.temperature > (T0C + 250))
		strength = (fuel_moles/20)

		if(strength >=1)
			explosion(ground_zero, 0, round(strength,1), round(strength*2,1), round(strength*3,1))
		else if (strength >=0.5)
			explosion(ground_zero, -1, 0, 1, 2)
		else
			ground_zero.assume_air(air_contents)
			ground_zero.hotspot_expose(1000, 125)

	else if(air_contents.temperature > (T0C + 100))
		strength = (fuel_moles/25)

		if (strength >=1)
			explosion(ground_zero, -1, 0, round(strength,1), round(strength*3,1))
		else
			ground_zero.assume_air(air_contents)
			ground_zero.hotspot_expose(1000, 125)

	else
		ground_zero.assume_air(air_contents)
		ground_zero.hotspot_expose(1000, 125)

	if(master)
		cdel(master)
		master = null
	cdel(src)

/obj/item/tank/proc/release()	//This happens when the bomb is not welded. Tank contents are just spat out.
	var/datum/gas_mixture/removed = air_contents.remove(air_contents.total_moles)
	var/turf/simulated/T = get_turf(src)
	if(!T)
		return
	T.assume_air(removed)