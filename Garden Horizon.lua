-- ============================================================
--  PHCzack // Garden Horizon  |  Full Feature Script v3
--  Press RightShift to toggle UI
-- ============================================================
local PHCzack = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Zack1211/PHCzackScript/refs/heads/main/PHCzackLib.lua"
))()

-- ============================================================
--  SERVICES
-- ============================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP                = Players.LocalPlayer

-- ============================================================
--  POSITION CONSTANTS  (defined early so all functions can use them)
-- ============================================================
local SELL_STAND_CF  = CFrame.new(149.7, 204.0, 669.8)
local SEED_SHOP_CF   = CFrame.new(177.1, 204.0, 670.9)
local GEAR_SHOP_CF   = CFrame.new(209.9, 204.0, 607.7)
local QUEST_BOARD_CF = CFrame.new(114.1, 204.0, 635.5)
local GARDEN_CENTER_CF = CFrame.new(0, 204.0, 800)

-- ============================================================
--  DATA TABLES
-- ============================================================
local SEED_RARITY = {
    Common    = {"Carrot Seed", "Corn Seed"},
    Uncommon  = {"Onion Seed", "Strawberry Seed", "Mushroom Seed"},
    Rare      = {"Beetroot Seed", "Tomato Seed", "Apple Seed", "Rose Seed"},
    Epic      = {"Wheat Seed", "Banana Seed", "Plum Seed", "Potato Seed"},
    Legendary = {"Cabbage Seed", "Cherry Seed", "Bamboo Seed", "Mango Seed"},
}
local GEAR_RARITY = {
    Common    = {"Watering Can", "Trowel"},
    Uncommon  = {"Basic Sprinkler"},
    Rare      = {"Harvest Bell"},
    Epic      = {"Turbo Sprinkler", "Favorite Tool"},
    Legendary = {"Super Sprinkler"},
}
local RARITY_ORDER = {"Common","Uncommon","Rare","Epic","Legendary"}

local SEED_LIST = {}
for _, r in ipairs(RARITY_ORDER) do
    for _, s in ipairs(SEED_RARITY[r]) do table.insert(SEED_LIST, s) end
end
local GEAR_LIST = {}
for _, r in ipairs(RARITY_ORDER) do
    for _, g in ipairs(GEAR_RARITY[r]) do table.insert(GEAR_LIST, g) end
end

-- Mutations with their multipliers (nil = unknown/variable)
local MUTATION_MULT = {
    Snowy      = 2.0,
    Frostbit   = 3.5,
    Chilled    = 1.5,
    Soaked     = 1.2,
    Flooded    = 1.75,
    Galactic   = nil,
    Electric   = nil,
    Foggy      = 1.25,
    Shocked    = 4.5,
    Starstruck = 6.5,
    Sandy      = 2.5,
    Mossy      = nil,
    Muddy      = nil,
}
local MUTATION_LIST = {
    "Snowy","Frostbit","Chilled","Soaked","Flooded",
    "Galactic","Electric","Foggy","Shocked","Starstruck",
    "Sandy","Mossy","Muddy"
}

-- Ripeness/Variant stages with multipliers
local VARIANT_MULT = {
    Unripe  = 0.5,
    Ripe    = 1.0,
    Overripe= 0.8,
    Lush    = 3.0,
    Gold    = 5.0,
    Silver  = 2.0,
}
local VARIANT_LIST = {"Unripe","Ripe","Overripe","Lush","Gold","Silver"}

-- Rarity colors for ESP labels
local MUTATION_COLOR = {
    Snowy      = Color3.fromRGB(200,230,255),
    Frostbit   = Color3.fromRGB(100,180,255),
    Chilled    = Color3.fromRGB(160,220,255),
    Soaked     = Color3.fromRGB(80,160,220),
    Flooded    = Color3.fromRGB(50,120,200),
    Galactic   = Color3.fromRGB(180,100,255),
    Electric   = Color3.fromRGB(255,255,80),
    Foggy      = Color3.fromRGB(180,180,200),
    Shocked    = Color3.fromRGB(255,220,50),
    Starstruck = Color3.fromRGB(255,200,50),
    Sandy      = Color3.fromRGB(220,180,100),
    Mossy      = Color3.fromRGB(100,200,80),
    Muddy      = Color3.fromRGB(140,100,60),
}
local VARIANT_COLOR = {
    Unripe   = Color3.fromRGB(150,220,80),
    Ripe     = Color3.fromRGB(100,220,100),
    Overripe = Color3.fromRGB(180,140,60),
    Lush     = Color3.fromRGB(0,210,120),
    Gold     = Color3.fromRGB(255,200,50),
    Silver   = Color3.fromRGB(200,210,220),
}


-- ============================================================
--  HELPERS
-- ============================================================
local function GetMoney()
    -- Direct path matches the known working source:
    -- game:GetService("Players").LocalPlayer.PlayerGui.ShillingsCurrency.CurrencyAmount.Text
    local ok, result = pcall(function()
        local txt = LP.PlayerGui.ShillingsCurrency.CurrencyAmount.Text
        -- strip everything except digits (handles "$31.99K", "$847", "1,234" etc.)
        -- special case: "K" suffix  e.g. "$31.99K" = 31990
        local num
        if txt:match("K$") then
            num = tonumber(txt:gsub("[^%d%.]+",""))
            if num then num = math.floor(num * 1000) end
        else
            num = tonumber(txt:gsub("[^%d]",""))
        end
        return num or 0
    end)
    return (ok and result) or 0
end

local function ReadSeedStock(seedName)
    local node = seedName:gsub(" Seed","")
    local ok, val = pcall(function()
        local pg  = LP:FindFirstChild("PlayerGui")
        local sf  = pg and pg:FindFirstChild("SeedShop")
        local fr  = sf and sf:FindFirstChild("Frame")
        local scr = fr and fr:FindFirstChild("ScrollingFrame")
        local item= scr and scr:FindFirstChild(node)
        local mi  = item and item:FindFirstChild("MainInfo")
        local st  = mi and mi:FindFirstChild("StockText")
        if not st then return nil end
        return tonumber(st.Text:match("(%d+)"))
    end)
    return ok and val or nil
end

local function ReadGearStock(gearName)
    local ok, val = pcall(function()
        local pg  = LP:FindFirstChild("PlayerGui")
        local gs  = pg and pg:FindFirstChild("GearShop")
        local fr  = gs and gs:FindFirstChild("Frame")
        local scr = fr and fr:FindFirstChild("ScrollingFrame")
        local item= scr and scr:FindFirstChild(gearName)
        local mi  = item and item:FindFirstChild("MainInfo")
        local st  = mi and mi:FindFirstChild("StockText")
        if not st then return nil end
        return tonumber(st.Text:match("(%d+)"))
    end)
    return ok and val or nil
end

local function BuySeed(name)
    pcall(function()
        ReplicatedStorage.RemoteEvents.PurchaseShopItem:InvokeServer("SeedShop", name)
    end)
end
local function BuyGear(name)
    pcall(function()
        ReplicatedStorage.RemoteEvents.PurchaseShopItem:InvokeServer("GearShop", name)
    end)
end

-- Auto-buy core loop
-- ============================================================
--  AUTO BUY CORE
-- ============================================================
-- Simplified loop: just buys without relying on GUI stock checks.
-- Stock check is optional — if nil (shop not open) we still buy.
-- TP: teleports to the correct shop, waits, buys, teleports back.

local function DoAutoBuyLoop(flagGetter, getItems, shopType, amtGetter)
    task.spawn(function()
        while flagGetter() do
            local items = getItems()
            if #items == 0 then task.wait(1) ; continue end

            local hrp     = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            local savedCF = hrp and hrp.CFrame
            local didTp   = false

            -- Teleport to shop ONCE at start of each buy pass
            if _G.PHC_AutoBuyTeleport and hrp then
                local destCF = (shopType == "Seed") and SEED_SHOP_CF or GEAR_SHOP_CF
                pcall(function() hrp.CFrame = destCF end)
                task.wait(0.4)
                didTp = true
            end

            -- Buy ALL items fully before doing anything else
            local shopName = (shopType == "Seed") and "SeedShop" or "GearShop"
            for _, name in ipairs(items) do
                if not flagGetter() then break end
                local amt = amtGetter()
                for i = 1, amt do
                    if not flagGetter() then break end
                    pcall(function()
                        ReplicatedStorage.RemoteEvents.PurchaseShopItem:InvokeServer(shopName, name)
                    end)
                    task.wait(0.1)
                end
            end

            -- Only teleport back AFTER all items are bought
            if didTp and savedCF then
                local hrp2 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp2 then pcall(function() hrp2.CFrame = savedCF end) end
            end

            task.wait(0.5)
        end
    end)
end

-- ============================================================
--  FRUIT DATA READER
-- ============================================================
-- Returns table of {plant, fruit, mutations(table), ripeness, multiplier, weight, scale, sizeBoost}
-- for all fruits in ClientPlants, optionally filtered by mutation/variant filters
local function GetFruitData(filterMutations, filterVariants)
    local results = {}
    local cp = workspace:FindFirstChild("ClientPlants")
    if not cp then return results end

    for _, plant in ipairs(cp:GetChildren()) do
        -- Each child of ClientPlants is e.g. Corn1, Mushroom1 etc.
        for _, fruitObj in ipairs(plant:GetChildren()) do
            -- Fruit1, Fruit2 etc  (skip Seed)
            if fruitObj.Name:match("^Fruit") then
                local ok, data = pcall(function()
                    local attrs = fruitObj -- fruit-level attributes
                    local mutRaw   = attrs:GetAttribute("Mutation") or ""
                    local ripMult  = attrs:GetAttribute("RipenessMultiplier") or 1
                    -- RipenessStage and Variant are on the PLANT model, not the fruit
                    local ripStage = fruitObj:GetAttribute("RipenessStage") or "Unknown"
                    local plantVar = fruitObj:GetAttribute("Variant") or ""
                    local weight   = attrs:GetAttribute("FruitWeight") or 0
                    local scale    = attrs:GetAttribute("FruitScale") or 0
                    local sizeBoost= attrs:GetAttribute("FruitSizeBoost") or 0

                    -- Parse comma-separated mutations e.g. "Shocked,Soaked"
                    local mutations = {}
                    for m in mutRaw:gmatch("[^,]+") do
                        table.insert(mutations, m:match("^%s*(.-)%s*$")) -- trim spaces
                    end

                    return {
                        plant      = plant,
                        fruitObj   = fruitObj,
                        mutations  = mutations,
                        mutRaw     = mutRaw,
                        ripStage   = ripStage,
                        plantVar   = plantVar,
                        ripMult    = ripMult,
                        weight     = weight,
                        scale      = scale,
                        sizeBoost  = sizeBoost,
                    }
                end)
                if ok and data then
                    -- Apply mutation filter
                    local mutPass = true
                    if filterMutations and #filterMutations > 0 then
                        mutPass = false
                        for _, fm in ipairs(filterMutations) do
                            for _, dm in ipairs(data.mutations) do
                                if dm == fm then mutPass = true ; break end
                            end
                            if mutPass then break end
                        end
                    end
                    -- Apply variant filter (check both RipenessStage and plant Variant)
                    local varPass = true
                    if filterVariants and #filterVariants > 0 then
                        varPass = false
                        for _, fv in ipairs(filterVariants) do
                            if data.ripStage == fv or data.plantVar == fv then varPass = true ; break end
                        end
                    end

                    if mutPass and varPass then
                        table.insert(results, data)
                    end
                end
            end
        end
    end
    return results
