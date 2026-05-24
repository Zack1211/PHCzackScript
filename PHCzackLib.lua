-- // PHCzack UI Library v2.0 + Online Key System
-- // Server-hosted usage (recommended):
-- //   local PHCzack = loadstring(game:HttpGet("http://script.x10.mx/scripts.php?name=PHCzackLib"))()
-- //
-- // GitHub raw link usage (fallback):
-- //   local PHCzack = loadstring(game:HttpGet("YOUR_RAW_URL"))()
-- //
-- // Studio ModuleScript usage:
-- //   local PHCzack = require(game.ReplicatedStorage.PHCzack)
-- //
-- // This file MUST be used as shown above.
-- // Do NOT paste this whole file into executor and run it directly.
-- // It only defines the library - your script calls it.

-- ============================================================
-- SERVICES
-- ============================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

-- ============================================================
-- KEY SYSTEM CONFIGURATION
-- Change these to match your server setup
-- ============================================================
local KEY_CONFIG = {
    -- ================================================================
    -- Your PHP admin panel at script.x10.mx
    -- Manage keys & providers at: /admin.php?page=api_providers
    -- ================================================================
    API_URL      = "http://script.x10.mx/api.php",
    API_SECRET   = "PHCz_S3cR3t_K3y_2026!@#",

    -- Provider links are fetched dynamically from your admin panel.
    API_PROVIDERS = {},

    -- Heartbeat interval (seconds) — keeps keys alive on your server
    HEARTBEAT_INTERVAL = 300,
    KEY_FILE     = "PHCzack_key.dat",
}

-- ============================================================
-- THEME
-- ============================================================
local T = {
    BG      = Color3.fromRGB(10, 12, 18),
    SURFACE = Color3.fromRGB(17, 20, 30),
    BORDER  = Color3.fromRGB(30, 38, 55),
    ACCENT  = Color3.fromRGB(0, 210, 120),
    ACCENT2 = Color3.fromRGB(0, 140, 255),
    DANGER  = Color3.fromRGB(220, 60, 60),
    TEXT    = Color3.fromRGB(200, 215, 230),
    DIM     = Color3.fromRGB(90, 110, 140),
    WHITE   = Color3.fromRGB(255, 255, 255),
    INPUT   = Color3.fromRGB(8, 10, 16),
    TOG_ON  = Color3.fromRGB(0, 210, 120),
    TOG_OFF = Color3.fromRGB(40, 50, 65),
}

-- ── Mobile-aware sizing ─────────────────────────────────────
local _IS_MOBILE = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
    or  (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)

local _VP        = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
                   or Vector2.new(800, 600)

-- On mobile: use a compact fixed size that fits most phone screens
-- Width: ~88% of screen. Height: ~95% of screen (near full height)
-- On PC: original 460×520
local _mobileW = math.floor(math.min(_VP.X * 0.88, 340))
local _mobileH = math.floor(math.min(_VP.Y * 0.95, 680))
local W = _IS_MOBILE and _mobileW or 460
local H = _IS_MOBILE and _mobileH or 520

-- ============================================================
-- HELPERS
-- ============================================================
local function Tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function NewFrame(parent, size, pos, color)
    local f = Instance.new("Frame")
    f.Size              = size or UDim2.new(1,0,1,0)
    f.Position          = pos  or UDim2.new(0,0,0,0)
    f.BackgroundColor3  = color or T.SURFACE
    f.BorderSizePixel   = 0
    f.Parent            = parent
    return f
end

local function NewLabel(parent, text, tsize, color, pos, size)
    local l = Instance.new("TextLabel")
    l.Text              = text or ""
    l.TextSize          = tsize or 13
    l.TextColor3        = color or T.TEXT
    l.Font              = Enum.Font.Code
    l.BackgroundTransparency = 1
    l.Position          = pos  or UDim2.new(0,0,0,0)
    l.Size              = size or UDim2.new(1,0,1,0)
    l.TextXAlignment    = Enum.TextXAlignment.Left
    l.Parent            = parent
    return l
end

local function NewCorner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
end

local function NewStroke(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color     = color or T.BORDER
    s.Thickness = thick or 1
    s.Parent    = parent
end

local function NewList(parent, gap)
    local l = Instance.new("UIListLayout")
    l.Padding       = UDim.new(0, gap or 6)
    l.FillDirection = Enum.FillDirection.Vertical
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.Parent        = parent
    return l
end

local function NewPad(parent, px)
    local p  = Instance.new("UIPadding")
    local u  = UDim.new(0, px or 8)
    p.PaddingLeft   = u
    p.PaddingRight  = u
    p.PaddingTop    = u
    p.PaddingBottom = u
    p.Parent        = parent
end

local function MakeDraggable(frame, handle)
    -- Touch / mouse drag with proper mobile support.
    -- IMPORTANT: on drag start we resolve the frame's ABSOLUTE pixel position
    -- so that any Scale component in the initial UDim2 doesn't cause a jump.
    local dragging   = false
    local dragStart  = nil
    local startAbsX  = 0
    local startAbsY  = 0

    local function onInputBegan(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            dragStart  = i.Position
            -- Capture current absolute pixel position of the frame
            startAbsX  = frame.AbsolutePosition.X
            startAbsY  = frame.AbsolutePosition.Y
        end
    end

    local function onInputChanged(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d  = i.Position - dragStart
            local vp = workspace.CurrentCamera.ViewportSize
            local ax = frame.AbsoluteSize.X
            local ay = frame.AbsoluteSize.Y
            -- Use pure offset (Scale = 0) so position never jumps
            local nx = math.clamp(startAbsX + d.X, 0, vp.X - ax)
            local ny = math.clamp(startAbsY + d.Y, 0, vp.Y - ay * 0.3)
            frame.Position = UDim2.new(0, nx, 0, ny)
        end
    end

    local function onInputEnded(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end

    handle.InputBegan:Connect(onInputBegan)
    handle.InputChanged:Connect(onInputChanged)
    UserInputService.InputChanged:Connect(function(i)
        if dragging then onInputChanged(i) end
    end)
    UserInputService.InputEnded:Connect(onInputEnded)
end

-- ============================================================
-- SAFE GUI PARENT
-- Works with loadstring() in executors AND in Studio
-- ============================================================
local function GetParent()
    -- gethui() = Synapse X, Xeno, KRNL, etc.
    if gethui then
        return gethui()
    end
    -- CoreGui works in most executors
    local ok = pcall(function()
        local t = Instance.new("ScreenGui")
        t.Parent = CoreGui
        t:Destroy()
    end)
    if ok then return CoreGui end
    -- Fallback: PlayerGui (Studio / in-game LocalScript)
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
-- DEVICE ID GENERATOR
-- Creates a unique device fingerprint for key binding
-- ============================================================
local function GetDeviceId()
    local parts = {
        tostring(LocalPlayer.UserId),
        tostring(game.PlaceId),
        game:GetService("RbxAnalyticsService"):GetClientId() or "unknown"
    }
    -- Simple hash
    local str = table.concat(parts, "-")
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + string.byte(str, i)) % 0x7FFFFFFF
    end
    return string.format("RBXDEV-%08X-%s", hash, tostring(LocalPlayer.UserId))
end

-- ============================================================
-- KEY SYSTEM - HTTP HELPERS
-- ============================================================
local KeySystem = {}

function KeySystem.SaveKey(key)
    pcall(function()
        if writefile then
            writefile(KEY_CONFIG.KEY_FILE, key)
        end
    end)
end

function KeySystem.LoadKey()
    local ok, result = pcall(function()
        if readfile and isfile and isfile(KEY_CONFIG.KEY_FILE) then
            return readfile(KEY_CONFIG.KEY_FILE)
        end
        return nil
    end)
    return ok and result or nil
end

function KeySystem.DeleteKey()
    pcall(function()
        if delfile and isfile and isfile(KEY_CONFIG.KEY_FILE) then
            delfile(KEY_CONFIG.KEY_FILE)
        end
    end)
end

function KeySystem.ValidateKey(key)
    local deviceId = GetDeviceId()
    local deviceInfo = string.format("%s | PlaceId: %d | OS: %s",
        LocalPlayer.Name, game.PlaceId, UserInputService:GetPlatform().Name)

    local success, response

    -- ALWAYS try request() first — it sends X-API-Key header (required by server)
    success, response = pcall(function()
        local reqFn = request or http_request or (syn and syn.request)
        if reqFn then
            local res = reqFn({
                Url = KEY_CONFIG.API_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-API-Key"] = KEY_CONFIG.API_SECRET,
                },
                Body = HttpService:JSONEncode({
                    action = "validate",
                    key = key,
                    device_id = deviceId,
                    device_info = deviceInfo,
                }),
            })
            return res.Body
        end
        error("no_request_fn")
    end)

    -- Fallback: HttpGet with api_key as query param (no header support)
    if not success then
        success, response = pcall(function()
            return game:HttpGet(
                KEY_CONFIG.API_URL .. "?" ..
                "action=validate" ..
                "&api_key=" .. HttpService:UrlEncode(KEY_CONFIG.API_SECRET) ..
                "&key=" .. HttpService:UrlEncode(key) ..
                "&device_id=" .. HttpService:UrlEncode(deviceId) ..
                "&device_info=" .. HttpService:UrlEncode(deviceInfo),
                true
            )
        end)
    end

    if not success then
        return false, "HTTP request failed: " .. tostring(response)
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)

    if not ok or not data then
        return false, "Invalid server response"
    end

    return data.success == true, data.message or "Unknown error", data.data
end

function KeySystem.Heartbeat(key)
    local deviceId = GetDeviceId()
    pcall(function()
        if request or http_request or (syn and syn.request) then
            local reqFn = request or http_request or syn.request
            reqFn({
                Url = KEY_CONFIG.API_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-API-Key"] = KEY_CONFIG.API_SECRET,
                },
                Body = HttpService:JSONEncode({
                    action = "heartbeat",
                    key = key,
                    device_id = deviceId,
                }),
            })
        end
    end)
end

