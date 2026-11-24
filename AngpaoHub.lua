-- Optional: If you execute this via loadstring(game:HttpGet("YOUR_RAW_URL"))(),
-- paste that exact raw URL below so queue_on_teleport can re-run it after hopping.
local SCRIPT_URL = ""

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- State variables
local autoCollectEnabled = false
local collectMethod = "Walk" -- "Walk" or "Teleport"
local serverHopWhenEmpty = false
local autoLoadConfig = true
local isHopping = false
local collectedSessionCount = 0

local CONFIG_FOLDER = "AngpaoCollectorConfig"
local CONFIG_FILE = CONFIG_FOLDER .. "/MainSettings.json"

-- UI references & state setters (populated when building UI)
local UI = {
	SetAutoCollect = nil,
	SetMethod = nil,
	SetServerHop = nil,
	SetAutoLoad = nil,
	UpdateStats = nil,
	Notify = nil,
	Destroy = nil,
	SetVisible = nil
}

-- Helper: Safe file IO checks (Delta / executor compatible)
local function hasFileIO()
	return type(isfile) == "function"
		and type(readfile) == "function"
		and type(writefile) == "function"
end

local function saveConfigToFile()
	if not hasFileIO() then
		return false, "Executor file functions unavailable"
	end

	local ok, err = pcall(function()
		if type(makefolder) == "function" and not isfolder(CONFIG_FOLDER) then
			makefolder(CONFIG_FOLDER)
		end

		local payload = HttpService:JSONEncode({
			autoCollectEnabled = autoCollectEnabled,
			collectMethod = collectMethod,
			serverHopWhenEmpty = serverHopWhenEmpty,
			autoLoadConfig = autoLoadConfig
		})
		writefile(CONFIG_FILE, payload)
	end)

	return ok, err
end

local function loadConfigFromFile(force)
	if not hasFileIO() then
		return false
	end

	local ok, data = pcall(function()
		if not isfile(CONFIG_FILE) then
			return nil
		end
		return HttpService:JSONDecode(readfile(CONFIG_FILE))
	end)

	if not ok or type(data) ~= "table" then
		return false
	end

	if type(data.autoLoadConfig) == "boolean" then
		autoLoadConfig = data.autoLoadConfig
		if UI.SetAutoLoad then
			UI.SetAutoLoad(autoLoadConfig)
		end
	end

	if not force and not autoLoadConfig then
		return false
	end

	if type(data.collectMethod) == "string" and (data.collectMethod == "Walk" or data.collectMethod == "Teleport") then
		collectMethod = data.collectMethod
		if UI.SetMethod then
			UI.SetMethod(collectMethod)
		end
	end

	if type(data.serverHopWhenEmpty) == "boolean" then
		serverHopWhenEmpty = data.serverHopWhenEmpty
		if UI.SetServerHop then
			UI.SetServerHop(serverHopWhenEmpty)
		end
	end

	if type(data.autoCollectEnabled) == "boolean" then
		autoCollectEnabled = data.autoCollectEnabled
		if UI.SetAutoCollect then
			UI.SetAutoCollect(autoCollectEnabled)
		end
	end

	return true
end

-- Helper: Queue script to auto-execute after teleport (Delta Executor compatible)
local function queueAutoExecute()
	local queueFunc = queue_on_teleport
		or (syn and syn.queue_on_teleport)
		or (fluxus and fluxus.queue_on_teleport)

	if not queueFunc then
		return false
	end

	if SCRIPT_URL ~= "" then
		queueFunc(string.format('loadstring(game:HttpGet(%q))()', SCRIPT_URL))
		return true
	elseif isfile and readfile and isfile("AngpaoAutoCollect.lua") then
		-- If you save this script as "AngpaoAutoCollect.lua" inside Delta's workspace folder
		queueFunc(readfile("AngpaoAutoCollect.lua"))
		return true
	end

	return false
end

