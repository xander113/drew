local Spacing = {}

-- Leave room for the widest R6 stance, including the walking animation.
Spacing.Clearance = 4.9

function Spacing.clear(start, finish, shoppers, own)
	local dx, dz = finish.X - start.X, finish.Z - start.Z
	local length = dx * dx + dz * dz
	local limit = Spacing.Clearance * Spacing.Clearance
	for _, other in shoppers do
		if other == own or not other.position then continue end
		local x, z = other.position.X - start.X, other.position.Z - start.Z
		local toward = x * dx + z * dz
		local along = if length > 0 then math.clamp(toward / length, 0, 1) else 0
		x, z = x - dx * along, z - dz * along
		if x * x + z * z < limit then return false, other end
	end
	return true
end

return table.freeze(Spacing)
