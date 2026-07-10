-- BattleUI — battle playback panel. Pure view: the server event log drives
-- everything through the imperative primitives below; no combat math happens
-- here. Centered large panel (not fullscreen), GlobalTeamBar stays visible.

local TweenService = game:GetService("TweenService")

local BattleUI = {}

local panel, headerRound, headerFloor, speedBtn, skipBtn
local enemyRow, playerRow, toastLabel, resultOverlay
local frames = {}        -- ["P3"] = { frame, hpBar, hpText, mpBar, shieldBar, scale, unit }
local screenGui
local CardDatabase, RarityConfig
local speedIndex = 1
local speeds = { 1, 2 }
local onSkip

local BG      = Color3.fromRGB(14, 14, 24)
local HP_HI   = Color3.fromRGB(70, 200, 110)
local HP_LO   = Color3.fromRGB(210, 70, 60)
local MP_COL  = Color3.fromRGB(80, 140, 240)
local SH_COL  = Color3.fromRGB(200, 220, 255)

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function key(refT) return refT.side .. refT.slot end

-- ── Unit frames ───────────────────────────────────────────────────────────────

local function buildUnitFrame(parent, unit, order)
	local card = CardDatabase:GetById(unit.cardId)
	local rarityColor = card and RarityConfig.Rarities[card.rarity] and RarityConfig.Rarities[card.rarity].color
		or Color3.fromRGB(150, 150, 150)

	local f = Instance.new("Frame")
	f.Size = UDim2.new(0.18, 0, 0.9, 0)
	f.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.ZIndex = 31
	f.Parent = parent
	corner(f, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityColor; stroke.Thickness = 2; stroke.Parent = f

	local scale = Instance.new("UIScale"); scale.Parent = f

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -8, 0.3, 0); name.Position = UDim2.new(0, 4, 0, 2)
	name.BackgroundTransparency = 1
	name.Text = unit.name
	name.TextColor3 = Color3.fromRGB(225, 225, 245)
	name.TextScaled = true; name.TextWrapped = true
	name.Font = Enum.Font.GothamBold
	name.ZIndex = 32; name.Parent = f

	local function bar(yScale, height, color, bgTrans)
		local holder = Instance.new("Frame")
		holder.Size = UDim2.new(1, -12, 0, height)
		holder.Position = UDim2.new(0, 6, yScale, 0)
		holder.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
		holder.BackgroundTransparency = bgTrans or 0.2
		holder.BorderSizePixel = 0; holder.ZIndex = 32; holder.Parent = f
		corner(holder, 4)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(1, 0, 1, 0)
		fill.BackgroundColor3 = color
		fill.BorderSizePixel = 0; fill.ZIndex = 33; fill.Parent = holder
		corner(fill, 4)
		return holder, fill
	end

	local _, hpBar = bar(0.42, 14, HP_HI)
	local hpText = Instance.new("TextLabel")
	hpText.Size = UDim2.new(1, -12, 0, 14); hpText.Position = UDim2.new(0, 6, 0.42, 0)
	hpText.BackgroundTransparency = 1
	hpText.Text = unit.hp .. "/" .. unit.maxHp
	hpText.TextColor3 = Color3.fromRGB(240, 240, 250)
	hpText.TextScaled = true; hpText.Font = Enum.Font.GothamBold
	hpText.ZIndex = 34; hpText.Parent = f

	local _, shieldBar = bar(0.62, 6, SH_COL, 0.6)
	shieldBar.Size = UDim2.new(0, 0, 1, 0)
	local _, mpBar = bar(0.74, 8, MP_COL)
	mpBar.Size = UDim2.new(unit.maxMp > 0 and unit.mp / unit.maxMp or 0, 0, 1, 0)

	local role = Instance.new("TextLabel")
	role.Size = UDim2.new(1, -8, 0.12, 0); role.Position = UDim2.new(0, 4, 0.86, 0)
	role.BackgroundTransparency = 1
	role.Text = unit.role
	role.TextColor3 = Color3.fromRGB(140, 140, 170)
	role.TextScaled = true; role.Font = Enum.Font.Gotham
	role.ZIndex = 32; role.Parent = f

	return {
		frame = f, hpBar = hpBar, hpText = hpText, mpBar = mpBar,
		shieldBar = shieldBar, scale = scale,
		maxHp = unit.maxHp, maxMp = unit.maxMp,
	}
end

local function setHpVisual(entry, newHp, newShield)
	local ratio = math.clamp(newHp / entry.maxHp, 0, 1)
	TweenService:Create(entry.hpBar, TweenInfo.new(0.2), {
		Size = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = HP_LO:Lerp(HP_HI, ratio),
	}):Play()
	entry.hpText.Text = newHp .. "/" .. entry.maxHp
	if newShield ~= nil then
		local sRatio = math.clamp(newShield / entry.maxHp, 0, 1)
		TweenService:Create(entry.shieldBar, TweenInfo.new(0.2), { Size = UDim2.new(sRatio, 0, 1, 0) }):Play()
	end
end

