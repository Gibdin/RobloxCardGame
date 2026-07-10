-- Team composition builder UI.
-- 5-card linear queue: Slot 1 = frontline, on death Slot 2 takes over, etc.
-- No role lock. Role bonuses and synergies update live as cards are placed.

local TeamBuilderUI = {}

local TweenService = game:GetService("TweenService")
local TS_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TS_MED  = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ── Layout ────────────────────────────────────────────────────────────────────
local PW, PH        = 1000, 640
local TOPBAR_H      = 44
local BODY_Y        = TOPBAR_H + 1
local BODY_H        = PH - BODY_Y         -- 595

local SLOTS_W       = 204
local CENTER_X      = SLOTS_W + 1         -- 205
local CENTER_W      = 455
local RIGHT_X       = CENTER_X + CENTER_W + 1  -- 661
local RIGHT_W       = PW - RIGHT_X        -- 339

local DET_H         = 280
local INV_H         = BODY_H - DET_H - 1 -- 314

local SLOT_HDR_H    = 34
local SLOT_H        = 108
local SLOT_GAP      = 4

local MINI_TW, MINI_TH, MINI_GAP = 74, 98, 4

-- ── Colors ────────────────────────────────────────────────────────────────────
local ROLE_COLOR = {
	Tank    = Color3.fromRGB(60,  130, 220),
	DPS     = Color3.fromRGB(220,  60,  60),
	Support = Color3.fromRGB(60,  200, 120),
}
local PASSIVE_COLOR = {
	Drain       = Color3.fromRGB(60,  130, 220),
	Rage        = Color3.fromRGB(220,  60,  60),
	Executioner = Color3.fromRGB(220, 130,  40),
	Medic       = Color3.fromRGB(60,  200, 120),
	Battery     = Color3.fromRGB(60,  180, 200),
}
local RARITY_COLOR = {
	Common    = Color3.fromRGB(130, 130, 130),
	Uncommon  = Color3.fromRGB(80,  200,  80),
	Rare      = Color3.fromRGB(80,  130, 255),
	Epic      = Color3.fromRGB(160,  60, 220),
	Legendary = Color3.fromRGB(255, 165,   0),
	Mythic    = Color3.fromRGB(255,  50,  50),
	God       = Color3.fromRGB(255, 215,   0),
	Secret    = Color3.fromRGB(160,   0,  35),
}
local RARITY_BG = {
	Common    = Color3.fromRGB( 30, 30, 32),
	Uncommon  = Color3.fromRGB( 12, 30, 12),
	Rare      = Color3.fromRGB(  8, 14, 38),
	Epic      = Color3.fromRGB( 22,  8, 38),
	Legendary = Color3.fromRGB( 38, 26,  4),
	Mythic    = Color3.fromRGB( 38,  6,  6),
	God       = Color3.fromRGB( 38, 36,  4),
	Secret    = Color3.fromRGB( 28,  2,  8),
}

-- ── State ─────────────────────────────────────────────────────────────────────
local cardDb, rarityConf, roleConf
local rfGetInventory, rfGetTeam, rfSetTeam

local allCards     = {}
-- false = empty slot; avoids nil holes in the array across RemoteFunctions
local team         = { false, false, false, false, false }
local selectedCard = nil

-- ── UI refs ───────────────────────────────────────────────────────────────────
local panel, teamCountLbl
local slotFrames  = {}
local invScroll
local detEmpty, detContent
local detArtBg, detName, detRarityBadge, detRoleBadge
local detATK, detHP, detMP
local detPassiveChip, detPassiveDesc, detCardPassiveLbl
local roleRows    = {}
local synergyScroll
local saveDebounce

-- ── Micro-helpers ─────────────────────────────────────────────────────────────
local function F(parent, name, bg, x, y, w, h, zi)
	local f = Instance.new("Frame")
	f.Name = name; f.BackgroundColor3 = bg
	f.Position = UDim2.new(0, x, 0, y); f.Size = UDim2.new(0, w, 0, h)
	if zi then f.ZIndex = zi end
	f.BorderSizePixel = 0; f.Parent = parent
	return f
end
local function L(parent, text, x, y, w, h, size, color, font, xa, ya)
	local l = Instance.new("TextLabel")
	l.Text = text
	l.Position = UDim2.new(0, x, 0, y); l.Size = UDim2.new(0, w, 0, h)
	l.BackgroundTransparency = 1
	l.TextSize = size or 14; l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = font or Enum.Font.Gotham
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.TextYAlignment = ya or Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent; return l
end
local function B(parent, text, x, y, w, h, bg, tc)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Position = UDim2.new(0, x, 0, y); b.Size = UDim2.new(0, w, 0, h)
	b.BackgroundColor3 = bg or Color3.fromRGB(50, 80, 140)
	b.TextColor3 = tc or Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold; b.TextSize = 13
	b.BorderSizePixel = 0; b.AutoButtonColor = true; b.Parent = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = b
	return b
