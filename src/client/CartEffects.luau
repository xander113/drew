local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ScreenLayout = require(script.Parent.ScreenLayout)

local CartEffects = {}
CartEffects.__index = CartEffects

local TAG = "WWMSPushedCart"
local rgb = Color3.fromRGB
local COLORS = { rgb(255, 219, 65), rgb(32, 133, 255), rgb(124, 249, 182), rgb(255, 249, 223) }
local BLUE, INK = rgb(13, 84, 222), rgb(19, 42, 83)

local function holdHandle(driver, amount)
	local torso = driver.Parent and driver.Parent:FindFirstChild("Torso")
	if not torso then return end
	local reach = CFrame.Angles(1.12, 0, 0)
	for _, shoulder in { "Left Shoulder", "Right Shoulder" } do
		local arm = torso:FindFirstChild(shoulder)
		if arm and arm:IsA("Motor6D") then
			local rest = arm.C0.Rotation
			local target = rest:Inverse() * reach * rest
			arm.Transform = arm.Transform:Lerp(target, amount)
		end
	end
end

local function move(joint, model, dt, now, reduce)
	local driver = joint.Part0
	if not driver then return end
	local target = driver.CFrame * joint.C0
	local at = model:GetAttribute("GrabAt") or 0
	local parked = model:GetAttribute("GrabFrom")
	local alpha = math.clamp((now - at) / .29, 0, 1)
	holdHandle(driver, if reduce then .88 else math.clamp(alpha * 2, 0, .88))
	if alpha < 1 and parked and not reduce then
		local ease = 1 - (1 - alpha) ^ 3
		local lift = math.sin(math.pi * alpha) * .86
		local frame = parked:Lerp(target, ease) + Vector3.new(0, lift, 0)
		joint.Transform = target:ToObjectSpace(frame)
	elseif reduce then
		joint.Transform = CFrame.new()
	else
		local travel = driver.CFrame:VectorToObjectSpace(driver.AssemblyLinearVelocity)
		local speed = math.clamp(Vector3.new(travel.X, 0, travel.Z).Magnitude / 13, 0, 1)
		local rock = math.sin((now - at) * 18) * speed
		local roll = math.clamp(travel.X * -.018, -.14, .14)
		local pose = CFrame.new(0, .045 + math.abs(rock) * .13, 0) * CFrame.Angles(rock * .028, 0, roll + rock * .04)
		joint.Transform = joint.Transform:Lerp(pose, 1 - math.exp(-19 * dt))
	end
end

function CartEffects.new(hud, player)
	local self = setmetatable({ player = player, random = Random.new(), carts = {}, bursts = 0 }, CartEffects)
	local wrap = Instance.new("Frame")
	wrap.Name, wrap.BackgroundTransparency = "Cart cheer area", 1
	wrap.Size, wrap.AnchorPoint = UDim2.fromOffset(255, 50), Vector2.new(.5, 0)
	wrap.Parent = hud
	self.wrap, self.fit = wrap, Instance.new("UIScale")
	self.fit.Parent = wrap
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end)
	local chip = Instance.new("TextLabel")
	chip.Name = "Cart cheer"
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3, chip.TextColor3 = COLORS[1], INK
	chip.Text, chip.TextSize, chip.Font = "", 27, Enum.Font.FredokaOne
	chip.BorderSizePixel, chip.Visible = 0, false
	chip.Parent = wrap
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0, 19), chip
	self.scale = Instance.new("UIScale")
	self.scale.Parent = chip
	self.chip = chip
	for _, model in CollectionService:GetTagged(TAG) do self.carts[model] = true end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model) self.carts[model] = true end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model) self.carts[model] = nil end)
	RunService.PreSimulation:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		local reduced = GuiService.ReducedMotionEnabled
		for model in self.carts do
			local root = model.PrimaryPart
			local joint = root and root:FindFirstChild("PushJoint")
			if joint then move(joint, model, dt, now, reduced) end
		end
	end)
	return self
end

