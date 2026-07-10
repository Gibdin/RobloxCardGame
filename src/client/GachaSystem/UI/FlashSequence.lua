-- FlashSequence — smooth rarity-colored card cycling.
-- Replaces screen-flash with expanding color blooms.
-- No white flashes, no full-screen flickering.

local TweenService = game:GetService("TweenService")

local FlashSequence = {}

local rarityConfig, cardDatabase, vfxConfig, soundMgr
local flashBg, flashCard, cardGlow

local function makeLabel(parent, size, pos, color, font)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos; l.BackgroundTransparency = 1
	l.Text = ""; l.TextColor3 = color or Color3.new(1,1,1)
	l.TextScaled = true; l.Font = font or Enum.Font.GothamBold; l.Parent = parent
	return l
end

local function buildUI(gui)
	-- Soft dark background
	local bg = Instance.new("Frame"); bg.Name = "FlashBG"
	bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(4,4,14)
	bg.BackgroundTransparency = 0.22; bg.ZIndex = 30; bg.Visible = false; bg.Parent = gui

	-- Card panel
	local panel = Instance.new("Frame"); panel.Name = "FlashCard"
	panel.Size = UDim2.new(0,260,0,360); panel.Position = UDim2.new(0.5,-130,0.5,-180)
	panel.BackgroundColor3 = Color3.fromRGB(18,18,32); panel.BorderSizePixel = 0
	panel.ZIndex = 32; panel.Parent = bg
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,14); corner.Parent = panel

	-- Colored border glow (changes per rarity each flash)
	local glow = Instance.new("UIStroke"); glow.Color = Color3.new(1,1,1); glow.Thickness = 0
	glow.Parent = panel; cardGlow = glow

	local bar = Instance.new("Frame"); bar.Name = "RarityBar"
	bar.Size = UDim2.new(1,0,0,10); bar.BackgroundColor3 = Color3.new(1,1,1)
	bar.BorderSizePixel = 0; bar.ZIndex = 33; bar.Parent = panel
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,14); bc.Parent = bar

	local art = makeLabel(panel, UDim2.new(1,0,0.50,0), UDim2.new(0,0,0.05,0),
		Color3.fromRGB(70,70,95), Enum.Font.GothamBlack)
	art.Name = "ArtLabel"; art.Text = "?"; art.TextSize = 84; art.TextScaled = false

	local nameLabel = makeLabel(panel, UDim2.new(0.9,0,0,36), UDim2.new(0.05,0,0.72,0), Color3.new(1,1,1))
	nameLabel.Name = "CardName"
	local rarLabel  = makeLabel(panel, UDim2.new(0.9,0,0,28), UDim2.new(0.05,0,0.85,0), Color3.fromRGB(200,180,100))
	rarLabel.Name   = "RarityLabel"

	flashBg   = bg
	flashCard = panel
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Weighted random card: low rarities appear more for filler flashes
local function randomFlashCard()
	local all = cardDatabase:GetAll(); local pool = {}
	for _, card in ipairs(all) do
		local order  = rarityConfig:GetOrder(card.rarity)
		local weight = math.max(1, (9-order)^3)
		for _ = 1, weight do table.insert(pool, card) end
	end
	return pool[math.random(1,#pool)]
end

local function displayCard(card)
	local rData = rarityConfig.Rarities[card.rarity] or {}
	local col   = rData.color or Color3.new(1,1,1)
	flashCard.RarityBar.BackgroundColor3 = col
	flashCard.CardName.Text              = card.name
	flashCard.RarityLabel.Text           = card.rarity
	flashCard.RarityLabel.TextColor3     = col
	cardGlow.Color     = col
	cardGlow.Thickness = 5
end

-- Subtle card pop (no screen flash)
local function popCard()
	flashCard.Size = UDim2.new(0,236,0,326)
	TweenService:Create(flashCard, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0,260,0,360)
	}):Play()
	-- Glow fades after the pop
	task.delay(0.14, function()
		TweenService:Create(cardGlow, TweenInfo.new(0.18), {Thickness = 0}):Play()
	end)
end