end
local function corner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p
end
local function stroke(p, t, col, mode)
	local s = Instance.new("UIStroke"); s.Thickness = t or 1
	s.Color = col or Color3.fromRGB(50, 50, 70)
	if mode then s.ApplyStrokeMode = mode end
	s.Parent = p; return s
end

-- ── Team helpers ──────────────────────────────────────────────────────────────
local function isInTeam(cardId)
	for i = 1, 5 do if team[i] == cardId then return true end end
	return false
end

local function calcTeamStats()
	local roles  = { Tank = 0, DPS = 0, Support = 0 }
	local series = {}
	for i = 1, 5 do
		local id = team[i]
		if id and id ~= false then
			local card = cardDb:GetById(id)
			if card then
				roles[card.role] = (roles[card.role] or 0) + 1
				for _, syn in ipairs(card.series or {}) do
					series[syn] = (series[syn] or 0) + 1
				end
			end
		end
	end
	return roles, series
end

local function getActiveBonus(bonuses, count)
	if count == 0 then return nil end
	local best = nil
	for i = 1, math.min(count, #bonuses) do
		best = bonuses[i]
	end
	return best
end

-- ── Refresh: team slot display ────────────────────────────────────────────────
local function refreshTeamSlots()
	local filled = 0
	for i = 1, 5 do if team[i] and team[i] ~= false then filled = filled + 1 end end
	if teamCountLbl then teamCountLbl.Text = filled .. " / 5" end

	for i = 1, 5 do
		local sf = slotFrames[i]
		if not sf then continue end
		local emptyGrp = sf:FindFirstChild("EmptyGrp")
		local occGrp   = sf:FindFirstChild("OccGrp")
		local sStroke  = sf:FindFirstChildOfClass("UIStroke")

		local cardId = team[i]
		if cardId and cardId ~= false then
			local card = cardDb:GetById(cardId)
			if card then
				if emptyGrp then emptyGrp.Visible = false end
				if occGrp   then occGrp.Visible   = true  end

				local rc = RARITY_COLOR[card.rarity] or Color3.fromRGB(60, 60, 80)
				if sStroke then sStroke.Color = rc end

				if occGrp then
					local cn = occGrp:FindFirstChild("CardName")
					if cn then cn.Text = card.name end

					local rb = occGrp:FindFirstChild("RoleBadge")
					if rb then
						rb.BackgroundColor3 = ROLE_COLOR[card.role] or Color3.fromRGB(80, 80, 80)
						local rl = rb:FindFirstChild("RoleLbl")
						if rl then rl.Text = card.role:upper() end
					end

					local rar = occGrp:FindFirstChild("RarityLbl")
					if rar then
						rar.Text = card.rarity
						rar.TextColor3 = rc
					end

					local st = occGrp:FindFirstChild("StatsLbl")
					if st then st.Text = card.attack .. " / " .. card.hp .. " / " .. card.mp end
				end
			end
		else
			if emptyGrp then
				emptyGrp.Visible = true
				local hl = emptyGrp:FindFirstChild("HintLbl")
				if hl then
					if selectedCard then
						hl.Text = "← Equip " .. selectedCard.name
						hl.TextColor3 = Color3.fromRGB(70, 160, 70)
					else
						hl.Text = "Select a card below"
						hl.TextColor3 = Color3.fromRGB(45, 45, 60)
					end
				end
			end
			if occGrp   then occGrp.Visible   = false end
			if sStroke  then sStroke.Color = Color3.fromRGB(45, 45, 65) end
		end
	end
end

-- ── Refresh: synergy panel ────────────────────────────────────────────────────
local function refreshSynergies()
	local roles, series = calcTeamStats()

	for roleName, row in pairs(roleRows) do
		local roleDef = roleConf.Roles[roleName]
		local count   = roles[roleName] or 0
		local bonus   = getActiveBonus(roleDef.bonuses, count)
		row.countLbl.Text = roleName .. ": " .. count
		row.bonusLbl.Text = bonus or "—"
		local active = count > 0
		TweenService:Create(row.countLbl, TS_FAST, {TextColor3 = active and ROLE_COLOR[roleName] or Color3.fromRGB(60, 60, 70)}):Play()
		TweenService:Create(row.bonusLbl, TS_FAST, {TextColor3 = active and Color3.fromRGB(190, 220, 190) or Color3.fromRGB(60, 60, 70)}):Play()
	end

	if not synergyScroll then return end
	for _, child in ipairs(synergyScroll:GetChildren()) do
		if not child:IsA("Frame") then continue end
		local synName = child:GetAttribute("SynName")
		if not synName then continue end

		local synDef = roleConf.Synergies[synName]
		if not synDef then continue end
		local count = series[synName] or 0

		local countLbl = child:FindFirstChild("CountLbl")
		if countLbl then
			countLbl.Text = count .. " / " .. synDef.maxCount
			countLbl.TextColor3 = count > 0 and (synDef.color or Color3.fromRGB(180, 220, 180)) or Color3.fromRGB(55, 55, 65)
		end

		-- Find the active tier
		local activeBonus = nil
		local nextThresh  = nil
		for _, thresh in ipairs(synDef.thresholds) do
			if count >= thresh.count then
				activeBonus = thresh
			elseif not nextThresh then
				nextThresh = thresh
			end
		end

		local barBg   = child:FindFirstChild("BarBg")
		local barFill = barBg and barBg:FindFirstChild("BarFill")
		if barFill then
			local pct = math.min(count / synDef.maxCount, 1)
			local fillColor = activeBonus and (synDef.color or Color3.fromRGB(60, 200, 90)) or Color3.fromRGB(70, 70, 100)
			TweenService:Create(barFill, TS_MED, {Size = UDim2.new(pct, 0, 1, 0), BackgroundColor3 = fillColor}):Play()
		end

		local bonusLbl = child:FindFirstChild("BonusLbl")
		if bonusLbl then
			if activeBonus then
				bonusLbl.Text = activeBonus.bonus
				bonusLbl.TextColor3 = Color3.fromRGB(100, 230, 130)
			elseif nextThresh then
				bonusLbl.Text = "Need " .. nextThresh.count .. " → " .. nextThresh.bonus
				bonusLbl.TextColor3 = Color3.fromRGB(140, 140, 90)
			else
				bonusLbl.Text = synDef.thresholds[1] and synDef.thresholds[1].bonus or "—"
				bonusLbl.TextColor3 = Color3.fromRGB(50, 50, 60)
			end
		end

		TweenService:Create(child, TS_MED, {BackgroundTransparency = count > 0 and 0 or 0.65}):Play()
	end
end

-- ── Refresh: inventory tile team indicators ───────────────────────────────────
local function refreshTileIndicators()
	if not invScroll then return end
	for _, child in ipairs(invScroll:GetChildren()) do
		if child:IsA("TextButton") then
			local ind = child:FindFirstChild("TeamInd")
			if ind then
				local idStr = child.Name:match("^Tile(%d+)$")
				if idStr then ind.Visible = isInTeam(tonumber(idStr)) end
			end
		end
	end
end

-- ── Card detail panel ─────────────────────────────────────────────────────────
local function selectCard(card)
	selectedCard = card

	if not card then
		if detEmpty   then detEmpty.Visible   = true  end
		if detContent then detContent.Visible = false end
		refreshTeamSlots()
		return
	end

	if detEmpty   then detEmpty.Visible   = false end
	if detContent then detContent.Visible = true  end

	local rc = RARITY_COLOR[card.rarity] or Color3.fromRGB(60, 60, 80)
	local rb = RARITY_BG[card.rarity]    or Color3.fromRGB(20, 20, 28)

	if detArtBg then
		detArtBg.BackgroundColor3 = rb
		local s = detArtBg:FindFirstChildOfClass("UIStroke")
		if s then s.Color = rc end
	end

	if detName then detName.Text = card.name end

	if detRarityBadge then
		detRarityBadge.BackgroundColor3 = rc
		local lbl = detRarityBadge:FindFirstChild("Lbl")
		if lbl then lbl.Text = card.rarity:upper() end
	end

	if detRoleBadge then
		detRoleBadge.BackgroundColor3 = ROLE_COLOR[card.role] or Color3.fromRGB(80, 80, 80)
		local lbl = detRoleBadge:FindFirstChild("Lbl")
		if lbl then lbl.Text = card.role:upper() end
	end

	if detATK then detATK.Text = tostring(card.attack) end
	if detHP  then detHP.Text  = tostring(card.hp)     end
	if detMP  then detMP.Text  = tostring(card.mp)     end

	if detPassiveChip then
		local ptColor = PASSIVE_COLOR[card.passive_type] or Color3.fromRGB(100, 100, 180)
		detPassiveChip.BackgroundColor3 = ptColor
		local lbl = detPassiveChip:FindFirstChild("Lbl")
		if lbl then lbl.Text = card.passive_type or "—" end
	end

	if detPassiveDesc then
		local roleDef = roleConf.Roles[card.role]
		local desc = ""
		if roleDef then
			if roleDef.passiveDesc then
				desc = roleDef.passiveDesc
			elseif roleDef.passives and card.passive_type then
				desc = roleDef.passives[card.passive_type] or ""
			end
		end
		detPassiveDesc.Text = desc
	end

	if detCardPassiveLbl then
		local label = card.passive_name or card.passive
		if label and label ~= "" then
			detCardPassiveLbl.Text    = label
			detCardPassiveLbl.Visible = true
		else
			detCardPassiveLbl.Visible = false
		end
	end

	refreshTeamSlots()
end

-- ── Equip / remove ────────────────────────────────────────────────────────────
local function scheduleSave()
	if saveDebounce then task.cancel(saveDebounce) end
	saveDebounce = task.delay(1.5, function()
		pcall(function() rfSetTeam:InvokeServer(team) end)
	end)
end

local function equipToSlot(slotIdx)
	if not selectedCard then return end
	local cardId = selectedCard.id
	for i = 1, 5 do if team[i] == cardId then team[i] = false end end
	team[slotIdx] = cardId
	refreshTeamSlots()
	refreshSynergies()
	refreshTileIndicators()
	scheduleSave()
	local sf = slotFrames[slotIdx]
	if sf then
		sf.BackgroundColor3 = Color3.fromRGB(28, 48, 30)
		TweenService:Create(sf, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundColor3 = Color3.fromRGB(20, 20, 32)}):Play()
	end
