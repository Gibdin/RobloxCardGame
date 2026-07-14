-- SocialUI — tabbed GUILD / TRADE / FRIENDS panel (Phase 7), consolidating
-- what would otherwise be 3 more side-menu buttons into the one existing
-- tabbed-panel pattern already used by QuestUI/ArenaUI. Pure view: all
-- create/join/trade/gift actions are routed through callbacks; Refresh(data)
-- pushes fresh server data in.
--
-- Trade card selection is numeric card-ID entry rather than a visual picker
-- — consistent with this project's established "functional MVP first, visual
-- polish later" scope (see GameDesign.md Phase 7 notes).

local SocialUI = {}

local panel = {}
local tabButtons, tabFrames = {}, {}
local guildListRows = {}
local memberRows = {}
local chatRows = {}
local incomingRows = {}
local outgoingRows = {}
local friendRows = {}
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

local function textbox(parent, placeholder, size, pos)
	local t = Instance.new("TextBox")
	t.Size = size; t.Position = pos
	t.BackgroundColor3 = Color3.fromRGB(30, 34, 40)
	t.BorderSizePixel = 0
	t.PlaceholderText = placeholder
	t.Text = ""
	t.TextColor3 = Color3.new(1, 1, 1)
	t.PlaceholderColor3 = Color3.fromRGB(130, 130, 150)
	t.TextScaled = true
	t.Font = Enum.Font.Gotham
	t.ZIndex = 22; t.Parent = parent
	corner(t, 6)
	return t
end

local HEADER_HEIGHT = 66

local function buildTopBar(gui)
	local tb = Instance.new("Frame")
	tb.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	tb.BackgroundColor3 = Color3.fromRGB(10, 16, 20)
	tb.BorderSizePixel = 0
	tb.ZIndex = 21; tb.Parent = panel.root

	label(tb, "SOCIAL", UDim2.new(0, 140, 0, 28), UDim2.new(0, 16, 0, 8),
		Color3.fromRGB(100, 200, 220), Enum.Font.GothamBlack)

	local closeBtn = button(tb, "X", UDim2.new(0, 28, 0, 28), UDim2.new(1, -22, 0, 8), Color3.fromRGB(80, 30, 30))
	closeBtn.MouseButton1Click:Connect(function() SocialUI:Hide() end)

	local tabNames = { { id = "guild", label = "GUILD" }, { id = "trade", label = "TRADE" }, { id = "friends", label = "FRIENDS" } }
	local TAB_W, TAB_GAP = 110, 6
	for i, t in ipairs(tabNames) do
		local b = button(tb, t.label, UDim2.new(0, TAB_W, 0, 26), UDim2.new(0, 8 + (i - 1) * (TAB_W + TAB_GAP), 0, 36),
			Color3.fromRGB(18, 26, 30))
		b.TextSize = 12
		tabButtons[t.id] = b
		b.MouseButton1Click:Connect(function() SocialUI:ShowTab(t.id) end)
	end
end

-- ── GUILD tab ─────────────────────────────────────────────────────────────────

