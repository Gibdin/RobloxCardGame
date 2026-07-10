-- ShopUI — dungeon shop node: buy items for a selected team card, buy heal
-- services, reroll the offer list. Select a target card first; item/service
-- buttons purchase immediately for that target.

local ShopUI = {}

local panel, goldLabel, rerollBtn, leaveBtn
local offerButtons, serviceButtons, cardButtons = {}, {}, {}
local selectedCard
local callbacks, DungeonConfig, CardDatabase

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function refreshCardSelection()
	for id, b in pairs(cardButtons) do
		b.stroke.Color = (id == selectedCard) and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(50, 50, 80)
		b.stroke.Thickness = (id == selectedCard) and 3 or 1
	end
end

function ShopUI:Init(gui, dungeonConfig, cardDb, cbs)
	DungeonConfig = dungeonConfig
	CardDatabase = cardDb
	callbacks = cbs or {}

	panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.Size = UDim2.new(0, 480, 0, 460)
	panel.Position = UDim2.new(0.5, -240, 0.5, -230)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.ZIndex = 40
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(60, 140, 160); stroke.Thickness = 2; stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.5, 0, 0, 30); title.Position = UDim2.new(0, 16, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "SHOP"
	title.TextColor3 = Color3.fromRGB(120, 210, 230)
	title.TextScaled = true; title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 41; title.Parent = panel

	goldLabel = Instance.new("TextLabel")
	goldLabel.Size = UDim2.new(0.3, 0, 0, 26); goldLabel.Position = UDim2.new(0.68, 0, 0, 12)
	goldLabel.BackgroundTransparency = 1
	goldLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
	goldLabel.TextScaled = true; goldLabel.Font = Enum.Font.GothamBold
	goldLabel.TextXAlignment = Enum.TextXAlignment.Right
	goldLabel.ZIndex = 41; goldLabel.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, -32, 0, 18); hint.Position = UDim2.new(0, 16, 0, 40)
	hint.BackgroundTransparency = 1
	hint.Text = "Select a card, then buy an item or service for it"
	hint.TextColor3 = Color3.fromRGB(150, 150, 180)
	hint.TextScaled = true; hint.Font = Enum.Font.Gotham
	hint.ZIndex = 41; hint.Parent = panel

	rerollBtn = Instance.new("TextButton")
	rerollBtn.Size = UDim2.new(0, 140, 0, 30); rerollBtn.Position = UDim2.new(1, -156, 0, 340)
	rerollBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
	rerollBtn.BorderSizePixel = 0
	rerollBtn.TextColor3 = Color3.new(1, 1, 1)
	rerollBtn.TextScaled = true; rerollBtn.Font = Enum.Font.GothamBold
	rerollBtn.ZIndex = 41; rerollBtn.Parent = panel
	corner(rerollBtn, 6)
	rerollBtn.MouseButton1Click:Connect(function()
		if callbacks.onReroll then callbacks.onReroll() end
	end)

	leaveBtn = Instance.new("TextButton")
	leaveBtn.Size = UDim2.new(1, -32, 0, 36); leaveBtn.Position = UDim2.new(0, 16, 1, -46)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	leaveBtn.BorderSizePixel = 0
	leaveBtn.Text = "LEAVE SHOP"
	leaveBtn.TextColor3 = Color3.fromRGB(210, 210, 230)
	leaveBtn.TextScaled = true; leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.ZIndex = 41; leaveBtn.Parent = panel
	corner(leaveBtn, 8)
	leaveBtn.MouseButton1Click:Connect(function()
		if callbacks.onLeave then callbacks.onLeave() end
	end)
end

local function buildOffer(index, offer)
	local def = DungeonConfig.Items[offer.itemId]
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.23, 0, 0, 130)
	b.Position = UDim2.new(0.02 + (index - 1) * 0.245, 0, 0, 64)
	b.BackgroundColor3 = offer.sold and Color3.fromRGB(20, 20, 32) or Color3.fromRGB(26, 26, 44)
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = not offer.sold
	b.ZIndex = 41
	b.Parent = panel
	corner(b, 10)
	local st = Instance.new("UIStroke")
	st.Color = offer.sold and Color3.fromRGB(40, 40, 50) or Color3.fromRGB(60, 140, 160)
	st.Thickness = 1; st.Parent = b

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -10, 0, 36); nameLbl.Position = UDim2.new(0, 5, 0, 6)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = def and def.name or offer.itemId
	nameLbl.TextColor3 = offer.sold and Color3.fromRGB(100, 100, 110) or Color3.fromRGB(230, 230, 245)
	nameLbl.TextScaled = true; nameLbl.TextWrapped = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.ZIndex = 42; nameLbl.Parent = b

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(1, -10, 0, 44); descLbl.Position = UDim2.new(0, 5, 0, 44)
	descLbl.BackgroundTransparency = 1
	descLbl.Text = def and def.desc or ""
	descLbl.TextColor3 = offer.sold and Color3.fromRGB(80, 80, 90) or Color3.fromRGB(170, 170, 200)
	descLbl.TextScaled = true; descLbl.TextWrapped = true
	descLbl.Font = Enum.Font.Gotham
	descLbl.ZIndex = 42; descLbl.Parent = b

	local priceLbl = Instance.new("TextLabel")
	priceLbl.Size = UDim2.new(1, -10, 0, 24); priceLbl.Position = UDim2.new(0, 5, 1, -30)
	priceLbl.BackgroundTransparency = 1
	priceLbl.Text = offer.sold and "SOLD" or (offer.price .. "g")
	priceLbl.TextColor3 = offer.sold and Color3.fromRGB(90, 90, 100) or Color3.fromRGB(255, 210, 90)
	priceLbl.TextScaled = true; priceLbl.Font = Enum.Font.GothamBold
	priceLbl.ZIndex = 42; priceLbl.Parent = b

	if not offer.sold then
		b.MouseButton1Click:Connect(function()
			if selectedCard and callbacks.onBuyItem then callbacks.onBuyItem(index, selectedCard) end
		end)
	end
	return b
