-- QuestUI — daily/weekly quests, login streak calendar, the Battle Pass
-- tier/XP bar, and (Phase 8) account level/titles/prestige/artifacts under a
-- 4th PROGRESS tab — consolidated here rather than a new side-menu button,
-- same reasoning Phase 7 used for SocialUI. Pure view: claims/equips/prestige
-- are routed through callbacks; Refresh(state)/RefreshAccount(data) push
-- fresh server data into the panel.

local QuestUI = {}

local panel, tabButtons = {}, {}
local tabFrames = {}
local questRows = {}     -- [scope.."_"..id] = { row, bar, btn }
local streakCells = {}   -- [day] = { frame, btn }
local titleRows = {}
local artifactRows = {}

local MonetizationConfig
local callbacks = {}
local state = { daily = {}, weekly = {}, loginStreak = {}, dailyPool = {}, weeklyPool = {}, streakCalendar = {}, battlePass = {} }

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function stroke(inst, color, thickness)
	local s = Instance.new("UIStroke"); s.Color = color or Color3.fromRGB(50, 50, 80); s.Thickness = thickness or 1; s.Parent = inst
	return s
end

local function label(parent, text, size, pos, color, font)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text; l.TextColor3 = color or Color3.fromRGB(220, 220, 240)
	l.TextScaled = true; l.Font = font or Enum.Font.Gotham
	l.ZIndex = 22; l.Parent = parent
	return l
end

local function button(parent, text, size, pos, bg)
	local b = Instance.new("TextButton")
	b.Size = size; b.Position = pos
	b.BackgroundColor3 = bg or Color3.fromRGB(60, 60, 90)
	b.BorderSizePixel = 0
	b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
	b.TextScaled = true; b.Font = Enum.Font.GothamBold
	b.ZIndex = 22; b.Parent = parent
	corner(b, 6)
	return b
end

local function rewardText(reward)
	local parts = {}
	if reward.gems then table.insert(parts, reward.gems .. " Gems") end
	if reward.packs then
		for packType, n in pairs(reward.packs) do
			table.insert(parts, n .. "x " .. packType)
		end
	end
	return table.concat(parts, " + ")
end

local HEADER_HEIGHT = 66

local function buildTopBar(gui)
	local tb = Instance.new("Frame")
	tb.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	tb.BackgroundColor3 = Color3.fromRGB(10, 14, 20)
	tb.BorderSizePixel = 0
	tb.ZIndex = 21; tb.Parent = panel.root

	label(tb, "QUESTS", UDim2.new(0, 120, 0, 28), UDim2.new(0, 16, 0, 8),
		Color3.fromRGB(120, 220, 160), Enum.Font.GothamBlack)

	local passLbl = label(tb, "Battle Pass Tier 0", UDim2.new(0, 220, 0, 24), UDim2.new(1, -236, 0, 10),
		Color3.fromRGB(200, 160, 255), Enum.Font.GothamBold)
	passLbl.TextXAlignment = Enum.TextXAlignment.Right
	panel.passLbl = passLbl

	local closeBtn = button(tb, "X", UDim2.new(0, 28, 0, 28), UDim2.new(1, -22, 0, 8), Color3.fromRGB(80, 30, 30))
	closeBtn.MouseButton1Click:Connect(function() QuestUI:Hide() end)

	local tabNames = { { id = "daily", label = "DAILY" }, { id = "weekly", label = "WEEKLY" }, { id = "streak", label = "STREAK" }, { id = "progress", label = "PROGRESS" } }
	local TAB_W, TAB_GAP = 110, 6
	for i, t in ipairs(tabNames) do
		local b = button(tb, t.label, UDim2.new(0, TAB_W, 0, 26), UDim2.new(0, 8 + (i - 1) * (TAB_W + TAB_GAP), 0, 36),
			Color3.fromRGB(24, 30, 24))
		b.TextSize = 12
		tabButtons[t.id] = b
		b.MouseButton1Click:Connect(function() QuestUI:ShowTab(t.id) end)
	end
end

