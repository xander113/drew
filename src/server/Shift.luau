local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("CartCatcher")
local Config = require(shared.Config)
local Layout = require(shared.Layout)
local Pay = require(shared.Pay)
local Timing = require(shared.RescueTiming)
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
	humanoid.WalkSpeed, humanoid.AutoRotate = Config.WalkSpeed, true
	root.Anchored = not active
end

local function updateSpeed(entry, humanoid)
	local speed = if entry.stop or entry.slip then 0 elseif entry.cart then Config.PushSpeed else Config.WalkSpeed
	if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
end

function Shift.new(room, arena, origin, now, effects)
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
		effects = effects, difficulty = Config.Levels[room.level], random = Random.new(), serial = 0,
	}, Shift)
	self.carts = Carts.new(objects, Layout, self.random, function(player, item)
		self:pickup(player, item)
	end, settings.carts, origin)
	self.shoppers = Shoppers.new(objects, Layout, self.random, settings.shoppers, settings.speed, now, origin, self.difficulty.encounters.range)
	for index, player in room.members do
		local entry = { station = markers["Worker" .. index], delivered = 0, pickupAt = 0, safeUntil = now + self.difficulty.encounters.grace, checkAt = 0, rescueAt = 0 }
		self.entries[player] = entry
		player:SetAttribute("CarryingCart", false)
		player:SetAttribute("ReturnedCarts", 0)
		player:SetAttribute("Stopped", false)
		player:SetAttribute("Slipped", false)
		Shift.place(player, entry.station, true)
	end
	self.deadline = Workspace:GetServerTimeNow() + settings.seconds
	return self
end

function Shift:spawn(player)
	local entry = self.entries[player]
	if entry then Shift.place(player, entry.station, true) end
end

function Shift:release(player, entry, dock)
	if entry.cart then
		self.carts:release(entry.cart, dock)
		entry.cart = nil
		player:SetAttribute("CarryingCart", false)
	end
end

function Shift:reset(player)
	local entry = self.entries[player]
	if not entry then return end
	self:release(player, entry)
	self:endStop(player, entry, "Gone", Workspace:GetServerTimeNow())
	self:endRescue(player, entry, "Lost")
	self:endSlip(player, entry, false)
	entry.wet = nil
	entry.safeUntil = Workspace:GetServerTimeNow() + 3
end

function Shift:remove(player)
	self:reset(player)
	self.entries[player] = nil
end

function Shift:pickup(player, item)
	local now = Workspace:GetServerTimeNow()
	local entry = self.entries[player]
	if not entry or self.wonAt or now >= self.deadline or now < entry.pickupAt then return end
	entry.pickupAt = now + .15
	if entry.cart or entry.stop or entry.slip or item.carrier or not item.prompt.Enabled then return end
	local root, humanoid = alive(player)
	if not root then return end
	local delta = item.model.PrimaryPart.Position - root.Position
	if delta.Magnitude > Config.PickupDistance or Workspace:Raycast(root.Position, delta, self.ray) then return end

	local offset = humanoid.HipHeight + root.Size.Y / 2
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = player.Character:FindFirstChild("Left Leg")
		offset += if leg then leg.Size.Y else 2
	end
	local position = item.model.PrimaryPart.Position
	self.carts:claim(item, player, root, offset, now)
	entry.cart = item
	player:SetAttribute("CarryingCart", true)
	updateSpeed(entry, humanoid)
	self.effects:FireClient(player, "Grab", { position = position })
end

function Shift:broadcast(kind, payload)
	for player in self.entries do self.effects:FireClient(player, kind, payload) end
end

function Shift:question(player, shopper, lines, now)
	local entry = self.entries[player]
	if not entry or entry.stop or entry.slip or entry.rescue or now < entry.safeUntil or now < entry.checkAt or self.deadline - now < 2 then return false end
	local root, humanoid = alive(player)
	if not root or root.Anchored or root.Position.Y - self.origin.Y > 4.6 then return false end
	local direction = shopper.model.PrimaryPart.Position - root.Position
	if Workspace:Raycast(root.Position, direction, self.ray) then return false end

	local encounters = self.difficulty.encounters
	entry.checkAt = now + encounters.retry
	if self.random:NextNumber(0, 1) >= encounters.chance then return false end
	self.shoppers:stop(shopper, root.Position)
	local at = root.Position
	local target = shopper.model.PrimaryPart.Position
	local flat = Vector3.new(target.X - at.X, 0, target.Z - at.Z)
	if flat.Magnitude > .01 then root.CFrame = CFrame.lookAt(at, at + flat) end
	root.Anchored = true
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	humanoid.AutoRotate = false
	self.serial += 1
	local untilTime = math.min(self.deadline, now + self.difficulty.stopSeconds)
	entry.stop = { id = self.serial, shopper = shopper, started = now, untilTime = untilTime, root = root, humanoid = humanoid }
	updateSpeed(entry, humanoid)
	player:SetAttribute("Stopped", true)
	self:broadcast("Stopped", {
		id = entry.stop.id, worker = player, shopper = shopper.model,
		lines = lines, name = shopper.model.Name, start = now, finish = untilTime,
	})
	return true
