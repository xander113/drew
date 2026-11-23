local TweenService = game:GetService("TweenService")
local CartSpawns = require(script.Parent.CartSpawns)

local Carts = {}
Carts.__index = Carts

local BLUE = Color3.fromRGB(0, 87, 210)
local METAL = Color3.fromRGB(164, 184, 200)
local TIRE = Color3.fromRGB(28, 44, 66)
local GOLD = Color3.fromRGB(255, 205, 60)
local HUB = Color3.fromRGB(210, 225, 239)
local v = Vector3.new

local function build(parent, frame)
	local model = Instance.new("Model")
	model.Name = "Shopping Cart"

	local structure = {}
	local function piece(base, name, size, offset, color, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = frame * CFrame.new(offset)
		part.Color = color
		part.Material = if color == METAL or color == HUB then Enum.Material.Metal else Enum.Material.SmoothPlastic
		part.Shape = shape or Enum.PartType.Block
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow, part.Massless = false, false, false, false, true
		part.Parent = model
		if base then table.insert(structure, { base = base, part = part }) end
		return part
	end

	local root = piece(nil, "Chassis", v(2.43, .14, 3.55), v(0, .68, 0), BLUE)
	root.Transparency = 1
	model.PrimaryPart = root

	local runners, braces = {}, {}
	for side = -1, 1, 2 do
		local runner = piece(root, "Steel Runner", v(.17, .16, 3.4), v(side * 1.08, .7, .08), METAL)
		runners[side] = runner
		braces[side] = piece(runner, "Basket Brace", v(.19, .70, .20), v(side * 1.1, 1.08, -.92), METAL)
	end
	piece(runners[1], "Lower Shelf", v(2.13, .095, 2.45), v(0, .82, .03), METAL).Transparency = .36
	local basket = piece(braces[1], "Basket Floor", v(2.5, .15, 2.85), v(0, 1.44, -.16), METAL)
	local frontGrid = piece(basket, "Front Grid", v(2.5, .95, .055), v(0, 1.96, -1.61), METAL)
	frontGrid.Transparency = .62
	piece(frontGrid, "Front Rim", v(2.66, .16, .17), v(0, 2.48, -1.62), BLUE)
	piece(frontGrid, "Front Grid Rail", v(2.54, .06, .085), v(0, 1.93, -1.635), HUB)
	local gate = piece(basket, "Rear Gate", v(2.48, .93, .07), v(0, 1.96, 1.23), METAL)
	gate.Transparency = .52
	piece(gate, "Rear Rim", v(2.66, .16, .17), v(0, 2.48, 1.23), BLUE)
	piece(gate, "Gate Hinge", v(1.63, .12, .11), v(0, 2.39, 1.29), HUB)

	for side = -1, 1, 2 do
		local runner = runners[side]
		local sideWall = piece(basket, "Side Grid", v(.055, .96, 2.79), v(side * 1.25, 1.95, -.17), METAL)
		sideWall.Transparency = .60
		piece(sideWall, "Side Rim", v(.16, .16, 2.96), v(side * 1.27, 2.48, -.2), BLUE)
		piece(sideWall, "Side Grid Rail", v(.085, .06, 2.79), v(side * 1.26, 1.91, -.17), HUB)
		for _, z in { -1.56, 1.20 } do
			piece(basket, "Basket Corner", v(.12, 1.02, .12), v(side * 1.25, 1.96, z), METAL)
		end
		local post = piece(runner, "Handle Upright", v(.14, 2.02, .16), v(side * 1.24, 1.66, 1.61), METAL)
		local sleeve = piece(post, "Handle Sleeve", v(.20, .28, .25), v(side * 1.24, 2.64, 1.67), BLUE)
		if side > 0 then piece(sleeve, "Grip", v(3.04, .23, .25), v(0, 2.65, 1.76), GOLD) end

		for _, z in { -1.25, 1.25 } do
			local fork = piece(runner, "Caster Fork", v(.42, .38, .23), v(side * 1.1, .57, z), METAL)
			local wheel = piece(fork, "Rubber Wheel", v(.31, .71, .71), v(side * 1.14, .355, z), TIRE, Enum.PartType.Cylinder)
			piece(wheel, "Wheel Hub", v(.075, .32, .32), v(side * 1.31, .355, z), HUB, Enum.PartType.Cylinder)
		end
	end
	local plate = piece(frontGrid, "WWMS Plate", v(.88, .29, .075), v(0, 2.19, -1.66), BLUE)
	local lettering = Instance.new("SurfaceGui")
	lettering.Name, lettering.Face, lettering.MaxDistance = "WWMS", Enum.NormalId.Front, 20
	lettering.CanvasSize, lettering.Parent = Vector2.new(110, 38), plate
	local logo = Instance.new("TextLabel")
	logo.Size, logo.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	logo.Font, logo.Text, logo.TextColor3, logo.TextScaled = Enum.Font.FredokaOne, "WWMS", GOLD, true
	logo.Parent = lettering

	local prompt = Instance.new("ProximityPrompt")
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
	beacon.MaxDistance = 54
	beacon.AlwaysOnTop = false
	beacon.Parent = root
	local marker = Instance.new("TextLabel")
	marker.Size, marker.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	marker.Font, marker.TextSize, marker.Text = Enum.Font.FredokaOne, 18, "!"
	marker.TextColor3, marker.TextStrokeTransparency = GOLD, .36
	marker.Parent = beacon

	model.Parent = parent
	return model, prompt, structure
end

function Carts.new(parent, layout, random, onPickup, count, origin)
	local self = setmetatable({ items = {} }, Carts)
	for _, position in CartSpawns.pick(layout, random, count) do
		local frame = CFrame.new(position + origin) * CFrame.Angles(0, math.rad(random:NextInteger(-35, 35)), 0)
		local model, prompt, structure = build(parent, frame)
		local item = { model = model, parked = model:GetPivot(), prompt = prompt, structure = structure }
		table.insert(self.items, item)
		prompt.Triggered:Connect(function(player)
			onPickup(player, item)
		end)
	end
	return self
end

local function attachBasket(item)
	local welds = {}
	for index, link in item.structure do
		local weld = Instance.new("WeldConstraint")
		weld.Name, weld.Part0, weld.Part1 = "Cart Link", link.base, link.part
		weld.Parent = link.part
		welds[index] = weld
	end
	for _, link in item.structure do link.part.Anchored = false end
	item.welds = welds
end

local function parkBasket(item)
	for _, link in item.structure do link.part.Anchored = true end
	for _, weld in item.welds do weld:Destroy() end
	item.welds = nil
end

function Carts:claim(item, player, characterRoot, groundOffset, now)
	local model = item.model
	local root = model.PrimaryPart
	item.carrier = player
	item.prompt.Enabled, root.CartMarker.Enabled = false, false
	model:SetAttribute("GrabFrom", root.CFrame)
	model:SetAttribute("GrabAt", now)
	local joint = Instance.new("Motor6D")
	joint.Name = "PushJoint"
	joint.Part0, joint.Part1 = characterRoot, root
	joint.C0 = CFrame.new(0, .68 - groundOffset, -3.3)
	model:PivotTo(characterRoot.CFrame * joint.C0)
	attachBasket(item)
	joint.Parent = root
	root.Anchored = false
	model:AddTag("WWMSPushedCart")
	item.joint = joint
end

function Carts:release(item, dock)
	local model = item.model
	local root = model.PrimaryPart
	local from = root.CFrame
	model:RemoveTag("WWMSPushedCart")
	if item.joint then item.joint:Destroy() end
	item.joint, item.carrier = nil, nil
	root.Anchored = true
	model:PivotTo(from)
	if not dock then
		parkBasket(item)
		model:PivotTo(item.parked)
		item.prompt.Enabled, root.CartMarker.Enabled = true, true
		return
	end

	local destination = CFrame.lookAt(dock, dock + Vector3.zAxis)
	local hop = TweenService:Create(root, TweenInfo.new(.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = destination + Vector3.new(0, 1.05, 0),
	})
	hop:Play()
	task.delay(.26, function()
		if not model.Parent then return end
		TweenService:Create(root, TweenInfo.new(.34, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = destination - Vector3.new(0, 2.75, 0),
		}):Play()
	end)
	task.delay(.64, function()
		if model.Parent then model:Destroy() end
		item.model = nil
	end)
end

function Carts:destroy()
	for _, item in self.items do
		if item.model then item.model:Destroy() end
	end
	table.clear(self.items)
end

return Carts
