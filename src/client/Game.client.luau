local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("CartCatcher")
local Config = require(shared:WaitForChild("Config"))
local setQueue = shared:WaitForChild("SetQueue")
local value = shared:WaitForChild("ShiftState")
local Interface = require(script.Parent.Interface)
local cameras = Workspace:WaitForChild("WWMS"):WaitForChild("MenuCameras")

local shots = {}
for _, name in { "Facade", "Willy", "Aisles", "Return" } do
	table.insert(shots, cameras:WaitForChild(name).CFrame)
end

local view = Interface.new(player:WaitForChild("PlayerGui"), Config.Levels)
local state = HttpService:JSONDecode(value.Value)
local playing, cinematicStart
local lastUpdate = 0
local previousQueued = -math.huge
local savedFov
local input = UserInputService:GetLastInputType()
local shotDuration = 7.5

local function selectButton()
	if not playing and string.match(input.Name, "^Gamepad") and not GuiService.SelectedObject then
		GuiService.SelectedObject = view.button
	end
end

local function applyCamera()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if playing then
		camera.CameraType = Enum.CameraType.Custom
		if savedFov then
			camera.FieldOfView = savedFov
			savedFov = nil
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
	else
		savedFov = savedFov or camera.FieldOfView
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 62
	end
end

local function refresh(now)
	local active = state.phase == "Active" and player:GetAttribute("InShift") == true
	local carrying = player:GetAttribute("CarryingCart") == true
	local interrupted = now < (player:GetAttribute("QuestionUntil") or 0)
	ProximityPromptService.Enabled = active and not carrying and not interrupted
	if active ~= playing then
		playing = active
		if not playing then cinematicStart = now end
		view.menu.Visible, view.backdrop.Enabled, view.hud.Visible = not playing, not playing, playing
		if playing and GuiService.SelectedObject == view.button then
			GuiService.SelectedObject = nil
		else
			selectButton()
		end
		applyCamera()
	end

	local remaining = math.max(0, math.ceil(state.deadline - now))
	if playing then
		local question = if interrupted then player:GetAttribute("Question") else nil
		view:showShift(state, Config.Levels[state.level].name, remaining, player:GetAttribute("ReturnedCarts") or 0, carrying, question, input)
	else
		view:showMenu(state, player:GetAttribute("Queued") == true, remaining)
	end
end

view.button.Activated:Connect(function()
	local now = os.clock()
	if now - previousQueued < .5 then return end
	previousQueued = now
	setQueue:FireServer(player:GetAttribute("Queued") ~= true)
end)
value:GetPropertyChangedSignal("Value"):Connect(function()
	state = HttpService:JSONDecode(value.Value)
	refresh(Workspace:GetServerTimeNow())
end)
for _, attribute in { "Queued", "InShift", "CarryingCart", "QuestionUntil", "Question", "ReturnedCarts" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		refresh(Workspace:GetServerTimeNow())
	end)
end
UserInputService.LastInputTypeChanged:Connect(function(lastInput)
	input = lastInput
	selectButton()
	refresh(Workspace:GetServerTimeNow())
end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(applyCamera)
player.CharacterAdded:Connect(function(character)
	if character:WaitForChild("Humanoid", 10) then applyCamera() end
end)
view.screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() view:resize() end)
view:resize()
refresh(Workspace:GetServerTimeNow())

RunService:BindToRenderStep("WWMSCinematic", Enum.RenderPriority.Camera.Value + 1, function()
	local now = Workspace:GetServerTimeNow()
	if now >= lastUpdate then
		lastUpdate = now + .10
		refresh(now)
	end
	if playing then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end

	local elapsed = now - cinematicStart
	local shotIndex = math.floor(elapsed / shotDuration) % #shots + 1
	local shotTime = elapsed % shotDuration
	local alpha = math.clamp(shotTime / shotDuration, 0, 1)
	local frame = shots[shotIndex]
	local ease = alpha * alpha * (3 - 2 * alpha)
	local portrait = camera.ViewportSize.X < camera.ViewportSize.Y
	local yaw = if portrait then 3 else 11
	camera.CFrame = frame * CFrame.new(2 - 5 * ease, 1.5 - ease, 1 - 5 * ease) * CFrame.Angles(0, math.rad(yaw - 3 * ease), 0)
	camera.Focus = frame * CFrame.new(0, 0, -33)
	local fadeWindow = .44
	view.fade.BackgroundTransparency = math.clamp(math.min(shotTime, shotDuration - shotTime) / fadeWindow, 0, 1)
end)