end

function Shift:endRescue(player, entry, outcome)
	local attempt = entry.rescue
	if not attempt then return end
	entry.rescue = nil
	self.effects:FireClient(player, "RescueEnd", { id = attempt.id, outcome = outcome })
end

function Shift:endStop(player, entry, outcome, now)
	local stop = entry.stop
	if not stop then return end
	entry.stop, entry.safeUntil = nil, now + self.difficulty.encounters.cooldown
	if stop.root.Parent and stop.root.Parent == player.Character then
		stop.humanoid.AutoRotate = true
		updateSpeed(entry, stop.humanoid)
		stop.root.Anchored = false
	end
	player:SetAttribute("Stopped", false)
	self.shoppers:resume(stop.shopper, now)
	for helper, helperEntry in self.entries do
		if helperEntry.rescue and helperEntry.rescue.stop == stop then self:endRescue(helper, helperEntry, "Lost") end
	end
	self:broadcast("Freed", { id = stop.id, worker = player, outcome = outcome })
end

function Shift:near(helper, target)
	local root = alive(helper)
	local targetRoot = alive(target)
	if not root or not targetRoot then return false end
	local offset = targetRoot.Position - root.Position
	local gap = offset.Magnitude
	return gap <= Config.RescueDistance and (gap < .01 or Workspace:Raycast(root.Position, offset, self.ray) == nil)
end

function Shift:rescue(player, action, target, now)
	local entry = self.entries[player]
	if not entry or entry.stop or entry.slip or self.wonAt or now >= self.deadline or now < entry.rescueAt then return end
	entry.rescueAt = now + .12
	if action == "Begin" then
		local victim = self.entries[target]
		local stop = victim and victim.stop
		if entry.rescue or not stop or target == player or not self:near(player, target) then return end
		local pattern = Timing.build(self.difficulty, now, self.random)
		if pattern.start + #pattern.cues * pattern.period > stop.untilTime then
			self.effects:FireClient(player, "RescueNote", "Too late to help.")
			return
		end
		self.serial += 1
		local attempt = { id = self.serial, step = 1, target = target, stop = stop, pattern = pattern }
		entry.rescue = attempt
		self.effects:FireClient(player, "RescueStart", { id = attempt.id, pattern = pattern })
	elseif action == "Tap" then
		local attempt = entry.rescue
		if not attempt or target ~= attempt.id then return end
		local victim = self.entries[attempt.target]
		if not victim or victim.stop ~= attempt.stop or not self:near(player, attempt.target) then
			self:endRescue(player, entry, "Lost")
			return
		end
		if now < attempt.pattern.start then return end
		if not Timing.hit(attempt.pattern, attempt.step, now, player:GetNetworkPing()) then
			self:endRescue(player, entry, "Miss")
			return
		end
		attempt.step += 1
		if attempt.step > #attempt.pattern.cues then
			self:endRescue(player, entry, "Hit")
			self:endStop(attempt.target, victim, "Helped", now)
		else
			self.effects:FireClient(player, "RescueStep", { id = attempt.id, step = attempt.step })
		end
	end
end

function Shift:isRunning(now)
	return not self.wonAt and now < self.deadline
end

local function wetSpot(position)
	for _, wet in Layout.WetSpots do
		local dx = (position.X - wet.x) / (wet.width / 2)
		local dz = (position.Z - wet.z) / (wet.depth / 2)
		if dx * dx + dz * dz < 1 then return wet end
	end
	return nil
end

function Shift:slip(player, entry, root, humanoid, now)
	local start = root.Position
	local velocity = root.AssemblyLinearVelocity
	local forward = Vector3.new(velocity.X, 0, velocity.Z)
	if forward.Magnitude < .8 then forward = root.CFrame.LookVector end
	forward = Vector3.new(forward.X, 0, forward.Z).Unit
	local distance = 2.1
	local hit = Workspace:Raycast(start, forward * distance, self.ray)
	if hit then distance = math.max(0, hit.Distance - 1.1) end
	local stand = start + forward * distance
	local upright = CFrame.lookAt(stand, stand + forward)
	local fallen = CFrame.lookAt(stand - Vector3.new(0, 1.7, 0), stand + forward - Vector3.new(0, 1.7, 0))
		* CFrame.Angles(math.rad(-78), 0, 0)
	self:release(player, entry)
	self:endRescue(player, entry, "Lost")
	root.Anchored, humanoid.AutoRotate = true, false
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	local recovery = self.difficulty.slipSeconds
	local fall = TweenService:Create(root, TweenInfo.new(.29, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = fallen })
	entry.slip = { root = root, humanoid = humanoid, recover = now + recovery, stand = upright, motion = fall }
	updateSpeed(entry, humanoid)
	player:SetAttribute("Slipped", true)
	fall:Play()
