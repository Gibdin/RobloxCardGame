-- PackOpeningUI — premium pack rip experience.
-- Blur, ambient particles, idle float+tilt, color streaks.
-- No white flash; all effects are color-bloom based.
--
-- Layout:
--   BackgroundBlurLayer  full-screen dark tint during rip (ZIndex 8)
--   PacksDropdown        LEFT edge side drawer             (ZIndex 2)
--   PackRipFrame         CENTER rip sequence               (ZIndex 10)
--   UtilityPanel         RIGHT side, AUTO icon button      (ZIndex 55, dynamic)
--   TopBar               BOTTOM LEFT, economy placeholder  (ZIndex 2)

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local Lighting     = game:GetService("Lighting")

local PackOpeningUI = {}

local RIPS_REQUIRED = 3

local ripEvent  = Instance.new("BindableEvent")
local skipEvent = Instance.new("BindableEvent")

local packScrollFrame, packRipFrame, tearBar
local packDropdownFrame
local togglePacksDrawer
local packDrawerOpen = false
local autoRollBtn, autoRollPanel, autoRollStroke
local bgBlurLayer, ambientContainer
local vfxConfig, soundMgr
local openCallback, autoRollCallback
local blurEffect

local autoRollOn = false

-- Connection handles
local glowConn, floatConn, ambientConn
local activeGlow

-- Shared float+shake state (combined in one Heartbeat connection)
local packBasePos  = UDim2.new(0.5,-210,0.5,-260)
local shakeOffset  = Vector2.new(0,0)
local shaking      = false
local shakeIntens  = 0
local shakeDur     = 0
local shakeElapsed = 0

-- ── UI helpers ────────────────────────────────────────────────────────────────

local function label(parent, text, size, pos, color, font)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos; l.BackgroundTransparency = 1
	l.Text = text; l.TextColor3 = color or Color3.new(1,1,1)
	l.TextScaled = true; l.Font = font or Enum.Font.GothamBold; l.Parent = parent
	return l
end

local function button(parent, text, size, pos, bg, fg)
	local b = Instance.new("TextButton")
	b.Size = size; b.Position = pos; b.BackgroundColor3 = bg or Color3.fromRGB(60,60,60)
	b.BorderSizePixel = 0; b.Text = text; b.TextColor3 = fg or Color3.new(1,1,1)
	b.TextScaled = true; b.Font = Enum.Font.GothamBold; b.Parent = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = b
	return b
end

local function roundFrame(parent, size, pos, bg, zIdx)
	local f = Instance.new("Frame")
	f.Size = size; f.Position = pos; f.BackgroundColor3 = bg or Color3.fromRGB(25,25,40)
	f.BorderSizePixel = 0; f.ZIndex = zIdx or 1; f.Parent = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,12); c.Parent = f
	return f
end

-- ── Build sections ────────────────────────────────────────────────────────────

