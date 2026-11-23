local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local build = require("./StoreBuilder")
local layout = require("../src/shared/Layout")

if not fs.isDir("world") then
	fs.writeDir("world")
end
fs.writeFile("world/WWMS.rbxm", roblox.serializeModel({ build(roblox, layout) }))
