local AisleRoutes = {}
AisleRoutes.__index = AisleRoutes

local RADIUS = 1.75
local cached = setmetatable({}, { __mode = "k" })

local function crosses(start, finish, rect)
	local first, last = 0, 1
	local dx, dz = finish.X - start.X, finish.Z - start.Z
	if math.abs(dx) < .001 then
		if start.X < rect.minX or start.X > rect.maxX then return false end
	else
		local a, b = (rect.minX - start.X) / dx, (rect.maxX - start.X) / dx
		first, last = math.max(first, math.min(a, b)), math.min(last, math.max(a, b))
	end
	if math.abs(dz) < .001 then
		if start.Z < rect.minZ or start.Z > rect.maxZ then return false end
	else
		local a, b = (rect.minZ - start.Z) / dz, (rect.maxZ - start.Z) / dz
		first, last = math.max(first, math.min(a, b)), math.min(last, math.max(a, b))
	end
	return first <= last
end

function AisleRoutes:clear(start, finish)
	for _, rect in self.blockers do
		if crosses(start, finish, rect) then return false end
	end
	return true
end

function AisleRoutes.new(layout)
	if cached[layout] then return cached[layout] end
	local self = setmetatable({ blockers = {}, nodes = {}, patrol = {}, nextHop = {} }, AisleRoutes)
	for _, rect in layout.Blockers do
		local halfX, halfZ = rect.width / 2 + RADIUS, rect.depth / 2 + RADIUS
		table.insert(self.blockers, { minX = rect.x - halfX, maxX = rect.x + halfX, minZ = rect.z - halfZ, maxZ = rect.z + halfZ })
	end

	local function add(x, z, patrol)
		if math.abs(x) >= 84.5 or z < -67 or z > 46 then return end
		local point = Vector3.new(x, 0, z)
		if not self:clear(point, point) then return end
		table.insert(self.nodes, point)
		if patrol then table.insert(self.patrol, point) end
	end
	for _, x in layout.LaneX do
		for _, z in layout.CrossZ do add(x, z, true) end
		for _, z in { -48, -29, 4, 22 } do add(x, z, true) end
	end
	for _, rect in layout.Blockers do
		if rect.kind == "Shelf" then continue end
		local x, z = rect.width / 2 + RADIUS + .35, rect.depth / 2 + RADIUS + .35
		for signX = -1, 1, 2 do
			for signZ = -1, 1, 2 do add(rect.x + x * signX, rect.z + z * signZ, false) end
		end
	end

	-- The shelves and displays are static. Reuse the short paths for every shopper.
	local size, distances = #self.nodes, {}
	for i, node in self.nodes do
		local hops, weights = {}, {}
		self.nextHop[i], distances[i] = hops, weights
		for j, other in self.nodes do
			if i == j then
				weights[j] = 0
			elseif self:clear(node, other) then
				weights[j], hops[j] = (other - node).Magnitude, j
			else
				weights[j] = math.huge
			end
		end
	end
	for via = 1, size do
		local bridge = distances[via]
		for from = 1, size do
			local row = distances[from]
			local cost = row[via]
			if from == via or cost == math.huge then continue end
			local hops = self.nextHop[from]
			for to = 1, size do
				local candidate = cost + bridge[to]
				if candidate + .0001 < row[to] then
					row[to], hops[to] = candidate, hops[via]
				end
			end
		end
	end
	cached[layout] = self
	return self
end

function AisleRoutes:closest(position)
	local nearest, distance = nil, math.huge
	for index, node in self.nodes do
		local offset = node - position
		local squared = offset:Dot(offset)
		if squared < distance and self:clear(position, node) then
			nearest, distance = index, squared
		end
	end
	return nearest
end

function AisleRoutes:trace(start, finish)
	if self:clear(start, finish) then return { finish } end
	local entry = self:closest(start)
	local exit = self:closest(finish)
	if not entry or not exit then return {} end
	local route = { self.nodes[entry] }
	while entry ~= exit do
		entry = self.nextHop[entry][exit]
		if not entry then return {} end
		table.insert(route, self.nodes[entry])
	end
	table.insert(route, finish)
	return route
end

return AisleRoutes
