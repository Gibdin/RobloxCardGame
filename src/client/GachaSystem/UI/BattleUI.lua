-- BattleUI — battle playback panel. Pure view: the server event log drives
-- everything through the imperative primitives below; no combat math happens
-- here. Centered large panel (not fullscreen), GlobalTeamBar stays visible.

local TweenService = game:GetService("TweenService")

local FxUtil = require(script.Parent.FxUtil)

local BattleUI = {}

local panel, headerRound, headerFloor, speedBtn, skipBtn
local enemyRow, playerRow, toastLabel, resultOverlay, flashFrame
local logFrame, logLayout
local logCount = 0
local frames = {}        -- ["P3"] = unit frame entry (see buildUnitFrame)
local frontSlots = {}    -- [side] = current frontline slot (for low-HP pulses)
local lastActor          -- last unit to attack/cast; attributes the next damage line
local screenGui
local CardDatabase, RarityConfig, RoleConfig, CombatConfig, VFXConfig
local Sound = { Play = function() end, Stop = function() end }  -- no-op until Init provides one
local speedIndex = 1
local speeds = { 1, 2 }
local onSkip
local lowHpWarningEnabled = true

local BG      = Color3.fromRGB(14, 14, 24)
local HP_HI   = Color3.fromRGB(70, 200, 110)
local HP_LO   = Color3.fromRGB(210, 70, 60)
local MP_COL  = Color3.fromRGB(80, 140, 240)
local SH_COL  = Color3.fromRGB(200, 220, 255)
local FRAME_BG = Color3.fromRGB(22, 22, 38)
local HIT_BG   = Color3.fromRGB(120, 35, 45)
local GOLD_COL = Color3.fromRGB(255, 210, 90)

local MAX_LOG_LINES = 60

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function key(refT) return refT.side .. refT.slot end

-- ── Damage log ────────────────────────────────────────────────────────────────

local function logLine(text, color)
	if not logFrame then return end
	logCount = logCount + 1
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -6, 0, 16)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(190, 190, 215)
	lbl.TextSize = 13
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.LayoutOrder = logCount
	lbl.ZIndex = 32
	lbl.Parent = logFrame

	local labels = {}
	for _, c in ipairs(logFrame:GetChildren()) do
		if c:IsA("TextLabel") then table.insert(labels, c) end
	end
	if #labels > MAX_LOG_LINES then
		table.sort(labels, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		for i = 1, #labels - MAX_LOG_LINES do labels[i]:Destroy() end
	end
	logFrame.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize.Y + 4)
	logFrame.CanvasPosition = Vector2.new(0, math.max(0, logLayout.AbsoluteContentSize.Y - logFrame.AbsoluteSize.Y))
end

