-- EliteBuffUI — pick 1 of 3 offered run-buffs and a target card.
-- Shared by tower (every 5th floor) and dungeon (elite wins). Blocks the parent
-- flow until a pick is confirmed.

local EliteBuffUI = {}

local panel, confirmBtn
local buffButtons, cardButtons = {}, {}
local selectedBuff, selectedCard
local onConfirm
local DungeonConfig, CardDatabase

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function refreshSelection()
	for i, b in ipairs(buffButtons) do
		b.stroke.Color = (i == selectedBuff) and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(50, 50, 80)
		b.stroke.Thickness = (i == selectedBuff) and 3 or 1
	end
	for id, b in pairs(cardButtons) do
		b.stroke.Color = (id == selectedCard) and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(50, 50, 80)
		b.stroke.Thickness = (id == selectedCard) and 3 or 1
	end
	local ready = selectedBuff and selectedCard
	confirmBtn.BackgroundColor3 = ready and Color3.fromRGB(70, 170, 90) or Color3.fromRGB(40, 40, 60)
	confirmBtn.TextColor3 = ready and Color3.new(1, 1, 1) or Color3.fromRGB(130, 130, 150)
end

function EliteBuffUI:Init(gui, dungeonConfig, cardDb)
	DungeonConfig = dungeonConfig
	CardDatabase = cardDb

	panel = Instance.new("Frame")
	panel.Name = "EliteBuffPanel"
	panel.Size = UDim2.new(0, 460, 0, 360)
	panel.Position = UDim2.new(0.5, -230, 0.5, -180)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.ZIndex = 50
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(255, 210, 90); stroke.Thickness = 2; stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -32, 0, 30); title.Position = UDim2.new(0, 16, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "CHOOSE A BLESSING"
	title.TextColor3 = Color3.fromRGB(255, 220, 130)
	title.TextScaled = true; title.Font = Enum.Font.GothamBlack
	title.ZIndex = 51; title.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -32, 0, 18); hint.Position = UDim2.new(0, 16, 0, 42)
	hint.BackgroundTransparency = 1
	hint.Text = "Pick one buff, then the card that receives it (lasts the whole run)"
	hint.TextColor3 = Color3.fromRGB(150, 150, 180)
	hint.TextScaled = true; hint.Font = Enum.Font.Gotham
	hint.ZIndex = 51; hint.Parent = panel

	confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0, 200, 0, 42); confirmBtn.Position = UDim2.new(0.5, -100, 1, -54)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Text = "CONFIRM"
	confirmBtn.TextColor3 = Color3.fromRGB(130, 130, 150)
	confirmBtn.TextScaled = true; confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.ZIndex = 51; confirmBtn.Parent = panel
	corner(confirmBtn, 8)
	confirmBtn.MouseButton1Click:Connect(function()
		if selectedBuff and selectedCard and onConfirm then
			local cb = onConfirm
			onConfirm = nil
			panel.Visible = false
			cb(selectedBuff, selectedCard)
		end
	end)
end

-- choices: array of buff ids; teamIds: array of card ids (holes removed).
-- cb(choiceIndex, targetCardId) fires once on confirm.
function EliteBuffUI:Show(choices, teamIds, cb)
	onConfirm = cb
	selectedBuff, selectedCard = nil, nil

	for _, b in ipairs(buffButtons) do b.btn:Destroy() end
	for _, b in pairs(cardButtons) do b.btn:Destroy() end
	buffButtons, cardButtons = {}, {}

	for i, buffId in ipairs(choices) do
		local def = DungeonConfig.Buffs[buffId]
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.3, 0, 0, 110)
		b.Position = UDim2.new(0.02 + (i - 1) * 0.325, 0, 0, 68)
		b.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
		b.BorderSizePixel = 0
		b.Text = ""
		b.ZIndex = 51
		b.Parent = panel
		corner(b, 10)
		local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(50, 50, 80); st.Thickness = 1; st.Parent = b

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -12, 0, 40); nameLbl.Position = UDim2.new(0, 6, 0, 8)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = def and def.name or buffId
		nameLbl.TextColor3 = Color3.fromRGB(235, 235, 250)
		nameLbl.TextScaled = true; nameLbl.TextWrapped = true
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.ZIndex = 52; nameLbl.Parent = b

		local descLbl = Instance.new("TextLabel")
		descLbl.Size = UDim2.new(1, -12, 0, 50); descLbl.Position = UDim2.new(0, 6, 0, 52)
		descLbl.BackgroundTransparency = 1
		descLbl.Text = def and def.desc or ""
		descLbl.TextColor3 = Color3.fromRGB(170, 170, 200)
		descLbl.TextScaled = true; descLbl.TextWrapped = true
		descLbl.Font = Enum.Font.Gotham
		descLbl.ZIndex = 52; descLbl.Parent = b

		b.MouseButton1Click:Connect(function()
			selectedBuff = i
			refreshSelection()
		end)
		table.insert(buffButtons, { btn = b, stroke = st })
	end

	local n = #teamIds
	for i, cardId in ipairs(teamIds) do
		local card = CardDatabase:GetById(cardId)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 78, 0, 78)
		b.Position = UDim2.new(0.5, math.floor((i - 1 - n / 2) * 86) + 4, 0, 196)
		b.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
		b.BorderSizePixel = 0
		b.Text = card and card.name or ("#" .. cardId)
		b.TextColor3 = Color3.fromRGB(220, 220, 240)
		b.TextScaled = true; b.TextWrapped = true
		b.Font = Enum.Font.GothamBold
		b.ZIndex = 51
		b.Parent = panel
		corner(b, 8)
		local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(50, 50, 80); st.Thickness = 1; st.Parent = b

		b.MouseButton1Click:Connect(function()
			selectedCard = cardId
			refreshSelection()
		end)
		cardButtons[cardId] = { btn = b, stroke = st }
	end

	refreshSelection()
	panel.Visible = true
end

function EliteBuffUI:Hide()
	panel.Visible = false
end

function EliteBuffUI:GetPanel()
	return panel
end

return EliteBuffUI
