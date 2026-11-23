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
	shopper.following, shopper.plannedDestination, shopper.pass = nil, nil, nil
	shopper.blockedAt, shopper.nextPass = nil, nil
	shopper.route, shopper.routeIndex, shopper.planAt = {}, 1, now
	shopper.restUntil = math.max(shopper.restUntil, now + 1.75)
end

function Shoppers:cancelChase(player, now)
	local shopper = self.chasers[player]
	if shopper then releaseChase(self, shopper, now) end
end

function Shoppers:stop(shopper, workerPosition, now)
	releaseChase(self, shopper, now)
	shopper.pass, shopper.speaking = nil, true
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
	shopper.following, shopper.plannedDestination, shopper.pass = nil, nil, nil
	shopper.blockedAt, shopper.nextPass = nil, nil
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
			id = index, model = model, position = position, route = {}, routeIndex = 1, trip = trip, visitIndex = random:NextInteger(1, #trip - 1),
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

local function openGround(self, start, finish)
	return AisleRoutes.inAisles(finish) and self.routes:clear(start, finish)
end

local function makePass(self, shopper, blocker, now)
	local start, target = shopper.position, shopper.route[shopper.routeIndex]
	local offset = target - start
	local forward = offset.Unit
	local side = Vector3.new(-forward.Z, 0, forward.X)
	local across = (blocker.position - start):Dot(side)
	local ahead = (blocker.position - start):Dot(forward)
	local gap = Spacing.Clearance
	local length = math.min(offset.Magnitude, ahead + gap + .5)
	if length < .5 or (target - blocker.position).Magnitude < gap then return nil end

	local function try(laneOffset, full)
		local entry = start + side * laneOffset
		local exit = entry + forward * length
		if math.abs(laneOffset) < .08 or not openGround(self, start, entry) or not openGround(self, entry, exit)
			or not Spacing.clear(start, entry, self.list, shopper) then return nil end
		if full and not Spacing.clear(entry, exit, self.list, shopper) then return nil end
		return { points = { entry, exit }, index = 1, expires = now + 3.6 }
	end

	-- Keep to the same side until past the other shopper. Two people facing
	-- each other each take a little over half the space in a narrow aisle.
	return try(across + gap + .10, true) or try(across - gap - .10, true)
		or try(gap * .54, false) or try(-gap * .54, false)
end

local function move(self, shopper, remaining, points, index)
	while remaining > .002 do
		local target = points[index]
		if not target then break end
		local start = shopper.position
		local delta = target - start
		local distance = delta.Magnitude
		if distance < .002 then
			index += 1
			continue
		end
		local direction = delta / distance
		local stride = math.min(distance, remaining)
		local finish = if stride == distance then target else start + direction * stride
		if not openGround(self, start, finish) then return index, nil, true end
		local clear, blocker = Spacing.clear(start, finish, self.list, shopper)
		if not clear then return index, blocker, false end
		shopper.position, shopper.facing = finish, direction
		remaining -= stride
		if stride == distance then index += 1 end
	end
	return index, nil, false
end

local function changeVisit(self, shopper, now)
	if shopper.following then
		releaseChase(self, shopper, now)
	else
		visitNext(self, shopper)
	end
	shopper.pass, shopper.blockedAt, shopper.nextPass = nil, nil, nil
	shopper.route, shopper.routeIndex, shopper.plannedDestination, shopper.planAt = {}, 1, nil, now
end

local function walk(self, shopper, stride, now)
	local pass = shopper.pass
	if pass then
		local start = shopper.position
		local index, _, wall = move(self, shopper, stride, pass.points, pass.index)
		pass.index = index
		if start ~= shopper.position then pass.waitSince = nil else pass.waitSince = pass.waitSince or now end
		if pass.index > #pass.points then
			shopper.pass, shopper.blockedAt, shopper.nextPass = nil, nil, nil
			if pass.retreat then changeVisit(self, shopper, now) end
			shopper.route, shopper.routeIndex, shopper.plannedDestination, shopper.planAt = {}, 1, nil, now
		elseif wall or now >= pass.expires or (pass.waitSince and now - pass.waitSince >= 1.1) then
			changeVisit(self, shopper, now)
		end
		return
	end

	local blocker, wall
	shopper.routeIndex, blocker, wall = move(self, shopper, stride, shopper.route, shopper.routeIndex)
	if wall then shopper.plannedDestination, shopper.planAt = nil, now end
	if not blocker then
		shopper.blockedAt, shopper.nextPass = nil, nil
		return
	end
	shopper.blockedAt = shopper.blockedAt or now
	if now < (shopper.nextPass or 0) then return end
	shopper.nextPass = now + .23
	shopper.pass = makePass(self, shopper, blocker, now)
	if shopper.pass or now - shopper.blockedAt < .8 then return end

	-- In a single-file gap, only one of the two shoppers backs out.
	local direction = (shopper.route[shopper.routeIndex] - shopper.position).Unit
	if blocker.speaking or shopper.id > blocker.id then
		local retreat = shopper.position - direction * 6
		if openGround(self, shopper.position, retreat) and Spacing.clear(shopper.position, retreat, self.list, shopper) then
			shopper.pass = { points = { retreat }, index = 1, expires = now + 2.4, retreat = true }
			return
		end
	end
	if now - shopper.blockedAt >= 1.65 then changeVisit(self, shopper, now) end
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
		walk(self, shopper, speed * dt, now)
		pose(shopper, self.origin)
	end
	self.first = if count > 0 then (first + 1) % count else 0
end

return Shoppers