local function clearLog()
	if not logFrame then return end
	for _, c in ipairs(logFrame:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	logCount = 0
	logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- ── Unit frames ───────────────────────────────────────────────────────────────

local function buildUnitFrame(parent, unit, order, sideKey)
	local card = CardDatabase:GetById(unit.cardId)
	local rarity = card and card.rarity or "Common"
	local rarityDef = RarityConfig.Rarities[rarity] or {}
	local rarityColor = rarityDef.color or Color3.fromRGB(150, 150, 150)
	local rarityOrder = RarityConfig:GetOrder(rarity)
	local roleDef = RoleConfig and RoleConfig.Roles[unit.role]

	local f = Instance.new("Frame")
	f.Size = UDim2.new(0.18, 0, 0.9, 0)
	f.BackgroundColor3 = FRAME_BG
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.ZIndex = 31
	f.Parent = parent
	corner(f, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityOrder >= 5 and (rarityDef.glowColor or rarityColor) or rarityColor
	stroke.Thickness = rarityOrder >= 4 and 3 or 2
	stroke.Parent = f

	local scale = Instance.new("UIScale"); scale.Parent = f

	-- Rarity-gradient header behind the name.
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.3, 0)
	header.BackgroundColor3 = rarityColor
	header.BackgroundTransparency = 0.35
	header.BorderSizePixel = 0
	header.ZIndex = 31
	header.Parent = f
	corner(header, 10)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(rarityColor, rarityColor:Lerp(Color3.new(0, 0, 0), 0.55))
	grad.Rotation = 90
	grad.Parent = header

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -26, 0.3, -4); name.Position = UDim2.new(0, 22, 0, 2)
	name.BackgroundTransparency = 1
	name.Text = unit.name
	name.TextColor3 = Color3.fromRGB(245, 245, 255)
	name.TextScaled = true; name.TextWrapped = true
	name.Font = Enum.Font.GothamBold
	name.ZIndex = 33; name.Parent = f

	-- Role glyph chip at the header's left edge.
	local chip = Instance.new("TextLabel")
	chip.Size = UDim2.new(0, 18, 0, 18); chip.Position = UDim2.new(0, 3, 0, 3)
	chip.BackgroundColor3 = roleDef and roleDef.color or Color3.fromRGB(90, 90, 110)
	chip.Text = roleDef and roleDef.icon or "?"
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.TextSize = 12
	chip.Font = Enum.Font.GothamBold
	chip.BorderSizePixel = 0
	chip.ZIndex = 34; chip.Parent = f
	corner(chip, 9)

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

	-- Low-HP warning overlay (pulsed while the frontliner is in danger).
	local lowOverlay = Instance.new("Frame")
	lowOverlay.Size = UDim2.new(1, 0, 1, 0)
	lowOverlay.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	lowOverlay.BackgroundTransparency = 1
	lowOverlay.BorderSizePixel = 0
	lowOverlay.ZIndex = 35
	lowOverlay.Parent = f
	corner(lowOverlay, 10)

	return {
		frame = f, hpBar = hpBar, hpText = hpText, mpBar = mpBar,
		shieldBar = shieldBar, scale = scale,
		maxHp = unit.maxHp, maxMp = unit.maxMp,
		name = unit.name, baseScale = 1,
		side = sideKey, slot = unit.slot,
		lowOverlay = lowOverlay, lowPulse = nil, lowWarned = false,
		hpRatio = unit.hp / unit.maxHp, alive = true,
	}
end

-- ── Low-HP tension ────────────────────────────────────────────────────────────

local function stopLowHpPulse(entry)
	if entry.lowPulse then
		entry.lowPulse:Cancel()
		entry.lowPulse = nil
	end
	entry.lowOverlay.BackgroundTransparency = 1
end

local function updateLowHpState(entry)
	local threshold = CombatConfig and CombatConfig.Drama and CombatConfig.Drama.LowHpThreshold or 0.3
	local isFront = frontSlots[entry.side] == entry.slot
	local inDanger = entry.alive and isFront and entry.hpRatio > 0 and entry.hpRatio < threshold
	if inDanger and not entry.lowPulse then
		entry.lowOverlay.BackgroundTransparency = 0.85
		entry.lowPulse = TweenService:Create(entry.lowOverlay,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ BackgroundTransparency = 0.55 })
		entry.lowPulse:Play()
		if not entry.lowWarned and entry.side == "P" then
			entry.lowWarned = true
			if lowHpWarningEnabled then Sound:Play("low_hp_warn") end
		end
	elseif not inDanger and entry.lowPulse then
		stopLowHpPulse(entry)
	end
end

local function refreshLowHpAll()
	for _, entry in pairs(frames) do
		updateLowHpState(entry)
	end
end

local function setHpVisual(entry, newHp, newShield)
	local ratio = math.clamp(newHp / entry.maxHp, 0, 1)
	entry.hpRatio = ratio
	TweenService:Create(entry.hpBar, TweenInfo.new(0.2), {
		Size = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = HP_LO:Lerp(HP_HI, ratio),
	}):Play()
	entry.hpText.Text = newHp .. "/" .. entry.maxHp
	if newShield ~= nil then
		local sRatio = math.clamp(newShield / entry.maxHp, 0, 1)
		TweenService:Create(entry.shieldBar, TweenInfo.new(0.2), { Size = UDim2.new(sRatio, 0, 1, 0) }):Play()
	end
	updateLowHpState(entry)
