local function build(roblox, layout)
	local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
	local Color3, UDim2, Enum = roblox.Color3, roblox.UDim2, roblox.Enum
	local rgb, v = Color3.fromRGB, Vector3.new

	local blue = rgb(0, 104, 236)
	local royal = rgb(21, 66, 168)
	local navy = rgb(16, 36, 72)
	local ink = rgb(29, 45, 73)
	local white = rgb(247, 250, 249)
	local yellow = rgb(255, 207, 70)
	local sky = rgb(103, 208, 250)
	local mint = rgb(131, 221, 178)
	local coral = rgb(245, 133, 109)
	local steel = rgb(135, 153, 178)
	local floor = rgb(221, 229, 237)
	local concrete = rgb(167, 182, 200)
	local glass = rgb(157, 217, 252)
	local store = Instance.new("Model")
	store.Name = "WWMS"

	local function folder(parent, name, class)
		local object = Instance.new(class or "Folder")
		object.Name = name
		object.Parent = parent
		return object
	end

	local function part(parent, name, size, frame, color, solid, material)
		local object = Instance.new("Part")
		object.Name = name
		object.Size = size
		object.CFrame = frame
		object.Color = color
		object.Material = material or Enum.Material.SmoothPlastic
		object.Anchored = true
		object.CanCollide = solid == true
		object.CanTouch = false
		object.CanQuery = solid == true
		object.CastShadow = solid == true
		object.Parent = parent
		return object
	end

	local function box(parent, name, size, position, color, solid, material)
		return part(parent, name, size, CFrame.new(position), color, solid, material)
	end

	local function mark(parent, name, frame, size)
		local marker = part(parent, name, size or v(.25, .25, .25), frame, white, false)
		marker.Transparency = 1
		return marker
	end

	local function text(facePart, face, title, subtitle, color)
		local ui = folder(facePart, "Sign", "SurfaceGui")
		ui.Face = face
		ui.LightInfluence = 0
		ui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		ui.PixelsPerStud = 22

		local function line(name, value, y, height, tint, font)
			local label = folder(ui, name, "TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.fromScale(.035, y)
			label.Size = UDim2.fromScale(.93, height)
			label.Text, label.TextColor3, label.TextScaled = value, tint, true
			label.FontFace = roblox.Font.fromEnum(font)
		end

		line("Title", title, subtitle and .08 or .12, subtitle and .56 or .76, color, Enum.Font.GothamBlack)
		if subtitle then
			line("Subtitle", subtitle, .67, .22, white, Enum.Font.GothamBold)
		end
	end

	local building = folder(store, "Building")
	local merchandise = folder(store, "Departments")
	local checkout = folder(store, "Checkout")
	local lot = folder(store, "Forecourt")
	local bay = folder(store, "CartReturn")
	local cameras = folder(store, "MenuCameras")
	local markers = folder(store, "Markers")

	box(lot, "Ground", v(246, 2, 226), v(0, -2, 17), concrete, true)
	box(lot, "Car Park", v(230, .9, 69), v(0, -.54, 96), rgb(74, 92, 117), true)
	box(lot, "Front Pavement", v(190, 1.1, 18), v(0, -.54, 77), floor, true)
	box(lot, "Crew Patio", v(32, .6, 23), v(0, -.28, 106), navy, true)
	box(lot, "Crew Stripe", v(32, .04, .35), v(0, .035, 96), yellow)
	for _, x in { -72, -59, -46, 46, 59, 72 } do
		box(lot, "Parking Stripe", v(.28, .04, 17), v(x, -.065, 102), white)
	end
	for x = -11, 11, 2 do
		box(lot, "Crosswalk", v(.8, .04, 12), v(x, -.065, 89), white)
	end
	for _, x in { -76, 76 } do
		box(lot, "Planter", v(12, 2.6, 4.5), v(x, 1.3, 80), navy, true)
		for i = -1, 1 do
			local bush = box(lot, "Shrub", v(4, 3, 4), v(x + i * 3.45, 3, 80), rgb(76, 152, 113))
			bush.Shape = Enum.PartType.Ball
		end
	end

	box(building, "Sales Floor", v(174, 1, 144), v(0, -.5, 0), floor, true)
	box(building, "Back Wall", v(174, 22, 2), v(0, 11, -72), white, true)
	for _, x in { -87, 87 } do
		box(building, "Side Wall", v(2, 22, 144), v(x, 11, 0), white, true)
		box(building, "Side Trim", v(.24, 3.2, 143), v(x - math.sign(x) * 1.12, 1.6, 0), royal)
	end
	box(building, "Back Trim", v(172, 3.2, .24), v(0, 1.6, -70.89), royal)
	box(building, "Fascia", v(176, 9, 2.6), v(0, 17.5, 72), blue, true)
	box(building, "Gold Canopy Trim", v(176, .6, 2.81), v(0, 13.28, 72), yellow)
	box(building, "Canopy", v(176, .9, 10), v(0, 12.85, 75), navy, true)
	local marquee = box(building, "Main Marquee", v(83, 7.7, .25), v(0, 17.55, 73.43), blue)
	text(marquee, Enum.NormalId.Back, "WILLY WALTER’S", "M E G A   S H O P", white)
	for _, x in { -75, 75 } do
		local logo = box(building, "WWMS Emblem", v(13, 4.8, .28), v(x, 17.55, 73.46), royal)
		text(logo, Enum.NormalId.Back, "WWMS", nil, yellow)
	end
	for _, x in { -80, -62, -44, -26, -14, 14, 26, 44, 62, 80 } do
		box(building, "Window Mullion", v(.75, 13, 1.28), v(x, 6.5, 71), navy, true)
	end
	for _, pair in { {-87, -14}, {14, 87} } do
		local width = pair[2] - pair[1]
		local x = (pair[2] + pair[1]) / 2
		local window = box(building, "Show Windows", v(width, 12.6, .28), v(x, 6.5, 71), glass, true, Enum.Material.Glass)
		window.Transparency = .65
		window.CastShadow = false
		box(building, "Window Base", v(width, .65, .65), v(x, .33, 71), royal, true)
	end
	for _, x in { -13, 13 } do
		box(building, "Door Bollard", v(.52, 3.6, .52), v(x, 1.8, 75), yellow, true)
	end
	for _, z in { -61, -44, -27, -10, 7, 24, 41, 58 } do
		box(building, "Ceiling Beam", v(172, .65, 1.15), v(0, 19.9, z), steel)
		local roof = box(building, "Roof Panel", v(174, .75, 17), v(0, 21.2, z), rgb(211, 229, 244))
		roof.Transparency = .29
		for _, x in { -64, -32, 0, 32, 64 } do
			box(building, "LED Strip", v(10, .22, .7), v(x, 19.48, z), white, false, Enum.Material.Neon)
		end
	end
	box(building, "Main Aisle Stripe", v(170, .035, .22), v(0, .019, 40.2), blue)
	box(building, "Entrance Stripe", v(19, .036, .33), v(0, .022, 66), yellow)

	local departments = { "PRODUCE", "PANTRY", "SNACKS", "HOME", "HARDWARE", "EVERYDAY" }
	local colors = { mint, rgb(110, 177, 246), yellow, coral, rgb(190, 160, 233), sky }
	local packaging = { coral, yellow, mint, sky, rgb(171, 156, 223), rgb(239, 163, 198), white }
	for index, x in layout.ShelfX do
		local department = folder(merchandise, departments[index], "Model")
		local tint = colors[index]
		local banner = box(department, "Department Sign", v(14, 3.6, .75), v(x, 12.35, 31.5), royal)
		text(banner, Enum.NormalId.Back, string.format("%02d  %s", index, departments[index]), nil, white)
		text(banner, Enum.NormalId.Front, departments[index], nil, white)
		box(department, "Department Accent", v(14, .37, .78), v(x, 10.6, 31.5), tint)
		for hangingX = -1, 1, 2 do
			box(department, "Sign Hanger", v(.15, 6, .15), v(x + hangingX * 5, 16.9, 31.5), steel)
		end
		for row, z in layout.ShelfZ do
			local shelf = folder(department, "Gondola " .. row, "Model")
			local case = box(shelf, "Shelf Collision", v(5.6, 6.8, 30), v(x, 3.4, z), navy, true)
			case.Transparency = 1
			case.CastShadow = false
			box(shelf, "Spine", v(.25, 6.64, 29.8), v(x, 3.35, z), steel)
			for _, endZ in { -14.9, 14.9 } do
				box(shelf, "End Cap", v(5.65, 6.65, .53), v(x, 3.34, z + endZ), royal)
				box(shelf, "End Cap Accent", v(5.7, .52, .57), v(x, 5.72, z + endZ), tint)
			end
			for tier = 0, 3 do
				box(shelf, "Shelf", v(5.62, .26, 29.8), v(x, .46 + tier * 1.88, z), white)
			end
			for section = -3, 3 do
				for tier = 0, 2 do
					for side = -1, 1, 2 do
						local color = packaging[(index + section + tier + row + side) % #packaging + 1]
						local height = .68 + ((section + index + tier) % 3) * .19
						box(shelf, "Stock", v(1.95, height, 2.8), v(x + side * 1.42, .59 + tier * 1.88 + height / 2, z + section * 4), color)
					end
				end
			end
		end
	end

	for i = 1, 3 do
		local x = 52 + i * 8
		box(checkout, "Checkout Counter", v(4.7, 3, 9), v(x, 1.5, 54), royal, true)
		box(checkout, "Conveyor", v(3.7, .28, 6.4), v(x, 3.15, 53.1), ink)
		box(checkout, "Register", v(2, 1.55, .6), v(x, 3.93, 57.6), navy)
		box(checkout, "Register Display", v(1.62, 1, .1), v(x, 4, 57.23), mint)
		local sign = box(checkout, "Register Sign", v(3.65, 1.8, .45), v(x, 7.6, 54), blue)
		text(sign, Enum.NormalId.Front, tostring(i), nil, white)
	end

	local bx, bz = layout.BayX, layout.BayZ
	box(bay, "Return Paint", v(26, .047, 14), v(bx, .025, bz), royal)
	for _, offset in { -12.8, 12.8 } do
		box(bay, "Bay Side Stripe", v(.35, .06, 14.1), v(bx + offset, .037, bz), yellow)
		box(bay, "Bay Rail", v(.38, .38, 14.1), v(bx + offset, 2.05, bz), steel, true)
		for _, z in { 49, 56, 63 } do
			box(bay, "Rail Post", v(.45, 2.35, .45), v(bx + offset, 1.18, z), royal, true)
		end
	end
	for x = -9, 9, 3 do
		box(bay, "Return Threshold", v(1.65, .055, .4), v(bx + x, .038, 49.1), white)
	end
	box(bay, "Back Rail", v(26, 2.4, .6), v(bx, 1.2, 63.4), navy, true)
	local returnSign = box(bay, "Cart Hole Sign", v(25, 4.8, .7), v(bx, 7.3, 63.4), blue)
	text(returnSign, Enum.NormalId.Front, "CART HOLE", "P U S H   C A R T S   H E R E", yellow)
	box(bay, "Cart Hole Beacon", v(25, .3, .86), v(bx, 9.81, 63.4), mint, false, Enum.Material.Neon)
	mark(markers, "CartHole", CFrame.new(bx, 3, bz), v(25, 6, 13))

	local mascot = folder(store, "Willy Walter", "Model")
	local base = CFrame.new(25, 0, 54) * CFrame.Angles(0, math.rad(158), 0)
	local skin = rgb(224, 169, 127)
	local hair = rgb(222, 228, 230)
	local pants = rgb(50, 71, 108)
	local function feature(name, size, x, y, z, color, angle)
		return part(mascot, name, size, base * CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(angle or 0)), color)
	end
	box(mascot, "Plinth", v(14, .65, 9), v(25, .325, 54), royal, true)
	local mascotSign = feature("Mascot Plaque", v(8, 1.3, .25), 0, 1.22, 4.1, navy)
	mascotSign.CanCollide = true
	mascotSign.CanQuery = true
	text(mascotSign, Enum.NormalId.Back, "WILLY WALTER", nil, white)
	for _, sign in { -1, 1 } do
		feature("Boot", v(1.28, .54, 1.9), sign * .77, .94, .18, navy)
		feature("Trouser", v(1.27, 2, 1.41), sign * .77, 2.02, 0, pants)
	end
	feature("Polo", v(3.16, 2.75, 1.66), 0, 4.1, 0, blue)
	feature("Name Badge", v(.81, .39, .1), -.79, 4.71, .87, yellow)
	feature("Resting Sleeve", v(.87, 1.27, 1.28), -1.94, 4.66, 0, blue, -11)
	feature("Resting Hand", v(.79, 1.37, 1.18), -2.16, 3.62, .04, skin, -11)
	feature("Waving Sleeve", v(.98, 1.47, 1.27), 2.02, 4.86, 0, blue, -53)
	feature("Waving Hand", v(.92, 1.6, 1.04), 2.84, 5.76, .08, skin, 14)
	feature("Head", v(2.66, 2.25, 1.93), 0, 6.44, 0, skin)
	feature("Back Hair", v(2.74, 2.03, .47), 0, 6.65, -.81, hair)
	for _, sign in { -1, 1 } do
		feature("Hair at Temple", v(.42, 1.42, 1.77), sign * 1.19, 6.9, 0, hair)
		feature("Glasses", v(.64, .48, .12), sign * .47, 6.67, .99, navy)
		feature("Lenses", v(.47, .29, .06), sign * .47, 6.67, 1.066, rgb(188, 222, 225))
		feature("Eyes", v(.12, .19, .055), sign * .47, 6.67, 1.11, ink)
		feature("Smile Corners", v(.13, .17, .05), sign * .24, 6.02, 1.005, pants, sign * -20)
	end
	feature("Glasses Bridge", v(.38, .11, .1), 0, 6.67, 1.01, navy)
	feature("Smile", v(.4, .09, .05), 0, 5.97, 1.005, pants)
	feature("Moustache", v(.83, .2, .09), 0, 6.21, 1.03, hair)
	feature("Comb-over", v(1.88, .56, 1.93), -.24, 7.59, 0, hair, 8)

	local spawn = folder(lot, "Crew Spawn", "SpawnLocation")
	spawn.Size, spawn.CFrame = v(12, .5, 10), CFrame.new(0, .20, 107)
	spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
	spawn.Color, spawn.Material = blue, Enum.Material.SmoothPlastic
	mark(markers, "Crew", CFrame.new(0, 4, 105))
	for index = 1, 25 do
		local column = (index - 1) % 9
		local row = math.floor((index - 1) / 9)
		mark(markers, "Worker" .. index, CFrame.lookAt(v(-13 + column * 3.25, 3.5, 45 + row * 4.2), v(-13 + column * 3.25, 3.5, 19)))
	end

	local shots = {
		{ "Facade", v(52, 22, 121), v(0, 12, 67) },
		{ "Willy", v(36, 8, 35), v(24.8, 4.9, 54) },
		{ "Aisles", v(52, 15, -61), v(3, 6, 1) },
		{ "Return", v(-15, 11, 37), v(-34, 5.4, 58) },
	}
	for _, shot in shots do
		mark(cameras, shot[1], CFrame.lookAt(shot[2], shot[3]))
	end

	return store
end

return build