-- LEFT EDGE: pack drawer — toggled by SideMenu MY PACKS button, no built-in tab.
-- SideMenu occupies x=6..136; drawer starts at x=144 with an 8px gap.
local function buildPacksDropdown(gui)
	local PANEL_W = 264
	local HEIGHT  = 460

	local container = Instance.new("Frame")
	container.Name              = "PacksDropdown"
	container.Size              = UDim2.new(0, 0, 0, HEIGHT)
	container.Position          = UDim2.new(0, 144, 0.5, -HEIGHT/2)
	container.BackgroundTransparency = 1
	container.ClipsDescendants  = true
	container.ZIndex            = 2
	container.Parent            = gui

	local panel = Instance.new("Frame")
	panel.Name              = "DrawerPanel"
	panel.Size              = UDim2.new(0, PANEL_W, 1, 0)
	panel.Position          = UDim2.new(0, 0, 0, 0)
	panel.BackgroundColor3  = Color3.fromRGB(14, 14, 24)
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel   = 0
	panel.ZIndex            = 3
	panel.Parent            = container
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0,8); pc.Parent = panel

	local hdr = Instance.new("TextLabel")
	hdr.Size              = UDim2.new(1,-14,0,38)
	hdr.Position          = UDim2.new(0,10,0,5)
	hdr.BackgroundTransparency = 1
	hdr.Text              = "My Packs"
	hdr.TextColor3        = Color3.fromRGB(130,130,170)
	hdr.TextXAlignment    = Enum.TextXAlignment.Left
	hdr.TextScaled        = true
	hdr.Font              = Enum.Font.GothamBold
	hdr.ZIndex            = 4
	hdr.Parent            = panel

	local div = Instance.new("Frame")
	div.Size = UDim2.new(1,0,0,1); div.Position = UDim2.new(0,0,0,46)
	div.BackgroundColor3 = Color3.fromRGB(36,36,54); div.BorderSizePixel = 0
	div.ZIndex = 4; div.Parent = panel

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name              = "PackList"
	scroll.Size              = UDim2.new(1,-8,1,-52)
	scroll.Position          = UDim2.new(0,4,0,50)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel   = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Color3.fromRGB(60,60,90)
	scroll.CanvasSize        = UDim2.new(0,0,0,0)
	scroll.Parent            = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.Name
	layout.Padding   = UDim.new(0,4)
	layout.Parent    = scroll

	packScrollFrame   = scroll
	packDropdownFrame = container

	local open = false
	togglePacksDrawer = function()
		open = not open
		packDrawerOpen = open
		TweenService:Create(container,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, open and PANEL_W or 0, 0, HEIGHT)
		}):Play()
	end
end

-- CENTER: pack rip frame + support layers
local function buildPackRip(gui)
	local overlay = Instance.new("Frame"); overlay.Name = "BackgroundBlurLayer"
	overlay.Size = UDim2.new(1,0,1,0); overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
	overlay.BackgroundTransparency = 1; overlay.ZIndex = 8; overlay.Visible = false
	overlay.BorderSizePixel = 0; overlay.Parent = gui
	bgBlurLayer = overlay

	local ambient = Instance.new("Frame"); ambient.Name = "AmbientContainer"
	ambient.Size = UDim2.new(1,0,1,0); ambient.BackgroundTransparency = 1
	ambient.ZIndex = 9; ambient.Visible = false; ambient.BorderSizePixel = 0
	ambient.ClipsDescendants = false; ambient.Parent = gui
	ambientContainer = ambient

	local frame = roundFrame(gui,
		UDim2.new(0,420,0,520), packBasePos,
		Color3.fromRGB(12,12,22), 10)
	frame.Name = "PackRipFrame"; frame.Visible = false; frame.ClipsDescendants = false

	local art = roundFrame(frame,
		UDim2.new(0,240,0,300), UDim2.new(0.5,-120,0,26),
		Color3.fromRGB(40,50,90), 11)
	art.Name = "PackArt"; art.ClipsDescendants = false
	label(art, "PACK", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(180,190,255))

	local barBg = Instance.new("Frame"); barBg.Size = UDim2.new(0.8,0,0,18)
	barBg.Position = UDim2.new(0.1,0,0,344); barBg.BackgroundColor3 = Color3.fromRGB(30,30,50)
	barBg.BorderSizePixel = 0; barBg.ZIndex = 11; barBg.Parent = frame
	local bbc = Instance.new("UICorner"); bbc.CornerRadius = UDim.new(1,0); bbc.Parent = barBg
	local fill = Instance.new("Frame"); fill.Name = "Fill"; fill.Size = UDim2.new(0,0,1,0)
	fill.BackgroundColor3 = Color3.fromRGB(80,200,100); fill.BorderSizePixel = 0
	fill.ZIndex = 12; fill.Parent = barBg
	local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1,0); fc.Parent = fill
	tearBar = fill

	label(frame, "Click the pack 3 times to rip it open!",
		UDim2.new(0.9,0,0,26), UDim2.new(0.05,0,0,370),
		Color3.fromRGB(140,140,170))

	local skipBtn = button(frame, "Skip",
		UDim2.new(0,110,0,38), UDim2.new(0.5,-55,1,-54),
		Color3.fromRGB(55,58,80))
	skipBtn.MouseEnter:Connect(function() TweenService:Create(skipBtn, TweenInfo.new(0.10), {BackgroundColor3=Color3.fromRGB(72,76,100)}):Play() end)
	skipBtn.MouseLeave:Connect(function() TweenService:Create(skipBtn, TweenInfo.new(0.10), {BackgroundColor3=Color3.fromRGB(55,58,80)}):Play() end)
	skipBtn.MouseButton1Click:Connect(function() skipEvent:Fire() end)

	local clickArea = Instance.new("TextButton"); clickArea.Size = UDim2.new(1,0,1,0)
	clickArea.BackgroundTransparency = 1; clickArea.Text = ""
	clickArea.ZIndex = 15; clickArea.Parent = art
	clickArea.MouseButton1Click:Connect(function() ripEvent:Fire() end)

	packRipFrame = frame
