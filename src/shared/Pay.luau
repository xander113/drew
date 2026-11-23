local Pay = {}

-- Store and add hundredths of a Walbuck as integers.
function Pay.shift(personal: number, team: number, goal: number, payPercent: number)
	if personal <= 0 then return { work = 0, team = 0, bonus = 0, total = 0 } end
	local function scale(amount)
		return math.floor(amount * payPercent / 100 + .5)
	end
	local work = scale(750 + 125 * personal)
	local teamPay = scale(math.floor(600 * math.clamp(team / math.max(goal, 1), 0, 1)))
	local bonus = if team >= goal then scale(450) else 0
	return { work = work, team = teamPay, bonus = bonus, total = work + teamPay + bonus }
end

function Pay.format(cents: number): string
	return string.format("%d.%02d", math.floor(cents / 100), cents % 100)
end

return table.freeze(Pay)
