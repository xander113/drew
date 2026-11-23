local Pay = {}

-- Keep the existing wallet's storage unit. Every award, fee, and balance is a whole Walbuck.
function Pay.roundCents(cents: number): number
	local rounded = math.floor(math.abs(cents) / 100 + .5) * 100
	return if cents < 0 then -rounded else rounded
end
function Pay.shift(personal: number, team: number, goal: number, payPercent: number)
	if personal <= 0 then return { work = 0, team = 0, bonus = 0, total = 0 } end
	local function scale(amount)
		return Pay.roundCents(amount * payPercent / 100)
	end
	local work = scale(750 + 125 * personal)
	local teamPay = scale(600 * math.clamp(team / math.max(goal, 1), 0, 1))
	local bonus = if team >= goal then scale(450) else 0
	return { work = work, team = teamPay, bonus = bonus, total = work + teamPay + bonus }
end

function Pay.format(cents: number): string
	return string.format("%.0f", Pay.roundCents(cents) / 100)
end

return table.freeze(Pay)
