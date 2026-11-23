local AisleRoutes = {}
AisleRoutes.__index = AisleRoutes

local RADIUS = 1.75
local cached = setmetatable({}, { __mode = "k" })

function AisleRoutes.inAisles(point)
	return math.abs(point.X) < 84.5 and point.Z >= -67 and point.Z <= 69
end

function AisleRoutes.inStore(point)
	return math.abs(point.X) <= 86 and point.Z >= -70 and point.Z <= 70
end

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
	local fixtures = table.clone(layout.Blockers)
	for _, rect in layout.ShopperBlockers do table.insert(fixtures, rect) end
	for _, rect in fixtures do
		local halfX, halfZ = rect.width / 2 + RADIUS, rect.depth / 2 + RADIUS
		table.insert(self.blockers, { minX = rect.x - halfX, maxX = rect.x + halfX, minZ = rect.z - halfZ, maxZ = rect.z + halfZ })
	end

	local function add(x, z, patrol)
		local point = Vector3.new(x, 0, z)
		if not AisleRoutes.inAisles(point) then return end
		if not self:clear(point, point) then return end
		table.insert(self.nodes, point)
		if patrol then table.insert(self.patrol, point) end
	end
	for _, x in layout.LaneX do
		for _, z in layout.CrossZ do add(x, z, true) end
		for _, z in { -48, -29, 4, 22 } do add(x, z, true) end
	end
	for x = -78, 78, 13 do
		add(x, 45, false)
		add(x, 66, false)
	end
	for _, rect in fixtures do
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
	self.distances = distances
	cached[layout] = self
	return self
end

local searchAngles = {}
for i = 1, 8 do
	local angle = i * math.pi / 4
	searchAngles[i] = Vector3.new(math.cos(angle), 0, math.sin(angle))
end

function AisleRoutes:approach(from, target)
	if AisleRoutes.inAisles(target) and self:clear(target, target) then return target end
	for _, radius in { 2.1, 4.2 } do
		local chosen, distance = nil, math.huge
		for _, direction in searchAngles do
			local option = target + direction * radius
			if AisleRoutes.inAisles(option) and self:clear(option, option) then
				local leg = (option - from).Magnitude
				if leg < distance then chosen, distance = option, leg end
			end
		end
		if chosen then return chosen end
	end
	return nil
end

function AisleRoutes:bridges(position)
	local choices = {}
	for index, node in self.nodes do
		local offset = node - position
		local squared = offset:Dot(offset)
		if (#choices < 4 or squared < choices[#choices].squared) and self:clear(position, node) then
			local where = #choices + 1
			while where > 1 and squared < choices[where - 1].squared do where -= 1 end
			table.insert(choices, where, { node = index, squared = squared, length = math.sqrt(squared) })
			if #choices > 4 then table.remove(choices) end
		end
	end
	return choices
end

function AisleRoutes:trace(start, finish)
	if self:clear(start, finish) then return { finish } end
	local starts, ends = self:bridges(start), self:bridges(finish)
	local entry, exit, cost = nil, nil, math.huge
	for _, from in starts do
		for _, to in ends do
			local candidate = from.length + self.distances[from.node][to.node] + to.length
			if candidate < cost then entry, exit, cost = from.node, to.node, candidate end
		end
	end
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