-- ============================================================
-- FETCH PROVIDER LINKS FROM SERVER
-- Dynamically loads the "Get Key" URLs from your admin panel
-- ============================================================
function KeySystem.FetchProviders()
    local providerUrl = KEY_CONFIG.API_URL .. "?action=get_key_links"

    local ok, result = pcall(function()
        -- Try request() first (supports headers)
        local reqFn = request or http_request or (syn and syn.request)
        if reqFn then
            local res = reqFn({
                Url    = providerUrl,
                Method = "GET",
                Headers = { ["Accept"] = "application/json" },
            })
            if res and res.Body then
                local data = HttpService:JSONDecode(res.Body)
                if data and data.success then
                    -- Store server flags
                    if data.weekend_free ~= nil then
                        KEY_CONFIG._weekend_free = data.weekend_free
                    end
                    if data.no_key_mode ~= nil then
                        KEY_CONFIG._no_key_mode = data.no_key_mode
                    end
                    if data.providers then
                        return data.providers
                    end
                end
            end
        end

        -- Fallback: HttpGet (no headers, but endpoint is public)
        local body = game:HttpGet(providerUrl, true)
        local data = HttpService:JSONDecode(body)
        if data and data.success then
            if data.weekend_free ~= nil then
                KEY_CONFIG._weekend_free = data.weekend_free
            end
            if data.no_key_mode ~= nil then
                KEY_CONFIG._no_key_mode = data.no_key_mode
            end
            if data.providers then
                return data.providers
            end
        end

        return nil
    end)

    if ok and result and #result > 0 then
        KEY_CONFIG.API_PROVIDERS = result
    end
end

