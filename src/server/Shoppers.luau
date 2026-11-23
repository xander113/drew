local AisleRoutes = require(script.Parent.AisleRoutes)
local Wardrobe = require(script.Parent.Wardrobe)

local Shoppers = {}
Shoppers.__index = Shoppers

local ServerStorage = game:GetService("ServerStorage")
local rig = ServerStorage:WaitForChild("ShopperRig")

local scenes = {
	{ "Hey! Where’s the milk?", "Coolers at the back.", "Thanks. I walked right past it!" },
	{ "Is this price for two?", "Check the yellow tag.", "Oh! I see it now." },
	{ "Which aisle has batteries?", "Try aisle five.", "Great. Thanks!" },
	{ "Can I return this toaster?", "Try the pickup desk.", "Got it. Thanks!" },
	{ "Where’s the cereal?", "Try the pantry aisle.", "That was quick. Thanks!" },
	{ "Is register three open?", "Look for the green light.", "Found it. Thanks!" },
	{ "Where did the apples go?", "Try the fruit bins.", "I’ll look there. Thanks!" },
}

local names = { "Sam", "Jo", "Ari", "Lee", "Max", "Kim", "Ray", "Pat" }
local rgb = Color3.fromRGB
local skins = {
	rgb(249, 219, 192), rgb(238, 196, 164), rgb(216, 168, 133), rgb(198, 146, 108),
	rgb(179, 124, 86), rgb(158, 105, 74), rgb(139, 88, 63), rgb(121, 76, 58),
	rgb(101, 61, 48), rgb(77, 48, 40),
}