end

-- ── Init / panel construction ─────────────────────────────────────────────────

function BattleUI:Init(gui, cardDb, rarityConf, soundManager, vfxConfig, roleConf, combatConf)
	screenGui = gui
	CardDatabase = cardDb
	RarityConfig = rarityConf
	RoleConfig = roleConf
	CombatConfig = combatConf
	VFXConfig = vfxConfig
	if soundManager then Sound = soundManager end

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
		r.Size = UDim2.new(1, -24, 0.32, 0)
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
	playerRow = row(0.54)

	-- Damage log strip along the bottom of the panel.
	logFrame = Instance.new("ScrollingFrame")
	logFrame.Name = "DamageLog"
	logFrame.Size = UDim2.new(1, -24, 0.11, 0)
	logFrame.Position = UDim2.new(0, 12, 0.875, 0)
	logFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
	logFrame.BackgroundTransparency = 0.35
	logFrame.BorderSizePixel = 0
	logFrame.ScrollBarThickness = 4
	logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	logFrame.ZIndex = 31
	logFrame.Parent = panel
	corner(logFrame, 6)
	logLayout = Instance.new("UIListLayout")
	logLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logLayout.Padding = UDim.new(0, 1)
	logLayout.Parent = logFrame
	local logPad = Instance.new("UIPadding")
	logPad.PaddingLeft = UDim.new(0, 6)
	logPad.PaddingTop = UDim.new(0, 3)
	logPad.Parent = logFrame

	toastLabel = Instance.new("TextLabel")
	toastLabel.Size = UDim2.new(0.5, 0, 0, 26)
	toastLabel.Position = UDim2.new(0.25, 0, 0.475, 0)
	toastLabel.BackgroundTransparency = 1
	toastLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	toastLabel.TextTransparency = 1
	toastLabel.TextScaled = true; toastLabel.Font = Enum.Font.GothamBold
	toastLabel.ZIndex = 36; toastLabel.Parent = panel

	-- White flash used by the final blow.
	flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.new(1, 0, 1, 0)
	flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 44
	flashFrame.Parent = panel
	corner(flashFrame, 14)
end

-- ── Battle lifecycle ──────────────────────────────────────────────────────────

function BattleUI:BeginBattle(playerStart, enemyStart, floorLabel)
	for _, entry in pairs(frames) do
		stopLowHpPulse(entry)
		entry.frame:Destroy()
	end
	frames = {}
	frontSlots = {}
	lastActor = nil
	clearLog()
	if resultOverlay then resultOverlay:Destroy(); resultOverlay = nil end
	if flashFrame then flashFrame.BackgroundTransparency = 1 end

	for i, unit in ipairs(enemyStart) do
		frames["E" .. unit.slot] = buildUnitFrame(enemyRow, unit, i, "E")
	end
	for i, unit in ipairs(playerStart) do
		frames["P" .. unit.slot] = buildUnitFrame(playerRow, unit, i, "P")
	end
	-- Frontline emphasis: lowest slot on each side.
	self:PlayAdvance({ side = "P", newFrontSlot = playerStart[1] and playerStart[1].slot })
	self:PlayAdvance({ side = "E", newFrontSlot = enemyStart[1] and enemyStart[1].slot })

	headerFloor.Text = floorLabel or "BATTLE"
	headerRound.Text = ""
	panel.Visible = true
	Sound:Play("battle_start")
end

function BattleUI:SetRound(n)
	headerRound.Text = "Round " .. n
	logLine("— Round " .. n .. " —", Color3.fromRGB(120, 120, 155))
end

