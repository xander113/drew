local Interface = {}
Interface.__index = Interface

local INK = Color3.fromRGB(9, 23, 50)
local NAVY = Color3.fromRGB(14, 36, 72)
local BLUE = Color3.fromRGB(16, 97, 224)
local SKY = Color3.fromRGB(157, 200, 255)
local WHITE = Color3.fromRGB(247, 250, 255)
local GOLD = Color3.fromRGB(255, 212, 67)
local RED = Color3.fromRGB(255, 159, 144)
local MINT = Color3.fromRGB(150, 239, 193)
local FONT = Enum.Font.Gotham
local BOLD = Enum.Font.GothamBold
local BLACK = Enum.Font.GothamBlack
local MONO = Enum.Font.RobotoMono
local pixel = UDim2.fromOffset
local scale = UDim2.fromScale

local function new(class, name, parent)
	local item = Instance.new(class)
	item.Name = name
	item.Parent = parent
	return item
end

local function styleBox(item, tint, radius, opacity)
	item.BorderSizePixel = 0
	item.BackgroundColor3 = tint
	item.BackgroundTransparency = if opacity then 1 - opacity else 0
	if radius then new("UICorner", "Corner", item).CornerRadius = UDim.new(0, radius) end
	return item
end

local function frame(parent, name, size, position, tint, radius, opacity)
	local object = new("Frame", name, parent)
	object.Size, object.Position = size, position
	return styleBox(object, tint or INK, radius, if tint then opacity else 0)
end

local function label(parent, name, value, size, position, points, tint, font, align)
	local object = new("TextLabel", name, parent)
	object.Size, object.Position = size, position
	object.BackgroundTransparency = 1
	object.Text, object.TextSize, object.TextColor3 = value, points, tint
	object.TextXAlignment, object.Font = align or Enum.TextXAlignment.Left, font or FONT
	return object
end

local function stroke(parent, tint, transparency)
	local object = new("UIStroke", "Outline", parent)
	object.Color, object.Transparency = tint, transparency
	object.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return object
end

local function gui(parent, name, order, fullBleed)
	local object = Instance.new("ScreenGui")
	object.Name, object.DisplayOrder, object.ResetOnSpawn = name, order, false
	object.ScreenInsets = if fullBleed then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets
	object.Parent = parent
	return object
end

local function gradient(parent, rotation, stops)
	local object = new("UIGradient", "Gradient", parent)
	object.Rotation = rotation
	object.Transparency = NumberSequence.new(stops)
	return object
end