end

-- RIGHT: icon-only AUTO circle — hidden when idle, animates in/out during sequence
local function buildUtilityPanel(gui)
	local container = Instance.new("Frame")
	container.Name              = "UtilityPanel"
	container.Size              = UDim2.new(0, 48, 0, 48)
	container.Position          = UDim2.new(1, 0, 0.5, -24)
	container.BackgroundTransparency = 1
	container.ZIndex            = 55
	container.Visible           = false
	container.Parent            = gui

	local arBtn = Instance.new("TextButton")
	arBtn.Size             = UDim2.new(1,0,1,0)
	arBtn.BackgroundColor3 = Color3.fromRGB(40,40,70)
	arBtn.BorderSizePixel  = 0
	arBtn.Text             = "AUTO"
	arBtn.TextSize         = 10
	arBtn.Font             = Enum.Font.GothamBold
	arBtn.TextColor3       = Color3.fromRGB(140,180,255)
	arBtn.ZIndex           = 56
	arBtn.Parent           = container
	local arc = Instance.new("UICorner"); arc.CornerRadius = UDim.new(0.5,0); arc.Parent = arBtn
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2; stroke.Color = Color3.fromRGB(70,70,110); stroke.Parent = arBtn

	arBtn.MouseEnter:Connect(function()
		local bg = autoRollOn and Color3.fromRGB(40,150,40) or Color3.fromRGB(55,55,90)
		TweenService:Create(arBtn, TweenInfo.new(0.12), {BackgroundColor3=bg}):Play()
	end)
	arBtn.MouseLeave:Connect(function()
		local bg = autoRollOn and Color3.fromRGB(30,120,30) or Color3.fromRGB(40,40,70)
		TweenService:Create(arBtn, TweenInfo.new(0.12), {BackgroundColor3=bg}):Play()
	end)
	arBtn.MouseButton1Click:Connect(function()
		autoRollOn = not autoRollOn
		arBtn.BackgroundColor3 = autoRollOn
			and Color3.fromRGB(30,120,30) or Color3.fromRGB(40,40,70)
		stroke.Color = autoRollOn
			and Color3.fromRGB(40,180,40) or Color3.fromRGB(70,70,110)
		if autoRollCallback then autoRollCallback(autoRollOn) end
	end)

	autoRollBtn    = arBtn
	autoRollStroke = stroke
	autoRollPanel  = container
end

-- BOTTOM LEFT: economy placeholder — compact, low visual priority
local function buildTopBar(gui)
	local bar = roundFrame(gui,
		UDim2.new(0,160,0,34), UDim2.new(0,10,1,-44),
		Color3.fromRGB(12,12,20), 2)
	bar.Name = "TopBar"
	label(bar, "Economy", UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
		Color3.fromRGB(55,55,75))
end

-- ── Blur ──────────────────────────────────────────────────────────────────────

