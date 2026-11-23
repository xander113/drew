local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local AvatarPreview = require(script.Parent.AvatarPreview)

local ShopMenu = {}
ShopMenu.__index = ShopMenu

local rgb, pixel = Color3.fromRGB, UDim2.fromOffset
local INK, BLUE, GOLD, PAPER, PALE = rgb(16, 40, 81), rgb(0, 78, 213), rgb(255, 212, 60), rgb(255, 251, 231), rgb(209, 230, 254)
local WHITE = rgb(255, 255, 255)
local DISPLAY = Enum.Font.FredokaOne

local function item(class, parent, color, radius)
	local object = Instance.new(class)
	object.Parent = parent
	if color then object.BackgroundColor3, object.BorderSizePixel = color, 0 end
	if radius then
		local round = Instance.new("UICorner")
		round.CornerRadius, round.Parent = UDim.new(0, radius), object
	end
	return object
end

local function place(object, x, y, w, h)
	object.Position, object.Size = pixel(x, y), pixel(w, h)
end

local function label(parent, value, size)
	local text = item("TextLabel", parent)
	text.BackgroundTransparency = 1
	text.Text, text.TextSize, text.TextColor3, text.Font = value, size, INK, DISPLAY
	text.TextXAlignment, text.TextTruncate = Enum.TextXAlignment.Left, Enum.TextTruncate.AtEnd
	return text
end

local function button(parent, value, color, invoke)
	local btn = item("TextButton", parent, color, 14)
	btn.Text, btn.TextSize, btn.Font = value, 21, DISPLAY
	btn.TextColor3 = if color == BLUE then WHITE else INK
	btn.Activated:Connect(invoke)
	return btn
end

local function tween(object, seconds, properties)
	if GuiService.ReducedMotionEnabled then
		for property, value in properties do object[property] = value end
		return nil
	end
	local move = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), properties)
	move:Play()
	return move
end

function ShopMenu.new(parent, player, actions)
	local gui = item("ScreenGui", parent)
	gui.Name, gui.DisplayOrder, gui.ResetOnSpawn = "WWMS Menu", 25, false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local self = setmetatable({ gui = gui, player = player, actions = actions, rows = {} }, ShopMenu)
	local launcher = button(gui, "Menu", BLUE, function() actions.toggle() end)
	launcher.AnchorPoint = Vector2.new(1, 0)
	launcher.Position, launcher.Size = UDim2.new(1, -14, 0, 10), pixel(88, 44)
	launcher.Visible, self.launcher = false, launcher

	local dim = item("Frame", gui, INK)
	dim.BackgroundTransparency, dim.Size, dim.Active = .34, UDim2.fromScale(1, 1), true
	dim.Visible, self.dim = false, dim
	local panel = item("Frame", dim, PAPER, 25)
	panel.Position, panel.AnchorPoint = UDim2.fromScale(.5, .5), Vector2.new(.5, .5)
	self.panel, self.panelScale = panel, item("UIScale", panel)
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness, outline.Parent = BLUE, 5, panel

	self.title = label(panel, "", 37)
	self.balance = label(panel, "", 16)
	self.balance.TextXAlignment = Enum.TextXAlignment.Right
	self.back = button(panel, "Back", PALE, function() actions.back() end)
	self.info = label(panel, "", 16)
	self.info.TextWrapped = true
	self.info.TextTruncate = Enum.TextTruncate.None
	self.notice = label(panel, "", 15)
	self.notice.TextWrapped = true
	self.notice.TextTruncate = Enum.TextTruncate.None
	self.notice.TextColor3 = rgb(159, 43, 58)

	self.first = button(panel, "Resume", BLUE, function() actions.main(self.mode) end)
	self.second = button(panel, "Shop", GOLD, function() actions.extra(self.mode) end)
	self.third = button(panel, "Leave shift", PALE, function() self:show("Leave") end)

	self.list = item("ScrollingFrame", panel)
	self.list.BackgroundTransparency, self.list.BorderSizePixel = 1, 0
	self.list.ScrollBarThickness = 4
	self.list.ScrollingDirection = Enum.ScrollingDirection.Y
	self.itemTitle = label(panel, "", 18)
	self.buy = button(panel, "Buy", BLUE, function()
		if self.buy.Active and self.selected then
			actions.buy(self.selected.key)
		end
	end)

	local stage = item("ViewportFrame", panel, PALE, 21)
	stage.LightColor, stage.Ambient = WHITE, rgb(208, 231, 253)
	stage.LightDirection = Vector3.new(-1, -.4, -.75)
	self.stage, self.world = stage, item("WorldModel", stage)
	local camera = item("Camera", stage)
	camera.FieldOfView = 32
	camera.CFrame = CFrame.lookAt(Vector3.new(-2.8, 1.2, -13.7), Vector3.new(0, -.05, 0))
	stage.CurrentCamera = camera
	local stand = item("Part", self.world)
	stand.Shape = Enum.PartType.Cylinder
	stand.Anchored, stand.CanCollide = true, false
	stand.Size, stand.Color = Vector3.new(.25, 4.5, 4.5), BLUE
	stand.CFrame = CFrame.new(0, -3.12, 0) * CFrame.Angles(0, 0, math.pi / 2)
	self.previewText = label(stage, "Your preview", 15)
	self.previewText.TextXAlignment = Enum.TextXAlignment.Center
	self.previewText.Size, self.previewText.Position = UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, -29)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end)
	return self
