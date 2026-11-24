local UILib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Zack1211/PHCzackScript/refs/heads/main/AngpaoUILib.lua"))()

local Window = UILib:CreateWindow({
	Title = "AngpaoHub",
	Subtitle = "v1.2.0 • Auto Farm",
	Section = "Main",
	FloatingText = "🧧  Angpao UI"
})

local CollectorTab = Window:CreateTab("Collector", "🧧")
local SettingsTab = Window:CreateTab("Settings", "⚙")

local FarmCard = CollectorTab:CreateCard({
	Title = "Angpao Auto Farm",
	Badge = "Idle",
	Side = "Left"
})

local targetLbl = FarmCard:AddLabel("Targets in AngpaoLocal: 0")
local sessionLbl = FarmCard:AddLabel("Collected this session: 0")

FarmCard:AddCheckbox({
	Text = "Auto Collect All Angpao",
	Default = false,
	Callback = function(enabled)
		print("Auto Collect:", enabled)
		FarmCard:SetBadge(enabled and "Running" or "Idle", enabled and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(161, 161, 170))
		Window:SetStatus(enabled and "Collecting..." or "Idle")
	end
})

local MoveCard = CollectorTab:CreateCard({
	Title = "Movement & Hopping",
	Badge = "Walk",
	Side = "Right"
})

MoveCard:AddSegmented({
	Text = "Movement Method",
	Options = { "Walk", "Teleport" },
	Default = "Walk",
	Callback = function(selected)
		MoveCard:SetBadge(selected)
		Window:Notify("Movement Changed", "Switched to " .. selected, 2.5)
	end
})

MoveCard:AddButton({
	Text = "Test Notification",
	Accent = true,
	Callback = function()
		Window:Notify("AngpaoHub", "Library working smoothly!", 3)
	end
})

local CfgCard = SettingsTab:CreateCard({
	Title = "Interface",
	Badge = "UI",
	Side = "Left"
})

CfgCard:AddButton({
	Text = "Unload UI",
	Accent = true,
	Callback = function()
		Window:Destroy()
	end
})

-- Example live telemetry update
task.spawn(function()
	while task.wait(0.5) do
		Window:SetTelemetry(string.format("%d fps  •  0 Angpao", Window:GetFps()))
	end
end)