local function floatText(entry, text, color)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.Position = UDim2.new(0, math.random(-14, 14), 0.3, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.ZIndex = 40
	lbl.Parent = entry.frame
	TweenService:Create(lbl, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = lbl.Position - UDim2.new(0, 0, 0.35, 0),
		TextTransparency = 1,
	}):Play()
	task.delay(0.8, function() lbl:Destroy() end)
end

-- ── Init / panel construction ─────────────────────────────────────────────────

function BattleUI:Init(gui, cardDb, rarityConf)
	screenGui = gui
	CardDatabase = cardDb
	RarityConfig = rarityConf

	panel = Instance.new("Frame")
	panel.Name = "BattlePanel"
	panel.Size = UDim2.new(0.72, 0, 0.78, 0)
	panel.Position = UDim2.new(0.5, 0, 0.47, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.ZIndex = 30
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(45, 45, 70); stroke.Thickness = 1; stroke.Parent = panel

	headerFloor = Instance.new("TextLabel")
	headerFloor.Size = UDim2.new(0.3, 0, 0, 30); headerFloor.Position = UDim2.new(0, 14, 0, 8)
	headerFloor.BackgroundTransparency = 1
	headerFloor.TextColor3 = Color3.fromRGB(220, 220, 245)
	headerFloor.TextXAlignment = Enum.TextXAlignment.Left
	headerFloor.TextScaled = true; headerFloor.Font = Enum.Font.GothamBold
	headerFloor.ZIndex = 31; headerFloor.Parent = panel

	headerRound = Instance.new("TextLabel")
	headerRound.Size = UDim2.new(0.2, 0, 0, 26); headerRound.Position = UDim2.new(0.4, 0, 0, 10)
	headerRound.BackgroundTransparency = 1
	headerRound.TextColor3 = Color3.fromRGB(160, 160, 190)
	headerRound.TextScaled = true; headerRound.Font = Enum.Font.Gotham
	headerRound.ZIndex = 31; headerRound.Parent = panel

	local function headerBtn(text, xScale)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 64, 0, 28); b.Position = UDim2.new(xScale, 0, 0, 8)
		b.BackgroundColor3 = Color3.fromRGB(34, 34, 56)
		b.BorderSizePixel = 0
		b.Text = text
		b.TextColor3 = Color3.fromRGB(210, 210, 235)
		b.TextScaled = true; b.Font = Enum.Font.GothamBold
		b.ZIndex = 31; b.Parent = panel
		corner(b, 6)
		return b
	end
	speedBtn = headerBtn("1x", 0.82)
	skipBtn = headerBtn("SKIP", 0.9)

	speedBtn.MouseButton1Click:Connect(function()
		speedIndex = speedIndex % #speeds + 1
		speedBtn.Text = speeds[speedIndex] .. "x"
	end)
	skipBtn.MouseButton1Click:Connect(function()
		if onSkip then onSkip() end
	end)

	local function row(yScale)
		local r = Instance.new("Frame")
		r.Size = UDim2.new(1, -24, 0.34, 0)
		r.Position = UDim2.new(0, 12, yScale, 0)
		r.BackgroundTransparency = 1
		r.ZIndex = 31
		r.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0.01, 0)
		layout.Parent = r
		return r
	end
	enemyRow = row(0.08)
	playerRow = row(0.56)

	toastLabel = Instance.new("TextLabel")
	toastLabel.Size = UDim2.new(0.5, 0, 0, 26)
	toastLabel.Position = UDim2.new(0.25, 0, 0.475, 0)
	toastLabel.BackgroundTransparency = 1
	toastLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	toastLabel.TextTransparency = 1
	toastLabel.TextScaled = true; toastLabel.Font = Enum.Font.GothamBold
	toastLabel.ZIndex = 36; toastLabel.Parent = panel
end

-- ── Battle lifecycle ──────────────────────────────────────────────────────────

function BattleUI:BeginBattle(playerStart, enemyStart, floorLabel)
	for _, entry in pairs(frames) do entry.frame:Destroy() end
	frames = {}
	if resultOverlay then resultOverlay:Destroy(); resultOverlay = nil end

	for i, unit in ipairs(enemyStart) do
		frames["E" .. unit.slot] = buildUnitFrame(enemyRow, unit, i)
	end
	for i, unit in ipairs(playerStart) do
		frames["P" .. unit.slot] = buildUnitFrame(playerRow, unit, i)
	end
	-- Frontline emphasis: lowest slot on each side.
	self:PlayAdvance({ side = "P", newFrontSlot = playerStart[1] and playerStart[1].slot })
	self:PlayAdvance({ side = "E", newFrontSlot = enemyStart[1] and enemyStart[1].slot })

	headerFloor.Text = floorLabel or "BATTLE"
	headerRound.Text = ""
	panel.Visible = true
end

function BattleUI:SetRound(n)
	headerRound.Text = "Round " .. n
end

function BattleUI:PlayAttack(ev)
	local entry = frames[key(ev.src)]
	if not entry then return end
	local dir = ev.src.side == "P" and -1 or 1
	local orig = entry.frame.Position
	TweenService:Create(entry.frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = orig + UDim2.new(0, 0, 0.08 * dir, 0),
	}):Play()
	task.delay(0.14, function()
		TweenService:Create(entry.frame, TweenInfo.new(0.15), { Position = orig }):Play()
	end)
