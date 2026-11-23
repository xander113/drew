local AisleRoutes = require(script.Parent.AisleRoutes)

local Shoppers = {}
Shoppers.__index = Shoppers

local QUESTIONS = {
	"Excuse me! Where's the oat milk?",
	"Is this price for two?",
	"Do you work here?",
	"Which aisle has batteries?",
	"Can I return a toaster here?",
	"Where did the cereal go?",
	"Is register three open?",
}

local COLORS = {
	Color3.fromRGB(224, 130, 89), Color3.fromRGB(100, 155, 132),
	Color3.fromRGB(150, 114, 190), Color3.fromRGB(205, 112, 142),
	Color3.fromRGB(223, 168, 85), Color3.fromRGB(106, 154, 200),
}

local SKIN = {
	Color3.fromRGB(234, 181, 142), Color3.fromRGB(172, 115, 82),
	Color3.fromRGB(121, 77, 65), Color3.fromRGB(244, 204, 173),
}

local INK = Color3.fromRGB(34, 49, 75)
local GOLD = Color3.fromRGB(255, 220, 104)

local function shopperModel(parent, id, position)
	local model = Instance.new("Model")
	model.Name = "Shopper " .. id
	local shirt = COLORS[(id - 1) % #COLORS + 1]
	local skin = SKIN[(id - 1) % #SKIN + 1]

	local function part(name, size, offset, color)
		local item = Instance.new("Part")
		item.Name, item.Size, item.Color = name, size, color
		item.CFrame = CFrame.new(position + offset)
		item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
		item.CastShadow = false
		item.Parent = model
		return item
	end

	local root = part("Root", Vector3.one, Vector3.zero, INK)
	root.Transparency = 1
	model.PrimaryPart = root
	part("Torso", Vector3.new(1.52, 1.55, .88), Vector3.new(0, 2.25, 0), shirt)
	local head = part("Head", Vector3.new(1.15, 1.06, .93), Vector3.new(0, 3.52, 0), skin)
	part("Hair", Vector3.new(1.21, .28, .96), Vector3.new(0, 4.01, 0), INK)
	part("Eyes", Vector3.new(.48, .12, .033), Vector3.new(0, 3.58, -.48), INK)
	local limbs = {}
	for _, side in { -1, 1 } do
		local arm = part("Arm", Vector3.new(.47, 1.37, .65), Vector3.new(side * 1.0, 2.29, 0), shirt)
		local leg = part("Leg", Vector3.new(.60, 1.40, .68), Vector3.new(side * .4, .77, 0), INK)
		table.insert(limbs, { arm = arm, leg = leg, side = side })
	end

	local indicator = Instance.new("BillboardGui")
	indicator.Name = "QuestionMark"
	indicator.Size = UDim2.fromOffset(28, 32)
	indicator.StudsOffsetWorldSpace = Vector3.new(0, 1.08, 0)
	indicator.MaxDistance = 70
	indicator.Parent = head
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize, label.Text = Enum.Font.GothamBlack, 24, "?"
	label.TextColor3, label.TextStrokeTransparency = GOLD, .36
	label.Parent = indicator

	model.Parent = parent
	return model, limbs
end

function Shoppers.new(parent, layout, random, count, speed, now)
	local self = setmetatable({ list = {}, random = random, routes = AisleRoutes.new(layout), speed = speed }, Shoppers)
	local nodes = self.routes.nodes
	local offset = random:NextInteger(1, #nodes)
	for index = 1, count do
		local position = nodes[(offset + index * 5) % #nodes + 1]
		local model, limbs = shopperModel(parent, index, position)
		table.insert(self.list, {
			model = model, limbs = limbs, position = position, route = {}, routeIndex = 1,
			facing = Vector3.new(0, 0, -1), patrol = nil, plannedDestination = nil, planAt = now + index * .019,
			restUntil = 0, stride = 0,
		})
	end
	return self
end

function Shoppers:step(dt, now, workers, catch)
	for _, shopper in self.list do
		if now >= shopper.planAt then
			local nearest, distance = nil, 34
			if now >= shopper.restUntil then
				for _, worker in workers do
					local delta = worker.position - shopper.position
					local gap = delta.Magnitude
					if worker.position.Z <= 46 and gap < distance and worker.eligible then
						nearest, distance = worker, gap
					end
				end
			end
			if nearest and distance <= 4.6 and self.routes:clear(shopper.position, nearest.position) then
				local question = QUESTIONS[self.random:NextInteger(1, #QUESTIONS)]
				if catch(nearest.player, question, now) then
					nearest.eligible = false
					shopper.restUntil = now + 4
					nearest = nil
				end
			end
			local destination
			if nearest then
				destination = nearest.position
			else
				if not shopper.patrol or (shopper.patrol - shopper.position).Magnitude < 2 then
					local nodes = self.routes.nodes
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

		local pose = CFrame.lookAt(shopper.position, shopper.position + shopper.facing)
		shopper.model:PivotTo(pose)
		local swing = if target then math.sin(shopper.stride) * .40 else 0
		for _, limb in shopper.limbs do
			limb.leg.CFrame = pose * CFrame.new(limb.side * .4, 1.41, 0) * CFrame.Angles(swing * limb.side, 0, 0) * CFrame.new(0, -.64, 0)
			limb.arm.CFrame = pose * CFrame.new(limb.side, 2.88, 0) * CFrame.Angles(-swing * limb.side, 0, 0) * CFrame.new(0, -.59, 0)
		end
	end
end

return Shoppers
