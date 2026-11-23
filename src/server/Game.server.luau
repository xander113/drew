local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("CartCatcher")
local Config = require(shared.Config)
local Layout = require(shared.Layout)
local Carts = require(script.Parent.Carts)
local Shoppers = require(script.Parent.Shoppers)

local store = Workspace:WaitForChild("WWMS")
local markers = store:WaitForChild("Markers")
local bay = markers:WaitForChild("CartHole")
local crew = markers:WaitForChild("Crew")
local runtime = Instance.new("Folder")
runtime.Name, runtime.Parent = "ShiftObjects", Workspace

local staffCollision = "WWMSWorker"
if not PhysicsService:IsCollisionGroupRegistered(staffCollision) then
	PhysicsService:RegisterCollisionGroup(staffCollision)
end
PhysicsService:CollisionGroupSetCollidable(staffCollision, staffCollision, false)

local stateValue = Instance.new("StringValue")
stateValue.Name = "ShiftState"
local setQueue = Instance.new("RemoteEvent")
setQueue.Name = "SetQueue"

local phase, level, deadline = "Waiting", 1, 0
local goal, banked, shiftSize = 0, 0, 0
local outcome = ""
local players = {}
local random = Random.new()
local carts, shoppers, shiftObjects
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = { store }
ray.RespectCanCollide = true

local function alive(player)
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil
end

local function readyPlayers()
	local ready = {}
	for player, entry in players do
		if entry.queued then table.insert(ready, player) end
	end
	return ready
end

local function publish()
	local queued = 0
	for _, entry in players do
		if entry.queued then queued += 1 end
	end
	stateValue.Value = HttpService:JSONEncode({
		phase = phase, level = level, deadline = deadline, goal = goal,
		banked = banked, workers = shiftSize, queued = queued, outcome = outcome,
	})
end

local function releaseCart(player, entry, returned)
	if entry.cart then
		carts:release(entry.cart, returned)
		entry.cart = nil
		player:SetAttribute("CarryingCart", false)
	end
end

local function updateSpeed(entry, humanoid, now)
	local outstandingQuestion = now < entry.questionUntil
	local speed = if outstandingQuestion then Config.QuestionSpeed elseif entry.cart then Config.PushSpeed else Config.WalkSpeed
	if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
end

local function clearQuestion(player, entry)
	entry.questionUntil = 0
	entry.questionCooldown = 0
	player:SetAttribute("QuestionUntil", 0)
	player:SetAttribute("Question", "")
end

local function uniform(character, enabled)
	local head = character:FindFirstChild("Head")
	if not head then return end
	local badge = head:FindFirstChild("WWMSCrew")
	if badge then badge:Destroy() end
	if not enabled then return end
	badge = Instance.new("BillboardGui")
	badge.Name = "WWMSCrew"
	badge.Size = UDim2.fromOffset(44, 15)
	badge.StudsOffsetWorldSpace = Vector3.new(0, 2.25, 0)
	badge.MaxDistance = 48
	badge.PlayerToHideFrom = Players:GetPlayerFromCharacter(character)
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundColor3 = Color3.fromRGB(0, 81, 206)
	caption.BorderSizePixel = 0
	caption.TextColor3 = Color3.fromRGB(255, 223, 104)
	caption.Font, caption.TextSize, caption.Text = Enum.Font.GothamBold, 10, "WWMS"
	caption.Parent = badge
	badge.Parent = head
end

