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

return table.freeze(layout)