local function buildGuildTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.guild = f

	-- "No guild" sub-view: create or browse/join.
	local noGuild = Instance.new("Frame")
	noGuild.Size = UDim2.new(1, 0, 1, 0); noGuild.BackgroundTransparency = 1
	noGuild.ZIndex = 21; noGuild.Parent = f
	panel.noGuildFrame = noGuild

	local nameBox = textbox(noGuild, "Guild name...", UDim2.new(0, 260, 0, 34), UDim2.new(0, 8, 0, 6))
	panel.guildNameBox = nameBox
	local createBtn = button(noGuild, "CREATE", UDim2.new(0, 100, 0, 34), UDim2.new(0, 276, 0, 6), Color3.fromRGB(50, 130, 60))
	createBtn.MouseButton1Click:Connect(function()
		if callbacks.onCreateGuild then callbacks.onCreateGuild(nameBox.Text) end
	end)

	label(noGuild, "Existing guilds:", UDim2.new(0, 200, 0, 20), UDim2.new(0, 8, 0, 48),
		Color3.fromRGB(160, 170, 180), Enum.Font.GothamBold).TextSize = 13

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -76); scroll.Position = UDim2.new(0, 8, 0, 72)
	scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 15 * 46)
	scroll.ZIndex = 21; scroll.Parent = noGuild

	for i = 1, 15 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 40); row.Position = UDim2.new(0, 0, 0, (i - 1) * 46)
		row.BackgroundColor3 = Color3.fromRGB(16, 22, 26); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = scroll
		row.Visible = false
		corner(row, 6)

		local nameLbl = label(row, "—", UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 10, 0, 0),
			Color3.fromRGB(220, 220, 240), Enum.Font.GothamBold)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left

		local joinBtn = button(row, "JOIN", UDim2.new(0, 80, 0, 30), UDim2.new(1, -88, 0.5, -15), Color3.fromRGB(50, 110, 140))
		joinBtn.MouseButton1Click:Connect(function()
			local guildId = joinBtn:GetAttribute("guildId")
			if guildId and callbacks.onJoinGuild then callbacks.onJoinGuild(guildId) end
		end)

		guildListRows[i] = { row = row, nameLbl = nameLbl, joinBtn = joinBtn }
	end
	panel.guildListEmptyLbl = label(scroll, "No guilds exist yet — be the first to create one!",
		UDim2.new(1, -16, 0, 30), UDim2.new(0, 4, 0, 4), Color3.fromRGB(140, 150, 160), Enum.Font.Gotham)
	panel.guildListEmptyLbl.TextWrapped = true
	panel.guildListEmptyLbl.Visible = false

	-- "In guild" sub-view: dashboard + chat.
	local inGuild = Instance.new("Frame")
	inGuild.Size = UDim2.new(1, 0, 1, 0); inGuild.BackgroundTransparency = 1
	inGuild.ZIndex = 21; inGuild.Parent = f
	inGuild.Visible = false
	panel.inGuildFrame = inGuild

	local headerLbl = label(inGuild, "—", UDim2.new(0.65, 0, 0, 24), UDim2.new(0, 8, 0, 4),
		Color3.fromRGB(220, 220, 240), Enum.Font.GothamBlack)
	headerLbl.TextXAlignment = Enum.TextXAlignment.Left
	panel.guildHeaderLbl = headerLbl

	local leaveBtn = button(inGuild, "LEAVE", UDim2.new(0, 90, 0, 26), UDim2.new(1, -98, 0, 6), Color3.fromRGB(120, 40, 40))
	leaveBtn.MouseButton1Click:Connect(function()
		if callbacks.onLeaveGuild then callbacks.onLeaveGuild() end
	end)

	local xpBarBg = Instance.new("Frame")
	xpBarBg.Size = UDim2.new(1, -16, 0, 8); xpBarBg.Position = UDim2.new(0, 8, 0, 30)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(30, 34, 30); xpBarBg.BorderSizePixel = 0
	xpBarBg.ZIndex = 21; xpBarBg.Parent = inGuild
	corner(xpBarBg, 4)
	local xpBar = Instance.new("Frame")
	xpBar.Size = UDim2.new(0, 0, 1, 0)
	xpBar.BackgroundColor3 = Color3.fromRGB(100, 200, 220); xpBar.BorderSizePixel = 0
	xpBar.ZIndex = 22; xpBar.Parent = xpBarBg
	corner(xpBar, 4)
	panel.guildXpBar = xpBar

	local xpLbl = label(inGuild, "", UDim2.new(0.5, 0, 0, 16), UDim2.new(0, 8, 0, 40),
		Color3.fromRGB(160, 170, 180), Enum.Font.Gotham)
	xpLbl.TextXAlignment = Enum.TextXAlignment.Left; xpLbl.TextSize = 12
	panel.guildXpLbl = xpLbl

	local warLbl = label(inGuild, "", UDim2.new(0.5, 0, 0, 16), UDim2.new(0.5, 0, 0, 40),
		Color3.fromRGB(255, 210, 90), Enum.Font.Gotham)
	warLbl.TextXAlignment = Enum.TextXAlignment.Right; warLbl.TextSize = 12
	panel.guildWarLbl = warLbl

	label(inGuild, "Members", UDim2.new(0.35, 0, 0, 18), UDim2.new(0, 8, 0, 60),
		Color3.fromRGB(160, 170, 180), Enum.Font.GothamBold).TextSize = 12

	local memberScroll = Instance.new("ScrollingFrame")
	memberScroll.Size = UDim2.new(0.35, -12, 1, -84); memberScroll.Position = UDim2.new(0, 8, 0, 80)
	memberScroll.BackgroundTransparency = 1; memberScroll.BorderSizePixel = 0
	memberScroll.ScrollBarThickness = 4
	memberScroll.CanvasSize = UDim2.new(0, 0, 0, 20 * 26)
	memberScroll.ZIndex = 21; memberScroll.Parent = inGuild

	for i = 1, 20 do
		local m = label(memberScroll, "—", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, (i - 1) * 26),
			Color3.fromRGB(200, 210, 220), Enum.Font.Gotham)
		m.TextXAlignment = Enum.TextXAlignment.Left; m.TextSize = 13
		m.Visible = false
		memberRows[i] = m
	end

	label(inGuild, "Guild Chat", UDim2.new(0.6, 0, 0, 18), UDim2.new(0.37, 0, 0, 60),
		Color3.fromRGB(160, 170, 180), Enum.Font.GothamBold).TextSize = 12

	local chatScroll = Instance.new("ScrollingFrame")
	chatScroll.Size = UDim2.new(0.63, -8, 1, -128); chatScroll.Position = UDim2.new(0.37, 0, 0, 80)
	chatScroll.BackgroundColor3 = Color3.fromRGB(14, 18, 22); chatScroll.BorderSizePixel = 0
	chatScroll.ScrollBarThickness = 4
	chatScroll.CanvasSize = UDim2.new(0, 0, 0, 50 * 22)
	chatScroll.ZIndex = 21; chatScroll.Parent = inGuild
	corner(chatScroll, 6)

	-- Each row pairs the message with a small REPORT button (Trust & Safety —
	-- filtering catches profanity, not harassment/context-dependent abuse, so
	-- players still need a way to flag a message for human review).
	for i = 1, 50 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 20); row.Position = UDim2.new(0, 4, 0, (i - 1) * 22)
		row.BackgroundTransparency = 1
		row.ZIndex = 21; row.Parent = chatScroll
		row.Visible = false

		local c = label(row, "", UDim2.new(1, -52, 1, 0), UDim2.new(0, 0, 0, 0),
			Color3.fromRGB(210, 220, 230), Enum.Font.Gotham)
		c.TextXAlignment = Enum.TextXAlignment.Left; c.TextWrapped = true; c.TextSize = 12

		local reportBtn = button(row, "REPORT", UDim2.new(0, 48, 0, 18), UDim2.new(1, -48, 0, 1), Color3.fromRGB(90, 40, 40))
		reportBtn.TextSize = 9
		reportBtn.MouseButton1Click:Connect(function()
			local targetUserId = reportBtn:GetAttribute("targetUserId")
			if targetUserId and callbacks.onReportMessage then
				callbacks.onReportMessage(targetUserId, c.Text)
			end
		end)

		chatRows[i] = { row = row, label = c, reportBtn = reportBtn }
	end
	panel.chatScroll = chatScroll

	local chatBox = textbox(inGuild, "Say something...", UDim2.new(0.63 - 0.14, -8, 0, 34), UDim2.new(0.37, 0, 1, -40))
	panel.chatBox = chatBox
	local sendBtn = button(inGuild, "SEND", UDim2.new(0, 90, 0, 34), UDim2.new(1, -98, 1, -40), Color3.fromRGB(50, 110, 140))
	sendBtn.MouseButton1Click:Connect(function()
		if callbacks.onSendChat and chatBox.Text ~= "" then
			callbacks.onSendChat(chatBox.Text)
			chatBox.Text = ""
		end
	end)
