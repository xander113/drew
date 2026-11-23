local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local catalog = require("../src/server/OutfitCatalog")

local groups = {
	{ 11, catalog.Shirts }, { 12, catalog.Pants }, { 41, catalog.Hair }, { 8, catalog.Hats },
	{ 11, { catalog.Walter.shirt } }, { 12, { catalog.Walter.pants } },
	{ 41, { catalog.Walter.hair } }, { 8, { catalog.Walter.hat } },
}
local args = { "tools/fetch-wardrobe.py" }
local types = {}
for _, group in groups do
	for _, id in group[2] do
		local name = tostring(id)
		if not types[name] then table.insert(args, name .. ":" .. group[1]) end
		types[name] = group[1]
	end
end
local result = process.exec("python3", args)
assert(result.ok, result.stderr)
local encoded = serde.decode("json", result.stdout)
local wardrobe = roblox.Instance.new("Folder")
wardrobe.Name = "OfficialWardrobe"
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local values = {}
for index = 1, #alphabet do values[string.byte(alphabet, index)] = index - 1 end

local function decode64(value)
	local bytes = {}
	for index = 1, #value, 4 do
		local a, b, c, d = string.byte(value, index, index + 3)
		local bits = values[a] * 2 ^ 18 + values[b] * 2 ^ 12 + (values[c] or 0) * 64 + (values[d] or 0)
		table.insert(bytes, string.char(math.floor(bits / 65536)))
		if c ~= 61 then table.insert(bytes, string.char(math.floor(bits / 256) % 256)) end
		if d ~= 61 then table.insert(bytes, string.char(bits % 256)) end
	end
	return table.concat(bytes)
end

local names = {}
for name in encoded do table.insert(names, name) end
table.sort(names)
for _, name in names do
	local expected = ({ [11] = "Shirt", [12] = "Pants", [41] = "Accessory", [8] = "Accessory" })[types[name]]
	local selected
	local ok, children = pcall(roblox.deserializeModel, decode64(encoded[name]))
	assert(ok, "Could not read Roblox asset " .. name .. ": " .. tostring(children))
	for _, value in children do
		if value:IsA(expected) then selected = value; break end
	end
	assert(selected, "Wrong Roblox model for asset " .. name)
	for _, part in selected:GetDescendants() do
		if not part:IsA("BasePart") and not part:IsA("Attachment") and not part:IsA("DataModelMesh")
			and not part:IsA("SurfaceAppearance") and not part:IsA("Decal") then
			part:Destroy()
		end
	end
	selected.Name, selected.Parent = name, wardrobe
end
fs.writeFile("world/OfficialWardrobe.rbxm", roblox.serializeModel({ wardrobe }))
