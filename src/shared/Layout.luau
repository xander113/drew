local layout = {
	ShelfX = table.freeze({ -53, -31, -9, 13, 35, 57 }),
	ShelfZ = table.freeze({ -38, 12 }),
	ShelfWidth = 5.6,
	ShelfDepth = 30,
	LaneX = table.freeze({ -70, -42, -20, 2, 24, 46, 70 }),
	CrossZ = table.freeze({ -62, -13, 39 }),
	BayX = -33,
	BayZ = 56,
	BayWidth = 25,
	BayDepth = 13,
	Fixtures = table.freeze({
		table.freeze({ x = -78, z = 23, width = 8, depth = 12 }),
		table.freeze({ x = -78, z = 2, width = 8, depth = 12 }),
		table.freeze({ x = 80, z = -31, width = 7, depth = 24 }),
		table.freeze({ x = 80, z = 10, width = 7, depth = 25 }),
	}),
}

local function obstacle(kind, x, z, width, depth)
	return table.freeze({ kind = kind, x = x, z = z, width = width, depth = depth })
end

layout.MiniObstacles = table.freeze({
	obstacle("Pallet", -62, -48, 5.2, 4.2),
	obstacle("Restock", -41, -34, 4.8, 3.8),
	obstacle("Sale", -20, -52, 5.8, 4.6),
	obstacle("Pallet", 23, -32, 5.2, 4.2),
	obstacle("Restock", 44, -43, 4.8, 3.8),
	obstacle("Sale", 67, -49, 5.8, 4.6),
	obstacle("Sale", -42, -5, 5.8, 4.6),
	obstacle("Pallet", -21, 7, 5.2, 4.2),
	obstacle("Restock", 4, 16, 4.8, 3.8),
	obstacle("Sale", 22, 2, 5.8, 4.6),
	obstacle("Pallet", 68, 7, 5.2, 4.2),
	obstacle("Restock", -61, 34, 4.8, 3.8),
	obstacle("Sale", 25, 31, 5.8, 4.6),
	obstacle("Pallet", 49, 32, 5.2, 4.2),
	obstacle("Restock", 66, 32, 4.8, 3.8),
})

layout.WetSpots = table.freeze({
	obstacle("Wet Spot", 1, -40, 4.4, 3.6),
	obstacle("Wet Spot", -65, -18, 4.4, 3.6),
	obstacle("Wet Spot", 48, -5, 4.4, 3.6),
	obstacle("Wet Spot", -16, 32, 4.4, 3.6),
	obstacle("Wet Spot", 74, 41, 4.4, 3.6),
})

-- A visit holds a place to stand and a fixture to look at.
local function visit(x, z, faceX, faceZ)
	return table.freeze({ x = x, z = z, faceX = faceX, faceZ = faceZ })
end

layout.ShoppingStops = table.freeze({
	Produce = table.freeze({ visit(-71, 22, -78, 23), visit(-70, 1, -78, 2) }),
	Bakery = table.freeze({ visit(-61, -63, -57, -70), visit(-53, -62, -57, -70) }),
	Pantry = table.freeze({ visit(-25, -32, -31, -32), visit(-37, 19, -31, 19) }),
	Drinks = table.freeze({ visit(-19, -62, -20, -70), visit(-27, -63, -20, -70) }),
	Snacks = table.freeze({ visit(-15, 16, -9, 16), visit(-3, -29, -9, -29) }),
	Home = table.freeze({ visit(41, 15, 35, 15), visit(27, 19, 35, 19) }),
	Hardware = table.freeze({ visit(50, -21, 57, -21), visit(62, -24, 57, -24) }),
	Dairy = table.freeze({ visit(16, -62, 18, -70), visit(22, -63, 18, -70) }),
	Pickup = table.freeze({ visit(56, -63, 56, -70), visit(62, -61, 56, -70) }),
	Checkout = table.freeze({ visit(56, 43, 60, 54), visit(64, 44, 68, 54), visit(72, 45, 76, 54) }),
})

layout.ShoppingTrips = table.freeze({
	table.freeze({ "Produce", "Bakery", "Pantry", "Checkout" }),
	table.freeze({ "Pantry", "Snacks", "Drinks", "Checkout" }),
	table.freeze({ "Drinks", "Dairy", "Snacks", "Checkout" }),
	table.freeze({ "Home", "Hardware", "Pickup", "Checkout" }),
	table.freeze({ "Produce", "Snacks", "Dairy", "Checkout" }),
	table.freeze({ "Home", "Dairy", "Bakery", "Checkout" }),
})

local blockers = {}
for _, x in layout.ShelfX do
	for _, z in layout.ShelfZ do
		table.insert(blockers, obstacle("Shelf", x, z, layout.ShelfWidth, layout.ShelfDepth))
	end
end
for _, fixtures in { layout.Fixtures, layout.MiniObstacles } do
	for _, rect in fixtures do table.insert(blockers, rect) end
end
layout.Blockers = table.freeze(blockers)

-- Front-of-store fixtures only need extra clearance for shopper routes.
layout.ShopperBlockers = table.freeze({
	obstacle("Checkout", 60, 54, 4.7, 9),
	obstacle("Checkout", 68, 54, 4.7, 9),
	obstacle("Checkout", 76, 54, 4.7, 9),
	obstacle("Stage", 25, 54, 14, 9),
	obstacle("Bay Rail", layout.BayX - 12.8, layout.BayZ, .45, 14.1),
	obstacle("Bay Rail", layout.BayX + 12.8, layout.BayZ, .45, 14.1),
	obstacle("Bay Rail", layout.BayX, 63.4, 26, .6),
})


return table.freeze(layout)
