-- RunTeamPanel — thin strip shown during a run (docked above GlobalTeamBar):
-- one chip per team card with level badge, HP bar, and buff/item pip counts.
-- Shared by tower and dungeon modes.

local TweenService = game:GetService("TweenService")

local RunTeamPanel = {}

local panel
local chips = {}   -- [cardId] = { frame, hpBar, lvlLbl, pipsLbl }
local CardDatabase

local HP_HI = Color3.fromRGB(70, 200, 110)
local HP_LO = Color3.fromRGB(210, 70, 60)

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = inst
end

function RunTeamPanel:Init(gui, cardDb)
	CardDatabase = cardDb

	panel = Instance.new("Frame")
	panel.Name = "RunTeamPanel"
	panel.Size = UDim2.new(0, 470, 0, 58)
	panel.Position = UDim2.new(0.5, -235, 1, -196)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.ZIndex = 22
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 10)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel
end

-- run: state snapshot { team = {ids/false}, cards = { [tostring(id)] = {level, hpPct, items, buffs} } }
function RunTeamPanel:Update(run)
	for _, chip in pairs(chips) do chip.frame:Destroy() end
	chips = {}
	if not run then return end

	for _, id in ipairs(run.team) do
		if id then
			local cs = run.cards[tostring(id)] or {}
			local card = CardDatabase:GetById(id)

			local f = Instance.new("Frame")
			f.Size = UDim2.new(0, 86, 0, 48)
			f.BackgroundColor3 = Color3.fromRGB(24, 24, 42)
			f.BackgroundTransparency = 0.1
			f.BorderSizePixel = 0
			f.ZIndex = 23
			f.Parent = panel
			corner(f, 8)

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(1, -30, 0, 16); name.Position = UDim2.new(0, 4, 0, 2)
			name.BackgroundTransparency = 1
			name.Text = card and card.name or ("#" .. id)
			name.TextColor3 = Color3.fromRGB(220, 220, 240)
			name.TextScaled = true; name.Font = Enum.Font.GothamBold
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.ZIndex = 24; name.Parent = f

			local lvl = Instance.new("TextLabel")
			lvl.Size = UDim2.new(0, 26, 0, 16); lvl.Position = UDim2.new(1, -28, 0, 2)
			lvl.BackgroundColor3 = Color3.fromRGB(60, 50, 110)
			lvl.Text = "L" .. (cs.level or 1)
			lvl.TextColor3 = Color3.fromRGB(230, 225, 255)
			lvl.TextScaled = true; lvl.Font = Enum.Font.GothamBold
			lvl.BorderSizePixel = 0
			lvl.ZIndex = 24; lvl.Parent = f
			corner(lvl, 4)

			local hpHolder = Instance.new("Frame")
			hpHolder.Size = UDim2.new(1, -8, 0, 8); hpHolder.Position = UDim2.new(0, 4, 0, 22)
			hpHolder.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
			hpHolder.BorderSizePixel = 0
			hpHolder.ZIndex = 24; hpHolder.Parent = f
			corner(hpHolder, 3)
			local hpPct = math.clamp(cs.hpPct or 1, 0, 1)
			local hpBar = Instance.new("Frame")
			hpBar.Size = UDim2.new(hpPct, 0, 1, 0)
			hpBar.BackgroundColor3 = HP_LO:Lerp(HP_HI, hpPct)
			hpBar.BorderSizePixel = 0
			hpBar.ZIndex = 25; hpBar.Parent = hpHolder
			corner(hpBar, 3)

			local pips = Instance.new("TextLabel")
			pips.Size = UDim2.new(1, -8, 0, 14); pips.Position = UDim2.new(0, 4, 0, 32)
			pips.BackgroundTransparency = 1
			local nBuffs = #(cs.buffs or {})
			local nItems = #(cs.items or {})
			local parts = {}
			if nBuffs > 0 then table.insert(parts, "B" .. nBuffs) end
			if nItems > 0 then table.insert(parts, "I" .. nItems) end
			pips.Text = table.concat(parts, "  ")
			pips.TextColor3 = Color3.fromRGB(255, 210, 110)
			pips.TextScaled = true; pips.Font = Enum.Font.GothamBold
			pips.TextXAlignment = Enum.TextXAlignment.Left
			pips.ZIndex = 24; pips.Parent = f

			chips[id] = { frame = f, hpBar = hpBar }
		end
	end
end

function RunTeamPanel:Show()
	panel.Visible = true
end

function RunTeamPanel:Hide()
	panel.Visible = false
end

return RunTeamPanel