end

-- ============================================================
--  GLOBAL STATE
-- ============================================================
_G.PHC_SelectedSeeds    = {}
_G.PHC_SelectedGears    = {}
_G.PHC_SeedAmt          = 1
_G.PHC_GearAmt          = 1
_G.PHC_AutoBuySeed      = false
_G.PHC_AutoBuyGear      = false
_G.PHC_AutoBuyAllSeeds  = false
_G.PHC_AutoBuyAllGears  = false
_G.PHC_AutoBuyRarity    = {}
_G.PHC_AutoBuyTeleport  = false
_G.PHC_InfJump          = false
_G.PHC_NoClip           = false
_G.PHC_HarvestMutFilter = {}
_G.PHC_HarvestVarFilter = {}
_G.PHC_FruitESP         = false
_G.PHC_FruitESPObjs     = {} -- {bill, bill, ...} to destroy on toggle off
_G.PHC_AfkConn          = nil

-- ============================================================
--  WINDOW
-- ============================================================
local Window = PHCzack:CreateWindow({
    Title    = "PHCzack",
    SubTitle = "Garden Horizon",
})

local Main    = Window:AddTab("MAIN")
local Farm    = Window:AddTab("FARM")
local Shop    = Window:AddTab("SHOP")
local Visuals = Window:AddTab("VISUALS")
local Events  = Window:AddTab("EVENTS")

-- ============================================================
--  ░░  MAIN TAB  ░░
-- ============================================================
Main:AddShowFPS()
Main:AddSeparator("PLAYER")

Main:AddSlider("Walk Speed", 16, 200, 16, function(v)
    local c = LP.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = v end
end)
Main:AddSlider("Jump Power", 50, 300, 50, function(v)
    local c = LP.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower = v end
end)

Main:AddToggle("Infinite Jump", false, function(on) _G.PHC_InfJump = on end)
if not _G.PHC_IJConn then
    _G.PHC_IJConn = UserInputService.JumpRequest:Connect(function()
        if _G.PHC_InfJump then
            local c = LP.Character
            if c and c:FindFirstChild("Humanoid") then
                c.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end)
end

Main:AddCheckbox("No Clip", false, function(on) _G.PHC_NoClip = on end)
if not _G.PHC_NCConn then
    _G.PHC_NCConn = RunService.Stepped:Connect(function()
        if _G.PHC_NoClip then
            local c = LP.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end
    end)
end

-- ── Anti AFK ──────────────────────────────────────────────
-- Uses VirtualUser:CaptureController() which is the actual Roblox anti-idle signal.
-- Also physically nudges the character every 15s to reset ANY server-side idle timer.
-- Fires the game's own AFK remote too for good measure.
Main:AddToggle("Anti AFK", false, function(on)
    _G.PHC_AfkActive = on
    if on then
        task.spawn(function()
            -- Bind VirtualUser immediately — this alone prevents the Roblox idle popup
            local VU = game:GetService("VirtualUser")
            pcall(function() VU:CaptureController() end)

            local elapsed = 0
            while _G.PHC_AfkActive do
                task.wait(1)
                elapsed = elapsed + 1

                -- Every 15 seconds: physical nudge + re-bind VirtualUser + fire remote
                if elapsed >= 15 then
                    elapsed = 0

                    -- 1. Re-bind VirtualUser (resets Roblox's internal idle clock)
                    pcall(function() VU:CaptureController() end)

                    -- 2. Fire game's AFK remote
                    pcall(function()
                        ReplicatedStorage.RemoteEvents.AFK:FireServer(false)
                    end)

                    -- 3. Physically move character a tiny bit forward then back
                    local char = LP.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    local hum  = char and char:FindFirstChild("Humanoid")
                    if hrp and hum then
                        local orig = hrp.CFrame
                        -- Nudge 0.5 studs forward
                        hrp.CFrame = orig * CFrame.new(0, 0, -0.5)
                        task.wait(0.1)
                        hrp.CFrame = orig
                    end

                    -- 4. Virtual button press (simulates input so Roblox thinks player is active)
                    pcall(function()
                        VU:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                        task.wait(0.05)
                        VU:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    end)
                end
            end
        end)
    end
end)

Main:AddSeparator("MISC")
Main:AddDropdown("Gravity", {"Normal","Low","Moon","Zero"}, function(v)
    local map = {Normal=196,Low=80,Moon=20,Zero=0}
    workspace.Gravity = map[v] or 196
end)
Main:AddButton("Reset Character", function()
    local c = LP.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.Health = 0 end
end)
Main:AddButton("Rejoin", function()
    TeleportService:Teleport(game.PlaceId, LP)
end, "accent")

-- ── Auto Teleport ──────────────────────────────────────────
Main:AddSeparator("AUTO TELEPORT")
Main:AddLabel("Saves your spot → teleports to dest → returns after 3s", nil)

local function StartAutoTeleport(flagName, destCF)
    task.spawn(function()
        while _G[flagName] do
            local char = LP.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local savedCF = hrp.CFrame
                hrp.CFrame = destCF
                task.wait(20)               -- stay 20 seconds at destination
                if _G[flagName] then
                    local char2 = LP.Character
                    local hrp2  = char2 and char2:FindFirstChild("HumanoidRootPart")
                    if hrp2 then hrp2.CFrame = savedCF end
                end
            end
            task.wait(20)  -- wait 20 seconds at original pos, then repeat
        end
    end)
end

_G.PHC_AutoTpSell = false
Main:AddToggle("Auto TP: Sell Stand (every 20s)", false, function(on)
    _G.PHC_AutoTpSell = on
    if on then StartAutoTeleport("PHC_AutoTpSell", SELL_STAND_CF) end
end)

_G.PHC_AutoTpSeed = false
Main:AddToggle("Auto TP: Seed Shop (every 20s)", false, function(on)
    _G.PHC_AutoTpSeed = on
    if on then StartAutoTeleport("PHC_AutoTpSeed", SEED_SHOP_CF) end
end)

_G.PHC_AutoTpGear = false
Main:AddToggle("Auto TP: Gear Shop (every 20s)", false, function(on)
    _G.PHC_AutoTpGear = on
    if on then StartAutoTeleport("PHC_AutoTpGear", GEAR_SHOP_CF) end
end)

Main:AddButton("TP to Sell Stand Now", function()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = SELL_STAND_CF end
end)

Main:AddButton("TP to Seed Shop Now", function()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = SEED_SHOP_CF end
end)

Main:AddButton("TP to Gear Shop Now", function()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = GEAR_SHOP_CF end
end)

Main:AddButton("TP to Quest Board Now", function()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.CFrame = QUEST_BOARD_CF end
end)

-- ============================================================
--  ░░  FARM TAB  ░░
-- ============================================================
local PLANT_TYPES = {
    "Carrot","Corn","Onion","Strawberry","Mushroom",
    "Beetroot","Tomato","Apple","Rose","Wheat",
    "Banana","Plum","Potato","Cabbage","Cherry","Dawnfruit",
    "Bamboo","Mango","Amberpine","Bellpepper","Birch"
}
local selectedCrops = {}
local harvestMode   = "Normal"

Farm:AddSeparator("AUTO HARVEST")
Farm:AddMultiDropdown("Select Crops", PLANT_TYPES, function(sel) selectedCrops = sel end)
Farm:AddDropdown("Harvest Mode", {"Normal","Fly","Teleport"}, function(v) harvestMode = v end)

-- Mutation filter for harvest
Farm:AddSeparator("HARVEST FILTERS")
Farm:AddMultiDropdown("Filter: Mutation Only", MUTATION_LIST, function(sel)
    _G.PHC_HarvestMutFilter = sel
end)
Farm:AddMultiDropdown("Filter: Variant Only", VARIANT_LIST, function(sel)
    _G.PHC_HarvestVarFilter = sel
end)
Farm:AddLabel("(Empty = harvest all. Select to only harvest matching)", nil)

-- Get HarvestPrompt objects from ClientPlants based on selected crops + filters
local function GetHarvestPrompts()
    local prompts = {}
    local cp = workspace:FindFirstChild("ClientPlants")
    if not cp then return prompts end

    for _, plant in ipairs(cp:GetChildren()) do
        -- Match crop type
        local matchesCrop = (#selectedCrops == 0)
        for _, cropName in ipairs(selectedCrops) do
            if plant.Name:match("^"..cropName) then
                matchesCrop = true ; break
            end
        end
        if not matchesCrop then continue end

        -- Scan Fruit children
        for _, fruitObj in ipairs(plant:GetChildren()) do
            if not fruitObj.Name:match("^Fruit") then continue end

            -- ── FILTER LOGIC ───────────────────────────────────────────
            local shouldHarvest = true
            local hasMutFilter = #_G.PHC_HarvestMutFilter > 0
            local hasVarFilter = #_G.PHC_HarvestVarFilter > 0

            if hasMutFilter or hasVarFilter then
                -- Read attributes directly (no pcall - we want to see if this fails)
                local mutRaw = ""
                local ripStage = ""
                pcall(function()
                    local v = fruitObj:GetAttribute("Mutation")
                    if type(v) == "string" then mutRaw = v end
                end)
                pcall(function()
                    -- RipenessStage is on the PLANT model
                    local v = fruitObj:GetAttribute("RipenessStage")
                    if type(v) == "string" then ripStage = v end
                end)

                -- Mutation AND: every selected mutation must appear in fruit string
                if hasMutFilter then
                    for _, fm in ipairs(_G.PHC_HarvestMutFilter) do
                        -- exact word match to avoid "Shocked" matching "Shocked,Soaked" partially wrong
                        local found = false
                        for word in mutRaw:gmatch("[^,]+") do
                            if word:match("^%s*(.-)%s*$") == fm then
                                found = true ; break
                            end
                        end
                        if not found then
                            shouldHarvest = false
                            break
                        end
                    end
                end

                -- Variant OR: check both plant RipenessStage AND plant Variant (Gold/Silver)
                if hasVarFilter and shouldHarvest then
                    local plantVariant = ""
                    pcall(function() plantVariant = fruitObj:GetAttribute("Variant") or "" end)
                    local varMatch = false
                    for _, fv in ipairs(_G.PHC_HarvestVarFilter) do
                        if ripStage == fv or plantVariant == fv then varMatch = true ; break end
                    end
                    if not varMatch then shouldHarvest = false end
                end
            end

            if not shouldHarvest then continue end

            -- Now find HarvestPrompt inside this fruit
            -- Structures seen:
            --   Corn:     Fruit1.Handle.HarvestPrompt
            --   Dawnfruit: Fruit1["1"].HarvestPrompt
            --   Mushroom: Fruit1["4"].HarvestPrompt
            for _, desc in ipairs(fruitObj:GetDescendants()) do
                if desc.Name == "HarvestPrompt" then
                    table.insert(prompts, desc)
                end
            end
        end
    end
    return prompts
end

local function DoHarvest(prompt)
    if not prompt or not prompt.Parent then return end

    -- Move to crop if Fly or Teleport mode
    if harvestMode ~= "Normal" then
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local targetPart = nil
            if prompt:IsA("BasePart") then
                targetPart = prompt
            else
                -- Walk up ancestry to find a BasePart
                local p = prompt.Parent
                while p and p ~= workspace do
                    if p:IsA("BasePart") then targetPart = p ; break end
                    p = p.Parent
                end
                if not targetPart then
                    targetPart = prompt:FindFirstAncestorWhichIsA("BasePart")
                end
            end
            if targetPart then
                hrp.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0))
                task.wait(0.08)
            end
        end
    end

    -- Fire the ProximityPrompt — try all cases
    -- Case 1: HarvestPrompt itself is a ProximityPrompt
    pcall(function()
        if prompt:IsA("ProximityPrompt") then
            fireproximityprompt(prompt)
        end
    end)
    -- Case 2: Direct child ProximityPrompt
    pcall(function()
        local pp = prompt:FindFirstChildWhichIsA("ProximityPrompt")
        if pp then fireproximityprompt(pp) end
    end)
    -- Case 3: Sibling ProximityPrompt
    pcall(function()
        if prompt.Parent then
            local pp = prompt.Parent:FindFirstChildWhichIsA("ProximityPrompt")
            if pp then fireproximityprompt(pp) end
        end
    end)
    -- Case 4: Scan all descendants
    pcall(function()
        for _, v in ipairs(prompt:GetDescendants()) do
            if v:IsA("ProximityPrompt") then fireproximityprompt(v) end
        end
    end)