end

function ShopMenu:resize()
	local size = self.gui.AbsoluteSize
	if size.X < 60 or size.Y < 100 then return end
	local shop = self.mode == "Shop"
	local width = if shop then (if size.X < size.Y then 423 else 720) else 410
	local height = if shop then 492 else 405
	local left = if width < 500 then 199 else 318
	self.panel.Size = pixel(width, height)
	self.panelScale.Scale = math.min(1, (size.X - 24) / width, (size.Y - 24) / height)
	place(self.back, 20, 18, 83, 34)
	place(self.balance, width - 217, 18, 194, 33)
	place(self.title, 22, 58, width - 44, 48)
	place(self.info, 22, 114, width - 44, 46)
	place(self.notice, 23, height - 46, width - 46, 32)
	place(self.first, 22, 169, width - 44, 49)
	place(self.second, 22, 229, width - 44, 49)
	place(self.third, 22, 289, width - 44, 49)
	place(self.list, 22, 137, left, 218)
	place(self.itemTitle, 22, 359, left, 30)
	place(self.buy, 22, 394, left, 43)
	place(self.stage, left + 40, 110, width - left - 63, 322)
	for _, row in self.list:GetChildren() do
		row.Size = UDim2.new(1, -7, 0, 52)
	end
end

function ShopMenu:setBalance(value)
	self.balance.Text = value or ""
end

function ShopMenu:preview()
	if self.avatar then self.avatar:Destroy() end
	self.avatar = AvatarPreview.clone(self.player.Character, self.world)
	local selected = self.selected
	if self.avatar and selected and selected.color then
		local tint = rgb(table.unpack(selected.color))
		local torso = self.avatar:FindFirstChild("Torso")
		if torso then torso.Color = tint end
		if selected.kind == "Preview" then
			local shirt = self.avatar:FindFirstChildOfClass("Shirt")
			if shirt then shirt:Destroy() end
		end
		self.stage.BackgroundColor3 = PALE:Lerp(tint, .30)
	else
		self.stage.BackgroundColor3 = PALE
	end
	if self.avatar then self.avatar:PivotTo(CFrame.Angles(0, -.16, 0)) end
end

function ShopMenu:select(row)
	self.selected = row
	self.itemTitle.Text = row.name
	local owned = row.count or 0
	local preview = row.kind == "Preview" or row.available == false
	self.buy.Text = if preview then "Preview only"
		elseif row.kind == "Pass" and owned > 0 then "Owned"
		else "Buy · " .. row.price .. " Robux"
	self.buy.Active = not preview and (row.kind ~= "Pass" or owned == 0)
	self.buy.AutoButtonColor = self.buy.Active
	self.buy.BackgroundColor3 = if self.buy.Active then BLUE else PALE
	self.buy.TextColor3 = if self.buy.Active then WHITE else INK
	self.notice.Text = if owned > 0 then "Owned: " .. owned else ""
	self:preview()
end

function ShopMenu:catalog(rows)
	self.rows = rows
	self.list:ClearAllChildren()
	self.list.CanvasSize = pixel(0, #rows * 58)
	local selected
	for index, row in rows do
		local btn = button(self.list, row.name, PALE, function() self:select(row) end)
		btn.Position, btn.Size = pixel(0, (index - 1) * 58), UDim2.new(1, -7, 0, 52)
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		if self.selected and self.selected.key == row.key then selected = row end
	end
	if selected or rows[1] then self:select(selected or rows[1]) end
end

function ShopMenu:show(mode)
	self.mode = mode
	self.dim.Visible = mode ~= nil
	if not mode then
		if self.avatar then self.avatar:Destroy(); self.avatar = nil end
		return
	end
	local shop, leave = mode == "Shop", mode == "Leave"
	self.first.Visible, self.second.Visible, self.third.Visible = not shop, not shop, mode == "Pause"
	self.stage.Visible, self.list.Visible, self.buy.Visible, self.itemTitle.Visible = shop, shop, shop, shop
	self.info.Visible = not shop
	self.notice.Text = ""
	if shop then
		self.title.Text = "WWMS Shop"
		self.buy.Active, self.buy.Text = false, "Pick an item"
		self.itemTitle.Text = if #self.rows == 0 then "Looking for items…" else ""
		self:catalog(self.rows)
		if #self.rows == 0 then self:preview() end
	elseif leave then
		self.title.Text, self.first.Text, self.second.Text = "Leave shift?", "Keep playing", "Leave shift"
		self.info.Text = "Leaving now costs up to " .. self.actions.fee() .. " Walbucks."
	else
		self.title.Text, self.first.Text, self.second.Text = "Shift menu", "Resume", "Shop"
		self.info.Text = "The shift keeps going."
	end
	self:resize()
	if self.move then self.move:Cancel() end
	self.panel.Position = UDim2.new(.5, 0, .5, 16)
	self.move = tween(self.panel, .25, { Position = UDim2.fromScale(.5, .5) })
end

function ShopMenu:step(dt)
	if self.mode ~= "Shop" or not self.avatar or GuiService.ReducedMotionEnabled then return end
	self.spin = (self.spin or 0) + dt
	self.avatar:PivotTo(CFrame.Angles(0, -.16 + math.sin(self.spin * .8) * .36, 0))
end

return ShopMenu
