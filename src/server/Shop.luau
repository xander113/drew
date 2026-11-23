local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local settings = require(script.Parent.ShopItems)
local Shop = {}
Shop.__index = Shop

local PREVIEWS = {
	{ key = "sample:1", name = "Blue Crew", kind = "Preview", color = { 22, 110, 232 } },
	{ key = "sample:2", name = "Gold Shift", kind = "Preview", color = { 255, 197, 49 } },
	{ key = "sample:3", name = "Mint Crew", kind = "Preview", color = { 68, 183, 134 } },
}

local function itemKey(kind, id)
	return kind .. ":" .. id
end

local function add(list, entries, kind, id, info)
	if type(id) ~= "number" or id <= 0 or entries[itemKey(kind, id)] then return end
	local key = itemKey(kind, id)
	local name = info.Name or info.name
	local price = info.PriceInRobux or info.priceInRobux or info.price
	if type(name) ~= "string" or type(price) ~= "number" or price < 0 or info.IsForSale == false or info.isForSale == false then return end
	local override = settings.Overrides[key]
	local item = { key = key, id = id, kind = kind, name = if override and override.name then override.name else name, price = price, color = override and override.color }
	entries[key] = item
	table.insert(list, item)
end

local function products(list, entries)
	local pages = MarketplaceService:GetDeveloperProductsAsync()
	repeat
		for _, row in pages:GetCurrentPage() do add(list, entries, "Product", row.ProductId or row.productId, row) end
		if pages.IsFinished then break end
		pages:AdvanceToNextPageAsync()
	until false
end

local function passes(list, entries)
	for _, id in settings.PassIds do
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, Enum.InfoType.GamePass)
		if ok then add(list, entries, "Pass", id, info) end
	end
	local key = HttpService:GetSecret("WWMS_SHOP_KEY")
	local page
	for _ = 1, 8 do
		local url = string.format("https://apis.roblox.com/game-passes/v1/universes/%d/game-passes/creator?pageSize=100&passView=Full", game.GameId)
		if page then url ..= "&pageToken=" .. HttpService:UrlEncode(page) end
		local response = HttpService:RequestAsync({ Url = url, Method = "GET", Headers = { ["x-api-key"] = key } })
		assert(response.Success, "Game pass list is unavailable")
		local data = HttpService:JSONDecode(response.Body)
		for _, row in data.gamePasses or data.data or {} do
			local id = row.gamePassId or row.id
			if type(id) == "number" and not entries[itemKey("Pass", id)] then
				local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, Enum.InfoType.GamePass)
				if ok then add(list, entries, "Pass", id, info) end
			end
		end
		page = data.nextPageToken
		if type(page) ~= "string" or page == "" then break end
	end
end

function Shop.new(wallet)
	local self = setmetatable({ wallet = wallet, items = {}, rows = {}, updateAt = 0 }, Shop)
	if not RunService:IsStudio() then
		MarketplaceService.ProcessReceipt = function(receipt)
			local key = itemKey("Product", receipt.ProductId)
			if wallet:purchase(receipt.PlayerId, tostring(receipt.PurchaseId), key) then return Enum.ProductPurchaseDecision.PurchaseGranted end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
			local key = itemKey("Pass", id)
			if purchased and self.items[key] then self:ownsPass(player, id) end
		end)
	end
	return self
end

function Shop:ownsPass(player, id)
	local key = itemKey("Pass", id)
	if self.wallet:quantity(player, key) > 0 then return true end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	if ok and owns then
		self.wallet:grantPass(player, key)
		return true
	end
	return false
end

function Shop:refresh()
	if game.GameId == 0 or os.clock() < self.updateAt or self.loading then return end
	self.loading = true
	local items, rows = {}, {}
	local productOK = pcall(products, rows, items)
	local passesOK = pcall(passes, rows, items)
	if productOK or passesOK or #rows > 0 then
		-- Keep last verified entries if just one service was unavailable.
		for key, item in self.items do
			if not items[key] and ((item.kind == "Pass" and not passesOK) or (item.kind == "Product" and not productOK)) then
				items[key] = item
				table.insert(rows, item)
			end
		end
		table.sort(rows, function(a, b) return a.key < b.key end)
		self.items, self.rows = items, rows
	end
	self.updateAt, self.loading = os.clock() + 90, false
end

function Shop:list(player)
	self:refresh()
	if #self.rows == 0 then return PREVIEWS end
	local rows = {}
	for _, item in self.rows do
		local row = table.clone(item)
		row.count = self.wallet:quantity(player, row.key)
		row.available = not RunService:IsStudio()
		if row.kind == "Pass" and row.count == 0 and self:ownsPass(player, row.id) then row.count = 1 end
		table.insert(rows, row)
	end
	return rows
end

function Shop:buy(player, key)
	if type(key) ~= "string" then return "Pick an item." end
	local item = self.items[key]
	if not item or RunService:IsStudio() then return "Preview only." end
	if item.kind == "Pass" then
		if self:ownsPass(player, item.id) then return "You already own this." end
		MarketplaceService:PromptGamePassPurchase(player, item.id)
	else
		MarketplaceService:PromptProductPurchase(player, item.id)
	end
	return nil
end

return Shop
