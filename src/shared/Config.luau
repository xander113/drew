local levels = {
	table.freeze({ name = "Easy", seconds = 125, baseCarts = 5, teamCarts = 25, shoppers = 7, additionalShoppers = 6, speed = 8, stopSeconds = 4.6, rescueTaps = 1, rescuePeriod = .92, rescueWidth = .47, payPercent = 100 }),
	table.freeze({ name = "Mediocre", seconds = 110, baseCarts = 6, teamCarts = 34, shoppers = 10, additionalShoppers = 8, speed = 10, stopSeconds = 5.1, rescueTaps = 2, rescuePeriod = .84, rescueWidth = .36, payPercent = 125 }),
	table.freeze({ name = "IRL", seconds = 95, baseCarts = 7, teamCarts = 45, shoppers = 14, additionalShoppers = 10, speed = 12, stopSeconds = 5.7, rescueTaps = 3, rescuePeriod = .76, rescueWidth = .29, payPercent = 150 }),
}

local Config = {
	MaxPlayers = 25,
	MinPlayers = 1,
	BriefingSeconds = 3,
	WalkSpeed = 17,
	PushSpeed = 14,
	QuestionCooldown = 9,
	PickupDistance = 10,
	RescueDistance = 12,
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
		carts = math.min(63, goal + math.max(10, math.ceil(goal * .36))),
		shoppers = level.shoppers + math.floor(level.additionalShoppers * scale + 0.5),
		speed = level.speed,
	}
end

return table.freeze(Config)
