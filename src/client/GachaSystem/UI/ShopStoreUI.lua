-- ShopStoreUI — the real-money storefront: Gem packages, VIP Game Pass,
-- Battle Pass (skeleton), and the active rate-up banner. Distinct from the
-- in-run ShopUI (dungeon gold shop) and from PackOpeningUI's "My Packs" drawer
-- (owned-pack inventory) — this is specifically where Robux-backed purchases
-- happen. Pure view: purchases/prompts are all routed through callbacks.
--
-- Compliance: a permanent "View Odds" link opens a panel showing the exact
-- rarity weights, and every Gem-pack purchase row also shows a compact odds
-- summary inline — both required so a real-money-adjacent randomized purchase
-- always has its odds visibly disclosed before the player spends anything.

local ShopStoreUI = {}

local panel, tabButtons = {}, {}
local tabFrames = {}
local activeTab = "gems"
local oddsPanel

local CardDatabase, RarityConfig, MonetizationConfig, CosmeticConfig
local callbacks = {}
local info = { gems = 0, vip = false, battlePass = { premium = false }, banner = nil }
local cosmeticRows = {}  -- [cosmeticId] = { btn = TextButton }
local cosmeticsState = { owned = { none = true }, equipped = "none" }

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

-- ── Odds disclosure ────────────────────────────────────────────────────────────

local function buildOddsPanel(gui)
	local p = Instance.new("Frame")
	p.Name = "OddsPanel"
	p.Size = UDim2.new(0, 360, 0, 420)
	p.Position = UDim2.new(0.5, -180, 0.5, -210)
	p.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
	p.BackgroundTransparency = 0.03
	p.BorderSizePixel = 0
	p.ZIndex = 40
	p.Visible = false
	p.Parent = gui
	corner(p, 12)
	stroke(p, Color3.fromRGB(60, 60, 90), 2)

	label(p, "DROP RATES", UDim2.new(1, -32, 0, 34), UDim2.new(0, 16, 0, 10),
		Color3.fromRGB(255, 210, 90), Enum.Font.GothamBlack)

	local closeBtn = button(p, "X", UDim2.new(0, 30, 0, 30), UDim2.new(1, -40, 0, 10), Color3.fromRGB(80, 30, 30))
	closeBtn.MouseButton1Click:Connect(function() p.Visible = false end)

	local total = 0
	for _, name in ipairs(RarityConfig.RarityOrder) do
		total = total + RarityConfig.Rarities[name].weight
	end

	local y = 54
	for _, name in ipairs(RarityConfig.RarityOrder) do
		local rData = RarityConfig.Rarities[name]
		local pct = (rData.weight / total) * 100
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -32, 0, 30); row.Position = UDim2.new(0, 16, 0, y)
		row.BackgroundTransparency = 1
		row.ZIndex = 41; row.Parent = p

		label(row, name, UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 0, 0, 0), rData.color, Enum.Font.GothamBold)
		local pctLbl = label(row, string.format("%.2f%%", pct), UDim2.new(0.4, 0, 1, 0), UDim2.new(0.6, 0, 0, 0),
			Color3.fromRGB(200, 200, 220), Enum.Font.GothamBold)
		pctLbl.TextXAlignment = Enum.TextXAlignment.Right
		y = y + 32
	end

	local note = Instance.new("TextLabel")
	note.Size = UDim2.new(1, -32, 0, 60); note.Position = UDim2.new(0, 16, 1, -70)
	note.BackgroundTransparency = 1
	note.Text = "Rates shown are base odds. Pity guarantees a minimum rarity after enough rolls without one; the active banner further biases the featured card within its own rarity."
	note.TextColor3 = Color3.fromRGB(130, 130, 160)
	note.TextWrapped = true; note.TextSize = 12; note.Font = Enum.Font.Gotham
	note.TextYAlignment = Enum.TextYAlignment.Top
	note.ZIndex = 41; note.Parent = p

	return p
