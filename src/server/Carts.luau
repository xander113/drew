local TweenService = game:GetService("TweenService")
local CartSpawns = require(script.Parent.CartSpawns)

local Carts = {}
Carts.__index = Carts

local BLUE = Color3.fromRGB(0, 105, 226)
local METAL = Color3.fromRGB(164, 184, 200)
local TIRE = Color3.fromRGB(28, 44, 66)
local GOLD = Color3.fromRGB(255, 205, 60)

local function build(parent, frame)
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
		part.Anchored = true
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
	root.Anchored = true
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
	return model, prompt
end

function Carts.new(parent, layout, random, onPickup, count, origin)
	local self = setmetatable({ items = {} }, Carts)
	for _, position in CartSpawns.pick(layout, random, count) do
		local frame = CFrame.new(position + origin) * CFrame.Angles(0, math.rad(random:NextInteger(-35, 35)), 0)
		local model, prompt = build(parent, frame)
		local item = { model = model, parked = model:GetPivot(), prompt = prompt }
		table.insert(self.items, item)
		prompt.Triggered:Connect(function(player)
			onPickup(player, item)
		end)
	end
	return self
end

local function attachBasket(item)
	local root = item.model.PrimaryPart
	local welds = {}
	for _, piece in item.model:GetChildren() do
		if piece == root then continue end
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = root, piece, piece
		piece.Anchored = false
		table.insert(welds, weld)
	end
	item.welds = welds
end

local function parkBasket(item)
	for _, weld in item.welds do
		weld.Part1.Anchored = true
		weld:Destroy()
	end
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