end

_G.PHC_AutoHarvest = false
Farm:AddToggle("Auto Harvest (Selected)", false, function(on)
    _G.PHC_AutoHarvest = on
    if on then
        task.spawn(function()
            while _G.PHC_AutoHarvest do
                local prompts = GetHarvestPrompts()
                for _, p in ipairs(prompts) do
                    if not _G.PHC_AutoHarvest then break end
                    DoHarvest(p)
                    task.wait(harvestMode == "Normal" and 0.5 or 0.12)
                end
                task.wait(0.5)
            end
        end)
    end
end)

Farm:AddButton("Harvest Once (Selected)", function()
    for _, p in ipairs(GetHarvestPrompts()) do
        DoHarvest(p) ; task.wait(0.1)
    end
end, "accent")

-- ============================================================
--  SELL
-- ============================================================
Farm:AddSeparator("SELL")

-- Sell All Fruits (auto-loop toggle)
_G.PHC_AutoSellAll = false
Farm:AddToggle("Auto Sell All Fruits", false, function(on)
    _G.PHC_AutoSellAll = on
    if on then
        task.spawn(function()
            while _G.PHC_AutoSellAll do
                pcall(function()
                    ReplicatedStorage.RemoteEvents.SellItems:InvokeServer("SellAll")
                end)
                task.wait(1)
            end
        end)
    end
end)

Farm:AddButton("Sell All Fruits Now", function()
    pcall(function()
        ReplicatedStorage.RemoteEvents.SellItems:InvokeServer("SellAll")
    end)
end, "accent")

-- Sell On Hand (auto-loop toggle)
_G.PHC_AutoSellHand = false
Farm:AddToggle("Auto Sell On Hand", false, function(on)
    _G.PHC_AutoSellHand = on
    if on then
        task.spawn(function()
            while _G.PHC_AutoSellHand do
                pcall(function()
                    ReplicatedStorage.RemoteEvents.SellItems:InvokeServer("SellSingle")
                end)
                task.wait(0.5)
            end
        end)
    end
end)

Farm:AddButton("Sell On Hand Now", function()
    pcall(function()
        ReplicatedStorage.RemoteEvents.SellItems:InvokeServer("SellSingle")
    end)
end)


-- ============================================================
--  AUTO PLANT
-- ============================================================
Farm:AddSeparator("AUTO PLANT")
Farm:AddLabel("Reads seeds from your Backpack automatically", nil)

local selectedPlantSeeds = {}
local plantRadius   = 5     -- stud radius
local plantMode     = "Below Me"  -- "Below Me" | "Center"
local plantCenterPos = nil  -- set when user clicks "Set Center Here"
local plantSpacing  = 4     -- studs between each plant position in grid

Farm:AddMultiDropdown("Seeds to Plant", SEED_LIST, function(sel)
    selectedPlantSeeds = sel
end)

Farm:AddDropdown("Plant Position Mode", {"Below Me", "Center"}, function(v)
    plantMode = v
end)

Farm:AddSlider("Plant Radius (studs)", 1, 30, 5, function(v)
    plantRadius = v
end)

Farm:AddSlider("Grid Spacing (studs)", 1, 10, 4, function(v)
    plantSpacing = v
end)

Farm:AddButton("Set Center Point (Stand Here)", function()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        plantCenterPos = hrp.Position
    end
end)

-- ── Helpers ─────────────────────────────────────────────────

-- Get the base seed type name from a backpack tool name
-- "x19 Carrot Seed" → "Carrot"
-- "Apple Seed"      → "Apple"
-- "Onion Seed"      → "Onion"
local function ParseSeedType(toolName)
    -- Strip leading quantity like "x19 " or "x2 "
    local stripped = toolName:gsub("^x%d+%s*", "")
    -- Strip trailing " Seed"
    local seedType = stripped:gsub("%s*Seed$", ""):match("^%s*(.-)%s*$")
    return seedType
end

-- Find a backpack tool that matches the given seed selection name
-- selectedName is e.g. "Carrot Seed" (from SEED_LIST)
-- Returns the Tool instance or nil
local function FindBackpackSeed(selectedName)
    local bp = LP:FindFirstChild("Backpack")
    if not bp then return nil end
    -- Target seed type: "Carrot Seed" → "Carrot"
    local targetType = selectedName:gsub("%s*Seed$", ""):match("^%s*(.-)%s*$")
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            local parsed = ParseSeedType(tool.Name)
            if parsed:lower() == targetType:lower() then
                return tool
            end
        end
    end
    -- Also check already-equipped tool in character
    local char = LP.Character
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local parsed = ParseSeedType(tool.Name)
                if parsed:lower() == targetType:lower() then
                    return tool
                end
            end
        end
    end
    return nil
end

-- Equip a tool from backpack into character's hand
local function EquipSeed(tool)
    if not tool then return false end
    -- If it's already in character, already equipped
    if tool.Parent == LP.Character then return true end
    -- Move from backpack to character to equip
    pcall(function()
        local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:EquipTool(tool)
        end
    end)
    task.wait(0.15)
    return true
end

-- Generate a grid of Vector3 positions within radius around an origin point
-- Returns positions on the XZ plane at origin.Y (ground level)
local function GetPlantPositions(origin)
    local positions = {}
    local r = plantRadius
    local s = plantSpacing
    local y = origin.Y  -- keep same height as origin/player feet

    for dx = -r, r, s do
        for dz = -r, r, s do
            if math.sqrt(dx*dx + dz*dz) <= r then
                table.insert(positions, Vector3.new(origin.X + dx, y, origin.Z + dz))
            end
        end
    end
    return positions
end

-- Get the origin point based on current plant mode
local function GetPlantOrigin()
    if plantMode == "Center" and plantCenterPos then
        return plantCenterPos
    end
    -- "Below Me" — use current player position
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

-- Plant one seed at one position
-- seedName = display name like "Carrot Seed"
-- pos = Vector3 world position
local function PlantAtPosition(seedName, pos)
    -- 1. Find the tool in backpack
    local tool = FindBackpackSeed(seedName)
    if not tool then return false end  -- no seed of this type in backpack

    -- 2. Equip it
    EquipSeed(tool)

    -- 3. Get seed type for remote (strip "Seed" suffix)
    local seedType = seedName:gsub("%s*Seed$", ""):match("^%s*(.-)%s*$")

    -- 4. Fire the PlantSeed remote with position
    -- Confirmed format: PlantSeed:InvokeServer(seedType, Vector3Position)
    local ok = pcall(function()
        ReplicatedStorage.RemoteEvents.PlantSeed:InvokeServer(seedType, pos)
    end)
    return ok
end

-- Full plant pass: for each selected seed, plant across all positions in radius
local function DoPlantPass(single)
    local origin = GetPlantOrigin()
    if not origin then return end

    local positions = single and {origin} or GetPlantPositions(origin)

    for _, seedName in ipairs(selectedPlantSeeds) do
        local tool = FindBackpackSeed(seedName)
        if not tool then continue end  -- skip if not in backpack

        EquipSeed(tool)
        task.wait(0.1)

        for _, pos in ipairs(positions) do
            if not (_G.PHC_AutoPlant or single) then break end
            PlantAtPosition(seedName, pos)
            task.wait(0.3)
        end
    end
end

-- ── UI Controls ─────────────────────────────────────────────

_G.PHC_AutoPlant = false
Farm:AddToggle("Auto Plant Selected Seeds", false, function(on)
    _G.PHC_AutoPlant = on
    if on then
        task.spawn(function()
            while _G.PHC_AutoPlant do
                DoPlantPass(false)
                task.wait(1)
            end
        end)
    end
end)

Farm:AddButton("Plant Once at Current Position", function()
    task.spawn(function() DoPlantPass(false) end)
end, "accent")

Farm:AddButton("Plant Single Below Me", function()
    task.spawn(function()
        local origin = GetPlantOrigin()
        if not origin then return end
        for _, seedName in ipairs(selectedPlantSeeds) do
            local tool = FindBackpackSeed(seedName)
            if not tool then continue end
            EquipSeed(tool)
            task.wait(0.1)
            PlantAtPosition(seedName, origin)
            task.wait(0.3)
        end
    end)
end)

-- ============================================================
--  AUTO SHOVEL
-- ============================================================
Farm:AddSeparator("AUTO SHOVEL")

local shovelCrops          = {}
local shovelKeepRipeness   = {}
local shovelKeepVariants   = {}
local shovelKeepScale        = 0   -- keep ANY fruit if scale >= this
local shovelKeepVariantScale = 0   -- keep variant fruit only if scale >= this
local shovelStatusLabel    = nil
local _G_PHC_ShovelTP      = false

local RIPENESS_LIST = {"Unripe","Ripe","Overripe","Lush"}
local PLANT_VARIANT_LIST = {"Gold","Silver"}

Farm:AddMultiDropdown("Shovel: Select Crops", PLANT_TYPES, function(sel)
    shovelCrops = sel
end)

Farm:AddLabel("Keep if fruit Ripeness is any of these:", nil)
Farm:AddMultiDropdown("Shovel: Keep Ripeness", RIPENESS_LIST, function(sel)
    shovelKeepRipeness = sel
end)

Farm:AddLabel("Keep if fruit Variant is Gold or Silver:", nil)
Farm:AddMultiDropdown("Shovel: Keep Variant", PLANT_VARIANT_LIST, function(sel)
    shovelKeepVariants = sel
end)

Farm:AddLabel("Keep fruit if Scale >= (0 = off):", nil)
Farm:AddSlider("Shovel: Keep if Scale >=", 0, 10, 0, function(v)
    shovelKeepScale = v
end)

