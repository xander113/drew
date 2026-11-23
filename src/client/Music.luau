local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Music = {}
Music.__index = Music

-- Courtesy of APM Music. Licensed for use in Roblox experiences.
local playlists = {
	Calm = {
		{ id = 1845341094 }, -- Chill Jazz
		{ id = 9047104336 }, -- Sunday In Bed
		{ id = 1840684529 }, -- Cool Vibes
	},
	Shift = {
		{ id = 1836728923 }, -- Bright Sky
		{ id = 9042684372, start = 16 }, -- Struttin (Underscore)
		{ id = 1839008939 }, -- Jazzy Vibe
	},
}

local LEVEL = { Calm = .24, Shift = .26 }
local FADE = 1.15
local LOAD_TIMEOUT = 6
local PRELOAD_AHEAD = 9

function Music.new()
	local group = Instance.new("SoundGroup")
	group.Name, group.Volume, group.Parent = "WWMS Music", .6, SoundService
	local decks = {}
	for index = 1, 2 do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundGroup, sound.Volume = "WWMS music " .. index, group, 0
		sound.Parent = SoundService
		decks[index] = { sound = sound }
	end
	return setmetatable({ decks = decks, cursor = { Calm = 0, Shift = 0 }, retryAt = 0, failures = 0 }, Music)
end

local function fade(deck, time, volume)
	if deck.tween then deck.tween:Cancel() end
	deck.tween = TweenService:Create(deck.sound, TweenInfo.new(time, Enum.EasingStyle.Linear), { Volume = volume })
	deck.tween:Play()
end

local function stop(deck)
	if deck.tween then deck.tween:Cancel(); deck.tween = nil end
	deck.sound:Stop()
	deck.sound.Volume, deck.stopAt = 0, nil
end

function Music:prepare(now)
	local playlist = playlists[self.mode]
	local index = self.cursor[self.mode] % #playlist + 1
	self.cursor[self.mode] = index
	local track = playlist[index]
	local deck = if self.current == self.decks[1] then self.decks[2] else self.decks[1]
	stop(deck)
	deck.sound.SoundId = "rbxassetid://" .. track.id
	deck.mode, deck.start, deck.waitUntil = self.mode, track.start or 0, now + LOAD_TIMEOUT
	self.incoming = deck
	if not deck.loading then
		deck.loading = true
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, { deck.sound })
			deck.loading = false
		end)
	end
end

function Music:step(active, now)
	local mode = if active then "Shift" else "Calm"
	if mode ~= self.mode then
		self.mode, self.retryAt, self.failures = mode, now, 0
		if self.incoming then stop(self.incoming); self.incoming = nil end
		-- Fade the round music promptly even when the next menu track is slow to load.
		if self.current and self.current.mode == "Shift" then
			fade(self.current, .45, 0)
			self.current.stopAt = now + .45
		end
	end

	for _, deck in self.decks do
		if deck.stopAt and now >= deck.stopAt then stop(deck) end
	end

	local current = self.current
	local changing = not current or current.mode ~= mode or not current.sound.IsPlaying
	local left = if changing then 0 else current.sound.TimeLength - current.sound.TimePosition
	local incoming = self.incoming
	if incoming then
		local sound = incoming.sound
		local ready = sound.IsLoaded and sound.TimeLength > 0
		if ready and left <= FADE then
			sound.TimePosition = math.min(incoming.start, math.max(0, sound.TimeLength - 3))
			sound:Play()
			fade(incoming, FADE, LEVEL[mode])
			if current and current.sound.IsPlaying and not current.stopAt then
				fade(current, FADE, 0)
				current.stopAt = now + FADE
			end
			self.current, self.incoming, self.failures = incoming, nil, 0
			return
		elseif not ready and now >= incoming.waitUntil then
			stop(incoming)
			self.incoming = nil
			self.failures += 1
			self.retryAt = now + (if self.failures % #playlists[mode] == 0 then 12 else .25)
		end
	end

	if not self.incoming and now >= self.retryAt and left <= PRELOAD_AHEAD then self:prepare(now) end
end

return Music