end

function Shift:endSlip(player, entry, stand)
	local slip = entry.slip
	if not slip then return end
	entry.slip = nil
	slip.motion:Cancel()
	if slip.root.Parent and slip.root.Parent == player.Character then
		if stand then slip.root.CFrame = slip.stand end
		slip.humanoid.AutoRotate = true
		updateSpeed(entry, slip.humanoid)
		slip.root.Anchored = false
	end
	player:SetAttribute("Slipped", false)
end

function Shift:checkWet(player, entry, root, humanoid, now)
	local position = root.Position - self.origin
	local wet = if position.Y < 3.75 and position.Y > 2 and humanoid.FloorMaterial ~= Enum.Material.Air then wetSpot(position) else nil
	if not wet then entry.wet = nil return end
	if wet ~= entry.wet then
		entry.wet = wet
		self:slip(player, entry, root, humanoid, now)
	end
end

local function inBay(bay, position)
	local relative = bay.CFrame:PointToObjectSpace(position)
	local half = bay.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

function Shift:step(dt, now)
	if self.wonAt then return if now >= self.wonAt then "Filled" else nil, false end
	if now >= self.deadline then return "Time", false end
	local workers = {}
	local changed = false
	for player, entry in self.entries do
		if entry.stop and now >= entry.stop.untilTime then self:endStop(player, entry, "Done", now) end
		local slip = entry.slip
		if slip and now >= slip.recover then
			self:endSlip(player, entry, true)
		elseif slip and not slip.rising and now >= slip.recover - .34 then
			slip.rising = true
			slip.motion:Cancel()
			slip.motion = TweenService:Create(slip.root, TweenInfo.new(.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = slip.stand })
			slip.motion:Play()
		end
		local attempt = entry.rescue
		if attempt then
			if not self:near(player, attempt.target) then
				self:endRescue(player, entry, "Lost")
			elseif Timing.slot(attempt.pattern, attempt.step, now - .16) >= 1 then
				self:endRescue(player, entry, "Miss")
			end
		end
		local root, humanoid = alive(player)
		if not root then continue end
		if not entry.stop and not entry.slip then self:checkWet(player, entry, root, humanoid, now) end
		local cart = entry.cart
		if cart and not entry.stop and not entry.slip and (inBay(self.bay, root.Position) or inBay(self.bay, cart.model.PrimaryPart.Position)) then
			local dockX = math.clamp(root.Position.X, self.bay.Position.X - 10, self.bay.Position.X + 10)
			local dock = Vector3.new(dockX, self.origin.Y + .68, self.bay.Position.Z + 2.5)
			self:release(player, entry, dock)
			entry.delivered += 1
			player:SetAttribute("ReturnedCarts", entry.delivered)
			self.banked += 1
			changed = true
			local full = self.banked >= self.goal
			self:broadcast("Returned", { worker = player, position = dock, full = full })
			if full then
				self.wonAt = now + 1.05
				for worker, workerEntry in self.entries do self:endStop(worker, workerEntry, "Gone", now) end
				return nil, true
			end
		end
		updateSpeed(entry, humanoid)
		local position = root.Position - self.origin
		if position.Y > 0 and position.Y < 9 and math.abs(position.X) < 85 and position.Z >= -69 then
			table.insert(workers, {
				player = player, position = Vector3.new(position.X, 0, position.Z),
				eligible = not entry.stop and not entry.slip and not entry.rescue and now >= entry.safeUntil and now >= entry.checkAt,
			})
		end
	end
	self.shoppers:step(dt, now, workers, function(player, shopper, lines, time)
		return self:question(player, shopper, lines, time)
	end)
	return nil, changed
end

function Shift:saveResult(player, wallet)
	local entry = self.entries[player]
	if not entry then return nil end
	local pay = Pay.shift(entry.delivered, self.banked, self.goal, self.difficulty.payPercent)
	wallet:finishShift(player, self.id, pay.total, entry.delivered, self.banked >= self.goal)
	return { carts = entry.delivered, pay = pay }
end

function Shift:finish(crew, wallet)
	local results = {}
	for player, entry in self.entries do
		results[player] = self:saveResult(player, wallet)
		player:SetAttribute("CarryingCart", false)
		self:endStop(player, entry, "Gone", Workspace:GetServerTimeNow())
		self:endRescue(player, entry, "Lost")
		self:endSlip(player, entry, true)
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