local function placePlayer(player, entry)
	local root, humanoid = alive(player)
	if not root then return end
	local character = player.Character
	local station = if entry.station then markers:FindFirstChild("Worker" .. entry.station) else crew
	root.Anchored = true
	character:PivotTo(station.CFrame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	uniform(character, entry.station ~= nil)
	updateSpeed(entry, humanoid, Workspace:GetServerTimeNow())
	root.Anchored = entry.station == nil
end

local function pickup(player, item)
	local now = Workspace:GetServerTimeNow()
	local entry = players[player]
	if phase ~= "Active" or now >= deadline or not entry or not entry.station then return end
	if now < entry.pickupAt then return end
	entry.pickupAt = now + .15
	if entry.cart or item.carrier or not item.prompt.Enabled or now < entry.questionUntil then return end
	local root, humanoid = alive(player)
	if not root then return end
	local handle = item.model.PrimaryPart
	local toCart = handle.Position - root.Position
	if toCart.Magnitude > Config.PickupDistance or Workspace:Raycast(root.Position, toCart, ray) then return end

	local offset = humanoid.HipHeight + root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = player.Character:FindFirstChild("Left Leg")
		offset += if leg then leg.Size.Y else 2
	end
	carts:claim(item, player, root, offset)
	entry.cart = item
	player:SetAttribute("CarryingCart", true)
	updateSpeed(entry, humanoid, now)
end

local function questioned(player, question, now)
	local entry = players[player]
	if not entry or not entry.station or now < entry.questionCooldown then return false end
	entry.questionUntil = now + Config.Levels[level].questionSeconds
	entry.questionCooldown = entry.questionUntil + Config.QuestionCooldown
	player:SetAttribute("Question", question)
	player:SetAttribute("QuestionUntil", entry.questionUntil)
	local _, humanoid = alive(player)
	if humanoid then updateSpeed(entry, humanoid, now) end
	return true
end

local function endShift(result, now)
	phase = "Results"
	deadline = now + Config.ResultSeconds
	outcome = result
	for player, entry in players do
		entry.cart = nil
		player:SetAttribute("CarryingCart", false)
		clearQuestion(player, entry)
		if entry.station then
			entry.station = nil
			player:SetAttribute("InShift", false)
			placePlayer(player, entry)
		end
	end
	carts:destroy()
	shiftObjects:Destroy()
	carts, shoppers, shiftObjects = nil, nil, nil
	publish()
end

local function startShift(ready, now)
	local settings = Config.shift(level, #ready)
	shiftSize, goal, banked = #ready, settings.goal, 0
	outcome = ""
	shiftObjects = Instance.new("Folder")
	shiftObjects.Name = "CurrentShift"
	shiftObjects.Parent = runtime
	carts = Carts.new(shiftObjects, Layout, random, pickup, settings.carts, settings.goal)
	shoppers = Shoppers.new(shiftObjects, Layout, random, settings.shoppers, settings.speed, now)
	for index, player in ready do
		local entry = players[player]
		entry.station = index
		entry.delivered, entry.pickupAt = 0, 0
		player:SetAttribute("ReturnedCarts", 0)
		player:SetAttribute("InShift", true)
		placePlayer(player, entry)
	end
	phase, deadline = "Active", Workspace:GetServerTimeNow() + settings.seconds
	publish()
end

local function leave(player, entry)
	releaseCart(player, entry, false)
	clearQuestion(player, entry)
	if entry.station then
		entry.station = nil
		player:SetAttribute("InShift", false)
		placePlayer(player, entry)
	end
end

local function configureCharacter(player, entry, character)
	if entry.descendants then entry.descendants:Disconnect() end
	if entry.death then entry.death:Disconnect() end
	local function configurePart(part)
		if part:IsA("BasePart") then part.CollisionGroup = staffCollision end
	end
	entry.descendants = character.DescendantAdded:Connect(configurePart)
	for _, part in character:GetDescendants() do configurePart(part) end
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or players[player] ~= entry or player.Character ~= character then return end
	entry.death = humanoid.Died:Connect(function()
		releaseCart(player, entry, false)
		clearQuestion(player, entry)
	end)
	placePlayer(player, entry)
end

local function addPlayer(player)
	if players[player] then return end
	local entry = { queued = false, pickupAt = 0, questionUntil = 0, questionCooldown = 0, delivered = 0, requestAt = 0 }
	players[player] = entry
	player:SetAttribute("Queued", false)
	player:SetAttribute("InShift", false)
	player:SetAttribute("CarryingCart", false)
	player:SetAttribute("ReturnedCarts", 0)
	clearQuestion(player, entry)
	entry.characterAdded = player.CharacterAdded:Connect(function(character)
		configureCharacter(player, entry, character)
	end)
	entry.characterRemoving = player.CharacterRemoving:Connect(function()
		releaseCart(player, entry, false)
		clearQuestion(player, entry)
	end)
	if player.Character then task.spawn(configureCharacter, player, entry, player.Character) end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local entry = players[player]
	if not entry then return end
	releaseCart(player, entry, false)
	for _, key in { "descendants", "death", "characterAdded", "characterRemoving" } do
		local connection = entry[key]
		if connection then connection:Disconnect() end
	end
	players[player] = nil
	publish()
end)
for _, player in Players:GetPlayers() do addPlayer(player) end

setQueue.OnServerEvent:Connect(function(player, enabled)
	local entry = players[player]
	local now = Workspace:GetServerTimeNow()
	if typeof(enabled) ~= "boolean" or not entry or now < entry.requestAt then return end
	entry.requestAt = now + .4
	if enabled == entry.queued then return end
	if enabled and #readyPlayers() >= Config.MaxPlayers then return end
	entry.queued = enabled
	player:SetAttribute("Queued", enabled)
	if not enabled then leave(player, entry) end
	publish()
end)

local function isInBay(position)
	local relative = bay.CFrame:PointToObjectSpace(position)
	local half = bay.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function activeStep(dt, now)
	if now >= deadline then
		endShift("Time", now)
		return
	end

	local workers = {}
	local participating, filled = 0, false
	local changed = false
	for player, entry in players do
		if not entry.station then continue end
		participating += 1
		local root, humanoid = alive(player)
		if not root then continue end
		if entry.cart and isInBay(root.Position) then
			releaseCart(player, entry, true)
			entry.delivered += 1
			player:SetAttribute("ReturnedCarts", entry.delivered)
			banked += 1
			if banked >= goal then
				filled = true
				break
			end
			changed = true
		end
		updateSpeed(entry, humanoid, now)
		if root.Position.Y > 0 and root.Position.Y < 9 and math.abs(root.Position.X) < 85 then
			local position = Vector3.new(root.Position.X, 0, root.Position.Z)
			table.insert(workers, { player = player, position = position, eligible = now >= entry.questionCooldown })
		end
	end

	if filled then
		endShift("Filled", now)
	elseif participating == 0 then
		endShift("Ended", now)
	else
		if changed then publish() end
		shoppers:step(dt, now, workers, questioned)
	end
end

publish()
stateValue.Parent = shared
setQueue.Parent = shared
local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < 1 / 15 then return end
	local step = math.min(accumulated, .15)
	accumulated = 0
	local now = Workspace:GetServerTimeNow()
	if phase == "Active" then
		activeStep(step, now)
	elseif phase == "Waiting" then
		if #readyPlayers() >= Config.MinPlayers then
			phase, deadline = "Briefing", now + Config.BriefingSeconds
			publish()
		end
	elseif phase == "Briefing" then
		local ready = readyPlayers()
		if #ready < Config.MinPlayers then
			phase, level, deadline = "Waiting", 1, 0
			publish()
		elseif now >= deadline then
			startShift(ready, now)
		end
	elseif now >= deadline then
		local ready = readyPlayers()
		if #ready < Config.MinPlayers then
			phase, level, deadline = "Waiting", 1, 0
		else
			if outcome == "Filled" then level = math.min(level + 1, #Config.Levels) end
			phase, deadline = "Briefing", now + Config.BriefingSeconds
		end
		outcome, goal, banked, shiftSize = "", 0, 0, 0
		publish()
	end
end)
