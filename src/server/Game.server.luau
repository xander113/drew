local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("CartCatcher")
local Config = require(shared.Config)
local Directory = require(script.Parent.LobbyDirectory)
local Shift = require(script.Parent.Shift)
local Wallet = require(script.Parent.Wallet)

local store = Workspace:WaitForChild("WWMS")
local crew = store.Markers.Crew
local studio = RunService:IsStudio()
local reserved = not studio and game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
local directory = Directory.new(studio)
local wallet = Wallet.new()
local players, rooms, arenaSlots = {}, {}, {}
local reservedRoom
local request = Instance.new("RemoteFunction")
request.Name = "LobbyRequest"
local changed = Instance.new("RemoteEvent")
changed.Name = "LobbyChanged"
local effects = Instance.new("RemoteEvent")
effects.Name = "ShiftEffects"
local rescue = Instance.new("RemoteEvent")
rescue.Name = "RescueInput"

local collisionGroup = "WWMSWorker"
if not PhysicsService:IsCollisionGroupRegistered(collisionGroup) then PhysicsService:RegisterCollisionGroup(collisionGroup) end
PhysicsService:CollisionGroupSetCollidable(collisionGroup, collisionGroup, false)

local function validLevel(level)
	return type(level) == "number" and level % 1 == 0 and Config.Levels[level] ~= nil
end

local function lobbyOpen(room)
	return not room.closed and room.mode == "Multi" and room.phase == "Lobby" and #room.members < Config.MaxPlayers
end