local function buildQuestRow(parent, y, scope)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -32, 0, 58); row.Position = UDim2.new(0, 16, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(18, 22, 18); row.BorderSizePixel = 0
	row.ZIndex = 22; row.Parent = parent
	corner(row, 8)

	local descLbl = label(row, "", UDim2.new(0.62, 0, 0, 24), UDim2.new(0, 12, 0, 6),
		Color3.fromRGB(220, 230, 220), Enum.Font.GothamBold)
	descLbl.TextXAlignment = Enum.TextXAlignment.Left

	local rewardLbl = label(row, "", UDim2.new(0.62, 0, 0, 18), UDim2.new(0, 12, 0, 30),
		Color3.fromRGB(150, 200, 255), Enum.Font.Gotham)
	rewardLbl.TextXAlignment = Enum.TextXAlignment.Left
	rewardLbl.TextSize = 13

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0.62, -12, 0, 6); barBg.Position = UDim2.new(0, 12, 1, -12)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 44, 40); barBg.BorderSizePixel = 0
	barBg.ZIndex = 22; barBg.Parent = row
	corner(barBg, 3)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(120, 220, 160); bar.BorderSizePixel = 0
	bar.ZIndex = 23; bar.Parent = barBg
	corner(bar, 3)

	local btn = button(row, "0/0", UDim2.new(0, 110, 0, 40), UDim2.new(1, -122, 0.5, -20), Color3.fromRGB(50, 50, 70))
	btn.MouseButton1Click:Connect(function()
		if callbacks.onClaimQuest then callbacks.onClaimQuest(scope, btn:GetAttribute("questId")) end
	end)

	return { row = row, descLbl = descLbl, rewardLbl = rewardLbl, bar = bar, btn = btn }
end

local function buildQuestTab(gui, scope)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames[scope] = f

	local maxRows = scope == "daily" and 3 or 3
	for i = 1, maxRows do
		local rowUI = buildQuestRow(f, 8 + (i - 1) * 66, scope)
		questRows[scope .. "_" .. i] = rowUI
	end
end

local function buildStreakTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.streak = f

	label(f, "Log in daily for escalating rewards. Miss a day and the streak resets.",
		UDim2.new(1, -32, 0, 30), UDim2.new(0, 16, 0, 4), Color3.fromRGB(160, 170, 160), Enum.Font.Gotham).TextSize = 13

	local CELL_W, GAP = 68, 8
	for day = 1, 7 do
		local cell = Instance.new("Frame")
		cell.Size = UDim2.new(0, CELL_W, 0, 90)
		cell.Position = UDim2.new(0, 16 + (day - 1) * (CELL_W + GAP), 0, 40)
		cell.BackgroundColor3 = Color3.fromRGB(18, 22, 18); cell.BorderSizePixel = 0
		cell.ZIndex = 22; cell.Parent = f
		corner(cell, 8)
		local st = stroke(cell, Color3.fromRGB(50, 60, 50), 1)

		label(cell, "Day " .. day, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 4), Color3.fromRGB(200, 210, 200), Enum.Font.GothamBold).TextSize = 12

		local rewardLbl = label(cell, "", UDim2.new(1, -6, 0, 34), UDim2.new(0, 3, 0, 22), Color3.fromRGB(150, 200, 255), Enum.Font.Gotham)
		rewardLbl.TextWrapped = true; rewardLbl.TextSize = 11

		local claimBtn = button(cell, "CLAIM", UDim2.new(1, -8, 0, 22), UDim2.new(0, 4, 1, -26), Color3.fromRGB(50, 130, 60))
		claimBtn.TextSize = 11
		claimBtn.MouseButton1Click:Connect(function()
			if callbacks.onClaimStreak then callbacks.onClaimStreak() end
		end)

		streakCells[day] = { cell = cell, stroke = st, rewardLbl = rewardLbl, claimBtn = claimBtn }
	end
end

-- ── PROGRESS tab (Phase 8: account level, titles, prestige, artifacts) ───────

