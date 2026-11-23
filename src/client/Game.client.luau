local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
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
local ShopperScene = require(script.Parent.ShopperScene)
local CartEffects = require(script.Parent.CartEffects)
local ShopMenu = require(script.Parent.ShopMenu)
local ShopperMotion = require(script.Parent.ShopperMotion)
local ScreenLayout = require(script.Parent.ScreenLayout)
local SoundEffects = require(script.Parent.SoundEffects)
local Music = require(script.Parent.Music)
local Timing = require(shared:WaitForChild("RescueTiming"))
local effectEvent = shared:WaitForChild("ShiftEffects")
local rescueInput = shared:WaitForChild("RescueInput")
local sprintInput = shared:WaitForChild("SprintInput")
local cameras = Workspace:WaitForChild("WWMS"):WaitForChild("MenuCameras")
local shots = {}
for _, name in { "Facade", "Willy", "Aisles", "Coolers", "Produce", "Return" } do
	table.insert(shots, cameras:WaitForChild(name).CFrame)
end

local gui = player:WaitForChild("PlayerGui")
local view = Interface.new(gui, Config, Pay)
local shopperScene = ShopperScene.new(gui, player, rescueInput, Timing, Config.RescueDistance)
local cartEffects = CartEffects.new(view.hud, player)
local shopActions = {}
local shopMenu = ShopMenu.new(gui, player, shopActions)
ShopperMotion.start()
SoundEffects.prepare()
local musicVolume = player:GetAttribute("MusicVolume") or Config.DefaultMusicVolume
local music = Music.new(musicVolume)
if not RunService:IsStudio() then TeleportService:SetTeleportGui(view:teleportGui()) end

local route = "Loading"
local state = { revision = 0 }
local model = { solo = 1, multi = 1, roomLevel = 1, private = false, code = "", musicVolume = musicVolume }
local actions = {}
local listBusy, busy = false, false
local message = ""
local active, savedFov
local filmStart = Workspace:GetServerTimeNow()
local lastRefresh, nextBrowse = 0, 0
local function preferredInput()
	local preferred = UserInputService.PreferredInput
	if preferred == Enum.PreferredInput.Touch then return Enum.UserInputType.Touch end
	if preferred == Enum.PreferredInput.Gamepad then return Enum.UserInputType.Gamepad1 end
	return UserInputService:GetLastInputType()
end
local input = preferredInput()
local pressureAt = 0
local function updateLayout()
	input = preferredInput()
	local tv = ScreenLayout.isGamepad(input) and GuiService.ViewportDisplaySize == Enum.DisplaySize.Large
	view:setInput(input, tv)
	shopperScene:setInput(input, tv)
	cartEffects:resize(tv)
	shopMenu:setInput(input, tv)
end
local controls
local shopReturn, shopLoading, shopQueued
local sprintKeys, sprintTouch, sprinting = {}, nil, false
local function syncSprint()
	local wanted = next(sprintKeys) ~= nil or sprintTouch ~= nil
	if wanted == sprinting then return end
	sprinting = wanted
	sprintInput:FireServer(wanted)
end

local function cancelSprint()
	table.clear(sprintKeys)
	sprintTouch = nil
	syncSprint()
end

local function canSprint()
	return active and not shopMenu.mode and not GuiService.MenuIsOpen and not shopperScene.attempt
		and not player:GetAttribute("Stopped") and not player:GetAttribute("Slipped")
end

local function modal(mode)
	if mode then cancelSprint() end
	shopMenu:show(mode)
	if controls then
		if mode and active then controls:Disable() else controls:Enable() end
	end
	if ScreenLayout.isGamepad(input) then
		GuiService.SelectedObject = if mode then shopMenu.back elseif not active then view.first else nil
	end
end