-- Helper: Get a target CFrame from an Angpao object
local function getTargetCFrame(item)
	if item:IsA("BasePart") then
		return item.CFrame
	elseif item:IsA("Model") then
		if item.PrimaryPart then
			return item.PrimaryPart.CFrame
		end
		local part = item:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.CFrame
		end
	end
	return nil
end

-- Helper: Gather valid Angpao targets inside workspace.AngpaoLocal
local function getAngpaoTargets()
	local folder = workspace:FindFirstChild("AngpaoLocal")
	if not folder then
		return {}
	end

	local targets = {}
	for _, child in ipairs(folder:GetChildren()) do
		local cf = getTargetCFrame(child)
		if cf then
			table.insert(targets, {
				Instance = child,
				CFrame = cf
			})
		end
	end
	return targets
end

-- Helper: Move character to target using Walk or Teleport
local function moveToTarget(targetCFrame, method)
	local character = LocalPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then return end

	if method == "Teleport" then
		character:PivotTo(targetCFrame + Vector3.new(0, 3, 0))
		task.wait(0.25)
	else
		local reached = false
		local conn
		conn = humanoid.MoveToFinished:Connect(function()
			reached = true
		end)

		humanoid:MoveTo(targetCFrame.Position)

		local elapsed = 0
		local timeout = 8
		while autoCollectEnabled and not reached and elapsed < timeout do
			local currentChar = LocalPlayer.Character
			local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
			if currentHum then
				currentHum:MoveTo(targetCFrame.Position)
			end
			elapsed += task.wait(0.2)
		end

		if conn then
			conn:Disconnect()
		end
		task.wait(0.15)
	end
end