local function buildProgressTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.progress = f

	-- Account level bar.
	local lvlLbl = label(f, "Account Level 1", UDim2.new(0.5, 0, 0, 20), UDim2.new(0, 8, 0, 4),
		Color3.fromRGB(220, 230, 220), Enum.Font.GothamBold)
	lvlLbl.TextXAlignment = Enum.TextXAlignment.Left
	panel.acctLvlLbl = lvlLbl

	local xpBarBg = Instance.new("Frame")
	xpBarBg.Size = UDim2.new(1, -16, 0, 8); xpBarBg.Position = UDim2.new(0, 8, 0, 26)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(30, 34, 30); xpBarBg.BorderSizePixel = 0
	xpBarBg.ZIndex = 21; xpBarBg.Parent = f
	corner(xpBarBg, 4)
	local xpBar = Instance.new("Frame")
	xpBar.Size = UDim2.new(0, 0, 1, 0)
	xpBar.BackgroundColor3 = Color3.fromRGB(120, 220, 160); xpBar.BorderSizePixel = 0
	xpBar.ZIndex = 22; xpBar.Parent = xpBarBg
	corner(xpBar, 4)
	panel.acctXpBar = xpBar

	local xpLbl = label(f, "", UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 36), Color3.fromRGB(160, 170, 160), Enum.Font.Gotham)
	xpLbl.TextXAlignment = Enum.TextXAlignment.Left; xpLbl.TextSize = 12
	panel.acctXpLbl = xpLbl

	label(f, "Titles", UDim2.new(0.3, 0, 0, 16), UDim2.new(0, 8, 0, 58), Color3.fromRGB(160, 170, 160), Enum.Font.GothamBold).TextSize = 12

	local titleScroll = Instance.new("ScrollingFrame")
	titleScroll.Size = UDim2.new(1, -16, 0, 70); titleScroll.Position = UDim2.new(0, 8, 0, 76)
	titleScroll.BackgroundTransparency = 1; titleScroll.BorderSizePixel = 0
	titleScroll.ScrollBarThickness = 4
	titleScroll.CanvasSize = UDim2.new(0, 8 * 150, 0, 0)
	titleScroll.ZIndex = 21; titleScroll.Parent = f

	for i = 1, 8 do
		local btn = button(titleScroll, "—", UDim2.new(0, 140, 0, 30), UDim2.new(0, (i - 1) * 148, 0, 0), Color3.fromRGB(50, 50, 70))
		btn.TextSize = 12
		btn.Visible = false
		btn.MouseButton1Click:Connect(function()
			local title = btn:GetAttribute("title")
			if title ~= nil and callbacks.onEquipTitle then callbacks.onEquipTitle(title) end
		end)
		titleRows[i] = btn
	end

	label(f, "Tower Prestige", UDim2.new(0.4, 0, 0, 16), UDim2.new(0, 8, 0, 154), Color3.fromRGB(160, 170, 160), Enum.Font.GothamBold).TextSize = 12

	local prestigeInfoLbl = label(f, "", UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 0, 172),
		Color3.fromRGB(200, 210, 200), Enum.Font.Gotham)
	prestigeInfoLbl.TextXAlignment = Enum.TextXAlignment.Left; prestigeInfoLbl.TextWrapped = true; prestigeInfoLbl.TextSize = 12
	panel.prestigeInfoLbl = prestigeInfoLbl

	local prestigeBtn = button(f, "PRESTIGE", UDim2.new(0, 160, 0, 32), UDim2.new(0, 8, 0, 206), Color3.fromRGB(160, 120, 40))
	prestigeBtn.MouseButton1Click:Connect(function()
		if callbacks.onPrestige then callbacks.onPrestige() end
	end)
	panel.prestigeBtn = prestigeBtn

	label(f, "Artifacts", UDim2.new(0.4, 0, 0, 16), UDim2.new(0, 8, 0, 246), Color3.fromRGB(160, 170, 160), Enum.Font.GothamBold).TextSize = 12

	local artifactScroll = Instance.new("ScrollingFrame")
	artifactScroll.Size = UDim2.new(1, -16, 1, -270); artifactScroll.Position = UDim2.new(0, 8, 0, 264)
	artifactScroll.BackgroundTransparency = 1; artifactScroll.BorderSizePixel = 0
	artifactScroll.ScrollBarThickness = 4
	artifactScroll.CanvasSize = UDim2.new(0, 0, 0, 8 * 46)
	artifactScroll.ZIndex = 21; artifactScroll.Parent = f

	for i = 1, 8 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 40); row.Position = UDim2.new(0, 0, 0, (i - 1) * 46)
		row.BackgroundColor3 = Color3.fromRGB(18, 22, 18); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = artifactScroll
		row.Visible = false
		corner(row, 6)

		local nameLbl = label(row, "—", UDim2.new(0.7, 0, 1, 0), UDim2.new(0, 10, 0, 0),
			Color3.fromRGB(220, 220, 240), Enum.Font.Gotham)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.TextWrapped = true; nameLbl.TextSize = 12

		local equipBtn = button(row, "EQUIP", UDim2.new(0, 80, 0, 30), UDim2.new(1, -88, 0.5, -15), Color3.fromRGB(50, 130, 60))
		equipBtn.TextSize = 12
		equipBtn.MouseButton1Click:Connect(function()
			local artifactId = equipBtn:GetAttribute("artifactId")
			if artifactId ~= nil and callbacks.onEquipArtifact then callbacks.onEquipArtifact(artifactId) end
		end)

		artifactRows[i] = { row = row, nameLbl = nameLbl, equipBtn = equipBtn }
	end
