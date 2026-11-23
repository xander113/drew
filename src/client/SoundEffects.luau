local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

-- Roblox Creator Store clips with packaged client sounds as fallbacks.
local clips = {
	tap = { "rbxassetid://12221967", "rbxasset://sounds/volume_slider.ogg" },
	tick = { "rbxassetid://12221990", "rbxasset://sounds/volume_slider.ogg" },
	spring = { "rbxassetid://12222124", "rbxasset://sounds/action_jump.mp3" },
	sweep = { "rbxassetid://12222200", "rbxasset://sounds/action_jump_land.mp3" },
	splash = { "rbxasset://sounds/impact_water.mp3" },
	stand = { "rbxasset://sounds/action_get_up.mp3" },
	pulse = { "rbxassetid://12221944", "rbxasset://sounds/volume_slider.ogg" },
}

local cues = {
	Menu = { "tap", .22, 1.22, .10 },
	Select = { "tick", .23, 1.52, .13 },
	Shop = { "sweep", .21, 1.30, .22 },
	Buy = { "tick", .27, 1.24, .18 },
	Owned = { "spring", .27, 1.31, .28 },
	Grab = { "spring", .31, 1.22, .24 },
	Return = { "tick", .35, 1.08, .26 },
	Win = { "tick", .37, 1.45, .23 },
	Start = { "sweep", .24, 1.12, .24 },
	Time = { "tick", .23, .83, .24 },
	Pressure = { "pulse", .27, .84, .28 },
	SlipTension = { "pulse", .27, .64, .40 },
	Shopper = { "sweep", .28, .89, .24 },
	Line = { "tap", .16, 1.10, .15 },
	Slip = { "splash", .26, 1.42, .43 },
	Stand = { "stand", .24, 1.05, .30 },
	Help = { "tick", .26, 1.03, .22 },
	Hit = { "tick", .27, 1.53, .20 },
	Miss = { "tap", .25, .70, .22 },
}

local SoundEffects = {}
local voices, last, usable = {}, {}, {}
local group

local function init()
	group = Instance.new("SoundGroup")
	group.Name, group.Volume, group.Parent = "WWMS Effects", .8, SoundService
	for index = 1, 7 do
		local voice = Instance.new("Sound")
		voice.Name = "WWMS Voice " .. index
		voice.SoundGroup, voice.Parent = group, SoundService
		voices[index] = { sound = voice, untilTime = 0 }
	end
	local assets = {}
	local seen = {}
	for _, options in clips do
		for _, content in options do
			if not seen[content] then
				seen[content] = true
				table.insert(assets, content)
			end
		end
	end
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, assets, function(content, status)
			usable[content] = status == Enum.AssetFetchStatus.Success
		end)
	end)
end

function SoundEffects.prepare()
	if not group then init() end
end

function SoundEffects.play(name)
	local cue = cues[name]
	if not cue then return end
	SoundEffects.prepare()
	local now = os.clock()
	if now < (last[name] or 0) then return end
	for _, voice in voices do
		if now < voice.untilTime then continue end
		local options = clips[cue[1]]
		local id = if usable[options[1]] == false then options[2] else options[1]
		if not id then return end
		last[name], voice.untilTime = now + math.min(.12, cue[4]), now + cue[4]
		local sound = voice.sound
		sound:Stop()
		if sound.SoundId ~= id then sound.SoundId = id end
		sound.TimePosition, sound.Volume, sound.PlaybackSpeed = 0, cue[2], cue[3]
		sound:Play()
		return
	end
end

function SoundEffects.cheer()
	SoundEffects.play("Return")
	task.delay(.14, function() SoundEffects.play("Win") end)
	task.delay(.31, function() SoundEffects.play("Owned") end)
end

return SoundEffects
