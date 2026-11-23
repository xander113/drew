local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("CartCatcher")
local Config = require(shared:WaitForChild("Config"))
local Pay = require(shared:WaitForChild("Pay"))
local request = shared:WaitForChild("LobbyRequest")
local changed = shared:WaitForChild("LobbyChanged")
local Interface = require(script.Parent.Interface)
local cameras = Workspace:WaitForChild("WWMS"):WaitForChild("MenuCameras")
local shots = {}
for _, name in { "Facade", "Willy", "Aisles", "Return" } do
	table.insert(shots, cameras:WaitForChild(name).CFrame)
end

local view = Interface.new(player:WaitForChild("PlayerGui"), Config, Pay)
if not RunService:IsStudio() then TeleportService:SetTeleportGui(view:teleportGui()) end

local route = "Loading"
local state = { revision = 0 }
local model = { solo = 1, multi = 1, roomLevel = 1, private = false, code = "" }
local actions = {}
local listBusy, busy = false, false
local message = ""
local active, savedFov
local filmStart = Workspace:GetServerTimeNow()
local lastRefresh, nextBrowse = 0, 0
local input = UserInputService:GetLastInputType()
local menuPages = { Home = true, Solo = true, Multi = true, Code = true, Create = true }

local function setCamera()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if active then
		camera.CameraType = Enum.CameraType.Custom
		if savedFov then
			camera.FieldOfView = savedFov
			savedFov = nil
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
	else
		savedFov = savedFov or camera.FieldOfView
		camera.CameraType, camera.FieldOfView = Enum.CameraType.Scriptable, 62
	end
end

local function setStatus()
	if state.travel then
		view:setNotice("One moment…", true)
	elseif busy then
		view:setNotice("Please wait…", true)
	elseif route == "Results" and message == "" and player:GetAttribute("WalletSaving") then
		view:setNotice("Saving pay…", true)
	else
		view:setNotice(if message ~= "" then message else state.notice, false)
	end
end

local function focus(force)
	if not active and string.match(input.Name, "^Gamepad") then
		local current = GuiService.SelectedObject
		if force or not current or not current:IsDescendantOf(view.screen) then
			GuiService.SelectedObject = view.first
		end
	end
end

local function refresh(now)
	local room = state.room
	local carrying = player:GetAttribute("CarryingCart") == true
	local question
	if now < (player:GetAttribute("QuestionUntil") or 0) then
		question = player:GetAttribute("Question")
	end
	local playing = route == "Active" and room ~= nil
	if active ~= playing then
		active = playing
		if not active then filmStart = now end
		view.menu.Visible, view.backdrop.Enabled, view.hud.Visible = not active, not active, active
		if active then
			local selection = GuiService.SelectedObject
			if selection and selection:IsDescendantOf(view.screen) then GuiService.SelectedObject = nil end
		end
		setCamera()
	end
	ProximityPromptService.Enabled = playing and not carrying and not question
	if room and playing then
		local seconds = math.max(0, math.ceil(room.deadline - now))
		view:showShift(room, seconds, player:GetAttribute("ReturnedCarts") or 0, carrying, question, input)
	elseif room and view.countdown then
		view.countdown.Text = tostring(math.max(1, math.ceil(room.deadline - now)))
	end
end

local function render()
	if route ~= "Active" then
		view:showPage(route, model, actions)
		focus(false)
	end
	setStatus()
	refresh(Workspace:GetServerTimeNow())
end

local function accept(update)
	if update.revision <= state.revision then return end
	local previous = state.room
	state, model.room = update, update.room
	local room = update.room
	if room then
		if route ~= "Level" or not previous or previous.phase ~= room.phase or not room.host then
			route = room.phase
		end
	elseif update.loading then
		route = "Loading"
	elseif update.hosted then
		route = "Return"
	elseif not menuPages[route] then
		route = "Home"
	end
	if not room and not previous and view.route == route then
		setStatus()
	else
		render()
	end
end

function actions.go(page)
	route, message = page, ""
	state.notice = nil
	render()
	if route == "Multi" and not model.rows then actions.browse(false) end