end

-- data: {
--   account = { level, xp, nextLevelXp, unlockedTitles, equippedTitle, ownedArtifacts, equippedArtifact, artifactDefs },
--   prestige = { count, cycleBestFloor, bestFloor, minFloorToPrestige, maxPrestige, canPrestige, mult },
-- }
function QuestUI:RefreshAccount(data)
	data = data or {}
	local account = data.account or {}
	local prestige = data.prestige or {}

	panel.acctLvlLbl.Text = "Account Level " .. tostring(account.level or 1)
	local nextXp = account.nextLevelXp
	if nextXp then
		panel.acctXpBar.Size = UDim2.new(math.clamp((account.xp or 0) / nextXp, 0, 1), 0, 1, 0)
		panel.acctXpLbl.Text = string.format("%d / %d XP", account.xp or 0, nextXp)
	else
		panel.acctXpBar.Size = UDim2.new(1, 0, 1, 0)
		panel.acctXpLbl.Text = string.format("%d XP (max level)", account.xp or 0)
	end

	local titles = account.unlockedTitles or {}
	-- "None" is always the first option so a player can unequip.
	for i, btn in ipairs(titleRows) do
		if i == 1 then
			btn.Visible = true
			btn.Text = "NONE"
			btn:SetAttribute("title", "")
			btn.BackgroundColor3 = (account.equippedTitle == "" or not account.equippedTitle) and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(50, 50, 70)
		else
			local title = titles[i - 1]
			if title then
				btn.Visible = true
				btn.Text = title
				btn:SetAttribute("title", title)
				btn.BackgroundColor3 = (account.equippedTitle == title) and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(50, 50, 70)
			else
				btn.Visible = false
			end
		end
	end

	panel.prestigeInfoLbl.Text = string.format(
		"Prestige %d/%d — cycle best floor %d (need %d). Current bonus: +%d%% ATK/HP account-wide.",
		prestige.count or 0, prestige.maxPrestige or 0, prestige.cycleBestFloor or 0,
		prestige.minFloorToPrestige or 0, math.floor(((prestige.mult or 1) - 1) * 100 + 0.5))

	if prestige.canPrestige then
		panel.prestigeBtn.Text = "PRESTIGE NOW"
		panel.prestigeBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 40)
	elseif (prestige.count or 0) >= (prestige.maxPrestige or 0) then
		panel.prestigeBtn.Text = "MAX PRESTIGE"
		panel.prestigeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	else
		panel.prestigeBtn.Text = "NOT YET ELIGIBLE"
		panel.prestigeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	end

	local artifactDefs = account.artifactDefs or {}
	local owned = account.ownedArtifacts or {}
	for i, rowUI in ipairs(artifactRows) do
		local def = artifactDefs[i]
		if def then
			rowUI.row.Visible = true
			local isOwned = owned[def.id] == true
			local isEquipped = account.equippedArtifact == def.id
			rowUI.nameLbl.Text = string.format("%s%s — %s", def.name, isOwned and "" or " (locked)", def.desc)
			rowUI.equipBtn:SetAttribute("artifactId", def.id)
			if not isOwned then
				rowUI.equipBtn.Text = "LOCKED"
				rowUI.equipBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
			elseif isEquipped then
				rowUI.equipBtn.Text = "EQUIPPED"
				rowUI.equipBtn.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
			else
				rowUI.equipBtn.Text = "EQUIP"
				rowUI.equipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
			end
		else
			rowUI.row.Visible = false
		end
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- cbs: { onClaimQuest(scope, questId), onClaimStreak(), onEquipTitle(title),
--        onEquipArtifact(artifactId), onPrestige() }
function QuestUI:Init(gui, monetizationConf, cbs)
	MonetizationConfig = monetizationConf
	callbacks = cbs or {}

	local root = Instance.new("Frame")
	root.Name = "QuestPanel"
	root.Size = UDim2.new(0, 620, 0, 480)
	root.Position = UDim2.new(0.5, -310, 0.5, -240)
	root.BackgroundColor3 = Color3.fromRGB(8, 12, 8)
	root.BackgroundTransparency = 0.05
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.ZIndex = 20
	root.Visible = false
	root.Parent = gui
	corner(root, 12)
	stroke(root, Color3.fromRGB(40, 60, 40), 1)
	panel.root = root

	buildTopBar(gui)
	buildQuestTab(gui, "daily")
	buildQuestTab(gui, "weekly")
	buildStreakTab(gui)
	buildProgressTab(gui)

	self:ShowTab("daily")
