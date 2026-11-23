local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")

local Directory = {}
Directory.__index = Directory

local ROOM_TTL = 110
local JOIN_TTL = 65
local ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
local CODE_LENGTH = 7

function Directory.code(value)
	if type(value) ~= "string" or #value > 32 then return nil end
	local code = string.upper(string.match(value, "^%s*(.-)%s*$"))
	if #code == CODE_LENGTH and not string.find(code, "[^" .. ALPHABET .. "]") then return code end
	return nil
end

function Directory.new(studio)
	return setmetatable({
		random = Random.new(),
		rooms = if studio then nil else MemoryStoreService:GetHashMap("CCRooms_v2"),
		public = if studio then nil else MemoryStoreService:GetSortedMap("CCPublic_v2"),
		tickets = if studio then nil else MemoryStoreService:GetHashMap("CCJoin_v2"),
	}, Directory)
end

function Directory:newCode()
	local code = {}
	for index = 1, CODE_LENGTH do
		local char = self.random:NextInteger(1, #ALPHABET)
		code[index] = string.sub(ALPHABET, char, char)
	end
	return table.concat(code)
end

function Directory:create(owner, mode, privacy, level)
	local access, privateId = TeleportService:ReserveServerAsync(game.PlaceId)
	local room = {
		owner = owner, mode = mode, private = privacy, level = level,
		access = access, privateId = privateId, open = false, members = 0,
	}
	for _ = 1, 5 do
		room.code = self:newCode()
		local result = self.rooms:UpdateAsync(room.code, function(current)
			if current == nil then return room end
			return nil
		end, ROOM_TTL)
		if result and result.privateId == privateId then return result end
	end
	error("Could not reserve a lobby code")
end

function Directory:find(code, publicOnly, maxPlayers)
	local room = self.rooms:GetAsync(code)
	if room and room.mode == "Multi" and room.open and room.members < maxPlayers and (not publicOnly or not room.private) then
		return room
	end
	return nil
end

function Directory:list()
	local now = os.clock()
	if self.cached and now < self.cacheUntil then return self.cached end
	if self.reading then
		local deadline = now + 5
		repeat task.wait(.15) until not self.reading or os.clock() >= deadline
		if self.cached then return self.cached end
		error("Lobby list is busy")
	end
	self.reading = true
	local ok, rows = pcall(self.public.GetRangeAsync, self.public, Enum.SortDirection.Descending, 25)
	self.reading = false
	if not ok then error(rows) end
	local result = {}
	for _, row in rows do
		table.insert(result, row.value)
	end
	self.cached, self.cacheUntil = result, os.clock() + 5
	return result
end

function Directory:options(room, userId)
	local token = HttpService:GenerateGUID(false)
	self.tickets:SetAsync(room.code .. ":" .. userId, token, JOIN_TTL)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = room.access
	options:SetTeleportData({ code = room.code, token = token })
	return options
end

function Directory:admit(player)
	local join = player:GetJoinData()
	local data = join.TeleportData
	local code = type(data) == "table" and Directory.code(data.code)
	if not code or join.SourceGameId ~= game.GameId or type(data.token) ~= "string" or #data.token ~= 36 then return nil end
	local token = self.tickets:GetAsync(code .. ":" .. player.UserId)
	if not token or token ~= data.token then return nil end
	local room = self.rooms:GetAsync(code)
	if not room or room.privateId ~= game.PrivateServerId then return nil end
	if room.job and room.job ~= game.JobId then return nil end
	if not room.job and player.UserId ~= room.owner then return nil end
	if room.job then return room end
	-- Roblox can split players with incompatible cross-play settings into another job.
	return self.rooms:UpdateAsync(code, function(current)
		if not current or current.privateId ~= game.PrivateServerId or (current.job and current.job ~= game.JobId) then return nil end
		current.job = game.JobId
		return current
	end, ROOM_TTL)
end

function Directory:publish(room, summary, closed, open)
	local current = self.rooms:UpdateAsync(room.code, function(data)
		if not data or data.job ~= game.JobId then return nil end
		data.open = open
		data.members = summary.members
		data.level = summary.level
		return data
	end, if closed then 15 else ROOM_TTL)
	if room.mode == "Multi" and not room.private then
		if current and current.open then
			self.public:SetAsync(room.code, summary, ROOM_TTL, os.time())
		else
			self.public:RemoveAsync(room.code)
		end
	end
end

return Directory
