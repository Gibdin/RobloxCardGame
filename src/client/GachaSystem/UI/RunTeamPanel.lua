-- RunTeamPanel — thin strip shown during a run (docked above GlobalTeamBar):
-- one chip per team card with role glyph, rarity-tinted name, level badge,
-- HP + XP bars, and buff/item pip counts. Shared by tower and dungeon modes.

local TweenService = game:GetService("TweenService")

local FxUtil = require(script.Parent.FxUtil)

local RunTeamPanel = {}

local panel
local chips = {}   -- [cardId] = { frame, hpBar, xpBar, lvlLabel, scale }
local CardDatabase, RarityConfig, RoleConfig, DungeonConfig
local Sound = { Play = function() end }

local HP_HI = Color3.fromRGB(70, 200, 110)
local HP_LO = Color3.fromRGB(210, 70, 60)
local XP_COL = Color3.fromRGB(170, 140, 255)

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = inst
end

function RunTeamPanel:Init(gui, cardDb, rarityConf, roleConf, dungeonConf, soundManager)
	CardDatabase = cardDb
	RarityConfig = rarityConf
	RoleConfig = roleConf
	DungeonConfig = dungeonConf
	if soundManager then Sound = soundManager end

	panel = Instance.new("Frame")
	panel.Name = "RunTeamPanel"
	panel.Size = UDim2.new(0, 470, 0, 62)
	panel.Position = UDim2.new(0.5, -235, 1, -200)
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

-- run: state snapshot { team = {ids/false}, cards = { [tostring(id)] = {level, xp, hpPct, items, buffs} } }
function RunTeamPanel:Update(run)
	for _, chip in pairs(chips) do chip.frame:Destroy() end
	chips = {}
	if not run then return end

	for _, id in ipairs(run.team) do
		if id then
			local cs = run.cards[tostring(id)] or {}
			local card = CardDatabase:GetById(id)
			local rarityDef = card and RarityConfig and RarityConfig.Rarities[card.rarity]
			local rarityColor = rarityDef and rarityDef.color or Color3.fromRGB(120, 120, 140)
			local roleDef = card and RoleConfig and RoleConfig.Roles[card.role]

			local f = Instance.new("Frame")
			f.Size = UDim2.new(0, 86, 0, 52)
			f.BackgroundColor3 = Color3.fromRGB(24, 24, 42)
			f.BackgroundTransparency = 0.1
			f.BorderSizePixel = 0
			f.ZIndex = 23
			f.Parent = panel
			corner(f, 8)
			local scale = Instance.new("UIScale"); scale.Parent = f

			-- Rarity-tinted name strip with a role glyph.
			local strip = Instance.new("Frame")
			strip.Size = UDim2.new(1, 0, 0, 18)
			strip.BackgroundColor3 = rarityColor
			strip.BackgroundTransparency = 0.45
			strip.BorderSizePixel = 0
			strip.ZIndex = 23
			strip.Parent = f
			corner(strip, 8)
			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new(rarityColor, rarityColor:Lerp(Color3.new(0, 0, 0), 0.5))
			grad.Rotation = 90
			grad.Parent = strip

			local glyph = Instance.new("TextLabel")
			glyph.Size = UDim2.new(0, 14, 0, 14); glyph.Position = UDim2.new(0, 2, 0, 2)
			glyph.BackgroundTransparency = 1
			glyph.Text = roleDef and roleDef.icon or ""
			glyph.TextSize = 11
			glyph.Font = Enum.Font.GothamBold
			glyph.TextColor3 = Color3.new(1, 1, 1)
			glyph.ZIndex = 25; glyph.Parent = f

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(1, -44, 0, 14); name.Position = UDim2.new(0, 17, 0, 2)
			name.BackgroundTransparency = 1
			name.Text = card and card.name or ("#" .. id)
			name.TextColor3 = Color3.fromRGB(240, 240, 250)
			name.TextScaled = true; name.Font = Enum.Font.GothamBold
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.ZIndex = 25; name.Parent = f

			local lvl = Instance.new("TextLabel")
			lvl.Size = UDim2.new(0, 26, 0, 14); lvl.Position = UDim2.new(1, -28, 0, 2)
			lvl.BackgroundColor3 = Color3.fromRGB(60, 50, 110)
			lvl.Text = "L" .. (cs.level or 1)
			lvl.TextColor3 = Color3.fromRGB(230, 225, 255)
			lvl.TextScaled = true; lvl.Font = Enum.Font.GothamBold
			lvl.BorderSizePixel = 0
			lvl.ZIndex = 25; lvl.Parent = f
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

			-- XP progress toward the next level.
			local xpHolder = Instance.new("Frame")
			xpHolder.Size = UDim2.new(1, -8, 0, 4); xpHolder.Position = UDim2.new(0, 4, 0, 32)
			xpHolder.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
			xpHolder.BorderSizePixel = 0
			xpHolder.ZIndex = 24; xpHolder.Parent = f
			corner(xpHolder, 2)
			local xpRatio = 0
			if DungeonConfig then
				local needed = DungeonConfig.Levels.XpForLevel(cs.level or 1)
				local atCap = (cs.level or 1) >= DungeonConfig.Levels.Cap
				xpRatio = atCap and 1 or math.clamp((cs.xp or 0) / needed, 0, 1)
			end
			local xpBar = Instance.new("Frame")
			xpBar.Size = UDim2.new(xpRatio, 0, 1, 0)
			xpBar.BackgroundColor3 = XP_COL
			xpBar.BorderSizePixel = 0
			xpBar.ZIndex = 25; xpBar.Parent = xpHolder
			corner(xpBar, 2)

			local pips = Instance.new("TextLabel")
			pips.Size = UDim2.new(1, -8, 0, 13); pips.Position = UDim2.new(0, 4, 0, 38)
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

			chips[id] = { frame = f, hpBar = hpBar, xpBar = xpBar, lvlLabel = lvl, scale = scale }
		end
	end
end

-- Plays level-up fanfare on chips after Update() has set the final state.
-- xpReport: { [tostring(cardId)] = { gained, level, leveledUp } } from the server.
function RunTeamPanel:PlayXpGains(xpReport)
	if not xpReport then return end
	local delay = 0
	for idStr, rep in pairs(xpReport) do
		local chip = chips[tonumber(idStr)]
		if chip and rep.leveledUp then
			delay = delay + 0.15
			task.delay(delay, function()
				if not chip.frame.Parent then return end
				Sound:Play("level_up")
				FxUtil.floatText(chip.frame, "LEVEL UP!", Color3.fromRGB(255, 225, 130), { yStart = 0 })
				chip.lvlLabel.BackgroundColor3 = Color3.fromRGB(220, 170, 50)
				TweenService:Create(chip.lvlLabel, TweenInfo.new(0.8), { BackgroundColor3 = Color3.fromRGB(60, 50, 110) }):Play()
				chip.scale.Scale = 1.18
				TweenService:Create(chip.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)
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
