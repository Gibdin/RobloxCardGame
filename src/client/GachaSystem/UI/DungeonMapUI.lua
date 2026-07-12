-- DungeonMapUI — scrolling node-graph panel for dungeon runs. Row 1 (mobs)
-- starts at the bottom, the boss sits at the top; edges are thin rotated
-- frames computed from each node's rendered position.
--
-- Interaction model: first click on a reachable node selects it and shows a
-- preview tooltip (danger stars, enemy info, reward hint, FIGHT/GO button);
-- a second click on the same node or the tooltip button commits via
-- onNodeClick. Clicking a different node moves the selection.

local TweenService = game:GetService("TweenService")

local DungeonMapUI = {}

local panel, scrollFrame, goldLabel, abandonBtn, closeBtn
local tooltip, ttTitle, ttStars, ttInfo, ttReward, ttButton, ttCards
local nodeButtons = {}
local nodesByIdCache = {}
local selectedNodeId
local onNodeClick, onAbandon
local Sound = { Play = function() end }

local ROW_HEIGHT = 74
local NODE_SIZE = 50
local PANEL_W = 380

local TYPE_ICON = { Mob = "S", Elite = "E", Shop = "$", Rest = "R", Boss = "B" }
local TYPE_NAME = { Mob = "Battle", Elite = "ELITE", Shop = "Shop", Rest = "Rest", Boss = "BOSS" }
local TYPE_COLOR = {
	Mob   = Color3.fromRGB(150, 60, 60),
	Elite = Color3.fromRGB(160, 60, 160),
	Shop  = Color3.fromRGB(60, 140, 160),
	Rest  = Color3.fromRGB(60, 160, 90),
	Boss  = Color3.fromRGB(220, 180, 40),
}

local RewardHint  -- from DungeonConfig.Preview
local CardDatabase, RarityConfig  -- for resolving preview.cards into name/rarity chips

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function hideTooltip()
	selectedNodeId = nil
	if tooltip then tooltip.Visible = false end
	for _, b in pairs(nodeButtons) do
		local sel = b:FindFirstChild("SelStroke")
		if sel then sel.Enabled = false end
	end
end

local function commitNode(nodeId)
	Sound:Play("node_commit")
	hideTooltip()
	if onNodeClick then onNodeClick(nodeId) end
end