task.spawn(function()
	local modules = player:FindFirstChild("PlayerScripts")
	local playerModule = modules and modules:WaitForChild("PlayerModule", 6)
	if playerModule then
		controls = require(playerModule):GetControls()
		if shopMenu.mode and active then controls:Disable() end
	end
end)
local menuPages = { Home = true, Solo = true, Multi = true, Code = true, Create = true, Music = true }

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
	if not active and not shopMenu.mode and ScreenLayout.isGamepad(input) then
		local current = GuiService.SelectedObject
		if force or not current or not current:IsDescendantOf(view.screen) then
			GuiService.SelectedObject = view.first
		end
	end
end

local function refresh(now)
	local room = state.room
	local carrying = player:GetAttribute("CarryingCart") == true
	local stopped = player:GetAttribute("Stopped") == true or shopperScene.stop ~= nil
	local slipped = player:GetAttribute("Slipped") == true
	local playing = route == "Active" and room ~= nil
	if active ~= playing then
		local previouslyActive = active
		active = playing
		shopMenu.launcher.Visible = playing
		if not active then
			cancelSprint()
			if previouslyActive then modal(nil) end
			filmStart = now
			shopperScene:reset(Workspace.CurrentCamera)
			cartEffects:reset()
		end
		view.menu.Visible, view.backdrop.Enabled, view.hud.Visible = not active, not active, active
		if active then
			local selection = GuiService.SelectedObject
			if selection and selection:IsDescendantOf(view.screen) then GuiService.SelectedObject = nil end
		end
		setCamera()
	end
	ProximityPromptService.Enabled = playing and not carrying and not stopped and not slipped and not shopMenu.mode
	if room and playing then
		local seconds = math.max(0, math.ceil(room.deadline - now))
		if room.banked < room.goal and seconds > 0 and seconds <= 12 then
			if now >= pressureAt then
				SoundEffects.play("Pressure")
				pressureAt = now + (if seconds <= 4 then .85 else 2.2)
			end
		else
			pressureAt = 0
		end
		view:showShift(room, seconds, player:GetAttribute("ReturnedCarts") or 0, carrying, input)
		if slipped then
			view.tipTitle.Text, view.tipText.Text = "You slipped!", "Wait to get back up."
		end
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
	if room and (not previous or room.phase ~= previous.phase) then
		if room.phase == "Active" then SoundEffects.play("Start")
		elseif room.phase == "Results" and room.result and room.result.outcome == "Time" then SoundEffects.play("Time") end
	end
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

local musicEdited, musicSave = false, 0
function actions.music(volume, save)
	musicEdited = true
	model.musicVolume = volume
	music:setVolume(volume)
	if not save then return end
	musicSave += 1
	local version = musicSave
	local function saveVolume()
		if version ~= musicSave then return true end
		local ok, response = pcall(request.InvokeServer, request, "MusicVolume", volume)
		return ok and response and not response.error
	end
	task.delay(.5, function()
		if not saveVolume() then task.delay(.75, saveVolume) end
	end)
end

player:GetAttributeChangedSignal("MusicVolume"):Connect(function()
	if musicEdited then return end
	local volume = player:GetAttribute("MusicVolume") or Config.DefaultMusicVolume
	model.musicVolume = volume
	music:setVolume(volume)
	if view.paintMusic then view.paintMusic(volume) end
end)

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
		if shopMenu.mode == "Leave" then shopMenu.notice.Text = message end
		setStatus()
	end)
end

local function shopList()
	if shopMenu.mode ~= "Shop" then return end
	if shopLoading then shopQueued = true return end
	shopLoading, shopQueued = true, false
	shopMenu.buy.Active, shopMenu.buy.Selectable = false, false
	local filters = table.clone(shopMenu.filters)
	task.spawn(function()
		local ok, response = pcall(request.InvokeServer, request, "Shop", filters)
		shopLoading = false
		if shopMenu.mode ~= "Shop" then return end
		if shopQueued then
			task.delay(.26, shopList)
		elseif ok and response.shop then
			shopMenu:catalog(response.shop)
		elseif ok and response.loading then
			task.delay(.55, shopList)
		else
			shopMenu.notice.Text = "Could not load the shop. Try again."
		end
	end)
end

function shopActions.load()
	shopList()
