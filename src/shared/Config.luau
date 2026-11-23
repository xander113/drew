local levels = {
	table.freeze({ name = "Easy", seconds = 125, baseCarts = 4, teamCarts = 22, shoppers = 4, additionalShoppers = 5, speed = 8, questionSeconds = 2 }),
	table.freeze({ name = "Mediocre", seconds = 110, baseCarts = 5, teamCarts = 30, shoppers = 6, additionalShoppers = 7, speed = 10, questionSeconds = 2.5 }),
	table.freeze({ name = "IRL", seconds = 95, baseCarts = 6, teamCarts = 40, shoppers = 8, additionalShoppers = 9, speed = 12, questionSeconds = 3 }),
}

local Config = {
	Title = "Cart Catcher!",
	MaxPlayers = 25,
	MinPlayers = 1,
	BriefingSeconds = 10,
	ResultSeconds = 8,
	WalkSpeed = 17,
	PushSpeed = 13,
	QuestionSpeed = 7,
	QuestionCooldown = 7,
	PickupDistance = 10,
	Levels = table.freeze(levels),
}

function Config.shift(levelIndex: number, playerCount: number)
	local level = levels[levelIndex]
	local crew = math.clamp(playerCount, Config.MinPlayers, Config.MaxPlayers)
	local scale = (crew - Config.MinPlayers) / (Config.MaxPlayers - Config.MinPlayers)
	local goal = level.baseCarts + math.floor((level.teamCarts - level.baseCarts) * scale + 0.5)
	return {
		name = level.name,
		seconds = level.seconds,
		goal = goal,
		carts = math.min(48, goal + math.max(6, math.ceil(goal * 0.2))),
		shoppers = level.shoppers + math.floor(level.additionalShoppers * scale + 0.5),
		speed = level.speed,
		questionSeconds = level.questionSeconds,
	}
end

return table.freeze(Config)
