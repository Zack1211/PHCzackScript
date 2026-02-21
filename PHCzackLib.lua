-- // PHCzack UI Library v2.0
-- // GitHub raw link usage:
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
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

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

local W, H = 460, 520

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
    local drag, inp, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            start = i.Position
            startPos = frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    drag = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement then
            inp = i
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i == inp then
            local d = i.Position - start
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
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
-- LIBRARY TABLE  <-- this is what gets returned to the caller
-- ============================================================
local PHCzack = {}

-- ============================================================
-- PHCzack:CreateWindow(config)
-- ============================================================
function PHCzack:CreateWindow(config)
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
    local Main = NewFrame(ScreenGui, UDim2.new(0,W,0,0), UDim2.new(0.5,-W/2,0.5,-H/2), T.BG)
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

    NewLabel(TitleBar, "  PHCzack // "..subtitle, 14, T.WHITE, UDim2.new(0,72,0,0), UDim2.new(1,-168,1,0))

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
    NewLabel(StatusBar, "[SYS] CONNECTED  |  SESSION: "..sess, 11, T.ACCENT, UDim2.new(0,22,0,0), UDim2.new(1,-22,1,0))

    -- ── Tab Bar ─────────────────────────────────────────────
    local TabBar = NewFrame(Main, UDim2.new(1,0,0,32), UDim2.new(0,0,0,68), T.BG)
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
    local CY = 68 + 32 + 6
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
        Btn.TextSize         = 12
        Btn.TextColor3       = T.DIM
        Btn.Text             = name
        Btn.BorderSizePixel  = 0
        Btn.AutoButtonColor  = false
        Btn.Parent           = TabBar
        NewCorner(Btn, 5)
        NewStroke(Btn, T.BORDER)

        local Scroll = Instance.new("ScrollingFrame")
        Scroll.Size                  = UDim2.new(1,0,1,0)
        Scroll.BackgroundTransparency= 1
        Scroll.BorderSizePixel       = 0
        Scroll.ScrollBarThickness    = 3
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
            local row = NewFrame(Scroll, UDim2.new(1,-6,0,h or 40), nil, T.SURFACE)
            row.LayoutOrder = Tab._count
            NewCorner(row, 6) ; NewStroke(row, T.BORDER)
            local lbl = NewLabel(row, labelTxt, 13, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.6,-10,1,0))
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

            local row = NewFrame(Scroll, UDim2.new(1,-6,0,58), nil, T.SURFACE)
            row.LayoutOrder = Tab._count
            NewCorner(row, 6) ; NewStroke(row, T.BORDER)

            local Top = NewFrame(row, UDim2.new(1,0,0,40), nil, Color3.new(0,0,0))
            Top.BackgroundTransparency = 1
            NewLabel(Top, labelTxt, 13, T.TEXT, UDim2.new(0,10,0,0), UDim2.new(0.65,0,1,0))
            local ValLbl = NewLabel(Top, tostring(val), 13, T.ACCENT, UDim2.new(0.65,0,0,0), UDim2.new(0.35,-10,1,0))
            ValLbl.TextXAlignment = Enum.TextXAlignment.Right

            local TBG = NewFrame(row, UDim2.new(1,-20,0,5), UDim2.new(0,10,0,46), T.INPUT)
            NewCorner(TBG, 3)
            local r0   = (val-min)/(max-min)
            local Fill = NewFrame(TBG, UDim2.new(r0,0,1,0), nil, T.ACCENT) ; NewCorner(Fill, 3)
            local Thumb= NewFrame(TBG, UDim2.new(0,13,0,13), UDim2.new(r0,-6,0.5,-6), T.WHITE) ; NewCorner(Thumb, 7)

            local sliding = false
            local function Update(xPos)
                local r = math.clamp((xPos - TBG.AbsolutePosition.X) / TBG.AbsoluteSize.X, 0, 1)
                val = math.round(min + (max-min)*r)
                Fill.Size      = UDim2.new(r, 0, 1, 0)
                Thumb.Position = UDim2.new(r, -6, 0.5, -6)
                ValLbl.Text    = tostring(val)
                if callback then pcall(callback, val) end
            end

            TBG.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = true ; Update(i.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
                    Update(i.Position.X)
                end
            end)

            return {
                Get = function() return val end,
                Set = function(v)
                    val = math.clamp(v, min, max)
                    local r = (val-min)/(max-min)
                    Fill.Size      = UDim2.new(r,0,1,0)
                    Thumb.Position = UDim2.new(r,-6,0.5,-6)
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
end -- CreateWindow

-- ============================================================
-- THIS LINE IS CRITICAL FOR loadstring() TO WORK
-- It returns the library table back to the caller
-- ============================================================
return PHCzack