end

-- ── Tabs ──────────────────────────────────────────────────────────────────────

local HEADER_HEIGHT = 84

local function buildTopBar(gui)
	local tb = Instance.new("Frame")
	tb.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	tb.BackgroundColor3 = Color3.fromRGB(18, 12, 6)
	tb.BorderSizePixel = 0
	tb.ZIndex = 21; tb.Parent = panel.root

	label(tb, "STORE", UDim2.new(0, 120, 0, 30), UDim2.new(0, 16, 0, 10),
		Color3.fromRGB(255, 210, 90), Enum.Font.GothamBlack)

	local gemsLbl = label(tb, "0", UDim2.new(0, 100, 0, 30), UDim2.new(1, -220, 0, 10),
		Color3.fromRGB(120, 220, 255), Enum.Font.GothamBold)
	gemsLbl.TextXAlignment = Enum.TextXAlignment.Right
	panel.gemsLbl = gemsLbl

	local oddsBtn = button(tb, "View Odds", UDim2.new(0, 90, 0, 28), UDim2.new(1, -120, 0, 11), Color3.fromRGB(40, 40, 60))
	oddsBtn.MouseButton1Click:Connect(function() oddsPanel.Visible = true end)

	local closeBtn = button(tb, "X", UDim2.new(0, 28, 0, 28), UDim2.new(1, -22, 0, 11), Color3.fromRGB(80, 30, 30))
	closeBtn.MouseButton1Click:Connect(function() ShopStoreUI:Hide() end)

	-- Tabs get their own row underneath so 5 tabs fit without crowding the
	-- title/gems/odds/close row above.
	local tabNames = { { id = "gems", label = "GEMS" }, { id = "vip", label = "VIP" },
		{ id = "pass", label = "BATTLE PASS" }, { id = "banner", label = "BANNER" },
		{ id = "cosmetics", label = "COSMETICS" } }
	local TAB_W, TAB_GAP = 104, 4
	for i, t in ipairs(tabNames) do
		local b = button(tb, t.label, UDim2.new(0, TAB_W, 0, 30), UDim2.new(0, 8 + (i - 1) * (TAB_W + TAB_GAP), 0, 46),
			Color3.fromRGB(30, 24, 14))
		b.TextSize = 12
		tabButtons[t.id] = b
		b.MouseButton1Click:Connect(function() ShopStoreUI:ShowTab(t.id) end)
	end
end

-- ── GEMS tab ──────────────────────────────────────────────────────────────────

local function buildGemsTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.gems = f

	for i, product in ipairs(MonetizationConfig.GemProducts) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -32, 0, 64); row.Position = UDim2.new(0, 16, 0, 16 + (i - 1) * 74)
		row.BackgroundColor3 = Color3.fromRGB(24, 20, 14); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = f
		corner(row, 8)

		local amountText = tostring(product.gems) .. (product.bonus > 0 and (" +" .. product.bonus .. " bonus") or "")
		label(row, amountText, UDim2.new(0.55, 0, 1, 0), UDim2.new(0, 14, 0, 0),
			Color3.fromRGB(120, 220, 255), Enum.Font.GothamBold)

		local buyBtn = button(row, "R$ " .. product.priceRobux, UDim2.new(0, 110, 0, 40),
			UDim2.new(1, -124, 0.5, -20), Color3.fromRGB(50, 130, 60))
		buyBtn.MouseButton1Click:Connect(function()
			if callbacks.onBuyGems then callbacks.onBuyGems(product.id) end
		end)
		if product.productId == 0 then
			buyBtn.Text = "Soon"
			buyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		end
	end
end

-- ── VIP tab ───────────────────────────────────────────────────────────────────