end

function actions.soloLevel(level) model.solo = level end
function actions.multiLevel(level) model.multi = level end
function actions.pickRoomLevel(level) model.roomLevel = level end
function actions.code(code) model.code = code end
function actions.privacy(private)
	model.private = private
	render()
end

function actions.roomLevel()
	model.roomLevel = state.room.level
	actions.go("Level")
end

function actions.browse(manual)
	if route ~= "Multi" or listBusy or busy then return end
	listBusy = true
	nextBrowse = os.clock() + 9
	if manual then view:setNotice("Looking for lobbies…", true) end
	task.spawn(function()
		local ok, response = pcall(request.InvokeServer, request, "Browse")
		listBusy = false
		if route ~= "Multi" then return end
		if ok and response.rows then
			model.rows = response.rows
			message = ""
			render()
		elseif not model.rows or manual then
			message = "Could not look for lobbies. Try Refresh."
			setStatus()
		end
	end)
end

function actions.send(action, arg, extra)
	if busy or state.travel then return end
	busy, message = true, ""
	setStatus()
	task.spawn(function()
		local ok, response = pcall(request.InvokeServer, request, action, arg, extra)
		busy = false
		if not ok or type(response) ~= "table" then
			message = "That did not work. Try again."
		elseif response.error then
			message = response.error
		elseif response.state then
			accept(response.state)
		elseif action == "Level" and state.room and route == "Level" then
			actions.go(state.room.phase)
		end
		setStatus()
	end)
end

changed.OnClientEvent:Connect(accept)
for _, attribute in { "CarryingCart", "QuestionUntil", "Question", "ReturnedCarts" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		refresh(Workspace:GetServerTimeNow())
	end)
end
local function updateWallet()
	view:setWallet(player:GetAttribute("WalbucksCents") or 0, player:GetAttribute("WalletReady"), player:GetAttribute("WalletSaving"))
	setStatus()
end
for _, attribute in { "WalbucksCents", "WalletReady", "WalletSaving" } do
	player:GetAttributeChangedSignal(attribute):Connect(updateWallet)
end
UserInputService.LastInputTypeChanged:Connect(function(last)
	input = last
	focus(false)
	refresh(Workspace:GetServerTimeNow())
end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(setCamera)
player.CharacterAdded:Connect(function(character)
	if character:WaitForChild("Humanoid", 10) then setCamera() end
end)
view.screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() view:resize() end)

view:resize()
updateWallet()
render()
task.spawn(function()
	while state.revision == 0 do
		local ok, response = pcall(request.InvokeServer, request, "Sync")
		if ok and response and response.state then accept(response.state) end
		if state.revision == 0 then task.wait(.8) end
	end
end)

local SHOT_SECONDS = 7.5
RunService:BindToRenderStep("WWMSCinematic", Enum.RenderPriority.Camera.Value + 1, function()
	local now = Workspace:GetServerTimeNow()
	if now >= lastRefresh then
		lastRefresh = now + .10
		refresh(now)
		if route == "Multi" and os.clock() >= nextBrowse then actions.browse(false) end
	end
	if active then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end

	local elapsed = if GuiService.ReducedMotionEnabled then SHOT_SECONDS / 2 else now - filmStart
	local shotTime = elapsed % SHOT_SECONDS
	local frame = shots[math.floor(elapsed / SHOT_SECONDS) % #shots + 1]
	local alpha = shotTime / SHOT_SECONDS
	local ease = alpha * alpha * (3 - 2 * alpha)
	local portrait = camera.ViewportSize.X < camera.ViewportSize.Y
	local yaw = if portrait then 3 else 16
	camera.CFrame = frame * CFrame.new(2 - 5 * ease, 1.5 - ease, 1 - 5 * ease) * CFrame.Angles(0, math.rad(yaw - 3 * ease), 0)
	camera.Focus = frame * CFrame.new(0, 0, -33)
	view.fade.BackgroundTransparency = math.clamp(math.min(shotTime, SHOT_SECONDS - shotTime) / .44, 0, 1)
end)
