local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.__index = Library

local theme = {
	BgMain = Color3.fromRGB(16, 16, 19),
	BgSidebar = Color3.fromRGB(20, 20, 24),
	BgCard = Color3.fromRGB(24, 24, 29),
	BgCardHeader = Color3.fromRGB(29, 29, 35),
	BgPill = Color3.fromRGB(34, 34, 41),
	BgHover = Color3.fromRGB(36, 36, 44),
	Border = Color3.fromRGB(42, 42, 50),
	Accent = Color3.fromRGB(249, 115, 22),
	AccentSoft = Color3.fromRGB(62, 36, 20),
	TextPrimary = Color3.fromRGB(244, 244, 246),
	TextSecondary = Color3.fromRGB(161, 161, 170),
	TextMuted = Color3.fromRGB(113, 113, 122),
	Success = Color3.fromRGB(34, 197, 94)
}

local function addCorner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end

local function addStroke(inst, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or theme.Border
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function makeDraggable(dragHandle, targetFrame, scaleProvider, onTap)
	local dragging = false
	local movedDistance = 0
	local dragStart = nil
	local startPos = nil
	local activeInput = nil

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			if activeInput then return end
			activeInput = input
			dragging = true
			movedDistance = 0
			dragStart = input.Position
			startPos = targetFrame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End and activeInput == input then
					local wasTap = (movedDistance < 8)
					dragging = false
					activeInput = nil
					if wasTap and onTap then
						onTap()
					end
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and activeInput == input
			and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			movedDistance = delta.Magnitude
			local s = 1
			if type(scaleProvider) == "function" then
				s = scaleProvider()
			elseif typeof(scaleProvider) == "Instance" and scaleProvider:IsA("UIScale") then
				s = scaleProvider.Scale
			end
			if s <= 0 then s = 1 end

			targetFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + (delta.X / s),
				startPos.Y.Scale,
				startPos.Y.Offset + (delta.Y / s)
			)
		end
	end)
end

local function getParentGui()
	local parentGui = nil
	pcall(function()
		if gethui then
			parentGui = gethui()
		end
	end)
	if not parentGui then
		parentGui = game:GetService("CoreGui")
	end
	local ok = pcall(function()
		local f = Instance.new("Folder")
		f.Parent = parentGui
		f:Destroy()
	end)
	if not ok then
		parentGui = LocalPlayer:WaitForChild("PlayerGui")
		return parentGui, true
	end
	return parentGui, false
end

