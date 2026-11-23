local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Wallet = {}
Wallet.__index = Wallet

local RECEIPT_LIFETIME = 2 * 24 * 60 * 60

local function count(value)
	return if type(value) == "number" and value >= 0 and value < math.huge then math.floor(value) else 0
end

local function dictionary(value)
	return if type(value) == "table" then table.clone(value) else {}
end

local function read(value)
	local data = if type(value) == "table" then value else {}
	return {
		cents = count(data.cents), receipts = dictionary(data.receipts), purchases = dictionary(data.purchases),
		items = dictionary(data.items), rounds = count(data.rounds), wins = count(data.wins), carts = count(data.carts),
	}
end

local function apply(data, entry)
	if entry.purchase then
		if data.purchases[entry.id] then return end
		data.purchases[entry.id] = true
		data.items[entry.item] = count(data.items[entry.item]) + 1
		return
	end
	if data.receipts[entry.id] then return end
	data.receipts[entry.id] = entry.issued
	data.cents = math.max(0, data.cents + (entry.cents or 0))
	if entry.item then data.items[entry.item] = 1 end
	if entry.round then
		data.rounds += 1
		if entry.won then data.wins += 1 end
		data.carts += entry.carts
	end
end

local function show(profile)
	if not profile.player then return end
	local amount = profile.saved.cents
	for _, entry in profile.pending do
		if not profile.saved.receipts[entry.id] then amount = math.max(0, amount + (entry.cents or 0)) end
	end
	profile.player:SetAttribute("WalbucksCents", amount)
	profile.player:SetAttribute("WalletReady", profile.loaded)
	profile.player:SetAttribute("WalletSaving", #profile.pending > 0)
end

function Wallet.new()
	local self = setmetatable({
		store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore("CartCatcherWallet_v1"),
		profiles = {},
	}, Wallet)
	task.spawn(function()
		while true do
			task.wait(35)
			for id, profile in self.profiles do
				if profile.player or #profile.pending > 0 then task.spawn(self.flush, self, id, true) end
			end
		end
	end)
	return self
end

function Wallet:add(player)
	local id = player.UserId
	local profile = self.profiles[id]
	if not profile then
		profile = { saved = read(nil), loaded = self.store == nil, pending = {}, queued = {}, busy = false }
		self.profiles[id] = profile
	end
	profile.player = player
	show(profile)
	task.spawn(self.flush, self, id, true)
end

function Wallet:queue(id, entry)
	local profile = self.profiles[id]
	if not profile or profile.queued[entry.id] or profile.saved.receipts[entry.id] or profile.saved.purchases[entry.id] then return end
	entry.issued = os.time()
	if self.store then
		profile.queued[entry.id] = true
		table.insert(profile.pending, entry)
		task.defer(self.flush, self, id)
	else
		apply(profile.saved, entry)
	end
	show(profile)
end

function Wallet:earn(player, id, cents)
	if cents > 0 then self:queue(player.UserId, { id = id, cents = cents }) end
end

function Wallet:finishShift(player, id, cents, carts, won)
	self:queue(player.UserId, { id = "shift:" .. id, cents = cents, carts = carts, round = true, won = won })
end

function Wallet:penalty(player, id, cents)
	self:queue(player.UserId, { id = "leave:" .. id, cents = -cents })
end

function Wallet:grantPass(player, item)
	if self:quantity(player, item) == 0 then self:queue(player.UserId, { id = "owned:" .. item, item = item }) end
end

function Wallet:quantity(player, item)
	local profile = self.profiles[player.UserId]
	return if profile then count(profile.saved.items[item]) else 0
end

function Wallet:purchase(userId, receipt, item)
	local profile = self.profiles[userId]
	if not profile then return false end
	self:queue(userId, { id = receipt, purchase = true, item = item })
	self:waitForSave(userId, 9)
	return profile.saved.purchases[receipt] == true
end

function Wallet:flush(id, refresh)
	local profile = self.profiles[id]
	if not profile or profile.busy or not self.store then return end
	profile.busy = true
	local succeeded = false
	local key = "u:" .. id
	for attempt = 1, 3 do
		local batch = table.clone(profile.pending)
		if #batch == 0 and profile.loaded and not refresh then break end
		local ok, result
		if #batch > 0 then
			local cutoff = os.time() - RECEIPT_LIFETIME
			ok, result = pcall(self.store.UpdateAsync, self.store, key, function(old)
				local data = read(old)
				for receipt, when in data.receipts do
					if type(when) ~= "number" or when < cutoff then data.receipts[receipt] = nil end
				end
				for _, entry in batch do apply(data, entry) end
				return data
			end)
		else
			local options = Instance.new("DataStoreGetOptions")
			options.UseCache = false
			ok, result = pcall(self.store.GetAsync, self.store, key, options)
		end
		if ok then
			succeeded = true
			profile.saved, profile.loaded = read(result), true
			for _, entry in batch do
				table.remove(profile.pending, 1)
				profile.queued[entry.id] = nil
			end
			show(profile)
			break
		end
		if attempt == 3 then warn("Cart Catcher wallet save failed", id, result)
		else task.wait(2 ^ (attempt - 1)) end
	end
	profile.busy = false
	if succeeded and #profile.pending > 0 then
		task.defer(self.flush, self, id)
	elseif not profile.player and #profile.pending == 0 then
		self.profiles[id] = nil
	end
end

function Wallet:waitForSave(id, seconds)
	local profile = self.profiles[id]
	if not profile or #profile.pending == 0 then return true end
	task.spawn(self.flush, self, id)
	local deadline = os.clock() + seconds
	while #profile.pending > 0 and os.clock() < deadline do task.wait(.15) end
	return #profile.pending == 0
end

function Wallet:remove(player)
	local profile = self.profiles[player.UserId]
	if not profile or profile.player ~= player then return end
	profile.player = nil
	if self.store then task.spawn(self.flush, self, player.UserId) end
end

function Wallet:close()
	if not self.store then return end
	for id, profile in self.profiles do
		if #profile.pending > 0 then task.spawn(self.flush, self, id) end
	end
	local deadline = os.clock() + 24
	repeat
		local waiting = false
		for _, profile in self.profiles do
			if #profile.pending > 0 then waiting = true break end
		end
		if not waiting then return end
		task.wait(.2)
	until os.clock() >= deadline
end

return Wallet
