local levels = {
	table.freeze({ name = "Easy", seconds = 125, baseCarts = 5, teamCarts = 25, shoppers = 9, additionalShoppers = 7, speed = 8, stopSeconds = 4.6, rescueTaps = 1, rescuePeriod = .92, rescueWidth = .47, extraCarts = 10, slipSeconds = 1.25, leaveCents = 300, payPercent = 100, encounters = table.freeze({ chance = .34, retry = 8, cooldown = 20, grace = 12, range = 19 }) }),
	table.freeze({ name = "Mediocre", seconds = 110, baseCarts = 6, teamCarts = 34, shoppers = 13, additionalShoppers = 9, speed = 10, stopSeconds = 5.1, rescueTaps = 2, rescuePeriod = .84, rescueWidth = .36, extraCarts = 12, slipSeconds = 1.75, leaveCents = 500, payPercent = 125, encounters = table.freeze({ chance = .60, retry = 5, cooldown = 13, grace = 8, range = 27 }) }),
	table.freeze({ name = "IRL", seconds = 95, baseCarts = 7, teamCarts = 45, shoppers = 17, additionalShoppers = 12, speed = 12, stopSeconds = 5.7, rescueTaps = 3, rescuePeriod = .76, rescueWidth = .29, extraCarts = 14, slipSeconds = 2.3, leaveCents = 800, payPercent = 150, encounters = table.freeze({ chance = .89, retry = 3, cooldown = 9, grace = 4, range = 34 }) }),
}

local Config = {
	MaxPlayers = 25,
	MinPlayers = 1,
	BriefingSeconds = 3,
	WalkSpeed = 17,
	PushSpeed = 14,
	PickupDistance = 10,
	RescueDistance = 12,
	DefaultMusicVolume = 42,
	Levels = table.freeze(levels),
}

function Config.shift(levelIndex: number, playerCount: number)
	local level = levels[levelIndex]
	local crew = math.clamp(playerCount, Config.MinPlayers, Config.MaxPlayers)
	local scale = (crew - Config.MinPlayers) / (Config.MaxPlayers - Config.MinPlayers)
	local goal = level.baseCarts + math.floor((level.teamCarts - level.baseCarts) * scale + 0.5)
	return {
		seconds = level.seconds,
		goal = goal,
		carts = 2 * (goal + math.max(10, math.ceil(goal * .36))) + level.extraCarts + math.floor(scale * 4 + .5),
		shoppers = level.shoppers + math.floor(level.additionalShoppers * scale + 0.5),
		speed = level.speed,
	}
end

return table.freeze(Config)
