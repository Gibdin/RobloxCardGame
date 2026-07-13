-- ArenaUI — PvP hub: async attack list (Phase 5), live duel queue (Phase 6),
-- and spectating recent live duels (Phase 6). Pure view: attacking, queueing,
-- and battle playback are all orchestrated by the controller
-- (PackOpeningController.client.lua), which already owns
-- BattleController/BattleUI — the same pattern DungeonController uses for
-- Dungeon/Tower fights, just without needing DungeonController involved at
-- all since PvP isn't a "run."

local ArenaUI = {}

local panel = {}
local tabButtons, tabFrames = {}, {}
local opponentRows = {}
local spectateRows = {}
local callbacks = {}

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

local HEADER_HEIGHT = 84

local function buildTopBar(gui)
	local tb = Instance.new("Frame")
	tb.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	tb.BackgroundColor3 = Color3.fromRGB(20, 10, 10)
	tb.BorderSizePixel = 0
	tb.ZIndex = 21; tb.Parent = panel.root

	label(tb, "ARENA", UDim2.new(0, 140, 0, 28), UDim2.new(0, 16, 0, 8),
		Color3.fromRGB(255, 120, 120), Enum.Font.GothamBlack)

	local ratingLbl = label(tb, "Rating: 1000", UDim2.new(0, 200, 0, 24), UDim2.new(1, -216, 0, 10),
		Color3.fromRGB(255, 210, 90), Enum.Font.GothamBold)
	ratingLbl.TextXAlignment = Enum.TextXAlignment.Right
	panel.ratingLbl = ratingLbl

	local closeBtn = button(tb, "X", UDim2.new(0, 28, 0, 28), UDim2.new(1, -22, 0, 8), Color3.fromRGB(80, 30, 30))
	closeBtn.MouseButton1Click:Connect(function() ArenaUI:Hide() end)

	local tabNames = { { id = "async", label = "ASYNC" }, { id = "duel", label = "LIVE DUEL" }, { id = "spectate", label = "SPECTATE" } }
	local TAB_W, TAB_GAP = 130, 6
	for i, t in ipairs(tabNames) do
		local b = button(tb, t.label, UDim2.new(0, TAB_W, 0, 26), UDim2.new(0, 8 + (i - 1) * (TAB_W + TAB_GAP), 0, 46),
			Color3.fromRGB(30, 18, 18))
		b.TextSize = 12
		tabButtons[t.id] = b
		b.MouseButton1Click:Connect(function() ArenaUI:ShowTab(t.id) end)
	end
end

-- ── ASYNC tab (Phase 5, unchanged) ────────────────────────────────────────────

local function buildAsyncTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.async = f

	label(f, "Attack a snapshot of another player's saved team. Only your rating changes.",
		UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 2), Color3.fromRGB(160, 140, 140), Enum.Font.Gotham).TextSize = 12

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -28); scroll.Position = UDim2.new(0, 8, 0, 24)
	scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 20 * 52)
	scroll.ZIndex = 21; scroll.Parent = f

	for i = 1, 20 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 46); row.Position = UDim2.new(0, 0, 0, (i - 1) * 52)
		row.BackgroundColor3 = Color3.fromRGB(24, 18, 18); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = scroll
		row.Visible = false
		corner(row, 6)

		local nameLbl = label(row, "—", UDim2.new(0.45, 0, 1, 0), UDim2.new(0, 10, 0, 0),
			Color3.fromRGB(220, 220, 240), Enum.Font.GothamBold)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left

		local ratingLbl = label(row, "—", UDim2.new(0.25, 0, 1, 0), UDim2.new(0.45, 0, 0, 0),
			Color3.fromRGB(255, 210, 90), Enum.Font.Gotham)

		local attackBtn = button(row, "ATTACK", UDim2.new(0, 100, 0, 34), UDim2.new(1, -110, 0.5, -17),
			Color3.fromRGB(160, 50, 50))
		attackBtn.MouseButton1Click:Connect(function()
			local opponentUserId = attackBtn:GetAttribute("opponentUserId")
			if opponentUserId and callbacks.onAttack then callbacks.onAttack(opponentUserId) end
		end)

		opponentRows[i] = { row = row, nameLbl = nameLbl, ratingLbl = ratingLbl, attackBtn = attackBtn }
	end

	local emptyLbl = label(scroll, "No opponents yet — check back once other players have set a team.",
		UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 0, 8), Color3.fromRGB(150, 130, 130), Enum.Font.Gotham)
	emptyLbl.TextWrapped = true
	emptyLbl.Visible = false
	panel.emptyLbl = emptyLbl
end

-- ── LIVE DUEL tab (Phase 6) ───────────────────────────────────────────────────

local function buildDuelTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.duel = f

	label(f, "Queue for a live duel against another online player. Both of you watch the same fight resolve together.",
		UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 0, 4), Color3.fromRGB(160, 140, 140), Enum.Font.Gotham).TextSize = 13

	local statusLbl = label(f, "Not queued.", UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 50),
		Color3.fromRGB(220, 220, 240), Enum.Font.GothamBold)
	panel.duelStatusLbl = statusLbl

	local queueBtn = button(f, "JOIN QUEUE", UDim2.new(0, 200, 0, 48), UDim2.new(0, 8, 0, 90), Color3.fromRGB(160, 50, 50))
	queueBtn.MouseButton1Click:Connect(function()
		if callbacks.onToggleQueue then callbacks.onToggleQueue() end
	end)
	panel.duelQueueBtn = queueBtn