end

function actions.shop()
	shopReturn = if active then "Pause" else nil
	SoundEffects.play("Shop")
	modal("Shop")
	shopList()
end

function shopActions.toggle()
	if not active then return end
	SoundEffects.play("Menu")
	if shopMenu.mode then modal(nil) else modal("Pause") end
end

function shopActions.back()
	if shopMenu.mode == "Shop" and shopMenu.categoryView then
		shopMenu:setCategoryView(false)
	elseif shopMenu.mode == "Shop" then
		modal(shopReturn)
	elseif shopMenu.mode == "Leave" then
		modal("Pause")
	else
		modal(nil)
	end
end

function shopActions.main()
	modal(nil)
end

function shopActions.extra(mode)
	if mode == "Leave" then
		shopMenu.notice.Text = "Leaving…"
		actions.send("Leave", true)
	else
		actions.shop()
	end
end

function shopActions.fee()
	local room = state.room
	return Pay.format(if room then Config.Levels[room.level].leaveCents else 0)
end

function shopActions.buy(key)
	if busy then return end
	busy = true
	SoundEffects.play("Buy")
	shopMenu.notice.Text = "Opening purchase…"
	task.spawn(function()
		local ok, response = pcall(request.InvokeServer, request, "Buy", key)
		busy = false
		shopMenu.notice.Text = if ok and response then response.error or "" else "Could not open the purchase."
	end)
end

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _, purchased)
	if userId == player.UserId and purchased then
		SoundEffects.play("Owned")
		task.delay(2, shopList)
	end
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, _, purchased)
	if who == player and purchased then
		SoundEffects.play("Owned")
		task.delay(1, shopList)
	end
end)
ContextActionService:BindActionAtPriority("WWMSMenu", function(_, actionState)
	if active and actionState == Enum.UserInputState.Begin and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox() then
		shopActions.toggle()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.P, Enum.KeyCode.ButtonL3)
ContextActionService:BindActionAtPriority("WWMSBack", function(_, actionState)
	if actionState == Enum.UserInputState.Begin and not GuiService.MenuIsOpen and not GuiService:IsModalDialog() then
		if shopMenu.mode then
			shopActions.back()
			return Enum.ContextActionResult.Sink
		elseif route == "Music" then
			actions.go("Home")
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)

changed.OnClientEvent:Connect(accept)
effectEvent.OnClientEvent:Connect(function(kind, payload)
	if not active then return end
	if kind == "Stopped" and payload.worker == player then
		SoundEffects.play("Shopper")
		if shopMenu.mode then modal(nil) end
	elseif kind == "Grab" then
		SoundEffects.play("Grab")
	elseif kind == "Returned" then
		if payload.full then SoundEffects.cheer() elseif payload.worker == player then SoundEffects.play("Return") end
	elseif kind == "RescueStart" then
		cancelSprint()
		SoundEffects.play("Help")
	elseif kind == "RescueStep" then
		SoundEffects.play("Hit")
	elseif kind == "RescueEnd" then
		if payload.outcome == "Hit" then SoundEffects.play("Hit")
		elseif payload.outcome == "Miss" then SoundEffects.play("Miss") end
	elseif kind == "Freed" and payload.worker == player and payload.outcome == "Helped" then
		SoundEffects.play("Hit")
	end
	if kind == "Grab" or kind == "Returned" then
		cartEffects:receive(kind, payload)
	else
		shopperScene:receive(kind, payload)
	end
end)
ContextActionService:BindActionAtPriority("WWMSHelp", function(_, actionState, actionInput)
	if active and not shopMenu.mode and not GuiService.MenuIsOpen and not player:GetAttribute("Slipped")
		and actionState == Enum.UserInputState.Begin and shopperScene:input(actionInput.KeyCode) then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonX)
