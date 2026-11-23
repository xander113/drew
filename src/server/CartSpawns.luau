local CartSpawns = {}

local STEP = 6.3
local CLEARANCE = 2.55

local function fits(blockers, x, z)
	for _, rect in blockers do
		if math.abs(x - rect.x) < rect.width / 2 + CLEARANCE and math.abs(z - rect.z) < rect.depth / 2 + CLEARANCE then
			return false
		end
	end
	return true
end

local function shuffle(random, items)
	for index = #items, 2, -1 do
		local other = random:NextInteger(1, index)
		items[index], items[other] = items[other], items[index]
	end
end

function CartSpawns.pick(layout, random, count)
	local zones = {}
	for index = 1, 9 do zones[index] = {} end
	-- One global grid keeps carts apart even where two store sections meet.
	for row = 0, 17 do
		local z = -64 + row * STEP
		for column = 0, 25 do
			local x = -80 + column * STEP + if row % 2 == 0 then 0 else STEP / 2
			if x <= 81 and fits(layout.Blockers, x, z) then
				local band = if z < -25 then 0 elseif z < 17 then 1 else 2
				local aisle = if x < -29 then 1 elseif x < 29 then 2 else 3
				table.insert(zones[band * 3 + aisle], Vector3.new(x, 0, z))
			end
		end
	end

	for _, zone in zones do shuffle(random, zone) end
	-- Keep a close cart on each side of the cart hole for the first run.
	for _, index in { 7, 8 } do
		local zone = zones[index]
		for i, point in zone do
			if math.abs(point.X - layout.BayX) < 21 and point.Z > 33 then
				zone[1], zone[i] = zone[i], zone[1]
				break
			end
		end
	end
	shuffle(random, zones)
	local picks = {}
	local row = 1
	while #picks < count do
		local previousSize = #picks
		for _, zone in zones do
			local point = zone[row]
			if point then table.insert(picks, point) end
			if #picks == count then break end
		end
		assert(#picks > previousSize, "The store needs more clear cart spaces")
		row += 1
	end
	return picks
end

return CartSpawns
