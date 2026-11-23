local Surfaces = {}

local finishes = {
	["Ground"] = "Concrete",
	["Car Park"] = "Asphalt",
	["Front Pavement"] = "Pavement",
	["Crew Patio"] = "Pavement",
	["Sales Floor"] = "Marble",
	["Back Wall"] = "Concrete",
	["Side Wall"] = "Concrete",
	["Roof Panel"] = "Metal",
	["Ceiling Beam"] = "Metal",
	["Canopy"] = "Metal",
	["Fascia"] = "Metal",
	["Window Mullion"] = "Metal",
	["Blue Pillar"] = "Metal",
	["Door Bollard"] = "Metal",
	["Side Trim"] = "Metal",
	["Back Trim"] = "Metal",
	["Gondola Fascia"] = "Metal",
	["Spine"] = "Metal",
	["Shelf"] = "Metal",
	["End Cap"] = "Metal",
	["Checkout Counter"] = "Metal",
	["Belt Lip"] = "Metal",
	["Conveyor"] = "Rubber",
	["Cabinet Handle"] = "Metal",
	["Display Base"] = "Metal",
	["Display Cabinet"] = "Metal",
	["Display Top"] = "WoodPlanks",
	["Bin"] = "WoodPlanks",
	["Entry Mat Rib"] = "Rubber",
	["Wood Pallet"] = "WoodPlanks",
	["Shipping Load"] = "Cardboard",
	["Top Box"] = "Cardboard",
	["End Cap Display Box"] = "Cardboard",
	["Paper Bag"] = "Cardboard",
	["Rack Base"] = "DiamondPlate",
	["Top Rail"] = "Metal",
	["Rack Wheel"] = "Rubber",
	["Sale Bin"] = "Metal",
	["Bay Rail"] = "Metal",
	["Rail Post"] = "Metal",
	["Back Rail"] = "Metal",
	["Return Paint"] = "DiamondPlate",
	["Plinth"] = "Marble",
	["Parking Lamp Stand"] = "Metal",
	["Parking Lamp Arm"] = "Metal",
	["Chassis"] = "Metal",
	["Body"] = "Metal",
	["Cabin Glass"] = "Glass",
	["Wheel"] = "Rubber",
	["Planter"] = "Concrete",
	["Planter Pot"] = "Concrete",
	["Shrub"] = "LeafyGrass",
	["Planter Leaves"] = "LeafyGrass",
}

function Surfaces.material(enum, name)
	local material = finishes[name]
	return if material then enum.Material[material] else enum.Material.SmoothPlastic
end

