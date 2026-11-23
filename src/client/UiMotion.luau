local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Motion = {}

function Motion.tween(object, seconds, values, style)
	if GuiService.ReducedMotionEnabled then
		for property, value in values do object[property] = value end
		return nil
	end
	local animation = TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), values)
	animation:Play()
	return animation
end

function Motion.arrive(frame, x, y, tilt, seconds)
	if GuiService.ReducedMotionEnabled then return nil end
	local home, rotation = frame.Position, frame.Rotation
	frame.Position, frame.Rotation = home + UDim2.fromOffset(x, y), rotation + tilt
	return Motion.tween(frame, seconds or .28, { Position = home, Rotation = rotation }, Enum.EasingStyle.Back)
end

function Motion.pulse(scale, from)
	if GuiService.ReducedMotionEnabled then
		scale.Scale = 1
		return nil
	end
	scale.Scale = from
	return Motion.tween(scale, .24, { Scale = 1 }, Enum.EasingStyle.Back)
end

return table.freeze(Motion)
