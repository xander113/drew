local AisleRoutes = require(script.Parent.AisleRoutes)

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
local shirts = { rgb(210, 84, 64), rgb(64, 146, 98), rgb(143, 106, 190), rgb(244, 172, 80), rgb(81, 141, 190), rgb(207, 107, 147) }
local skins = { rgb(239, 188, 151), rgb(171, 112, 77), rgb(120, 77, 65), rgb(242, 208, 175) }
local hair = { rgb(58, 43, 55), rgb(84, 55, 40), rgb(218, 153, 70), rgb(222, 221, 207) }
local shoes = rgb(30, 49, 78)

local function shopperModel(parent, id, position)
	local model = rig:Clone()
	model.Name = names[(id - 1) % #names + 1]
	local shirt = shirts[(id - 1) % #shirts + 1]
	local skin = skins[(id - 1) % #skins + 1]
	local style = (id - 1) % 4
	for _, limb in model:GetChildren() do
		if limb:IsA("BasePart") then
			limb.CanCollide, limb.CanTouch, limb.CanQuery = false, false, false
			limb.CastShadow = true
			limb.Massless = limb ~= model.PrimaryPart
			limb.Color = if limb.Name == "Torso" then shirt elseif string.find(limb.Name, "Leg") then shoes else skin
		end
	end
	model.PrimaryPart.Anchored = true
	model.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model.Humanoid.EvaluateStateMachine = false

	local head = model.Head
	local function wear(name, size, at, color)
		local piece = Instance.new("Part")
		piece.Name, piece.Size, piece.CFrame, piece.Color = name, size, head.CFrame * CFrame.new(at), color
		piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
		piece.Massless = true
		piece.Parent = head
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = head, piece, piece
	end
	local hairColor = hair[(id - 1) % #hair + 1]
	wear("Hair", Vector3.new(1.36, .29, 1.16), Vector3.new(0, .56, .04), hairColor)
	if style == 0 then
		wear("Cap", Vector3.new(1.45, .24, 1.19), Vector3.new(0, .65, .02), shirt)
		wear("Cap Brim", Vector3.new(1.10, .09, .58), Vector3.new(0, .55, -.67), shirt)
	elseif style == 1 then
		wear("Hair Back", Vector3.new(1.28, .97, .24), Vector3.new(0, .21, .53), hairColor)
	elseif style == 2 then
		local dark = rgb(45, 57, 82)
		wear("Glasses Bridge", Vector3.new(.88, .085, .07), Vector3.new(0, .11, -.64), dark)
		for _, x in { -.28, .28 } do
			wear("Glasses Frame", Vector3.new(.39, .26, .09), Vector3.new(x, .11, -.67), dark)
			wear("Lens", Vector3.new(.28, .15, .04), Vector3.new(x, .11, -.716), rgb(136, 187, 214))
		end
	else
		wear("Hair Bun", Vector3.new(.67, .56, .55), Vector3.new(.29, .73, .39), hairColor)
	end
	model:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	model.Parent = parent
	local joints = {}
	for _, jointName in { "Left Hip", "Right Hip", "Left Shoulder", "Right Shoulder" } do
		local motor = model.Torso[jointName]
		joints[jointName] = { motor = motor, rest = motor.C0 }
	end
	return model, joints
end

local function turn(binding, angle, yaw)
	binding.motor.C0 = CFrame.new(binding.rest.Position) * CFrame.Angles(angle, yaw or 0, 0) * binding.rest.Rotation
end

local function pose(shopper, origin, swing)
	local position = shopper.position + origin + Vector3.new(0, 3, 0)
	shopper.model:PivotTo(CFrame.lookAt(position, position + shopper.facing))
	local joints = shopper.joints
	turn(joints["Left Hip"], swing)
	turn(joints["Right Hip"], -swing)
	turn(joints["Left Shoulder"], -swing)
	turn(joints["Right Shoulder"], swing + (shopper.speaking and .34 or 0))
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
	pose(shopper, self.origin, 0)
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
		local model, joints = shopperModel(parent, index, position + origin)
		table.insert(self.list, {
			model = model, joints = joints, position = position, route = {}, routeIndex = 1,
			facing = Vector3.new(0, 0, -1), patrol = nil, plannedDestination = nil, planAt = now + index * .019,
			restUntil = now + 2.5 + (index % 5) * .25, stride = 0,
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
			shopper.stride += distance * 2
			shopper.facing = facing
		end

		pose(shopper, self.origin, if target then math.sin(shopper.stride) * .45 else 0)
	end
end

return Shoppers