local function buildVIPTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.vip = f

	label(f, "VIP", UDim2.new(1, -32, 0, 34), UDim2.new(0, 16, 0, 12),
		Color3.fromRGB(255, 215, 80), Enum.Font.GothamBlack)

	local benefitsLbl = Instance.new("TextLabel")
	benefitsLbl.Size = UDim2.new(1, -32, 0, 140); benefitsLbl.Position = UDim2.new(0, 16, 0, 50)
	benefitsLbl.BackgroundTransparency = 1
	benefitsLbl.Text = "\226\128\162 " .. table.concat(MonetizationConfig.VIP.benefits, "\n\226\128\162 ")
	benefitsLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
	benefitsLbl.TextWrapped = true; benefitsLbl.TextSize = 15; benefitsLbl.Font = Enum.Font.Gotham
	benefitsLbl.TextXAlignment = Enum.TextXAlignment.Left
	benefitsLbl.TextYAlignment = Enum.TextYAlignment.Top
	benefitsLbl.ZIndex = 22; benefitsLbl.Parent = f

	local buyBtn = button(f, "R$ " .. MonetizationConfig.VIP.priceRobux, UDim2.new(0, 160, 0, 44),
		UDim2.new(0, 16, 0, 200), Color3.fromRGB(180, 140, 30))
	buyBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuyVIP then callbacks.onBuyVIP() end
	end)
	panel.vipBuyBtn = buyBtn

	local claimBtn = button(f, "CLAIM DAILY PACK", UDim2.new(0, 220, 0, 44), UDim2.new(0, 16, 0, 256),
		Color3.fromRGB(50, 130, 60))
	claimBtn.MouseButton1Click:Connect(function()
		if callbacks.onClaimVIPDaily then callbacks.onClaimVIPDaily() end
	end)
	panel.vipClaimBtn = claimBtn
end

-- ── BATTLE PASS tab (skeleton) ────────────────────────────────────────────────

local function buildPassTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.pass = f

	label(f, "SEASON BATTLE PASS", UDim2.new(1, -32, 0, 34), UDim2.new(0, 16, 0, 12),
		Color3.fromRGB(200, 160, 255), Enum.Font.GothamBlack)

	local note = Instance.new("TextLabel")
	note.Size = UDim2.new(1, -32, 0, 80); note.Position = UDim2.new(0, 16, 0, 54)
	note.BackgroundTransparency = 1
	note.Text = ("%d tiers this season \226\128\162 earn Pass XP from Dungeon/Tower runs \226\128\162 reward track coming soon")
		:format(MonetizationConfig.BattlePass.maxTier)
	note.TextColor3 = Color3.fromRGB(180, 180, 210)
	note.TextWrapped = true; note.TextSize = 14; note.Font = Enum.Font.Gotham
	note.TextYAlignment = Enum.TextYAlignment.Top
	note.ZIndex = 22; note.Parent = f

	local buyBtn = button(f, "R$ " .. MonetizationConfig.BattlePass.priceRobux, UDim2.new(0, 160, 0, 44),
		UDim2.new(0, 16, 0, 150), Color3.fromRGB(120, 80, 200))
	buyBtn.MouseButton1Click:Connect(function()
		if callbacks.onBuyBattlePass then callbacks.onBuyBattlePass() end
	end)
	panel.passBuyBtn = buyBtn
end

-- ── BANNER tab ────────────────────────────────────────────────────────────────

