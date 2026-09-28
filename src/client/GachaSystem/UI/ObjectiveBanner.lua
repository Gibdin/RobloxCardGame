-- ObjectiveBanner — a compact "NEXT:" line at the top of the screen that
-- always tells a new player what to do next, and makes the matching side-menu
-- button pulse. Steps (AnimeRosterPlan.md §11.12):
--   open your free packs → build your team → enter the Shibuya Incident →
--   open any packs you've earned → beat the Domain boss.
-- Hidden once the player has beaten the boss and has no unopened packs.

local TweenService = game:GetService("TweenService")

local ObjectiveBanner = {}

local gui, rfGetInventory
local banner, textLbl
local glowStroke, glowTween
local refreshQueued = false

local POLL_SECONDS = 8   -- fallback refresh (packs earned in runs, etc.)

-- Returns text, side-menu button name (or nil to hide the banner).
local function nextStep(data)
	local packs = 0
	for _, n in pairs(data.packs or {}) do packs = packs + n end
	local owned = #(data.cardIds or {})
	local teamFilled = false
	for _, id in ipairs(data.team or {}) do if id then teamFilled = true end end
	local dungeon = data.dungeon or {}

	if owned == 0 then
		if packs > 0 then return "Open your free packs!", "packsBtn" end
		return "Get a pack from the Store!", "storeBtn"
	end
	if not teamFilled then return "Build your team!", "teamBtn" end
	if (dungeon.deepestRow or 0) == 0 then return "Enter the Shibuya Incident!", "battleBtn" end
	if packs > 0 then return ("You have %d pack%s to open!"):format(packs, packs == 1 and "" or "s"), "packsBtn" end
	if (dungeon.bossKills or 0) == 0 then return "Beat the Domain boss in Shibuya!", "battleBtn" end
	return nil, nil
end

local function setGlow(buttonName)
	if glowTween then glowTween:Cancel(); glowTween = nil end
	if glowStroke then glowStroke:Destroy(); glowStroke = nil end
	if not buttonName then return end
	local sideMenu = gui:FindFirstChild("SideMenu")
	local btn = sideMenu and sideMenu:FindFirstChild(buttonName)
	if not btn then return end
	glowStroke = Instance.new("UIStroke")
	glowStroke.Name = "ObjectiveGlow"
	glowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glowStroke.Color = Color3.fromRGB(255, 215, 90)
	glowStroke.Thickness = 2
	glowStroke.Parent = btn
	glowTween = TweenService:Create(glowStroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = 5, Transparency = 0.45 })
	glowTween:Play()
end

function ObjectiveBanner:Refresh()
	-- Coalesce bursts of change events into one server call.
	if refreshQueued then return end
	refreshQueued = true
	task.delay(0.3, function()
		refreshQueued = false
		local ok, data = pcall(function() return rfGetInventory:InvokeServer() end)
		if not ok or not data then return end
		local text, buttonName = nextStep(data)
		if not text then
			banner.Visible = false
			setGlow(nil)
			return
		end
		local changed = textLbl.Text ~= "NEXT:  " .. text
		textLbl.Text = "NEXT:  " .. text
		banner.Visible = true
		setGlow(buttonName)
		if changed then
			-- Small pop when the objective changes.
			local scale = banner:FindFirstChildOfClass("UIScale")
			scale.Scale = 1.15
			TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
end

function ObjectiveBanner:Init(screenGui, rfInv)
	gui, rfGetInventory = screenGui, rfInv

	banner = Instance.new("Frame")
	banner.Name = "ObjectiveBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 14)
	banner.Size = UDim2.new(0, 0, 0, 34)
	banner.AutomaticSize = Enum.AutomaticSize.X
	banner.BackgroundColor3 = Color3.fromRGB(24, 16, 36)
	banner.BackgroundTransparency = 0.1
	banner.BorderSizePixel = 0
	banner.ZIndex = 15
	banner.Visible = false
	banner.Parent = screenGui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = banner
	local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(255, 215, 90); stroke.Thickness = 1.5; stroke.Parent = banner
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 18); pad.PaddingRight = UDim.new(0, 18); pad.Parent = banner
	Instance.new("UIScale").Parent = banner

	textLbl = Instance.new("TextLabel")
	textLbl.Name = "Text"
	textLbl.Size = UDim2.new(0, 0, 1, 0)
	textLbl.AutomaticSize = Enum.AutomaticSize.X
	textLbl.BackgroundTransparency = 1
	textLbl.Text = ""
	textLbl.TextColor3 = Color3.fromRGB(255, 225, 140)
	textLbl.TextSize = 16
	textLbl.Font = Enum.Font.GothamBlack
	textLbl.ZIndex = 16
	textLbl.Parent = banner

	self:Refresh()
	task.spawn(function()
		while banner.Parent do
			task.wait(POLL_SECONDS)
			self:Refresh()
		end
	end)
end

return ObjectiveBanner
