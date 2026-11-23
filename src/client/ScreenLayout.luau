local ScreenLayout = {}

function ScreenLayout.isGamepad(input)
	return string.match(input.Name, "^Gamepad") ~= nil
end

function ScreenLayout.scale(size, width, height, margin, maximum, minimum)
	local byWidth = (size.X - margin) / width
	local byHeight = (size.Y - margin) / height
	return math.max(.08, math.min(maximum, byWidth, math.max(minimum or 0, byHeight)))
end

function ScreenLayout.showSelection(frame, selected, scale)
	if not selected or not selected:IsDescendantOf(frame) then return end
	scale = scale or 1
	local position = frame.CanvasPosition
	local relative = selected.AbsolutePosition.Y - frame.AbsolutePosition.Y
	local window = frame.AbsoluteWindowSize.Y
	if relative < 0 then
		frame.CanvasPosition = Vector2.new(position.X, math.max(0, position.Y + relative / scale - 5))
	elseif relative + selected.AbsoluteSize.Y > window then
		frame.CanvasPosition = Vector2.new(position.X, position.Y + (relative + selected.AbsoluteSize.Y - window) / scale + 5)
	end
end

return ScreenLayout