function CartEffects:resize(tv)
	if tv ~= nil then self.tv = tv end
	local size = self.wrap.Parent.AbsoluteSize
	if size.X < 60 or size.Y < 100 then return end
	local score = ScreenLayout.scale(size, 376, 385, 24, if self.tv then 1.2 else 1.04, .82)
	self.fit.Scale = ScreenLayout.scale(size, 255, 330, 24, if self.tv then 1.2 else 1.04, .85)
	self.wrap.Position = UDim2.new(.5, 0, 0, math.ceil(score * 111 + 9))
end

function CartEffects:cheer(message, color)
	local chip = self.chip
	if self.animation then self.animation:Cancel() end
	chip.Text, chip.TextColor3, chip.BackgroundColor3 = message, if color == BLUE then COLORS[4] else INK, color
	chip.TextTransparency, chip.BackgroundTransparency, chip.Visible = 0, 0, true
	self.scale.Scale = if GuiService.ReducedMotionEnabled then 1 else .75
	if not GuiService.ReducedMotionEnabled then
		self.animation = TweenService:Create(self.scale, TweenInfo.new(.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		self.animation:Play()
	end
	local current = {}
	self.current = current
	task.delay(.99, function()
		if self.current ~= current then return end
		if not GuiService.ReducedMotionEnabled then
			TweenService:Create(chip, TweenInfo.new(.22), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
		task.delay(.23, function()
			if self.current == current then chip.Visible = false end
		end)
	end)
end

function CartEffects:burst(at, count, wide)
	if GuiService.ReducedMotionEnabled or self.bursts >= 5 then return end
	local root = self.player.Character and self.player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - at).Magnitude > 82 then return end
	self.bursts += 1
	local sparks = Instance.new("Folder")
	sparks.Name, sparks.Parent = "Cart confetti", Workspace
	for index = 1, count do
		local angle = index / count * math.pi * 2 + self.random:NextNumber(-.18, .18)
		local distance = self.random:NextNumber(1.1, if wide then 7.8 else 3.1)
		local up = self.random:NextNumber(1.5, if wide then 6.3 else 3.1)
		local travel = Vector3.new(math.cos(angle) * distance, up, math.sin(angle) * distance)
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(.21, .38, .095)
		shard.Color = COLORS[(index - 1) % #COLORS + 1]
		shard.Material = Enum.Material.Neon
		shard.Anchored, shard.CanCollide, shard.CanTouch, shard.CanQuery, shard.CastShadow = true, false, false, false, false
		shard.CFrame, shard.Parent = CFrame.new(at), sparks
		local spin = CFrame.Angles(index * .74, angle, index * .52)
		TweenService:Create(shard, TweenInfo.new(.46, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(at + travel) * spin, Transparency = .72, Size = shard.Size * .4,
		}):Play()
	end
	if wide then
		for step = 1, 12 do
			local angle = step / 12 * math.pi * 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local floor = at - Vector3.new(0, .44, 0)
			local ring = Instance.new("Part")
			ring.Size, ring.Color, ring.Material = Vector3.new(.13, .07, .88), COLORS[1], Enum.Material.Neon
			ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
			ring.CastShadow = false
			ring.CFrame, ring.Parent = CFrame.lookAt(floor + out * 1.4, floor + out * 2.4), sparks
			TweenService:Create(ring, TweenInfo.new(.43, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(floor + out * 5, floor + out * 6), Transparency = 1,
			}):Play()
		end
	end
	Debris:AddItem(sparks, .52)
	task.delay(.53, function() self.bursts -= 1 end)
end

function CartEffects:receive(kind, payload)
	if kind == "Grab" then
		self:burst(payload.position, 11, false)
		self:cheer("Cart ready!", COLORS[1])
	elseif kind == "Returned" then
		self:burst(payload.position, if payload.full then 32 else 21, true)
		if payload.full then
			self:cheer("Bay full!", COLORS[3])
		elseif payload.worker == self.player then
			self:cheer("Cart back!  +1", BLUE)
		end
	end
end

function CartEffects:reset()
	self.current = nil
	self.chip.Visible = false
end

return CartEffects
