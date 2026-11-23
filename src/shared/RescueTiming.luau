local Timing = {}

function Timing.build(level, now, random)
	local startAt = now + .32
	local cues = {}
	for tap = 1, level.rescueTaps do
		cues[tap] = random:NextNumber(.35, .65)
	end
	return { start = startAt, period = level.rescuePeriod, width = level.rescueWidth, cues = cues }
end

function Timing.slot(pattern, step, now)
	return (now - pattern.start) / pattern.period - (step - 1)
end

function Timing.hit(pattern, step, receivedAt, ping)
	local elapsed = Timing.slot(pattern, step, receivedAt - math.clamp(ping, 0, .13))
	return math.abs(elapsed - pattern.cues[step]) <= pattern.width / 2
end

return table.freeze(Timing)