Farm:AddLabel("Keep variant fruit only if Scale >= (0 = keep all matching variant):", nil)
Farm:AddSlider("Shovel: Keep Variant if Scale >=", 0, 10, 0, function(v)
    shovelKeepVariantScale = v
end)

Farm:AddToggle("Shovel: Teleport to Fruit First", false, function(on)
    _G_PHC_ShovelTP = on
end)

shovelStatusLabel = Farm:AddLabel("Shovel: idle", nil)

local function TryEquipShovel()
    pcall(function()
        local char = LP.Character
        local bp   = LP:FindFirstChild("Backpack")
        local function find(c)
            if not c then return nil end
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find("shovel") then return t end
            end
        end
        local shovel = find(bp) or find(char)
        if shovel then
            local hum = char and char:FindFirstChild("Humanoid")
            if hum then hum:EquipTool(shovel) end
        end
    end)
end

local function ShouldShovel(fruit)
    local variant = ""
    local rip     = ""
    pcall(function() variant = fruit:GetAttribute("Variant") or "" end)
    pcall(function() rip     = fruit:GetAttribute("RipenessStage") or "" end)

    -- Keep if scale >= threshold (applies to ALL fruits)
    if shovelKeepScale > 0 then
        local sc = 0
        pcall(function() sc = fruit:GetAttribute("FruitScale") or 0 end)
        if sc >= shovelKeepScale then return false end
    end

    -- Keep if ripeness matches
    if #shovelKeepRipeness > 0 then
        for _, kv in ipairs(shovelKeepRipeness) do
            if rip == kv then return false end
        end
    end

    -- Keep if variant matches (Gold/Silver)
    -- If variant scale threshold set: only keep if scale >= threshold too
    if #shovelKeepVariants > 0 then
        for _, kv in ipairs(shovelKeepVariants) do
            if variant == kv then
                if shovelKeepVariantScale > 0 then
                    local sc = 0
                    pcall(function() sc = fruit:GetAttribute("FruitScale") or 0 end)
                    if sc >= shovelKeepVariantScale then return false end
                    -- scale too low → still shovel even if variant matches
                else
                    return false  -- keep all of this variant
                end
            end
        end
    end

    return true
end

local function DoShovelPass()
    if #shovelCrops == 0 then
        pcall(function() shovelStatusLabel.Set("Shovel: no crops selected") end)
        return
    end

    local cp = workspace:FindFirstChild("ClientPlants")
    if not cp then
        pcall(function() shovelStatusLabel.Set("Shovel: workspace.ClientPlants not found") end)
        return
    end

    -- Remote is in normal ReplicatedStorage
    local remote = nil
    pcall(function()
        remote = game:GetService("ReplicatedStorage").RemoteEvents.RemovePlant
    end)
    if not remote then
        -- Fallback: search nil instances
        pcall(function()
            for _, v in pairs(getnilinstances()) do
                if v.ClassName == "RemoteEvent" and v.Name == "RemovePlant" then
                    remote = v ; break
                end
            end
        end)
    end
    if not remote then
        pcall(function() shovelStatusLabel.Set("Shovel: RemovePlant remote not found!") end)
        return
    end

    TryEquipShovel()
    task.wait(0.2)

    local fired   = 0
    local skipped = 0

    for _, plant in ipairs(cp:GetChildren()) do
        local plantCrop = plant.Name:gsub("%d+$", "")
        local cropMatch = false
        for _, sc in ipairs(shovelCrops) do
            if sc:lower() == plantCrop:lower() then cropMatch = true ; break end
        end
        if not cropMatch then continue end

        for _, fruit in ipairs(plant:GetChildren()) do
            if not fruit.Name:match("^Fruit") then continue end

            if not ShouldShovel(fruit) then
                skipped = skipped + 1
                continue
            end

            -- Read Uuid attribute from fruit model
            -- Format: "cea8028a-6bf4-4174-a4ee-8481d75c30b5:regrow:4"
            -- arg1 = base uuid (before :regrow:), arg2 = number after last :
            local uuidRaw = ""
            pcall(function()
                local v = fruit:GetAttribute("Uuid")
                if v and v ~= "" then uuidRaw = v ; return end
                -- fallback: check children
                for _, child in ipairs(fruit:GetChildren()) do
                    local v2 = child:GetAttribute("Uuid")
                    if v2 and v2 ~= "" then uuidRaw = v2 ; return end
                end
            end)

            if uuidRaw == "" then
                skipped = skipped + 1
                continue
            end

            -- Parse "uuid:regrow:N" → uuidBase, N
            local uuidBase, uuidIdx
            uuidBase, uuidIdx = uuidRaw:match("^(.+):regrow:(%d+)$")
            if not uuidBase then
                -- fallback: try plain "uuid:N"
                uuidBase, uuidIdx = uuidRaw:match("^(.+):(%d+)$")
            end
            if not uuidBase then
                -- no suffix at all — use raw as base, idx=1
                uuidBase = uuidRaw
                uuidIdx = "1"
            end
            local idx = tonumber(uuidIdx) or 1

            -- Teleport to fruit if toggle enabled
            if _G_PHC_ShovelTP then
                pcall(function()
                    local hrp  = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    local part = fruit:FindFirstChildWhichIsA("BasePart")
                    if hrp and part then
                        hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                        task.wait(0.15)
                    end
                end)
            end

            -- Fire: RemoteEvents.RemovePlant:FireServer(uuidBase, idx)
            pcall(function()
                remote:FireServer(uuidBase, idx)
            end)

            fired = fired + 1
            pcall(function()
                shovelStatusLabel.Set("Fired " .. fired .. " | skipped " .. skipped .. " | " .. uuidBase:sub(1,8) .. ":" .. idx)
            end)
            task.wait(0.1)
        end
    end

    pcall(function() shovelStatusLabel.Set("Done — fired: " .. fired .. " | kept: " .. skipped) end)
end

Farm:AddButton("Shovel Once (Selected Crops)", function()
    task.spawn(DoShovelPass)
end, "accent")

_G.PHC_AutoShovel = false
Farm:AddToggle("Auto Shovel (loop)", false, function(on)
    _G.PHC_AutoShovel = on
    if on then
        task.spawn(function()
            while _G.PHC_AutoShovel do
                DoShovelPass()
                task.wait(1)
            end
            pcall(function() shovelStatusLabel.Set("Shovel: stopped") end)
        end)
    end
end)


Shop:AddSeparator("WALLET")
local moneyLabel = Shop:AddLabel("Balance: loading...", nil)
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            -- Show the raw text exactly as the game displays it
            local rawTxt = LP.PlayerGui.ShillingsCurrency.CurrencyAmount.Text
            moneyLabel.Set("Balance:  " .. rawTxt)
        end)
    end
end)

-- SEED SHOP
Shop:AddSeparator("SEED SHOP")
Shop:AddMultiDropdown("Seeds to Buy", SEED_LIST, function(sel)
    _G.PHC_SelectedSeeds = sel
end)
Shop:AddSlider("Seed Buy Amount", 1, 50, 1, function(v) _G.PHC_SeedAmt = v end)
Shop:AddButton("Buy Selected Seeds Now", function()
    for _, name in ipairs(_G.PHC_SelectedSeeds) do
        for _ = 1, _G.PHC_SeedAmt do
            pcall(function() ReplicatedStorage.RemoteEvents.PurchaseShopItem:InvokeServer("SeedShop", name) end)
            task.wait(0.2)
        end
    end
end, "accent")

Shop:AddSeparator("SEED AUTO-BUY")

-- Master: Auto Buy ALL Seeds
Shop:AddToggle("Auto Buy ALL Seeds", false, function(on)
    _G.PHC_AutoBuyAllSeeds = on
    if on then
        DoAutoBuyLoop(
            function() return _G.PHC_AutoBuyAllSeeds end,
            function() return SEED_LIST end,
            "Seed",
            function() return 1 end
        )
    end
end)

-- Auto Buy Selected Seeds
Shop:AddToggle("Auto Buy Selected Seeds", false, function(on)
    _G.PHC_AutoBuySeed = on
    if on then
        DoAutoBuyLoop(
            function() return _G.PHC_AutoBuySeed end,
            function() return _G.PHC_SelectedSeeds end,
            "Seed",
            function() return _G.PHC_SeedAmt end
        )
    end
end)

Shop:AddSeparator("SEED AUTO-BUY  (By Rarity)")
for _, rarityName in ipairs(RARITY_ORDER) do
    local seeds = SEED_RARITY[rarityName]
    local key   = "Seed_"..rarityName
    Shop:AddToggle("Auto Buy "..rarityName.." Seeds", false, function(on)
        _G.PHC_AutoBuyRarity[key] = on
        if on then
            DoAutoBuyLoop(
                function() return _G.PHC_AutoBuyRarity[key] == true end,
                function() return seeds end,
                "Seed",
                function() return 1 end
            )
        end
    end)
end

-- GEAR SHOP
Shop:AddSeparator("GEAR SHOP")
Shop:AddMultiDropdown("Gears to Buy", GEAR_LIST, function(sel)
    _G.PHC_SelectedGears = sel
end)
Shop:AddSlider("Gear Buy Amount", 1, 20, 1, function(v) _G.PHC_GearAmt = v end)
Shop:AddButton("Buy Selected Gears Now", function()
    for _, name in ipairs(_G.PHC_SelectedGears) do
        for _ = 1, _G.PHC_GearAmt do
            pcall(function() ReplicatedStorage.RemoteEvents.PurchaseShopItem:InvokeServer("GearShop", name) end)
            task.wait(0.1)
        end
    end
end, "accent")

Shop:AddSeparator("GEAR AUTO-BUY")

-- Master: Auto Buy ALL Gears
Shop:AddToggle("Auto Buy ALL Gears", false, function(on)
    _G.PHC_AutoBuyAllGears = on
    if on then
        DoAutoBuyLoop(
            function() return _G.PHC_AutoBuyAllGears end,
            function() return GEAR_LIST end,
            "Gear",
            function() return 1 end
        )
    end
end)

-- Auto Buy Selected Gears
Shop:AddToggle("Auto Buy Selected Gears", false, function(on)
    _G.PHC_AutoBuyGear = on
    if on then
        DoAutoBuyLoop(
            function() return _G.PHC_AutoBuyGear end,
            function() return _G.PHC_SelectedGears end,
            "Gear",
            function() return _G.PHC_GearAmt end
        )
    end
end)

Shop:AddSeparator("GEAR AUTO-BUY  (By Rarity)")
for _, rarityName in ipairs(RARITY_ORDER) do
    local gears = GEAR_RARITY[rarityName]
    local key   = "Gear_"..rarityName
    Shop:AddToggle("Auto Buy "..rarityName.." Gears", false, function(on)
        _G.PHC_AutoBuyRarity[key] = on
        if on then
            DoAutoBuyLoop(
                function() return _G.PHC_AutoBuyRarity[key] == true end,
                function() return gears end,
                "Gear",
                function() return 1 end
            )
        end
    end)
end

-- ── Teleport & Buy option ────────────────────────────────────
Shop:AddSeparator("TELEPORT & BUY")
Shop:AddLabel("When ON: TP to shop before buying, return after", nil)
Shop:AddToggle("Teleport to Shop When Buying", false, function(on)
    _G.PHC_AutoBuyTeleport = on
end)

