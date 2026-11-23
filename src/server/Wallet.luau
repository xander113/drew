local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Wallet = {}
Wallet.__index = Wallet

local RECEIPT_LIFETIME = 2 * 24 * 60 * 60

local function unpackData(data)
	if type(data) ~= "table" or type(data.cents) ~= "number" or data.cents < 0 or data.cents >= math.huge or data.cents % 1 ~= 0 then
		return 0, {}
	end
	return data.cents, if type(data.receipts) == "table" then data.receipts else {}
end

local function updateDisplay(profile)
	if not profile.player then return end
	local amount = profile.saved
	for _, award in profile.pending do amount += award.cents end
	profile.player:SetAttribute("WalbucksCents", amount)
	profile.player:SetAttribute("WalletReady", profile.loaded)
	profile.player:SetAttribute("WalletSaving", next(profile.pending) ~= nil)
end

function Wallet.new()
	local self = setmetatable({
		store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore("CartCatcherWallet_v1"),
		profiles = {},
	}, Wallet)
	task.spawn(function()
		while true do
			task.wait(25)
			for id, profile in self.profiles do
				if not profile.loaded or next(profile.pending) then task.spawn(self.flush, self, id) end
			end
		end
	end)
	return self
end

function Wallet:add(player)
	local id = player.UserId
	local profile = self.profiles[id]
	if not profile then
		profile = { saved = 0, loaded = self.store == nil, pending = {}, seen = {}, busy = false }
		self.profiles[id] = profile
	end
	profile.player = player
	updateDisplay(profile)
	task.spawn(self.flush, self, id)
end

function Wallet:earn(player, receipt, cents)
	local profile = self.profiles[player.UserId]
	if not profile or profile.seen[receipt] or cents <= 0 then return end
	profile.seen[receipt] = true
	if not self.store then
		profile.saved += cents
	else
		profile.pending[receipt] = { cents = cents, issued = os.time() }
		task.defer(self.flush, self, player.UserId)
	end
	updateDisplay(profile)
end

function Wallet:flush(id)
	local profile = self.profiles[id]
	if not profile or profile.busy or not self.store then return end
	profile.busy = true
	local succeeded = false
	for attempt = 1, 3 do
		local batch = table.clone(profile.pending)
		if not next(batch) and profile.loaded then break end
		local ok, result
		if next(batch) then
			local cutoff = os.time() - RECEIPT_LIFETIME
			ok, result = pcall(self.store.UpdateAsync, self.store, "u:" .. id, function(data)
				local cents, previous = unpackData(data)
				local receipts = {}
				for receipt, time in previous do
					if type(time) == "number" and time >= cutoff then receipts[receipt] = time end
				end
				for receipt, award in batch do
					if not previous[receipt] then cents += award.cents end
					receipts[receipt] = award.issued
				end
				return { cents = cents, receipts = receipts }
			end)
		else
			ok, result = pcall(self.store.GetAsync, self.store, "u:" .. id)
		end
		if ok then
			succeeded = true
			profile.saved = unpackData(result)
			profile.loaded = true
			for receipt in batch do profile.pending[receipt] = nil end
			updateDisplay(profile)
			break
		end
		if attempt == 3 then
			warn("Cart Catcher wallet could not save or load", id, result)
		else
			task.wait(2 ^ (attempt - 1))
		end
	end
	profile.busy = false
	if succeeded and next(profile.pending) then
		task.defer(self.flush, self, id)
	elseif not profile.player and not next(profile.pending) then
		self.profiles[id] = nil
	end
end

function Wallet:waitForSave(id, seconds)
	local profile = self.profiles[id]
	if not profile or not next(profile.pending) then return end
	task.spawn(self.flush, self, id)
	local deadline = os.clock() + seconds
	while next(profile.pending) and os.clock() < deadline do task.wait(.15) end
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
		if next(profile.pending) then task.spawn(self.flush, self, id) end
	end
	local deadline = os.clock() + 24
	repeat
		local waiting = false
		for _, profile in self.profiles do
			if next(profile.pending) then
				waiting = true
				break
			end
		end
		if not waiting then return end
		task.wait(.2)
	until os.clock() >= deadline
end

return Wallet
