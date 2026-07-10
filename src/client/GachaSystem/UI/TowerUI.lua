-- TowerUI — Endless Tower hub panel: floor counter, best floor, next milestone,
-- FIGHT and ABANDON. Battles themselves play in BattleUI.

local TowerUI = {}

local panel, floorLbl, bestLbl, milestoneLbl, fightBtn, abandonBtn
local callbacks = {}
local TowerConfig

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function nextMilestoneText(floor)
	-- Find the next floor with a pack reward.
	for f = floor + 1, floor + 30 do
		local packs = TowerConfig.Milestones[f]
		if not packs and f > 20 and f % TowerConfig.RepeatEvery == 0 then
			packs = TowerConfig.RepeatPacks
		end
		if packs then
			local parts = {}
			for packType, n in pairs(packs) do
				table.insert(parts, n .. "x " .. packType:gsub("Pack", " Pack"))
			end
			return "Floor " .. f .. ": " .. table.concat(parts, ", ")
		end
	end
	return ""
end

function TowerUI:Init(gui, towerConfig, cbs)
	TowerConfig = towerConfig
	callbacks = cbs or {}

	panel = Instance.new("Frame")
	panel.Name = "TowerPanel"
	panel.Size = UDim2.new(0, 340, 0, 300)
	panel.Position = UDim2.new(0.5, -170, 0.5, -150)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.ZIndex = 25
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(110, 100, 220); stroke.Thickness = 1; stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 32); title.Position = UDim2.new(0, 16, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "ENDLESS TOWER"
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

	floorLbl = Instance.new("TextLabel")
	floorLbl.Size = UDim2.new(1, -32, 0, 64); floorLbl.Position = UDim2.new(0, 16, 0, 52)
	floorLbl.BackgroundTransparency = 1
	floorLbl.TextColor3 = Color3.fromRGB(240, 240, 255)
	floorLbl.TextScaled = true; floorLbl.Font = Enum.Font.GothamBlack
	floorLbl.ZIndex = 26; floorLbl.Parent = panel

	bestLbl = Instance.new("TextLabel")
	bestLbl.Size = UDim2.new(1, -32, 0, 22); bestLbl.Position = UDim2.new(0, 16, 0, 120)
	bestLbl.BackgroundTransparency = 1
	bestLbl.TextColor3 = Color3.fromRGB(160, 160, 190)
	bestLbl.TextScaled = true; bestLbl.Font = Enum.Font.Gotham
	bestLbl.ZIndex = 26; bestLbl.Parent = panel

	milestoneLbl = Instance.new("TextLabel")
	milestoneLbl.Size = UDim2.new(1, -32, 0, 20); milestoneLbl.Position = UDim2.new(0, 16, 0, 148)
	milestoneLbl.BackgroundTransparency = 1
	milestoneLbl.TextColor3 = Color3.fromRGB(200, 180, 100)
	milestoneLbl.TextScaled = true; milestoneLbl.Font = Enum.Font.Gotham
	milestoneLbl.ZIndex = 26; milestoneLbl.Parent = panel

	fightBtn = Instance.new("TextButton")
	fightBtn.Size = UDim2.new(1, -32, 0, 56); fightBtn.Position = UDim2.new(0, 16, 0, 182)
	fightBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	fightBtn.BorderSizePixel = 0
	fightBtn.TextColor3 = Color3.new(1, 1, 1)
	fightBtn.TextScaled = true; fightBtn.Font = Enum.Font.GothamBlack
	fightBtn.ZIndex = 26; fightBtn.Parent = panel
	corner(fightBtn, 10)
	fightBtn.MouseButton1Click:Connect(function()
		if callbacks.onFight then callbacks.onFight() end
	end)

	abandonBtn = Instance.new("TextButton")
	abandonBtn.Size = UDim2.new(1, -32, 0, 34); abandonBtn.Position = UDim2.new(0, 16, 0, 250)
	abandonBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	abandonBtn.BorderSizePixel = 0
	abandonBtn.Text = "ABANDON RUN"
	abandonBtn.TextColor3 = Color3.fromRGB(200, 150, 150)
	abandonBtn.TextScaled = true; abandonBtn.Font = Enum.Font.GothamBold
	abandonBtn.ZIndex = 26; abandonBtn.Parent = panel
	corner(abandonBtn, 8)
	abandonBtn.MouseButton1Click:Connect(function()
		if callbacks.onAbandon then callbacks.onAbandon() end
	end)
end

-- run: state snapshot from Tower_GetState / Tower_Start.
function TowerUI:Update(run)
	local floor = run and run.floor or 0
	local nextFloor = floor + 1
	floorLbl.Text = "FLOOR " .. nextFloor
	bestLbl.Text = "Best: Floor " .. (run and run.bestFloor or 0) .. "   •   Cleared: " .. floor
	milestoneLbl.Text = nextMilestoneText(floor)
	local isBoss = nextFloor % TowerConfig.Enemies.BossEvery == 0
	fightBtn.Text = isBoss and ("FIGHT FLOOR " .. nextFloor .. "  (BOSS)") or ("FIGHT FLOOR " .. nextFloor)
	fightBtn.BackgroundColor3 = isBoss and Color3.fromRGB(200, 90, 40) or Color3.fromRGB(180, 60, 60)
end

function TowerUI:SetBusy(busy)
	fightBtn.Active = not busy
	fightBtn.AutoButtonColor = not busy
	fightBtn.TextTransparency = busy and 0.5 or 0
end

function TowerUI:Show()
	panel.Visible = true
end

function TowerUI:Hide()
	panel.Visible = false
end

function TowerUI:GetPanel()
	return panel
end

return TowerUI
