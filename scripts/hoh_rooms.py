# Python 3 script
# Author : Fred Limouzin (fphenix@hotmail.com)
# THis will parse the Rooms data from Head Over Heels (Amstrad CPC) and print out the decompacted data (Room Building).
# Result in hoh_rooms.out.txt
# Input data in hoh_rooms_in.py

from hoh_rooms_in import *
from os.path import dirname, realpath, join

cwd = dirname(realpath(__file__))

#---------------------------------------------------------------------------------------------------
def string2bin (str):
	lstr = str.replace(" ", "")
	rets = ""
	for char in lstr:
		rets += bin(int(char, 16))[2:].zfill(4)
	return rets

#---------------------------------------------------------------------------------------------------
def extract(nbbits, str):
	v = int(str[0:nbbits], 2)
	return v, str[nbbits:]

#---------------------------------------------------------------------------------------------------
def fwrite(file, label, str1, str2 = ""):
	if str2:
		str2 = " (" + str2 +")"
	file.write(label + ": " + str(str1) + str2 + "\n")

#---------------------------------------------------------------------------------------------------
def unpack_Room(fw, roomId, csvList):
	fwrite(fw, "#", "|" * 80)

	fwrite(fw, "Room ID", roomId)
	r = string2bin(Room_list1[roomId])

	roomDimId, r = extract(3, r)
	fwrite(fw, "Room Dimensions", roomDimId, roomDimensions[roomDimId])
	colScheme, r = extract(3, r)
	fwrite(fw, "Color Scheme", colScheme, colorScheme[colScheme])
	worldId, r = extract(3, r)
	fwrite(fw, "World", worldId, worldIds[worldId])
	doorId, r = extract(3, r)
	fwrite(fw, "Door SpriteId", doorId)

	row, col, elevation = (int(roomId[0], 16), int(roomId[1], 16), int(roomId[2], 16))
	csvList[row][col][elevation] = world1letter[worldId] + ":" + str(roomId)
	csvList[row][col][elevation] += " : Head"  if roomId == "8A4" else ""
	csvList[row][col][elevation] += " : Heels" if roomId == "894" else ""

	doorData = []
	for i in range(4):
		dd, r = extract(3, r)
		doorData.append(wall_door_state_condensed[dd])
		fwrite(fw, f"DoorData {i}", dd, wall_door_state[dd] + (" ; " + doorsDir[i] if dd > 1 else ""))

	floorCode, r = extract(3, r)
	fwrite(fw, "FloorId", floorCode, floorType[floorCode])
	floor = "!" if floorCode == 6 else " " if floorCode != 7 else "." # "!":Danger, " ":Tile or ".":None

	room_data = reset_room(roomId, worldIds[worldId], colorScheme[colScheme], doorData, roomDimensions[roomDimId], floor)
	origin_uvz = {"0": [0, 0, 7], "1": [0, 0, 7], "2": [0, 0, 7], "3": [0, 0, 7],}
	origin_uvz_index = 0
	obj_uvz = []

	macro = False
	loop = False
	flags10 = -1
	while True:
		if not loop:
			objid, r = extract(8, r)
			flags10 = -1
			flags2 = -1
			if objid == 0xFF:
				if "_" in r:
					r = r.split("_", 1)[1]
					fwrite(fw, "End", "Code FF")
					origin_uvz_index -= 1
					continue
				else:
					break
			elif objid >= 0xC0:
				macroId = hex(objid)[2:].upper().zfill(2)
				fwrite(fw, "Macro", macroId)
				origin_uvz_index += 1
				macro = True
			else:
				fwrite(fw, "Object", objid, objectList[objid][0] + "; Func:" + objectList[objid][1] + "; Flags:" + objectList[objid][2])
				if objid == 0:
					if roomId in Teleport.keys():
						fwrite(fw, "\tTeleport Destination", Teleport[roomId])
						csvList[row][col][elevation] += " (T:" + Teleport[roomId] + ")"

				if flags10 < 0:
					flags10, r = extract(2, r)
					fwrite(fw, "2b Flag", flags10)

					if flags10 >= 0b10:
						flags2, r = extract(1, r)
						fwrite(fw, "1b Global Flag", flags2, "NO flip" if flags2 == 0 else "FLIPPED")

					else:
						flags10 = 0b01
						flags2 = 0

					loop = True

		if 0 <= flags10 < 0b10 and not macro:
			flagsb, r = extract(1, r)
			fwrite(fw, "1b obj Flag", flagsb, "NO flip" if flagsb == 0 else "FLIPPED")		

		uvz = []
		for i in range(3):
			dd, r = extract(3, r)
			uvz.append(dd)
		
		if uvz[0] == 7 and uvz[1] == 7 and uvz[2] == 0:
			fwrite(fw, "end loop", "Code 770")
			loop = False
		else:
			fwrite(fw, "UVZ Coord", f"{uvz[0]} ; {uvz[1]} ; {uvz[2]}")

		if objid >= 0xC0:
			origin_uvz[str(origin_uvz_index)] = adduvz(origin_uvz[str(origin_uvz_index-1)], list((uvz[0], uvz[1], uvz[2])))
		else:
			if not(uvz[0] == 7 and uvz[1] == 7 and uvz[2] == 0):
				if objid == 0: #Teleport
					telep = "(" + Teleport[roomId] + ")"
				else:
					telep = ""
				obj_uvz = adduvz(origin_uvz[str(origin_uvz_index)], list((uvz[0], uvz[1], uvz[2])))
				room_data[f"r{obj_uvz[0]}c{obj_uvz[1]}"] += objectList[objid][3] + telep + str(obj_uvz[2])

		if ((flags10 % 2) == 0) and not macro:
			loop = False

		if macro:
			r = string2bin(Room_Macro_data[macroId]) + "_" + r
			macro = False
			loop = False

	if roomId in specialObj.keys():
		for speo in specialObj[roomId].split(" "):
			speo_spr = specialObjList[int(speo[-1], 16)][0]
			fwrite(fw, "Special Object", speo_spr)
			fwrite(fw, "Special Object UVZ Coord", f"{speo[0]} ; {speo[1]} ; {speo[2]}")
			room_data[f"r{speo[0]}c{speo[1]}"] += specialObjList[int(speo[-1], 16)][1] + str(speo[2])

	fw.write(print_room(room_data) + "\n")