local function buildBannerTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.banner = f

	local nameLbl = label(f, "", UDim2.new(1, -32, 0, 34), UDim2.new(0, 16, 0, 12),
		Color3.fromRGB(255, 210, 90), Enum.Font.GothamBlack)
	panel.bannerNameLbl = nameLbl

	local featuredLbl = label(f, "", UDim2.new(1, -32, 0, 28), UDim2.new(0, 16, 0, 50),
		Color3.fromRGB(220, 220, 240), Enum.Font.GothamBold)
	panel.bannerFeaturedLbl = featuredLbl

	local pullsLbl = label(f, "", UDim2.new(1, -32, 0, 22), UDim2.new(0, 16, 0, 82),
		Color3.fromRGB(150, 150, 180), Enum.Font.Gotham)
	panel.bannerPullsLbl = pullsLbl

	local cost = MonetizationConfig.PackGemCost.EventPack or 0
	local buyBtn = button(f, ("Pull \226\128\148 %d Gems"):format(cost), UDim2.new(0, 180, 0, 44),
		UDim2.new(0, 16, 0, 120), Color3.fromRGB(180, 60, 160))
	buyBtn.MouseButton1Click:Connect(function()
		if callbacks.onPullBanner then callbacks.onPullBanner() end
	end)
	panel.bannerBuyBtn = buyBtn

	local noBannerLbl = label(f, "No banner is currently active.", UDim2.new(1, -32, 0, 30), UDim2.new(0, 16, 0, 50),
		Color3.fromRGB(120, 120, 150), Enum.Font.Gotham)
	noBannerLbl.Visible = false
	panel.bannerNoneLbl = noBannerLbl
end

-- ── COSMETICS tab ─────────────────────────────────────────────────────────────
-- Gem-purchased Trails — never touches gacha odds. Trail preview swatches use
-- plain Frame colors, not the actual Trail effect (that only renders on a
-- character in the 3D world).

local function refreshCosmeticRow(cosmeticId)
	local row = cosmeticRows[cosmeticId]
	if not row then return end

	local owned = cosmeticsState.owned[cosmeticId] == true
	local equipped = cosmeticsState.equipped == cosmeticId

	if equipped then
		row.btn.Text = "EQUIPPED"
		row.btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	elseif owned then
		row.btn.Text = "EQUIP"
		row.btn.BackgroundColor3 = Color3.fromRGB(60, 110, 170)
	else
		row.btn.Text = row.costLabel
		row.btn.BackgroundColor3 = Color3.fromRGB(50, 130, 60)
	end
end

local function buildCosmeticsTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.cosmetics = f

	for i, cfg in ipairs(CosmeticConfig.Trails) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -32, 0, 50); row.Position = UDim2.new(0, 16, 0, 8 + (i - 1) * 58)
		row.BackgroundColor3 = Color3.fromRGB(24, 20, 14); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = f
		corner(row, 8)

		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 34, 0, 34); swatch.Position = UDim2.new(0, 8, 0.5, -17)
		swatch.BackgroundColor3 = cfg.color1 or Color3.fromRGB(60, 60, 70)
		swatch.BorderSizePixel = 0
		swatch.ZIndex = 23; swatch.Parent = row
		corner(swatch, 6)

		label(row, cfg.name, UDim2.new(0.5, -50, 1, 0), UDim2.new(0, 52, 0, 0),
			Color3.fromRGB(220, 220, 240), Enum.Font.GothamBold)

		local costLabel = cfg.gemCost > 0 and (tostring(cfg.gemCost) .. " Gems") or "Default"
		local btn = button(row, costLabel, UDim2.new(0, 110, 0, 34), UDim2.new(1, -120, 0.5, -17),
			Color3.fromRGB(50, 130, 60))
		btn.MouseButton1Click:Connect(function()
			local owned = cosmeticsState.owned[cfg.id] == true
			if owned then
				if callbacks.onEquipCosmetic then callbacks.onEquipCosmetic(cfg.id) end
			else
				if callbacks.onBuyCosmetic then callbacks.onBuyCosmetic(cfg.id) end
			end
		end)

		cosmeticRows[cfg.id] = { btn = btn, costLabel = costLabel }
	end
end