end

-- ── TRADE tab ─────────────────────────────────────────────────────────────────

local function buildTradeTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.trade = f

	label(f, "Card-for-card only. Common/Uncommon/Rare only. Enter the exact card IDs (see Inventory).",
		UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 0, 2), Color3.fromRGB(150, 160, 170), Enum.Font.Gotham).TextSize = 11

	local targetBox = textbox(f, "Target player's UserId", UDim2.new(0, 170, 0, 30), UDim2.new(0, 8, 0, 34))
	local offerBox  = textbox(f, "Your card Id",  UDim2.new(0, 120, 0, 30), UDim2.new(0, 184, 0, 34))
	local requestBox = textbox(f, "Their card Id", UDim2.new(0, 120, 0, 30), UDim2.new(0, 310, 0, 34))
	local proposeBtn = button(f, "PROPOSE", UDim2.new(0, 100, 0, 30), UDim2.new(0, 436, 0, 34), Color3.fromRGB(50, 130, 60))
	proposeBtn.MouseButton1Click:Connect(function()
		local toUserId = tonumber(targetBox.Text)
		local offerCardId = tonumber(offerBox.Text)
		local requestCardId = tonumber(requestBox.Text)
		if toUserId and offerCardId and requestCardId and callbacks.onProposeTrade then
			callbacks.onProposeTrade(toUserId, offerCardId, requestCardId)
		end
	end)

	label(f, "Incoming Offers", UDim2.new(0.5, 0, 0, 18), UDim2.new(0, 8, 0, 74),
		Color3.fromRGB(160, 170, 180), Enum.Font.GothamBold).TextSize = 12

	local inScroll = Instance.new("ScrollingFrame")
	inScroll.Size = UDim2.new(0.5, -12, 1, -100); inScroll.Position = UDim2.new(0, 8, 0, 94)
	inScroll.BackgroundTransparency = 1; inScroll.BorderSizePixel = 0
	inScroll.ScrollBarThickness = 4
	inScroll.CanvasSize = UDim2.new(0, 0, 0, 8 * 70)
	inScroll.ZIndex = 21; inScroll.Parent = f

	-- Row/button sizing here targets a touch-friendly ~32px minimum tap
	-- height (mobile is the majority of Roblox's audience) rather than the
	-- ~22px the rest of this project's smallest buttons use elsewhere.
	for i = 1, 8 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 64); row.Position = UDim2.new(0, 0, 0, (i - 1) * 70)
		row.BackgroundColor3 = Color3.fromRGB(16, 20, 26); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = inScroll
		row.Visible = false
		corner(row, 6)

		local descLbl = label(row, "—", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 2),
			Color3.fromRGB(210, 220, 230), Enum.Font.Gotham)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left; descLbl.TextWrapped = true; descLbl.TextSize = 12

		local acceptBtn = button(row, "ACCEPT", UDim2.new(0, 76, 0, 32), UDim2.new(0, 8, 1, -36), Color3.fromRGB(50, 130, 60))
		acceptBtn.TextSize = 12
		acceptBtn.MouseButton1Click:Connect(function()
			local id = acceptBtn:GetAttribute("offerId")
			if id and callbacks.onRespondTrade then callbacks.onRespondTrade(id, true) end
		end)

		local declineBtn = button(row, "DECLINE", UDim2.new(0, 76, 0, 32), UDim2.new(0, 90, 1, -36), Color3.fromRGB(120, 40, 40))
		declineBtn.TextSize = 12
		declineBtn.MouseButton1Click:Connect(function()
			local id = declineBtn:GetAttribute("offerId")
			if id and callbacks.onRespondTrade then callbacks.onRespondTrade(id, false) end
		end)

		incomingRows[i] = { row = row, descLbl = descLbl, acceptBtn = acceptBtn, declineBtn = declineBtn }
	end

	label(f, "Outgoing Offers", UDim2.new(0.5, 0, 0, 18), UDim2.new(0.5, 0, 0, 74),
		Color3.fromRGB(160, 170, 180), Enum.Font.GothamBold).TextSize = 12

	local outScroll = Instance.new("ScrollingFrame")
	outScroll.Size = UDim2.new(0.5, -12, 1, -100); outScroll.Position = UDim2.new(0.5, 4, 0, 94)
	outScroll.BackgroundTransparency = 1; outScroll.BorderSizePixel = 0
	outScroll.ScrollBarThickness = 4
	outScroll.CanvasSize = UDim2.new(0, 0, 0, 8 * 70)
	outScroll.ZIndex = 21; outScroll.Parent = f

	for i = 1, 8 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 64); row.Position = UDim2.new(0, 0, 0, (i - 1) * 70)
		row.BackgroundColor3 = Color3.fromRGB(16, 20, 26); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = outScroll
		row.Visible = false
		corner(row, 6)

		local descLbl = label(row, "—", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 2),
			Color3.fromRGB(210, 220, 230), Enum.Font.Gotham)
		descLbl.TextXAlignment = Enum.TextXAlignment.Left; descLbl.TextWrapped = true; descLbl.TextSize = 12

		local cancelBtn = button(row, "CANCEL", UDim2.new(0, 90, 0, 32), UDim2.new(0, 8, 1, -36), Color3.fromRGB(120, 40, 40))
		cancelBtn.TextSize = 12
		cancelBtn.MouseButton1Click:Connect(function()
			local id = cancelBtn:GetAttribute("offerId")
			if id and callbacks.onCancelTrade then callbacks.onCancelTrade(id) end
		end)

		outgoingRows[i] = { row = row, descLbl = descLbl, cancelBtn = cancelBtn }
	end