ContextActionService:BindActionAtPriority("WWMSSprint", function(_, actionState, actionInput)
	if actionState == Enum.UserInputState.Cancel then
		table.clear(sprintKeys)
		syncSprint()
		return Enum.ContextActionResult.Pass
	end
	local key = actionInput.KeyCode
	if actionState == Enum.UserInputState.Begin and canSprint() and not UserInputService:GetFocusedTextBox() then
		sprintKeys[key] = true
		syncSprint()
		return Enum.ContextActionResult.Sink
	elseif actionState == Enum.UserInputState.End and sprintKeys[key] then
		sprintKeys[key] = nil
		syncSprint()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.ButtonR2)

view.sprint.InputBegan:Connect(function(event)
	if not sprintTouch and event.UserInputType == Enum.UserInputType.Touch and canSprint() then
		sprintTouch = event
		syncSprint()
	end
end)
UserInputService.InputEnded:Connect(function(event)
	if event ~= sprintTouch then return end
	sprintTouch = nil
	syncSprint()
end)
UserInputService.WindowFocusReleased:Connect(cancelSprint)
GuiService.MenuOpened:Connect(cancelSprint)

for _, attribute in { "CarryingCart", "Stopped", "Slipped", "ReturnedCarts" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if (attribute == "Stopped" or attribute == "Slipped") and player:GetAttribute(attribute) then cancelSprint() end
		if active and attribute == "Slipped" then
			if player:GetAttribute("Slipped") then
				SoundEffects.play("SlipTension")
				SoundEffects.play("Slip")
			else
				SoundEffects.play("Stand")
			end
		end
		refresh(Workspace:GetServerTimeNow())
	end)
end
local function updateWallet()
	local cents = player:GetAttribute("WalbucksCents") or 0
	local ready = player:GetAttribute("WalletReady")
	view:setWallet(cents, ready, player:GetAttribute("WalletSaving"))
	shopMenu:setBalance(if ready then Pay.format(cents) .. " Walbucks" else "Walbucks …")
	setStatus()
end
for _, attribute in { "WalbucksCents", "WalletReady", "WalletSaving" } do
	player:GetAttributeChangedSignal(attribute):Connect(updateWallet)
end
local function switchInput()
	updateLayout()
	if shopMenu.mode and ScreenLayout.isGamepad(input) and not GuiService.SelectedObject then
		GuiService.SelectedObject = shopMenu.back
	end
	focus(false)
	refresh(Workspace:GetServerTimeNow())
end
UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(switchInput)
UserInputService.LastInputTypeChanged:Connect(switchInput)
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	local selected = GuiService.SelectedObject
	if shopMenu.mode then
		ScreenLayout.showSelection(shopMenu.scroll, selected)
	else
		ScreenLayout.showSelection(view.menuScroll, selected)
		if view.list then ScreenLayout.showSelection(view.list, selected, view.ticketScale.Scale) end
	end
end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(setCamera)
player.CharacterAdded:Connect(function(character)
	cancelSprint()
	if character:WaitForChild("Humanoid", 10) then setCamera() end
end)
view.screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() view:resize() end)

updateLayout()
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
RunService:BindToRenderStep("WWMSCinematic", Enum.RenderPriority.Camera.Value + 1, function(dt)
	shopMenu:step(dt)
	local now = Workspace:GetServerTimeNow()
	if now >= lastRefresh then
		lastRefresh = now + .10
		refresh(now)
		music:step(active == true, now)
		if route == "Multi" and os.clock() >= nextBrowse then actions.browse(false) end
	end
	local camera = Workspace.CurrentCamera
	if active then
		local encounterVisible = shopperScene:step(now, input, not shopMenu.mode and not GuiService.MenuIsOpen and not player:GetAttribute("Slipped"))
		view.sprint.Visible = input == Enum.UserInputType.Touch and canSprint() == true
		view.tip.Visible = player:GetAttribute("HasFinishedShift") == true and not shopMenu.mode and not encounterVisible
		shopMenu.launcher.Visible = not shopperScene.stop and not shopMenu.mode
		if camera and not shopperScene:camera(now, camera) and camera.CameraType == Enum.CameraType.Scriptable then setCamera() end
		return
	end
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