-- Radial color bloom expanding from screen center (replaces flash entirely)
local function colorBloom(color, strength)
	local cfg    = vfxConfig.Bloom
	local alpha  = cfg.startAlpha * (strength or 1.0)
	local r      = cfg.maxRadius * (strength or 1.0)
	local bloom  = Instance.new("Frame"); bloom.Name = "Bloom"
	bloom.AnchorPoint = Vector2.new(0.5,0.5)
	bloom.Size = UDim2.new(0,12,0,12); bloom.Position = UDim2.new(0.5,0,0.5,0)
	bloom.BackgroundColor3 = color; bloom.BackgroundTransparency = 1-alpha
	bloom.ZIndex = 34; bloom.BorderSizePixel = 0; bloom.Parent = flashBg
	local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1,0); uc.Parent = bloom
	TweenService:Create(bloom, TweenInfo.new(cfg.duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0,r,0,r), BackgroundTransparency = 1,
	}):Play()
	task.delay(cfg.duration+0.05, function() if bloom.Parent then bloom:Destroy() end end)
end

-- Gentle background tint shift (soft, not a flash)
local function tintBackground(color)
	TweenService:Create(flashBg, TweenInfo.new(0.20), {
		BackgroundColor3 = Color3.new(
			color.R * 0.12 + 0.02,
			color.G * 0.12 + 0.02,
			color.B * 0.12 + 0.02)
	}):Play()
	task.delay(0.30, function()
		TweenService:Create(flashBg, TweenInfo.new(0.25), {
			BackgroundColor3 = Color3.fromRGB(4,4,14)
		}):Play()
	end)
end

-- ── Public ────────────────────────────────────────────────────────────────────

function FlashSequence:Init(gui, rc, db, vfx, snd)
	rarityConfig = rc; cardDatabase = db; vfxConfig = vfx; soundMgr = snd
	buildUI(gui)
end

function FlashSequence:Play(finalCard, finalRarity)
	local cfg        = rarityConfig.FlashConfig
	local numFlashes = math.random(cfg.MinFlashes, cfg.MaxFlashes)
	local finalOrder = rarityConfig:GetOrder(finalRarity)
	local finalColor = (rarityConfig.Rarities[finalRarity] or {}).color or Color3.new(1,1,1)

	-- Scale in
	flashBg.Visible   = true
	flashBg.BackgroundColor3 = Color3.fromRGB(4,4,14)
	flashCard.Size     = UDim2.new(0,0,0,0)
	flashCard.Position = UDim2.new(0.5,0,0.5,0)
	TweenService:Create(flashCard, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size     = UDim2.new(0,260,0,360),
		Position = UDim2.new(0.5,-130,0.5,-180),
	}):Play()
	task.wait(0.20)

	local interval = cfg.BaseInterval

	for i = 1, numFlashes do
		local card
		local isFakeout = (i == numFlashes-1) and (math.random() < cfg.FakeoutChance)

		if i == numFlashes then
			-- Final card: large bloom with true rarity color
			card = finalCard
			colorBloom(finalColor, 1.0)
			tintBackground(finalColor)
		elseif isFakeout then
			-- Fakeout: bloom with the lower rarity color to mislead
			local fakeOrder  = math.max(1, finalOrder - cfg.FakeoutDropTiers)
			local fakeRarity = rarityConfig:ByOrder(fakeOrder)
			local pool = cardDatabase:GetByRarity(fakeRarity)
			card = (#pool > 0) and pool[math.random(1,#pool)] or randomFlashCard()
			local fakeRData = rarityConfig.Rarities[fakeRarity] or {}
			colorBloom(fakeRData.color or Color3.new(0.5,0.5,0.5), 0.7)
		else
			-- Normal filler: small bloom with card's rarity color
			card = randomFlashCard()
			local rData = rarityConfig.Rarities[card.rarity] or {}
			colorBloom(rData.color or Color3.fromRGB(140,140,140), 0.45)
		end

		displayCard(card)
		popCard()
		soundMgr:Play("roll_tick")

		task.wait(interval)
		interval = interval * cfg.SlowdownFactor
	end

	-- Final card lingers: burst glow then smooth fade-out
	cardGlow.Thickness = 10
	TweenService:Create(cardGlow, TweenInfo.new(0.40, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Thickness = 0}):Play()
	task.wait(0.28)
	TweenService:Create(flashBg, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
	task.wait(0.38)
	flashBg.Visible = false
	flashBg.BackgroundTransparency = 0.22
	flashBg.BackgroundColor3 = Color3.fromRGB(4,4,14)
end

return FlashSequence