end

-- ── SPECTATE tab (Phase 6) ────────────────────────────────────────────────────

local function buildSpectateTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.spectate = f

	label(f, "Recent live duels — watch a replay of the exact fight both players saw.",
		UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 2), Color3.fromRGB(160, 140, 140), Enum.Font.Gotham).TextSize = 12

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -28); scroll.Position = UDim2.new(0, 8, 0, 24)
	scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 5 * 52)
	scroll.ZIndex = 21; scroll.Parent = f

	for i = 1, 5 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 46); row.Position = UDim2.new(0, 0, 0, (i - 1) * 52)
		row.BackgroundColor3 = Color3.fromRGB(24, 18, 18); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = scroll
		row.Visible = false
		corner(row, 6)

		local matchupLbl = label(row, "—", UDim2.new(0.7, 0, 1, 0), UDim2.new(0, 10, 0, 0),
			Color3.fromRGB(220, 220, 240), Enum.Font.Gotham)
		matchupLbl.TextXAlignment = Enum.TextXAlignment.Left

		local watchBtn = button(row, "WATCH", UDim2.new(0, 90, 0, 34), UDim2.new(1, -100, 0.5, -17),
			Color3.fromRGB(90, 90, 140))
		watchBtn.MouseButton1Click:Connect(function()
			local duelId = watchBtn:GetAttribute("duelId")
			if duelId and callbacks.onWatch then callbacks.onWatch(duelId) end
		end)

		spectateRows[i] = { row = row, matchupLbl = matchupLbl, watchBtn = watchBtn }
	end

	local emptyLbl = label(scroll, "No live duels have happened yet.",
		UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 0, 8), Color3.fromRGB(150, 130, 130), Enum.Font.Gotham)
	emptyLbl.TextWrapped = true
	emptyLbl.Visible = false
	panel.spectateEmptyLbl = emptyLbl
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- cbs: { onAttack(opponentUserId), onToggleQueue(), onWatch(duelId) }
function ArenaUI:Init(gui, cbs)
	callbacks = cbs or {}

	local root = Instance.new("Frame")
	root.Name = "ArenaPanel"
	root.Size = UDim2.new(0, 480, 0, 500)
	root.Position = UDim2.new(0.5, -240, 0.5, -250)
	root.BackgroundColor3 = Color3.fromRGB(14, 10, 10)
	root.BackgroundTransparency = 0.05
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.ZIndex = 20
	root.Visible = false
	root.Parent = gui
	corner(root, 12)
	stroke(root, Color3.fromRGB(60, 40, 40), 1)
	panel.root = root

	buildTopBar(gui)
	buildAsyncTab(gui)
	buildDuelTab(gui)
	buildSpectateTab(gui)

	self:ShowTab("async")
end

function ArenaUI:ShowTab(tabId)
	for id, frame in pairs(tabFrames) do
		frame.Visible = (id == tabId)
	end
	for id, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (id == tabId) and Color3.fromRGB(90, 40, 40) or Color3.fromRGB(30, 18, 18)
	end
end

-- data: { opponents = { {userId, name, score}, ... }, myRating = number }
function ArenaUI:Refresh(data)
	panel.ratingLbl.Text = "Rating: " .. tostring(data.myRating or 0)

	local opponents = data.opponents or {}
	panel.emptyLbl.Visible = #opponents == 0

	for i, rowUI in ipairs(opponentRows) do
		local entry = opponents[i]
		if entry then
			rowUI.row.Visible = true
			rowUI.nameLbl.Text = entry.name
			rowUI.ratingLbl.Text = tostring(entry.score)
			rowUI.attackBtn:SetAttribute("opponentUserId", entry.userId)
		else
			rowUI.row.Visible = false
		end
	end
end

-- status: { queued = bool, waitSeconds = number }
function ArenaUI:RefreshQueueStatus(status)
	if status.queued then
		panel.duelStatusLbl.Text = ("In queue — %ds"):format(status.waitSeconds or 0)
		panel.duelQueueBtn.Text = "LEAVE QUEUE"
		panel.duelQueueBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
	else
		panel.duelStatusLbl.Text = "Not queued."
		panel.duelQueueBtn.Text = "JOIN QUEUE"
		panel.duelQueueBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
	end
end

-- duels: { {id, nameA, nameB, winnerName}, ... }
function ArenaUI:RefreshSpectate(duels)
	duels = duels or {}
	panel.spectateEmptyLbl.Visible = #duels == 0
	for i, rowUI in ipairs(spectateRows) do
		local d = duels[i]
		if d then
			rowUI.row.Visible = true
			rowUI.matchupLbl.Text = d.nameA .. " vs " .. d.nameB .. " — " .. d.winnerName .. " won"
			rowUI.watchBtn:SetAttribute("duelId", d.id)
		else
			rowUI.row.Visible = false
		end
	end
end

function ArenaUI:Show()
	panel.root.Visible = true
end

function ArenaUI:Hide()
	panel.root.Visible = false
end

function ArenaUI:GetPanel()
	return panel.root
end

return ArenaUI