-- ============================================================
--  ░░  VISUALS TAB  ░░
-- ============================================================
Visuals:AddSeparator("ENVIRONMENT")
Visuals:AddToggle("Fullbright", false, function(on)
    game:GetService("Lighting").Brightness = on and 10 or 1
end)
Visuals:AddSlider("Field of View", 70, 120, 70, function(v)
    workspace.CurrentCamera.FieldOfView = v
end)
Visuals:AddDropdown("Time of Day", {"Morning","Noon","Sunset","Night"}, function(v)
    local map = {Morning="06:00:00",Noon="12:00:00",Sunset="18:00:00",Night="00:00:00"}
    game:GetService("Lighting").TimeOfDay = map[v] or "12:00:00"
end)
Visuals:AddToggle("Remove Fog", false, function(on)
    local L = game:GetService("Lighting")
    L.FogEnd = on and 1e6 or 100000 ; L.FogStart = on and 1e6 or 0
end)

-- ============================================================
--  ESP SYSTEM  —  unified per-fruit billboard
-- ============================================================
-- All active ESP lines are combined into ONE BillboardGui per fruit
-- so nothing overlaps. Each toggle rebuilds only its own "slot"
-- inside that shared billboard.
--
-- Toggle state lives in ESP_FLAGS so each toggle knows what's on.
-- When any flag changes we call RebuildAllESP() which clears all
-- billboards and re-creates them with only the active lines.

local ESP_FLAGS = {
    Mutation   = false,
    Variant    = false,   -- Gold/Silver — plant.Variant
    Ripeness   = false,   -- Lush/Ripe/Unripe/Overripe — plant.RipenessStage
    Weight     = false,
    Scale      = false,
    SizeBoost  = false,
    FruitValue = false,
    Box        = false,
}
-- Filter state — same AND logic as harvest filter
local espMutFilter  = {}  -- ALL selected mutations must be present on fruit
local espVarFilter  = {}  -- fruit's ripeness must match ANY selected variant
local espCropFilter = {}  -- fruit's crop type must match ANY selected crop (OR)

-- ESP box objects (separate from billboard — SelectionBox per fruit)
local ESPBoxObjs = {}

-- Outline ESPs are separate (SelectionBox, not billboard)
local ESPOutlineObjs     = {}  -- plant outlines
local ESPFruitOutlineObjs= {}  -- fruit outlines

-- All active BillboardGui objects (one per fruit) — wiped & rebuilt on any flag change
local ESPBillboards = {}

local function ClearBillboards()
    for _, bb in ipairs(ESPBillboards) do
        pcall(function() bb:Destroy() end)
    end
    ESPBillboards = {}
end

local function ClearBoxes()
    for _, b in ipairs(ESPBoxObjs) do pcall(function() b:Destroy() end) end
    ESPBoxObjs = {}
end

local function ClearOutlines(tbl)
    for _, obj in ipairs(tbl) do pcall(function() obj:Destroy() end) end
    while #tbl > 0 do table.remove(tbl) end
end

-- Count how many ESP_FLAGS are true
local function AnyESPActive()
    for _, v in pairs(ESP_FLAGS) do
        if v then return true end
    end
    return false
end

-- Check if a fruitObj passes the active ESP filters
local function FruitPassesESPFilter(fruitObj)
    local hasMutFilter  = #espMutFilter > 0
    local hasVarFilter  = #espVarFilter > 0
    local hasCropFilter = #espCropFilter > 0
    if not hasMutFilter and not hasVarFilter and not hasCropFilter then return true end

    local mutRaw    = ""
    local ripStage  = ""
    local plantVariant = ""
    pcall(function()
        local v = fruitObj:GetAttribute("Mutation")
        if type(v) == "string" then mutRaw = v end
    end)
    pcall(function()
        -- RipenessStage is on the PLANT model
        local v = fruitObj:GetAttribute("RipenessStage")
        if type(v) == "string" then ripStage = v end
    end)
    pcall(function()
        -- Variant (Gold/Silver) is also on the PLANT model
        local v = fruitObj:GetAttribute("Variant")
        if type(v) == "string" then plantVariant = v end
    end)

    -- Crop OR: parent plant name must match any selected crop
    if hasCropFilter then
        local plantCrop = ""
        pcall(function()
            plantCrop = fruitObj.Parent and fruitObj.Parent.Name:gsub("%d+$","") or ""
        end)
        local cropMatch = false
        for _, fc in ipairs(espCropFilter) do
            if fc:lower() == plantCrop:lower() then cropMatch = true ; break end
        end
        if not cropMatch then return false end
    end

    -- Mutation AND: every selected mutation must be present
    if hasMutFilter then
        for _, fm in ipairs(espMutFilter) do
            local found = false
            for word in mutRaw:gmatch("[^,]+") do
                if word:match("^%s*(.-)%s*$") == fm then found = true ; break end
            end
            if not found then return false end
        end
    end

    -- Variant/Ripeness OR: espVarFilter covers both Gold/Silver (plant.Variant) and Lush/Ripe/etc (plant.RipenessStage)
    if hasVarFilter then
        local varMatch = false
        for _, fv in ipairs(espVarFilter) do
            if ripStage == fv or plantVariant == fv then varMatch = true ; break end
        end
        if not varMatch then return false end
    end

    return true
end

-- Build ONE BillboardGui for a fruit containing all active lines stacked neatly
local function MakeFruitBillboard(fruitObj, attachPart)
    -- Gather active lines: {text, color}
    local lines = {}

    -- ── Mutation ── ONE line, each mutation its own color via RichText
    if ESP_FLAGS.Mutation then
        local mutRaw = ""
        pcall(function()
            local v = fruitObj:GetAttribute("Mutation")
            if type(v) == "string" then mutRaw = v end
        end)
        if mutRaw ~= "" then
            local hasMutF = #espMutFilter > 0
            local richParts = {}  -- RichText colored segments
            for m in mutRaw:gmatch("[^,]+") do
                m = m:match("^%s*(.-)%s*$")
                local showThis = not hasMutF
                if hasMutF then
                    for _, fm in ipairs(espMutFilter) do
                        if m == fm then showThis = true ; break end
                    end
                end
                if showThis then
                    local mult = MUTATION_MULT[m]
                    local label = mult and (m .. " (" .. mult .. "x)") or m
                    -- Get per-mutation color, convert to RGB hex for RichText
                    local c = MUTATION_COLOR[m] or Color3.fromRGB(255,220,100)
                    local r = math.floor(c.R * 255)
                    local g = math.floor(c.G * 255)
                    local b = math.floor(c.B * 255)
                    table.insert(richParts, string.format('<font color="rgb(%d,%d,%d)">%s</font>', r, g, b, label))
                end
            end
            if #richParts > 0 then
                -- Separator "+" in white
                local joined = table.concat(richParts, '<font color="rgb(200,200,200)"> + </font>')
                -- richText flag on line so TextLabel enables RichText
                table.insert(lines, { text = joined, color = Color3.fromRGB(255,255,255), rich = true })
            end
        end
    end

    -- ── Variant / Ripeness ──
    -- Shows plant-level Variant (Gold/Silver) AND fruit-level RipenessStage (Lush/Ripe/etc)
    -- ── Variant (Gold/Silver) — plant.Variant ──
    if ESP_FLAGS.Variant then
        local plantVariant = ""
        pcall(function()
            local v = fruitObj:GetAttribute("Variant")
            if type(v) == "string" then plantVariant = v end
        end)
        if plantVariant ~= "" then
            local col = VARIANT_COLOR[plantVariant] or Color3.fromRGB(255, 200, 50)
            local mult = VARIANT_MULT[plantVariant] or 1
            table.insert(lines, { text = plantVariant .. " (" .. string.format("%.1f",mult) .. "x)", color = col })
        end
    end

    -- ── Ripeness (Lush/Ripe/Unripe/Overripe) — plant.RipenessStage ──
    if ESP_FLAGS.Ripeness then
        local ripStage = ""
        pcall(function()
            local v = fruitObj:GetAttribute("RipenessStage")
            if type(v) == "string" then ripStage = v end
        end)
        if ripStage ~= "" then
            local col = VARIANT_COLOR[ripStage] or Color3.fromRGB(0, 210, 120)
            local mult = VARIANT_MULT[ripStage] or 1
            table.insert(lines, { text = ripStage .. " (" .. string.format("%.1f",mult) .. "x)", color = col })
        end
    end

    -- ── Weight ──
    if ESP_FLAGS.Weight then
        local w = 0
        pcall(function()
            local v = fruitObj:GetAttribute("FruitWeight")
            if type(v) == "number" then w = v end
        end)
        table.insert(lines, { text = string.format("%.3f kg", w), color = Color3.fromRGB(100,210,255) })
    end

    -- ── Scale ──
    if ESP_FLAGS.Scale then
        local sc = 0
        pcall(function()
            local v = fruitObj:GetAttribute("FruitScale")
            if type(v) == "number" then sc = v end
        end)
        table.insert(lines, { text = "Scale: " .. string.format("%.2f", sc), color = Color3.fromRGB(180,140,255) })
    end

    -- ── SizeBoost ──
    if ESP_FLAGS.SizeBoost then
        local sb = 0
        pcall(function()
            local v = fruitObj:GetAttribute("FruitSizeBoost")
            if type(v) == "number" then sb = v end
        end)
        table.insert(lines, { text = "SizeBoost: " .. string.format("%.2f", sb), color = Color3.fromRGB(255,180,80) })
    end

    -- ── FruitValue ($) ──
    -- Reads FruitValue attribute directly from fruitObj.
    -- If not set yet, tries to match a harvested fruit in backpack by crop+mutation+weight
    -- and sets the attribute on the plant fruit so it shows correctly.
    if ESP_FLAGS.FruitValue then
        local fv = nil
        pcall(function() fv = fruitObj:GetAttribute("FruitValue") end)

        -- If not set, try to find matching harvested fruit in backpack
        if not fv or fv == 0 then
            pcall(function()
                local mutRaw  = fruitObj:GetAttribute("Mutation") or ""
                local ripMult = fruitObj:GetAttribute("RipenessMultiplier") or 1
                local weight  = fruitObj:GetAttribute("FruitWeight") or 0
                -- Get crop type from parent plant name e.g. "Plum1" → "Plum"
                local cropType = fruitObj.Parent and fruitObj.Parent.Name:gsub("%d+$","") or ""

                local bp = LP:FindFirstChild("Backpack")
                if bp then
                    for _, tool in ipairs(bp:GetChildren()) do
                        if not tool:IsA("Tool") then continue end
                        -- Tool name format: "Plum (0.05 KG)" — extract crop name
                        local toolCrop = tool.Name:gsub("%s*%(.*%)",""):match("^%s*(.-)%s*$")
                        if toolCrop:lower() ~= cropType:lower() then continue end
                        -- Get tool's mutation and weight
                        local toolMut = tool:GetAttribute("Mutation") or ""
                        local toolW   = tool:GetAttribute("FruitWeight") or 0
                        local toolVal = tool:GetAttribute("FruitValue")
                        if not toolVal or toolVal == 0 then continue end
                        -- Match by mutation and approximate weight (within 5%)
                        local weightMatch = weight == 0 or toolW == 0 or
                            math.abs(toolW - weight) / math.max(weight, 0.001) < 0.05
                        if toolMut == mutRaw and weightMatch then
                            fv = toolVal
                            -- Cache on the plant fruit so next read is instant
                            pcall(function() fruitObj:SetAttribute("FruitValue", fv) end)
                            break
                        end
                    end
                end
            end)
        end

        if fv and fv > 0 then
            local valTxt
            if fv >= 1e6 then valTxt = string.format("$%.2fM", fv/1e6)
            elseif fv >= 1e3 then valTxt = string.format("$%.1fK", fv/1e3)
            else valTxt = "$"..tostring(math.floor(fv)) end
            table.insert(lines, { text = valTxt, color = Color3.fromRGB(80, 220, 80) })
        else
            -- No match found yet — show placeholder so user knows ESP is working
            table.insert(lines, { text = "$ (harvest one first)", color = Color3.fromRGB(150, 150, 150) })
        end
    end

    if #lines == 0 then return nil end

    local ROW_H  = 18
    local totalH = #lines * ROW_H

    local bb = Instance.new("BillboardGui")
    bb.Adornee     = attachPart
    bb.AlwaysOnTop = true
    bb.Size        = UDim2.new(0, 240, 0, totalH)   -- wider: 240px
    bb.StudsOffset = Vector3.new(0, 5, 0)
    bb.MaxDistance = 150
    bb.Parent      = workspace

    for i, line in ipairs(lines) do
        local lbl = Instance.new("TextLabel")
        lbl.Size              = UDim2.new(1, 0, 0, ROW_H)
        lbl.Position          = UDim2.new(0, 0, 0, (i-1) * ROW_H)
        lbl.BackgroundTransparency = 1
        lbl.RichText          = line.rich == true   -- per-mutation colors via HTML tags
        lbl.Text              = line.text
        lbl.TextColor3        = line.color
        lbl.Font              = Enum.Font.GothamBold
        lbl.TextSize          = 12
        lbl.TextXAlignment    = Enum.TextXAlignment.Center
        lbl.TextYAlignment    = Enum.TextYAlignment.Center
        lbl.TextStrokeTransparency = 0.3
        lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
        lbl.TextTruncate      = Enum.TextTruncate.None
        lbl.TextWrapped       = false
        lbl.Parent            = bb
    end

    fruitObj.AncestryChanged:Connect(function()
        pcall(function() bb:Destroy() end)
    end)

    return bb