local function enableBlur()
	if not blurEffect then
		blurEffect = Instance.new("BlurEffect")
		blurEffect.Size = 0; blurEffect.Parent = Lighting
	end
	TweenService:Create(blurEffect, TweenInfo.new(vfxConfig.Entrance.blurFadeTime), {
		Size = vfxConfig.Entrance.blurSize
	}):Play()
end

local function disableBlur()
	if blurEffect then
		local b = blurEffect; blurEffect = nil
		TweenService:Create(b, TweenInfo.new(0.38), {Size = 0}):Play()
		task.delay(0.45, function() if b and b.Parent then b:Destroy() end end)
	end
end

-- ── Ambient particles ─────────────────────────────────────────────────────────

local WISP_COLORS = {
	Color3.fromRGB(200, 175, 255), Color3.fromRGB(145, 215, 255),
	Color3.fromRGB(255, 215, 130), Color3.fromRGB(175, 255, 200),
	Color3.fromRGB(255, 175, 205),
}

local function spawnAmbientParticle()
	local cfg  = vfxConfig.Ambient
	local sz   = math.random(cfg.minSize, cfg.maxSize)
	local dur  = cfg.minLife + math.random() * (cfg.maxLife - cfg.minLife)
	local col  = WISP_COLORS[math.random(1, #WISP_COLORS)]
	local sx   = math.random(5, 95) / 100
	local sy   = math.random(65, 95) / 100
	local p = Instance.new("Frame"); p.Name = "Wisp"
	p.Size = UDim2.new(0,sz,0,sz); p.Position = UDim2.new(sx,-sz/2,sy,-sz/2)
	p.BackgroundColor3 = col; p.BackgroundTransparency = 0.85
	p.BorderSizePixel = 0; p.ZIndex = 9; p.Parent = ambientContainer
	local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1,0); uc.Parent = p
	local drift = (math.random()-0.5) * 0.12
	TweenService:Create(p, TweenInfo.new(0.35), {BackgroundTransparency = 0.35}):Play()
	TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(sx+drift,-sz/2, sy-0.52,-sz/2),
	}):Play()
	task.delay(dur * 0.55, function()
		if p.Parent then TweenService:Create(p, TweenInfo.new(dur*0.45), {BackgroundTransparency=1}):Play() end
	end)
	task.delay(dur + 0.1, function() if p.Parent then p:Destroy() end end)
end

local lastAmbient = 0
local function startAmbientParticles()
	ambientContainer.Visible = true
	if ambientConn then ambientConn:Disconnect() end
	ambientConn = RunService.Heartbeat:Connect(function()
		local t = tick()
		if t - lastAmbient >= vfxConfig.Ambient.interval then
			lastAmbient = t; spawnAmbientParticle()
		end
	end)
end

local function stopAmbientParticles()
	if ambientConn then ambientConn:Disconnect(); ambientConn = nil end
	task.delay(2.0, function()
		if ambientContainer then
			for _, c in ipairs(ambientContainer:GetChildren()) do c:Destroy() end
			ambientContainer.Visible = false
		end
	end)
end

-- ── Float + Shake ─────────────────────────────────────────────────────────────

local function triggerShake(intensity, duration)
	shakeIntens = intensity; shakeDur = duration; shakeElapsed = 0; shaking = true
end

local function startIdleFloat()
	if floatConn then floatConn:Disconnect() end
	local cfg = vfxConfig.IdleFloat
	floatConn = RunService.Heartbeat:Connect(function(dt)
		if not packRipFrame or not packRipFrame.Visible then return end
		local t   = tick()
		local yOff = math.sin(t * cfg.yFrequency * math.pi * 2) * cfg.yAmplitude
		local rot  = math.sin(t * cfg.rotFrequency * math.pi * 2) * cfg.rotAmplitude
		if shaking then
			shakeElapsed = shakeElapsed + dt
			if shakeElapsed >= shakeDur then
				shaking = false; shakeOffset = Vector2.new(0,0)
			else
				local fade = 1 - shakeElapsed/shakeDur
				shakeOffset = Vector2.new(
					(math.random()-0.5)*2*shakeIntens*fade,
					(math.random()-0.5)*2*shakeIntens*fade)
			end
		end
		packRipFrame.Position = UDim2.new(
			packBasePos.X.Scale, packBasePos.X.Offset + shakeOffset.X,
			packBasePos.Y.Scale, packBasePos.Y.Offset + yOff + shakeOffset.Y)
		packRipFrame.Rotation = rot
	end)
