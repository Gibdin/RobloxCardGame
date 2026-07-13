-- ArenaUI — async PvP opponent list. Pure view: attacking and battle playback
-- are orchestrated by the controller (PackOpeningController.client.lua),
-- which already owns BattleController/BattleUI — the same pattern DungeonController
-- uses for Dungeon/Tower fights, just without needing DungeonController
-- involved at all since PvP isn't a "run."

local ArenaUI = {}

local panel = {}
local opponentRows = {}
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

local HEADER_HEIGHT = 60

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

	label(tb, "Attack a snapshot of another player's saved team. Only your rating changes.",
		UDim2.new(1, -32, 0, 18), UDim2.new(0, 16, 0, 38), Color3.fromRGB(160, 140, 140), Enum.Font.Gotham).TextSize = 12
end

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

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -32, 1, -HEADER_HEIGHT - 8); scroll.Position = UDim2.new(0, 16, 0, HEADER_HEIGHT)
	scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 20 * 52)
	scroll.ZIndex = 21; scroll.Parent = root
	panel.scroll = scroll

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
