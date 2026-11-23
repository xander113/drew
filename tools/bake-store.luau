local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local build = require("./StoreBuilder")
local makeR6 = require("./R6Builder")
local layout = require("../src/shared/Layout")

if not fs.isDir("world") then
	fs.writeDir("world")
end
fs.writeFile("world/WWMS.rbxm", roblox.serializeModel({ build(roblox, layout, makeR6) }))
fs.writeFile("world/R6.rbxm", roblox.serializeModel({ makeR6(roblox, "WWMS Worker") }))
