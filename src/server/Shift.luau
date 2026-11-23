local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("CartCatcher")
local Config = require(shared.Config)
local Layout = require(shared.Layout)
local Pay = require(shared.Pay)
local Carts = require(script.Parent.Carts)
local Shoppers = require(script.Parent.Shoppers)

local Shift = {}
Shift.__index = Shift

local function alive(player)
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then return root, humanoid end
	return nil
end

local function badge(player, visible)
	local head = player.Character:FindFirstChild("Head")
	if not head then return end
	local old = head:FindFirstChild("WWMSCrew")
	if old then old:Destroy() end
	if not visible then return end

	local tag = Instance.new("BillboardGui")
	tag.Name = "WWMSCrew"
	tag.Size = UDim2.fromOffset(44, 15)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.25, 0)
	tag.MaxDistance, tag.PlayerToHideFrom = 48, player
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundColor3 = Color3.fromRGB(0, 81, 206)
	caption.BorderSizePixel = 0
	caption.TextColor3 = Color3.fromRGB(255, 223, 104)
	caption.Font, caption.TextSize, caption.Text = Enum.Font.GothamBold, 10, "WWMS"
	caption.Parent = tag
	tag.Parent = head
end

function Shift.place(player, station, active)
	local root, humanoid = alive(player)
	if not root then return end
	root.Anchored = true
	player.Character:PivotTo(station.CFrame)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	badge(player, active)
	humanoid.WalkSpeed = Config.WalkSpeed
	root.Anchored = not active
end

local function clearQuestion(player, entry)
	entry.questionUntil, entry.questionCooldown = 0, 0
	player:SetAttribute("QuestionUntil", 0)
	player:SetAttribute("Question", "")
end

local function updateSpeed(entry, humanoid, now)
	local speed = if now < entry.questionUntil then Config.QuestionSpeed elseif entry.cart then Config.PushSpeed else Config.WalkSpeed
	if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
end

function Shift.new(room, arena, origin, now)
	local settings = Config.shift(room.level, #room.members)
	local markers = arena.Markers
	local objects = Instance.new("Folder")
	objects.Name, objects.Parent = "ShiftObjects", arena
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Include
	ray.FilterDescendantsInstances = { arena }
	ray.RespectCanCollide = true
	local self = setmetatable({
		id = HttpService:GenerateGUID(false), level = room.level, deadline = 0, goal = settings.goal,
		banked = 0, entries = {}, objects = objects, bay = markers.CartHole, origin = origin, ray = ray,
		questionSeconds = settings.questionSeconds, workers = #room.members,
	}, Shift)
	local random = Random.new()
	self.carts = Carts.new(objects, Layout, random, function(player, item)
		self:pickup(player, item)
	end, settings.carts, settings.goal, origin)
	self.shoppers = Shoppers.new(objects, Layout, random, settings.shoppers, settings.speed, now, origin)
	for index, player in room.members do
		local entry = { station = markers["Worker" .. index], delivered = 0, pickupAt = 0 }
		self.entries[player] = entry
		player:SetAttribute("CarryingCart", false)
		player:SetAttribute("ReturnedCarts", 0)
		clearQuestion(player, entry)
		Shift.place(player, entry.station, true)
	end
	self.deadline = Workspace:GetServerTimeNow() + settings.seconds
	return self
end

function Shift:spawn(player)
	local entry = self.entries[player]
	if entry then Shift.place(player, entry.station, true) end
end

function Shift:release(player, entry, returned)
	if entry.cart then
		self.carts:release(entry.cart, returned)
		entry.cart = nil
		player:SetAttribute("CarryingCart", false)
	end
end

function Shift:reset(player)
	local entry = self.entries[player]
	if not entry then return end
	self:release(player, entry, false)
	clearQuestion(player, entry)
end

function Shift:remove(player)
	self:reset(player)
	self.entries[player] = nil
end

function Shift:pickup(player, item)
	local now = Workspace:GetServerTimeNow()
	local entry = self.entries[player]
	if not entry or now >= self.deadline or now < entry.pickupAt then return end
	entry.pickupAt = now + .15
	if entry.cart or item.carrier or not item.prompt.Enabled or now < entry.questionUntil then return end
	local root, humanoid = alive(player)
	if not root then return end
	local delta = item.model.PrimaryPart.Position - root.Position
	if delta.Magnitude > Config.PickupDistance or Workspace:Raycast(root.Position, delta, self.ray) then return end

	local offset = humanoid.HipHeight + root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = player.Character:FindFirstChild("Left Leg")
		offset += if leg then leg.Size.Y else 2
	end
	self.carts:claim(item, player, root, offset)
	entry.cart = item
	player:SetAttribute("CarryingCart", true)
	updateSpeed(entry, humanoid, now)
end

function Shift:question(player, text, now)
	local entry = self.entries[player]
	if not entry or now < entry.questionCooldown then return false end
	entry.questionUntil = now + self.questionSeconds
	entry.questionCooldown = entry.questionUntil + Config.QuestionCooldown
	player:SetAttribute("Question", text)
	player:SetAttribute("QuestionUntil", entry.questionUntil)
	local _, humanoid = alive(player)
	if humanoid then updateSpeed(entry, humanoid, now) end
	return true
end

local function inBay(bay, position)
	local relative = bay.CFrame:PointToObjectSpace(position)
	local half = bay.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

function Shift:step(dt, now)
	if now >= self.deadline then return "Time", false end
	local workers = {}
	local changed = false
	for player, entry in self.entries do
		local root, humanoid = alive(player)
		if not root then continue end
		if entry.cart and inBay(self.bay, root.Position) then
			self:release(player, entry, true)
			entry.delivered += 1
			player:SetAttribute("ReturnedCarts", entry.delivered)
			self.banked += 1
			changed = true
			if self.banked >= self.goal then return "Filled", true end
		end
		updateSpeed(entry, humanoid, now)
		local position = root.Position - self.origin
		if position.Y > 0 and position.Y < 9 and math.abs(position.X) < 85 and position.Z >= -69 then
			table.insert(workers, {
				player = player, position = Vector3.new(position.X, 0, position.Z),
				eligible = now >= entry.questionCooldown,
			})
		end
	end
	self.shoppers:step(dt, now, workers, function(player, text, time)
		return self:question(player, text, time)
	end)
	return nil, changed
end

function Shift:finish(crew, wallet)
	local results = {}
	for player, entry in self.entries do
		local pay = Pay.shift(entry.delivered, self.banked, self.goal, Config.Levels[self.level].payPercent)
		results[player] = { carts = entry.delivered, pay = pay }
		wallet:earn(player, self.id, pay.total)
		player:SetAttribute("CarryingCart", false)
		clearQuestion(player, entry)
		Shift.place(player, crew, false)
	end
	self:destroy()
	return results
end

function Shift:destroy()
	self.carts:destroy()
	self.objects:Destroy()
end

return Shift
