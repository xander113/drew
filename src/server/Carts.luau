local Carts = {}
Carts.__index = Carts

local BLUE = Color3.fromRGB(0, 105, 226)
local METAL = Color3.fromRGB(164, 184, 200)
local TIRE = Color3.fromRGB(28, 44, 66)
local GOLD = Color3.fromRGB(255, 205, 60)

local function build(parent, frame, withPrompt)
	local model = Instance.new("Model")
	model.Name = "Shopping Cart"

	local function piece(name, size, offset, color, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = frame * CFrame.new(offset)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Shape = shape or Enum.PartType.Block
		part.Anchored = withPrompt
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.Parent = model
		return part
	end

	local root = piece("Chassis", Vector3.new(2.45, .15, 3.55), Vector3.new(0, .68, 0), BLUE)
	model.PrimaryPart = root
	piece("Basket Base", Vector3.new(2.55, .14, 2.85), Vector3.new(0, 1.48, -.17), METAL)
	piece("Handle", Vector3.new(3.05, .26, .26), Vector3.new(0, 2.65, 1.76), GOLD)
	piece("Front Lip", Vector3.new(2.7, .21, .2), Vector3.new(0, 2.43, -1.65), BLUE)
	piece("Back Lip", Vector3.new(2.7, .21, .2), Vector3.new(0, 2.43, 1.23), BLUE)
	piece("Front Mesh", Vector3.new(2.52, .84, .08), Vector3.new(0, 1.92, -1.64), METAL).Transparency = .48
	piece("Back Mesh", Vector3.new(2.52, .84, .08), Vector3.new(0, 1.92, 1.22), METAL).Transparency = .48
	for sign = -1, 1, 2 do
		piece("Tire", Vector3.new(.31, .79, .79), Vector3.new(sign * 1.16, .39, -1.27), TIRE, Enum.PartType.Cylinder)
		piece("Tire", Vector3.new(.31, .79, .79), Vector3.new(sign * 1.16, .39, 1.23), TIRE, Enum.PartType.Cylinder)
		piece("Upright", Vector3.new(.13, 2.04, .15), Vector3.new(sign * 1.22, 1.63, 1.66), METAL)
		piece("Basket Side", Vector3.new(.08, .86, 2.91), Vector3.new(sign * 1.27, 1.94, -.18), METAL).Transparency = .45
		piece("Side Rail", Vector3.new(.18, .21, 3), Vector3.new(sign * 1.28, 2.43, -.18), BLUE)
	end

	local prompt
	if withPrompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Grab cart"
		prompt.ObjectText = "Shopping cart"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = true
		prompt.Parent = root
		local beacon = Instance.new("BillboardGui")
		beacon.Name = "CartMarker"
		beacon.Size = UDim2.fromOffset(18, 18)
		beacon.StudsOffsetWorldSpace = Vector3.new(0, 3.05, 0)
		beacon.MaxDistance = 92
		beacon.AlwaysOnTop = false
		beacon.Parent = root
		local diamond = Instance.new("Frame")
		diamond.AnchorPoint, diamond.Position = Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
		diamond.Size = UDim2.fromOffset(10, 10)
		diamond.Rotation, diamond.BorderSizePixel, diamond.BackgroundColor3 = 45, 0, GOLD
		diamond.Parent = beacon
	else
		for _, part in model:GetChildren() do
			if part ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = root, part
				weld.Parent = part
			end
		end
	end

	model.Parent = parent
	return model, prompt
end

local function shuffle(random, items)
	for index = #items, 2, -1 do
		local other = random:NextInteger(1, index)
		items[index], items[other] = items[other], items[index]
	end
end

function Carts.new(parent, layout, random, onPickup, count, goal, origin)
	local self = setmetatable({ items = {}, parent = parent }, Carts)
	local front = {}
	for _, position in {
		Vector3.new(-51, 0, 43), Vector3.new(-45, 0, 42), Vector3.new(-38, 0, 43),
		Vector3.new(-31, 0, 39), Vector3.new(-26, 0, 43), Vector3.new(-18, 0, 46),
		Vector3.new(-42, 0, 31), Vector3.new(-21, 0, 34), Vector3.new(-56, 0, 36),
		Vector3.new(-49, 0, 32), Vector3.new(-28, 0, 33), Vector3.new(-14, 0, 38),
	} do
		table.insert(front, position)
	end
	local frontAisles, middle, far = {}, {}, {}
	for lane, x in layout.LaneX do
		for _, z in layout.CartZ do
			local position = Vector3.new(x + (lane % 2 == 0 and 3.1 or -3.1), 0, z)
			local pool = if z < -17 then far elseif x < 3 and z >= 19 then frontAisles else middle
			table.insert(pool, position)
		end
	end
	shuffle(random, front)
	shuffle(random, frontAisles)
	shuffle(random, middle)
	shuffle(random, far)
	local nearCount = math.min(#front, math.ceil(goal * .65))
	local positions = {}
	for index = 1, nearCount do table.insert(positions, front[index]) end
	for index = 1, math.min(#frontAisles, math.ceil(goal * .45)) do table.insert(positions, frontAisles[index]) end
	for _, position in middle do table.insert(positions, position) end
	for index = nearCount + 1, #front do table.insert(positions, front[index]) end
	for index = math.ceil(goal * .45) + 1, #frontAisles do table.insert(positions, frontAisles[index]) end
	for _, position in far do table.insert(positions, position) end
	-- Reserve some carts for the back aisles on every shift.
	local backCount = math.min(#far, math.max(2, math.floor(count * .22)))
	for index = 1, count do
		local position = if index > count - backCount then far[index - count + backCount] else positions[index]
		local frame = CFrame.new(position + origin) * CFrame.Angles(0, math.rad(random:NextInteger(-35, 35)), 0)
		local model, prompt = build(parent, frame, true)
		local item = { model = model, carrier = nil, pushed = nil, prompt = prompt }
		table.insert(self.items, item)
		prompt.Triggered:Connect(function(player)
			onPickup(player, item)
		end)
	end
	return self
end

function Carts:claim(item, player, characterRoot, groundOffset)
	item.carrier = player
	item.prompt.Enabled = false
	item.model.Parent = nil
	local model = build(nil, characterRoot.CFrame * CFrame.new(0, -groundOffset, -3.5), false)
	local joint = Instance.new("WeldConstraint")
	joint.Part0, joint.Part1 = characterRoot, model.PrimaryPart
	joint.Parent = model.PrimaryPart
	item.pushed = model
	model.Parent = self.parent
end

function Carts:release(item, returned)
	if item.pushed then
		item.pushed:Destroy()
		item.pushed = nil
	end
	item.carrier = nil
	if returned then
		item.model:Destroy()
		item.model = nil
	else
		item.model.Parent = self.parent
		item.prompt.Enabled = true
	end
end

function Carts:destroy()
	for _, item in self.items do
		if item.pushed then item.pushed:Destroy() end
		if item.model then item.model:Destroy() end
	end
	table.clear(self.items)
end

return Carts