function Interface.new(parent, levels)
	local self = setmetatable({}, Interface)
	local backdrop = gui(parent, "CinematicBackdrop", 20, true)
	self.backdrop = backdrop
	local scrim = frame(backdrop, "SideScrim", scale(1, 1), scale(0, 0), INK)
	gradient(scrim, 0, {
		NumberSequenceKeypoint.new(0, .01), NumberSequenceKeypoint.new(.36, .10),
		NumberSequenceKeypoint.new(.65, .75), NumberSequenceKeypoint.new(1, .97),
	})
	self.scrim = scrim
	local baseTone = frame(backdrop, "BottomScrim", scale(1, 1), scale(0, 0), INK)
	gradient(baseTone, 90, { NumberSequenceKeypoint.new(0, .94), NumberSequenceKeypoint.new(.65, .91), NumberSequenceKeypoint.new(1, .08) })
	local fade = frame(backdrop, "CutFade", scale(1, 1), scale(0, 0), INK, nil, 0)
	fade.ZIndex = 2
	self.fade = fade

	local screen = gui(parent, "ShiftInterface", 21, false)
	self.screen = screen
	local menu = frame(screen, "MainMenu", scale(1, 1), scale(0, 0))
	self.menu = menu

	local brand = frame(menu, "Brand", pixel(410, 42), pixel(44, 20))
	self.brand = brand
	self.brandScale = new("UIScale", "Scale", brand)
	local logo = frame(brand, "Logo", pixel(72, 35), pixel(0, 4), BLUE, 9)
	label(logo, "WWMS", "WWMS", scale(1, 1), scale(0, 0), 17, GOLD, BLACK, Enum.TextXAlignment.Center)
	label(brand, "Store", "WILLY WALTER’S MEGA SHOP", pixel(292, 36), pixel(84, 4), 14, WHITE, BOLD)

	local panel = frame(menu, "ClockInPanel", pixel(500, 396), UDim2.new(0, 64, .53, 0))
	panel.AnchorPoint = Vector2.new(0, .5)
	self.panel = panel
	self.panelScale = new("UIScale", "Scale", panel)

	local status = frame(panel, "ShiftStatus", pixel(222, 29), pixel(0, 0), NAVY, 15, .96)
	stroke(status, SKY, .65)
	self.statusDot = frame(status, "Dot", pixel(7, 7), pixel(12, 11), MINT, 5)
	self.status = label(status, "Status", "STORE OPEN", pixel(192, 28), pixel(26, 0), 12, WHITE, BOLD)
	label(panel, "TitleFirstLine", "CART", pixel(500, 89), pixel(-5, 32), 87, WHITE, BLACK)
	label(panel, "TitleSecondLine", "CATCHER!", pixel(500, 90), pixel(-5, 103), 87, GOLD, BLACK)

	self.blurb = label(panel, "Instructions", "", pixel(467, 61), pixel(0, 195), 19, WHITE, FONT)
	self.blurb.TextWrapped = true
	self.blurb.LineHeight = 1.14

	local button = new("TextButton", "ClockIn", panel)
	button.Size, button.Position = pixel(298, 54), pixel(0, 269)
	styleBox(button, GOLD, 12)
	button.Text, button.TextSize, button.TextColor3, button.Font = "CLOCK IN", 19, INK, BLACK
	button.Selectable = true
	self.button = button
	self.buttonStroke = stroke(button, WHITE, 1)
	button.SelectionGained:Connect(function() self.buttonStroke.Transparency = 0 end)
	button.SelectionLost:Connect(function() self.buttonStroke.Transparency = 1 end)

	self.chips = {}
	for index, level in levels do
		local chip = frame(panel, level.name, pixel(148, 37), pixel((index - 1) * 157, 344), NAVY, 9, .92)
		local border = stroke(chip, SKY, .69)
		local number = label(chip, "Level", string.format("%02d", index), pixel(27, 37), pixel(10, 0), 13, SKY, MONO)
		label(chip, "Name", string.upper(level.name), pixel(111, 37), pixel(41, 0), 13, WHITE, BOLD)
		self.chips[index] = { border = border, number = number }
	end

	local hud = frame(screen, "RoundHUD", scale(1, 1), scale(0, 0))
	hud.Visible = false
	self.hud = hud
	local meter = frame(hud, "CartMeter", pixel(462, 104), UDim2.new(.5, 0, 0, 10), INK, 15, .95)
	meter.AnchorPoint = Vector2.new(.5, 0)
	stroke(meter, SKY, .58)
	self.meterScale = new("UIScale", "Scale", meter)
	self.level = label(meter, "Difficulty", "LEVEL 01  /  EASY", pixel(305, 19), pixel(17, 11), 12, SKY, BOLD)
	self.progress = label(meter, "Progress", "0 / 4 CARTS", pixel(285, 29), pixel(17, 31), 25, WHITE, BLACK)
	self.timer = label(meter, "Time", "2:05", pixel(140, 33), pixel(303, 25), 29, WHITE, MONO, Enum.TextXAlignment.Right)
	local track = frame(meter, "Track", pixel(426, 7), pixel(18, 68), NAVY, 4)
	self.fill = frame(track, "Fill", scale(0, 1), scale(0, 0), GOLD, 4)
	self.personal = label(meter, "PersonalDeliveries", "YOU RETURNED  0", pixel(426, 18), pixel(18, 79), 11, SKY, BOLD)

	local instruction = frame(hud, "Action", pixel(435, 72), UDim2.new(.5, 0, 1, -20), INK, 14, .95)
	instruction.AnchorPoint = Vector2.new(.5, 1)
	stroke(instruction, SKY, .65)
	self.instructionScale = new("UIScale", "Scale", instruction)
	self.instruction = instruction
	self.action = label(instruction, "ActionTitle", "FIND A CART", pixel(401, 23), pixel(17, 11), 15, GOLD, BLACK)
	self.help = label(instruction, "ActionHelp", "", pixel(401, 24), pixel(17, 34), 14, WHITE, FONT)
	self.help.TextWrapped = true

	return self