end

function QuestUI:ShowTab(tabId)
	for id, frame in pairs(tabFrames) do
		frame.Visible = (id == tabId)
	end
	for id, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (id == tabId) and Color3.fromRGB(50, 80, 50) or Color3.fromRGB(24, 30, 24)
	end
end

local function refreshScope(scope, bucket, pool)
	local poolById = {}
	for _, q in ipairs(pool) do poolById[q.id] = q end

	for i = 1, 3 do
		local rowUI = questRows[scope .. "_" .. i]
		local questId = bucket.active and bucket.active[i]
		if not rowUI then continue end

		if not questId then
			rowUI.row.Visible = false
			continue
		end
		rowUI.row.Visible = true

		local qdef = poolById[questId]
		if not qdef then continue end

		local progress = (bucket.progress and bucket.progress[questId]) or 0
		local claimed = bucket.claimed and bucket.claimed[questId]
		local complete = progress >= qdef.target

		rowUI.descLbl.Text = qdef.desc
		rowUI.rewardLbl.Text = rewardText(qdef.reward)
		rowUI.bar.Size = UDim2.new(math.clamp(progress / qdef.target, 0, 1), 0, 1, 0)
		rowUI.btn:SetAttribute("questId", questId)

		if claimed then
			rowUI.btn.Text = "CLAIMED"
			rowUI.btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		elseif complete then
			rowUI.btn.Text = "CLAIM"
			rowUI.btn.BackgroundColor3 = Color3.fromRGB(50, 150, 70)
		else
			rowUI.btn.Text = progress .. "/" .. qdef.target
			rowUI.btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
		end
	end
end

-- Pushes a QuestService:GetState() payload into the panel.
function QuestUI:Refresh(newState)
	state = newState or state
	refreshScope("daily", state.daily or {}, state.dailyPool or {})
	refreshScope("weekly", state.weekly or {}, state.weeklyPool or {})

	local streak = state.loginStreak or {}
	local dayInCycle = ((math.max(streak.streak or 0, 1) - 1) % 7) + 1
	for day, cellUI in pairs(streakCells) do
		local def = state.streakCalendar and state.streakCalendar[day]
		cellUI.rewardLbl.Text = def and rewardText(def.reward) or ""
		if day < dayInCycle or (day == dayInCycle and streak.claimedToday) then
			cellUI.stroke.Color = Color3.fromRGB(60, 60, 60)
			cellUI.claimBtn.Text = "DONE"
			cellUI.claimBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		elseif day == dayInCycle then
			cellUI.stroke.Color = Color3.fromRGB(255, 210, 90)
			cellUI.claimBtn.Text = "CLAIM"
			cellUI.claimBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 70)
		else
			cellUI.stroke.Color = Color3.fromRGB(50, 60, 50)
			cellUI.claimBtn.Text = "LOCKED"
			cellUI.claimBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		end
	end

	if state.battlePass then
		local maxTier = MonetizationConfig and MonetizationConfig.BattlePass.maxTier or 30
		panel.passLbl.Text = ("Battle Pass Tier %d/%d"):format(state.battlePass.tier or 0, maxTier)
	end
end

function QuestUI:Show()
	panel.root.Visible = true
end

function QuestUI:Hide()
	panel.root.Visible = false
end

function QuestUI:GetPanel()
	return panel.root
end

return QuestUI
