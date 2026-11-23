local AisleRoutes = {}
AisleRoutes.__index = AisleRoutes

local function crossesShelf(start, finish, shelf)
	local first, last = 0, 1
	local dx, dz = finish.X - start.X, finish.Z - start.Z
	if math.abs(dx) < 0.001 then
		if start.X < shelf.minX or start.X > shelf.maxX then return false end
	else
		local a, b = (shelf.minX - start.X) / dx, (shelf.maxX - start.X) / dx
		first, last = math.max(first, math.min(a, b)), math.min(last, math.max(a, b))
	end
	if math.abs(dz) < 0.001 then
		if start.Z < shelf.minZ or start.Z > shelf.maxZ then return false end
	else
		local a, b = (shelf.minZ - start.Z) / dz, (shelf.maxZ - start.Z) / dz
		first, last = math.max(first, math.min(a, b)), math.min(last, math.max(a, b))
	end
	return first <= last
end

function AisleRoutes.new(layout)
	local self = setmetatable({ shelves = {}, nodes = {} }, AisleRoutes)
	for _, x in layout.ShelfX do
		for _, z in layout.ShelfZ do
			table.insert(self.shelves, { minX = x - 4.5, maxX = x + 4.5, minZ = z - 16.7, maxZ = z + 16.7 })
		end
	end
	for _, rect in layout.Fixtures do
		local halfX, halfZ = rect.width / 2 + 1.7, rect.depth / 2 + 1.7
		table.insert(self.shelves, { minX = rect.x - halfX, maxX = rect.x + halfX, minZ = rect.z - halfZ, maxZ = rect.z + halfZ })
	end
	for _, x in layout.LaneX do
		for _, z in layout.CrossZ do
			table.insert(self.nodes, Vector3.new(x, 0, z))
		end
	end
	return self
end

function AisleRoutes:clear(start, finish)
	for _, shelf in self.shelves do
		if crossesShelf(start, finish, shelf) then return false end
	end
	return true
end

function AisleRoutes:closest(position)
	local nearest, distance = nil, math.huge
	for _, node in self.nodes do
		local offset = node - position
		local squared = offset:Dot(offset)
		if squared < distance and self:clear(position, node) then
			nearest, distance = node, squared
		end
	end
	return nearest
end

function AisleRoutes:trace(start, finish)
	if self:clear(start, finish) then return { finish } end
	local entry = self:closest(start)
	local exit = self:closest(finish)
	if not entry or not exit then return {} end
	return { entry, Vector3.new(exit.X, 0, entry.Z), exit, finish }
end

return AisleRoutes