local function showTooltip(node, nodePos)
	selectedNodeId = node.id
	Sound:Play("node_select")

	for id, b in pairs(nodeButtons) do
		local sel = b:FindFirstChild("SelStroke")
		if sel then sel.Enabled = (id == node.id) end
	end

	local isBattle = node.type == "Mob" or node.type == "Elite" or node.type == "Boss"
	local risky = node.type == "Elite" or node.type == "Boss"

	ttTitle.Text = TYPE_NAME[node.type] or node.type
	ttTitle.TextColor3 = TYPE_COLOR[node.type] or Color3.fromRGB(220, 220, 240)

	if isBattle and node.preview then
		local p = node.preview
		ttStars.Text = string.rep("★", p.danger or 1) .. string.rep("☆", 5 - (p.danger or 1))
		ttStars.TextColor3 = (p.danger or 1) >= 4 and Color3.fromRGB(235, 90, 80)
			or ((p.danger or 1) >= 3 and Color3.fromRGB(235, 180, 80) or Color3.fromRGB(130, 220, 130))
		ttStars.Visible = true
		ttInfo.Text = p.enemyCount .. " enemies · up to " .. p.rarityBand
		ttInfo.Visible = true
	else
		ttStars.Visible = false
		ttInfo.Visible = false
	end

	-- Enemy-card reveal: server bakes preview.cards for Elite/Boss only.
	for _, child in ipairs(ttCards:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	local cardRowsHeight = 0
	if isBattle and node.preview and node.preview.cards and CardDatabase then
		for i, cardId in ipairs(node.preview.cards) do
			local card = CardDatabase:GetById(cardId)
			if card then
				local line = Instance.new("TextLabel")
				line.Size = UDim2.new(1, 0, 0, 13)
				line.BackgroundTransparency = 1
				line.Text = "• " .. card.name
				local rarity = RarityConfig and RarityConfig.Rarities and RarityConfig.Rarities[card.rarity]
				line.TextColor3 = rarity and rarity.color or Color3.fromRGB(190, 190, 215)
				line.TextScaled = true; line.Font = Enum.Font.GothamMedium
				line.TextXAlignment = Enum.TextXAlignment.Left
				line.LayoutOrder = i
				line.ZIndex = 31; line.Parent = ttCards
				cardRowsHeight = cardRowsHeight + 14
			end
		end
	end
	ttCards.Visible = cardRowsHeight > 0
	ttCards.Size = UDim2.new(1, -12, 0, cardRowsHeight)

	ttReward.Text = RewardHint and RewardHint(node.type, node.row) or ""
	ttButton.Text = risky and "RISK IT" or (isBattle and "FIGHT" or "GO")
	ttButton.BackgroundColor3 = risky and Color3.fromRGB(190, 55, 55) or Color3.fromRGB(70, 150, 90)

	-- Position beside the node, clamped inside the scroll canvas.
	-- Base height 118; grows to fit revealed enemy cards (button is bottom-anchored).
	local tipW, tipH = 170, 118 + (cardRowsHeight > 0 and cardRowsHeight + 4 or 0)
	tooltip.Size = UDim2.new(0, tipW, 0, tipH)
	local x = math.clamp(nodePos.X + NODE_SIZE / 2 + 8, 0, PANEL_W - tipW)
	local y = math.max(0, nodePos.Y - tipH / 2)
	tooltip.Position = UDim2.new(0, x, 0, y)
	tooltip.Visible = true
end

function DungeonMapUI:Init(gui, cbs, soundManager)
	onNodeClick = cbs and cbs.onNodeClick
	onAbandon = cbs and cbs.onAbandon
	if soundManager then Sound = soundManager end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ok, conf = pcall(function()
		return require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("DungeonConfig"))
	end)
	if ok and conf.Preview then RewardHint = conf.Preview.RewardHint end
	pcall(function()
		local folder = ReplicatedStorage:WaitForChild("GachaSystem")
		CardDatabase = require(folder:WaitForChild("CardDatabase"))
		RarityConfig = require(folder:WaitForChild("RarityConfig"))
	end)

	panel = Instance.new("Frame")
	panel.Name = "DungeonMapPanel"
	panel.Size = UDim2.new(0, 440, 0, 560)
	panel.Position = UDim2.new(0.5, -220, 0.5, -280)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.ZIndex = 25
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(200, 120, 60); stroke.Thickness = 1; stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.5, 0, 0, 32); title.Position = UDim2.new(0, 16, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "DUNGEON"
	title.TextColor3 = Color3.fromRGB(220, 220, 245)
	title.TextScaled = true; title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 26; title.Parent = panel

	goldLabel = Instance.new("TextLabel")
	goldLabel.Size = UDim2.new(0.3, 0, 0, 28); goldLabel.Position = UDim2.new(0.5, 0, 0, 10)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	goldLabel.TextScaled = true; goldLabel.Font = Enum.Font.GothamBold
	goldLabel.TextXAlignment = Enum.TextXAlignment.Right
	goldLabel.ZIndex = 26; goldLabel.Parent = panel

	closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 30, 0, 30); closeBtn.Position = UDim2.new(1, -40, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextScaled = true; closeBtn.Font = Enum.Font.GothamBold
	closeBtn.ZIndex = 26; closeBtn.Parent = panel
	corner(closeBtn, 6)
	closeBtn.MouseButton1Click:Connect(function() self:Hide() end)

	scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -20, 1, -92)
	scrollFrame.Position = UDim2.new(0, 10, 0, 46)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ZIndex = 25
	scrollFrame.Parent = panel

	abandonBtn = Instance.new("TextButton")
	abandonBtn.Size = UDim2.new(1, -32, 0, 34); abandonBtn.Position = UDim2.new(0, 16, 1, -42)
	abandonBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	abandonBtn.BorderSizePixel = 0
	abandonBtn.Text = "ABANDON RUN"
	abandonBtn.TextColor3 = Color3.fromRGB(200, 150, 150)
	abandonBtn.TextScaled = true; abandonBtn.Font = Enum.Font.GothamBold
	abandonBtn.ZIndex = 26; abandonBtn.Parent = panel
	corner(abandonBtn, 8)
	abandonBtn.MouseButton1Click:Connect(function()
		if onAbandon then onAbandon() end
	end)

	-- Preview tooltip (parented to the scroll canvas so it tracks its node).
	tooltip = Instance.new("Frame")
	tooltip.Name = "NodeTooltip"
	tooltip.Size = UDim2.new(0, 170, 0, 118)
	tooltip.BackgroundColor3 = Color3.fromRGB(20, 20, 34)
	tooltip.BorderSizePixel = 0
	tooltip.ZIndex = 30
	tooltip.Visible = false
	tooltip.Parent = scrollFrame
	corner(tooltip, 8)
	local ttStroke = Instance.new("UIStroke"); ttStroke.Color = Color3.fromRGB(90, 90, 130); ttStroke.Thickness = 1; ttStroke.Parent = tooltip

	ttTitle = Instance.new("TextLabel")
	ttTitle.Size = UDim2.new(1, -12, 0, 22); ttTitle.Position = UDim2.new(0, 6, 0, 4)
	ttTitle.BackgroundTransparency = 1
	ttTitle.TextScaled = true; ttTitle.Font = Enum.Font.GothamBlack
	ttTitle.TextXAlignment = Enum.TextXAlignment.Left
	ttTitle.ZIndex = 31; ttTitle.Parent = tooltip

	ttStars = Instance.new("TextLabel")
	ttStars.Size = UDim2.new(1, -12, 0, 18); ttStars.Position = UDim2.new(0, 6, 0, 26)
	ttStars.BackgroundTransparency = 1
	ttStars.TextScaled = true; ttStars.Font = Enum.Font.GothamBold
	ttStars.TextXAlignment = Enum.TextXAlignment.Left
	ttStars.ZIndex = 31; ttStars.Parent = tooltip

	ttInfo = Instance.new("TextLabel")
	ttInfo.Size = UDim2.new(1, -12, 0, 16); ttInfo.Position = UDim2.new(0, 6, 0, 45)
	ttInfo.BackgroundTransparency = 1
	ttInfo.TextColor3 = Color3.fromRGB(190, 190, 215)
	ttInfo.TextScaled = true; ttInfo.Font = Enum.Font.Gotham
	ttInfo.TextXAlignment = Enum.TextXAlignment.Left
	ttInfo.ZIndex = 31; ttInfo.Parent = tooltip

	ttReward = Instance.new("TextLabel")
	ttReward.Size = UDim2.new(1, -12, 0, 16); ttReward.Position = UDim2.new(0, 6, 0, 62)
	ttReward.BackgroundTransparency = 1
	ttReward.TextColor3 = Color3.fromRGB(255, 210, 90)
	ttReward.TextScaled = true; ttReward.Font = Enum.Font.Gotham
	ttReward.TextXAlignment = Enum.TextXAlignment.Left
	ttReward.ZIndex = 31; ttReward.Parent = tooltip

	-- Enemy-card reveal rows (Elite/Boss only — populated from node.preview.cards).
	ttCards = Instance.new("Frame")
	ttCards.Size = UDim2.new(1, -12, 0, 0); ttCards.Position = UDim2.new(0, 6, 0, 80)
	ttCards.BackgroundTransparency = 1
	ttCards.Visible = false
	ttCards.ZIndex = 31; ttCards.Parent = tooltip
	local cardsLayout = Instance.new("UIListLayout")
	cardsLayout.FillDirection = Enum.FillDirection.Vertical
	cardsLayout.Padding = UDim.new(0, 1)
	cardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardsLayout.Parent = ttCards

	ttButton = Instance.new("TextButton")
	ttButton.Size = UDim2.new(1, -12, 0, 28); ttButton.Position = UDim2.new(0, 6, 1, -34)
	ttButton.BorderSizePixel = 0
	ttButton.TextColor3 = Color3.new(1, 1, 1)
	ttButton.TextScaled = true; ttButton.Font = Enum.Font.GothamBlack
	ttButton.ZIndex = 31; ttButton.Parent = tooltip
	corner(ttButton, 6)
	ttButton.MouseButton1Click:Connect(function()
		if selectedNodeId then commitNode(selectedNodeId) end
	end)