#---------------------------------------------------------------------------------------------------
def reset_room(roomId, world, scheme, doors, dimensions, floor):
	inex = "X"
	dimensions = dimensions.split(None)
	res = {"RoomID": roomId, "World": world, "Scheme": scheme, "Door0": doors[0], "Door1": doors[1], "Door2": doors[2], "Door3": doors[3], "Floor": floor}
	col_min = (int(dimensions[1])/8)-1
	col_max = (int(dimensions[3])/8)-2
	row_min = (int(dimensions[0])/8)-1
	row_max = (int(dimensions[2])/8)-2
	for row in range(8):
		for col in range(8):
			k = f"r{row}c{col}"
			if any((col < col_min, col > col_max, row < row_min, row > row_max)):
				roomData = inex
			else:
				roomData = ""
			res[k] = roomData
	return res

#---------------------------------------------------------------------------------------------------
def print_room(data):
	#find the longest cell
	longuest = 2
	ws = "["
	we = "]"
	inex = "X"
	wall = "#"
	nowall = "_"
	nowallV = "|"
	floor = data["Floor"]
	for row in range(7, -1, -1):
		for col in range(7, -1, -1):
			k = f"r{row}c{col}"
			if len(data[k]) > longuest:
				longuest = len(data[k])
	# prepare NW and SE walls
	NWcell = []
	SEcell = []
	for _ in range(8):
		NWcell.append(wall if data["Door0"][0] == "W" else nowallV)
		SEcell.append(wall if data["Door2"][0] == "W" else nowallV)
	 
	if data["Door0"][1] != "":
		NWcell[2] = NWcell[5] = "-"
		NWcell[3] = NWcell[4] = data["Door0"][1]

	if data["Door2"][1] != "":
		SEcell[2] = SEcell[5] = "-"
		SEcell[3] = SEcell[4] = data["Door2"][1]
	
	# print Up room code (if any)
	res = "\nRoomID = " + data["RoomID"] + " (" + data["World"] + ")\n"
	if data["Door1"][1] != "" or data["Door1"][0] == "":
		res += (" " * 5)
		res += (" " * ((longuest+2) * 3)) + "   " + next_room(data["RoomID"], [1, 0, 0])
	res += "\n"
	# draw the NE wall/door
	res += (" " * 5)
	if data["Door1"][0] == "W" and data["Door1"][1] == "":
		res +=  wall * ((longuest+2) * 8) 
	elif data["Door1"][0] == "W":
		res += (wall * ((longuest+2) * 3)) + " [ " + (data["Door1"][1] * (((longuest+2) * 2) - 6)) + " ] " + (wall * ((longuest+2) * 3))
	else:
		res += nowall * ((longuest+2) * 8)
	#if room above exists and has no floor (room-data string has floor id in character [9] bits [3:1] ((value >> 1) mod 8) == 7 means "no floor")
	aboveroom = next_room(data["RoomID"], [0, 0, -1])
	if (Room_list1.get(aboveroom) is not None):
		if (((int(Room_list1[aboveroom][9], 16) // 2) % 8) == 7):
			res += " Above: " + aboveroom
	res += "\n"

	#draw the cells
	for row in range(7, -1, -1):
		#left room id if any
		line = next_room(data["RoomID"], [0, 1, 0]) if ((data["Door0"][1] != "" or data["Door0"][0] == "") and row == 4) else "   "
		line += " " + NWcell[row]
		#cells in current room
		for col in range(7, -1, -1):		
			k = f"r{row}c{col}"
			line += ws
			line += data[k] + (" " * (longuest - len(data[k]))) if (data[k] != inex and len(data[k]) != 0) else ""
			line += (data[k] * longuest) if data[k] == inex else ""
			line += (floor * longuest) if (len(data[k]) == 0) else "" 
			line += we
		#right room if any
		res += line + SEcell[row]
		res += " " + next_room(data["RoomID"], [0, -1, 0]) if ((data["Door2"][1] != "" or data["Door2"][0] == "") and row == 3) else ""
		res += "\n"

	# draw the SW wall/door
	res += (" " * 5)
	if data["Door3"][0] == "W" and data["Door3"][1] == "":
		res += wall * ((longuest+2) * 8) 
	elif data["Door3"][0] == "W":
		res += (wall * ((longuest+2) * 3)) + " [ " + (data["Door3"][1] * (((longuest+2) * 2) - 6)) + " ] " + (wall * ((longuest+2) * 3))
	else:
		res += nowall * ((longuest+2) * 8)
	# no floor, so add where we end up by falling down
	if (floor == "."):
		res += " Below: " + next_room(data["RoomID"], [0, 0, 1])
	res += "\n"
	# room code of Down door (if any)
	if data["Door3"][1] != "" or data["Door3"][0] == "":
		res += (" " * 5)
		res += (" " * ((longuest+2) * 3)) + "   " + next_room(data["RoomID"], [-1, 0, 0]) + "\n "

	return res

#---------------------------------------------------------------------------------------------------
def next_room(room, displacement):
	for i in range(3):
		if displacement[i] < 0:
			displacement[i] += 16
	u = (int(room[0], 16) + displacement[0]) % 16
	v = (int(room[1], 16) + displacement[1]) % 16
	z = (int(room[2], 16) + displacement[2]) % 16
	return hex(u)[2:].upper() + hex(v)[2:].upper() + hex(z)[2:].upper()

#---------------------------------------------------------------------------------------------------
def adduvz(orig, offset):
	newcoord = []
	idx = 0
	for  ori, offs in zip(orig, offset):
		if idx < 2:
			newcoord.append((ori + offs) % 8)
		else:
			maxi = max(ori, offs)
			mini = min(ori, offs)
			newcoord.append(7 - (maxi - mini))
		idx += 1
	return newcoord

#---------------------------------------------------------------------------------------------------

with open(join(cwd, "hoh_rooms.csv"), 'w') as fwcsv:
	rows, cols, elevation = (16, 16, 16)
	csvList = [[["" for _ in range(elevation)] for _ in range(cols)] for _ in range(rows)]
	with open(join(cwd, "hoh_rooms.out.txt"), 'w') as fw:
		for roomId in Room_list1.keys():
			#roomId = "8A4" #"E3C"
			unpack_Room(fw, roomId, csvList)
			#break

	fwcsv.write(",") # topleft empty cell
	for col in range(15, -1, -1):
		fwcsv.write(hex(col) + ("," if col > 0 else "\n")) # top row "col names"

	for row in range(15, -1, -1):
		fwcsv.write(hex(row) + ",")	# left col "row names"
		for col in range(15, -1, -1):
			tmpstr = '"'
			for elevation in range(16):
				addstr = csvList[row][col][elevation]
				tmpstr += ("\n" if (addstr != "" and tmpstr != "") else "") + addstr
			tmpstr += '"'
			fwcsv.write(tmpstr + ("," if col > 0 else "\n"))

raise SystemExit
