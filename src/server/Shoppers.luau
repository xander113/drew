local AisleRoutes = require(script.Parent.AisleRoutes)
local Wardrobe = require(script.Parent.Wardrobe)
local shared = game:GetService("ReplicatedStorage"):WaitForChild("CartCatcher")
local Config = require(shared.Config)
local Spacing = require(shared.ShopperSpacing)

local Shoppers = {}
Shoppers.__index = Shoppers

local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")
local rig = ServerStorage:WaitForChild("ShopperRig")
local collisionGroup = "WWMSShopper"
if not PhysicsService:IsCollisionGroupRegistered(collisionGroup) then PhysicsService:RegisterCollisionGroup(collisionGroup) end
PhysicsService:CollisionGroupSetCollidable(collisionGroup, collisionGroup, false)

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

local function shopperModel(parent, id, position, random, look)
	local model = rig:Clone()
	model.Name = names[(id - 1) % #names + 1]
	local skin = skins[random:NextInteger(1, #skins)]
	for _, limb in model:GetChildren() do
		if limb:IsA("BasePart") then
			limb.CastShadow = true
			limb.Massless = limb ~= model.PrimaryPart
			limb.Color = skin
		end
	end
	model.PrimaryPart.Anchored = true
	model.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.Humanoid.EvaluateStateMachine = false

	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	Wardrobe.shopper(model, random, look, id)
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CanCollide, piece.CanTouch, piece.CanQuery, piece.CollisionGroup = false, false, false, collisionGroup
		end
	end
	model:AddTag("WWMSShopper")
	model.Parent = parent
	return model
end

local function pose(shopper, origin)
	local position = shopper.position + origin + Vector3.new(0, 3, 0)
	local frame = CFrame.lookAt(position, position + shopper.facing)
	if shopper.model:GetPivot() ~= frame then shopper.model:PivotTo(frame) end
end

local function releaseChase(self, shopper, now)
	local player = shopper.following
	if not player then return end
	self.chasers[player], self.chaseCooldowns[player] = nil, now + Config.ChaseCooldown
	shopper.following, shopper.plannedDestination = nil, nil
	shopper.route, shopper.routeIndex, shopper.planAt = {}, 1, now
	shopper.restUntil = math.max(shopper.restUntil, now + 1.75)
end

function Shoppers:cancelChase(player, now)
	local shopper = self.chasers[player]
	if shopper then releaseChase(self, shopper, now) end
end

function Shoppers:stop(shopper, workerPosition, now)
	releaseChase(self, shopper, now)
	shopper.speaking = true
	local flat = Vector3.new(workerPosition.X, 0, workerPosition.Z) - self.origin
	local face = flat - shopper.position
	local direction = if face.Magnitude > .01 then face.Unit else shopper.facing
	if face.Magnitude < 2.7 then
		local proposed = flat - direction * 2.7
		if AisleRoutes.inAisles(proposed) and self.routes:clear(shopper.position, proposed)
			and Spacing.clear(shopper.position, proposed, self.list, shopper) then
			shopper.position = proposed
		end
	end
	shopper.facing = direction
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
		trips = layout.ShoppingTrips, stops = compileStops(layout, routes), chasers = {}, chaseCooldowns = {},
	}, Shoppers)
	local starts = table.clone(routes.patrol)
	local look = Wardrobe.looks(random, count)
	for index = 1, count do
		local chosen = random:NextInteger(index, #starts)
		starts[index], starts[chosen] = starts[chosen], starts[index]
		local position = starts[index]
		assert(Spacing.clear(position, position, self.list), "Shopper spawn needs room between R6 rigs")
		local model = shopperModel(parent, index, position + origin, random, look)
		local trip = self.trips[random:NextInteger(1, #self.trips)]
		table.insert(self.list, {
			model = model, position = position, route = {}, routeIndex = 1, trip = trip, visitIndex = random:NextInteger(1, #trip - 1),
			facing = Vector3.new(0, 0, -1), planAt = now + index * .019, restUntil = now + 2.5 + (index % 5) * .25,
		})
	end
	return self
end

function Shoppers:plan(shopper, now, workers, byPlayer, catch)
	local worker = byPlayer[shopper.following]
	if not worker and now >= shopper.restUntil then
		local nearest = self.range
		for _, candidate in workers do
			local gap = (candidate.position - shopper.position).Magnitude
			local player = candidate.player
			if candidate.eligible and not self.chasers[player] and now >= (self.chaseCooldowns[player] or 0)
				and gap < nearest and AisleRoutes.inStore(candidate.position) then
				worker, nearest = candidate, gap
			end
		end
		if worker then
			shopper.following, shopper.chaseUntil = worker.player, now + Config.ChaseSeconds
			self.chasers[worker.player] = shopper
		end
	end

	local destination
	if worker then
		local distance = (worker.position - shopper.position).Magnitude
		-- Walls near a worker can block a straight path. Approach from the open aisle.
		if distance <= 4.35 then
			local lines = scenes[self.random:NextInteger(1, #scenes)]
			local stopped, missed = catch(worker.player, shopper, lines, now)
			if stopped then
				worker.eligible = false
				releaseChase(self, shopper, now)
				return
			elseif missed then
				worker.eligible, worker = false, nil
				releaseChase(self, shopper, now)
			end
		end
		if worker then
			destination = self.routes:approach(shopper.position, worker.position)
			if not destination then releaseChase(self, shopper, now) end
		end
	end
	if destination then shopper.browseUntil = nil end
	destination = destination or shoppingTarget(self, shopper, now)
	if not destination then
		shopper.route, shopper.routeIndex, shopper.plannedDestination = {}, 1, nil
	elseif self.routes:clear(shopper.position, destination) then
		shopper.route, shopper.routeIndex, shopper.plannedDestination = { destination }, 1, destination
	elseif shopper.routeIndex > #shopper.route or not shopper.plannedDestination
		or (destination - shopper.plannedDestination).Magnitude > 3.6 then
		shopper.route = self.routes:trace(shopper.position, destination)
		shopper.routeIndex, shopper.plannedDestination = 1, destination
	end
	shopper.planAt = now + .28 + self.random:NextNumber(0, .15)
end

local turns = { .7, -.7, 1.22, -1.22, 1.57, -1.57 }
local function sidestep(self, shopper, direction, distance)
	local start = shopper.position
	for _, angle in turns do
		local cos, sin = math.cos(angle), math.sin(angle)
		local offset = Vector3.new(direction.X * cos - direction.Z * sin, 0, direction.X * sin + direction.Z * cos)
		local point = start + offset * distance
		if AisleRoutes.inAisles(point) and Spacing.clear(start, point, self.list, shopper)
			and self.routes:clear(start, point) then
			shopper.position, shopper.facing = point, offset
			return true
		end
	end
	return false
end

local function move(self, shopper, remaining)
	local moved = false
	while remaining > .002 do
		local target = shopper.route[shopper.routeIndex]
		if not target then break end
		local start = shopper.position
		local delta = target - start
		local distance = delta.Magnitude
		if distance < .002 then
			shopper.routeIndex += 1
			continue
		end
		local direction = delta / distance
		local stride = math.min(distance, remaining)
		local nextPoint = start + direction * stride
		local open = Spacing.clear(start, nextPoint, self.list, shopper)
		if not open or not Spacing.clear(start, start + direction * math.max(stride, 1.05), self.list, shopper, Spacing.Comfort) then
			if sidestep(self, shopper, direction, stride) then
				-- Recheck the path after moving off the original aisle segment.
				shopper.plannedDestination = nil
				return true
			end
			if not open then break end
		end
		if not self.routes:clear(start, nextPoint) then
			shopper.plannedDestination = nil
			break
		end
		shopper.position, shopper.facing = nextPoint, direction
		moved = true
		remaining -= stride
		if stride >= distance then shopper.routeIndex += 1 end
	end
	return moved
end

function Shoppers:step(dt, now, workers, catch)
	local byPlayer = {}
	for _, worker in workers do byPlayer[worker.player] = worker end
	for player, shopper in self.chasers do
		local worker = byPlayer[player]
		if not worker or not worker.eligible or now >= shopper.chaseUntil or not AisleRoutes.inStore(worker.position)
			or (worker.position - shopper.position).Magnitude > self.range + 7 then
			releaseChase(self, shopper, now)
		end
	end
	local count = #self.list
	local first = self.first or 0
	for index = 0, count - 1 do
		local shopper = self.list[(first + index) % count + 1]
		if shopper.speaking then continue end
		if now >= shopper.planAt then self:plan(shopper, now, workers, byPlayer, catch) end
		if shopper.speaking then continue end
		local speed = if shopper.following then self.speed + Config.ChaseSpeedBoost else self.speed * .63
		if move(self, shopper, speed * dt) or shopper.routeIndex > #shopper.route then
			shopper.waitingSince = nil
		else
			shopper.waitingSince = shopper.waitingSince or now
			if not shopper.following and now - shopper.waitingSince > 2 then
				visitNext(self, shopper)
				shopper.waitingSince, shopper.plannedDestination, shopper.planAt = nil, nil, now
			end
		end
		pose(shopper, self.origin)
	end
	self.first = if count > 0 then (first + 1) % count else 0
end

return Shoppers