-- ============================================================
-- KEY SYSTEM UI - Shows a key entry screen before loading lib
-- ============================================================
function KeySystem.ShowGate(onSuccess)
    -- Fetch latest provider links from your admin panel
    pcall(function() KeySystem.FetchProviders() end)

    local guiName = "PHCzack_KeyGate"

    -- Clean up any existing gate
    pcall(function()
        for _, v in ipairs(GetParent():GetChildren()) do
            if v.Name == guiName then v:Destroy() end
        end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = guiName
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder   = 10000
    pcall(function() ScreenGui.IgnoreGuiInset = true end)
    ScreenGui.Parent         = GetParent()

    -- Background overlay
    local Overlay = Instance.new("Frame")
    Overlay.Size = UDim2.new(1,0,1,0)
    Overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    Overlay.BackgroundTransparency = 0.3
    Overlay.BorderSizePixel = 0
    Overlay.Parent = ScreenGui

    -- Main card
    local _cardW   = _IS_MOBILE and math.floor(_VP.X * 0.92) or 380
    local _cardX   = _IS_MOBILE and math.floor(_VP.X * 0.04) or -190
    local _cardAnchorScale = _IS_MOBILE and 0 or 0.5
    local Card = NewFrame(ScreenGui, UDim2.new(0,_cardW,0,0), UDim2.new(_cardAnchorScale,_cardX,0.5,-180), T.BG)
    Card.ClipsDescendants = true
    NewCorner(Card, 10)
    NewStroke(Card, T.ACCENT, 1.5)

    -- Animate open
    task.spawn(function()
        task.wait(0.05)
        Tw(Card, {Size = UDim2.new(0,_cardW,0,360)}, 0.35)
    end)

    -- Header bar
    local Header = NewFrame(Card, UDim2.new(1,0,0,50), UDim2.new(0,0,0,0), T.SURFACE)
    local titleLbl = NewLabel(Header, "  PHCzack // KEY SYSTEM", 14, T.ACCENT, UDim2.new(0,10,0,0), UDim2.new(1,-50,1,0))
    titleLbl.Font = Enum.Font.Code

    -- Close / X button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size             = UDim2.new(0,30,0,30)
    CloseBtn.Position         = UDim2.new(1,-38,0,10)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(60,20,20)
    CloseBtn.Font             = Enum.Font.Code
    CloseBtn.TextSize         = 16
    CloseBtn.TextColor3       = T.DANGER
    CloseBtn.Text             = "X"
    CloseBtn.BorderSizePixel  = 0
    CloseBtn.AutoButtonColor  = false
    CloseBtn.Parent           = Header
    NewCorner(CloseBtn, 6)

    CloseBtn.MouseEnter:Connect(function()
        Tw(CloseBtn, {BackgroundColor3 = T.DANGER})
        Tw(CloseBtn, {TextColor3 = T.BG})
    end)
    CloseBtn.MouseLeave:Connect(function()
        Tw(CloseBtn, {BackgroundColor3 = Color3.fromRGB(60,20,20)})
        Tw(CloseBtn, {TextColor3 = T.DANGER})
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        Tw(Card, {Size = UDim2.new(0,_cardW,0,0)}, 0.25)
        task.wait(0.3)
        ScreenGui:Destroy()
    end)

    -- Accent line
    local AccLine = NewFrame(Card, UDim2.new(1,0,0,2), UDim2.new(0,0,0,50), T.ACCENT)

    -- Subtitle
    local subLbl = NewLabel(Card, "Enter your license key to continue", 12, T.DIM, UDim2.new(0,24,0,62), UDim2.new(1,-48,0,20))
    subLbl.TextXAlignment = Enum.TextXAlignment.Center

    -- Key input box
    local InputBG = NewFrame(Card, UDim2.new(1,-48,0,38), UDim2.new(0,24,0,94), T.INPUT)
    NewCorner(InputBG, 6)
    NewStroke(InputBG, T.BORDER)

    local KeyInput = Instance.new("TextBox")
    KeyInput.Size              = UDim2.new(1,-16,1,0)
    KeyInput.Position          = UDim2.new(0,8,0,0)
    KeyInput.BackgroundTransparency = 1
    KeyInput.Font              = Enum.Font.Code
    KeyInput.TextSize          = 13
    KeyInput.TextColor3        = T.ACCENT
    KeyInput.PlaceholderText   = "PHCz-XXXXXXXX-XXXXXXXX"
    KeyInput.PlaceholderColor3 = T.DIM
    KeyInput.Text              = ""
    KeyInput.ClearTextOnFocus  = false
    KeyInput.Parent            = InputBG

    -- Status label
    local StatusLbl = NewLabel(Card, "", 11, T.DIM, UDim2.new(0,24,0,140), UDim2.new(1,-48,0,18))
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Center

    -- Validate button
    local ValidateBtn = Instance.new("TextButton")
    ValidateBtn.Size             = UDim2.new(1,-48,0,38)
    ValidateBtn.Position         = UDim2.new(0,24,0,166)
    ValidateBtn.BackgroundColor3 = T.ACCENT
    ValidateBtn.Font             = Enum.Font.Code
    ValidateBtn.TextSize         = 14
    ValidateBtn.TextColor3       = T.BG
    ValidateBtn.Text             = "[ VALIDATE KEY ]"
    ValidateBtn.BorderSizePixel  = 0
    ValidateBtn.AutoButtonColor  = false
    ValidateBtn.Parent           = Card
    NewCorner(ValidateBtn, 6)

    -- Separator
    local sepLbl = NewLabel(Card, "--- or get a key ---", 10, T.DIM, UDim2.new(0,24,0,216), UDim2.new(1,-48,0,18))
    sepLbl.TextXAlignment = Enum.TextXAlignment.Center

    -- Get Key buttons (one per provider from your admin panel)
    local btnY = 242
    for i, provider in ipairs(KEY_CONFIG.API_PROVIDERS) do
        local GetKeyBtn = Instance.new("TextButton")
        GetKeyBtn.Size             = UDim2.new(1,-48,0,34)
        GetKeyBtn.Position         = UDim2.new(0,24,0,btnY)
        GetKeyBtn.BackgroundColor3 = T.SURFACE
        GetKeyBtn.Font             = Enum.Font.Code
        GetKeyBtn.TextSize         = 12
        GetKeyBtn.TextColor3       = T.ACCENT2
        GetKeyBtn.Text             = "[ GET KEY via " .. string.upper(provider.name) .. " ]"
        GetKeyBtn.BorderSizePixel  = 0
        GetKeyBtn.AutoButtonColor  = false
        GetKeyBtn.Parent           = Card
        NewCorner(GetKeyBtn, 6)
        NewStroke(GetKeyBtn, T.BORDER)

        GetKeyBtn.MouseEnter:Connect(function()
            Tw(GetKeyBtn, {BackgroundColor3 = Color3.fromRGB(20,30,50)})
        end)
        GetKeyBtn.MouseLeave:Connect(function()
            Tw(GetKeyBtn, {BackgroundColor3 = T.SURFACE})
        end)

        GetKeyBtn.MouseButton1Click:Connect(function()
            pcall(function()
                if setclipboard then
                    setclipboard(provider.url)
                    StatusLbl.Text = "Link copied! Complete tasks, then enter your key."
                    StatusLbl.TextColor3 = T.ACCENT2
                end
            end)
        end)

        btnY = btnY + 40
    end

    -- Footer
    local footerLbl = NewLabel(Card, "PHCzack Key System v1.0", 9, Color3.fromRGB(40,50,65),
        UDim2.new(0,0,1,-20), UDim2.new(1,0,0,18))
    footerLbl.TextXAlignment = Enum.TextXAlignment.Center

    -- Try loading saved key first
    local savedKey = KeySystem.LoadKey()
    if savedKey and #savedKey > 3 then
        KeyInput.Text = savedKey
        StatusLbl.Text = "Checking saved key..."
        StatusLbl.TextColor3 = T.ACCENT

        task.spawn(function()
            local valid, msg, data = KeySystem.ValidateKey(savedKey)
            if valid then
                StatusLbl.Text = "Key valid! Loading..."
                StatusLbl.TextColor3 = T.ACCENT
                Tw(Card, {Size = UDim2.new(0,_cardW,0,0)}, 0.25)
                task.wait(0.3)
                ScreenGui:Destroy()
                if onSuccess then onSuccess(savedKey, data) end
            else
                StatusLbl.Text = "Saved key invalid: " .. tostring(msg)
                StatusLbl.TextColor3 = T.DANGER
                KeySystem.DeleteKey()
                KeyInput.Text = ""
            end
        end)
    end

    -- Validate button click
    ValidateBtn.MouseButton1Click:Connect(function()
        local key = KeyInput.Text:match("^%s*(.-)%s*$") -- trim
        if not key or #key < 3 then
            StatusLbl.Text = "Please enter a valid key"
            StatusLbl.TextColor3 = T.DANGER
            return
        end

        ValidateBtn.Text = "[ CHECKING... ]"
        ValidateBtn.BackgroundColor3 = T.DIM
        StatusLbl.Text = "Validating..."
        StatusLbl.TextColor3 = T.DIM

        task.spawn(function()
            local valid, msg, data = KeySystem.ValidateKey(key)
            if valid then
                StatusLbl.Text = "Access granted!"
                StatusLbl.TextColor3 = T.ACCENT
                ValidateBtn.Text = "[ SUCCESS ]"
                ValidateBtn.BackgroundColor3 = T.ACCENT

                -- Save key locally
                KeySystem.SaveKey(key)

                -- Start heartbeat loop
                if KEY_CONFIG.HEARTBEAT_INTERVAL > 0 then
                    task.spawn(function()
                        while true do
                            task.wait(KEY_CONFIG.HEARTBEAT_INTERVAL)
                            KeySystem.Heartbeat(key)
                        end
                    end)
                end

                Tw(Card, {Size = UDim2.new(0,_cardW,0,0)}, 0.25)
                task.wait(0.3)
                ScreenGui:Destroy()
                if onSuccess then onSuccess(key, data) end
            else
                StatusLbl.Text = tostring(msg)
                StatusLbl.TextColor3 = T.DANGER
                ValidateBtn.Text = "[ VALIDATE KEY ]"
                ValidateBtn.BackgroundColor3 = T.ACCENT
                Tw(InputBG, {BackgroundColor3 = Color3.fromRGB(40,10,10)}, 0.1)
                task.delay(0.3, function()
                    Tw(InputBG, {BackgroundColor3 = T.INPUT}, 0.2)
                end)
            end
        end)
    end)

    MakeDraggable(Card, Header)
end

-- ============================================================
-- LIBRARY TABLE  <-- this is what gets returned to the caller
-- ============================================================
local PHCzack = {}

-- Store key config so scripts can update it before calling :CreateWindow
PHCzack.KeyConfig = KEY_CONFIG
PHCzack.KeySystem = KeySystem

-- Track if key has already been validated this session
local _keyValidatedThisSession = false
local _validatedKey = nil
local _validatedKeyData = nil

-- ============================================================
-- PHCzack:_CreateWindowInternal(config)
-- The actual window builder (no key gate).
-- This is called AFTER key validation passes.
-- ============================================================
function PHCzack:_CreateWindowInternal(config)
    config   = config or {}
    local title    = config.Title    or "PHCzack"
    local subtitle = config.SubTitle or "v2.0"
    local guiName  = "PHCzack_" .. title

    -- Kill any existing window with same name (safe re-run)
    pcall(function()
        for _, v in ipairs(CoreGui:GetChildren()) do
            if v.Name == guiName then v:Destroy() end
        end
    end)
    pcall(function()
        for _, v in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if v.Name == guiName then v:Destroy() end
        end
    end)
    pcall(function()
        if gethui then
            for _, v in ipairs(gethui():GetChildren()) do
                if v.Name == guiName then v:Destroy() end
            end
        end
    end)

    -- ScreenGui
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name            = guiName
    ScreenGui.ResetOnSpawn    = false
    ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder    = 9999
    pcall(function() ScreenGui.IgnoreGuiInset = true end)
    ScreenGui.Parent          = GetParent()

    -- Main frame (starts at height 0 so Show() animates it open)
    -- Use pure pixel offset (Scale=0) so MakeDraggable's AbsolutePosition math is always clean
    local _initX = math.floor((_VP.X - W) / 2)
    local _initY = math.floor((_VP.Y - H) / 2)
    local _startX = UDim2.new(0, _initX, 0, _initY)
    local Main = NewFrame(ScreenGui, UDim2.new(0,W,0,0), _startX, T.BG)
    Main.ClipsDescendants = true
    NewCorner(Main, 8)
    NewStroke(Main, T.BORDER)

    -- ── Title Bar ───────────────────────────────────────────
    local TitleBar = NewFrame(Main, UDim2.new(1,0,0,42), UDim2.new(0,0,0,0), T.SURFACE)

    local dots = {
        {Color3.fromRGB(255,90,90),  14},
        {Color3.fromRGB(255,190,50), 34},
        {T.ACCENT,                   54},
    }
    for _, d in ipairs(dots) do
        local dot = NewFrame(TitleBar, UDim2.new(0,12,0,12), UDim2.new(0,d[2],0.5,-6), d[1])
        NewCorner(dot, 6)
    end

    NewLabel(TitleBar, "  PHCzack // "..subtitle, _IS_MOBILE and 12 or 14, T.WHITE, UDim2.new(0,72,0,0), UDim2.new(1,-168,1,0))

    -- Minimize
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size             = UDim2.new(0,30,0,26)
    MinBtn.Position         = UDim2.new(1,-74,0.5,-13)
    MinBtn.BackgroundColor3 = T.SURFACE
    MinBtn.Font             = Enum.Font.Code
    MinBtn.TextSize         = 13
    MinBtn.TextColor3       = T.DIM
    MinBtn.Text             = "-"
    MinBtn.BorderSizePixel  = 0
    MinBtn.AutoButtonColor  = false
    MinBtn.Parent           = TitleBar
    NewCorner(MinBtn, 5)
    NewStroke(MinBtn, T.BORDER)

    -- Close
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size             = UDim2.new(0,30,0,26)
    CloseBtn.Position         = UDim2.new(1,-38,0.5,-13)
    CloseBtn.BackgroundColor3 = T.DANGER
    CloseBtn.Font             = Enum.Font.Code
    CloseBtn.TextSize         = 13
    CloseBtn.TextColor3       = T.WHITE
    CloseBtn.Text             = "X"
    CloseBtn.BorderSizePixel  = 0
    CloseBtn.AutoButtonColor  = false
    CloseBtn.Parent           = TitleBar
    NewCorner(CloseBtn, 5)

    CloseBtn.MouseButton1Click:Connect(function()
        Tw(Main, {Size = UDim2.new(0,W,0,0)}, 0.2)
        task.wait(0.22)
        ScreenGui:Destroy()
    end)

    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Tw(Main, {Size = UDim2.new(0,W,0, minimized and 42 or H)}, 0.2)
    end)

    MakeDraggable(Main, TitleBar)

    -- ── Mobile Hide/Show Floating Button ────────────────────
    -- On mobile only: a small draggable pill button so the user can
    -- hide/show the window. Uses a drag-distance threshold so dragging
    -- never accidentally triggers a hide/show toggle.
    local MobileToggleBtn = nil
    if _IS_MOBILE then
        -- Place it at a fixed pixel offset from top-left so position math is simple
        local _btnW, _btnH = 62, 28
        local _btnStartX   = 8
        local _btnStartY   = math.floor(_VP.Y - 48)  -- near bottom of screen

        MobileToggleBtn = Instance.new("TextButton")
        MobileToggleBtn.Size             = UDim2.new(0, _btnW, 0, _btnH)
        MobileToggleBtn.Position         = UDim2.new(0, _btnStartX, 0, _btnStartY)
        MobileToggleBtn.BackgroundColor3 = T.SURFACE
        MobileToggleBtn.Font             = Enum.Font.Code
        MobileToggleBtn.TextSize         = 11
        MobileToggleBtn.TextColor3       = T.ACCENT
        MobileToggleBtn.Text             = "[ UI ]"
        MobileToggleBtn.BorderSizePixel  = 0
        MobileToggleBtn.AutoButtonColor  = false
        MobileToggleBtn.ZIndex           = 20
        MobileToggleBtn.Parent           = ScreenGui
        NewCorner(MobileToggleBtn, 7)
        NewStroke(MobileToggleBtn, T.ACCENT, 1.5)

        -- Custom drag for the toggle button — uses pure offset position
        -- and tracks drag distance so we can distinguish tap vs drag
        local _tbDragging  = false
        local _tbDragStart = nil
        local _tbBtnStart  = nil
        local _tbMoved     = false   -- true if finger moved enough to count as a drag

        MobileToggleBtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
            or i.UserInputType == Enum.UserInputType.MouseButton1 then
                _tbDragging  = true
                _tbMoved     = false
                _tbDragStart = i.Position
                _tbBtnStart  = MobileToggleBtn.Position
            end
        end)

        UserInputService.InputChanged:Connect(function(i)
            if not _tbDragging then return end
            if i.UserInputType == Enum.UserInputType.Touch
            or i.UserInputType == Enum.UserInputType.MouseMovement then
                local dx = i.Position.X - _tbDragStart.X
                local dy = i.Position.Y - _tbDragStart.Y
                -- Only move if past a 6px threshold (prevents jitter toggling)
                if math.abs(dx) > 6 or math.abs(dy) > 6 then
                    _tbMoved = true
                    local vp  = workspace.CurrentCamera.ViewportSize
                    local nx  = math.clamp(_tbBtnStart.X.Offset + dx, 0, vp.X - _btnW)
                    local ny  = math.clamp(_tbBtnStart.Y.Offset + dy, 0, vp.Y - _btnH)
                    MobileToggleBtn.Position = UDim2.new(0, nx, 0, ny)
                end
            end
        end)

        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch
            or i.UserInputType == Enum.UserInputType.MouseButton1 then
                _tbDragging = false
            end
        end)

        local _guiShown = true
        MobileToggleBtn.MouseButton1Click:Connect(function()
            -- If the finger dragged, don't toggle — it was a drag not a tap
            if _tbMoved then _tbMoved = false ; return end
            _guiShown = not _guiShown
            if _guiShown then
                Main.Visible = true
                Tw(Main, {Size = UDim2.new(0,W,0,H)}, 0.2)
                MobileToggleBtn.TextColor3 = T.ACCENT
            else
                Tw(Main, {Size = UDim2.new(0,W,0,0)}, 0.18)
                task.delay(0.2, function() Main.Visible = false end)
                MobileToggleBtn.TextColor3 = T.DIM
            end
        end)
    end

    -- ── Status Bar ──────────────────────────────────────────
    local StatusBar = NewFrame(Main, UDim2.new(1,0,0,26), UDim2.new(0,0,0,42), Color3.fromRGB(13,16,24))
    local SDot = NewFrame(StatusBar, UDim2.new(0,7,0,7), UDim2.new(0,10,0.5,-3), T.ACCENT)
    NewCorner(SDot, 4)
    task.spawn(function()
        while ScreenGui.Parent do
            Tw(SDot, {BackgroundTransparency=1}, 0.5) ; task.wait(0.6)
            Tw(SDot, {BackgroundTransparency=0}, 0.3) ; task.wait(0.5)
        end
    end)
    local sess = string.format("%X", math.floor(tick()) % 0xFFFFFF)
    NewLabel(StatusBar, "[SYS] CONNECTED  |  SESSION: "..sess, _IS_MOBILE and 9 or 11, T.ACCENT, UDim2.new(0,22,0,0), UDim2.new(1,-22,1,0))

    -- ── Tab Bar ─────────────────────────────────────────────
    -- On mobile: ScrollingFrame so many tabs can be swiped horizontally
    local TabBar
    if _IS_MOBILE then
        TabBar = Instance.new("ScrollingFrame")
        TabBar.Size                 = UDim2.new(1,0,0,36)
        TabBar.Position             = UDim2.new(0,0,0,68)
        TabBar.BackgroundColor3     = T.BG
        TabBar.BorderSizePixel      = 0
        TabBar.ScrollBarThickness   = 0  -- hidden scrollbar (swipe to scroll)
        TabBar.ScrollingDirection   = Enum.ScrollingDirection.X
        TabBar.CanvasSize           = UDim2.new(0,0,0,0)
        TabBar.ClipsDescendants     = true
        TabBar.Parent               = Main
    else
        TabBar = NewFrame(Main, UDim2.new(1,0,0,36), UDim2.new(0,0,0,68), T.BG)
        TabBar.ClipsDescendants = true
    end
    local TL = Instance.new("UIListLayout")
    TL.Padding = UDim.new(0,4)
    TL.FillDirection = Enum.FillDirection.Horizontal
    TL.SortOrder = Enum.SortOrder.LayoutOrder
    TL.Parent = TabBar
    local TP = Instance.new("UIPadding")
    TP.PaddingLeft   = UDim.new(0,6) ; TP.PaddingRight  = UDim.new(0,6)
    TP.PaddingTop    = UDim.new(0,4) ; TP.PaddingBottom = UDim.new(0,4)
    TP.Parent = TabBar

    -- ── Content Host ────────────────────────────────────────
    local CY = 68 + 36 + 6
    local ContentHost = NewFrame(Main, UDim2.new(1,-20,0,H-CY-28), UDim2.new(0,10,0,CY), Color3.new(0,0,0))
    ContentHost.BackgroundTransparency = 1

    -- ── Footer ──────────────────────────────────────────────
    local FL = NewLabel(Main, string.format("PHCzack v2.0  |  %s  |  SECURE", os.date("%H:%M:%S")),
        10, T.DIM, UDim2.new(0,0,1,-20), UDim2.new(1,0,0,18))
    FL.TextXAlignment = Enum.TextXAlignment.Center

    -- ============================================================
    -- WINDOW OBJECT
    -- ============================================================
    local Window   = {}
    local AllTabs  = {}
    local AllTabBtns = {}

    -- Dynamically resize tab buttons so any number of tabs fits the bar
    local function ResizeTabBtns()
        local n = #AllTabBtns
        if n == 0 then return end
        if _IS_MOBILE then
            -- On mobile: fixed width per tab, tabs scroll horizontally
            local btnW = math.max(56, math.floor((W - 12) / math.min(n, 5)))
            for _, btn in ipairs(AllTabBtns) do
                btn.Size = UDim2.new(0, btnW, 1, -6)
            end
            -- Update scrollable canvas width
            local totalW = btnW * n + 4 * (n - 1) + 12
            TabBar.CanvasSize = UDim2.new(0, totalW, 0, 0)
        else
            local available = W - 12            -- left + right padding
            local totalGap  = 4 * (n - 1)      -- gaps between buttons
            local btnW      = math.floor((available - totalGap) / n)
            for _, btn in ipairs(AllTabBtns) do
                btn.Size = UDim2.new(0, btnW, 1, -6)
            end
        end
    end

    function Window:Show()
        -- Small wait ensures ScreenGui is registered before tweening
        task.spawn(function()
            task.wait(0.05)
            Tw(Main, {Size = UDim2.new(0,W,0,H)}, 0.35)
        end)
    end

    function Window:Hide()
        ScreenGui.Enabled = false
    end

    function Window:Toggle()
        ScreenGui.Enabled = not ScreenGui.Enabled
    end

    function Window:Destroy()
        ScreenGui:Destroy()
    end

    -- ============================================================
    -- Window:AddTab(name)
    -- ============================================================
    function Window:AddTab(name)
        local Btn = Instance.new("TextButton")
        Btn.Size             = UDim2.new(0,85,1,-6)
        Btn.BackgroundColor3 = T.SURFACE
        Btn.Font             = Enum.Font.Code
        Btn.TextSize         = _IS_MOBILE and 10 or 12
        Btn.TextColor3       = T.DIM
        Btn.Text             = name
        Btn.BorderSizePixel  = 0
        Btn.AutoButtonColor  = false
        Btn.Parent           = TabBar
        NewCorner(Btn, 5)
        NewStroke(Btn, T.BORDER)

        -- Auto-size all tab buttons to fit the bar
        table.insert(AllTabBtns, Btn)
        ResizeTabBtns()

        local Scroll = Instance.new("ScrollingFrame")
        Scroll.Size                  = UDim2.new(1,0,1,0)
        Scroll.BackgroundTransparency= 1
        Scroll.BorderSizePixel       = 0
        Scroll.ScrollBarThickness    = _IS_MOBILE and 6 or 3  -- thicker scrollbar for fingers
        Scroll.ScrollBarImageColor3  = T.ACCENT
        Scroll.CanvasSize            = UDim2.new(0,0,0,0)
        Scroll.Visible               = false
        Scroll.Parent                = ContentHost

        local IL = NewList(Scroll, 6)
        IL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Scroll.CanvasSize = UDim2.new(0,0,0, IL.AbsoluteContentSize.Y + 10)
        end)

        local Tab = {_count = 0}

        local function Activate(on)
            Btn.TextColor3       = on and T.ACCENT or T.DIM
            Btn.BackgroundColor3 = on and Color3.fromRGB(0,35,22) or T.SURFACE
            Scroll.Visible       = on
        end

        Btn.MouseButton1Click:Connect(function()
            for _, t in ipairs(AllTabs) do t._deactivate() end
            Activate(true)
        end)

        Tab._deactivate = function() Activate(false) end
        table.insert(AllTabs, Tab)
        if #AllTabs == 1 then Activate(true) end

        local function MakeRow(labelTxt, h)
            Tab._count = Tab._count + 1
            local rowH = h or (_IS_MOBILE and 40 or 40)
            local row = NewFrame(Scroll, UDim2.new(1,-6,0,rowH), nil, T.SURFACE)
            row.LayoutOrder = Tab._count
            NewCorner(row, 6) ; NewStroke(row, T.BORDER)
            local lbl = NewLabel(row, labelTxt, _IS_MOBILE and 12 or 13, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.6,-10,1,0))
            return row, lbl
        end

        -- ── Toggle ──────────────────────────────────────────
        function Tab:AddToggle(labelTxt, default, callback)
            local row   = MakeRow(labelTxt)
            local state = (default == true)

            local Track = NewFrame(row, UDim2.new(0,44,0,22), UDim2.new(1,-54,0.5,-11), state and T.TOG_ON or T.TOG_OFF)
            NewCorner(Track, 11)
            local Knob = NewFrame(Track, UDim2.new(0,18,0,18), state and UDim2.new(0,24,0.5,-9) or UDim2.new(0,2,0.5,-9), T.WHITE)
            NewCorner(Knob, 9)

            local HB = Instance.new("TextButton")
            HB.Size = UDim2.new(1,0,1,0) ; HB.BackgroundTransparency = 1 ; HB.Text = "" ; HB.Parent = row

            HB.MouseButton1Click:Connect(function()
                state = not state
                Tw(Track, {BackgroundColor3 = state and T.TOG_ON or T.TOG_OFF})
                Tw(Knob,  {Position = state and UDim2.new(0,24,0.5,-9) or UDim2.new(0,2,0.5,-9)})
                if callback then pcall(callback, state) end
            end)

            return {
                Get = function() return state end,
                Set = function(v)
                    state = v
                    Track.BackgroundColor3 = v and T.TOG_ON or T.TOG_OFF
                    Knob.Position = v and UDim2.new(0,24,0.5,-9) or UDim2.new(0,2,0.5,-9)
                end,
            }
        end

        -- ── Checkbox ────────────────────────────────────────
        function Tab:AddCheckbox(labelTxt, default, callback)
            local row   = MakeRow(labelTxt)
            local state = (default == true)

            local Box = NewFrame(row, UDim2.new(0,22,0,22), UDim2.new(1,-36,0.5,-11), state and T.ACCENT or T.INPUT)
            NewCorner(Box, 4) ; NewStroke(Box, state and T.ACCENT or T.BORDER)
            local Chk = NewLabel(Box, "v", 14, T.WHITE, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0))
            Chk.TextXAlignment  = Enum.TextXAlignment.Center
            Chk.TextTransparency = state and 0 or 1

            local HB = Instance.new("TextButton")
            HB.Size = UDim2.new(1,0,1,0) ; HB.BackgroundTransparency = 1 ; HB.Text = "" ; HB.Parent = row

            HB.MouseButton1Click:Connect(function()
                state = not state
                Tw(Box, {BackgroundColor3 = state and T.ACCENT or T.INPUT})
                Tw(Chk, {TextTransparency = state and 0 or 1})
                if callback then pcall(callback, state) end
            end)

            return {
                Get = function() return state end,
                Set = function(v)
                    state = v
                    Box.BackgroundColor3 = v and T.ACCENT or T.INPUT
                    Chk.TextTransparency = v and 0 or 1
                end,
            }
        end

        -- ── Dropdown ────────────────────────────────────────
        function Tab:AddDropdown(labelTxt, options, callback)
            Tab._count = Tab._count + 1
            local selected = options[1] or ""

            local Header = NewFrame(Scroll, UDim2.new(1,-6,0,40), nil, T.SURFACE)
            Header.LayoutOrder = Tab._count
            NewCorner(Header, 6) ; NewStroke(Header, T.BORDER)
            NewLabel(Header, labelTxt, 13, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.5,0,1,0))

            local ValBtn = Instance.new("TextButton")
            ValBtn.Size             = UDim2.new(0,140,0,28)
            ValBtn.Position         = UDim2.new(1,-148,0.5,-14)
            ValBtn.BackgroundColor3 = T.INPUT
            ValBtn.Font             = Enum.Font.Code
            ValBtn.TextSize         = 12
            ValBtn.TextColor3       = T.ACCENT
            ValBtn.Text             = selected .. " v"
            ValBtn.BorderSizePixel  = 0
            ValBtn.AutoButtonColor  = false
            ValBtn.Parent           = Header
            NewCorner(ValBtn, 5) ; NewStroke(ValBtn, T.BORDER)

            Tab._count = Tab._count + 1
            local Panel = NewFrame(Scroll, UDim2.new(1,-6,0, #options*32+8), nil, T.INPUT)
            Panel.LayoutOrder = Tab._count
            Panel.Visible     = false
            NewCorner(Panel, 6) ; NewStroke(Panel, T.ACCENT)
            NewPad(Panel, 4) ; NewList(Panel, 3)

            for _, opt in ipairs(options) do
                local OBtn = Instance.new("TextButton")
                OBtn.Size             = UDim2.new(1,0,0,28)
                OBtn.BackgroundColor3 = T.SURFACE
                OBtn.Font             = Enum.Font.Code
                OBtn.TextSize         = 12
                OBtn.TextColor3       = (opt == selected) and T.ACCENT or T.TEXT
                OBtn.Text             = "  " .. opt
                OBtn.TextXAlignment   = Enum.TextXAlignment.Left
                OBtn.BorderSizePixel  = 0
                OBtn.AutoButtonColor  = false
                OBtn.Parent           = Panel
                NewCorner(OBtn, 4)
                OBtn.MouseEnter:Connect(function() Tw(OBtn, {BackgroundColor3=Color3.fromRGB(25,35,50)}) end)
                OBtn.MouseLeave:Connect(function() Tw(OBtn, {BackgroundColor3=T.SURFACE}) end)
                OBtn.MouseButton1Click:Connect(function()
                    selected       = opt
                    ValBtn.Text    = opt .. " v"
                    for _, c in ipairs(Panel:GetChildren()) do
                        if c:IsA("TextButton") then
                            c.TextColor3 = c.Text:find(opt,1,true) and T.ACCENT or T.TEXT
                        end
                    end
                    Panel.Visible = false
                    if callback then pcall(callback, selected) end
                end)
            end

            local open = false
            ValBtn.MouseButton1Click:Connect(function()
                open = not open ; Panel.Visible = open
            end)

            return { Get = function() return selected end }
        end

        -- ── Multi-Select Dropdown ────────────────────────────
        -- callback receives a table of all currently selected values
        -- e.g. {"Cosmic", "Legendary"}  (empty table = nothing selected)
        function Tab:AddMultiDropdown(labelTxt, options, callback)
            Tab._count = Tab._count + 1
            local selected = {}   -- key = option string, value = true/false

            -- ── Header row (always visible) ──────────────────
            local Header = NewFrame(Scroll, UDim2.new(1,-6,0,40), nil, T.SURFACE)
            Header.LayoutOrder = Tab._count
            NewCorner(Header, 6) ; NewStroke(Header, T.BORDER)
            NewLabel(Header, labelTxt, 13, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.5,0,1,0))

            local ValBtn = Instance.new("TextButton")
            ValBtn.Size             = UDim2.new(0,140,0,28)
            ValBtn.Position         = UDim2.new(1,-148,0.5,-14)
            ValBtn.BackgroundColor3 = T.INPUT
            ValBtn.Font             = Enum.Font.Code
            ValBtn.TextSize         = 11
            ValBtn.TextColor3       = T.ACCENT
            ValBtn.Text             = "none v"
            ValBtn.BorderSizePixel  = 0
            ValBtn.AutoButtonColor  = false
            ValBtn.TextTruncate     = Enum.TextTruncate.AtEnd
            ValBtn.Parent           = Header
            NewCorner(ValBtn, 5) ; NewStroke(ValBtn, T.BORDER)

            -- ── Drop panel (rows = one option each) ──────────
            Tab._count = Tab._count + 1
            local Panel = NewFrame(Scroll, UDim2.new(1,-6,0, #options*34+8), nil, T.INPUT)
            Panel.LayoutOrder = Tab._count
            Panel.Visible     = false
            NewCorner(Panel, 6) ; NewStroke(Panel, T.ACCENT)
            NewPad(Panel, 4) ; NewList(Panel, 3)

            -- Helper: rebuild the summary text in ValBtn
            local function RefreshSummary()
                local parts = {}
                for _, opt in ipairs(options) do
                    if selected[opt] then table.insert(parts, opt) end
                end
                ValBtn.Text = (#parts == 0) and "none v"
                    or (#parts == 1) and (parts[1].." v")
                    or (#parts == #options) and ("all ("..#parts..") v")
                    or (#parts.." selected v")
            end

            -- Helper: fire callback with current selection list
            local function FireCB()
                local list = {}
                for _, opt in ipairs(options) do
                    if selected[opt] then table.insert(list, opt) end
                end
                if callback then pcall(callback, list) end
            end

            -- Build one row per option
            local rowObjs = {}   -- stores {row, chkBox, chkMark, lbl} per option
            for _, opt in ipairs(options) do
                local row = NewFrame(Panel, UDim2.new(1,0,0,28), nil, T.SURFACE)
                NewCorner(row, 4)

                -- Checkbox square on the right side
                local ChkBox  = NewFrame(row, UDim2.new(0,18,0,18), UDim2.new(1,-26,0.5,-9), T.INPUT)
                NewCorner(ChkBox, 3) ; NewStroke(ChkBox, T.BORDER)
                local ChkMark = NewLabel(ChkBox, "v", 12, T.WHITE, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0))
                ChkMark.TextXAlignment  = Enum.TextXAlignment.Center
                ChkMark.TextTransparency = 1

                local Lbl = NewLabel(row, "  "..opt, 12, T.TEXT, UDim2.new(0,0,0,0), UDim2.new(1,-30,1,0))
                Lbl.TextXAlignment = Enum.TextXAlignment.Left

                -- Hover effect on the row
                local HB = Instance.new("TextButton")
                HB.Size = UDim2.new(1,0,1,0) ; HB.BackgroundTransparency = 1 ; HB.Text = "" ; HB.Parent = row
                HB.MouseEnter:Connect(function() Tw(row, {BackgroundColor3 = Color3.fromRGB(25,35,50)}) end)
                HB.MouseLeave:Connect(function() Tw(row, {BackgroundColor3 = T.SURFACE}) end)

                HB.MouseButton1Click:Connect(function()
                    selected[opt] = not selected[opt]
                    local on = selected[opt]
                    Tw(ChkBox,  {BackgroundColor3 = on and T.ACCENT or T.INPUT})
                    Tw(ChkMark, {TextTransparency = on and 0 or 1})
                    Lbl.TextColor3 = on and T.ACCENT or T.TEXT
                    RefreshSummary()
                    FireCB()
                end)

                rowObjs[opt] = {row=row, box=ChkBox, mark=ChkMark, lbl=Lbl}
            end

            -- Toggle panel open/close
            local open = false
            ValBtn.MouseButton1Click:Connect(function()
                open = not open ; Panel.Visible = open
            end)

            return {
                -- Returns table of selected option strings
                Get = function()
                    local list = {}
                    for _, opt in ipairs(options) do
                        if selected[opt] then table.insert(list, opt) end
                    end
                    return list
                end,
                -- Programmatically set selection: pass table of strings
                Set = function(list)
                    selected = {}
                    for _, v in ipairs(list) do selected[v] = true end
                    for opt, objs in pairs(rowObjs) do
                        local on = selected[opt] == true
                        objs.box.BackgroundColor3 = on and T.ACCENT or T.INPUT
                        objs.mark.TextTransparency = on and 0 or 1
                        objs.lbl.TextColor3 = on and T.ACCENT or T.TEXT
                    end
                    RefreshSummary()
                end,
                -- Clear all selections
                Clear = function()
                    selected = {}
                    for _, objs in pairs(rowObjs) do
                        objs.box.BackgroundColor3 = T.INPUT
                        objs.mark.TextTransparency = 1
                        objs.lbl.TextColor3 = T.TEXT
                    end
                    RefreshSummary()
                end,
            }
        end

        -- ── Slider ──────────────────────────────────────────
        function Tab:AddSlider(labelTxt, min, max, default, callback)
            Tab._count = Tab._count + 1
            local val  = default or min

            -- Taller row on mobile so the track + thumb are easy to touch
            local rowH = _IS_MOBILE and 64 or 58
            local row = NewFrame(Scroll, UDim2.new(1,-6,0,rowH), nil, T.SURFACE)
            row.LayoutOrder = Tab._count
            NewCorner(row, 6) ; NewStroke(row, T.BORDER)

            local Top = NewFrame(row, UDim2.new(1,0,0,36), nil, Color3.new(0,0,0))
            Top.BackgroundTransparency = 1
            NewLabel(Top, labelTxt, _IS_MOBILE and 12 or 13, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.65,0,1,0))
            local ValLbl = NewLabel(Top, tostring(val), _IS_MOBILE and 12 or 13, T.ACCENT, UDim2.new(0.65,0,0,0), UDim2.new(0.35,-10,1,0))
            ValLbl.TextXAlignment = Enum.TextXAlignment.Right

            -- Track background — taller on mobile so finger can hit it easily
            local trackH  = _IS_MOBILE and 8 or 5
            local trackY  = _IS_MOBILE and 44 or 44
            local TBG = NewFrame(row, UDim2.new(1,-20,0,trackH), UDim2.new(0,10,0,trackY), T.INPUT)
            NewCorner(TBG, math.floor(trackH/2))
            local r0   = (val-min)/(max-min)
            local Fill = NewFrame(TBG, UDim2.new(r0,0,1,0), nil, T.ACCENT)
            NewCorner(Fill, math.floor(trackH/2))
            local thumbSz = _IS_MOBILE and 18 or 13
            local Thumb = NewFrame(TBG, UDim2.new(0,thumbSz,0,thumbSz),
                UDim2.new(r0, -math.floor(thumbSz/2), 0.5, -math.floor(thumbSz/2)), T.WHITE)
            NewCorner(Thumb, math.floor(thumbSz/2))

            local sliding = false

            local function Update(xPos)
                local rel = math.clamp((xPos - TBG.AbsolutePosition.X) / TBG.AbsoluteSize.X, 0, 1)
                val = math.round(min + (max - min) * rel)
                Fill.Size      = UDim2.new(rel, 0, 1, 0)
                Thumb.Position = UDim2.new(rel, -math.floor(thumbSz/2), 0.5, -math.floor(thumbSz/2))
                ValLbl.Text    = tostring(val)
                if callback then pcall(callback, val) end
            end

            -- Invisible hit area that covers full row width for easy touch
            local HitArea = Instance.new("TextButton")
            HitArea.Size                 = UDim2.new(1, -20, 0, _IS_MOBILE and 36 or 24)
            HitArea.Position             = UDim2.new(0, 10, 0, trackY - (_IS_MOBILE and 14 or 10))
            HitArea.BackgroundTransparency = 1
            HitArea.Text                 = ""
            HitArea.BorderSizePixel      = 0
            HitArea.ZIndex               = 5
            HitArea.Parent               = row

            -- Begin: mouse OR touch
            HitArea.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                    sliding = true
                    Update(i.Position.X)
                end
            end)

            -- Global move: mouse OR touch
            UserInputService.InputChanged:Connect(function(i)
                if not sliding then return end
                if i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch then
                    Update(i.Position.X)
                end
            end)

            -- End: mouse OR touch
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                    sliding = false
                end
            end)

            return {
                Get = function() return val end,
                Set = function(v)
                    val = math.clamp(v, min, max)
                    local r = (val - min) / (max - min)
                    Fill.Size      = UDim2.new(r, 0, 1, 0)
                    Thumb.Position = UDim2.new(r, -math.floor(thumbSz/2), 0.5, -math.floor(thumbSz/2))
                    ValLbl.Text    = tostring(val)
                end,
            }
        end

        -- ── Button ──────────────────────────────────────────
        function Tab:AddButton(labelTxt, callback, style)
            Tab._count  = Tab._count + 1
            local accent = (style == "accent")

            local Btn = Instance.new("TextButton")
            Btn.Size             = UDim2.new(1,-6,0,40)
            Btn.BackgroundColor3 = accent and T.ACCENT or T.SURFACE
            Btn.Font             = Enum.Font.Code
            Btn.TextSize         = 13
            Btn.TextColor3       = accent and T.BG or T.TEXT
            Btn.Text             = "[ " .. labelTxt .. " ]"
            Btn.BorderSizePixel  = 0
            Btn.AutoButtonColor  = false
            Btn.LayoutOrder      = Tab._count
            Btn.Parent           = Scroll
            NewCorner(Btn, 6) ; NewStroke(Btn, accent and T.ACCENT or T.BORDER)

            Btn.MouseEnter:Connect(function()
                Tw(Btn, {BackgroundColor3 = accent and Color3.fromRGB(0,180,100) or Color3.fromRGB(25,35,50)})
            end)
            Btn.MouseLeave:Connect(function()
                Tw(Btn, {BackgroundColor3 = accent and T.ACCENT or T.SURFACE})
            end)
            Btn.MouseButton1Click:Connect(function()
                Tw(Btn, {BackgroundColor3 = T.ACCENT2}, 0.08)
                task.delay(0.12, function() Tw(Btn, {BackgroundColor3 = accent and T.ACCENT or T.SURFACE}) end)
                if callback then pcall(callback) end
            end)
        end

        -- ── Text Input ──────────────────────────────────────
        function Tab:AddTextInput(labelTxt, placeholder, callback)
            Tab._count = Tab._count + 1
            local row  = NewFrame(Scroll, UDim2.new(1,-6,0,58), nil, T.SURFACE)
            row.LayoutOrder = Tab._count
            NewCorner(row, 6) ; NewStroke(row, T.BORDER)

            NewLabel(row, labelTxt, 11, T.DIM, UDim2.new(0,10,0,4), UDim2.new(1,-10,0,16))

            local IBox = Instance.new("TextBox")
            IBox.Size              = UDim2.new(1,-20,0,26)
            IBox.Position          = UDim2.new(0,10,0,24)
            IBox.BackgroundColor3  = T.INPUT
            IBox.Font              = Enum.Font.Code
            IBox.TextSize          = 12
            IBox.TextColor3        = T.ACCENT
            IBox.PlaceholderText   = placeholder or "type here..."
            IBox.PlaceholderColor3 = T.DIM
            IBox.Text              = ""
            IBox.BorderSizePixel   = 0
            IBox.ClearTextOnFocus  = false
            IBox.Parent            = row
            NewCorner(IBox, 4) ; NewStroke(IBox, T.BORDER)

            local p = Instance.new("UIPadding") ; p.PaddingLeft = UDim.new(0,8) ; p.Parent = IBox
            IBox.FocusLost:Connect(function(enter)
                if enter and callback then pcall(callback, IBox.Text) end
            end)

            return { Get = function() return IBox.Text end, Set = function(t) IBox.Text = t end }
        end

        -- Alias: AddTextbox -> AddTextInput (convenience)
        Tab.AddTextbox = Tab.AddTextInput

        -- ── FPS Monitor ─────────────────────────────────────
        function Tab:AddShowFPS()
            local row = MakeRow("  FPS MONITOR")
            row.BackgroundColor3 = Color3.fromRGB(10,20,14)
            NewStroke(row, T.ACCENT)

            local FVal = NewLabel(row, "--", 17, T.ACCENT, UDim2.new(0.55,0,0,0), UDim2.new(0.28,0,1,0))
            FVal.TextXAlignment = Enum.TextXAlignment.Right
            NewLabel(row, " fps", 11, T.DIM, UDim2.new(0.83,0,0,0), UDim2.new(0.15,0,1,0))

            local fc, el = 0, 0
            local conn = RunService.Heartbeat:Connect(function(dt)
                fc = fc + 1 ; el = el + dt
                if el >= 0.5 then
                    local fps = math.round(fc / el)
                    FVal.Text       = tostring(fps)
                    FVal.TextColor3 = fps >= 55 and Color3.fromRGB(0,210,120)
                        or fps >= 30 and Color3.fromRGB(255,200,0)
                        or Color3.fromRGB(220,60,60)
                    fc = 0 ; el = 0
                end
            end)
            ScreenGui.AncestryChanged:Connect(function()
                if not ScreenGui.Parent then conn:Disconnect() end
            end)
        end

        -- ── Separator ───────────────────────────────────────
        function Tab:AddSeparator(labelTxt)
            Tab._count = Tab._count + 1
            local sep = NewFrame(Scroll, UDim2.new(1,-6,0,22), nil, Color3.new(0,0,0))
            sep.BackgroundTransparency = 1
            sep.LayoutOrder = Tab._count
            NewFrame(sep, UDim2.new(labelTxt and 0.44 or 1, 0, 0, 1), UDim2.new(0,0,0.5,0), T.BORDER)
            if labelTxt then
                local sl = NewLabel(sep, labelTxt, 10, T.DIM, UDim2.new(0.5,-45,0,0), UDim2.new(0,90,1,0))
                sl.TextXAlignment = Enum.TextXAlignment.Center
                NewFrame(sep, UDim2.new(0.44,0,0,1), UDim2.new(0.56,0,0.5,0), T.BORDER)
            end
        end

        -- ── Category (collapsible section) ──────────────────
        -- Works like SpeedHub: a header button you tap/click to
        -- expand or collapse all items inside it.
        --
        -- Usage:
        --   local Cat = Tab:AddCategory("AUTO HARVEST")
        --   Cat:AddToggle(...)
        --   Cat:AddButton(...)
        --   -- Cat supports all the same methods as Tab
        function Tab:AddCategory(labelTxt, startOpen)
            Tab._count = Tab._count + 1

            -- ── Header button ────────────────────────────────
            local headerH = _IS_MOBILE and 38 or 34
            local Header = Instance.new("TextButton")
            Header.Size             = UDim2.new(1,-6,0,headerH)
            Header.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
            Header.Font             = Enum.Font.Code
            Header.TextSize         = _IS_MOBILE and 12 or 12
            Header.TextColor3       = T.ACCENT
            Header.Text             = ""
            Header.BorderSizePixel  = 0
            Header.AutoButtonColor  = false
            Header.LayoutOrder      = Tab._count
            Header.Parent           = Scroll
            NewCorner(Header, 6)
            NewStroke(Header, T.ACCENT, 1.2)

            -- Left accent bar
            local AccBar = NewFrame(Header, UDim2.new(0,3,0,headerH-10), UDim2.new(0,8,0.5,-(headerH-10)/2), T.ACCENT)
            NewCorner(AccBar, 2)

            -- Label
            local HLbl = NewLabel(Header, "  " .. (labelTxt or "CATEGORY"), _IS_MOBILE and 12 or 12,
                T.ACCENT, UDim2.new(0,16,0,0), UDim2.new(1,-50,1,0))
            HLbl.Font = Enum.Font.Code

            -- Arrow indicator  ▼ / ▶
            local Arrow = NewLabel(Header, "▼", _IS_MOBILE and 12 or 11,
                T.DIM, UDim2.new(1,-28,0,0), UDim2.new(0,22,1,0))
            Arrow.TextXAlignment = Enum.TextXAlignment.Center

            -- ── Container frame for child items ─────────────
            -- Height starts at 0 (collapsed) or auto (open)
            Tab._count = Tab._count + 1
            local Container = NewFrame(Scroll, UDim2.new(1,-6,0,0), nil, Color3.new(0,0,0))
            Container.BackgroundTransparency = 1
            Container.ClipsDescendants       = true
            Container.LayoutOrder            = Tab._count
            Container.Parent                 = Scroll  -- already set via NewFrame parent arg

            local CList = NewList(Container, 4)
            local CPad  = Instance.new("UIPadding")
            CPad.PaddingLeft   = UDim.new(0,10)
            CPad.PaddingRight  = UDim.new(0,0)
            CPad.PaddingTop    = UDim.new(0,4)
            CPad.PaddingBottom = UDim.new(0,4)
            CPad.Parent        = Container

            -- Track open/closed state and content height
            local isOpen       = (startOpen == true)
            local contentH     = 0

            -- Recompute container height when children change
            CList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                contentH = CList.AbsoluteContentSize.Y + 8
                if isOpen then
                    Container.Size = UDim2.new(1,-6,0, contentH)
                end
            end)

            local function SetOpen(open)
                isOpen = open
                Arrow.Text      = open and "▼" or "▶"
                Arrow.TextColor3 = open and T.ACCENT or T.DIM
                Tw(Container, {Size = UDim2.new(1,-6,0, open and contentH or 0)}, 0.18)
            end

            -- Start in correct state without animation
            if isOpen then
                Container.Size = UDim2.new(1,-6,0, contentH)
            end

            Header.MouseButton1Click:Connect(function()
                SetOpen(not isOpen)
            end)

            -- ── Category object — mirrors Tab API ────────────
            local Cat = {_count = 0}

            -- MakeRow for category children (narrower due to left padding)
            local function CatRow(txt, h)
                Cat._count = Cat._count + 1
                local rowH = h or (_IS_MOBILE and 40 or 38)
                local row = NewFrame(Container, UDim2.new(1,0,0,rowH), nil, Color3.fromRGB(20,25,38))
                row.LayoutOrder = Cat._count
                NewCorner(row, 5)
                NewStroke(row, Color3.fromRGB(35,45,65))
                local lbl = NewLabel(row, txt, _IS_MOBILE and 12 or 12, T.TEXT,
                    UDim2.new(0,10,0,0), UDim2.new(0.6,-10,1,0))
                return row, lbl
            end

            -- ── Mirror all Tab methods onto Cat ─────────────
            function Cat:AddToggle(labelTxt, default, callback)
                local row   = CatRow(labelTxt)
                local state = (default == true)
                local Track = NewFrame(row, UDim2.new(0,44,0,22), UDim2.new(1,-54,0.5,-11), state and T.TOG_ON or T.TOG_OFF)
                NewCorner(Track, 11)
                local Knob = NewFrame(Track, UDim2.new(0,18,0,18), state and UDim2.new(0,24,0.5,-9) or UDim2.new(0,2,0.5,-9), T.WHITE)
                NewCorner(Knob, 9)
                local HB = Instance.new("TextButton")
                HB.Size = UDim2.new(1,0,1,0) ; HB.BackgroundTransparency = 1 ; HB.Text = "" ; HB.Parent = row
                HB.MouseButton1Click:Connect(function()
                    state = not state
                    Tw(Track, {BackgroundColor3 = state and T.TOG_ON or T.TOG_OFF})
                    Tw(Knob,  {Position = state and UDim2.new(0,24,0.5,-9) or UDim2.new(0,2,0.5,-9)})
                    if callback then pcall(callback, state) end
                end)
                return { Get = function() return state end,
                    Set = function(v) state = v ; Track.BackgroundColor3 = v and T.TOG_ON or T.TOG_OFF
                        Knob.Position = v and UDim2.new(0,24,0.5,-9) or UDim2.new(0,2,0.5,-9) end }
            end

            function Cat:AddButton(labelTxt, callback, style)
                Cat._count = Cat._count + 1
                local accent = (style == "accent")
                local Btn = Instance.new("TextButton")
                Btn.Size             = UDim2.new(1,0,0, _IS_MOBILE and 38 or 36)
                Btn.BackgroundColor3 = accent and T.ACCENT or Color3.fromRGB(20,25,38)
                Btn.Font             = Enum.Font.Code
                Btn.TextSize         = _IS_MOBILE and 12 or 12
                Btn.TextColor3       = accent and T.BG or T.TEXT
                Btn.Text             = labelTxt
                Btn.BorderSizePixel  = 0
                Btn.AutoButtonColor  = false
                Btn.LayoutOrder      = Cat._count
                Btn.Parent           = Container
                NewCorner(Btn, 5)
                NewStroke(Btn, accent and T.ACCENT or Color3.fromRGB(35,45,65))
                Btn.MouseButton1Click:Connect(function()
                    Tw(Btn, {BackgroundColor3 = T.ACCENT2}, 0.08)
                    task.delay(0.12, function() Tw(Btn, {BackgroundColor3 = accent and T.ACCENT or Color3.fromRGB(20,25,38)}) end)
                    if callback then pcall(callback) end
                end)
            end

            function Cat:AddSlider(labelTxt, min, max, default, callback)
                local val  = default or min
                local rowH = _IS_MOBILE and 64 or 58
                local row = NewFrame(Container, UDim2.new(1,0,0,rowH), nil, Color3.fromRGB(20,25,38))
                Cat._count = Cat._count + 1
                row.LayoutOrder = Cat._count
                NewCorner(row, 5) ; NewStroke(row, Color3.fromRGB(35,45,65))

                local Top = NewFrame(row, UDim2.new(1,0,0,36), nil, Color3.new(0,0,0))
                Top.BackgroundTransparency = 1
                NewLabel(Top, labelTxt, _IS_MOBILE and 12 or 12, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.65,0,1,0))
                local ValLbl = NewLabel(Top, tostring(val), _IS_MOBILE and 12 or 12, T.ACCENT, UDim2.new(0.65,0,0,0), UDim2.new(0.35,-10,1,0))
                ValLbl.TextXAlignment = Enum.TextXAlignment.Right

                local trackH = _IS_MOBILE and 8 or 5
                local trackY = 44
                local TBG = NewFrame(row, UDim2.new(1,-20,0,trackH), UDim2.new(0,10,0,trackY), T.INPUT)
                NewCorner(TBG, math.floor(trackH/2))
                local r0   = (val-min)/(max-min)
                local Fill = NewFrame(TBG, UDim2.new(r0,0,1,0), nil, T.ACCENT) ; NewCorner(Fill, math.floor(trackH/2))
                local thumbSz = _IS_MOBILE and 18 or 13
                local Thumb = NewFrame(TBG, UDim2.new(0,thumbSz,0,thumbSz),
                    UDim2.new(r0,-math.floor(thumbSz/2),0.5,-math.floor(thumbSz/2)), T.WHITE)
                NewCorner(Thumb, math.floor(thumbSz/2))

                local sliding = false
                local function Update(xPos)
                    local rel = math.clamp((xPos - TBG.AbsolutePosition.X) / TBG.AbsoluteSize.X, 0, 1)
                    val = math.round(min + (max-min)*rel)
                    Fill.Size      = UDim2.new(rel,0,1,0)
                    Thumb.Position = UDim2.new(rel,-math.floor(thumbSz/2),0.5,-math.floor(thumbSz/2))
                    ValLbl.Text    = tostring(val)
                    if callback then pcall(callback, val) end
                end

                local HitArea = Instance.new("TextButton")
                HitArea.Size = UDim2.new(1,-20,0,_IS_MOBILE and 36 or 24)
                HitArea.Position = UDim2.new(0,10,0,trackY-(_IS_MOBILE and 14 or 10))
                HitArea.BackgroundTransparency = 1 ; HitArea.Text = "" ; HitArea.BorderSizePixel = 0
                HitArea.ZIndex = 5 ; HitArea.Parent = row
                HitArea.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        sliding = true ; Update(i.Position.X)
                    end
                end)
                UserInputService.InputChanged:Connect(function(i)
                    if not sliding then return end
                    if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                        Update(i.Position.X)
                    end
                end)
                UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)
                return { Get = function() return val end,
                    Set = function(v)
                        val = math.clamp(v,min,max) ; local r=(val-min)/(max-min)
                        Fill.Size=UDim2.new(r,0,1,0) ; Thumb.Position=UDim2.new(r,-math.floor(thumbSz/2),0.5,-math.floor(thumbSz/2))
                        ValLbl.Text=tostring(val)
                    end }
            end

            function Cat:AddDropdown(labelTxt, options, callback)
                local selected = options[1] or ""
                local Header2 = NewFrame(Container, UDim2.new(1,0,0,_IS_MOBILE and 42 or 38), nil, Color3.fromRGB(20,25,38))
                Cat._count = Cat._count + 1 ; Header2.LayoutOrder = Cat._count
                NewCorner(Header2, 5) ; NewStroke(Header2, Color3.fromRGB(35,45,65))
                NewLabel(Header2, labelTxt, _IS_MOBILE and 12 or 12, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.5,0,1,0))
                local ValBtn = Instance.new("TextButton")
                ValBtn.Size=UDim2.new(0,130,0,26) ; ValBtn.Position=UDim2.new(1,-138,0.5,-13)
                ValBtn.BackgroundColor3=T.INPUT ; ValBtn.Font=Enum.Font.Code ; ValBtn.TextSize=11
                ValBtn.TextColor3=T.ACCENT ; ValBtn.Text=selected.." v" ; ValBtn.BorderSizePixel=0
                ValBtn.AutoButtonColor=false ; ValBtn.Parent=Header2 ; NewCorner(ValBtn,5) ; NewStroke(ValBtn,T.BORDER)
                Cat._count = Cat._count + 1
                local Panel = NewFrame(Container, UDim2.new(1,0,0,#options*30+8), nil, T.INPUT)
                Panel.LayoutOrder = Cat._count ; Panel.Visible = false
                NewCorner(Panel,5) ; NewStroke(Panel,T.ACCENT) ; NewPad(Panel,4) ; NewList(Panel,3)
                for _, opt in ipairs(options) do
                    local OBtn = Instance.new("TextButton")
                    OBtn.Size=UDim2.new(1,0,0,26) ; OBtn.BackgroundColor3=T.SURFACE ; OBtn.Font=Enum.Font.Code
                    OBtn.TextSize=11 ; OBtn.TextColor3=(opt==selected) and T.ACCENT or T.TEXT
                    OBtn.Text="  "..opt ; OBtn.TextXAlignment=Enum.TextXAlignment.Left
                    OBtn.BorderSizePixel=0 ; OBtn.AutoButtonColor=false ; OBtn.Parent=Panel ; NewCorner(OBtn,4)
                    OBtn.MouseButton1Click:Connect(function()
                        selected=opt ; ValBtn.Text=opt.." v" ; Panel.Visible=false
                        if callback then pcall(callback,selected) end
                    end)
                end
                local open=false
                ValBtn.MouseButton1Click:Connect(function() open=not open ; Panel.Visible=open end)
                return { Get = function() return selected end }
            end

            function Cat:AddMultiDropdown(labelTxt, options, callback)
                local selected = {}

                local Header2 = NewFrame(Container, UDim2.new(1,0,0,_IS_MOBILE and 42 or 38), nil, Color3.fromRGB(20,25,38))
                Cat._count = Cat._count + 1 ; Header2.LayoutOrder = Cat._count
                NewCorner(Header2, 5) ; NewStroke(Header2, Color3.fromRGB(35,45,65))
                NewLabel(Header2, labelTxt, _IS_MOBILE and 12 or 12, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.5,0,1,0))

                local ValBtn = Instance.new("TextButton")
                ValBtn.Size=UDim2.new(0,130,0,26) ; ValBtn.Position=UDim2.new(1,-138,0.5,-13)
                ValBtn.BackgroundColor3=T.INPUT ; ValBtn.Font=Enum.Font.Code ; ValBtn.TextSize=10
                ValBtn.TextColor3=T.ACCENT ; ValBtn.Text="none v" ; ValBtn.BorderSizePixel=0
                ValBtn.AutoButtonColor=false ; ValBtn.TextTruncate=Enum.TextTruncate.AtEnd
                ValBtn.Parent=Header2 ; NewCorner(ValBtn,5) ; NewStroke(ValBtn,T.BORDER)

                Cat._count = Cat._count + 1
                local Panel = NewFrame(Container, UDim2.new(1,0,0,#options*30+8), nil, T.INPUT)
                Panel.LayoutOrder = Cat._count ; Panel.Visible = false
                NewCorner(Panel,5) ; NewStroke(Panel,T.ACCENT) ; NewPad(Panel,4) ; NewList(Panel,3)

                local rowObjs = {}
                local function RefreshSummary()
                    local list = {}
                    for _, opt in ipairs(options) do if selected[opt] then table.insert(list, opt) end end
                    ValBtn.Text = (#list == 0) and "none v" or (table.concat(list,", ").." v")
                    if callback then pcall(callback, list) end
                end

                for _, opt in ipairs(options) do
                    local ORow = Instance.new("TextButton")
                    ORow.Size=UDim2.new(1,0,0,26) ; ORow.BackgroundColor3=T.SURFACE ; ORow.Font=Enum.Font.Code
                    ORow.TextSize=11 ; ORow.TextColor3=T.TEXT ; ORow.Text="  "..opt
                    ORow.TextXAlignment=Enum.TextXAlignment.Left ; ORow.BorderSizePixel=0
                    ORow.AutoButtonColor=false ; ORow.Parent=Panel ; NewCorner(ORow,4)
                    local chk = NewLabel(ORow,"",11,T.ACCENT,UDim2.new(1,-20,0,0),UDim2.new(0,18,1,0))
                    chk.TextXAlignment=Enum.TextXAlignment.Center
                    rowObjs[opt] = {btn=ORow, chk=chk}
                    ORow.MouseButton1Click:Connect(function()
                        selected[opt] = not selected[opt]
                        chk.Text = selected[opt] and "✓" or ""
                        ORow.TextColor3 = selected[opt] and T.ACCENT or T.TEXT
                        RefreshSummary()
                    end)
                end

                local open2 = false
                ValBtn.MouseButton1Click:Connect(function() open2=not open2 ; Panel.Visible=open2 end)

                return {
                    Get = function()
                        local list={}
                        for _,opt in ipairs(options) do if selected[opt] then table.insert(list,opt) end end
                        return list
                    end,
                    Set = function(list)
                        selected={}
                        for _,v in ipairs(list) do selected[v]=true end
                        for opt,objs in pairs(rowObjs) do
                            objs.chk.Text = selected[opt] and "✓" or ""
                            objs.btn.TextColor3 = selected[opt] and T.ACCENT or T.TEXT
                        end
                        RefreshSummary()
                    end,
                }
            end

            function Cat:AddLabel(text, color)
                local row, lbl = CatRow(text)
                lbl.TextColor3 = color or T.DIM
                lbl.Size = UDim2.new(1,-10,1,0)
                lbl.Text = text
                return { Set = function(t) lbl.Text=t end, SetColor = function(c) lbl.TextColor3=c end }
            end

            function Cat:AddTextInput(labelTxt, placeholder, callback)
                Cat._count = Cat._count + 1
                local row = NewFrame(Container, UDim2.new(1,0,0,58), nil, Color3.fromRGB(20,25,38))
                row.LayoutOrder = Cat._count ; NewCorner(row,5) ; NewStroke(row, Color3.fromRGB(35,45,65))
                NewLabel(row, labelTxt, 11, T.DIM, UDim2.new(0,10,0,4), UDim2.new(1,-10,0,16))
                local IBox = Instance.new("TextBox")
                IBox.Size=UDim2.new(1,-20,0,26) ; IBox.Position=UDim2.new(0,10,0,24)
                IBox.BackgroundColor3=T.INPUT ; IBox.Font=Enum.Font.Code ; IBox.TextSize=12
                IBox.TextColor3=T.ACCENT ; IBox.PlaceholderText=placeholder or "type here..."
                IBox.PlaceholderColor3=T.DIM ; IBox.Text="" ; IBox.BorderSizePixel=0
                IBox.ClearTextOnFocus=false ; IBox.Parent=row ; NewCorner(IBox,4) ; NewStroke(IBox,T.BORDER)
                local p=Instance.new("UIPadding") ; p.PaddingLeft=UDim.new(0,8) ; p.Parent=IBox
                IBox.FocusLost:Connect(function(enter) if enter and callback then pcall(callback,IBox.Text) end end)
                return { Get=function() return IBox.Text end, Set=function(t) IBox.Text=t end }
            end
            Cat.AddTextbox = Cat.AddTextInput

            function Cat:AddCheckbox(labelTxt, default, callback)
                local row, _ = CatRow(labelTxt)
                local state = (default == true)
                local Box = NewFrame(row, UDim2.new(0,22,0,22), UDim2.new(1,-36,0.5,-11), state and T.ACCENT or T.INPUT)
                NewCorner(Box,4) ; NewStroke(Box, state and T.ACCENT or T.BORDER)
                local Chk = NewLabel(Box,"v",14,T.WHITE,UDim2.new(0,0,0,0),UDim2.new(1,0,1,0))
                Chk.TextXAlignment=Enum.TextXAlignment.Center ; Chk.TextTransparency = state and 0 or 1
                local HB = Instance.new("TextButton")
                HB.Size=UDim2.new(1,0,1,0) ; HB.BackgroundTransparency=1 ; HB.Text="" ; HB.Parent=row
                HB.MouseButton1Click:Connect(function()
                    state=not state ; Box.BackgroundColor3=state and T.ACCENT or T.INPUT
                    NewStroke(Box, state and T.ACCENT or T.BORDER) ; Chk.TextTransparency=state and 0 or 1
                    if callback then pcall(callback,state) end
                end)
                return { Get=function() return state end }
            end

            function Cat:AddSeparator(labelTxt)
                Cat._count = Cat._count + 1
                local sep = NewFrame(Container, UDim2.new(1,0,0,18), nil, Color3.new(0,0,0))
                sep.BackgroundTransparency = 1 ; sep.LayoutOrder = Cat._count
                NewFrame(sep, UDim2.new(labelTxt and 0.4 or 1,0,0,1), UDim2.new(0,0,0.5,0), T.BORDER)
                if labelTxt then
                    local sl = NewLabel(sep, labelTxt, 9, T.DIM, UDim2.new(0.5,-40,0,0), UDim2.new(0,80,1,0))
                    sl.TextXAlignment = Enum.TextXAlignment.Center
                    NewFrame(sep, UDim2.new(0.4,0,0,1), UDim2.new(0.6,0,0.5,0), T.BORDER)
                end
            end

            return Cat
        end -- AddCategory

        -- ── Label ───────────────────────────────────────────
        function Tab:AddLabel(text, color)
            local row, lbl = MakeRow(text)
            lbl.TextColor3 = color or T.DIM
            lbl.Size       = UDim2.new(1,-10,1,0)
            lbl.Text       = text
            return {
                Set      = function(t) lbl.Text = t end,
                SetColor = function(c) lbl.TextColor3 = c end,
            }
        end

        return Tab
    end -- AddTab

    return Window
end -- _CreateWindowInternal

-- ============================================================
-- PHCzack:CreateWindow(config)
--
-- THE MAIN ENTRY POINT — **key system is built-in**.
-- Every call to CreateWindow() shows the key gate FIRST.
-- After the user validates their key, the window loads.
--
-- To SKIP the key check (e.g. for free scripts), pass:
--   config.KeyRequired = false
--
-- Optional config fields:
--   config.ApiUrl     — override KEY_CONFIG.API_URL
--   config.ApiSecret  — override KEY_CONFIG.API_SECRET
--   config.OnKeyValidated = function(key, data) end
-- ============================================================
function PHCzack:CreateWindow(config)
    config = config or {}
    local keyRequired = (config.KeyRequired ~= false) -- default: true

    -- If key check is disabled, go straight to window
    if not keyRequired then
        return self:_CreateWindowInternal(config)
    end

    -- Apply overrides before showing the gate
    if config.ApiUrl then KEY_CONFIG.API_URL = config.ApiUrl end
    if config.ApiSecret then KEY_CONFIG.API_SECRET = config.ApiSecret end

    -- Fetch providers early to check no_key_mode & weekend_free flags
    pcall(function() KeySystem.FetchProviders() end)

    -- No-key-mode bypass: admin toggled "No Key Mode" ON — skip gate entirely
    if KEY_CONFIG._no_key_mode == true then
        local win = self:_CreateWindowInternal(config)
        if config.OnKeyValidated then
            pcall(config.OnKeyValidated, "NO_KEY_MODE", {no_key = true})
        end
        win:Show()
        return win
    end

    -- Weekend-free bypass: skip key gate entirely on Sat/Sun when enabled
    if KEY_CONFIG._weekend_free == true then
        local win = self:_CreateWindowInternal(config)
        if config.OnKeyValidated then
            pcall(config.OnKeyValidated, "WEEKEND_FREE", {weekend = true})
        end
        win:Show()
        return win
    end

    -- If already validated this session, skip the gate
    if _keyValidatedThisSession and _validatedKey then
        local win = self:_CreateWindowInternal(config)

        if config.OnKeyValidated then
            pcall(config.OnKeyValidated, _validatedKey, _validatedKeyData)
        end

        win:Show()
        return win
    end

    -- Show the key gate, then create window on success
    local windowRef = nil
    local gateDone  = false

    KeySystem.ShowGate(function(key, data)
        _keyValidatedThisSession = true
        _validatedKey = key
        _validatedKeyData = data

        -- Key validated — build the actual window
        windowRef = self:_CreateWindowInternal(config)

        if config.OnKeyValidated then
            pcall(config.OnKeyValidated, key, data)
        end

        windowRef:Show()
        gateDone = true
    end)

    -- YIELD: wait here until the key gate finishes.
    -- task.wait() yields the coroutine so the UI stays responsive.
    -- Once the user validates their key, gateDone becomes true and
    -- we return the REAL window object — so AddTab/AddToggle etc.
    -- all work correctly in the calling script.
    while not gateDone do
        task.wait(0.1)
    end

    return windowRef
end

-- CreateWindowWithKey is now just an alias (kept for backward compat)
PHCzack.CreateWindowWithKey = PHCzack.CreateWindow

-- ============================================================
-- THIS LINE IS CRITICAL FOR loadstring() TO WORK
-- It returns the library table back to the caller
-- ============================================================
return PHCzack