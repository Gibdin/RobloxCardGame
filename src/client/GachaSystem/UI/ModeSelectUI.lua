-- ModeSelectUI — compact battle mode picker: Dungeon Run | Endless Tower.
-- Shows resume state and the tower best-floor record.

local ModeSelectUI = {}

local panel, dungeonBtn, towerBtn, towerSub, dungeonSub
local callbacks = {}

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function modeButton(parent, y, title, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -32, 0, 74)
	b.Position = UDim2.new(0, 16, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(24, 24, 40)
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = true
	b.ZIndex = 26
	b.Parent = parent
	corner(b, 10)
	local stroke = Instance.new("UIStroke"); stroke.Color = color; stroke.Thickness = 2; stroke.Parent = b

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -20, 0, 32); titleLbl.Position = UDim2.new(0, 10, 0, 10)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = Color3.fromRGB(235, 235, 250)
	titleLbl.TextScaled = true; titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 27; titleLbl.Parent = b

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -20, 0, 20); sub.Position = UDim2.new(0, 10, 0, 44)
	sub.BackgroundTransparency = 1
	sub.Text = ""
	sub.TextColor3 = Color3.fromRGB(150, 150, 180)
	sub.TextScaled = true; sub.Font = Enum.Font.Gotham
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.ZIndex = 27; sub.Parent = b

	return b, sub
end

function ModeSelectUI:Init(gui, cbs)
	callbacks = cbs or {}

	panel = Instance.new("Frame")
	panel.Name = "ModeSelectPanel"
	panel.Size = UDim2.new(0, 340, 0, 260)
	panel.Position = UDim2.new(0.5, -170, 0.5, -130)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.ZIndex = 25
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(45, 45, 70); stroke.Thickness = 1; stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 36); title.Position = UDim2.new(0, 16, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "BATTLE"
	title.TextColor3 = Color3.fromRGB(220, 220, 245)
	title.TextScaled = true; title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 26; title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -40, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true; closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 26; closeBtn.Parent = panel
	corner(closeBtn, 6)
	closeBtn.MouseButton1Click:Connect(function() self:Hide() end)

	dungeonBtn, dungeonSub = modeButton(panel, 56, "DUNGEON RUN", Color3.fromRGB(200, 120, 60))
	towerBtn, towerSub = modeButton(panel, 146, "ENDLESS TOWER", Color3.fromRGB(110, 100, 220))

	dungeonBtn.MouseButton1Click:Connect(function()
		if callbacks.onDungeon then callbacks.onDungeon() end
	end)
	towerBtn.MouseButton1Click:Connect(function()
		if callbacks.onTower then callbacks.onTower() end
	end)
end

-- info: { towerBest = n, towerActive = bool, dungeonActive = bool, dungeonReady = bool }
function ModeSelectUI:Show(info)
	info = info or {}
	towerSub.Text = info.towerActive and "Run in progress — tap to resume"
		or ("Best: Floor " .. (info.towerBest or 0))
	if info.dungeonReady == false then
		dungeonSub.Text = "Coming Soon"
	else
		dungeonSub.Text = info.dungeonActive and "Run in progress — tap to resume"
			or "Branching map • shops • elites • boss"
	end
	panel.Visible = true
end

function ModeSelectUI:Hide()
	panel.Visible = false
end

function ModeSelectUI:GetPanel()
	return panel
end

return ModeSelectUI