end

-- ── FRIENDS tab ───────────────────────────────────────────────────────────────

local function buildFriendsTab(gui)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT); f.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	f.BackgroundTransparency = 1; f.Visible = false
	f.ZIndex = 21; f.Parent = panel.root
	tabFrames.friends = f

	label(f, "Friends in this server. One free pack gift per day, to anyone.",
		UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 2), Color3.fromRGB(150, 160, 170), Enum.Font.Gotham).TextSize = 12

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -30); scroll.Position = UDim2.new(0, 8, 0, 26)
	scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 15 * 46)
	scroll.ZIndex = 21; scroll.Parent = f

	for i = 1, 15 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 40); row.Position = UDim2.new(0, 0, 0, (i - 1) * 46)
		row.BackgroundColor3 = Color3.fromRGB(16, 22, 26); row.BorderSizePixel = 0
		row.ZIndex = 22; row.Parent = scroll
		row.Visible = false
		corner(row, 6)

		local nameLbl = label(row, "—", UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 10, 0, 0),
			Color3.fromRGB(220, 220, 240), Enum.Font.GothamBold)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left

		local giftBtn = button(row, "GIFT PACK", UDim2.new(0, 100, 0, 30), UDim2.new(1, -108, 0.5, -15), Color3.fromRGB(50, 130, 60))
		giftBtn.TextSize = 12
		giftBtn.MouseButton1Click:Connect(function()
			local userId = giftBtn:GetAttribute("userId")
			if userId and callbacks.onGiftPack then callbacks.onGiftPack(userId) end
		end)

		friendRows[i] = { row = row, nameLbl = nameLbl, giftBtn = giftBtn }
	end
	panel.friendsEmptyLbl = label(scroll, "No friends currently in this server.",
		UDim2.new(1, -16, 0, 30), UDim2.new(0, 4, 0, 4), Color3.fromRGB(140, 150, 160), Enum.Font.Gotham)
	panel.friendsEmptyLbl.Visible = false
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- cbs: { onCreateGuild(name), onJoinGuild(guildId), onLeaveGuild(), onSendChat(text),
--        onProposeTrade(toUserId, offerCardId, requestCardId), onRespondTrade(offerId, accept),
--        onCancelTrade(offerId), onGiftPack(toUserId), onReportMessage(targetUserId, text) }
function SocialUI:Init(gui, cbs)
	callbacks = cbs or {}

	local root = Instance.new("Frame")
	root.Name = "SocialPanel"
	root.Size = UDim2.new(0, 660, 0, 480)
	root.Position = UDim2.new(0.5, -330, 0.5, -240)
	root.BackgroundColor3 = Color3.fromRGB(8, 12, 14)
	root.BackgroundTransparency = 0.05
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.ZIndex = 20
	root.Visible = false
	root.Parent = gui
	corner(root, 12)
	stroke(root, Color3.fromRGB(40, 60, 65), 1)
	panel.root = root

	buildTopBar(gui)
	buildGuildTab(gui)
	buildTradeTab(gui)
	buildFriendsTab(gui)

	self:ShowTab("guild")