-- Helper: Server hop to another public server instance
local function serverHop()
	if isHopping then return end
	isHopping = true

	if UI.UpdateStats then
		UI.UpdateStats()
	end

	-- Queue script for next server before teleporting
	local queued = queueAutoExecute()

	if UI.Notify then
		UI.Notify(
			"Angpao Collector",
			queued
				and "No Angpao found. Hopping & queuing auto-execute..."
				or "No Angpao found. Hopping (put script in Delta autoexec if not using SCRIPT_URL)...",
			4
		)
	end

	task.wait(1)

	local placeId = game.PlaceId
	local jobId = game.JobId
	local servers = {}

	local success, response = pcall(function()
		local url = string.format(
			"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
			placeId
		)
		return HttpService:JSONDecode(game:HttpGet(url))
	end)

	if success and response and response.data then
		for _, server in ipairs(response.data) do
			if type(server) == "table"
				and server.id ~= jobId
				and tonumber(server.playing)
				and tonumber(server.maxPlayers)
				and server.playing < server.maxPlayers then
				table.insert(servers, server.id)
			end
		end
	end

	if #servers > 0 then
		local randomServer = servers[math.random(1, #servers)]
		TeleportService:TeleportToPlaceInstance(placeId, randomServer, LocalPlayer)
	else
		TeleportService:Teleport(placeId, LocalPlayer)
	end
end

-- ============================================================================
-- CUSTOM DARK DASHBOARD UI (NO RAYFIELD)
-- ============================================================================
local function buildDashboardUI()
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

	local parentGui = nil
	pcall(function()
		if gethui then
			parentGui = gethui()
		end
	end)
	if not parentGui then
		parentGui = game:GetService("CoreGui")
	end
	local usePlayerGuiFallback = false
	local testOk = pcall(function()
		local f = Instance.new("Folder")
		f.Parent = parentGui
		f:Destroy()
	end)
	if not testOk then
		parentGui = LocalPlayer:WaitForChild("PlayerGui")
		usePlayerGuiFallback = true
	end

	-- Cleanup any existing instance
	local existing = parentGui:FindFirstChild("AngpaoDashboardUI")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AngpaoDashboardUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 999
	screenGui.Parent = parentGui

	if usePlayerGuiFallback and screenGui:IsA("ScreenGui") then
		screenGui.IgnoreGuiInset = true
	end

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

	-- Main Window (created first so reopenBtn can scale consistently with it)
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

	-- Floating draggable reopen pill (shown when window is minimized/hidden)
	local reopenBtn = Instance.new("TextButton")
	reopenBtn.Name = "ReopenButton"
	reopenBtn.Size = UDim2.new(0, 152, 0, 38)
	reopenBtn.Position = UDim2.new(0.5, -76, 0, 64)
	reopenBtn.BackgroundColor3 = theme.BgCard
	reopenBtn.TextColor3 = theme.TextPrimary
	reopenBtn.Font = Enum.Font.GothamBold
	reopenBtn.TextSize = 12
	reopenBtn.Text = "🧧  Angpao UI"
	reopenBtn.AutoButtonColor = false
	reopenBtn.Active = true
	reopenBtn.Visible = false
	reopenBtn.ZIndex = 20
	reopenBtn.Parent = screenGui
	addCorner(reopenBtn, 10)
	addStroke(reopenBtn, theme.Accent, 1.4)

	local function refreshScale()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		local scaleX = (vp.X - 20) / 760
		local scaleY = (vp.Y - 20) / 460
		uiScale.Scale = math.clamp(math.min(scaleX, scaleY, 1), 0.55, 1)
	end
	refreshScale()
	local camConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		refreshScale()
	end)

	-- Dragging support (works on mouse + mobile touch, with optional tap callback)
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

	-- ========================================================================
	-- LEFT SIDEBAR (Brand Header + Nav Tabs + Player Footer)
	-- ========================================================================
	local sidebarWidth = 178
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
	sidebar.Position = UDim2.new(0, 0, 0, 0)
	sidebar.BackgroundColor3 = theme.BgSidebar
	sidebar.BorderSizePixel = 0
	sidebar.Parent = mainWindow

	local sidebarBorder = Instance.new("Frame")
	sidebarBorder.Size = UDim2.new(0, 1, 1, 0)
	sidebarBorder.Position = UDim2.new(1, -1, 0, 0)
	sidebarBorder.BackgroundColor3 = theme.Border
	sidebarBorder.BorderSizePixel = 0
	sidebarBorder.Parent = sidebar

	-- Brand Header
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
	brandTitle.Text = "AngpaoHub"
	brandTitle.Parent = brandFrame

	local brandSub = Instance.new("TextLabel")
	brandSub.Size = UDim2.new(1, -56, 0, 14)
	brandSub.Position = UDim2.new(0, 50, 0, 28)
	brandSub.BackgroundTransparency = 1
	brandSub.Font = Enum.Font.Gotham
	brandSub.TextSize = 10
	brandSub.TextXAlignment = Enum.TextXAlignment.Left
	brandSub.TextColor3 = theme.TextMuted
	brandSub.Text = "v1.2.0 • Auto Farm"
	brandSub.Parent = brandFrame

	local sectionLabel = Instance.new("TextLabel")
	sectionLabel.Size = UDim2.new(1, -24, 0, 20)
	sectionLabel.Position = UDim2.new(0, 14, 0, 62)
	sectionLabel.BackgroundTransparency = 1
	sectionLabel.Font = Enum.Font.GothamMedium
	sectionLabel.TextSize = 10
	sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	sectionLabel.TextColor3 = theme.TextMuted
	sectionLabel.Text = "Main"
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

	-- Player Footer
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
	playerStatusLbl.Text = "Executor Ready"
	playerStatusLbl.Parent = footerFrame

	-- ========================================================================
	-- RIGHT CONTENT AREA (Top Header + Telemetry Pill + Search + Pages)
	-- ========================================================================
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, -sidebarWidth, 1, 0)
	contentArea.Position = UDim2.new(0, sidebarWidth, 0, 0)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = mainWindow

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
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
	pageTitleLbl.Text = "Collector"
	pageTitleLbl.Parent = topBar

	-- Telemetry strip
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
	telemetryLbl.Text = "60 fps  •  0 Angpao"
	telemetryLbl.Parent = telemetryPill

	-- Search input
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

	-- Minimize & Close buttons
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

	-- Pages container
	local pagesHolder = Instance.new("Frame")
	pagesHolder.Size = UDim2.new(1, 0, 1, -44)
	pagesHolder.Position = UDim2.new(0, 0, 0, 44)
	pagesHolder.BackgroundTransparency = 1
	pagesHolder.Parent = contentArea

	local pages = {}
	local navButtons = {}
	local searchableItems = {} -- { Frame = inst, Page = pageFrame, Keywords = string }

	local function createPage(name)
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
		leftCol.Name = "LeftColumn"
		leftCol.Size = UDim2.new(0.5, -6, 0, 0)
		leftCol.Position = UDim2.new(0, 0, 0, 0)
		leftCol.BackgroundTransparency = 1
		leftCol.Parent = scroll

		local leftLayout = Instance.new("UIListLayout")
		leftLayout.Padding = UDim.new(0, 10)
		leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
		leftLayout.Parent = leftCol

		local rightCol = Instance.new("Frame")
		rightCol.Name = "RightColumn"
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
		return pages[name]
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

	local function addNavTab(name, iconText, order)
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
	end

	-- Card & control builders
	local function createCard(pageObj, columnSide, titleText, badgeText, order)
		local parentCol = (columnSide == "Right") and pageObj.Right or pageObj.Left

		local card = Instance.new("Frame")
		card.Name = titleText .. "Card"
		card.Size = UDim2.new(1, 0, 0, 56)
		card.LayoutOrder = order
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

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(0.55, 0, 1, 0)
		titleLbl.Position = UDim2.new(0, 12, 0, 0)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextSize = 12
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.TextColor3 = theme.TextPrimary
		titleLbl.Text = titleText
		titleLbl.Parent = header

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
		badgeLbl.Text = badgeText or "Ready"
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
		body.Name = "Body"
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
			pageObj.Resize()
		end

		bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(recalcCard)

		header.MouseButton1Click:Connect(function()
			collapsed = not collapsed
			recalcCard()
		end)

		table.insert(searchableItems, {
			Frame = card,
			Page = pageObj.Scroll,
			Keywords = string.lower(titleText .. " " .. (badgeText or ""))
		})

		return {
			Card = card,
			Body = body,
			BadgeLabel = badgeLbl,
			Recalc = recalcCard,
			AddKeyword = function(extra)
				searchableItems[#searchableItems].Keywords ..= " " .. string.lower(extra)
			end
		}
	end

	local function addCheckboxRow(cardObj, labelText, initialVal, order, onChanged)
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 26)
		row.LayoutOrder = order
		row.BackgroundTransparency = 1
		row.Text = ""
		row.AutoButtonColor = false
		row.Parent = cardObj.Body

		local box = Instance.new("Frame")
		box.Size = UDim2.new(0, 16, 0, 16)
		box.Position = UDim2.new(0, 0, 0.5, -8)
		box.BackgroundColor3 = initialVal and theme.Accent or theme.BgPill
		box.Parent = row
		addCorner(box, 4)
		addStroke(box, initialVal and theme.Accent or theme.Border, 1)

		local checkMark = Instance.new("TextLabel")
		checkMark.Size = UDim2.new(1, 0, 1, 0)
		checkMark.BackgroundTransparency = 1
		checkMark.Font = Enum.Font.GothamBold
		checkMark.TextSize = 11
		checkMark.TextColor3 = Color3.new(1, 1, 1)
		checkMark.Text = initialVal and "✓" or ""
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

		local state = initialVal and true or false
		local function setState(val, fireCallback)
			state = val and true or false
			box.BackgroundColor3 = state and theme.Accent or theme.BgPill
			checkMark.Text = state and "✓" or ""
			if fireCallback and onChanged then
				onChanged(state)
			end
		end

		row.MouseButton1Click:Connect(function()
			setState(not state, true)
		end)

		cardObj.AddKeyword(labelText)
		return function(val)
			setState(val, false)
		end
	end

	local function addSegmentedRow(cardObj, labelText, options, currentOpt, order, onChanged)
		local container = Instance.new("Frame")
		container.Size = UDim2.new(1, 0, 0, 44)
		container.LayoutOrder = order
		container.BackgroundTransparency = 1
		container.Parent = cardObj.Body

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

		local function setOption(optVal, fireCallback)
			for k, b in pairs(buttons) do
				local active = (k == optVal)
				b.BackgroundTransparency = active and 0 or 1
				b.BackgroundColor3 = active and theme.Accent or Color3.fromRGB(0, 0, 0)
				b.TextColor3 = active and Color3.new(1, 1, 1) or theme.TextSecondary
			end
			if fireCallback and onChanged then
				onChanged(optVal)
			end
		end

		for opt, b in pairs(buttons) do
			b.MouseButton1Click:Connect(function()
				setOption(opt, true)
			end)
		end

		cardObj.AddKeyword(labelText .. " " .. table.concat(options, " "))
		return function(val)
			setOption(val, false)
		end
	end

	local function addActionButton(cardObj, btnText, accentStyle, order, onClick)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 28)
		btn.LayoutOrder = order
		btn.BackgroundColor3 = accentStyle and theme.AccentSoft or theme.BgPill
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 11
		btn.TextColor3 = accentStyle and theme.Accent or theme.TextPrimary
		btn.Text = btnText
		btn.AutoButtonColor = false
		btn.Parent = cardObj.Body
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
		btn.MouseButton1Click:Connect(onClick)

		cardObj.AddKeyword(btnText)
		return btn
	end

	local function addInfoLine(cardObj, initialText, order)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 16)
		lbl.LayoutOrder = order
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 11
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextColor3 = theme.TextSecondary
		lbl.Text = initialText
		lbl.Parent = cardObj.Body
		return lbl
	end

	-- Toast Notification container (bottom-right)
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

	local toastOrder = 0
	UI.Notify = function(title, content, duration)
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

	-- Build Tabs & Pages
	addNavTab("Collector", "🧧", 1)
	addNavTab("Settings", "⚙", 2)

	local collectorPage = createPage("Collector")
	local settingsPage = createPage("Settings")

	-- Collector Tab Cards
	local farmCard = createCard(collectorPage, "Left", "Angpao Auto Farm", "Idle", 1)
	UI.SetAutoCollect = addCheckboxRow(farmCard, "Auto Collect All Angpao", autoCollectEnabled, 1, function(val)
		autoCollectEnabled = val
		if UI.UpdateStats then
			UI.UpdateStats()
		end
	end)
	local targetCountLbl = addInfoLine(farmCard, "Targets in AngpaoLocal: 0", 2)
	local sessionCountLbl = addInfoLine(farmCard, "Collected this session: 0", 3)

	local moveCard = createCard(collectorPage, "Right", "Movement & Hopping", collectMethod, 1)
	UI.SetMethod = addSegmentedRow(moveCard, "Movement Method", { "Walk", "Teleport" }, collectMethod, 1, function(opt)
		collectMethod = opt
		moveCard.BadgeLabel.Text = opt
	end)
	UI.SetServerHop = addCheckboxRow(moveCard, "Server Hop If No Angpao", serverHopWhenEmpty, 2, function(val)
		serverHopWhenEmpty = val
	end)
	addActionButton(moveCard, "Server Hop Now", false, 3, function()
		serverHop()
	end)

	-- Settings Tab Cards
	local cfgCard = createCard(settingsPage, "Left", "Configuration", "JSON", 1)
	UI.SetAutoLoad = addCheckboxRow(cfgCard, "Auto-Load Previous Settings on Startup", autoLoadConfig, 1, function(val)
		autoLoadConfig = val
	end)
	addActionButton(cfgCard, "Save Current Settings", true, 2, function()
		local ok, err = saveConfigToFile()
		UI.Notify(
			ok and "Settings Saved" or "Save Failed",
			ok and "Your toggles and movement mode have been saved." or tostring(err),
			3
		)
	end)
	addActionButton(cfgCard, "Load Previous Settings", false, 3, function()
		local loaded = loadConfigFromFile(true)
		UI.Notify(
			loaded and "Settings Loaded" or "No Config Found",
			loaded and "Restored your saved configuration." or "No saved configuration file was found.",
			3
		)
	end)

	local uiCard = createCard(settingsPage, "Right", "Interface Controls", "Active", 1)
	addInfoLine(uiCard, "Drag floating icon or press RightShift", 1)
	addActionButton(uiCard, "Hide to Floating Pill", false, 2, function()
		mainWindow.Visible = false
		reopenBtn.Visible = true
	end)
	addActionButton(uiCard, "Unload UI", true, 3, function()
		autoCollectEnabled = false
		if UI.Destroy then
			UI.Destroy()
		end
	end)

	-- Make floating reopen icon draggable on touch & mouse, and reopen on tap
	makeDraggable(reopenBtn, reopenBtn, 1, function()
		reopenBtn.Visible = false
		mainWindow.Visible = true
		for _, p in pairs(pages) do
			if p.Scroll.Visible then
				p.Resize()
			end
		end
	end)

	-- Search filter across cards
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

	-- Minimize / Reopen / Close
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
		if input.KeyCode == Enum.KeyCode.RightShift then
			local nextVis = not mainWindow.Visible
			mainWindow.Visible = nextVis
			reopenBtn.Visible = not nextVis
		end
	end)

	-- Live telemetry updater
	local lastFps = 60
	local hbConn = RunService.Heartbeat:Connect(function(dt)
		if dt > 0 then
			lastFps = math.floor((1 / dt) + 0.5)
		end
	end)

	UI.UpdateStats = function()
		if not screenGui.Parent then return end
		local targets = getAngpaoTargets()
		local count = #targets
		telemetryLbl.Text = string.format("%d fps  •  %d Angpao", lastFps, count)
		targetCountLbl.Text = string.format("Targets in AngpaoLocal: %d", count)
		sessionCountLbl.Text = string.format("Collected this session: %d", collectedSessionCount)

		if isHopping then
			farmCard.BadgeLabel.Text = "Hopping"
			farmCard.BadgeLabel.TextColor3 = theme.Accent
			playerStatusLbl.Text = "Server Hopping..."
		elseif autoCollectEnabled then
			farmCard.BadgeLabel.Text = "Running"
			farmCard.BadgeLabel.TextColor3 = theme.Success
			playerStatusLbl.Text = "Collecting (" .. collectMethod .. ")"
		else
			farmCard.BadgeLabel.Text = "Idle"
			farmCard.BadgeLabel.TextColor3 = theme.TextSecondary
			playerStatusLbl.Text = "Executor Ready"
		end
	end

	UI.Destroy = function()
		if camConn then camConn:Disconnect() end
		if inputConn then inputConn:Disconnect() end
		if hbConn then hbConn:Disconnect() end
		screenGui:Destroy()
	end

	selectTab("Collector")
	UI.UpdateStats()
	return UI
end

-- Build UI
buildDashboardUI()

-- Load saved configuration automatically on execution
task.defer(function()
	task.wait(0.5)
	loadConfigFromFile(false)
	if UI.UpdateStats then
		UI.UpdateStats()
	end
end)

-- Main Auto-Collect Loop
task.spawn(function()
	while true do
		if UI.UpdateStats then
			UI.UpdateStats()
		end

		if autoCollectEnabled and not isHopping then
			local targets = getAngpaoTargets()

			if #targets > 0 then
				for _, entry in ipairs(targets) do
					if not autoCollectEnabled or isHopping then
						break
					end
					if entry.Instance and entry.Instance.Parent then
						local latestCF = getTargetCFrame(entry.Instance) or entry.CFrame
						moveToTarget(latestCF, collectMethod)
						if not entry.Instance.Parent then
							collectedSessionCount += 1
						end
						if UI.UpdateStats then
							UI.UpdateStats()
						end
					end
				end
			else
				if serverHopWhenEmpty then
					serverHop()
				end
			end
		end
		task.wait(0.5)
	end
end)
