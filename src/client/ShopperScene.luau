local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local AvatarPreview = require(script.Parent.AvatarPreview)

local ShopperScene = {}
ShopperScene.__index = ShopperScene

local rgb, offset, scale = Color3.fromRGB, UDim2.fromOffset, UDim2.fromScale
local INK, BLUE = rgb(16, 35, 74), rgb(0, 82, 220)
local GOLD, PAPER, WHITE = rgb(255, 214, 58), rgb(255, 252, 235), rgb(255, 255, 255)
local RED = rgb(255, 35, 61)
local DISPLAY, BODY = Enum.Font.FredokaOne, Enum.Font.GothamBold

local function object(class, parent)
	local item = Instance.new(class)
	item.Parent = parent
	return item
end

local function round(item, radius)
	object("UICorner", item).CornerRadius = UDim.new(0, radius)
end

local function box(parent, x, y, w, h, color, radius, class)
	local item = object(class or "Frame", parent)
	item.Size, item.Position = offset(w, h), offset(x, y)
	item.BackgroundColor3, item.BorderSizePixel = color, 0
	if radius then round(item, radius) end
	return item
end

local function text(parent, x, y, w, h, value, size, color, font, centered)
	local item = box(parent, x, y, w, h, color, nil, "TextLabel")
	item.Text, item.TextSize, item.TextColor3, item.Font = value, size, color, font
	item.BackgroundTransparency = 1
	item.TextXAlignment = if centered then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	return item
end

local function pop(item)
	if GuiService.ReducedMotionEnabled then return end
	local rest = item.Position
	item.Position = rest + offset(0, 17)
	TweenService:Create(item, TweenInfo.new(.29, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = rest }):Play()
end

function ShopperScene.new(parent, player, remote, timing, helpRange)
	local gui = object("ScreenGui", parent)
	gui.Name, gui.DisplayOrder, gui.ResetOnSpawn = "WWMS Scene", 24, false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local self = setmetatable({
		player = player, remote = remote, timing = timing, helpRange = helpRange, marks = {}, gui = gui,
	}, ShopperScene)

	local speech = box(gui, 0, 0, 640, 138, BLUE, 25)
	speech.AnchorPoint = Vector2.new(.5, 1)
	speech.Visible, self.speech = false, speech
	self.speechScale = object("UIScale", speech)
	box(speech, 6, 7, 628, 121, PAPER, 21)
	local nameplate = box(speech, 15, -28, 192, 43, GOLD, 14)
	nameplate.Rotation = -4
	self.speaker = text(nameplate, 16, 0, 163, 43, "", 23, INK, DISPLAY)
	self.line = text(speech, 27, 27, 587, 61, "", 28, INK, DISPLAY)
	self.line.TextWrapped = true
	local rail = box(speech, 27, 101, 587, 7, rgb(198, 220, 247), 4)
	self.speechTime = box(rail, 0, 0, 587, 7, BLUE, 4)
	self.caption = text(speech, 27, 111, 587, 19, "A shopper stopped you", 13, INK, BODY)
	self.caption.TextXAlignment = Enum.TextXAlignment.Right

	local portrait = box(gui, 0, 0, 163, 172, GOLD, 26)
	portrait.AnchorPoint = Vector2.new(1, 0)
	portrait.Visible, self.portrait = false, portrait
	self.portraitScale = object("UIScale", portrait)
	self.viewport = box(portrait, 8, 7, 147, 154, BLUE, 19, "ViewportFrame")
	self.viewport.Ambient = rgb(230, 235, 246)
	self.viewport.LightColor = WHITE
	self.viewport.LightDirection = Vector3.new(-1, -.6, -1)
	self.faceCamera = object("Camera", self.viewport)
	self.faceCamera.FieldOfView = 24
	self.faceCamera.CFrame = CFrame.lookAt(Vector3.new(-1.5, 1.9, -5.15), Vector3.new(0, 1.52, 0))
	self.viewport.CurrentCamera = self.faceCamera

	local help = box(gui, 0, 0, 366, 92, BLUE, 21)
	help.AnchorPoint = Vector2.new(.5, 1)
	help.Visible, self.help = false, help
	self.helpScale = object("UIScale", help)
	local button = box(help, 5, 5, 356, 81, PAPER, 17, "TextButton")
	button.Text, button.AutoButtonColor, button.Selectable = "", true, false
	self.helpHeader = text(button, 13, 5, 329, 31, "Help your teammate", 23, INK, DISPLAY, true)
	self.helpText = text(button, 12, 36, 331, 32, "", 16, INK, BODY, true)
	local track = box(button, 17, 48, 322, 15, rgb(197, 216, 247), 8)
	self.track = track
	self.zone = box(track, 0, 0, 60, 15, rgb(119, 228, 99), 8)
	self.needle = box(track, 0, -3, 5, 21, BLUE, 4)
	button.Activated:Connect(function() self:input() end)
	self:resize()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end)
	return self
end