end

-- run: { map = {rows, maxRow}, position, gold, ... } from Dungeon_GetState/ChooseNode.
function DungeonMapUI:Render(run)
	for _, b in pairs(nodeButtons) do b:Destroy() end
	nodeButtons = {}
	nodesByIdCache = {}
	hideTooltip()
	for _, c in ipairs(scrollFrame:GetChildren()) do
		if c.Name == "Edge" or c.Name == "Stars" then c:Destroy() end
	end

	local rows = run.map.rows
	local maxRow = run.map.maxRow

	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, maxRow * ROW_HEIGHT + 60)

	local reachable = {}
	if run.position == false then
		for _, n in ipairs(rows[1]) do reachable[n.id] = true end
	else
		for r = 1, maxRow do
			for _, n in ipairs(rows[r]) do
				if n.id == run.position then
					for _, e in ipairs(n.edges) do reachable[e] = true end
				end
			end
		end
	end

	local positions = {}
	for r = 1, maxRow do
		local rowNodes = rows[r]
		local count = #rowNodes
		for i, node in ipairs(rowNodes) do
			local x = (i - 0.5) / count * PANEL_W
			local y = (maxRow - r) * ROW_HEIGHT + 30
			positions[node.id] = Vector2.new(x, y)
			nodesByIdCache[node.id] = node
		end
	end

	for r = 1, maxRow - 1 do
		for _, node in ipairs(rows[r]) do
			for _, targetId in ipairs(node.edges) do
				local p1, p2 = positions[node.id], positions[targetId]
				if p1 and p2 then
					local delta = p2 - p1
					-- Trim a node-radius off each end so the line runs edge-to-edge
					-- instead of poking through the circles.
					local length = math.max(0, delta.Magnitude - NODE_SIZE)
					local mid = (p1 + p2) / 2
					local target = nodesByIdCache[targetId]
					local traveled = node.visited and target and target.visited
					local edge = Instance.new("Frame")
					edge.Name = "Edge"
					edge.Size = UDim2.new(0, length, 0, 2)
					-- Roblox rotates frames about their center, so the frame's
					-- center must sit on the segment midpoint for the line to
					-- actually connect the two nodes.
					edge.Position = UDim2.new(0, mid.X, 0, mid.Y)
					edge.AnchorPoint = Vector2.new(0.5, 0.5)
					edge.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					edge.BackgroundColor3 = traveled and Color3.fromRGB(200, 120, 60) or Color3.fromRGB(50, 50, 74)
					edge.BorderSizePixel = 0
					edge.ZIndex = 26
					edge.Parent = scrollFrame
				end
			end
		end
	end

	for r = 1, maxRow do
		for _, node in ipairs(rows[r]) do
			local pos = positions[node.id]
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, NODE_SIZE, 0, NODE_SIZE)
			btn.Position = UDim2.new(0, pos.X - NODE_SIZE / 2, 0, pos.Y - NODE_SIZE / 2)
			btn.BackgroundColor3 = TYPE_COLOR[node.type] or Color3.fromRGB(100, 100, 100)
			btn.Text = TYPE_ICON[node.type] or "?"
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.TextScaled = true
			btn.Font = Enum.Font.GothamBlack
			btn.ZIndex = 27
			btn.Parent = scrollFrame
			corner(btn, NODE_SIZE / 2)

			-- Selection highlight ring (toggled by showTooltip).
			local sel = Instance.new("UIStroke")
			sel.Name = "SelStroke"
			sel.Color = Color3.fromRGB(255, 255, 160)
			sel.Thickness = 3
			sel.Enabled = false
			sel.Parent = btn

			-- Permanent danger stars under elite/boss nodes.
			if (node.type == "Elite" or node.type == "Boss") and node.preview then
				local stars = Instance.new("TextLabel")
				stars.Name = "Stars"
				stars.Size = UDim2.new(0, NODE_SIZE + 20, 0, 12)
				stars.Position = UDim2.new(0, pos.X - NODE_SIZE / 2 - 10, 0, pos.Y + NODE_SIZE / 2 + 1)
				stars.BackgroundTransparency = 1
				stars.Text = string.rep("★", node.preview.danger or 1)
				stars.TextColor3 = Color3.fromRGB(235, 150, 80)
				stars.TextSize = 11
				stars.Font = Enum.Font.GothamBold
				stars.ZIndex = 27
				stars.Parent = scrollFrame
			end

			if node.visited then
				btn.BackgroundTransparency = 0.55
				btn.AutoButtonColor = false
			elseif reachable[node.id] then
				btn.BackgroundTransparency = 0
				btn.AutoButtonColor = true
				btn.MouseButton1Click:Connect(function()
					if selectedNodeId == node.id then
						commitNode(node.id)
					else
						showTooltip(node, pos)
					end
				end)
			else
				btn.BackgroundTransparency = 0.8
				btn.AutoButtonColor = false
			end

			if node.id == run.position then
				local hi = Instance.new("UIStroke")
				hi.Color = Color3.fromRGB(255, 255, 255)
				hi.Thickness = 3
				hi.Parent = btn
			end

			nodeButtons[node.id] = btn
		end
	end

	goldLabel.Text = run.gold .. "g"

	-- Scroll to the player's current row (or the bottom, at run start).
	local scrollY = run.position and positions[run.position] and positions[run.position].Y or (maxRow * ROW_HEIGHT)
	scrollFrame.CanvasPosition = Vector2.new(0, math.max(0, scrollY - scrollFrame.AbsoluteSize.Y / 2))
end

function DungeonMapUI:Show()
	panel.Visible = true
end

function DungeonMapUI:Hide()
	hideTooltip()
	panel.Visible = false
end

function DungeonMapUI:GetPanel()
	return panel
end

return DungeonMapUI