local function shopperModel(parent, id, position, random)
	local model = rig:Clone()
	model.Name = names[(id - 1) % #names + 1]
	local skin = skins[random:NextInteger(1, #skins)]
	for _, limb in model:GetChildren() do
		if limb:IsA("BasePart") then
			limb.CanCollide, limb.CanTouch, limb.CanQuery = false, false, false
			limb.CastShadow = true
			limb.Massless = limb ~= model.PrimaryPart
			limb.Color = skin
		end
	end
	model.PrimaryPart.Anchored = true
	model.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.Humanoid.EvaluateStateMachine = false

	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	model.Parent = parent
	Wardrobe.shopper(model, random)
	model:AddTag("WWMSShopper")
	return model
end

local function pose(shopper, origin)
	local position = shopper.position + origin + Vector3.new(0, 3, 0)
	local frame = CFrame.lookAt(position, position + shopper.facing)
	if shopper.model:GetPivot() ~= frame then shopper.model:PivotTo(frame) end
end

function Shoppers:stop(shopper, workerPosition)
	shopper.speaking = true
	local flat = Vector3.new(workerPosition.X, 0, workerPosition.Z) - self.origin
	local face = flat - shopper.position
	if face.Magnitude > .01 then
		if face.Magnitude < 2.7 then
			local proposed = flat - face.Unit * 2.7
			if self.routes:clear(shopper.position, proposed) then shopper.position = proposed end
		end
		shopper.facing = face.Unit
	end
	pose(shopper, self.origin)
end

function Shoppers:resume(shopper, now)
	shopper.speaking = false
	shopper.restUntil, shopper.planAt = now + 4, now + .12
	shopper.route, shopper.routeIndex = {}, 1
	shopper.following, shopper.plannedDestination = nil, nil
end

local function compileStops(layout, routes)
	local stops = {}
	for name, visits in layout.ShoppingStops do
		local group = {}
		for _, visit in visits do
			local point = Vector3.new(visit.x, 0, visit.z)
			if routes:clear(point, point) then
				table.insert(group, { point = point, gaze = Vector3.new(visit.faceX, 0, visit.faceZ) })
			end
		end
		stops[name] = group
	end
	return stops
end

local function visitNext(self, shopper)
	if not shopper.trip or shopper.visitIndex > #shopper.trip then
		local trips = self.trips
		local first = self.random:NextInteger(1, #trips)
		if trips[first] == shopper.trip and #trips > 1 then first = first % #trips + 1 end
		shopper.trip, shopper.visitIndex = trips[first], 1
	end
	local group = self.stops[shopper.trip[shopper.visitIndex]]
	shopper.visitIndex += 1
	if group and #group > 0 then
		shopper.visit = group[self.random:NextInteger(1, #group)]
	else
		local points = self.routes.patrol
		local point = points[self.random:NextInteger(1, #points)]
		shopper.visit = { point = point, gaze = nil }
	end
	shopper.browseUntil = nil
end

local function shoppingTarget(self, shopper, now)
	if not shopper.visit then visitNext(self, shopper) end
	local visit = shopper.visit
	if (visit.point - shopper.position).Magnitude > .6 then
		shopper.browseUntil = nil
		return visit.point
	end
	if not shopper.browseUntil then
		shopper.browseUntil = now + self.random:NextNumber(.85, 2.0)
		if visit.gaze then
			local angle = visit.gaze - shopper.position
			if angle.Magnitude > .1 then shopper.facing = angle.Unit end
		end
	end
	if now >= shopper.browseUntil then
		visitNext(self, shopper)
		return shopper.visit.point
	end
	return nil
end

function Shoppers.new(parent, layout, random, count, speed, now, origin, range)
	local routes = AisleRoutes.new(layout)
	local self = setmetatable({
		list = {}, random = random, routes = routes, speed = speed, origin = origin, range = range,
		trips = layout.ShoppingTrips, stops = compileStops(layout, routes),
	}, Shoppers)
	local starts = table.clone(routes.patrol)
	for index = 1, count do
		local chosen = random:NextInteger(index, #starts)
		starts[index], starts[chosen] = starts[chosen], starts[index]
		local position = starts[index]
		local model = shopperModel(parent, index, position + origin, random)
		local trip = self.trips[random:NextInteger(1, #self.trips)]
		table.insert(self.list, {
			model = model, position = position, route = {}, routeIndex = 1, trip = trip, visitIndex = random:NextInteger(1, #trip - 1),
			facing = Vector3.new(0, 0, -1), planAt = now + index * .019, restUntil = now + 2.5 + (index % 5) * .25,
		})
	end
	return self
end

function Shoppers:plan(shopper, now, workers, catch)
	local nearest, distance, rank = nil, self.range, math.huge
	if now >= shopper.restUntil then
		for _, worker in workers do
			local gap = (worker.position - shopper.position).Magnitude
			local cost = gap + (if shopper.following == worker.player then 0 else 3)
			if worker.eligible and worker.position.Z <= 46 and gap < self.range and cost < rank then
				nearest, distance, rank = worker, gap, cost
			end
		end
	end
	if nearest and distance <= 4.35 and self.routes:clear(shopper.position, nearest.position) then
		local lines = scenes[self.random:NextInteger(1, #scenes)]
		if catch(nearest.player, shopper, lines, now) then
			nearest.eligible = false
			return
		end
		nearest = nil
	end

	local previous = shopper.following
	local destination = if nearest then self.routes:approach(shopper.position, nearest.position) else nil
	if destination then shopper.browseUntil = nil end
	shopper.following = if destination then nearest.player else nil
	destination = destination or shoppingTarget(self, shopper, now)
	if not destination then
		shopper.route, shopper.routeIndex, shopper.plannedDestination = {}, 1, nil
	elseif self.routes:clear(shopper.position, destination) then
		shopper.route, shopper.routeIndex, shopper.plannedDestination = { destination }, 1, destination
	elseif previous ~= shopper.following or shopper.routeIndex > #shopper.route
		or not shopper.plannedDestination or (destination - shopper.plannedDestination).Magnitude > 4.8 then
		shopper.route = self.routes:trace(shopper.position, destination)
		shopper.routeIndex, shopper.plannedDestination = 1, destination
	end
	shopper.planAt = now + .32 + self.random:NextNumber(0, .12)
end

local function move(shopper, remaining)
	while remaining > .001 do
		local target = shopper.route[shopper.routeIndex]
		if not target then return end
		local delta = target - shopper.position
		local distance = delta.Magnitude
		if distance < .02 then
			shopper.routeIndex += 1
		else
			shopper.facing = delta.Unit
			if distance >= remaining then
				shopper.position += shopper.facing * remaining
				return
			end
			shopper.position = target
			remaining -= distance
			shopper.routeIndex += 1
		end
	end
end

function Shoppers:step(dt, now, workers, catch)
	for _, shopper in self.list do
		if shopper.speaking then continue end
		if now >= shopper.planAt then self:plan(shopper, now, workers, catch) end
		if shopper.speaking then continue end
		local pace = if shopper.following then 1 else .63
		move(shopper, self.speed * dt * pace)
		pose(shopper, self.origin)
	end
end

return Shoppers