local function summary(room)
	local host = room.members[1]
	return { code = room.code, host = if host then host.DisplayName else "", level = room.level, members = #room.members }
end

local function snapshot(entry)
	entry.revision += 1
	local state = {
		revision = entry.revision, hosted = reserved, loading = entry.loading,
		travel = entry.travel ~= nil, notice = entry.notice,
	}
	local room = entry.room
	if not room then return state end

	local members = {}
	for _, member in room.members do table.insert(members, member.DisplayName) end
	state.room = {
		phase = room.phase, mode = room.mode, private = room.private,
		code = if room.private and room.mode == "Multi" then room.code else nil,
		level = room.level, host = room.members[1] == entry.player, members = members,
		deadline = room.deadline,
	}
	if room.shift then
		state.room.deadline = room.shift.deadline
		state.room.goal, state.room.banked = room.shift.goal, room.shift.banked
	elseif room.result then
		state.room.result = room.result
		state.room.mine = room.pay[entry.player]
	end
	return state
end

local function send(entry)
	changed:FireClient(entry.player, snapshot(entry))
end

local function sendRoom(room)
	for _, player in room.members do send(players[player]) end
end

local function syncDirectory(room)
	if studio then return end
	room.directoryDirty = true
	if room.directoryBusy then return end
	room.directoryBusy = true
	task.defer(function()
		while room.directoryDirty do
			room.directoryDirty = false
			local ok, err = pcall(directory.publish, directory, room, summary(room), room.closed, lobbyOpen(room))
			if not ok then warn("Cart Catcher could not update the lobby list", err) end
		end
		room.directoryBusy = false
	end)
end

local function roomChanged(room)
	sendRoom(room)
	syncDirectory(room)
end

local function newRoom(info)
	local room = {
		code = info.code, mode = info.mode, private = info.private, level = info.level,
		members = {}, phase = "Lobby", deadline = 0,
	}
	rooms[room.code] = room
	return room
end

local function joinRoom(entry, room)
	if entry.room or room.closed or room.phase ~= "Lobby" or #room.members >= Config.MaxPlayers then return false end
	if room.mode == "Solo" and #room.members > 0 then return false end
	table.insert(room.members, entry.player)
	entry.room = room
	entry.notice = nil
	roomChanged(room)
	return true
end

local function buildArena()
	if not studio then return store, Vector3.zero end
	local slot = 1
	while arenaSlots[slot] do slot += 1 end
	arenaSlots[slot] = true
	local offset = Vector3.new(((slot - 1) % 5 + 1) * 350, 0, math.floor((slot - 1) / 5) * 350)
	local arena = store:Clone()
	arena.Name = "ShiftArena" .. slot
	arena.Forecourt["Crew Spawn"].Enabled = false
	arena:PivotTo(store:GetPivot() + offset)
	arena.Parent = Workspace
	return arena, offset, slot
end

local function clearArena(room)
	if room.slot then
		room.arena:Destroy()
		arenaSlots[room.slot] = nil
	end
	room.arena, room.slot = nil, nil
end

local function startBriefing(room)
	room.phase, room.deadline = "Briefing", Workspace:GetServerTimeNow() + Config.BriefingSeconds
	room.result, room.pay = nil, nil
	roomChanged(room)
end

local function startShift(room, now)
	local arena, origin, slot = buildArena()
	room.arena, room.slot = arena, slot
	room.shift = Shift.new(room, arena, origin, now, effects)
	room.phase = "Active"
	sendRoom(room)
end

local function endShift(room, outcome)
	local shift = room.shift
	room.result = { outcome = outcome, banked = shift.banked, goal = shift.goal }
	room.pay = shift:finish(crew, wallet)
	room.shift = nil
	clearArena(room)
	room.phase, room.deadline = "Results", 0
	roomChanged(room)
end

local function leaveRoom(entry)
	local room = entry.room
	if not room then return end
	if room.shift then room.shift:remove(entry.player) end
	if room.pay then room.pay[entry.player] = nil end
	table.remove(room.members, table.find(room.members, entry.player))
	entry.room = nil
	if #room.members == 0 then
		room.closed = true
		if room.shift then room.shift:destroy() end
		clearArena(room)
		rooms[room.code] = nil
	end
	roomChanged(room)
end

local function configureCharacter(entry, character)
	if entry.descendants then entry.descendants:Disconnect() end
	if entry.death then entry.death:Disconnect() end
	local function useCollisionGroup(part)
		if part:IsA("BasePart") then part.CollisionGroup = collisionGroup end
	end
	entry.descendants = character.DescendantAdded:Connect(useCollisionGroup)
	for _, part in character:GetDescendants() do useCollisionGroup(part) end

	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local player = entry.player
	if not humanoid or not root or players[player] ~= entry or player.Character ~= character then return end
	entry.death = humanoid.Died:Connect(function()
		local shift = entry.room and entry.room.shift
		if shift then shift:reset(player) end
	end)
	local shift = entry.room and entry.room.shift
	if shift then shift:spawn(player) else Shift.place(player, crew, false) end
end

local function arrive(entry)
	local player = entry.player
	local ok, info = pcall(directory.admit, directory, player)
	if not ok then warn("Cart Catcher could not check a lobby join", info) end
	if players[player] ~= entry then return end
	entry.loading = false
	if ok and info then
		if not reservedRoom then reservedRoom = newRoom(info) end
		if reservedRoom.code == info.code and joinRoom(entry, reservedRoom) then
			if reservedRoom.mode == "Solo" then startBriefing(reservedRoom) end
			return
		end
	end
	entry.notice = if ok then "This lobby is closed or full." else "We could not open this lobby."
	send(entry)
end

local function addPlayer(player)
	if players[player] then return end
	local entry = { player = player, loading = reserved, revision = 0, requestAt = 0, createAt = 0, listAt = 0, syncAt = 0, joinAt = 0 }
	players[player] = entry
	wallet:add(player)
	entry.added = player.CharacterAdded:Connect(function(character) configureCharacter(entry, character) end)
	entry.removing = player.CharacterRemoving:Connect(function()
		local shift = entry.room and entry.room.shift
		if shift then shift:reset(player) end
	end)
	if player.Character then task.spawn(configureCharacter, entry, player.Character) end
	if reserved then task.spawn(arrive, entry) end
end

local function travel(entry, options)
	local player = entry.player
	if players[player] ~= entry then return { error = "You left the game." } end
	local attempt = {}
	entry.travel, entry.notice = attempt, nil
	send(entry)
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
	if not ok then
		warn("Cart Catcher could not move a player", err)
		if entry.travel == attempt then entry.travel = nil end
		send(entry)
		return { error = "Could not move you. Try again." }
	end
	task.delay(35, function()
		if players[player] == entry and entry.travel == attempt then
			entry.travel = nil
			entry.notice = "Could not move you. Try again."
			send(entry)
		end
	end)
	return {}
end

local function browse()
	if not studio then return directory:list() end
	local rows = {}
	for _, room in rooms do
		if lobbyOpen(room) and not room.private then table.insert(rows, summary(room)) end
	end
	table.sort(rows, function(a, b)
		return if a.host == b.host then a.code < b.code else a.host < b.host
	end)
	return rows
end

local function create(entry, mode, level, privacy)
	if not validLevel(level) or type(privacy) ~= "boolean" then return { error = "Pick a level." } end
	local now = os.clock()
	if now < entry.createAt then return { error = "Wait a moment and try again." } end
	entry.createAt = now + 4
	if not studio then
		local room = directory:create(entry.player.UserId, mode, privacy, level)
		return travel(entry, directory:options(room, entry.player.UserId))
	end
	local code = directory:newCode()
	while rooms[code] do code = directory:newCode() end
	local room = newRoom({ code = code, mode = mode, private = privacy, level = level })
	joinRoom(entry, room)
	if mode == "Solo" then startBriefing(room) end
	return {}
end

local function handle(entry, action, arg, extra)
	local room = entry.room
	if entry.loading or entry.travel then return { error = "Please wait." } end
	if action == "Leave" then
		if reserved then
			wallet:waitForSave(entry.player.UserId, 3)
			return travel(entry, nil)
		end
		leaveRoom(entry)
		Shift.place(entry.player, crew, false)
		send(entry)
		return {}
	end
	if room then
		if room.members[1] ~= entry.player then return { error = "Only the host can do that." } end
		if room.phase == "Lobby" or room.phase == "Results" then
			if action == "Level" and validLevel(arg) then
				room.level = arg
				roomChanged(room)
				return {}
			end
			if action == "Start" then
				startBriefing(room)
				return {}
			end
			if action == "Reopen" and room.mode == "Multi" and room.phase == "Results" then
				room.phase, room.result, room.pay = "Lobby", nil, nil
				roomChanged(room)
				return {}
			end
		end
		return { error = "You are already in a lobby." }
	end
	if reserved then return { error = "Go back to the menu." } end

	if action == "Solo" then return create(entry, "Solo", arg, true) end
	if action == "Create" then return create(entry, "Multi", arg, extra) end
	if action == "JoinCode" or action == "JoinPublic" then
		local code = Directory.code(arg)
		if not code then return { error = "Use the 7 letters or numbers in the code." } end
		local now = os.clock()
		if now < entry.joinAt then return { error = "Wait a moment and try again." } end
		entry.joinAt = now + .8
		local publicOnly = action == "JoinPublic"
		if not studio then
			local target = directory:find(code, publicOnly, Config.MaxPlayers)
			if target then return travel(entry, directory:options(target, entry.player.UserId)) end
		else
			local target = rooms[code]
			if target and lobbyOpen(target) and (not publicOnly or not target.private) and joinRoom(entry, target) then return {} end
		end
		return { error = "This lobby is closed or full." }
	end
	return { error = "Try again." }
end

request.OnServerInvoke = function(player, action, arg, extra)
	local entry = players[player]
	if not entry then return { error = "Please wait." } end
	local now = os.clock()
	if action == "Sync" then
		if now < entry.syncAt then return { error = "Please wait." } end
		entry.syncAt = now + .6
		return { state = snapshot(entry) }
	end
	if action == "Browse" then
		if now < entry.listAt or entry.room or reserved then return { error = "Please wait." } end
		entry.listAt = now + 1.5
		local ok, rows = pcall(browse)
		return if ok then { rows = rows } else { error = "Could not look for lobbies." }
	end
	if now < entry.requestAt or entry.busy then return { error = "Please wait." } end
	entry.requestAt = now + .25
	entry.busy = true
	local ok, result = pcall(handle, entry, action, arg, extra)
	entry.busy = false
	if ok then return result end
	warn("Cart Catcher lobby request failed", action, result)
	return { error = "That did not work. Try again." }
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local entry = players[player]
	if not entry then return end
	leaveRoom(entry)
	for _, key in { "added", "removing", "descendants", "death" } do
		if entry[key] then entry[key]:Disconnect() end
	end
	players[player] = nil
	wallet:remove(player)
end)
for _, player in Players:GetPlayers() do addPlayer(player) end

TeleportService.TeleportInitFailed:Connect(function(player)
	local entry = players[player]
	if not entry or not entry.travel then return end
	entry.travel = nil
	entry.notice = "Could not move you. Try again."
	send(entry)
end)

rescue.OnServerEvent:Connect(function(player, action, target)
	local entry = players[player]
	local shift = entry and entry.room and entry.room.shift
	if shift then shift:rescue(player, action, target, Workspace:GetServerTimeNow()) end
end)

effects.Parent = shared
rescue.Parent = shared
changed.Parent = shared
request.Parent = shared

local elapsed, nextDirectorySync = 0, 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 / 15 then return end
	local step = math.min(elapsed, .15)
	elapsed = 0
	local now = Workspace:GetServerTimeNow()
	local updateDirectory = not studio and now >= nextDirectorySync
	if updateDirectory then nextDirectorySync = now + 20 end
	for _, room in rooms do
		if room.phase == "Briefing" and now >= room.deadline then
			startShift(room, now)
		elseif room.shift then
			local outcome, progress = room.shift:step(step, now)
			if outcome then endShift(room, outcome)
			elseif progress then sendRoom(room) end
		end
		if updateDirectory then syncDirectory(room) end
	end
end)

game:BindToClose(function() wallet:close() end)
