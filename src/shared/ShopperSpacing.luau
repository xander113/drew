local Spacing = {}

-- Leave room for the widest R6 stance, including the walking animation.
Spacing.Clearance = 4.9
Spacing.Comfort = 5.6

function Spacing.clear(start, finish, shoppers, own, gap)
	gap = gap or Spacing.Clearance
	local dx, dz = finish.X - start.X, finish.Z - start.Z
	local length = dx * dx + dz * dz
	local limit = gap * gap
	for _, other in shoppers do
		if other == own or not other.position then continue end
		local x, z = other.position.X - start.X, other.position.Z - start.Z
		local toward = x * dx + z * dz
		-- A shopper already inside the comfort zone may step away from it.
		if gap > Spacing.Clearance and toward <= 0 then continue end
		local along = if length > 0 then math.clamp(toward / length, 0, 1) else 0
		x, z = x - dx * along, z - dz * along
		if x * x + z * z < limit then return false end
	end
	return true
end

return table.freeze(Spacing)