function ShopperScene:resize()
	local dims = self.gui.AbsoluteSize
	local phone = dims.X < dims.Y
	self.speechScale.Scale = math.clamp((dims.X - 26) / 640, .42, 1)
	self.portraitScale.Scale = if phone then .76 else 1
	self.helpScale.Scale = math.clamp((dims.X - 26) / 366, .42, 1)
	self.speech.Position = UDim2.new(.5, 0, 1, if phone then -103 else -27)
	self.help.Position = self.speech.Position
	self.portrait.Position = UDim2.new(1, if phone then -15 else -38, 0, if phone then 114 else 34)
end

function ShopperScene:portraitOf(shopper)
	if self.face then self.face:Destroy() end
	self.face = AvatarPreview.clone(shopper, self.viewport)
end

function ShopperScene:mark(data)
	local character = data.worker.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	local mark = object("Highlight", character)
	mark.Name, mark.Adornee, mark.DepthMode = "Needs help", character, Enum.HighlightDepthMode.AlwaysOnTop
	mark.FillColor, mark.OutlineColor, mark.FillTransparency = RED, rgb(255, 197, 193), .27
	local badge = object("BillboardGui", head)
	badge.Name, badge.Adornee, badge.AlwaysOnTop = "Help marker", head, true
	badge.Size, badge.MaxDistance = offset(103, 29), 125
	badge.StudsOffsetWorldSpace = Vector3.new(0, 2.18, 0)
	local bg = box(badge, 0, 0, 103, 29, RED, 12)
	text(bg, 0, 0, 103, 29, "Need help!", 16, WHITE, DISPLAY, true)
	data.highlight, data.badge = mark, badge
end

function ShopperScene:unmark(worker)
	local data = self.marks[worker]
	if not data then return end
	if data.highlight then data.highlight:Destroy() end
	if data.badge then data.badge:Destroy() end
	self.marks[worker] = nil
end

function ShopperScene:note(value)
	self.noteText, self.noteUntil = value, Workspace:GetServerTimeNow() + .96
end

function ShopperScene:receive(kind, data)
	if kind == "Stopped" then
		if data.worker == self.player then
			self.stop = data
			self.line.Text, self.beat = "", nil
			self.speech.Visible, self.portrait.Visible = true, true
			self:portraitOf(data.shopper)
			pop(self.speech)
			pop(self.portrait)
		else
			self:unmark(data.worker)
			self.marks[data.worker] = data
			self:mark(data)
		end
	elseif kind == "Freed" then
		if data.worker == self.player then
			if not self.stop or self.stop.id ~= data.id then return end
			self.stop = nil
			self.speech.Visible, self.portrait.Visible = false, false
			if self.cameraScene then self.cameraScene.exiting = Workspace:GetServerTimeNow() end
			if data.outcome == "Helped" then self:note("A teammate helped!") end
		elseif self.marks[data.worker] and self.marks[data.worker].id == data.id then
			self:unmark(data.worker)
		end
	elseif kind == "RescueStart" then
		data.step = 1
		self.attempt = data
		pop(self.help)
	elseif kind == "RescueStep" then
		if self.attempt and self.attempt.id == data.id then self.attempt.step = data.step end
	elseif kind == "RescueEnd" then
		if not self.attempt or self.attempt.id ~= data.id then return end
		self.attempt = nil
		if data.outcome == "Hit" then
			self:note("Nice save!")
		elseif data.outcome == "Miss" then
			self:note("Missed. Try again.")
		end
	elseif kind == "RescueNote" then
		self:note(data)
	end
end

function ShopperScene:input()
	if self.stop then return false end
	local now = Workspace:GetServerTimeNow()
	if now < (self.inputAt or 0) then return false end
	if self.attempt then
		self.remote:FireServer("Tap", self.attempt.id)
	elseif self.target then
		self.remote:FireServer("Begin", self.target)
	else
		return false
	end
	self.inputAt = now + .13
	return true
end

local function body(player)
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end

function ShopperScene:nearest(now)
	local ownRoot = body(self.player)
	local best, gap = nil, self.helpRange
	for worker, data in self.marks do
		local root = body(worker)
		if now >= data.finish + .6 or not root then
			self:unmark(worker)
		elseif ownRoot and (root.Position - ownRoot.Position).Magnitude < gap then
			local delta = root.Position - ownRoot.Position
			local ray = RaycastParams.new()
			ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, { self.player.Character, worker.Character }
			ray.RespectCanCollide = true
			if delta.Magnitude < .01 or not Workspace:Raycast(ownRoot.Position, delta, ray) then best, gap = worker, delta.Magnitude end
		end
	end
	return best
end

