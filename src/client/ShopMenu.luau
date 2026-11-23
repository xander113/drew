local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local AvatarPreview = require(script.Parent.AvatarPreview)
local ScreenLayout = require(script.Parent.ScreenLayout)
local SoundEffects = require(script.Parent.SoundEffects)

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

local function button(parent, value, color, invoke, size)
	local btn = item("TextButton", parent, color, 14)
	btn.Text, btn.TextSize, btn.Font = value, size or 21, DISPLAY
	btn.TextColor3 = if color == BLUE then WHITE else INK
	btn.Active, btn.Selectable = true, true
	local focus = Instance.new("UIStroke")
	focus.Color, focus.Thickness = INK, 3
	focus.ApplyStrokeMode, focus.Transparency, focus.Parent = Enum.ApplyStrokeMode.Border, 1, btn
	btn.SelectionGained:Connect(function() focus.Transparency = 0 end)
	btn.SelectionLost:Connect(function() focus.Transparency = 1 end)
	btn.Activated:Connect(function()
		if not btn.Active then return end
		SoundEffects.play("Menu")
		invoke()
	end)
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
	ScreenLayout.applyInsets(gui)
	local self = setmetatable({
		gui = gui, player = player, actions = actions, filters = { page = 1, categoryPage = 1, category = "", query = "" },
	}, ShopMenu)
	self.launcher = button(gui, "Menu", BLUE, function() actions.toggle() end)
	self.launcher.AnchorPoint, self.launcher.Visible = Vector2.new(1, 0), false
	self.launchScale = item("UIScale", self.launcher)

	local dim = item("Frame", gui, INK)
	dim.BackgroundTransparency, dim.Size, dim.Active = .34, UDim2.fromScale(1, 1), true
	dim.Visible, self.dim = false, dim
	local scroll = item("ScrollingFrame", dim)
	scroll.Size, scroll.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	scroll.BorderSizePixel, scroll.ScrollBarThickness = 0, 5
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	self.scroll = scroll

	local panel = item("Frame", scroll, PAPER, 25)
	panel.SelectionGroup = true
	panel.SelectionBehaviorUp, panel.SelectionBehaviorDown = Enum.SelectionBehavior.Stop, Enum.SelectionBehavior.Stop
	panel.SelectionBehaviorLeft, panel.SelectionBehaviorRight = Enum.SelectionBehavior.Stop, Enum.SelectionBehavior.Stop
	self.panel, self.panelScale = panel, item("UIScale", panel)
	local outline = item("UIStroke", panel)
	outline.Color, outline.Thickness = BLUE, 5

	self.title = label(panel, "", 35)
	self.balance = label(panel, "", 16)
	self.balance.TextXAlignment = Enum.TextXAlignment.Right
	self.back = button(panel, "Back", PALE, function() actions.back() end)
	self.info = label(panel, "", 16)
	self.info.TextWrapped, self.info.TextTruncate = true, Enum.TextTruncate.None
	self.notice = label(panel, "", 15)
	self.notice.TextWrapped, self.notice.TextTruncate = true, Enum.TextTruncate.None
	self.notice.TextColor3 = rgb(159, 43, 58)
	self.first = button(panel, "Resume", BLUE, function() actions.main(self.mode) end)
	self.second = button(panel, "Shop", GOLD, function() actions.extra(self.mode) end)
	self.third = button(panel, "Leave shift", PALE, function() self:show("Leave") end)

	self.categoryButton = button(panel, "Categories", GOLD, function()
		self:setCategoryView(not self.categoryView)
	end, 18)
	self.search = item("TextBox", panel, WHITE, 12)
	self.search.Font, self.search.TextSize, self.search.TextColor3 = DISPLAY, 16, INK
	self.search.Text, self.search.PlaceholderText, self.search.ClearTextOnFocus = "", "Find an item", false
	self.search.ShowNativeInput, self.search.Selectable = true, true
	self.search.FocusLost:Connect(function(enter)
		if enter then self:find() end
	end)
	self.searchButton = button(panel, "Find", PALE, function() self:find() end, 16)
	self.list = item("ScrollingFrame", panel)
	self.list.BackgroundTransparency, self.list.BorderSizePixel = 1, 0
	self.list.ScrollBarThickness, self.list.ScrollingDirection = 5, Enum.ScrollingDirection.Y
	self.prev = button(panel, "Prev", PALE, function() self:turn(-1) end, 17)
	self.next = button(panel, "Next", PALE, function() self:turn(1) end, 17)
	self.page = label(panel, "", 14)
	self.page.TextXAlignment = Enum.TextXAlignment.Center
	self.itemTitle = label(panel, "", 17)
	self.buy = button(panel, "Buy", BLUE, function()
		if self.selected then actions.buy(self.selected.key) end
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
	local previewText = label(stage, "Your preview", 15)
	previewText.TextXAlignment = Enum.TextXAlignment.Center
	previewText.Size, previewText.Position = UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, -29)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:resize() end)
	return self