end

local function removeFromSlot(slotIdx)
	team[slotIdx] = false
	refreshTeamSlots()
	refreshSynergies()
	refreshTileIndicators()
	scheduleSave()
end

-- ── Build: team slot frame ────────────────────────────────────────────────────
local function buildSlotFrame(slotIdx, parent)
	local yPos = SLOT_HDR_H + (slotIdx - 1) * (SLOT_H + SLOT_GAP)
	local W = SLOTS_W - 12

	local sf = Instance.new("TextButton")
	sf.Name = "Slot" .. slotIdx; sf.Text = ""; sf.AutoButtonColor = false
	sf.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
	sf.Position = UDim2.new(0, 6, 0, yPos); sf.Size = UDim2.new(0, W, 0, SLOT_H)
	sf.BorderSizePixel = 0; sf.ZIndex = 11; sf.Parent = parent
	corner(sf, 8)
	stroke(sf, 1, Color3.fromRGB(45, 45, 65))

	-- Slot number badge
	local badge = F(sf, "Badge", Color3.fromRGB(30, 50, 95), 8, 8, 26, 26, 12)
	corner(badge, 13)
	local bl = L(badge, tostring(slotIdx), 0, 0, 26, 26, 13, Color3.fromRGB(160, 200, 255), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	bl.ZIndex = 13

	-- FRONTLINE tag (slot 1 only)
	if slotIdx == 1 then
		local ftag = F(sf, "FrontlineTag", Color3.fromRGB(35, 90, 55), 8, 38, 68, 16, 12)
		corner(ftag, 4)
		local ftl = L(ftag, "FRONTLINE", 0, 0, 68, 16, 9, Color3.fromRGB(120, 240, 160), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		ftl.ZIndex = 13
	end

	-- Empty state
	local emptyGrp = F(sf, "EmptyGrp", Color3.fromRGB(20, 20, 32), 0, 0, W, SLOT_H, 12)
	emptyGrp.BackgroundTransparency = 1
	L(emptyGrp, "— Empty —", 40, 28, W - 50, 20, 13, Color3.fromRGB(95, 95, 120), Enum.Font.Gotham, Enum.TextXAlignment.Left).ZIndex = 13
	local hl = L(emptyGrp, "Select a card below", 40, 50, W - 50, 14, 10, Color3.fromRGB(85, 85, 110), Enum.Font.Gotham, Enum.TextXAlignment.Left)
	hl.Name = "HintLbl"; hl.ZIndex = 13

	-- Occupied state
	local occGrp = F(sf, "OccGrp", Color3.fromRGB(20, 20, 32), 0, 0, W, SLOT_H, 12)
	occGrp.BackgroundTransparency = 1; occGrp.Visible = false

	local cn = L(occGrp, "", 40, 7, W - 72, 20, 13, Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	cn.Name = "CardName"; cn.ZIndex = 13

	local rb = F(occGrp, "RoleBadge", ROLE_COLOR.Tank, 40, 30, 52, 16, 12)
	corner(rb, 4)
	local rbl = L(rb, "TANK", 0, 0, 52, 16, 9, Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	rbl.Name = "RoleLbl"; rbl.ZIndex = 13

	local rarl = L(occGrp, "", 96, 30, W - 108, 16, 10, Color3.fromRGB(130, 130, 130), Enum.Font.Gotham, Enum.TextXAlignment.Left)
	rarl.Name = "RarityLbl"; rarl.ZIndex = 13

	local stl = L(occGrp, "", 40, 52, W - 50, 14, 10, Color3.fromRGB(150, 150, 170), Enum.Font.Gotham, Enum.TextXAlignment.Left)
	stl.Name = "StatsLbl"; stl.ZIndex = 13

	-- Remove button (child TextButton; click doesn't bubble to parent)
	local removeBtn = B(occGrp, "×", W - 30, 6, 24, 24, Color3.fromRGB(75, 22, 22), Color3.new(1, 1, 1))
	removeBtn.Name = "RemoveBtn"; removeBtn.TextSize = 16; removeBtn.ZIndex = 14

	removeBtn.MouseButton1Click:Connect(function()
		removeFromSlot(slotIdx)
	end)

	sf.MouseButton1Click:Connect(function()
		if selectedCard then
			equipToSlot(slotIdx)
		else
			local id = team[slotIdx]
			if id and id ~= false then selectCard(cardDb:GetById(id)) end
		end
	end)

	sf.MouseEnter:Connect(function()
		TweenService:Create(sf, TS_FAST, {BackgroundColor3 = Color3.fromRGB(36, 36, 52)}):Play()
	end)
	sf.MouseLeave:Connect(function()
		TweenService:Create(sf, TS_FAST, {BackgroundColor3 = Color3.fromRGB(20, 20, 32)}):Play()
	end)

	return sf
end

-- ── Build: card detail (center-top) ──────────────────────────────────────────
local function buildCardDetail(centerFrame)
	local det = F(centerFrame, "CardDetail", Color3.fromRGB(16, 16, 24), 0, 0, CENTER_W, DET_H, 11)

	detEmpty = F(det, "Empty", Color3.fromRGB(16, 16, 24), 0, 0, CENTER_W, DET_H, 12)
	detEmpty.BackgroundTransparency = 1
	local el = L(detEmpty, "Select a card from your collection below", 0, 0, CENTER_W, DET_H, 15, Color3.fromRGB(50, 50, 65), Enum.Font.Gotham, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
	el.TextWrapped = true; el.ZIndex = 13

	detContent = F(det, "Content", Color3.fromRGB(16, 16, 24), 0, 0, CENTER_W, DET_H, 12)
	detContent.BackgroundTransparency = 1; detContent.Visible = false

	-- Art frame
	detArtBg = F(detContent, "Art", Color3.fromRGB(20, 20, 28), 10, 10, 104, DET_H - 20, 13)
	corner(detArtBg, 8)
	stroke(detArtBg, 2, Color3.fromRGB(60, 60, 80), Enum.ApplyStrokeMode.Border)

	-- Info block
	local IX = 124
	local IW = CENTER_W - IX - 10

	detName = L(detContent, "", IX, 10, IW, 26, 18, Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	detName.ZIndex = 13

	detRarityBadge = F(detContent, "RarityBadge", Color3.fromRGB(100, 100, 100), IX, 40, 78, 20, 13)
	corner(detRarityBadge, 5)
	local rbl = L(detRarityBadge, "", 0, 0, 78, 20, 10, Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	rbl.Name = "Lbl"; rbl.ZIndex = 14

	detRoleBadge = F(detContent, "RoleBadge", ROLE_COLOR.Tank, IX + 82, 40, 60, 20, 13)
	corner(detRoleBadge, 5)
	local rolel = L(detRoleBadge, "", 0, 0, 60, 20, 10, Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	rolel.Name = "Lbl"; rolel.ZIndex = 14

	F(detContent, "Div", Color3.fromRGB(35, 35, 50), IX, 66, IW, 1).ZIndex = 13

	-- Stats
	local statW = math.floor(IW / 3) - 4
	local statLabels = { { "ATK", "detATK" }, { "HP", "detHP" }, { "MP", "detMP" } }
	for i, st in ipairs(statLabels) do
		local sx = IX + (i - 1) * (statW + 6)
		local box = F(detContent, st[1] .. "Box", Color3.fromRGB(22, 22, 34), sx, 74, statW, 46, 13)
		corner(box, 6)
		L(box, st[1], 0, 4, statW, 14, 9, Color3.fromRGB(110, 110, 150), Enum.Font.GothamBold, Enum.TextXAlignment.Center).ZIndex = 14
		local vl = L(box, "0", 0, 20, statW, 22, 14, Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
		vl.Name = "Val"; vl.ZIndex = 14
		if st[2] == "detATK" then detATK = vl
		elseif st[2] == "detHP" then detHP = vl
		else detMP = vl end
	end

	-- Role passive section
	local rpY = 130
	L(detContent, "ROLE PASSIVE", IX, rpY, 90, 15, 9, Color3.fromRGB(90, 90, 120), Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 13

	detPassiveChip = F(detContent, "PassiveChip", Color3.fromRGB(60, 130, 220), IX + 94, rpY, 92, 15, 13)
	corner(detPassiveChip, 4)
	local pcl = L(detPassiveChip, "", 0, 0, 92, 15, 9, Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Center)
	pcl.Name = "Lbl"; pcl.ZIndex = 14

	detPassiveDesc = L(detContent, "", IX, rpY + 18, IW, 34, 11, Color3.fromRGB(155, 160, 180), Enum.Font.Gotham, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top)
	detPassiveDesc.TextWrapped = true; detPassiveDesc.TextTruncate = Enum.TextTruncate.None; detPassiveDesc.ZIndex = 13

	-- Card passive
	L(detContent, "CARD PASSIVE", IX, rpY + 56, 90, 15, 9, Color3.fromRGB(90, 90, 120), Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 13
	detCardPassiveLbl = L(detContent, "", IX + 94, rpY + 56, IW - 94, 15, 11, Color3.fromRGB(200, 180, 110), Enum.Font.Gotham, Enum.TextXAlignment.Left)
	detCardPassiveLbl.ZIndex = 13

	-- Equip hint
	L(detContent, "Click a team slot (left) to equip", IX, DET_H - 28, IW, 14, 10, Color3.fromRGB(55, 95, 55), Enum.Font.Gotham, Enum.TextXAlignment.Left).ZIndex = 13
end

-- ── Build: synergy panel (right) ─────────────────────────────────────────────
local function buildSynergyPanel(rightFrame)
	local bg = F(rightFrame, "Bg", Color3.fromRGB(14, 14, 22), 0, 0, RIGHT_W, BODY_H, 11)

	-- Header
	L(bg, "BONUSES", 10, 8, RIGHT_W - 20, 16, 10, Color3.fromRGB(120, 120, 155), Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 12

	-- Role bonus rows (Tank / DPS / Support)
	local roleOrder = { "Tank", "DPS", "Support" }
	local rowY = 28
	for _, roleName in ipairs(roleOrder) do
		local rowBg = F(bg, roleName .. "Row", Color3.fromRGB(20, 20, 32), 6, rowY, RIGHT_W - 12, 42, 12)
		corner(rowBg, 6)
		local strip = F(rowBg, "Strip", ROLE_COLOR[roleName], 0, 0, 4, 42, 13)
		corner(strip, 2)

		local cl = L(rowBg, roleName .. ": 0", 10, 4, RIGHT_W - 22, 16, 12, Color3.fromRGB(60, 60, 70), Enum.Font.GothamBold, Enum.TextXAlignment.Left)
		cl.Name = "CountLbl"; cl.ZIndex = 13
		local bl = L(rowBg, "—", 10, 22, RIGHT_W - 22, 14, 10, Color3.fromRGB(60, 60, 70), Enum.Font.Gotham, Enum.TextXAlignment.Left)
		bl.Name = "BonusLbl"; bl.ZIndex = 13

		roleRows[roleName] = { countLbl = cl, bonusLbl = bl }
		rowY = rowY + 46
	end

	-- Synergy section header
	local divY = rowY + 4
	F(bg, "Div", Color3.fromRGB(35, 35, 50), 6, divY, RIGHT_W - 12, 1).ZIndex = 12
	L(bg, "SYNERGIES", 10, divY + 6, RIGHT_W - 20, 14, 9, Color3.fromRGB(100, 100, 130), Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 12

	-- Synergy scroll
	local synY = divY + 24
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "SynScroll"; scroll.Parent = bg
	scroll.Position = UDim2.new(0, 4, 0, synY)
	scroll.Size = UDim2.new(0, RIGHT_W - 8, 0, BODY_H - synY - 4)
	scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5; scroll.ScrollBarImageColor3 = Color3.fromRGB(55, 55, 75)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 12

	local list = Instance.new("UIListLayout"); list.Parent = scroll
	list.Padding = UDim.new(0, 4); list.SortOrder = Enum.SortOrder.LayoutOrder

	-- Synergy entries
	for order, synName in ipairs(roleConf.SynergyOrder) do
		local synDef = roleConf.Synergies[synName]
		if not synDef then continue end
		local entW = RIGHT_W - 12

		local entry = F(scroll, "Syn_" .. order, Color3.fromRGB(20, 20, 32), 0, 0, entW, 54, 13)
		corner(entry, 6); entry.LayoutOrder = order
		entry:SetAttribute("SynName", synName)

		L(entry, synName, 8, 5, entW - 56, 16, 11, Color3.fromRGB(160, 160, 195), Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 14

		local cl = L(entry, "0 / " .. synDef.maxCount, entW - 48, 5, 44, 16, 9, Color3.fromRGB(55, 55, 65), Enum.Font.Gotham, Enum.TextXAlignment.Right)
		cl.Name = "CountLbl"; cl.ZIndex = 14

		-- Color strip on left edge
		local cstrip = F(entry, "CStrip", synDef.color or Color3.fromRGB(80, 80, 120), 0, 0, 4, 54, 14)
		corner(cstrip, 2)

		local barBg = F(entry, "BarBg", Color3.fromRGB(14, 14, 20), 8, 24, entW - 18, 6, 14)
		corner(barBg, 3)
		local barFill = F(barBg, "BarFill", Color3.fromRGB(70, 70, 100), 0, 0, 0, 6, 15)
		corner(barFill, 3)

		local bl = L(entry, synDef.thresholds[1] and synDef.thresholds[1].bonus or "—", 8, 34, entW - 18, 14, 9, Color3.fromRGB(50, 50, 60), Enum.Font.Gotham, Enum.TextXAlignment.Left)
		bl.Name = "BonusLbl"; bl.TextTruncate = Enum.TextTruncate.AtEnd; bl.ZIndex = 14
	end

	synergyScroll = scroll
end

-- ── Build: inventory mini-grid (center-bottom) ────────────────────────────────
local function buildMiniTile(card)
	local t = Instance.new("TextButton")
	t.Name = "Tile" .. card.id
	t.Size = UDim2.new(0, MINI_TW, 0, MINI_TH)
	t.BackgroundColor3 = RARITY_BG[card.rarity] or Color3.fromRGB(20, 20, 28)
	t.Text = ""; t.BorderSizePixel = 0; t.ZIndex = 12; t.AutoButtonColor = false
	t.Parent = invScroll
	corner(t, 6)
	local rarStroke = stroke(t, 2, RARITY_COLOR[card.rarity] or Color3.fromRGB(80, 80, 80), Enum.ApplyStrokeMode.Border)
	rarStroke.Name = "RarStroke"

	local art = F(t, "Art", Color3.fromRGB(10, 10, 14), 4, 4, MINI_TW - 8, MINI_TH - 26, 13)
	corner(art, 4)

	local nl = L(t, card.name, 2, MINI_TH - 22, MINI_TW - 4, 20, 9, Color3.fromRGB(200, 200, 225), Enum.Font.Gotham, Enum.TextXAlignment.Center)
	nl.ZIndex = 13

	-- Role dot
	local rdot = F(t, "RoleDot", ROLE_COLOR[card.role] or Color3.fromRGB(80, 80, 80), MINI_TW - 13, 4, 9, 9, 14)
	corner(rdot, 5)

	-- Team overlay
	local ind = F(t, "TeamInd", Color3.fromRGB(25, 90, 35), 0, 0, MINI_TW, MINI_TH, 14)
	ind.BackgroundTransparency = 0.65; ind.Visible = false; corner(ind, 6)
	local itl = L(ind, "EQUIPPED", 0, 0, MINI_TW, MINI_TH, 8, Color3.fromRGB(80, 255, 130), Enum.Font.GothamBold, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
	itl.ZIndex = 15

	-- Selection highlight
	local selStroke = stroke(t, 2, Color3.fromRGB(80, 200, 100), Enum.ApplyStrokeMode.Border)
	selStroke.Enabled = false; selStroke.Name = "SelStroke"

	t.MouseEnter:Connect(function()
		TweenService:Create(rarStroke, TS_FAST, {Thickness = 3.5}):Play()
	end)
	t.MouseLeave:Connect(function()
		TweenService:Create(rarStroke, TS_FAST, {Thickness = 2}):Play()
	end)

	t.MouseButton1Click:Connect(function()
		-- Update selection stroke on old selected tile
		if selectedCard then
			local old = invScroll:FindFirstChild("Tile" .. selectedCard.id)
			if old then
				local ss = old:FindFirstChild("SelStroke")
				if ss then ss.Enabled = false end
			end
		end

		if selectedCard and selectedCard.id == card.id then
			selectCard(nil)
		else
			selectCard(card)
			selStroke.Enabled = true
		end
	end)

	return t
end

local function rebuildInventoryGrid()
	if not invScroll then return end
	for _, ch in ipairs(invScroll:GetChildren()) do
		if ch:IsA("TextButton") then ch:Destroy() end
	end
	for _, card in ipairs(allCards) do
		local tile = buildMiniTile(card)
		local ind = tile:FindFirstChild("TeamInd")
		if ind then ind.Visible = isInTeam(card.id) end
	end
end

-- ── Build: full panel ─────────────────────────────────────────────────────────
local function buildPanel(gui)
	panel = F(gui, "TeamBuilderPanel", Color3.fromRGB(14, 14, 22), 0, 0, PW, PH, 20)
	panel.Position = UDim2.new(0.5, -PW / 2, 0.5, -PH / 2)
	panel.Visible = false; panel.ClipsDescendants = true
	corner(panel, 12)
	stroke(panel, 1, Color3.fromRGB(40, 40, 60))

	-- Top bar
	local topbar = F(panel, "TopBar", Color3.fromRGB(18, 18, 30), 0, 0, PW, TOPBAR_H, 21)
	F(panel, "TopDiv", Color3.fromRGB(35, 35, 50), 0, TOPBAR_H, PW, 1).ZIndex = 21
	L(topbar, "TEAM BUILDER", 16, 0, 220, TOPBAR_H, 15, Color3.fromRGB(210, 215, 255), Enum.Font.GothamBold, Enum.TextXAlignment.Left, Enum.TextYAlignment.Center).ZIndex = 22
	teamCountLbl = L(topbar, "0 / 5", PW / 2 - 30, 0, 60, TOPBAR_H, 13, Color3.fromRGB(120, 130, 170), Enum.Font.Gotham, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
	teamCountLbl.ZIndex = 22
	local closeBtn = B(topbar, "×", PW - 46, 6, 32, 32, Color3.fromRGB(70, 22, 22), Color3.new(1, 1, 1))
	closeBtn.TextSize = 18; closeBtn.ZIndex = 22
	closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

	-- Body
	local body = F(panel, "Body", Color3.fromRGB(14, 14, 22), 0, BODY_Y, PW, BODY_H, 21)
	body.ClipsDescendants = true

	-- Left: team slots
	local slotsFrame = F(body, "Slots", Color3.fromRGB(14, 14, 22), 0, 0, SLOTS_W, BODY_H, 11)
	L(slotsFrame, "YOUR TEAM", 8, 8, SLOTS_W - 16, 18, 10, Color3.fromRGB(90, 90, 120), Enum.Font.GothamBold, Enum.TextXAlignment.Left).ZIndex = 12
	for i = 1, 5 do
		slotFrames[i] = buildSlotFrame(i, slotsFrame)
	end

	-- Divider 1
	F(body, "Div1", Color3.fromRGB(35, 35, 50), SLOTS_W, 0, 1, BODY_H).ZIndex = 11

	-- Center
	local centerFrame = F(body, "Center", Color3.fromRGB(16, 16, 24), CENTER_X, 0, CENTER_W, BODY_H, 11)
	buildCardDetail(centerFrame)

	-- Horizontal divider inside center
	F(centerFrame, "HDiv", Color3.fromRGB(35, 35, 50), 0, DET_H, CENTER_W, 1).ZIndex = 12

	-- Inventory scroll
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "InvScroll"; scroll.Parent = centerFrame
	scroll.Position = UDim2.new(0, 0, 0, DET_H + 1); scroll.Size = UDim2.new(0, CENTER_W, 0, INV_H)
	scroll.BackgroundColor3 = Color3.fromRGB(13, 13, 20)
	scroll.BorderSizePixel = 0; scroll.ZIndex = 12
	scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = Color3.fromRGB(48, 48, 68)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

	local grid = Instance.new("UIGridLayout"); grid.Parent = scroll
	grid.CellSize = UDim2.new(0, MINI_TW, 0, MINI_TH)
	grid.CellPadding = UDim2.new(0, MINI_GAP, 0, MINI_GAP)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder

	local pad = Instance.new("UIPadding"); pad.Parent = scroll
	pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)

	invScroll = scroll

	-- Divider 2
	F(body, "Div2", Color3.fromRGB(35, 35, 50), RIGHT_X - 1, 0, 1, BODY_H).ZIndex = 11

	-- Right: synergy panel
	local rightFrame = F(body, "Right", Color3.fromRGB(14, 14, 22), RIGHT_X, 0, RIGHT_W, BODY_H, 11)
	buildSynergyPanel(rightFrame)
end

-- ── Data loader ───────────────────────────────────────────────────────────────
local function loadData()
	local ok1, invData = pcall(function() return rfGetInventory:InvokeServer() end)
	local ok2, teamData = pcall(function() return rfGetTeam:InvokeServer() end)

	if ok1 and invData and invData.cardIds then
		allCards = {}
		for _, id in ipairs(invData.cardIds) do
			local card = cardDb:GetById(id)
			if card then table.insert(allCards, card) end
		end
		table.sort(allCards, function(a, b)
			local ra = rarityConf:GetOrder(a.rarity) or 0
			local rb = rarityConf:GetOrder(b.rarity) or 0
			if ra ~= rb then return ra > rb end
			return a.name < b.name
		end)
		rebuildInventoryGrid()
	end

	if ok2 and teamData then
		for i = 1, 5 do
			local v = teamData[i]
			team[i] = (type(v) == "number" and v > 0) and v or false
		end
	end

	refreshTeamSlots()
	refreshSynergies()
	refreshTileIndicators()
end

-- ── Public API ────────────────────────────────────────────────────────────────
function TeamBuilderUI:Init(gui, db, rc, roleC, rfInv, rfGT, rfST)
	cardDb         = db
	rarityConf     = rc
	roleConf       = roleC
	rfGetInventory = rfInv
	rfGetTeam      = rfGT
	rfSetTeam      = rfST
	buildPanel(gui)
end

function TeamBuilderUI:Show()
	panel.Position = UDim2.new(0.5, -PW/2, 0.5, -PH/2 + 18)
	panel.Visible = true
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -PW/2, 0.5, -PH/2)}):Play()
	selectedCard  = nil
	selectCard(nil)
	task.spawn(loadData)
end

function TeamBuilderUI:Hide()
	TweenService:Create(panel, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5, -PW/2, 0.5, -PH/2 + 14)}):Play()
	task.delay(0.14, function() if panel then panel.Visible = false end end)
end

function TeamBuilderUI:GetPanel()
	return panel
end

return TeamBuilderUI