end

function SocialUI:ShowTab(tabId)
	for id, frame in pairs(tabFrames) do
		frame.Visible = (id == tabId)
	end
	for id, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (id == tabId) and Color3.fromRGB(40, 80, 90) or Color3.fromRGB(18, 26, 30)
	end
end

-- data: {
--   guild = nil or { id, name, level, xp, nextLevelXP, warScore, members = {{userId,name,isOwner}} },
--   guildList = { {id,name,level,memberCount}, ... },
--   chat = { {userId,name,text,ts}, ... },
--   incomingOffers = { {id,fromUserId,toUserId,offerCardId,offerCardName,requestCardId,requestCardName} },
--   outgoingOffers = same shape,
--   friends = { {userId, name}, ... },
-- }
function SocialUI:Refresh(data)
	data = data or {}

	-- Guild sub-view.
	local guild = data.guild
	panel.noGuildFrame.Visible = guild == nil
	panel.inGuildFrame.Visible = guild ~= nil

	if guild == nil then
		local list = data.guildList or {}
		panel.guildListEmptyLbl.Visible = #list == 0
		for i, rowUI in ipairs(guildListRows) do
			local e = list[i]
			if e then
				rowUI.row.Visible = true
				rowUI.nameLbl.Text = string.format("%s (Lv.%d, %d members)", e.name, e.level, e.memberCount)
				rowUI.joinBtn:SetAttribute("guildId", e.id)
			else
				rowUI.row.Visible = false
			end
		end
	else
		panel.guildHeaderLbl.Text = string.format("%s — Level %d", guild.name, guild.level)
		local nextXP = guild.nextLevelXP
		if nextXP then
			panel.guildXpBar.Size = UDim2.new(math.clamp(guild.xp / nextXP, 0, 1), 0, 1, 0)
			panel.guildXpLbl.Text = string.format("%d / %d XP", guild.xp, nextXP)
		else
			panel.guildXpBar.Size = UDim2.new(1, 0, 1, 0)
			panel.guildXpLbl.Text = string.format("%d XP (max level)", guild.xp)
		end
		panel.guildWarLbl.Text = "Guild Wars Score: " .. tostring(guild.warScore or 0)

		local members = guild.members or {}
		for i, m in ipairs(memberRows) do
			local e = members[i]
			if e then
				m.Visible = true
				m.Text = e.name .. (e.isOwner and "  (owner)" or "")
			else
				m.Visible = false
			end
		end
	end

	if data.chat then
		local chat = data.chat
		for i, rowUI in ipairs(chatRows) do
			local e = chat[i]
			if e then
				rowUI.row.Visible = true
				rowUI.label.Text = string.format("[%s] %s", e.name, e.text)
				rowUI.reportBtn:SetAttribute("targetUserId", e.userId)
			else
				rowUI.row.Visible = false
			end
		end
	end

	local incoming = data.incomingOffers or {}
	for i, rowUI in ipairs(incomingRows) do
		local o = incoming[i]
		if o then
			rowUI.row.Visible = true
			rowUI.descLbl.Text = string.format("Offers %s for your %s", o.offerCardName, o.requestCardName)
			rowUI.acceptBtn:SetAttribute("offerId", o.id)
			rowUI.declineBtn:SetAttribute("offerId", o.id)
		else
			rowUI.row.Visible = false
		end
	end

	local outgoing = data.outgoingOffers or {}
	for i, rowUI in ipairs(outgoingRows) do
		local o = outgoing[i]
		if o then
			rowUI.row.Visible = true
			rowUI.descLbl.Text = string.format("You offered %s for their %s", o.offerCardName, o.requestCardName)
			rowUI.cancelBtn:SetAttribute("offerId", o.id)
		else
			rowUI.row.Visible = false
		end
	end

	local friends = data.friends or {}
	panel.friendsEmptyLbl.Visible = #friends == 0
	for i, rowUI in ipairs(friendRows) do
		local e = friends[i]
		if e then
			rowUI.row.Visible = true
			rowUI.nameLbl.Text = e.name
			rowUI.giftBtn:SetAttribute("userId", e.userId)
		else
			rowUI.row.Visible = false
		end
	end
end

function SocialUI:Show()
	panel.root.Visible = true
end

function SocialUI:Hide()
	panel.root.Visible = false
end

function SocialUI:GetPanel()
	return panel.root
end

return SocialUI