function Surfaces.decorate(kit)
	local v, rgb, box, part, folder, cf, enum = kit.v, kit.rgb, kit.box, kit.part, kit.folder, kit.cf, kit.enum
	local indoor = folder(kit.store, "Floor Finishes")
	local outdoor = folder(kit.lot, "Pavement Details")
	local tile, tileEdge = rgb(195, 216, 236), rgb(149, 181, 215)
	local concrete, grout, paint = rgb(177, 195, 216), rgb(143, 162, 184), rgb(230, 238, 244)
	local gold, navy = kit.yellow, kit.navy

	-- Keep the walking surfaces as single colliders. Finishes sit flush above them.
	for _, z in { -62, -13, 39 } do
		box(indoor, "Aisle Tile Band", v(170, .012, 5.4), v(0, .006, z), tile, false, enum.Material.Slate)
		for _, side in { -1, 1 } do
			box(indoor, "Tile Border", v(170, .016, .17), v(0, .01, z + side * 2.66), tileEdge)
		end
	end
	for _, x in { -82, 83 } do
		box(indoor, "Wall Tile Border", v(2.8, .016, 138), v(x, .009, 0), tile, false, enum.Material.Slate)
	end
	for column = -5, 5 do
		for row = 0, 2 do
			local x, z = column * 1.6, 61.8 + row * 1.65
			local tone = if (row + column) % 2 == 0 then tile else rgb(230, 237, 244)
			box(indoor, "Entry Mosaic Tile", v(1.56, .022, 1.6), v(x, .015, z), tone, false, enum.Material.Marble)
		end
	end
	for _, x in { 60, 68, 76 } do
		box(indoor, "Checkout Queue Pad", v(3.4, .012, 5.4), v(x, .009, 47), tile, false, enum.Material.Slate)
		for _, z in { 45.2, 47, 48.8 } do
			box(indoor, "Checkout Queue Line", v(2.7, .017, .2), v(x, .017, z), kit.white)
		end
	end
	for x = -90, 90, 6 do
		box(outdoor, "Pavement Joint", v(.06, .014, 17.5), v(x, .018, 77), grout)
	end
	for _, z in { 72, 77, 82 } do
		box(outdoor, "Pavement Joint", v(188, .014, .06), v(0, .019, z), grout)
	end
	for _, side in { -1, 1 } do
		local x = 52.25 * side
		box(outdoor, "Curb Top", v(85.5, .056, .68), v(x, .038, 85.59), concrete, false, enum.Material.Concrete)
		box(outdoor, "Curb Face", v(85.5, .13, .16), v(x, -.014, 85.95), paint)
		box(outdoor, "Curb Safety Paint", v(85.5, .022, .21), v(x, .077, 85.78), gold)
		box(outdoor, "Pedestrian Ramp", v(9.1, .027, 2.4), v(4.55 * side, .026, 84.45), gold, false, enum.Material.DiamondPlate)
		box(outdoor, "Grass Verge", v(7.2, .19, 176), v(119.9 * side, -.88, 8), rgb(101, 150, 109), false, enum.Material.Grass)
		for _, z in { -62, -37, -12, 13, 38, 116 } do
			local xPlant = side * (118.9 + z % 3 * .56)
			local shrub = box(outdoor, "Verge Plant", v(3.4, 1.6, 2.8), v(xPlant, -.04, z), rgb(107, 169, 116), false, enum.Material.LeafyGrass)
			shrub.Shape = enum.PartType.Ball
			local crown = box(outdoor, "Verge Plant Tips", v(2.24, 1.62, 2.1), v(xPlant + side * .61, .21, z - .28), rgb(139, 186, 106), false, enum.Material.LeafyGrass)
			crown.Shape = enum.PartType.Ball
		end
	end
	for _, z in { 92, 98, 104, 110, 116, 122 } do
		for _, x in { -30, 30 } do
			box(outdoor, "Drive Lane Dash", v(.38, .02, 2.95), v(x, -.073, z), gold)
		end
	end
	for _, x in { -103, 103 } do
		box(outdoor, "Storm Drain", v(3.2, .025, 1.66), v(x, -.068, 88), navy, false, enum.Material.Metal)
		for slot = -3, 3 do
			box(outdoor, "Drain Bar", v(.09, .022, 1.3), v(x + slot * .39, -.051, 88), grout)
		end
	end
	for _, x in { -37, 37 } do
		box(outdoor, "Drive Arrow Stem", v(.28, .024, 4.1), v(x, -.067, 113.6), paint)
		for _, side in { -1, 1 } do
			part(outdoor, "Drive Arrow Head", v(.28, .026, 2.1), cf.new(x + side * .66, -.067, 112) * cf.Angles(0, -side * math.rad(41), 0), paint)
		end
	end

	local exterior = folder(kit.building, "Wall Panels")
	for _, x in { -85.91, 85.91 } do
		for z = -60, 60, 12 do
			box(exterior, "Wall Panel Joint", v(.06, 15.5, .1), v(x, 11.12, z), rgb(188, 205, 224))
		end
		box(exterior, "Wall Chair Rail", v(.21, .28, 142), v(x, 3.28, 0), kit.steel, false, enum.Material.Metal)
	end
	for x = -78, 78, 12 do
		box(exterior, "Facade Panel Joint", v(.16, 8.28, .055), v(x, 17.5, 73.34), kit.royal)
	end
end

return Surfaces