end

function ShopMenu:setInput(input, tv)
	self.gamepad, self.tv = ScreenLayout.isGamepad(input), tv
	self:resize()
end

function ShopMenu:resize()
	local size = self.gui.AbsoluteSize
	if size.X < 60 or size.Y < 100 then return end
	local narrow = size.X < 570
	local shop, short = self.mode == "Shop", size.Y < 470 and not narrow
	local width = if shop then (if narrow then 427 else 752) else 410
	local height = if shop then (if short then 435 else 512) else 405
	local left = if width < 500 then 211 else 329
	local amount = ScreenLayout.scale(size, width, height, 24, if self.tv then 1.2 else 1, .75)
	self.launchScale.Scale = ScreenLayout.scale(size, 97, 52, 20, if self.tv then 1.18 else 1)
	local menuY = if size.X < 620 then 158 else 57
	self.launcher.Position, self.launcher.Size = UDim2.new(1, -14, 0, menuY), pixel(96, 48)
	self.panel.Size, self.panelScale.Scale = pixel(width, height), amount
	local canvas = math.max(size.Y, height * amount + 26)
	self.scroll.CanvasSize = pixel(0, canvas)
	self.scroll.ScrollingEnabled = canvas > size.Y + 1
	self.panelHome = pixel(math.floor((size.X - width * amount) / 2), math.max(12, math.floor((size.Y - height * amount) / 2)))
	if self.move then self.move:Cancel(); self.move = nil end
	self.panel.Position = self.panelHome
	place(self.back, 20, 17, 87, 42)
	place(self.balance, width - 220, 17, 196, 37)
	place(self.title, 22, 59, width - 44, 43)
	place(self.info, 22, 114, width - 44, 46)
	place(self.notice, 23, height - 35, width - 46, 26)
	place(self.first, 22, 169, width - 44, 49)
	place(self.second, 22, 229, width - 44, 49)
	place(self.third, 22, 289, width - 44, 49)
	local listY
	if short then
		place(self.categoryButton, 22, 110, if self.categoryView then left else 122, 42)
		place(self.search, 150, 110, left - 190, 42)
		place(self.searchButton, left - 30, 110, 52, 42)
		listY = 160
	else
		place(self.categoryButton, 22, 110, left, 41)
		place(self.search, 22, 158, left - 62, 42)
		place(self.searchButton, left - 30, 158, 52, 42)
		listY = if self.categoryView then 158 else 207
	end
	place(self.list, 22, listY, left, height - 150 - listY)
	local footer = height - 143
	local mid = math.floor(left * .5)
	place(self.prev, 22, footer, 62, 38)
	place(self.page, mid - 20, footer, 87, 38)
	place(self.next, 22 + left - 62, footer, 62, 38)
	place(self.itemTitle, 22, height - 100, left, 23)
	place(self.buy, 22, height - 72, left, 39)
	place(self.stage, left + 40, 110, width - left - 63, height - 150)
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

local function enable(btn, active)
	btn.Active, btn.Selectable, btn.AutoButtonColor = active, active, active
end

function ShopMenu:select(row)
	self.selected = row
	self.itemTitle.Text = if row then row.name else ""
	local owned = if row then row.count or 0 else 0
	local preview = row and (row.kind == "Preview" or row.available == false)
	self.buy.Text = if not row then "Pick an item" elseif preview then "Preview only"
		elseif row.kind == "Pass" and owned > 0 then "Owned" else "Buy · " .. row.price .. " Robux"
	enable(self.buy, row ~= nil and not preview and (row.kind ~= "Pass" or owned == 0))
	self.buy.BackgroundColor3 = if self.buy.Active then BLUE else PALE
	self.buy.TextColor3 = if self.buy.Active then WHITE else INK
	self.notice.Text = if owned > 0 then "Owned: " .. owned else ""
	self:preview()
end

function ShopMenu:find()
	local text = self.search.Text
	local limit = utf8.offset(text, 65)
	self.filters.query = if limit then string.sub(text, 1, limit - 1) else text
	self.filters.page = 1
	self.actions.load()
end

function ShopMenu:turn(delta)
	if not self.data then return end
	local key, limit = if self.categoryView then "categoryPage" else "page", if self.categoryView then self.data.categoryPages else self.data.pages
	local target = math.clamp(self.filters[key] + delta, 1, limit)
	if target ~= self.filters[key] then
		self.filters[key] = target
		self.actions.load()
	end
