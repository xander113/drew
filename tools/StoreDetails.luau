return function(kit)
	local v, rgb, box, part, folder, text, cf, enum = kit.v, kit.rgb, kit.box, kit.part, kit.folder, kit.text, kit.cf, kit.enum
	local blue, royal, navy, gold, steel, white = kit.blue, kit.royal, kit.navy, kit.yellow, kit.steel, kit.white
	local green = rgb(64, 139, 94)
	local light = rgb(186, 216, 242)
	local oak = rgb(225, 170, 106)
	local charcoal = rgb(48, 64, 81)
	local neon = enum.Material.Neon
	local function sign(parent, title, subtitle, size, position, face, tint)
		local panel = box(parent, title, size, position, blue)
		text(panel, face, title, subtitle, tint or white)
	end

	local floor = folder(kit.store, "Floor and Signs")
	for x = -84, 84, 6 do
		box(floor, "Tile Joint", v(.035, .016, 142), v(x, .01, 0), rgb(196, 208, 220))
	end
	for z = -66, 66, 6 do
		box(floor, "Tile Joint", v(171, .017, .035), v(0, .011, z), rgb(196, 208, 220))
	end
	for _, z in { -61, -13, 39 } do
		for x = -80, 80, 4 do
			box(floor, "Floor Lane Mark", v(2, .023, .2), v(x, .016, z), rgb(158, 193, 228))
		end
	end
	for _, x in { -68, 69 } do
		sign(floor, "CHECKOUT", "This way", v(10, 2.8, .4), v(x, 10, -12), enum.NormalId.Front)
		sign(floor, "BACK AISLES", "Milk and bread", v(13, 2.8, .4), v(x, 10, -12), enum.NormalId.Back)
		box(floor, "Sign Rod", v(.16, 8, .16), v(x, 15.2, -12), steel)
	end

	local rear = folder(kit.store, "Back Wall Counters")
	local backWall = {
		{ -57, "BAKERY", "Baked this morning", oak },
		{ -20, "COLD DRINKS", "Keep it cool", rgb(77, 164, 212) },
		{ 18, "MILK & EGGS", "In the coolers", rgb(110, 160, 198) },
		{ 56, "PICKUP", "Get your order here", gold },
	}
	for _, entry in backWall do
		local x, title, subtitle, color = table.unpack(entry)
		sign(rear, title, subtitle, v(22, 4, .28), v(x, 11.6, -69.9), enum.NormalId.Back)
		box(rear, "Bumper Rail", v(29, .25, .5), v(x, 1.05, -68.9), steel)
		for bay = -2, 2 do
			local startX = x + bay * 5.4
			box(rear, "Display Cabinet", v(5.2, 6.55, 1.4), v(startX, 3.3, -69.75), charcoal)
			box(rear, "Frame", v(4.8, 5.9, .18), v(startX, 3.58, -69), color)
			for tier = 0, 2 do
				box(rear, "Glass Shelf", v(4.45, .12, .7), v(startX, 1.75 + tier * 1.45, -68.76), light)
				for item = -1, 1 do
					local tone = if (item + tier) % 2 == 0 then white else color
					box(rear, "Pack", v(.93, .78, .4), v(startX + item * 1.3, 2.17 + tier * 1.45, -68.58), tone)
				end
			end
			box(rear, "Cabinet Handle", v(.15, 1.04, .22), v(startX + 1.95, 3.5, -68.25), steel)
			box(rear, "Cooler Lamp", v(4.7, .07, .12), v(startX, 6.1, -68.42), white, false, neon)
		end
	end

	local fixtures = folder(kit.store, "Produce and Home Displays")
	for i, rect in kit.layout.Fixtures do
		local x, z = rect.x, rect.z
		local produce = i <= 2
		local color = if produce then oak else light
		box(fixtures, "Display Base", v(rect.width, 2.5, rect.depth), v(x, 1.25, z), navy, true)
		box(fixtures, "Display Top", v(rect.width - .12, .26, rect.depth - .1), v(x, 2.54, z), color)
		for n = -(i <= 2 and 1 or 2), (i <= 2 and 1 or 2) do
			local zz = z + n * (if produce then 3.5 else 4.5)
			box(fixtures, "Bin", v(rect.width - 1, .55, if produce then 3.15 else 3.8), v(x, 2.95, zz), color)
			for side = -1, 1, 2 do
				for row = -1, 1 do
					local shade = if produce then ({ rgb(238, 93, 42), rgb(222, 50, 65), rgb(111, 178, 60) })[(i + row + n + 5) % 3 + 1] else ({ gold, light, green })[(i + row + n + 5) % 3 + 1]
					local pack = box(fixtures, if produce then "Fruit" else "Kitchen Set", v(1.5, 1.2, 1.1), v(x + side * 1.45, 3.68, zz + row * 1.02), shade)
					if produce then pack.Shape = enum.PartType.Ball end
				end
			end
		end
		local face = if x < 0 then enum.NormalId.Right else enum.NormalId.Left
		sign(fixtures, ({ "FRESH FRUIT", "VEG TODAY", "KITCHEN", "HOME DEALS" })[i], nil, v(.36, 1.8, 8), v(x, 5.46, z), face, gold)
	end

	for _, x in { -80, -58, -37, 37, 58, 80 } do
		box(kit.building, "Blue Pillar", v(1.9, 13.3, 1.8), v(x, 6.7, 76.5), royal, true)
		box(kit.building, "Yellow Pillar Band", v(2.05, .38, 1.96), v(x, 11.28, 76.5), gold)
	end
	for _, x in { -10.5, 10.5 } do
		box(kit.building, "Entry Portal Side", v(.75, 8.9, 1.36), v(x, 4.45, 72), blue, true)
	end
	box(kit.building, "Entry Portal Top", v(22, .8, 1.45), v(0, 8.78, 72), blue)
	sign(kit.building, "WELCOME TO WWMS", nil, v(20, 2.4, .28), v(0, 10.45, 72.8), enum.NormalId.Back, gold)
	for z = 69.5, 74.5, .5 do
		box(kit.building, "Entry Mat Rib", v(18, .026, .19), v(0, .047, z), charcoal)
	end
	for _, x in { -91, 91 } do
		sign(kit.lot, "WWMS", "MEGA SHOP", v(10, 4.25, .6), v(x, 15.6, 99), enum.NormalId.Back, gold)
		box(kit.lot, "Parking Sign Post", v(.85, 14.5, .85), v(x, 7.2, 99), navy, true)
	end

	local parking = folder(kit.lot, "Parked Cars")
	for i, spot in { {-69, 104}, {-51, 101}, {53, 104}, {72, 102}, {-82, 120}, {78, 117} } do
		local x, z = spot[1], spot[2]
		local car = folder(parking, "Car " .. i, "Model")
		local tones = { rgb(225, 103, 92), rgb(202, 218, 236), gold, rgb(87, 135, 212), rgb(110, 179, 136), white }
		box(car, "Chassis", v(7.7, 1.2, 14), v(x, 1.67, z), charcoal)
		box(car, "Body", v(7.45, 1.9, 13.5), v(x, 2.41, z), tones[i], true)
		box(car, "Cabin Glass", v(6.3, 1.7, 6.8), v(x, 4.02, z + .5), rgb(62, 92, 122))
		box(car, "Roof", v(6.5, .38, 7), v(x, 4.99, z + .5), tones[i])
		for side = -1, 1, 2 do
			for tire = -1, 1, 2 do
				local wheel = box(car, "Wheel", v(.72, 2.28, 2.28), v(x + side * 3.77, 1.16, z + tire * 4.1), charcoal)
				wheel.Shape = enum.PartType.Cylinder
			end
			box(car, "Front Light", v(1.7, .41, .19), v(x + side * 2.46, 2.66, z - 6.77), white)
			box(car, "Rear Light", v(1.65, .44, .19), v(x + side * 2.46, 2.55, z + 6.77), rgb(236, 62, 72))
		end
	end

	for _, x in { -85, -44, 44, 85 } do
		box(kit.lot, "Parking Lamp Stand", v(.68, 14.3, .68), v(x, 7.1, 117), navy, true)
		box(kit.lot, "Parking Lamp Arm", v(4.7, .45, .65), v(x, 14.1, 117), navy)
		box(kit.lot, "Lamp", v(4.24, .14, .54), v(x, 13.83, 117), white, false, neon)
	end
	for _, x in { -94, -36, 36, 94 } do
		box(kit.lot, "Planter Pot", v(4.2, 2.1, 4.2), v(x, 1, 82), blue, true)
		for i = 1, 3 do
			local plant = box(kit.lot, "Planter Leaves", v(3.2, 2.8, 2.9), v(x + (i - 2) * .8, 1.8 + i * .55, 82), rgb(52 + i * 10, 115 + i * 11, 82))
			plant.Shape = enum.PartType.Ball
		end
	end

	for i = 1, 3 do
		local x = 52 + i * 8
		box(kit.checkout, "Belt Lip", v(4.5, .3, .2), v(x, 3.33, 49.57), gold)
		box(kit.checkout, "Scanner", v(1.6, .13, 1.25), v(x, 3.33, 54.2), charcoal)
		box(kit.checkout, "Scan Light", v(1.24, .05, .12), v(x, 3.41, 54.13), rgb(236, 82, 69), false, neon)
		for iBag = -1, 1 do
			box(kit.checkout, "Paper Bag", v(.77, 1, .56), v(x + iBag * 1.02, 3.71, 57.15), oak)
		end
	end
	for _, x in { 46, 80 } do
		box(kit.checkout, "Queue Post", v(.4, 3, .4), v(x, 1.5, 47.3), steel)
		box(kit.checkout, "Queue Base", v(1.28, .18, 1.28), v(x, .09, 47.3), charcoal)
	end

	local bx, bz = kit.layout.BayX, kit.layout.BayZ
	for _, side in { -1, 1 } do
		box(kit.bay, "Lit Bay Upright", v(1.3, 8, 1.1), v(bx + side * 12.7, 4, 62.5), blue)
		box(kit.bay, "Bay Upright Light", v(.24, 6.56, .16), v(bx + side * 12.67, 4.5, 61.89), rgb(155, 253, 189), false, neon)
		for z = 50, 62, 2 do
			box(kit.bay, "Bay LEDs", v(.22, .045, .75), v(bx + side * 12.11, .052, z), light, false, neon)
		end
		for z = 46, 54, 4 do
			part(kit.bay, "Floor Arrow", v(.16, .034, 2.55), cf.new(bx + side * .66, .075, z) * cf.Angles(0, -side * math.rad(32), 0), gold)
		end
	end
	for x = -10, 10, 2 do
		box(kit.bay, "Return Mat Rib", v(.08, .035, 10), v(bx + x, .065, bz + .5), rgb(48, 128, 236))
	end
end