end

function Interface.resize(self)
	local size = self.screen.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	local portrait = size.X / size.Y < .95
	self.panelScale.Scale = math.min(1.12, (size.X - 36) / 500, (size.Y - 66) / 396)
	local margin = math.clamp(size.X * .060, 18, 96)
	self.panel.Position = UDim2.new(0, margin, if portrait then .63 else .54, 0)
	self.brand.Position = UDim2.fromOffset(margin, math.clamp(size.Y * .030, 8, 28))
	self.brandScale.Scale = math.min(1, (size.X - margin * 2) / 400, size.Y / 420)
	self.meterScale.Scale = math.min(1, (size.X - 24) / 462, size.Y / 395)
	self.instructionScale.Scale = math.min(1, (size.X - 28) / 435, size.Y / 395)
	self.instruction.Position = UDim2.new(.5, 0, 1, if portrait then -112 else -20)
end

local function clock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Interface.showMenu(self, state, queued, remaining)
	local status, tint, blurb = "STORE OPEN", MINT, "The cart hole’s empty. Grab carts around the store, push them back, and dodge curious shoppers."
	if state.phase == "Briefing" then
		status, tint = "SHIFT STARTS IN " .. clock(remaining), GOLD
		blurb = string.format("%d %s clocked in. Grab carts and push them into the blue cart hole.", state.queued, if state.queued == 1 then "worker" else "workers")
	elseif state.phase == "Active" then
		status, tint = "SHIFT IN PROGRESS", SKY
		blurb = if queued then "You’re clocked in for the next shift." else "The crew is on the floor. Clock in to join the next shift."
	elseif state.phase == "Results" then
		if state.outcome == "Filled" then
			status, tint = "CART HOLE FILLED", MINT
		elseif state.outcome == "Time" then
			status, tint = "TIME’S UP", RED
		else
			status, tint = "SHIFT ENDED", SKY
		end
		blurb = string.format("The crew returned %d of %d carts. Next shift opens in %s.", state.banked, state.goal, clock(remaining))
	end
	self.status.Text, self.statusDot.BackgroundColor3 = status, tint
	self.blurb.Text = blurb
	self.button.Text = if queued then "CLOCK OUT" else "CLOCK IN"
	self.button.BackgroundColor3 = if queued then SKY else GOLD
	for index, item in self.chips do
		local selected = index == state.level
		item.border.Color = if selected then GOLD else SKY
		item.border.Transparency = if selected then .15 else .69
		item.number.TextColor3 = if selected then GOLD else SKY
	end
end

function Interface.showShift(self, state, levelName, remaining, personal, carrying, question, input)
	self.level.Text = string.format("LEVEL %02d  /  %s", state.level, string.upper(levelName))
	self.progress.Text = string.format("%d / %d CARTS", state.banked, state.goal)
	self.timer.Text = clock(remaining)
	self.timer.TextColor3 = if remaining <= 15 then RED else WHITE
	self.fill.Size = scale(math.clamp(state.banked / math.max(state.goal, 1), 0, 1), 1)
	self.personal.Text = "YOU RETURNED  " .. personal
	if question then
		self.action.Text, self.action.TextColor3 = "STOPPED BY A SHOPPER", RED
		self.help.Text = question
	elseif carrying then
		self.action.Text, self.action.TextColor3 = "PUSH TO THE CART HOLE", MINT
		self.help.Text = "Follow the blue bay sign at the front of the store."
	else
		self.action.Text, self.action.TextColor3 = "FIND A CART", GOLD
		if input == Enum.UserInputType.Touch then
			self.help.Text = "Tap the prompt next to a cart to grab it."
		elseif string.match(input.Name, "^Gamepad") then
			self.help.Text = "Press X near a cart to grab it."
		else
			self.help.Text = "Press E near a cart to grab it."
		end
	end
end

return Interface