function ShopperScene:step(now, inputType)
	if self.stop then
		local scene = self.stop
		local section = (scene.finish - scene.start) / #scene.lines
		local beat = math.clamp(math.floor((now - scene.start) / section) + 1, 1, #scene.lines)
		if beat ~= self.beat then
			self.beat = beat
			self.speaker.Text = if beat == 2 then "You" else scene.name
			self.line.Text = scene.lines[beat]
		end
		self.line.MaxVisibleGraphemes = if GuiService.ReducedMotionEnabled then -1 else math.max(0, math.floor((now - scene.start - (beat - 1) * section) * 58))
		self.speechTime.Size = UDim2.new(math.clamp((scene.finish - now) / (scene.finish - scene.start), 0, 1), 0, 0, 7)
		self.help.Visible, self.target = false, nil
		return true
	end

	if now >= (self.nextSearch or 0) then
		self.target, self.nextSearch = self:nearest(now), now + .12
	end
	local attempt = self.attempt
	local note = if now < (self.noteUntil or 0) then self.noteText else nil
	self.help.Visible = attempt ~= nil or self.target ~= nil or note ~= nil
	self.track.Visible, self.helpText.Visible = attempt ~= nil, attempt == nil
	local key = if inputType == Enum.UserInputType.Touch then "Tap here" elseif string.match(inputType.Name, "^Gamepad") then "Press Y" else "Press Q"
	if attempt then
		local pattern = attempt.pattern
		self.helpHeader.Text = string.format("%s in green   %d/%d", key, attempt.step, #pattern.cues)
		self.zone.Size = UDim2.new(pattern.width, 0, 1, 0)
		self.zone.Position = UDim2.fromScale(pattern.cues[attempt.step] - pattern.width / 2, 0)
		self.needle.Position = UDim2.new(math.clamp(self.timing.slot(pattern, attempt.step, now), 0, 1), -2, 0, -3)
	else
		self.helpHeader.Text = note or "Help your teammate"
		self.helpText.Text = if self.target then key .. " to help" else ""
	end
	return self.help.Visible
end

local function shot(camera, worker, shopper)
	local a, b = worker.Position, shopper.Position
	local center = (a + b) * .5 + Vector3.new(0, .72, 0)
	local across = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	across = if across.Magnitude > .01 then across.Unit else Vector3.xAxis
	local side = across:Cross(Vector3.yAxis)
	local distance = if camera.ViewportSize.X < camera.ViewportSize.Y then 13 else 9.8
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { worker.Parent, shopper.Parent }
	ray.RespectCanCollide = true

	local best, clearance = center + side * distance, 0
	for _, sign in { -1, 1 } do
		local direction = side * (sign * distance) - across * .42 + Vector3.new(0, 1.42, 0)
		local hit = Workspace:Raycast(center, direction, ray)
		local allowed = if hit then math.max(1, hit.Distance - .38) else direction.Magnitude
		local candidate = center + direction.Unit * allowed
		if allowed > clearance then best, clearance = candidate, allowed end
	end
	if clearance < 4 then
		local direction = side * 2.4 + Vector3.new(0, 4.1, 0)
		local hit = Workspace:Raycast(center, direction, ray)
		if not hit then best = center + direction end
	end
	return CFrame.lookAt(best, center), center
end

function ShopperScene:camera(now, camera)
	local scene = self.stop
	local stored = self.cameraScene
	if scene then
		local worker, shopper = body(self.player), scene.shopper and scene.shopper.PrimaryPart
		if not worker or not shopper then return false end
		if not stored or stored.id ~= scene.id then
			local frame, center = shot(camera, worker, shopper)
			stored = { id = scene.id, base = camera.CFrame, focus = camera.Focus, fov = camera.FieldOfView, frame = frame, center = center }
			self.cameraScene = stored
		end
		local reduce = GuiService.ReducedMotionEnabled
		local alpha = if reduce then 1 else math.clamp((now - scene.start) / .38, 0, 1)
		local ease = 1 - (1 - alpha) ^ 3
		local bump = if reduce then 0 else math.sin(alpha * math.pi) * .85
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = stored.base:Lerp(stored.frame, ease) * CFrame.new(0, bump, 0)
		camera.Focus = stored.focus:Lerp(CFrame.new(stored.center), ease)
		camera.FieldOfView = stored.fov + (53 - stored.fov) * ease
		return true
	end
	if stored then
		local alpha = if GuiService.ReducedMotionEnabled then 1 else math.clamp((now - (stored.exiting or now)) / .22, 0, 1)
		camera.CFrame = stored.frame:Lerp(stored.base, alpha)
		camera.Focus = CFrame.new(stored.center):Lerp(stored.focus, alpha)
		camera.FieldOfView = 53 + (stored.fov - 53) * alpha
		if alpha < 1 then return true end
		self.cameraScene = nil
	end
	return false
end

function ShopperScene:reset(camera)
	for worker in self.marks do self:unmark(worker) end
	if camera and self.cameraScene then camera.FieldOfView = self.cameraScene.fov end
	self.stop, self.attempt, self.target, self.cameraScene, self.noteUntil = nil, nil, nil, nil, nil
	self.speech.Visible, self.portrait.Visible, self.help.Visible = false, false, false
end

return ShopperScene