end

local function stopIdleFloat()
	if floatConn then floatConn:Disconnect(); floatConn = nil end
	if packRipFrame then packRipFrame.Position = packBasePos; packRipFrame.Rotation = 0 end
end

-- ── Glow ──────────────────────────────────────────────────────────────────────

local function startEntryGlow()
	if activeGlow then activeGlow:Destroy() end
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100,160,255); stroke.Thickness = 5
	stroke.Parent = packRipFrame; activeGlow = stroke
	if glowConn then glowConn:Disconnect() end
	glowConn = RunService.Heartbeat:Connect(function()
		if not stroke.Parent then glowConn:Disconnect(); return end
		local alpha = (math.sin(tick() * vfxConfig.Entrance.glowPulseSpeed * math.pi) + 1) * 0.5
		stroke.Thickness = 3 + alpha * 9
		stroke.Color = Color3.fromHSV((tick() * 0.08) % 1, 0.65, 1)
	end)
end

local function stopEntryGlow()
	if glowConn then glowConn:Disconnect(); glowConn = nil end
	if activeGlow then activeGlow:Destroy(); activeGlow = nil end
end

-- ── Rip VFX ───────────────────────────────────────────────────────────────────

local STREAK_PALETTES = {
	{ Color3.fromRGB(255,220,100), Color3.fromRGB(255,185,55) },
	{ Color3.fromRGB(255,150,60),  Color3.fromRGB(240,100,30) },
	{ Color3.fromRGB(200,100,255), Color3.fromRGB(255,60,170) },
}

local function addColorStreaks(stage)
	local cols = STREAK_PALETTES[stage] or STREAK_PALETTES[1]
	local cfg  = vfxConfig.RipStages[stage]
	for _ = 1, cfg.streakCount do
		local horiz = math.random() > 0.5
		local w = horiz and math.random(55,170) or math.random(2,4)
		local h = horiz and math.random(2,4)    or math.random(55,170)
		local s = Instance.new("Frame")
		s.Size = UDim2.new(0,w,0,h); s.BackgroundColor3 = cols[math.random(1,#cols)]
		s.BackgroundTransparency = 0.05; s.BorderSizePixel = 0
		s.ZIndex = 14; s.Rotation = math.random(-35,35)
		s.Position = UDim2.new(math.random(10,80)/100,0,math.random(15,80)/100,0)
		s.Parent = packRipFrame.PackArt
		TweenService:Create(s, TweenInfo.new(0.32+stage*0.05), {
			BackgroundTransparency=1, Size=UDim2.new(0,w*1.6,0,h)
		}):Play()
		task.delay(0.45, function() if s.Parent then s:Destroy() end end)
	end
end

local function addTearMarks(stage)
	local cfg = vfxConfig.RipStages[stage]
	for i = 1, cfg.tearCount do
		local w = 58+stage*30+math.random(-8,8); local h = 2+stage
		local t = Instance.new("Frame")
		t.Size = UDim2.new(0,w,0,h); t.BackgroundColor3 = Color3.fromRGB(255,255,255)
		t.BackgroundTransparency = 0.25; t.BorderSizePixel = 0; t.Rotation = math.random(-55,55)
		local px = 0.15+(i/(stage+1))*0.70
		local py = 0.25+math.random(-14,14)/100+(stage-1)*0.18
		t.Position = UDim2.new(px,-w/2,py,-h/2); t.ZIndex = 14; t.Parent = packRipFrame.PackArt
		TweenService:Create(t, TweenInfo.new(0.38+stage*0.06), {
			BackgroundTransparency=1, Size=UDim2.new(0,w*1.5,0,h)
		}):Play()
		task.delay(0.5, function() if t.Parent then t:Destroy() end end)
	end
end

local function spawnSparks(count, stage, color)
	local col = color or Color3.fromRGB(255,215,80)
	for _ = 1, count do
		local sz = math.random(4,11); local p = Instance.new("Frame")
		p.Size = UDim2.new(0,sz,0,sz); p.Position = UDim2.new(0,210-sz/2,0,176-sz/2)
		p.BackgroundColor3 = col; p.BackgroundTransparency = 0
		p.BorderSizePixel = 0; p.ZIndex = 16; p.Parent = packRipFrame
		local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1,0); uc.Parent = p
		local ang = math.random()*math.pi*2; local dist = math.random(50,220)
		local dur = 0.35+math.random()*0.45
		TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position=UDim2.new(0,210+math.cos(ang)*dist-sz/2,0,176+math.sin(ang)*dist-sz/2),
			Size=UDim2.new(0,0,0,0), BackgroundTransparency=1,
		}):Play()
		task.delay(dur+0.1, function() if p.Parent then p:Destroy() end end)
	end