function Library:CreateWindow(opts)
	opts = opts or {}
	local titleText = opts.Title or "AngpaoHub"
	local subtitleText = opts.Subtitle or "v1.2.0 • Script Hub"
	local sectionText = opts.Section or "Main"
	local floatingText = opts.FloatingText or "🧧  Angpao UI"
	local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift

	local parentGui, usePlayerGuiFallback = getParentGui()
	local existing = parentGui:FindFirstChild("CustomDashboardLibUI")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CustomDashboardLibUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 999
	screenGui.Parent = parentGui
	if usePlayerGuiFallback then
		screenGui.IgnoreGuiInset = true
	end

	local mainWindow = Instance.new("Frame")
	mainWindow.Name = "MainWindow"
	mainWindow.Size = UDim2.new(0, 760, 0, 460)
	mainWindow.Position = UDim2.new(0.5, -380, 0.5, -230)
	mainWindow.BackgroundColor3 = theme.BgMain
	mainWindow.BorderSizePixel = 0
	mainWindow.ClipsDescendants = true
	mainWindow.Parent = screenGui
	addCorner(mainWindow, 14)
	addStroke(mainWindow, theme.Border, 1.2)

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = mainWindow

	local function refreshScale()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		local scaleX = (vp.X - 20) / 760
		local scaleY = (vp.Y - 20) / 460
		uiScale.Scale = math.clamp(math.min(scaleX, scaleY, 1), 0.55, 1)
	end
	refreshScale()
	local camConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refreshScale)

	local reopenBtn = Instance.new("TextButton")
	reopenBtn.Name = "ReopenButton"
	reopenBtn.Size = UDim2.new(0, 152, 0, 38)
	reopenBtn.Position = UDim2.new(0.5, -76, 0, 64)
	reopenBtn.BackgroundColor3 = theme.BgCard
	reopenBtn.TextColor3 = theme.TextPrimary
	reopenBtn.Font = Enum.Font.GothamBold
	reopenBtn.TextSize = 12
	reopenBtn.Text = floatingText
	reopenBtn.AutoButtonColor = false
	reopenBtn.Active = true
	reopenBtn.Visible = false
	reopenBtn.ZIndex = 20
	reopenBtn.Parent = screenGui
	addCorner(reopenBtn, 10)
	addStroke(reopenBtn, theme.Accent, 1.4)

	-- Sidebar
	local sidebarWidth = 178
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
	sidebar.BackgroundColor3 = theme.BgSidebar
	sidebar.BorderSizePixel = 0
	sidebar.Parent = mainWindow

	local sidebarBorder = Instance.new("Frame")
	sidebarBorder.Size = UDim2.new(0, 1, 1, 0)
	sidebarBorder.Position = UDim2.new(1, -1, 0, 0)
	sidebarBorder.BackgroundColor3 = theme.Border
	sidebarBorder.BorderSizePixel = 0
	sidebarBorder.Parent = sidebar

	local brandFrame = Instance.new("Frame")
	brandFrame.Size = UDim2.new(1, 0, 0, 56)
	brandFrame.BackgroundTransparency = 1
	brandFrame.Parent = sidebar
	makeDraggable(brandFrame, mainWindow, uiScale)

	local brandBadge = Instance.new("Frame")
	brandBadge.Size = UDim2.new(0, 32, 0, 32)
	brandBadge.Position = UDim2.new(0, 12, 0.5, -16)
	brandBadge.BackgroundColor3 = theme.AccentSoft
	brandBadge.Parent = brandFrame
	addCorner(brandBadge, 8)
	addStroke(brandBadge, theme.Accent, 1)

	local brandIcon = Instance.new("TextLabel")
	brandIcon.Size = UDim2.new(1, 0, 1, 0)
	brandIcon.BackgroundTransparency = 1
	brandIcon.Font = Enum.Font.GothamBold
	brandIcon.TextSize = 16
	brandIcon.TextColor3 = theme.Accent
	brandIcon.Text = "🧧"
	brandIcon.Parent = brandBadge

	local brandTitle = Instance.new("TextLabel")
	brandTitle.Size = UDim2.new(1, -56, 0, 18)
	brandTitle.Position = UDim2.new(0, 50, 0, 10)
	brandTitle.BackgroundTransparency = 1
	brandTitle.Font = Enum.Font.GothamBold
	brandTitle.TextSize = 13
	brandTitle.TextXAlignment = Enum.TextXAlignment.Left
	brandTitle.TextColor3 = theme.TextPrimary
	brandTitle.Text = titleText
	brandTitle.Parent = brandFrame

	local brandSub = Instance.new("TextLabel")
	brandSub.Size = UDim2.new(1, -56, 0, 14)
	brandSub.Position = UDim2.new(0, 50, 0, 28)
	brandSub.BackgroundTransparency = 1
	brandSub.Font = Enum.Font.Gotham
	brandSub.TextSize = 10
	brandSub.TextXAlignment = Enum.TextXAlignment.Left
	brandSub.TextColor3 = theme.TextMuted
	brandSub.Text = subtitleText
	brandSub.Parent = brandFrame

	local sectionLabel = Instance.new("TextLabel")
	sectionLabel.Size = UDim2.new(1, -24, 0, 20)
	sectionLabel.Position = UDim2.new(0, 14, 0, 62)
	sectionLabel.BackgroundTransparency = 1
	sectionLabel.Font = Enum.Font.GothamMedium
	sectionLabel.TextSize = 10
	sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	sectionLabel.TextColor3 = theme.TextMuted
	sectionLabel.Text = sectionText
	sectionLabel.Parent = sidebar

	local navContainer = Instance.new("Frame")
	navContainer.Size = UDim2.new(1, -16, 1, -148)
	navContainer.Position = UDim2.new(0, 8, 0, 86)
	navContainer.BackgroundTransparency = 1
	navContainer.Parent = sidebar

	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 4)
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Parent = navContainer

	-- Footer
	local footerFrame = Instance.new("Frame")
	footerFrame.Size = UDim2.new(1, 0, 0, 54)
	footerFrame.Position = UDim2.new(0, 0, 1, -54)
	footerFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	footerFrame.BorderSizePixel = 0
	footerFrame.Parent = sidebar

	local footerTopLine = Instance.new("Frame")
	footerTopLine.Size = UDim2.new(1, 0, 0, 1)
	footerTopLine.BackgroundColor3 = theme.Border
	footerTopLine.BorderSizePixel = 0
	footerTopLine.Parent = footerFrame

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Size = UDim2.new(0, 30, 0, 30)
	avatarImg.Position = UDim2.new(0, 12, 0.5, -15)
	avatarImg.BackgroundColor3 = theme.BgPill
	avatarImg.BorderSizePixel = 0
	avatarImg.Parent = footerFrame
	addCorner(avatarImg, 15)

	task.spawn(function()
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(
				LocalPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size48x48
			)
		end)
		if ok and thumb and avatarImg.Parent then
			avatarImg.Image = thumb
		end
	end)

	local playerNameLbl = Instance.new("TextLabel")
	playerNameLbl.Size = UDim2.new(1, -52, 0, 16)
	playerNameLbl.Position = UDim2.new(0, 48, 0, 11)
	playerNameLbl.BackgroundTransparency = 1
	playerNameLbl.Font = Enum.Font.GothamBold
	playerNameLbl.TextSize = 11
	playerNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	playerNameLbl.TextXAlignment = Enum.TextXAlignment.Left
	playerNameLbl.TextColor3 = theme.TextPrimary
	playerNameLbl.Text = LocalPlayer.DisplayName or LocalPlayer.Name
	playerNameLbl.Parent = footerFrame

	local playerStatusLbl = Instance.new("TextLabel")
	playerStatusLbl.Size = UDim2.new(1, -52, 0, 14)
	playerStatusLbl.Position = UDim2.new(0, 48, 0, 27)
	playerStatusLbl.BackgroundTransparency = 1
	playerStatusLbl.Font = Enum.Font.Gotham
	playerStatusLbl.TextSize = 10
	playerStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
	playerStatusLbl.TextColor3 = theme.Accent
	playerStatusLbl.Text = "Ready"
	playerStatusLbl.Parent = footerFrame

	-- Content Area
	local contentArea = Instance.new("Frame")
	contentArea.Size = UDim2.new(1, -sidebarWidth, 1, 0)
	contentArea.Position = UDim2.new(0, sidebarWidth, 0, 0)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = mainWindow

	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 44)
	topBar.BackgroundColor3 = theme.BgSidebar
	topBar.BorderSizePixel = 0
	topBar.Parent = contentArea
	makeDraggable(topBar, mainWindow, uiScale)

	local topBarBorder = Instance.new("Frame")
	topBarBorder.Size = UDim2.new(1, 0, 0, 1)
	topBarBorder.Position = UDim2.new(0, 0, 1, -1)
	topBarBorder.BackgroundColor3 = theme.Border
	topBarBorder.BorderSizePixel = 0
	topBarBorder.Parent = topBar

	local pageTitleLbl = Instance.new("TextLabel")
	pageTitleLbl.Size = UDim2.new(0, 140, 1, 0)
	pageTitleLbl.Position = UDim2.new(0, 16, 0, 0)
	pageTitleLbl.BackgroundTransparency = 1
	pageTitleLbl.Font = Enum.Font.GothamBold
	pageTitleLbl.TextSize = 14
	pageTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
	pageTitleLbl.TextColor3 = theme.TextPrimary
	pageTitleLbl.Text = "Tab"
	pageTitleLbl.Parent = topBar

	local telemetryPill = Instance.new("Frame")
	telemetryPill.Size = UDim2.new(0, 168, 0, 24)
	telemetryPill.Position = UDim2.new(0, 152, 0.5, -12)
	telemetryPill.BackgroundColor3 = theme.BgPill
	telemetryPill.Parent = topBar
	addCorner(telemetryPill, 6)
	addStroke(telemetryPill, theme.Border, 1)

	local telemetryLbl = Instance.new("TextLabel")
	telemetryLbl.Size = UDim2.new(1, -10, 1, 0)
	telemetryLbl.Position = UDim2.new(0, 5, 0, 0)
	telemetryLbl.BackgroundTransparency = 1
	telemetryLbl.Font = Enum.Font.GothamMedium
	telemetryLbl.TextSize = 10
	telemetryLbl.TextColor3 = theme.TextSecondary
	telemetryLbl.Text = "60 fps"
	telemetryLbl.Parent = telemetryPill

	local searchBoxFrame = Instance.new("Frame")
	searchBoxFrame.Size = UDim2.new(0, 148, 0, 26)
	searchBoxFrame.Position = UDim2.new(1, -214, 0.5, -13)
	searchBoxFrame.BackgroundColor3 = theme.BgPill
	searchBoxFrame.Parent = topBar
	addCorner(searchBoxFrame, 6)
	addStroke(searchBoxFrame, theme.Border, 1)

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -14, 1, 0)
	searchBox.Position = UDim2.new(0, 8, 0, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.Font = Enum.Font.Gotham
	searchBox.TextSize = 11
	searchBox.PlaceholderText = "Search..."
	searchBox.PlaceholderColor3 = theme.TextMuted
	searchBox.TextColor3 = theme.TextPrimary
	searchBox.Text = ""
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = searchBoxFrame

	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.new(0, 26, 0, 26)
	minBtn.Position = UDim2.new(1, -58, 0.5, -13)
	minBtn.BackgroundColor3 = theme.BgPill
	minBtn.Font = Enum.Font.GothamBold
	minBtn.TextSize = 13
	minBtn.TextColor3 = theme.TextSecondary
	minBtn.Text = "—"
	minBtn.Parent = topBar
	addCorner(minBtn, 6)
	addStroke(minBtn, theme.Border, 1)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.Position = UDim2.new(1, -28, 0.5, -13)
	closeBtn.BackgroundColor3 = theme.BgPill
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 12
	closeBtn.TextColor3 = theme.Accent
	closeBtn.Text = "✕"
	closeBtn.Parent = topBar
	addCorner(closeBtn, 6)
	addStroke(closeBtn, theme.Border, 1)

	local pagesHolder = Instance.new("Frame")
	pagesHolder.Size = UDim2.new(1, 0, 1, -44)
	pagesHolder.Position = UDim2.new(0, 0, 0, 44)
	pagesHolder.BackgroundTransparency = 1
	pagesHolder.Parent = contentArea

	-- Toast container
	local toastHolder = Instance.new("Frame")
	toastHolder.Size = UDim2.new(0, 270, 0, 180)
	toastHolder.Position = UDim2.new(1, -284, 1, -194)
	toastHolder.BackgroundTransparency = 1
	toastHolder.ZIndex = 30
	toastHolder.Parent = screenGui

	local toastLayout = Instance.new("UIListLayout")
	toastLayout.Padding = UDim.new(0, 8)
	toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Parent = toastHolder

	local pages = {}
	local navButtons = {}
	local searchableItems = {}
	local tabOrderCounter = 0
	local toastOrder = 0

	local winObj = {}

	function winObj:Notify(title, content, duration)
		toastOrder += 1
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, 0, 0, 56)
		card.LayoutOrder = toastOrder
		card.BackgroundColor3 = theme.BgCard
		card.ZIndex = 31
		card.Parent = toastHolder
		addCorner(card, 8)
		addStroke(card, theme.Accent, 1)

		local tLbl = Instance.new("TextLabel")
		tLbl.Size = UDim2.new(1, -16, 0, 18)
		tLbl.Position = UDim2.new(0, 8, 0, 6)
		tLbl.BackgroundTransparency = 1
		tLbl.Font = Enum.Font.GothamBold
		tLbl.TextSize = 11
		tLbl.TextXAlignment = Enum.TextXAlignment.Left
		tLbl.TextColor3 = theme.Accent
		tLbl.Text = tostring(title)
		tLbl.ZIndex = 32
		tLbl.Parent = card

		local cLbl = Instance.new("TextLabel")
		cLbl.Size = UDim2.new(1, -16, 0, 26)
		cLbl.Position = UDim2.new(0, 8, 0, 24)
		cLbl.BackgroundTransparency = 1
		cLbl.Font = Enum.Font.Gotham
		cLbl.TextSize = 10
		cLbl.TextWrapped = true
		cLbl.TextXAlignment = Enum.TextXAlignment.Left
		cLbl.TextColor3 = theme.TextPrimary
		cLbl.Text = tostring(content)
		cLbl.ZIndex = 32
		cLbl.Parent = card

		task.delay(duration or 3.5, function()
			if card and card.Parent then
				card:Destroy()
			end
		end)
	end

	function winObj:SetStatus(text)
		playerStatusLbl.Text = tostring(text)
	end

	function winObj:SetTelemetry(text)
		telemetryLbl.Text = tostring(text)
	end

	local function selectTab(name)
		pageTitleLbl.Text = name
		for tabName, pageInfo in pairs(pages) do
			pageInfo.Scroll.Visible = (tabName == name)
			if tabName == name then
				pageInfo.Resize()
			end
		end
		for tabName, btnData in pairs(navButtons) do
			local active = (tabName == name)
			btnData.Button.BackgroundColor3 = active and theme.BgPill or Color3.fromRGB(0, 0, 0)
			btnData.Button.BackgroundTransparency = active and 0 or 1
			btnData.Label.TextColor3 = active and theme.TextPrimary or theme.TextSecondary
			btnData.Icon.TextColor3 = active and theme.Accent or theme.TextMuted
			btnData.Indicator.Visible = active
		end
	end

	function winObj:SelectTab(name)
		if pages[name] then
			selectTab(name)
		end
	end

	function winObj:CreateTab(name, iconText)
		tabOrderCounter += 1
		local order = tabOrderCounter
		iconText = iconText or "•"

		local btn = Instance.new("TextButton")
		btn.Name = name .. "Nav"
		btn.Size = UDim2.new(1, 0, 0, 32)
		btn.LayoutOrder = order
		btn.BackgroundColor3 = theme.BgPill
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = navContainer
		addCorner(btn, 7)

		local indicator = Instance.new("Frame")
		indicator.Size = UDim2.new(0, 3, 0, 16)
		indicator.Position = UDim2.new(0, 2, 0.5, -8)
		indicator.BackgroundColor3 = theme.Accent
		indicator.BorderSizePixel = 0
		indicator.Visible = false
		indicator.Parent = btn
		addCorner(indicator, 2)

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size = UDim2.new(0, 22, 1, 0)
		iconLbl.Position = UDim2.new(0, 10, 0, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Font = Enum.Font.GothamBold
		iconLbl.TextSize = 12
		iconLbl.TextColor3 = theme.TextMuted
		iconLbl.Text = iconText
		iconLbl.Parent = btn

		local textLbl = Instance.new("TextLabel")
		textLbl.Size = UDim2.new(1, -38, 1, 0)
		textLbl.Position = UDim2.new(0, 34, 0, 0)
		textLbl.BackgroundTransparency = 1
		textLbl.Font = Enum.Font.GothamMedium
		textLbl.TextSize = 12
		textLbl.TextXAlignment = Enum.TextXAlignment.Left
		textLbl.TextColor3 = theme.TextSecondary
		textLbl.Text = name
		textLbl.Parent = btn

		navButtons[name] = {
			Button = btn,
			Label = textLbl,
			Icon = iconLbl,
			Indicator = indicator
		}

		btn.MouseButton1Click:Connect(function()
			selectTab(name)
		end)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = name .. "Page"
		scroll.Size = UDim2.new(1, -20, 1, -12)
		scroll.Position = UDim2.new(0, 10, 0, 6)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.ScrollBarImageColor3 = theme.Accent
		scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Visible = false
		scroll.Parent = pagesHolder

		local leftCol = Instance.new("Frame")
		leftCol.Size = UDim2.new(0.5, -6, 0, 0)
		leftCol.BackgroundTransparency = 1
		leftCol.Parent = scroll

		local leftLayout = Instance.new("UIListLayout")
		leftLayout.Padding = UDim.new(0, 10)
		leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
		leftLayout.Parent = leftCol

		local rightCol = Instance.new("Frame")
		rightCol.Size = UDim2.new(0.5, -6, 0, 0)
		rightCol.Position = UDim2.new(0.5, 6, 0, 0)
		rightCol.BackgroundTransparency = 1
		rightCol.Parent = scroll

		local rightLayout = Instance.new("UIListLayout")
		rightLayout.Padding = UDim.new(0, 10)
		rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rightLayout.Parent = rightCol

		local function resizeCanvas()
			local lHeight = leftLayout.AbsoluteContentSize.Y
			local rHeight = rightLayout.AbsoluteContentSize.Y
			leftCol.Size = UDim2.new(0.5, -6, 0, lHeight)
			rightCol.Size = UDim2.new(0.5, -6, 0, rHeight)
			scroll.CanvasSize = UDim2.new(0, 0, 0, math.max(lHeight, rHeight) + 32)
		end

		leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeCanvas)
		rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeCanvas)

		pages[name] = {
			Scroll = scroll,
			Left = leftCol,
			Right = rightCol,
			Resize = resizeCanvas
		}

		if order == 1 then
			selectTab(name)
		end

		local tabObj = {}
		local cardOrderCounter = 0

		function tabObj:CreateCard(cardOpts)
			cardOpts = cardOpts or {}
			cardOrderCounter += 1
			local titleStr = cardOpts.Title or "Section"
			local badgeStr = cardOpts.Badge or "Ready"
			local side = (cardOpts.Side == "Right") and "Right" or "Left"
			local parentCol = (side == "Right") and rightCol or leftCol

			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 56)
			card.LayoutOrder = cardOpts.Order or cardOrderCounter
			card.BackgroundColor3 = theme.BgCard
			card.Parent = parentCol
			addCorner(card, 10)
			addStroke(card, theme.Border, 1)

			local header = Instance.new("TextButton")
			header.Size = UDim2.new(1, 0, 0, 34)
			header.BackgroundColor3 = theme.BgCardHeader
			header.BackgroundTransparency = 0.35
			header.Text = ""
			header.AutoButtonColor = false
			header.Parent = card
			addCorner(header, 10)

			local tLbl = Instance.new("TextLabel")
			tLbl.Size = UDim2.new(0.55, 0, 1, 0)
			tLbl.Position = UDim2.new(0, 12, 0, 0)
			tLbl.BackgroundTransparency = 1
			tLbl.Font = Enum.Font.GothamBold
			tLbl.TextSize = 12
			tLbl.TextXAlignment = Enum.TextXAlignment.Left
			tLbl.TextColor3 = theme.TextPrimary
			tLbl.Text = titleStr
			tLbl.Parent = header

			local badge = Instance.new("Frame")
			badge.Size = UDim2.new(0, 88, 0, 20)
			badge.Position = UDim2.new(1, -112, 0.5, -10)
			badge.BackgroundColor3 = theme.BgPill
			badge.Parent = header
			addCorner(badge, 10)
			addStroke(badge, theme.Border, 1)

			local badgeLbl = Instance.new("TextLabel")
			badgeLbl.Size = UDim2.new(1, -8, 1, 0)
			badgeLbl.Position = UDim2.new(0, 4, 0, 0)
			badgeLbl.BackgroundTransparency = 1
			badgeLbl.Font = Enum.Font.GothamMedium
			badgeLbl.TextSize = 10
			badgeLbl.TextTruncate = Enum.TextTruncate.AtEnd
			badgeLbl.TextColor3 = theme.TextSecondary
			badgeLbl.Text = badgeStr
			badgeLbl.Parent = badge

			local chevron = Instance.new("TextLabel")
			chevron.Size = UDim2.new(0, 18, 1, 0)
			chevron.Position = UDim2.new(1, -22, 0, 0)
			chevron.BackgroundTransparency = 1
			chevron.Font = Enum.Font.GothamBold
			chevron.TextSize = 11
			chevron.TextColor3 = theme.TextSecondary
			chevron.Text = "⌄"
			chevron.Parent = header

			local body = Instance.new("Frame")
			body.Size = UDim2.new(1, -20, 0, 0)
			body.Position = UDim2.new(0, 10, 0, 40)
			body.BackgroundTransparency = 1
			body.ClipsDescendants = false
			body.Parent = card

			local bodyLayout = Instance.new("UIListLayout")
			bodyLayout.Padding = UDim.new(0, 8)
			bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
			bodyLayout.Parent = body

			local collapsed = false
			local function recalcCard()
				if collapsed then
					body.Visible = false
					body.Size = UDim2.new(1, -20, 0, 0)
					card.Size = UDim2.new(1, 0, 0, 36)
					chevron.Text = "›"
				else
					body.Visible = true
					local h = bodyLayout.AbsoluteContentSize.Y
					body.Size = UDim2.new(1, -20, 0, h)
					card.Size = UDim2.new(1, 0, 0, 54 + h)
					chevron.Text = "⌄"
				end
				resizeCanvas()
			end

			bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(recalcCard)
			header.MouseButton1Click:Connect(function()
				collapsed = not collapsed
				recalcCard()
			end)

			local searchEntry = {
				Frame = card,
				Keywords = string.lower(titleStr .. " " .. badgeStr)
			}
			table.insert(searchableItems, searchEntry)

			local cardObj = {}
			local elemOrder = 0

			function cardObj:SetBadge(text, color)
				badgeLbl.Text = tostring(text)
				if color then
					badgeLbl.TextColor3 = color
				end
			end

			function cardObj:AddCheckbox(cOpts)
				cOpts = cOpts or {}
				elemOrder += 1
				local labelText = cOpts.Text or "Option"
				local state = cOpts.Default and true or false
				local cb = cOpts.Callback

				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, 0, 0, 26)
				row.LayoutOrder = elemOrder
				row.BackgroundTransparency = 1
				row.Text = ""
				row.AutoButtonColor = false
				row.Parent = body

				local box = Instance.new("Frame")
				box.Size = UDim2.new(0, 16, 0, 16)
				box.Position = UDim2.new(0, 0, 0.5, -8)
				box.BackgroundColor3 = state and theme.Accent or theme.BgPill
				box.Parent = row
				addCorner(box, 4)
				addStroke(box, state and theme.Accent or theme.Border, 1)

				local checkMark = Instance.new("TextLabel")
				checkMark.Size = UDim2.new(1, 0, 1, 0)
				checkMark.BackgroundTransparency = 1
				checkMark.Font = Enum.Font.GothamBold
				checkMark.TextSize = 11
				checkMark.TextColor3 = Color3.new(1, 1, 1)
				checkMark.Text = state and "✓" or ""
				checkMark.Parent = box

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, -24, 1, 0)
				lbl.Position = UDim2.new(0, 24, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamMedium
				lbl.TextSize = 11
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.TextColor3 = theme.TextPrimary
				lbl.Text = labelText
				lbl.Parent = row

				local function setState(val, fire)
					state = val and true or false
					box.BackgroundColor3 = state and theme.Accent or theme.BgPill
					checkMark.Text = state and "✓" or ""
					if fire and cb then
						cb(state)
					end
				end

				row.MouseButton1Click:Connect(function()
					setState(not state, true)
				end)

				searchEntry.Keywords ..= " " .. string.lower(labelText)
				return {
					Set = function(_, val) setState(val, false) end,
					Get = function() return state end
				}
			end

			function cardObj:AddSegmented(sOpts)
				sOpts = sOpts or {}
				elemOrder += 1
				local labelText = sOpts.Text or "Select"
				local options = sOpts.Options or { "A", "B" }
				local currentOpt = sOpts.Default or options[1]
				local cb = sOpts.Callback

				local container = Instance.new("Frame")
				container.Size = UDim2.new(1, 0, 0, 44)
				container.LayoutOrder = elemOrder
				container.BackgroundTransparency = 1
				container.Parent = body

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, 16)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.GothamMedium
				lbl.TextSize = 11
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.TextColor3 = theme.TextSecondary
				lbl.Text = labelText
				lbl.Parent = container

				local segHolder = Instance.new("Frame")
				segHolder.Size = UDim2.new(1, 0, 0, 24)
				segHolder.Position = UDim2.new(0, 0, 0, 20)
				segHolder.BackgroundColor3 = theme.BgPill
				segHolder.Parent = container
				addCorner(segHolder, 6)
				addStroke(segHolder, theme.Border, 1)

				local buttons = {}
				local count = #options
				for i, opt in ipairs(options) do
					local b = Instance.new("TextButton")
					b.Size = UDim2.new(1 / count, -4, 1, -4)
					b.Position = UDim2.new((i - 1) / count, 2, 0, 2)
					b.BackgroundColor3 = (opt == currentOpt) and theme.Accent or Color3.fromRGB(0, 0, 0)
					b.BackgroundTransparency = (opt == currentOpt) and 0 or 1
					b.Font = Enum.Font.GothamBold
					b.TextSize = 11
					b.TextColor3 = (opt == currentOpt) and Color3.new(1, 1, 1) or theme.TextSecondary
					b.Text = opt
					b.AutoButtonColor = false
					b.Parent = segHolder
					addCorner(b, 5)
					buttons[opt] = b
				end

				local function setOption(optVal, fire)
					currentOpt = optVal
					for k, b in pairs(buttons) do
						local active = (k == optVal)
						b.BackgroundTransparency = active and 0 or 1
						b.BackgroundColor3 = active and theme.Accent or Color3.fromRGB(0, 0, 0)
						b.TextColor3 = active and Color3.new(1, 1, 1) or theme.TextSecondary
					end
					if fire and cb then
						cb(optVal)
					end
				end

				for opt, b in pairs(buttons) do
					b.MouseButton1Click:Connect(function()
						setOption(opt, true)
					end)
				end

				searchEntry.Keywords ..= " " .. string.lower(labelText .. " " .. table.concat(options, " "))
				return {
					Set = function(_, val) setOption(val, false) end,
					Get = function() return currentOpt end
				}
			end

			function cardObj:AddButton(bOpts)
				bOpts = bOpts or {}
				elemOrder += 1
				local btnText = bOpts.Text or "Button"
				local accentStyle = bOpts.Accent and true or false
				local cb = bOpts.Callback

				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 28)
				btn.LayoutOrder = elemOrder
				btn.BackgroundColor3 = accentStyle and theme.AccentSoft or theme.BgPill
				btn.Font = Enum.Font.GothamBold
				btn.TextSize = 11
				btn.TextColor3 = accentStyle and theme.Accent or theme.TextPrimary
				btn.Text = btnText
				btn.AutoButtonColor = false
				btn.Parent = body
				addCorner(btn, 6)
				addStroke(btn, accentStyle and theme.Accent or theme.Border, 1)

				btn.MouseEnter:Connect(function()
					btn.BackgroundColor3 = accentStyle and theme.Accent or theme.BgHover
					if accentStyle then
						btn.TextColor3 = Color3.new(1, 1, 1)
					end
				end)
				btn.MouseLeave:Connect(function()
					btn.BackgroundColor3 = accentStyle and theme.AccentSoft or theme.BgPill
					btn.TextColor3 = accentStyle and theme.Accent or theme.TextPrimary
				end)
				btn.MouseButton1Click:Connect(function()
					if cb then cb() end
				end)

				searchEntry.Keywords ..= " " .. string.lower(btnText)
				return btn
			end

			function cardObj:AddLabel(text)
				elemOrder += 1
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, 16)
				lbl.LayoutOrder = elemOrder
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 11
				lbl.TextTruncate = Enum.TextTruncate.AtEnd
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.TextColor3 = theme.TextSecondary
				lbl.Text = tostring(text or "")
				lbl.Parent = body

				return {
					Set = function(_, newText)
						lbl.Text = tostring(newText or "")
					end
				}
			end

			return cardObj
		end

		return tabObj
	end

	-- Floating reopen drag + tap
	makeDraggable(reopenBtn, reopenBtn, 1, function()
		reopenBtn.Visible = false
		mainWindow.Visible = true
		for _, p in pairs(pages) do
			if p.Scroll.Visible then
				p.Resize()
			end
		end
	end)

	-- Search filter
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(string.gsub(searchBox.Text, "^%s*(.-)%s*$", "%1"))
		for _, entry in ipairs(searchableItems) do
			if q == "" then
				entry.Frame.Visible = true
			else
				entry.Frame.Visible = string.find(entry.Keywords, q, 1, true) ~= nil
			end
		end
		for _, p in pairs(pages) do
			p.Resize()
		end
	end)

	minBtn.MouseButton1Click:Connect(function()
		mainWindow.Visible = false
		reopenBtn.Visible = true
	end)

	closeBtn.MouseButton1Click:Connect(function()
		mainWindow.Visible = false
		reopenBtn.Visible = true
	end)

	local inputConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == toggleKey then
			local nextVis = not mainWindow.Visible
			mainWindow.Visible = nextVis
			reopenBtn.Visible = not nextVis
		end
	end)

	local lastFps = 60
	local hbConn = RunService.Heartbeat:Connect(function(dt)
		if dt > 0 then
			lastFps = math.floor((1 / dt) + 0.5)
		end
	end)

	function winObj:GetFps()
		return lastFps
	end

	function winObj:Destroy()
		if camConn then camConn:Disconnect() end
		if inputConn then inputConn:Disconnect() end
		if hbConn then hbConn:Disconnect() end
		screenGui:Destroy()
	end

	return winObj
end

return Library
