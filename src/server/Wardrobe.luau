local ServerStorage = game:GetService("ServerStorage")
local Headwear = require(game:GetService("ReplicatedStorage"):WaitForChild("CartCatcher").Headwear)

local catalog = require(script.Parent.OutfitCatalog)
local closet = ServerStorage:WaitForChild("OfficialWardrobe")

local Wardrobe = {}

local headwear = {}
for _, id in catalog.Hats do table.insert(headwear, { id = id, role = "Hat" }) end
for _, id in catalog.Hair do table.insert(headwear, { id = id, role = "Hair" }) end

local function deal(random, pool, count)
	local items = table.clone(pool)
	assert(#items >= count, "WWMS needs a distinct look for each shopper")
	for index = 1, count do
		local other = random:NextInteger(index, #items)
		items[index], items[other] = items[other], items[index]
	end
	return items
end

function Wardrobe.looks(random, count)
	return { faces = deal(random, catalog.Faces, count), headwear = deal(random, headwear, count) }
end

function Wardrobe.shopper(character, random, look, index)
	for _, pool in { catalog.Shirts, catalog.Pants } do
		local id = pool[random:NextInteger(1, #pool)]
		closet[tostring(id)]:Clone().Parent = character
	end
	local head = character.Head
	local old = head:FindFirstChild("face")
	if old then old:Destroy() end
	local face = closet[tostring(look.faces[index])]:Clone()
	face.Name, face.Face, face.Parent = "face", Enum.NormalId.Front, head
	local accessory = look.headwear[index]
	Headwear.fit(character, closet[tostring(accessory.id)]:Clone(), accessory.role, { Instance = Instance })
end

return Wardrobe
