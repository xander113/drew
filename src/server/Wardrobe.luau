local ServerStorage = game:GetService("ServerStorage")

local catalog = require(script.Parent.OutfitCatalog)
local closet = ServerStorage:WaitForChild("OfficialWardrobe")

local Wardrobe = {}

local function choose(random, pool)
	return pool[random:NextInteger(1, #pool)]
end

function Wardrobe.shopper(character, random)
	for _, id in { choose(random, catalog.Shirts), choose(random, catalog.Pants) } do
		closet[tostring(id)]:Clone().Parent = character
	end
	local headwear = if random:NextInteger(1, 3) == 1 then catalog.Hats else catalog.Hair
	local accessory = closet[tostring(choose(random, headwear))]:Clone()
	local handle = accessory:FindFirstChild("Handle")
	if handle then
		handle.Anchored, handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, false, true
	end
	character.Humanoid:AddAccessory(accessory)
end

return Wardrobe
