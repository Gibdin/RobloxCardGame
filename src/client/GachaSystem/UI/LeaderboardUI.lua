-- LeaderboardUI — top-20 + "your score" for each OrderedDataStore-backed
-- board (Tower best floor, Dungeon deepest row; Phase 5 will add PvP rating
-- here the same way). Pure view: Refresh(board, data) pushes fresh
-- LeaderboardService results in; RequestBoard(board) is fired via callback
-- whenever a tab is selected so the controller can fetch fresh data.

local LeaderboardUI = {}

local panel, tabButtons = {}, {}
local tabFrames = {}
local rowLabels = {}   -- [board] = { {rankLbl, nameLbl, scoreLbl}, ... }
local myScoreLabels = {}

local callbacks = {}
local activeBoard = "TowerBestFloor"

local BOARDS = {
	{ id = "TowerBestFloor",    label = "TOWER",   unit = "Floor" },
	{ id = "DungeonDeepestRow", label = "DUNGEON", unit = "Row" },
}

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

local HEADER_HEIGHT = 66

local function buildTopBar(gui)
	local tb = Instance.new("Frame")
	tb.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	tb.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
	tb.BorderSizePixel = 0
	tb.ZIndex = 21; tb.Parent = panel.root

	label(tb, "RANKINGS", UDim2.new(0, 160, 0, 28), UDim2.new(0, 16, 0, 8),
		Color3.fromRGB(255, 210, 90), Enum.Font.GothamBlack)

	local closeBtn = button(tb, "X", UDim2.new(0, 28, 0, 28), UDim2.new(1, -22, 0, 8), Color3.fromRGB(80, 30, 30))
	closeBtn.MouseButton1Click:Connect(function() LeaderboardUI:Hide() end)

	local TAB_W, TAB_GAP = 110, 6
	for i, b in ipairs(BOARDS) do
		local btn = button(tb, b.label, UDim2.new(0, TAB_W, 0, 26), UDim2.new(0, 8 + (i - 1) * (TAB_W + TAB_GAP), 0, 36),
			Color3.fromRGB(28, 24, 36))
		btn.TextSize = 12
		tabButtons[b.id] = btn
		btn.MouseButton1Click:Connect(function() LeaderboardUI:ShowBoard(b.id) end)
	end
end

local function buildBoardTab(gui, boardDef)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames[boardDef.id] = f

	local myRow = Instance.new("Frame")
	myRow.Size = UDim2.new(1, -32, 0, 30); myRow.Position = UDim2.new(0, 16, 0, 4)
	myRow.BackgroundColor3 = Color3.fromRGB(30, 26, 40); myRow.BorderSizePixel = 0
	myRow.ZIndex = 22; myRow.Parent = f
	corner(myRow, 6)
	local myLbl = label(myRow, "Your Best: —", UDim2.new(1, -16, 1, 0), UDim2.new(0, 8, 0, 0),
		Color3.fromRGB(255, 210, 90), Enum.Font.GothamBold)
	myLbl.TextXAlignment = Enum.TextXAlignment.Left
	myScoreLabels[boardDef.id] = myLbl

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -32, 1, -44); scroll.Position = UDim2.new(0, 16, 0, 40)
	scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 20 * 30)
	scroll.ZIndex = 22; scroll.Parent = f

	local rows = {}
	for i = 1, 20 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 28); row.Position = UDim2.new(0, 0, 0, (i - 1) * 30)
		row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(18, 16, 26) or Color3.fromRGB(22, 20, 30)
		row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = scroll
		corner(row, 4)

		local rankLbl = label(row, "#" .. i, UDim2.new(0, 44, 1, 0), UDim2.new(0, 8, 0, 0), Color3.fromRGB(150, 150, 180), Enum.Font.GothamBold)
		local nameLbl = label(row, "—", UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 56, 0, 0), Color3.fromRGB(220, 220, 240), Enum.Font.Gotham)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		local scoreLbl = label(row, "—", UDim2.new(0, 100, 1, 0), UDim2.new(1, -108, 0, 0), Color3.fromRGB(255, 210, 90), Enum.Font.GothamBold)
		scoreLbl.TextXAlignment = Enum.TextXAlignment.Right

		table.insert(rows, { row = row, rankLbl = rankLbl, nameLbl = nameLbl, scoreLbl = scoreLbl })
	end
	rowLabels[boardDef.id] = rows
end

-- cbs: { onRequestBoard(boardId) }
function LeaderboardUI:Init(gui, cbs)
	callbacks = cbs or {}

	local root = Instance.new("Frame")
	root.Name = "LeaderboardPanel"
	root.Size = UDim2.new(0, 480, 0, 500)
	root.Position = UDim2.new(0.5, -240, 0.5, -250)
	root.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
	root.BackgroundTransparency = 0.05
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.ZIndex = 20
	root.Visible = false
	root.Parent = gui
	corner(root, 12)
	stroke(root, Color3.fromRGB(50, 44, 60), 1)
	panel.root = root

	buildTopBar(gui)
	for _, b in ipairs(BOARDS) do
		buildBoardTab(gui, b)
	end

	self:ShowBoard("TowerBestFloor")
end

function LeaderboardUI:ShowBoard(boardId)
	activeBoard = boardId
	for id, frame in pairs(tabFrames) do
		frame.Visible = (id == boardId)
	end
	for id, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (id == boardId) and Color3.fromRGB(60, 50, 80) or Color3.fromRGB(28, 24, 36)
	end
	if callbacks.onRequestBoard then callbacks.onRequestBoard(boardId) end
end

-- data: { top = { {userId, name, score}, ... }, mine = number|nil }
function LeaderboardUI:Refresh(boardId, data)
	local rows = rowLabels[boardId]
	if not rows then return end

	for i, rowUI in ipairs(rows) do
		local entry = data.top and data.top[i]
		if entry then
			rowUI.nameLbl.Text = entry.name
			rowUI.scoreLbl.Text = tostring(entry.score)
		else
			rowUI.nameLbl.Text = "—"
			rowUI.scoreLbl.Text = "—"
		end
	end

	local boardDef
	for _, b in ipairs(BOARDS) do if b.id == boardId then boardDef = b end end
	local myLbl = myScoreLabels[boardId]
	if myLbl then
		myLbl.Text = data.mine and ("Your Best: " .. data.mine .. " (" .. (boardDef and boardDef.unit or "") .. ")") or "Your Best: —"
	end
end

function LeaderboardUI:GetActiveBoard()
	return activeBoard
end

function LeaderboardUI:Show()
	panel.root.Visible = true
end

function LeaderboardUI:Hide()
	panel.root.Visible = false
end

function LeaderboardUI:GetPanel()
	return panel.root
end

return LeaderboardUI