function BattleUI:PlayAttack(ev)
	local entry = frames[key(ev.src)]
	if not entry then return end
	lastActor = entry
	-- The unit frames live under a UIListLayout, which owns their Position —
	-- so the bump animates Scale and Rotation (layout-safe) instead: a quick
	-- pop toward the target with a tilt, then settle back.
	local dir = ev.src.side == "P" and -1 or 1
	entry.frame.Rotation = 0
	TweenService:Create(entry.scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = entry.baseScale * 1.16,
	}):Play()
	TweenService:Create(entry.frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = 7 * dir,
	}):Play()
	task.delay(0.12, function()
		TweenService:Create(entry.scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = entry.baseScale,
		}):Play()
		TweenService:Create(entry.frame, TweenInfo.new(0.18), { Rotation = 0 }):Play()
	end)
end

local function logDamage(entry, ev)
	local suffix = ev.crit and "  CRIT!" or ""
	if ev.source == "reflect" then
		logLine(entry.name .. " takes " .. ev.amount .. " reflected damage", Color3.fromRGB(200, 160, 120))
	elseif ev.source == "chain" then
		logLine((lastActor and lastActor.name or "?") .. " chains to " .. entry.name .. " for " .. ev.amount .. suffix, Color3.fromRGB(140, 190, 255))
	else
		logLine((lastActor and lastActor.name or "?") .. " hits " .. entry.name .. " for " .. ev.amount .. suffix,
			ev.crit and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(230, 140, 130))
	end
end

function BattleUI:ApplyDamage(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	setHpVisual(entry, ev.newHp, ev.newShield)
	local color = ev.crit and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 90, 80)
	FxUtil.floatText(entry.frame, (ev.crit and "-" .. ev.amount .. "!" or "-" .. ev.amount), color,
		{ scale = ev.crit and 1.4 or 1 })
	Sound:Play(ev.crit and "attack_crit" or "attack_hit")

	if ev.crit and CombatConfig and CombatConfig.Drama then
		FxUtil.shake(panel, CombatConfig.Drama.CritShake.intensity, CombatConfig.Drama.CritShake.duration)
	end

	-- Hit flash so the defender reads at a glance.
	entry.frame.BackgroundColor3 = HIT_BG
	TweenService:Create(entry.frame, TweenInfo.new(0.3), { BackgroundColor3 = FRAME_BG }):Play()

	logDamage(entry, ev)
end