end

-- Rebuild all fruit ESP billboards + boxes from scratch based on current flags + filters
local function RebuildAllESP()
    ClearBillboards()
    ClearBoxes()
    if not AnyESPActive() then return end

    local cp = workspace:FindFirstChild("ClientPlants")
    if not cp then return end

    for _, plant in ipairs(cp:GetChildren()) do
        for _, fruitObj in ipairs(plant:GetChildren()) do
            if fruitObj.Name:match("^Fruit") then
                -- Apply ESP filters (AND mutation, OR variant)
                if not FruitPassesESPFilter(fruitObj) then continue end

                local attachPart = fruitObj:FindFirstChildWhichIsA("BasePart", true)
                if not attachPart then continue end

                -- Billboard (text info)
                local anyTextFlag = ESP_FLAGS.Mutation or ESP_FLAGS.Variant or ESP_FLAGS.Ripeness or
                    ESP_FLAGS.Weight or ESP_FLAGS.Scale or ESP_FLAGS.SizeBoost or
                    ESP_FLAGS.FruitValue
                if anyTextFlag then
                    local bb = MakeFruitBillboard(fruitObj, attachPart)
                    if bb then table.insert(ESPBillboards, bb) end
                end

                -- Box (SelectionBox)
                if ESP_FLAGS.Box then
                    local sb = Instance.new("SelectionBox")
                    sb.Adornee             = fruitObj
                    sb.Color3              = Color3.fromRGB(255,220,50)
                    sb.LineThickness       = 0.05
                    sb.SurfaceTransparency = 1   -- no fill, lines only
                    sb.SurfaceColor3       = Color3.fromRGB(255,220,50)
                    sb.Parent              = workspace
                    table.insert(ESPBoxObjs, sb)
                    fruitObj.AncestryChanged:Connect(function()
                        pcall(function() sb:Destroy() end)
                    end)
                end
            end
        end
    end
end

-- Auto-refresh (shared timer — only runs when any ESP flag is true)
local espRefreshActive = false
local function EnsureRefreshRunning()
    if espRefreshActive then return end
    espRefreshActive = true
    task.spawn(function()
        while AnyESPActive() do
            task.wait(4)
            if AnyESPActive() then RebuildAllESP() end
        end
        espRefreshActive = false
    end)
end

-- Outline helpers
local function BuildOutlineESP()
    ClearOutlines(ESPOutlineObjs)
    local cp = workspace:FindFirstChild("ClientPlants")
    if not cp then return end
    for _, child in ipairs(cp:GetChildren()) do
        local hl = Instance.new("SelectionBox")
        hl.Adornee             = child
        hl.Color3              = Color3.fromRGB(0,210,120)
        hl.LineThickness       = 0.04
        hl.SurfaceTransparency = 0.85
        hl.SurfaceColor3       = Color3.fromRGB(0,210,120)
        hl.Parent              = workspace
        table.insert(ESPOutlineObjs, hl)
        child.AncestryChanged:Connect(function() pcall(function() hl:Destroy() end) end)
    end
end