end

local function colorBloom(parent, color, startSize, maxSize, dur)
	local bloom = Instance.new("Frame"); bloom.Name = "Bloom"
	bloom.AnchorPoint = Vector2.new(0.5,0.5)
	bloom.Size = UDim2.new(0,startSize,0,startSize); bloom.Position = UDim2.new(0.5,0,0.45,0)
	bloom.BackgroundColor3 = color; bloom.BackgroundTransparency = 0.45
	bloom.BorderSizePixel = 0; bloom.ZIndex = 18; bloom.Parent = parent
	local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1,0); uc.Parent = bloom
	TweenService:Create(bloom, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size=UDim2.new(0,maxSize,0,maxSize), BackgroundTransparency=1,
	}):Play()
	task.delay(dur+0.05, function() if bloom.Parent then bloom:Destroy() end end)
end

local function finalBurstVFX()
	soundMgr:Play("pack_burst"); spawnSparks(36,3)
	task.delay(0.07, function() spawnSparks(20,2) end)
	colorBloom(packRipFrame, Color3.fromRGB(170,195,255), 20, 580, 0.60)
end

local function doRipVFX(stage)
	local cfg = vfxConfig.RipStages[stage]; soundMgr:Play("rip_click_"..stage)
	triggerShake(cfg.shakeIntensity, cfg.shakeDuration)
	addTearMarks(stage); addColorStreaks(stage); spawnSparks(cfg.sparkCount, stage)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function PackOpeningUI:Init(gui, _rc, vfx, snd)
	vfxConfig = vfx; soundMgr = snd
	buildPacksDropdown(gui)
	buildPackRip(gui)
	buildUtilityPanel(gui)
	buildTopBar(gui)
end

function PackOpeningUI:UpdatePackList(packs)
	for _, child in ipairs(packScrollFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local totalH = 0
	for packType, count in pairs(packs) do
		if count > 0 then
			local row = roundFrame(packScrollFrame,
				UDim2.new(1,-8,0,66), UDim2.new(0,4,0,0), Color3.fromRGB(32,32,48))
			row.Name = packType
			row.MouseEnter:Connect(function()
				TweenService:Create(row, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(40,40,58)}):Play()
			end)
			row.MouseLeave:Connect(function()
				TweenService:Create(row, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(32,32,48)}):Play()
			end)
			label(row, packType,   UDim2.new(1,-104,0,28), UDim2.new(0,10,0,6))
			label(row, "x"..count, UDim2.new(0,60,0,22),   UDim2.new(0,10,0,36), Color3.fromRGB(200,200,80))
			local openBtn = button(row, "Open",
				UDim2.new(0,84,0,38), UDim2.new(1,-94,0.5,-19), Color3.fromRGB(60,140,70))
			openBtn.MouseEnter:Connect(function()
				TweenService:Create(openBtn, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(80,170,90)}):Play()
			end)
			openBtn.MouseLeave:Connect(function()
				TweenService:Create(openBtn, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(60,140,70)}):Play()
			end)
			local captured = packType
			openBtn.MouseButton1Click:Connect(function()
				if openCallback then openCallback(captured) end
			end)
			totalH = totalH + 72
		end
	end
	packScrollFrame.CanvasSize = UDim2.new(0,0,0,totalH)
