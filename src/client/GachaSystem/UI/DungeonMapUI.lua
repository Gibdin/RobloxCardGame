-- DungeonMapUI — scrolling node-graph panel for dungeon runs. Row 1 (mobs)
-- starts at the bottom, the boss sits at the top; edges are thin rotated
-- frames computed from each node's rendered position.

local TweenService = game:GetService("TweenService")

local DungeonMapUI = {}

local panel, scrollFrame, goldLabel, abandonBtn, closeBtn
local nodeButtons = {}
local onNodeClick, onAbandon

local ROW_HEIGHT = 74
local NODE_SIZE = 50
local PANEL_W = 380

local TYPE_ICON = { Mob = "S", Elite = "E", Shop = "$", Rest = "R", Boss = "B" }
local TYPE_COLOR = {
	Mob   = Color3.fromRGB(150, 60, 60),
	Elite = Color3.fromRGB(160, 60, 160),
	Shop  = Color3.fromRGB(60, 140, 160),
	Rest  = Color3.fromRGB(60, 160, 90),
	Boss  = Color3.fromRGB(220, 180, 40),
}

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

function DungeonMapUI:Init(gui, cbs)
	onNodeClick = cbs and cbs.onNodeClick
	onAbandon = cbs and cbs.onAbandon

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
end

-- run: { map = {rows, maxRow}, position, gold, ... } from Dungeon_GetState/ChooseNode.
function DungeonMapUI:Render(run)
	for _, b in pairs(nodeButtons) do b:Destroy() end
	nodeButtons = {}
	for _, c in ipairs(scrollFrame:GetChildren()) do
		if c.Name == "Edge" then c:Destroy() end
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
	local nodesById = {}
	for r = 1, maxRow do
		local rowNodes = rows[r]
		local count = #rowNodes
		for i, node in ipairs(rowNodes) do
			local x = (i - 0.5) / count * PANEL_W
			local y = (maxRow - r) * ROW_HEIGHT + 30
			positions[node.id] = Vector2.new(x, y)
			nodesById[node.id] = node
		end
	end

	for r = 1, maxRow - 1 do
		for _, node in ipairs(rows[r]) do
			for _, targetId in ipairs(node.edges) do
				local p1, p2 = positions[node.id], positions[targetId]
				if p1 and p2 then
					local delta = p2 - p1
					local length = delta.Magnitude
					local target = nodesById[targetId]
					local traveled = node.visited and target and target.visited
					local edge = Instance.new("Frame")
					edge.Name = "Edge"
					edge.Size = UDim2.new(0, length, 0, 2)
					edge.Position = UDim2.new(0, p1.X, 0, p1.Y)
					edge.AnchorPoint = Vector2.new(0, 0.5)
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

			if node.visited then
				btn.BackgroundTransparency = 0.55
				btn.AutoButtonColor = false
			elseif reachable[node.id] then
				btn.BackgroundTransparency = 0
				btn.AutoButtonColor = true
				btn.MouseButton1Click:Connect(function()
					if onNodeClick then onNodeClick(node.id) end
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
	panel.Visible = false
end

function DungeonMapUI:GetPanel()
	return panel
end

return DungeonMapUI