local function BuildFruitOutlineESP()
    ClearOutlines(ESPFruitOutlineObjs)
    local cp = workspace:FindFirstChild("ClientPlants")
    if not cp then return end
    for _, plant in ipairs(cp:GetChildren()) do
        local match = (#selectedCrops == 0)
        for _, cropName in ipairs(selectedCrops) do
            if plant.Name:match("^"..cropName) then match = true ; break end
        end
        if not match then continue end
        for _, fruitObj in ipairs(plant:GetChildren()) do
            if fruitObj.Name:match("^Fruit") then
                local hl = Instance.new("SelectionBox")
                hl.Adornee             = fruitObj
                hl.Color3              = Color3.fromRGB(255,200,50)
                hl.LineThickness       = 0.05
                hl.SurfaceTransparency = 0.8
                hl.SurfaceColor3       = Color3.fromRGB(255,200,50)
                hl.Parent              = workspace
                table.insert(ESPFruitOutlineObjs, hl)
                fruitObj.AncestryChanged:Connect(function() pcall(function() hl:Destroy() end) end)
            end
        end
    end
end

local outlineRefreshActive = false
local function EnsureOutlineRefresh(tbl, buildFn, flagName)
    task.spawn(function()
        while _G["PHC_ESP_"..flagName] do
            task.wait(4)
            if _G["PHC_ESP_"..flagName] then buildFn() end
        end
    end)
end

-- ── VISUALS TAB UI ─────────────────────────────────────────
Visuals:AddSeparator("ENVIRONMENT")
Visuals:AddToggle("Fullbright", false, function(on)
    game:GetService("Lighting").Brightness = on and 10 or 1
end)
Visuals:AddSlider("Field of View", 70, 120, 70, function(v)
    workspace.CurrentCamera.FieldOfView = v
end)
Visuals:AddDropdown("Time of Day", {"Morning","Noon","Sunset","Night"}, function(v)
    local map = {Morning="06:00:00",Noon="12:00:00",Sunset="18:00:00",Night="00:00:00"}
    game:GetService("Lighting").TimeOfDay = map[v] or "12:00:00"
end)
Visuals:AddToggle("Remove Fog", false, function(on)
    local L = game:GetService("Lighting")
    L.FogEnd = on and 1e6 or 100000 ; L.FogStart = on and 1e6 or 0
end)

-- ── ESP FILTERS ────────────────────────────────────────────
Visuals:AddSeparator("ESP FILTERS")
Visuals:AddLabel("Crop: OR (show only selected crops, empty = all)", nil)
Visuals:AddMultiDropdown("Filter: Crop Name", PLANT_TYPES, function(sel)
    espCropFilter = sel
    if AnyESPActive() then RebuildAllESP() end
end)
Visuals:AddLabel("Mutation: AND (fruit must have ALL selected)", nil)
Visuals:AddMultiDropdown("Filter: Mutation (AND)", MUTATION_LIST, function(sel)
    espMutFilter = sel
    if AnyESPActive() then RebuildAllESP() end
end)
Visuals:AddLabel("Variant: OR — Gold/Silver = plant attribute | Lush/Ripe/etc = fruit ripeness", nil)
Visuals:AddMultiDropdown("Filter: Variant (OR)", VARIANT_LIST, function(sel)
    espVarFilter = sel
    if AnyESPActive() then RebuildAllESP() end
end)
Visuals:AddLabel("Empty = show all fruits", nil)

-- ── ESP TOGGLES ────────────────────────────────────────────
Visuals:AddSeparator("FRUIT ESP  (each toggle = one info row)")
Visuals:AddLabel("All rows merge into one clean label per fruit", nil)

Visuals:AddToggle("ESP: Mutation + Multiplier", false, function(on)
    ESP_FLAGS.Mutation = on
    RebuildAllESP()
    if on then EnsureRefreshRunning() end
end)

Visuals:AddToggle("ESP: Variant (Gold/Silver)", false, function(on)
    ESP_FLAGS.Variant = on
    RebuildAllESP()
    if on then EnsureRefreshRunning() end
end)

Visuals:AddToggle("ESP: Ripeness (Lush/Ripe/etc)", false, function(on)
    ESP_FLAGS.Ripeness = on
    RebuildAllESP()
    if on then EnsureRefreshRunning() end
end)

Visuals:AddToggle("ESP: Fruit Weight (kg)", false, function(on)
    ESP_FLAGS.Weight = on
    RebuildAllESP()
    if on then EnsureRefreshRunning() end
end)

Visuals:AddToggle("ESP: Fruit Scale", false, function(on)
    ESP_FLAGS.Scale = on
    RebuildAllESP()
    if on then EnsureRefreshRunning() end
end)

Visuals:AddToggle("ESP: Size Boost", false, function(on)
    ESP_FLAGS.SizeBoost = on
    RebuildAllESP()
    if on then EnsureRefreshRunning() end
end)

Visuals:AddToggle("ESP: Fruit Value ($)", false, function(on)
    ESP_FLAGS.FruitValue = on
    RebuildAllESP()
    if on then EnsureRefreshRunning() end
end)

Visuals:AddToggle("ESP: Fruit Box (SelectionBox)", false, function(on)
    ESP_FLAGS.Box = on
    RebuildAllESP()
    if on then EnsureRefreshRunning() end
end)

Visuals:AddButton("Refresh ESP Now", function()
    RebuildAllESP()
end)

-- ── OUTLINE ESP ─────────────────────────────────────────────
Visuals:AddSeparator("OUTLINE ESP")

_G.PHC_ESP_PlantOutline = false
Visuals:AddToggle("Plant Outline ESP (All)", false, function(on)
    _G.PHC_ESP_PlantOutline = on
    if on then
        BuildOutlineESP()
        EnsureOutlineRefresh(ESPOutlineObjs, BuildOutlineESP, "PlantOutline")
    else
        ClearOutlines(ESPOutlineObjs)
    end
end)

_G.PHC_ESP_FruitOutline = false
Visuals:AddToggle("Fruit Outline ESP (Selected Crops)", false, function(on)
    _G.PHC_ESP_FruitOutline = on
    if on then
        BuildFruitOutlineESP()
        EnsureOutlineRefresh(ESPFruitOutlineObjs, BuildFruitOutlineESP, "FruitOutline")
    else
        ClearOutlines(ESPFruitOutlineObjs)
    end
end)

-- ── EDIT MONEY ─────────────────────────────────────────────
Visuals:AddSeparator("EDIT MONEY  (display only)")

-- Slider: 0 to 999 (represents multiplied value via tier)
-- We use a 0–1000 slider where each unit = $1K for clean steps
-- and provide preset buttons for large values
local function FormatMoney(num)
    if num >= 1e12 then
        return string.format("$%.2fT", num/1e12)
    elseif num >= 1e9 then
        return string.format("$%.2fB", num/1e9)
    elseif num >= 1e6 then
        return string.format("$%.2fM", num/1e6)
    elseif num >= 1e3 then
        return string.format("$%.1fK", num/1e3)
    else
        return "$"..tostring(math.floor(num))
    end
end

local function SetMoneyDisplay(num)
    pcall(function()
        LP.PlayerGui.ShillingsCurrency.CurrencyAmount.Text = FormatMoney(num)
    end)
end

-- Slider range: 1–1000 where value represents $1K steps ($1K to $1B)
Visuals:AddSlider("Money (K) — x1000", 1, 1000, 1, function(v)
    SetMoneyDisplay(v * 1000)  -- 1 = $1K, 1000 = $1M
end)
Visuals:AddSlider("Money (M) — x1000000", 1, 999, 1, function(v)
    SetMoneyDisplay(v * 1000000)  -- 1 = $1M, 999 = $999M
end)
Visuals:AddSlider("Money (B) — x1000000000", 1, 999, 1, function(v)
    SetMoneyDisplay(v * 1000000000)
end)

Visuals:AddButton("$999,999,999,999", function() SetMoneyDisplay(999999999999) end)

Visuals:AddButton("Reset Money Display", function()
    pcall(function()
        local txt = LP.PlayerGui.ShillingsCurrency.CurrencyAmount.Text
        moneyLabel.Set("Balance:  " .. txt)
    end)
end)

-- ============================================================
--  EDIT INVENTORY  (display only — client side)
-- ============================================================
Visuals:AddSeparator("EDIT INVENTORY  (display only)")
Visuals:AddLabel("Changes shown count in your backpack/hand only", nil)

-- ── Edit Seed Count ─────────────────────────────────────────
local editSeedSelected = "Carrot Seed"
local editSeedCount    = 1

Visuals:AddDropdown("Seed to Edit", SEED_LIST, function(v)
    editSeedSelected = v
end)

Visuals:AddSlider("Seed Count", 1, 999, 1, function(v)
    editSeedCount = v
end)

Visuals:AddButton("Apply Seed Count", function()
    local bp   = LP:FindFirstChild("Backpack")
    local char = LP.Character
    local targetType = editSeedSelected:gsub("%s*Seed$",""):match("^%s*(.-)%s*$")

    local function tryEdit(container)
        if not container then return false end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local parsed = tool.Name:gsub("^x%d+%s*",""):gsub("%s*Seed$",""):match("^%s*(.-)%s*$")
                if parsed:lower() == targetType:lower() then
                    -- Rename to show new count
                    local newName = "x"..tostring(editSeedCount).." "..targetType.." Seed"
                    pcall(function() tool.Name = newName end)
                    return true
                end
            end
        end
        return false
    end

    -- Check backpack first, then character (equipped)
    if not tryEdit(bp) then tryEdit(char) end
end, "accent")

-- ── Edit Fruit Count in Hand ────────────────────────────────
Visuals:AddSeparator("")
local FRUIT_TYPES = {
    "Carrot","Corn","Onion","Strawberry","Mushroom",
    "Beetroot","Tomato","Apple","Rose","Wheat",
    "Banana","Plum","Potato","Cabbage","Cherry","Dawnfruit",
    "Silver Carrot"
}

local editFruitSelected = "Carrot"
local editFruitCount    = 1

Visuals:AddDropdown("Fruit to Edit", FRUIT_TYPES, function(v)
    editFruitSelected = v
end)

Visuals:AddSlider("Fruit Count", 1, 999, 1, function(v)
    editFruitCount = v
end)

Visuals:AddButton("Apply Fruit Count", function()
    local bp   = LP:FindFirstChild("Backpack")
    local char = LP.Character
    local target = editFruitSelected:lower()

    local function tryEditFruit(container)
        if not container then return false end
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                -- Match fruit tools: "Silver Carrot (0.06 KG)" or "Carrot" etc
                local baseName = tool.Name:gsub("%s*%(.*%)",""):match("^%s*(.-)%s*$"):lower()
                if baseName == target then
                    -- Build new name preserving any suffix like (0.06 KG)
                    local suffix = tool.Name:match("(%s*%b())")  or ""
                    local newName = "x"..tostring(editFruitCount).." "..editFruitSelected..suffix
                    pcall(function() tool.Name = newName end)
                    return true
                end
            end
        end
        return false
    end

    if not tryEditFruit(bp) then tryEditFruit(char) end
end, "accent")

-- ── ESP: Fruit Value in Inventory ───────────────────────────
Visuals:AddSeparator("FRUIT VALUE IN INVENTORY")
Visuals:AddLabel("Renames each fruit in backpack to show its $value", nil)
Visuals:AddLabel("e.g.  Plum (0.05 KG)  →  Plum (0.05 KG) [$20,893]", nil)

local _fruitValueOrigNames  = {}
local _fruitValueBillboards = {}
local _fruitValueConn       = nil

local function FormatFruitVal(num)
    if not num or num == 0 then return "$0" end
    if num >= 1e6 then return string.format("$%.2fM", num/1e6)
    elseif num >= 1e3 then return string.format("$%.1fK", num/1e3)
    else return "$"..tostring(math.floor(num)) end
end

local function ClearValueBillboards()
    for _, bb in ipairs(_fruitValueBillboards) do
        pcall(function() bb:Destroy() end)
    end
    _fruitValueBillboards = {}
end

-- Lookup table: cleanName (lower) = true, for fast inventory label matching
local _fruitValueLookup = {}

-- Called on any new TextLabel/Button added to PlayerGui (inventory open)
-- Colors the [$value] portion green using RichText, fruit name stays default
local function TryColorInventoryLabel(obj)
    if not _G.PHC_FruitValueESP then return end
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
    local txt = obj.Text
    if not txt or txt == "" then return end
    if not txt:find("%[%$") then return end  -- no value tag = skip
    local lower = txt:lower()
    for key in pairs(_fruitValueLookup) do
        if lower:find(key, 1, true) then
            pcall(function()
                obj.RichText = true
                -- Replace [$VALUE] with green colored version, leave fruit name white
                obj.Text = txt:gsub("(%[%$[^%]]*%])", '<font color="rgb(80,220,80)">%1</font>')
            end)
            break
        end
    end
end

local function ApplyFruitValueESP()
    ClearValueBillboards()
    _fruitValueLookup = {}

    local containers = { LP:FindFirstChild("Backpack"), LP.Character }
    for _, container in ipairs(containers) do
        if not container then continue end
        for _, tool in ipairs(container:GetChildren()) do
            if not tool:IsA("Tool") then continue end

            local val = nil
            pcall(function() val = tool:GetAttribute("FruitValue") end)
            if val == nil then continue end

            if not _fruitValueOrigNames[tool] then
                _fruitValueOrigNames[tool] = tool.Name
            end
            local origName = _fruitValueOrigNames[tool]
            local cleanName = origName:gsub("%s*%[%$[^%]]*%]$", "")
            local valStr = "$"..tostring(math.floor(val))
            pcall(function() tool.Name = cleanName .. " [" .. valStr .. "]" end)

            _fruitValueLookup[cleanName:lower()] = true

            -- Green BillboardGui when fruit is equipped (in character)
            local handle = tool:FindFirstChildWhichIsA("BasePart")
            if handle and tool.Parent == LP.Character then
                local bb = Instance.new("BillboardGui")
                bb.Adornee     = handle
                bb.AlwaysOnTop = true
                bb.Size        = UDim2.new(0, 140, 0, 22)
                bb.StudsOffset = Vector3.new(0, 2.5, 0)
                bb.MaxDistance = 30
                bb.Parent      = workspace

                local lbl = Instance.new("TextLabel")
                lbl.Size                   = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text                   = valStr
                lbl.TextColor3             = Color3.fromRGB(80, 220, 80)
                lbl.Font                   = Enum.Font.GothamBold
                lbl.TextSize               = 13
                lbl.TextXAlignment         = Enum.TextXAlignment.Center
                lbl.TextStrokeTransparency = 0.3
                lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
                lbl.TextTruncate           = Enum.TextTruncate.None
                lbl.Parent                 = bb

                table.insert(_fruitValueBillboards, bb)
                tool.AncestryChanged:Connect(function()
                    pcall(function() bb:Destroy() end)
                end)
            end
        end
    end
end

local function RestoreFruitValueESP()
    ClearValueBillboards()
    _fruitValueLookup = {}
    if _fruitValueConn then
        pcall(function() _fruitValueConn:Disconnect() end)
        _fruitValueConn = nil
    end
    for tool, origName in pairs(_fruitValueOrigNames) do
        pcall(function()
            if tool and tool.Parent then tool.Name = origName end
        end)
    end
    _fruitValueOrigNames = {}
end

_G.PHC_FruitValueESP = false
Visuals:AddToggle("ESP: Fruit Value in Inventory", false, function(on)
    _G.PHC_FruitValueESP = on
    if on then
        ApplyFruitValueESP()
        -- Hook DescendantAdded on PlayerGui: fires only when inventory GUI opens
        -- Zero FPS cost compared to polling all descendants every frame
        pcall(function()
            if _fruitValueConn then _fruitValueConn:Disconnect() end
            local pg = LP:FindFirstChild("PlayerGui")
            if pg then
                _fruitValueConn = pg.DescendantAdded:Connect(function(obj)
                    if _G.PHC_FruitValueESP then
                        task.wait()  -- 1 frame so Text property is populated
                        TryColorInventoryLabel(obj)
                    end
                end)
            end
        end)
        task.spawn(function()
            while _G.PHC_FruitValueESP do
                task.wait(3)
                if _G.PHC_FruitValueESP then ApplyFruitValueESP() end
            end
        end)
    else
        RestoreFruitValueESP()
    end
end)

Visuals:AddButton("Refresh Fruit Values Now", function()
    if _G.PHC_FruitValueESP then ApplyFruitValueESP() end
end)

-- ============================================================
--  ░░  EVENTS TAB  ░░
-- ============================================================
-- Categories: DAILY QUESTS | (more coming soon)
-- ============================================================

-- ── Helpers: read quest data from PlayerGui ─────────────────

local function GetQuestFrame(slot)
    -- slot = 1..5
    return pcall(function()
        return LP.PlayerGui.Quests.BG.ScrollingFrame[tostring(slot)]
    end)
end

local function ReadQuests()
    -- Returns array of {slot, name, reward, status, claimed, target, current, questType, subject}
    local quests = {}
    for slot = 1, 5 do
        local ok, frame = pcall(function()
            return LP.PlayerGui.Quests.BG.ScrollingFrame[tostring(slot)]
        end)
        if not ok or not frame then continue end

        local name    = ""
        local reward  = ""
        local status  = ""
        pcall(function() name   = frame.QuestName.Text   end)
        pcall(function() reward = frame.QuestReward.Text  end)
        pcall(function() status = frame.QuestStatus.Text  end)

        local claimed = (status == "Claimed!" or status == "Claim!")
        local current, target = 0, 0
        if not claimed then
            local c, t = status:match("(%d+)/(%d+)")
            current = tonumber(c) or 0
            target  = tonumber(t) or 0
        end

        -- Parse quest type from name
        -- Patterns: "Plant X [Seed] Seeds", "Harvest X [Fruit]s", "Earn X Shillings"
        local questType = "unknown"
        local subject   = ""
        local amount    = 0

        local plantSeed = name:match("Plant (%d+) (.+) Seeds?")
        local harvest   = name:match("Harvest (%d+) (.+)")
        local earn      = name:match("Earn (%d+) Shillings?")

        if plantSeed then
            amount = tonumber(plantSeed) or target
            subject = name:match("Plant %d+ (.+) Seeds?") or ""
            -- subject is like "Onion", "Corn", "Rose" etc
            subject = subject:match("^%s*(.-)%s*$")
            questType = "plant"
        elseif harvest then
            amount = tonumber(harvest) or target
            subject = name:match("Harvest %d+ (.+)") or ""
            subject = subject:gsub("s$",""):match("^%s*(.-)%s*$")  -- strip trailing 's'
            questType = "harvest"
        elseif earn then
            amount = tonumber(earn) or target
            questType = "earn"
        end

        table.insert(quests, {
            slot      = slot,
            name      = name,
            reward    = reward,
            status    = status,
            claimed   = claimed,
            current   = current,
            target    = target,
            questType = questType,
            subject   = subject,
            amount    = amount,
        })
    end
    return quests
end

-- Click the Claim button for a quest slot
local function ClaimQuest(slot)
    pcall(function()
        local frame = LP.PlayerGui.Quests.BG.ScrollingFrame[tostring(slot)]
        local claim = frame and frame:FindFirstChild("Claim")
        if claim then
            -- Try as ImageButton / TextButton
            if claim:IsA("GuiButton") then
                local fire = claim.MouseButton1Click
                if fire then fire:Fire() end
            end
            -- Try fireproximityprompt if it's a ProximityPrompt
            if claim:IsA("ProximityPrompt") then
                pcall(function() fireproximityprompt(claim) end)
            end
            -- Also try clicking children buttons
            for _, child in ipairs(claim:GetDescendants()) do
                if child:IsA("GuiButton") then
                    pcall(function() child.MouseButton1Click:Fire() end)
                end
            end
        end
    end)
end

-- ── Quest display label (live refresh) ──────────────────────

Events:AddSeparator("DAILY QUESTS")
Events:AddLabel("Quests reset daily — auto-detected from game UI", nil)

local questDisplayLabels = {}
for i = 1, 5 do
    questDisplayLabels[i] = Events:AddLabel("Quest "..i..": loading...", nil)
end

local function RefreshQuestDisplay()
    local quests = ReadQuests()
    for i, q in ipairs(quests) do
        if questDisplayLabels[i] then
            local statusStr = q.claimed and "✓ Claimed" or (q.target > 0 and (q.current.."/"..q.target) or q.status)
            local text = "Q"..q.slot..": "..q.name.." | "..statusStr
            pcall(function() questDisplayLabels[i].Set(text) end)
        end
    end
    -- Fill any missing
    for i = #quests + 1, 5 do
        if questDisplayLabels[i] then
            pcall(function() questDisplayLabels[i].Set("Quest "..i..": (none)") end)
        end
    end
end

Events:AddButton("Refresh Quest List", function()
    RefreshQuestDisplay()
end)

-- Auto-refresh quest display every 5s
task.spawn(function()
    task.wait(3)  -- wait for game to load
    while true do
        pcall(RefreshQuestDisplay)
        task.wait(5)
    end
end)

-- ── Claim All Completed ──────────────────────────────────────
Events:AddButton("Claim All Completed Quests", function()
    local quests = ReadQuests()
    for _, q in ipairs(quests) do
        if not q.claimed and q.target > 0 and q.current >= q.target then
            ClaimQuest(q.slot)
            task.wait(0.5)
        end
    end
    task.wait(0.5)
    RefreshQuestDisplay()
end, "accent")

-- ── Auto Complete Daily Quests ───────────────────────────────
Events:AddSeparator("AUTO COMPLETE QUESTS")
Events:AddLabel("Reads each quest and auto-does the required action", nil)
Events:AddLabel("Teleports to garden → does action → returns to Quest Board", nil)

_G.PHC_AutoQuests = false
Events:AddToggle("Auto Complete Daily Quests", false, function(on)
    _G.PHC_AutoQuests = on
    if not on then return end

    task.spawn(function()
        while _G.PHC_AutoQuests do
            local quests = ReadQuests()
            local allDone = true

            for _, q in ipairs(quests) do
                if not _G.PHC_AutoQuests then break end
                if q.claimed then continue end

                -- Check if already completed — TP to quest board and claim
                if q.target > 0 and q.current >= q.target then
                    local hrpC = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if hrpC then hrpC.CFrame = QUEST_BOARD_CF end
                    task.wait(0.5)
                    ClaimQuest(q.slot)
                    task.wait(0.5)
                    continue
                end

                allDone = false
                local needed = q.target - q.current

                -- Save position before doing quest action
                local hrp     = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                local savedCF = hrp and hrp.CFrame

                -- ── PLANT quests ──
                if q.questType == "plant" and needed > 0 then
                    -- TP to garden center to plant
                    if hrp then hrp.CFrame = GARDEN_CENTER_CF end
                    task.wait(0.4)
                    hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    local seedName = q.subject .. " Seed"
                    if hrp then
                        for attempt = 1, needed do
                            if not _G.PHC_AutoQuests then break end
                            local tool = FindBackpackSeed(seedName)
                            if not tool then break end
                            EquipSeed(tool)
                            task.wait(0.1)
                            local pos = hrp.Position + Vector3.new(
                                math.random(-5,5), 0, math.random(-5,5)
                            )
                            pcall(function()
                                ReplicatedStorage.RemoteEvents.PlantSeed:InvokeServer(q.subject, pos)
                            end)
                            task.wait(0.4)
                        end
                    end

                -- ── HARVEST quests ──
                elseif q.questType == "harvest" and needed > 0 then
                    -- TP near plants of that type
                    local cp = workspace:FindFirstChild("ClientPlants")
                    if cp then
                        -- Find a matching plant and TP near it first
                        for _, plant in ipairs(cp:GetChildren()) do
                            if plant.Name:lower():find(q.subject:lower()) then
                                local plantBase = plant:FindFirstChildWhichIsA("BasePart", true)
                                if plantBase then
                                    local phrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                                    if phrp then
                                        phrp.CFrame = CFrame.new(plantBase.Position + Vector3.new(0, 3, 0))
                                    end
                                    task.wait(0.3)
                                end
                                break
                            end
                        end

                        hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                        local harvested = 0
                        for _, plant in ipairs(cp:GetChildren()) do
                            if not _G.PHC_AutoQuests then break end
                            if harvested >= needed then break end
                            if plant.Name:lower():find(q.subject:lower()) then
                                -- TP to each plant before harvesting
                                local plantBase = plant:FindFirstChildWhichIsA("BasePart", true)
                                if plantBase and hrp then
                                    hrp.CFrame = CFrame.new(plantBase.Position + Vector3.new(0, 3, 0))
                                    task.wait(0.2)
                                end
                                for _, fruit in ipairs(plant:GetChildren()) do
                                    if harvested >= needed then break end
                                    if fruit.Name:match("^Fruit") then
                                        for _, desc in ipairs(fruit:GetDescendants()) do
                                            if desc.Name == "HarvestPrompt" then
                                                pcall(function() fireproximityprompt(desc) end)
                                                harvested = harvested + 1
                                                task.wait(0.3)
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                -- ── EARN quests ──
                elseif q.questType == "earn" and needed > 0 then
                    -- TP to sell stand to sell
                    hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then hrp.CFrame = SELL_STAND_CF end
                    task.wait(0.4)
                    pcall(function()
                        ReplicatedStorage.RemoteEvents.SellItems:InvokeServer("SellAll")
                    end)
                    task.wait(0.5)
                end

                -- TP back to Quest Board to claim
                task.wait(0.5)
                local hrpBack = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrpBack then hrpBack.CFrame = QUEST_BOARD_CF end
                task.wait(0.5)

                local updated = ReadQuests()
                for _, uq in ipairs(updated) do
                    if uq.slot == q.slot and uq.target > 0 and uq.current >= uq.target then
                        ClaimQuest(q.slot)
                        task.wait(0.5)
                        break
                    end
                end

                -- Return to saved position after claiming
                if savedCF then
                    local hrpRet = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if hrpRet then hrpRet.CFrame = savedCF end
                end
            end

            if allDone then
                task.wait(60)
            else
                task.wait(2)
            end
        end
    end)
end)

Events:AddButton("Do Quests Once (All)", function()
    task.spawn(function()
        local quests = ReadQuests()
        for _, q in ipairs(quests) do
            if q.claimed then continue end

            if q.questType == "plant" then
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    for attempt = 1, math.max(1, q.target - q.current) do
                        local tool = FindBackpackSeed(q.subject .. " Seed")
                        if not tool then break end
                        EquipSeed(tool)
                        task.wait(0.1)
                        local pos = hrp.Position + Vector3.new(math.random(-5,5), 0, math.random(-5,5))
                        pcall(function()
                            ReplicatedStorage.RemoteEvents.PlantSeed:InvokeServer(q.subject, pos)
                        end)
                        task.wait(0.3)
                    end
                end

            elseif q.questType == "harvest" then
                local cp = workspace:FindFirstChild("ClientPlants")
                if cp then
                    local done = 0
                    for _, plant in ipairs(cp:GetChildren()) do
                        if done >= (q.target - q.current) then break end
                        if plant.Name:lower():find(q.subject:lower()) then
                            for _, fruit in ipairs(plant:GetChildren()) do
                                if fruit.Name:match("^Fruit") then
                                    for _, desc in ipairs(fruit:GetDescendants()) do
                                        if desc.Name == "HarvestPrompt" then
                                            pcall(function() fireproximityprompt(desc) end)
                                            done = done + 1
                                            task.wait(0.2)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

            elseif q.questType == "earn" then
                pcall(function()
                    ReplicatedStorage.RemoteEvents.SellItems:InvokeServer("SellAll")
                end)
                task.wait(0.5)
            end

            task.wait(0.5)
            ClaimQuest(q.slot)
            task.wait(0.3)
        end
        RefreshQuestDisplay()
    end)
end)

-- Placeholder separator for future event categories
Events:AddSeparator("MORE EVENTS")
Events:AddLabel("More event categories coming soon...", nil)

-- ============================================================
--  SHOW
-- ============================================================
Window:Show()

UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightShift then
        Window:Toggle()
    end
end)