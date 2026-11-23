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
end

function Shoppers.new(parent, layout, random, count, speed, now, origin, range)
	local self = setmetatable({ list = {}, random = random, routes = AisleRoutes.new(layout), speed = speed, origin = origin, range = range }, Shoppers)
	local starts = table.clone(self.routes.patrol)
	for index = 1, count do
		local chosen = random:NextInteger(index, #starts)
		starts[index], starts[chosen] = starts[chosen], starts[index]
		local position = starts[index]
		local model = shopperModel(parent, index, position + origin, random)
		table.insert(self.list, {
			model = model, position = position, route = {}, routeIndex = 1,
			facing = Vector3.new(0, 0, -1), patrol = nil, plannedDestination = nil, planAt = now + index * .019,
			restUntil = now + 2.5 + (index % 5) * .25,
		})
	end
	return self
end

function Shoppers:step(dt, now, workers, catch)
	for _, shopper in self.list do
		if shopper.speaking then continue end
		if now >= shopper.planAt then
			local nearest, distance = nil, self.range
			if now >= shopper.restUntil then
				for _, worker in workers do
					local delta = worker.position - shopper.position
					local gap = delta.Magnitude
					if worker.position.Z <= 46 and gap < distance and worker.eligible then
						nearest, distance = worker, gap
					end
				end
			end
			if nearest and distance <= 4.35 and self.routes:clear(shopper.position, nearest.position) then
				local lines = scenes[self.random:NextInteger(1, #scenes)]
				if catch(nearest.player, shopper, lines, now) then
					nearest.eligible = false
					continue
				end
				nearest = nil
			end
			local destination
			if nearest then
				destination = nearest.position
			else
				if not shopper.patrol or (shopper.patrol - shopper.position).Magnitude < 2 then
					local nodes = self.routes.patrol
					shopper.patrol = nodes[self.random:NextInteger(1, #nodes)]
				end
				destination = shopper.patrol
			end
			local planExpired = shopper.routeIndex > #shopper.route
			local destinationMoved = not shopper.plannedDestination or (destination - shopper.plannedDestination).Magnitude > 9
			if destinationMoved or planExpired or self.routes:clear(shopper.position, destination) then
				shopper.route = self.routes:trace(shopper.position, destination)
				shopper.routeIndex = 1
				shopper.plannedDestination = destination
			end
			shopper.planAt = now + .30 + self.random:NextNumber(0, .10)
		end

		local target = shopper.route[shopper.routeIndex]
		while target and (target - shopper.position).Magnitude < .11 do
			shopper.routeIndex += 1
			target = shopper.route[shopper.routeIndex]
		end
		if target then
			local delta = target - shopper.position
			local distance = math.min(delta.Magnitude, self.speed * dt * (now < shopper.restUntil and .65 or 1))
			local facing = delta.Unit
			shopper.position += facing * distance
			shopper.facing = facing
		end

		pose(shopper, self.origin)
	end
end

return Shoppers
