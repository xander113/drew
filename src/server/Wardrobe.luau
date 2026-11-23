local ServerStorage = game:GetService("ServerStorage")
local Headwear = require(game:GetService("ReplicatedStorage"):WaitForChild("CartCatcher").Headwear)

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
	local hat = random:NextInteger(1, 3) == 1
	local accessory = closet[tostring(choose(random, if hat then catalog.Hats else catalog.Hair))]:Clone()
	Headwear.fit(character, accessory, if hat then "Hat" else "Hair", { Instance = Instance })
end

return Wardrobe