end

local function buildService(y, serviceId, def)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -32, 0, 40)
	b.Position = UDim2.new(0, 16, 0, y)
	b.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
	b.BorderSizePixel = 0
	b.Text = ""
	b.ZIndex = 41
	b.Parent = panel
	corner(b, 8)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -100, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = def.name .. " — " .. def.desc
	lbl.TextColor3 = Color3.fromRGB(220, 220, 240)
	lbl.TextScaled = true; lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 42; lbl.Parent = b

	local priceLbl = Instance.new("TextLabel")
	priceLbl.Size = UDim2.new(0, 80, 1, 0); priceLbl.Position = UDim2.new(1, -90, 0, 0)
	priceLbl.BackgroundTransparency = 1
	priceLbl.Text = def.price .. "g"
	priceLbl.TextColor3 = Color3.fromRGB(255, 210, 90)
	priceLbl.TextScaled = true; priceLbl.Font = Enum.Font.GothamBold
	priceLbl.ZIndex = 42; priceLbl.Parent = b

	b.MouseButton1Click:Connect(function()
		if def.target == "all" then
			if callbacks.onBuyService then callbacks.onBuyService(serviceId, nil) end
		elseif selectedCard and callbacks.onBuyService then
			callbacks.onBuyService(serviceId, selectedCard)
		end
	end)
	return b
end

-- shopData: { offers = {{itemId, price, sold}}, rerollCost }
-- run: state snapshot { gold, team, cards }
function ShopUI:Show(shopData, run)
	for _, b in ipairs(offerButtons) do b:Destroy() end
	for _, b in ipairs(serviceButtons) do b:Destroy() end
	for _, b in pairs(cardButtons) do b.btn:Destroy() end
	offerButtons, serviceButtons, cardButtons = {}, {}, {}
	selectedCard = nil

	for i, offer in ipairs(shopData.offers) do
		table.insert(offerButtons, buildOffer(i, offer))
	end

	local serviceIds = {}
	for id in pairs(DungeonConfig.Shop.Services) do table.insert(serviceIds, id) end
	table.sort(serviceIds)
	for i, id in ipairs(serviceIds) do
		table.insert(serviceButtons, buildService(200 + (i - 1) * 46, id, DungeonConfig.Shop.Services[id]))
	end

	local teamIds = {}
	for _, id in ipairs(run.team) do
		if id then table.insert(teamIds, id) end
	end
	local n = #teamIds
	for i, cardId in ipairs(teamIds) do
		local card = CardDatabase:GetById(cardId)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 78, 0, 44)
		b.Position = UDim2.new(0.5, math.floor((i - 1 - n / 2) * 86) + 4, 0, 296)
		b.BackgroundColor3 = Color3.fromRGB(26, 26, 44)
		b.BorderSizePixel = 0
		local itemCount = run.cards[tostring(cardId)] and #(run.cards[tostring(cardId)].items or {}) or 0
		b.Text = (card and card.name or ("#" .. cardId)) .. "\n[" .. itemCount .. "/" .. DungeonConfig.MaxItemsPerCard .. "]"
		b.TextColor3 = Color3.fromRGB(220, 220, 240)
		b.TextScaled = true; b.TextWrapped = true
		b.Font = Enum.Font.GothamBold
		b.ZIndex = 41
		b.Parent = panel
		corner(b, 8)
		local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(50, 50, 80); st.Thickness = 1; st.Parent = b
		b.MouseButton1Click:Connect(function()
			selectedCard = cardId
			refreshCardSelection()
		end)
		cardButtons[cardId] = { btn = b, stroke = st }
	end

	rerollBtn.Text = "REROLL (" .. shopData.rerollCost .. "g)"
	goldLabel.Text = run.gold .. "g"
	refreshCardSelection()
	panel.Visible = true
end

function ShopUI:UpdateGold(gold)
	goldLabel.Text = gold .. "g"
end

function ShopUI:Hide()
	panel.Visible = false
end

function ShopUI:GetPanel()
	return panel
end

return ShopUI