-- The battle-deciding hit: white flash + heavy shake on top of normal damage.
function BattleUI:PlayFinalBlow(ev)
	self:ApplyDamage(ev)
	if CombatConfig and CombatConfig.Drama then
		FxUtil.shake(panel, CombatConfig.Drama.FinalBlowShake.intensity, CombatConfig.Drama.FinalBlowShake.duration)
	end
	if flashFrame then
		flashFrame.BackgroundTransparency = 0.35
		TweenService:Create(flashFrame, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
	end
end

function BattleUI:ApplyHeal(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	setHpVisual(entry, ev.newHp)
	FxUtil.floatText(entry.frame, "+" .. ev.amount, Color3.fromRGB(120, 235, 140))
	Sound:Play("heal")
	logLine(entry.name .. " heals " .. ev.amount .. (ev.source and (" (" .. ev.source .. ")") or ""), Color3.fromRGB(120, 210, 140))
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
	lastActor = entry
	entry.mpBar.Size = UDim2.new(0, 0, 1, 0)
	FxUtil.floatText(entry.frame, "CAST!", Color3.fromRGB(140, 180, 255))
	Sound:Play("cast")
	local label = ev.activeName and (ev.activeName ~= (ev.role .. " Active") and ev.activeName or nil)
	if label then
		logLine(entry.name .. " casts " .. label .. "!", Color3.fromRGB(140, 180, 255))
	else
		logLine(entry.name .. " casts their active!", Color3.fromRGB(140, 180, 255))
	end
end

function BattleUI:ApplyShield(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	local sRatio = math.clamp(ev.newShield / entry.maxHp, 0, 1)
	TweenService:Create(entry.shieldBar, TweenInfo.new(0.2), { Size = UDim2.new(sRatio, 0, 1, 0) }):Play()
	FxUtil.floatText(entry.frame, "+" .. ev.amount .. " shield", SH_COL)
	Sound:Play("shield_gain")
end

function BattleUI:PlayDeath(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	entry.alive = false
	stopLowHpPulse(entry)
	setHpVisual(entry, 0, 0)
	-- Collapse: red flash + scale crush, then the fade.
	entry.frame.BackgroundColor3 = HIT_BG
	TweenService:Create(entry.scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = entry.baseScale * 0.82,
	}):Play()
	TweenService:Create(entry.frame, TweenInfo.new(0.4), { BackgroundTransparency = 0.7 }):Play()
	for _, child in ipairs(entry.frame:GetChildren()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 0.6 }):Play()
		end
	end
	logLine(entry.name .. " is defeated!", Color3.fromRGB(235, 90, 80))
	Sound:Play(ev.dst.side == "E" and "enemy_death" or "unit_death")
	if CombatConfig and CombatConfig.Drama then
		FxUtil.shake(panel, CombatConfig.Drama.KillShake.intensity, CombatConfig.Drama.KillShake.duration)
	end
end

function BattleUI:PlayAdvance(ev)
	if not ev.newFrontSlot then return end
	frontSlots[ev.side] = ev.newFrontSlot
	for k, entry in pairs(frames) do
		if k:sub(1, 1) == ev.side then
			local isFront = k == ev.side .. ev.newFrontSlot
			entry.baseScale = isFront and 1.12 or 1
			TweenService:Create(entry.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = entry.baseScale,
			}):Play()
		end
	end
	refreshLowHpAll()
end

function BattleUI:ShowSynergy(ev)
	toastLabel.Text = ev.name .. "  (Tier " .. ev.tier .. ")"
	toastLabel.TextTransparency = 0
	TweenService:Create(toastLabel, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	logLine((ev.side == "P" and "Your " or "Enemy ") .. ev.name .. " synergy (tier " .. ev.tier .. ") is active", Color3.fromRGB(255, 220, 120))
	if ev.side == "P" then Sound:Play("synergy_proc") end
end

-- Permanent Max HP reduction from a unique-active step (e.g. World Cutter's
-- Domainless Cleave). No bar re-scale needed here — the next ApplyDamage/
-- ApplyHeal call already recomputes ratios off the unit's current maxHp.
function BattleUI:PlayMaxHpShred(ev)
	local entry = frames[key(ev.dst)]
	if not entry then return end
	entry.maxHp = ev.newMaxHp
	FxUtil.floatText(entry.frame, "-" .. math.floor(ev.pct * 100) .. "% Max HP", Color3.fromRGB(200, 100, 220))
	logLine(entry.name .. "'s Max HP is permanently cut by " .. math.floor(ev.pct * 100) .. "%", Color3.fromRGB(200, 100, 220))
end

-- ── Result overlay ────────────────────────────────────────────────────────────

-- payload:
--   victory, title, buttons = { {text, color, cb}... }
--   summary  = { rounds, totalDamage, kills, mvpName, mvpColor, mvpDamage } (optional)
--   gold     = n (optional; count-up row)
--   xpTotal  = n (optional; count-up row)
--   levelUps = { "Name reached Lv 3!", ... } (optional)
--   packs    = { [packType] = n } (optional)
--   bonus    = { kind, gold, itemName, cardName, packLabel } (optional; own beat)
--   recordLabel = "NEW DEEPEST ROW: 9" (optional)
--   lines    = { ... } (legacy fallback rows)
function BattleUI:ShowResult(payload)
	Sound:Play(payload.victory and "victory_sting" or "defeat_sting")
	if resultOverlay then resultOverlay:Destroy() end
	resultOverlay = Instance.new("Frame")
	resultOverlay.Size = UDim2.new(1, 0, 1, 0)
	resultOverlay.BackgroundColor3 = BG
	resultOverlay.BackgroundTransparency = 0.15
	resultOverlay.BorderSizePixel = 0
	resultOverlay.ZIndex = 45
	resultOverlay.Parent = panel
	corner(resultOverlay, 14)

	local resultsConf = (VFXConfig and VFXConfig.Results) or {
		bannerTime = 0.35, staggerDelay = 0.28, countUpTime = 0.8,
		tickEvery = 0.05, bonusHold = 0.45, bonusShake = 10,
	}

	-- Banner slams in.
	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.new(0.8, 0, 0.14, 0); banner.Position = UDim2.new(0.1, 0, 0.08, 0)
	banner.BackgroundTransparency = 1
	banner.Text = payload.title
	banner.TextColor3 = payload.victory and Color3.fromRGB(120, 230, 140) or Color3.fromRGB(235, 90, 80)
	banner.TextScaled = true; banner.Font = Enum.Font.GothamBlack
	banner.ZIndex = 46; banner.Parent = resultOverlay
	local bannerScale = Instance.new("UIScale"); bannerScale.Scale = 1.6; bannerScale.Parent = banner
	TweenService:Create(bannerScale, TweenInfo.new(resultsConf.bannerTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- Rows holder.
	local rowsHolder = Instance.new("Frame")
	rowsHolder.Size = UDim2.new(0.8, 0, 0.5, 0); rowsHolder.Position = UDim2.new(0.1, 0, 0.25, 0)
	rowsHolder.BackgroundTransparency = 1
	rowsHolder.ZIndex = 46
	rowsHolder.Parent = resultOverlay
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowsLayout.Padding = UDim.new(0, 4)
	rowsLayout.Parent = rowsHolder

	local rows = {}          -- { { frame, onShow } }
	local rowOrder = 0
	local function addRow(text, color, height, onShow, font)
		rowOrder = rowOrder + 1
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, height or 24)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = color or Color3.fromRGB(210, 210, 235)
		lbl.TextScaled = true
		lbl.Font = font or Enum.Font.Gotham
		lbl.LayoutOrder = rowOrder
		lbl.ZIndex = 46
		lbl.Visible = false
		lbl.Parent = rowsHolder
		table.insert(rows, { frame = lbl, onShow = onShow })
		return lbl
	end

	-- Build rows from the structured payload.
	if payload.summary then
		local s = payload.summary
		addRow(("Rounds %d   ·   Team damage %d   ·   Kills %d"):format(s.rounds or 0, s.totalDamage or 0, s.kills or 0),
			Color3.fromRGB(180, 180, 210), 22)
		if s.mvpName then
			addRow("★ MVP: " .. s.mvpName .. " — " .. (s.mvpDamage or 0) .. " dmg",
				s.mvpColor or GOLD_COL, 26, function() Sound:Play("mvp_reveal") end, Enum.Font.GothamBold)
		end
	end
	if payload.gold and payload.gold > 0 then
		local lbl = addRow("+0g", GOLD_COL, 30, nil, Enum.Font.GothamBold)
		rows[#rows].onShow = function()
			FxUtil.countUp(lbl, 0, payload.gold, resultsConf.countUpTime,
				{ prefix = "+", suffix = "g", tickEvery = resultsConf.tickEvery, sound = { mgr = Sound, name = "gold_tick" } })
		end
	end
	if payload.xpTotal and payload.xpTotal > 0 then
		local lbl = addRow("+0 XP", Color3.fromRGB(170, 140, 255), 26, nil, Enum.Font.GothamBold)
		rows[#rows].onShow = function()
			FxUtil.countUp(lbl, 0, payload.xpTotal, resultsConf.countUpTime,
				{ prefix = "+", suffix = " XP", tickEvery = resultsConf.tickEvery, sound = { mgr = Sound, name = "xp_tick" } })
		end
	end
	for _, line in ipairs(payload.levelUps or {}) do
		addRow("▲ " .. line, Color3.fromRGB(255, 225, 130), 24, function() Sound:Play("level_up") end, Enum.Font.GothamBold)
	end
	if payload.packs then
		local parts = {}
		for packType, n in pairs(payload.packs) do
			table.insert(parts, n .. "x " .. packType:gsub("Pack", " Pack"))
		end
		if #parts > 0 then
			addRow("🎁 " .. table.concat(parts, ", "), Color3.fromRGB(140, 200, 255), 26, nil, Enum.Font.GothamBold)
		end
	end
	for _, line in ipairs(payload.lines or {}) do
		addRow(line, Color3.fromRGB(210, 210, 235), 24)
	end

	-- Bonus loot gets its own beat: a held pause, then a slam + shake.
	local bonusRows = {}
	if payload.bonus then
		local b = payload.bonus
		local bannerRow = addRow("★ BONUS LOOT! ★", GOLD_COL, 32, nil, Enum.Font.GothamBlack)
		local detailText = ""
		if b.kind == "goldJackpot" then
			detailText = "Gold jackpot: +" .. (b.gold or 0) .. "g"
		elseif b.kind == "freeItem" then
			detailText = (b.itemName or "Item") .. " → " .. (b.cardName or "?")
		elseif b.kind == "bonusPack" then
			detailText = "Free " .. (b.packLabel or "pack") .. "!"
		end
		local detailRow = addRow(detailText, GOLD_COL, 24, nil, Enum.Font.GothamBold)
		bonusRows = { banner = bannerRow, detail = detailRow, data = b }
		-- Remove them from the normal stagger; the bonus beat plays them.
		rows[#rows] = nil
		rows[#rows] = nil
	end

	if payload.recordLabel then
		addRow("★ " .. payload.recordLabel .. " ★", Color3.fromRGB(130, 255, 200), 26,
			function() Sound:Play("new_record") end, Enum.Font.GothamBlack)
	end

	-- Buttons render immediately so the ceremony never blocks the player.
	local n = #payload.buttons
	for i, def in ipairs(payload.buttons) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.24, 0, 0, 44)
		b.Position = UDim2.new(0.5 - 0.13 * n + 0.26 * (i - 1) + 0.01, 0, 0.82, 0)
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

	-- Staggered reveal (cosmetic only; all values are final payload data).
	local overlayRef = resultOverlay
	task.spawn(function()
		task.wait(resultsConf.bannerTime)
		for _, r in ipairs(rows) do
			if overlayRef.Parent == nil then return end
			r.frame.Visible = true
			if r.onShow then r.onShow() end
			task.wait(resultsConf.staggerDelay)
		end
		if bonusRows.banner and overlayRef.Parent ~= nil then
			task.wait(resultsConf.bonusHold)
			if overlayRef.Parent == nil then return end
			bonusRows.banner.Visible = true
			local slam = Instance.new("UIScale"); slam.Scale = 2; slam.Parent = bonusRows.banner
			TweenService:Create(slam, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			Sound:Play("bonus_loot")
			FxUtil.shake(panel, resultsConf.bonusShake, 0.4)
			task.wait(resultsConf.staggerDelay)
			if overlayRef.Parent == nil then return end
			bonusRows.detail.Visible = true
			if bonusRows.data.kind == "goldJackpot" then
				FxUtil.countUp(bonusRows.detail, 0, bonusRows.data.gold or 0, resultsConf.countUpTime * 0.6,
					{ prefix = "Gold jackpot: +", suffix = "g", tickEvery = resultsConf.tickEvery * 0.6,
					  sound = { mgr = Sound, name = "gold_tick" } })
			end
		end
	end)
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

function BattleUI:SetLowHpWarningEnabled(enabled)
	lowHpWarningEnabled = enabled
end

return BattleUI