-- Pushes fresh cosmetics data (owned/equipped) and refreshes every row.
function ShopStoreUI:RefreshCosmetics(cosmeticsInfo)
	cosmeticsState = cosmeticsInfo or cosmeticsState
	for cosmeticId in pairs(cosmeticRows) do
		refreshCosmeticRow(cosmeticId)
	end
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- cbs: { onBuyGems(configId), onBuyVIP(), onClaimVIPDaily(), onBuyBattlePass(),
--        onPullBanner(), onBuyCosmetic(id), onEquipCosmetic(id) }
function ShopStoreUI:Init(gui, cardDb, rarityConf, monetizationConf, cosmeticConf, cbs)
	CardDatabase = cardDb
	RarityConfig = rarityConf
	MonetizationConfig = monetizationConf
	CosmeticConfig = cosmeticConf
	callbacks = cbs or {}

	local root = Instance.new("Frame")
	root.Name = "ShopStorePanel"
	root.Size = UDim2.new(0, 560, 0, 480)
	root.Position = UDim2.new(0.5, -280, 0.5, -240)
	root.BackgroundColor3 = Color3.fromRGB(16, 12, 8)
	root.BackgroundTransparency = 0.05
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.ZIndex = 20
	root.Visible = false
	root.Parent = gui
	corner(root, 12)
	stroke(root, Color3.fromRGB(60, 50, 30), 1)
	panel.root = root

	buildTopBar(gui)
	buildGemsTab(gui)
	buildVIPTab(gui)
	buildPassTab(gui)
	buildBannerTab(gui)
	buildCosmeticsTab(gui)
	oddsPanel = buildOddsPanel(gui)

	self:ShowTab("gems")
end

function ShopStoreUI:ShowTab(tabId)
	activeTab = tabId
	for id, frame in pairs(tabFrames) do
		frame.Visible = (id == tabId)
	end
	for id, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (id == tabId) and Color3.fromRGB(70, 56, 20) or Color3.fromRGB(30, 24, 14)
	end
end

-- Pushes fresh server data (gems/vip/battlePass/banner) into the panel.
function ShopStoreUI:Refresh(newInfo)
	info = newInfo or info
	panel.gemsLbl.Text = tostring(info.gems or 0)

	if info.vip then
		panel.vipBuyBtn.Text = "OWNED"
		panel.vipBuyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		panel.vipClaimBtn.Visible = true
	else
		panel.vipBuyBtn.Text = "R$ " .. MonetizationConfig.VIP.priceRobux
		panel.vipBuyBtn.BackgroundColor3 = Color3.fromRGB(180, 140, 30)
		panel.vipClaimBtn.Visible = false
	end

	if info.battlePass and info.battlePass.premium then
		panel.passBuyBtn.Text = "OWNED"
		panel.passBuyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	else
		panel.passBuyBtn.Text = "R$ " .. MonetizationConfig.BattlePass.priceRobux
		panel.passBuyBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 200)
	end

	if info.banner then
		panel.bannerNoneLbl.Visible = false
		panel.bannerNameLbl.Visible = true
		panel.bannerFeaturedLbl.Visible = true
		panel.bannerPullsLbl.Visible = true
		panel.bannerBuyBtn.Visible = true

		panel.bannerNameLbl.Text = info.banner.name
		local card = CardDatabase:GetById(info.banner.featuredCardId)
		panel.bannerFeaturedLbl.Text = "Featured: " .. (card and card.name or ("#" .. info.banner.featuredCardId))
			.. (card and (" (" .. card.rarity .. ")") or "")
		panel.bannerPullsLbl.Text = ("%dx rate-up \226\128\162 %d/%d pulls to guarantee"):format(
			info.banner.rateMult, info.banner.pulls, info.banner.guaranteeAfter)
	else
		panel.bannerNoneLbl.Visible = true
		panel.bannerNameLbl.Visible = false
		panel.bannerFeaturedLbl.Visible = false
		panel.bannerPullsLbl.Visible = false
		panel.bannerBuyBtn.Visible = false
	end
end

function ShopStoreUI:Show()
	panel.root.Visible = true
end

function ShopStoreUI:Hide()
	panel.root.Visible = false
	oddsPanel.Visible = false
end

function ShopStoreUI:GetPanel()
	return panel.root
end

return ShopStoreUI