end

function ShopMenu:setCategoryView(show)
	self.categoryView = show
	self.search.Visible, self.searchButton.Visible, self.buy.Visible = not show, not show, not show
	self.categoryButton.Text = if show then "Back to items" elseif self.filters.category ~= "" then self.filters.category else "Categories"
	self.categoryButton.TextTruncate = Enum.TextTruncate.AtEnd
	if show then self.itemTitle.Text = "Pick a category" end
	self:resize()
	self:populate()
end

function ShopMenu:populate()
	local data = self.data
	self.list:ClearAllChildren()
	self.list.CanvasPosition = Vector2.zero
	local labels, selected = {}, nil
	if self.categoryView then
		table.insert(labels, { name = "All items", category = "" })
		for _, name in (data and data.categories or {}) do table.insert(labels, { name = name, category = name }) end
	else
		labels = data and data.items or {}
	end
	self.list.CanvasSize = pixel(0, #labels * 53)
	local previous
	for index, row in labels do
		local btn = button(self.list, row.name, PALE, function()
			if self.categoryView then
				self.filters.category, self.filters.page = row.category, 1
				self:setCategoryView(false)
				self.actions.load()
			else
				self:select(row)
			end
		end, 17)
		btn.Position, btn.Size = pixel(0, (index - 1) * 53), UDim2.new(1, -8, 0, 47)
		btn.TextTruncate = Enum.TextTruncate.AtEnd
		btn.SelectionGained:Connect(function() ScreenLayout.showSelection(self.list, btn, self.panelScale.Scale) end)
		btn.NextSelectionUp = previous or self.categoryButton
		if previous then previous.NextSelectionDown = btn else
			self.categoryButton.NextSelectionDown = btn
			self.search.NextSelectionDown, self.searchButton.NextSelectionDown = btn, btn
		end
		btn.NextSelectionDown = self.next
		previous = btn
		if self.selected and self.selected.key == row.key then selected = row end
	end
	local page, total = 1, 1
	if data then
		page = if self.categoryView then data.categoryPage else data.page
		total = if self.categoryView then data.categoryPages else data.pages
	end
	self.page.Text = string.format("%d / %d", page, total)
	enable(self.prev, page > 1)
	enable(self.next, page < total)
	if previous then previous.NextSelectionDown = if self.next.Active then self.next elseif self.prev.Active then self.prev elseif not self.categoryView and self.buy.Active then self.buy else self.categoryButton end
	if not self.categoryView then
		self:select(selected or labels[1])
		if data and #labels == 0 then self.itemTitle.Text = "No items found" end
		if not data then self.itemTitle.Text = "Looking for items…" end
		if previous and not self.next.Active and not self.prev.Active and self.buy.Active then previous.NextSelectionDown = self.buy end
		self.buy.NextSelectionUp = if self.next.Active then self.next elseif self.prev.Active then self.prev else previous
	end
	if self.gamepad and (not GuiService.SelectedObject or not GuiService.SelectedObject:IsDescendantOf(self.panel)) then
		GuiService.SelectedObject = self.categoryButton
	end
end

function ShopMenu:catalog(data)
	self.data = data
	self.filters.page, self.filters.categoryPage, self.filters.category = data.page, data.categoryPage, data.category
	self:setCategoryView(self.categoryView == true)
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
	for _, widget in { self.stage, self.list, self.buy, self.itemTitle, self.prev, self.next, self.page, self.categoryButton, self.search, self.searchButton } do
		widget.Visible = shop
	end
	self.info.Visible = not shop
	self.notice.Text = ""
	if shop then
		self.title.Text = "WWMS Shop"
		self.search.Text = self.filters.query
		self:setCategoryView(false)
	elseif leave then
		self.title.Text, self.first.Text, self.second.Text = "Leave shift?", "Keep playing", "Leave shift"
		self.info.Text = "Leaving now costs up to " .. self.actions.fee() .. " Walbucks."
	else
		self.title.Text, self.first.Text, self.second.Text = "Shift menu", "Resume", "Shop"
		self.info.Text = "The shift keeps going."
	end
	self.scroll.CanvasPosition = Vector2.zero
	self:resize()
	if self.panelHome then
		self.panel.Position = self.panelHome + pixel(0, 15)
		self.move = tween(self.panel, .25, { Position = self.panelHome })
	end
end

function ShopMenu:step(dt)
	if self.mode ~= "Shop" or not self.avatar or GuiService.ReducedMotionEnabled then return end
	self.spin = (self.spin or 0) + dt
	self.avatar:PivotTo(CFrame.Angles(0, -.16 + math.sin(self.spin * .8) * .36, 0))
end

return ShopMenu