end

function BattleUI:ApplyDamage(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	setHpVisual(entry, ev.newHp, ev.newShield)
	local color = ev.crit and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 90, 80)
	floatText(entry, (ev.crit and "-" .. ev.amount .. "!" or "-" .. ev.amount), color)
end

function BattleUI:ApplyHeal(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	setHpVisual(entry, ev.newHp)
	floatText(entry, "+" .. ev.amount, Color3.fromRGB(120, 235, 140))
end

function BattleUI:SetMp(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	local ratio = entry.maxMp > 0 and math.clamp(ev.newMp / entry.maxMp, 0, 1) or 0
	TweenService:Create(entry.mpBar, TweenInfo.new(0.15), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
end

function BattleUI:PlayCast(ev)
	local entry = frames[key(ev.src)]
	if not entry then return end
	entry.mpBar.Size = UDim2.new(0, 0, 1, 0)
	floatText(entry, "CAST!", Color3.fromRGB(140, 180, 255))
end

function BattleUI:ApplyShield(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	local sRatio = math.clamp(ev.newShield / entry.maxHp, 0, 1)
	TweenService:Create(entry.shieldBar, TweenInfo.new(0.2), { Size = UDim2.new(sRatio, 0, 1, 0) }):Play()
	floatText(entry, "+" .. ev.amount .. " shield", SH_COL)
end

function BattleUI:PlayDeath(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	setHpVisual(entry, 0, 0)
	TweenService:Create(entry.frame, TweenInfo.new(0.4), { BackgroundTransparency = 0.7 }):Play()
	for _, child in ipairs(entry.frame:GetChildren()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 0.6 }):Play()
		end
	end
end

function BattleUI:PlayAdvance(ev)
	if not ev.newFrontSlot then return end
	for k, entry in pairs(frames) do
		if k:sub(1, 1) == ev.side then
			local isFront = k == ev.side .. ev.newFrontSlot
			TweenService:Create(entry.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = isFront and 1.12 or 1,
			}):Play()
		end
	end
end

function BattleUI:ShowSynergy(ev)
	toastLabel.Text = ev.name .. "  (Tier " .. ev.tier .. ")"
	toastLabel.TextTransparency = 0
	TweenService:Create(toastLabel, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
end

-- ── Result overlay ────────────────────────────────────────────────────────────

-- payload: { victory, title, lines = {string...}, buttons = { {text, color, cb}... } }
function BattleUI:ShowResult(payload)
	if resultOverlay then resultOverlay:Destroy() end
	resultOverlay = Instance.new("Frame")
	resultOverlay.Size = UDim2.new(1, 0, 1, 0)
	resultOverlay.BackgroundColor3 = BG
	resultOverlay.BackgroundTransparency = 0.25
	resultOverlay.BorderSizePixel = 0
	resultOverlay.ZIndex = 45
	resultOverlay.Parent = panel
	corner(resultOverlay, 14)

	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.new(0.8, 0, 0.16, 0); banner.Position = UDim2.new(0.1, 0, 0.12, 0)
	banner.BackgroundTransparency = 1
	banner.Text = payload.title
	banner.TextColor3 = payload.victory and Color3.fromRGB(120, 230, 140) or Color3.fromRGB(235, 90, 80)
	banner.TextScaled = true; banner.Font = Enum.Font.GothamBlack
	banner.ZIndex = 46; banner.Parent = resultOverlay

	for i, line in ipairs(payload.lines or {}) do
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.7, 0, 0, 24)
		lbl.Position = UDim2.new(0.15, 0, 0.32 + (i - 1) * 0.07, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = line
		lbl.TextColor3 = Color3.fromRGB(210, 210, 235)
		lbl.TextScaled = true; lbl.Font = Enum.Font.Gotham
		lbl.ZIndex = 46; lbl.Parent = resultOverlay
	end

	local n = #payload.buttons
	for i, def in ipairs(payload.buttons) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.24, 0, 0, 44)
		b.Position = UDim2.new(0.5 - 0.13 * n + 0.26 * (i - 1) + 0.01, 0, 0.8, 0)
		b.BackgroundColor3 = def.color
		b.BorderSizePixel = 0
		b.Text = def.text
		b.TextColor3 = Color3.new(1, 1, 1)
		b.TextScaled = true; b.Font = Enum.Font.GothamBold
		b.ZIndex = 46; b.Parent = resultOverlay
		corner(b, 8)
		b.MouseButton1Click:Connect(function()
			if resultOverlay then resultOverlay:Destroy(); resultOverlay = nil end
			def.cb()
		end)
	end
end

-- ── Misc ──────────────────────────────────────────────────────────────────────

function BattleUI:GetSpeed()
	return speeds[speedIndex]
end

function BattleUI:SetOnSkip(cb)
	onSkip = cb
end

function BattleUI:Show()
	panel.Visible = true
end

function BattleUI:Hide()
	panel.Visible = false
end

function BattleUI:GetPanel()
	return panel
end

return BattleUI