end

function PackOpeningUI:ShowPackRip(_packType)
	local rips = 0; local skipped = false
	tearBar.Size = UDim2.new(0,0,1,0); shaking = false; shakeOffset = Vector2.new(0,0)
	bgBlurLayer.Visible = true
	TweenService:Create(bgBlurLayer, TweenInfo.new(0.38), {BackgroundTransparency=0.58}):Play()
	enableBlur(); startAmbientParticles()
	packRipFrame.Size = UDim2.new(0,0,0,0); packRipFrame.Position = UDim2.new(0.5,0,0.5,0)
	packRipFrame.Rotation = 0; packRipFrame.Visible = true
	soundMgr:Play("pack_select")
	TweenService:Create(packRipFrame,
		TweenInfo.new(vfxConfig.Entrance.duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0,420,0,520), Position = packBasePos,
	}):Play()
	task.wait(vfxConfig.Entrance.duration)
	startIdleFloat(); startEntryGlow()
	local ripConn = ripEvent.Event:Connect(function()
		if rips >= RIPS_REQUIRED then return end
		rips = rips + 1
		TweenService:Create(tearBar, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			Size = UDim2.new(math.min(rips/RIPS_REQUIRED,1),0,1,0)
		}):Play()
		if rips < RIPS_REQUIRED then doRipVFX(rips) else doRipVFX(3); finalBurstVFX() end
	end)
	local skipConn = skipEvent.Event:Connect(function() skipped = true end)
	while rips < RIPS_REQUIRED and not skipped do task.wait(0.03) end
	ripConn:Disconnect(); skipConn:Disconnect(); stopEntryGlow()
	return skipped
end

function PackOpeningUI:HidePackRip()
	stopIdleFloat(); stopEntryGlow(); stopAmbientParticles(); disableBlur()
	TweenService:Create(bgBlurLayer, TweenInfo.new(0.28), {BackgroundTransparency=1}):Play()
	TweenService:Create(packRipFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Size=UDim2.new(0,0,0,0), Position=UDim2.new(0.5,0,0.5,0)}):Play()
	task.delay(0.22, function()
		if packRipFrame then packRipFrame.Visible=false; packRipFrame.Rotation=0 end
		if bgBlurLayer  then bgBlurLayer.Visible=false end
	end)
end

function PackOpeningUI:SetOpenCallback(cb)     openCallback     = cb end
function PackOpeningUI:SetAutoRollCallback(cb) autoRollCallback = cb end

function PackOpeningUI:ShowAutoRollButton()
	if not autoRollPanel then return end
	autoRollPanel.Position = UDim2.new(1, 0, 0.5, -24)
	autoRollPanel.Visible  = true
	TweenService:Create(autoRollPanel,
		TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -58, 0.5, -24)
	}):Play()
end

function PackOpeningUI:HideAutoRollButton()
	if not autoRollPanel then return end
	autoRollOn = false
	if autoRollBtn    then autoRollBtn.BackgroundColor3 = Color3.fromRGB(40,40,70) end
	if autoRollStroke then autoRollStroke.Color         = Color3.fromRGB(70,70,110) end
	TweenService:Create(autoRollPanel,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1, 0, 0.5, -24)
	}):Play()
	task.delay(0.18, function() if autoRollPanel then autoRollPanel.Visible = false end end)
end

function PackOpeningUI:TogglePacksDrawer()
	if togglePacksDrawer then togglePacksDrawer() end
end

function PackOpeningUI:ClosePacksDrawer()
	if packDrawerOpen and togglePacksDrawer then togglePacksDrawer() end
end

return PackOpeningUI
