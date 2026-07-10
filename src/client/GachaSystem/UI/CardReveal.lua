-- CardReveal — premium card reveal. Layout: NEW! → art → rarity → name.
-- No stats. VFX: large aura, rotating dot ring, orbital particles, idle hover.
-- No harsh flashes; all effects use soft color blooms and smooth tweens.

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local CardReveal = {}

local rarityConfig, vfxConfig, soundMgr
local revealBg, auraFrame, ringContainer, panel, continuePrompt
local dismissSignal = Instance.new("BindableEvent")
local glowStroke
local activeConns = {}

-- Shared orbital particle state (one connection for all particles)
local orbitData = {}   -- { frame, speed, phase, radius, sz, scaleX }
local orbitConn

-- ── Build ─────────────────────────────────────────────────────────────────────

local function lbl(parent, size, pos, color, font)
	local l = Instance.new("TextLabel")
	l.Size = size; l.Position = pos; l.BackgroundTransparency = 1
	l.Text = ""; l.TextColor3 = color or Color3.new(1,1,1)
	l.TextScaled = true; l.Font = font or Enum.Font.GothamBold; l.Parent = parent
	return l
end

local function buildUI(gui)
	-- Full-screen dark background
	local bg = Instance.new("Frame"); bg.Name = "RevealStage"
	bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
	bg.BackgroundTransparency = 0.45; bg.ZIndex = 40; bg.Visible = false; bg.Parent = gui
	revealBg = bg

	-- Large soft aura (ellipse shape, behind everything)
	local aura = Instance.new("Frame"); aura.Name = "RarityAura"
	aura.AnchorPoint = Vector2.new(0.5,0.5)
	aura.Size = UDim2.new(0,500,0,680); aura.Position = UDim2.new(0.5,0,0.5,0)
	aura.BackgroundColor3 = Color3.new(1,1,1); aura.BackgroundTransparency = 1
	aura.ZIndex = 41; aura.BorderSizePixel = 0; aura.Parent = bg
	local auC = Instance.new("UICorner"); auC.CornerRadius = UDim.new(0.5,0); auC.Parent = aura
	auraFrame = aura

	-- Rotating dot ring container (sits between aura and card)
	local ring = Instance.new("Frame"); ring.Name = "RingContainer"
	ring.AnchorPoint = Vector2.new(0.5,0.5)
	ring.Size = UDim2.new(0,400,0,540); ring.Position = UDim2.new(0.5,0,0.5,0)
	ring.BackgroundTransparency = 1; ring.ZIndex = 42; ring.BorderSizePixel = 0; ring.Parent = bg
	ringContainer = ring

	-- Card panel — tall card aspect ratio, AnchorPoint centered for slam anim
	local p = Instance.new("Frame"); p.Name = "RevealPanel"
	p.AnchorPoint = Vector2.new(0.5,0.5)
	p.Size = UDim2.new(0,280,0,460); p.Position = UDim2.new(0.5,0,0.5,0)
	p.BackgroundColor3 = Color3.fromRGB(12,12,22); p.BorderSizePixel = 0
	p.ZIndex = 43; p.Parent = bg
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0,18); pc.Parent = p

	-- Rarity top bar
	local rarBar = Instance.new("Frame"); rarBar.Name = "RarBar"
	rarBar.Size = UDim2.new(1,0,0,10); rarBar.BackgroundColor3 = Color3.new(1,1,1)
	rarBar.BorderSizePixel = 0; rarBar.ZIndex = 44; rarBar.Parent = p
	local rbc = Instance.new("UICorner"); rbc.CornerRadius = UDim.new(0,18); rbc.Parent = rarBar

	-- NEW! badge (top-right corner of the card)
	local badge = Instance.new("Frame"); badge.Name = "NewBadge"
	badge.Size = UDim2.new(0,68,0,26); badge.Position = UDim2.new(1,-76,0,16)
	badge.BackgroundColor3 = Color3.fromRGB(45,210,75); badge.BorderSizePixel = 0
	badge.ZIndex = 46; badge.Visible = false; badge.Parent = p
	local nbc = Instance.new("UICorner"); nbc.CornerRadius = UDim.new(0,8); nbc.Parent = badge
	local newLbl = Instance.new("TextLabel")
	newLbl.Size = UDim2.new(1,0,1,0); newLbl.BackgroundTransparency = 1
	newLbl.Text = "NEW!"; newLbl.TextColor3 = Color3.new(1,1,1)
	newLbl.Font = Enum.Font.GothamBlack; newLbl.TextScaled = true
	newLbl.ZIndex = 47; newLbl.Parent = badge

	-- Large art frame (takes most of the card height)
	local art = Instance.new("Frame"); art.Name = "ArtFrame"
	art.Size = UDim2.new(0.90,0,0,232); art.Position = UDim2.new(0.05,0,0,18)
	art.BackgroundColor3 = Color3.fromRGB(26,26,44); art.BorderSizePixel = 0
	art.ZIndex = 44; art.Parent = p
	local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0,12); ac.Parent = art
	local artHint = Instance.new("TextLabel")
	artHint.Size = UDim2.new(1,0,1,0); artHint.BackgroundTransparency = 1
	artHint.Text = "ART"; artHint.TextColor3 = Color3.fromRGB(50,50,75)
	artHint.Font = Enum.Font.GothamBlack; artHint.TextScaled = true
	artHint.ZIndex = 45; artHint.Parent = art

	-- Rarity label (colored, below art)
	local rarLbl = lbl(p, UDim2.new(0.88,0,0,32), UDim2.new(0.06,0,0,262), Color3.fromRGB(200,180,100))
	rarLbl.Name = "RarityLabel"; rarLbl.ZIndex = 44; rarLbl.Font = Enum.Font.GothamBold

	-- Card name (large, prominent)
	local nameLbl = lbl(p, UDim2.new(0.88,0,0,50), UDim2.new(0.06,0,0,298), Color3.new(1,1,1), Enum.Font.GothamBlack)
	nameLbl.Name = "CardName"; nameLbl.ZIndex = 44

	panel = p

	-- ContinuePrompt: full-screen transparent click area with hint text at bottom center.
	-- Shown by WaitForDismiss(); hidden again once the player clicks.
	local prompt = Instance.new("TextButton"); prompt.Name = "ContinuePrompt"
	prompt.Size = UDim2.new(1,0,1,0); prompt.BackgroundTransparency = 1
	prompt.Text = ""; prompt.ZIndex = 51; prompt.Visible = false; prompt.Parent = bg
	local promptLbl = Instance.new("TextLabel")
	promptLbl.Size = UDim2.new(0.46,0,0,36); promptLbl.Position = UDim2.new(0.27,0,1,-58)
	promptLbl.BackgroundTransparency = 1; promptLbl.Text = "Click anywhere to continue"
	promptLbl.TextColor3 = Color3.fromRGB(170,170,200); promptLbl.Font = Enum.Font.GothamBold
	promptLbl.TextScaled = true; promptLbl.ZIndex = 52; promptLbl.Parent = prompt
	prompt.MouseButton1Click:Connect(function() dismissSignal:Fire() end)
	continuePrompt = prompt
end

-- ── Connection management ─────────────────────────────────────────────────────

local function disconnectAll()
	for _, c in ipairs(activeConns) do pcall(function() c:Disconnect() end) end
	activeConns = {}
	if orbitConn then pcall(function() orbitConn:Disconnect() end); orbitConn = nil end
end

local function trackConn(c) table.insert(activeConns, c) end

-- ── Effects ───────────────────────────────────────────────────────────────────

local function cameraShake(intensity, duration)
	local camera = workspace.CurrentCamera; if not camera then return end
	local elapsed = 0; local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed = elapsed + dt
		if elapsed >= duration then conn:Disconnect(); return end
		local fade = 1 - elapsed/duration
		camera.CFrame = camera.CFrame * CFrame.new(
			(math.random()-0.5)*2*intensity*fade,
			(math.random()-0.5)*2*intensity*fade, 0)
	end)
	trackConn(conn)
end

-- Pulsing UIStroke glow on the card panel
local function startGlowPulse(color)
	if glowStroke then glowStroke:Destroy() end
	glowStroke = Instance.new("UIStroke")
	glowStroke.Color = color; glowStroke.Thickness = 4; glowStroke.Parent = panel
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not glowStroke or not glowStroke.Parent then conn:Disconnect(); return end
		local alpha = (math.sin(tick()*3.2*math.pi)+1)*0.5
		glowStroke.Thickness = 3 + alpha*9
	end)
	trackConn(conn)
end

-- Idle hover: gentle sine-wave Y offset on the card panel
local function startIdleHover()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not panel or not panel.Parent then conn:Disconnect(); return end
		local yOff = math.sin(tick()*1.5) * 4
		panel.Position = UDim2.new(0.5,0, 0.5, yOff)
	end)
	trackConn(conn)
end

-- Build and spin a dot ring around the card
local function buildAndSpinRing(color)
	for _, c in ipairs(ringContainer:GetChildren()) do c:Destroy() end
	local cfg  = vfxConfig.Ring
	local rw   = ringContainer.Size.X.Offset * 0.5  -- horizontal radius
	local rh   = ringContainer.Size.Y.Offset * 0.5  -- vertical radius

	for i = 1, cfg.dotCount do
		local angle = ((i-1)/cfg.dotCount) * math.pi * 2
		local sz = cfg.dotSize + (i % 3 == 0 and 5 or 0)
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5,0.5)
		dot.Size = UDim2.new(0,sz,0,sz)
		dot.Position = UDim2.new(0.5, math.cos(angle)*rw, 0.5, math.sin(angle)*rh)
		dot.BackgroundColor3 = color; dot.BackgroundTransparency = 0.20
		dot.BorderSizePixel = 0; dot.ZIndex = 42; dot.Parent = ringContainer
		local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1,0); uc.Parent = dot
	end

	ringContainer.Rotation = 0; ringContainer.Visible = true
	local speed = vfxConfig.Ring.speed
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not ringContainer.Parent then conn:Disconnect(); return end
		ringContainer.Rotation = ringContainer.Rotation + speed
	end)
	trackConn(conn)
end

-- Burst particles from screen center outward
local function spawnBurstParticles(count, color)
	for _ = 1, count do
		local sz  = math.random(5,15); local dur = 0.5+math.random()*0.6
		local ang = math.random()*math.pi*2; local dist = math.random(110,360)
		local p = Instance.new("Frame"); p.Name = "BurstPtcl"
		p.Size = UDim2.new(0,sz,0,sz); p.Position = UDim2.new(0.5,-sz/2,0.5,-sz/2)
		p.BackgroundColor3 = color; p.BackgroundTransparency = 0.10
		p.BorderSizePixel = 0; p.ZIndex = 50; p.Parent = revealBg
		local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1,0); uc.Parent = p
		local tx = 0.5+math.cos(ang)*dist/900; local ty = 0.5+math.sin(ang)*dist/650
		TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(tx,-sz/2, ty,-sz/2),
			Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1,
		}):Play()
		task.delay(dur+0.1, function() if p.Parent then p:Destroy() end end)
	end
end

-- Orbital particles: continuously orbit the card (single Heartbeat for all)
local function spawnOrbitalParticles(count, color)
	-- Clean up old ones
	for _, data in ipairs(orbitData) do
		if data.frame and data.frame.Parent then data.frame:Destroy() end
	end
	orbitData = {}

	local baseRadius = 175
	for i = 1, count do
		local sz     = math.random(4,9)
		local speed  = (0.7+math.random()*0.9) * (math.random()>0.5 and 1 or -1)
		local phase  = (i/count)*math.pi*2
		local radius = baseRadius + math.random(-22,22)
		local scaleX = 1.0 + math.random()*0.28  -- slight horizontal stretch = ellipse orbit
		local p = Instance.new("Frame"); p.Name = "OrbPtcl"
		p.AnchorPoint = Vector2.new(0.5,0.5)
		p.Size = UDim2.new(0,sz,0,sz); p.Position = UDim2.new(0.5,0,0.5,0)
		p.BackgroundColor3 = color; p.BackgroundTransparency = 0.25
		p.BorderSizePixel = 0; p.ZIndex = 42; p.Parent = revealBg
		local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(1,0); uc.Parent = p
		table.insert(orbitData, {frame=p, speed=speed, phase=phase, radius=radius, sz=sz, scaleX=scaleX})
	end

	if orbitConn then pcall(function() orbitConn:Disconnect() end) end
	orbitConn = RunService.Heartbeat:Connect(function()
		local t = tick()
		for _, d in ipairs(orbitData) do
			if not d.frame.Parent then return end
			local angle = t*d.speed + d.phase
			d.frame.Position = UDim2.new(0.5, math.cos(angle)*d.radius*d.scaleX,
			                              0.5, math.sin(angle)*d.radius)
		end
	end)
end

-- ── specialFX handlers ────────────────────────────────────────────────────────

-- Expanding ring burst (used by pulse/explosion/burst)
local function burstRing(color, duration)
	local ring = Instance.new("Frame"); ring.Name = "BurstRing"
	ring.AnchorPoint = Vector2.new(0.5,0.5)
	ring.Size = UDim2.new(0,40,0,40); ring.Position = UDim2.new(0.5,0,0.5,0)
	ring.BackgroundTransparency = 1; ring.ZIndex = 48; ring.BorderSizePixel = 0; ring.Parent = revealBg
	local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = 6; s.Parent = ring
	local rc2 = Instance.new("UICorner"); rc2.CornerRadius = UDim.new(1,0); rc2.Parent = ring
	TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0,750,0,900), Position = UDim2.new(0.5,0,0.5,0)
	}):Play()
	TweenService:Create(s, TweenInfo.new(duration), {Thickness = 0}):Play()
	task.delay(duration+0.05, function() if ring.Parent then ring:Destroy() end end)
end

local specialFXHandlers = {}

-- Epic: single ring + panel scale pulse
function specialFXHandlers.pulse(color)
	burstRing(color, 0.60)
	-- Gentle scale pop
	TweenService:Create(panel, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0,298,0,490),
	}):Play()
	task.delay(0.14, function()
		TweenService:Create(panel, TweenInfo.new(0.14), {Size = UDim2.new(0,280,0,460)}):Play()
	end)
end

-- Legendary: three cascading rings
function specialFXHandlers.explosion(color)
	for i = 1, 3 do
		task.delay((i-1)*0.13, function() burstRing(color, 0.75) end)
	end
end

-- Mythic: four rings + gentle background color breathe (no rapid flicker)
function specialFXHandlers.burst(color)
	for i = 1, 4 do
		task.delay((i-1)*0.10, function() burstRing(color, 0.70) end)
	end
	task.spawn(function()
		for _ = 1, 3 do
			TweenService:Create(revealBg, TweenInfo.new(0.35), {
				BackgroundColor3 = Color3.new(color.R*0.25, color.G*0.25, color.B*0.25)
			}):Play()
			task.wait(0.38)
			TweenService:Create(revealBg, TweenInfo.new(0.35), {
				BackgroundColor3 = Color3.fromRGB(0,0,0)
			}):Play()
			task.wait(0.38)
		end
	end)
end

-- God: five rainbow rings + continuous HSV aura + rainbow ring dots
function specialFXHandlers.rainbow()
	for i = 1, 5 do
		task.delay((i-1)*0.15, function()
			burstRing(Color3.fromHSV((i-1)/5, 1, 1), 1.0)
		end)
	end
	-- Cycle aura color
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not auraFrame or not auraFrame.Parent then conn:Disconnect(); return end
		local h = (tick()*0.28)%1
		auraFrame.BackgroundColor3 = Color3.fromHSV(h, 0.88, 1)
	end)
	trackConn(conn)
	-- Also cycle ring dot colors
	local conn2
	conn2 = RunService.Heartbeat:Connect(function()
		if not ringContainer or not ringContainer.Parent then conn2:Disconnect(); return end
		local h = (tick()*0.22)%1
		for j, dot in ipairs(ringContainer:GetChildren()) do
			if dot:IsA("Frame") then
				dot.BackgroundColor3 = Color3.fromHSV((h + j*0.08)%1, 0.90, 1)
			end
		end
	end)
	trackConn(conn2)
end

-- Secret: cinematic dark emergence (no chaotic effects)
function specialFXHandlers.secret(color)
	-- Slowly pulse the aura between dark and vivid
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not auraFrame or not auraFrame.Parent then conn:Disconnect(); return end
		local alpha = (math.sin(tick()*0.7)+1)*0.5
		auraFrame.BackgroundColor3 = Color3.new(
			color.R*alpha, color.G*alpha, color.B*alpha)
	end)
	trackConn(conn)
	-- Slow counter-rotate the ring for mystery
	local conn2
	conn2 = RunService.Heartbeat:Connect(function()
		if not ringContainer or not ringContainer.Parent then conn2:Disconnect(); return end
		ringContainer.Rotation = ringContainer.Rotation - 0.5
	end)
	trackConn(conn2)
end

-- ── Public ────────────────────────────────────────────────────────────────────

function CardReveal:Init(gui, rc, vfx, snd)
	rarityConfig = rc; vfxConfig = vfx; soundMgr = snd
	activeConns  = {}
	buildUI(gui)
end

function CardReveal:Show(result)
	local card   = result.card
	local rarity = result.rarity
	local rData  = rarityConfig.Rarities[rarity] or {}
	local cfg    = (vfxConfig.RarityReveal or {})[rarity] or {}
	local col    = rData.color or Color3.new(1,1,1)

	disconnectAll()

	-- Populate card (text hidden initially for staged reveal)
	panel.RarBar.BackgroundColor3         = col
	panel.RarityLabel.Text                = rarity
	panel.RarityLabel.TextColor3          = col
	panel.RarityLabel.TextTransparency    = 1
	panel.CardName.Text                   = card.name or "Unknown"
	panel.CardName.TextTransparency       = 1
	panel.NewBadge.Visible                = false
	panel.NewBadge.Size                   = UDim2.new(0,0,0,0)
	panel.NewBadge.Position               = UDim2.new(1,-40,0,16)

	-- Reset positions
	auraFrame.BackgroundColor3       = col
	auraFrame.BackgroundTransparency = 1
	ringContainer.Visible            = false
	panel.Size                       = UDim2.new(0,0,0,0)
	panel.Position                   = UDim2.new(0.5,0,0.5,0)
	revealBg.BackgroundColor3        = Color3.fromRGB(0,0,0)
	revealBg.BackgroundTransparency  = 0.45
	revealBg.Visible                 = true

	-- Dramatic pause: deep darkness builds anticipation
	local pause = cfg.dramaticPause or 0
	if pause > 0 then
		TweenService:Create(revealBg, TweenInfo.new(0.3), {BackgroundTransparency = 0.08}):Play()
		task.wait(pause)
		TweenService:Create(revealBg, TweenInfo.new(0.25), {BackgroundTransparency = 0.45}):Play()
		task.wait(0.28)
	end

	-- Sound
	soundMgr:Play(cfg.sound or "reveal_common")

	-- Slam in: scale from 0 with Back easing = natural bounce/impact
	TweenService:Create(panel, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0,280,0,460),
	}):Play()
	task.wait(0.28)

	-- Staged text reveal: rarity → name → NEW! badge
	TweenService:Create(panel.RarityLabel, TweenInfo.new(0.22), {TextTransparency = 0}):Play()
	task.delay(0.14, function()
		TweenService:Create(panel.CardName, TweenInfo.new(0.22), {TextTransparency = 0}):Play()
	end)
	if not result.isDuplicate then
		task.delay(0.28, function()
			panel.NewBadge.Visible = true
			TweenService:Create(panel.NewBadge,
				TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{Size = UDim2.new(0,68,0,26), Position = UDim2.new(1,-76,0,16)}):Play()
		end)
	end

	-- Camera shake (starts after impact)
	if (cfg.shakeIntensity or 0) > 0 then
		cameraShake(cfg.shakeIntensity * 0.04, 0.55)
	end

	-- Aura fade in (large soft glow behind card)
	if (cfg.auraAlpha or 0) > 0 then
		local scale   = cfg.auraScale or 1.0
		local auraW   = math.floor(500 * scale)
		local auraH   = math.floor(680 * scale)
		auraFrame.Size = UDim2.new(0,auraW,0,auraH)
		TweenService:Create(auraFrame, TweenInfo.new(0.40), {
			BackgroundTransparency = 1 - cfg.auraAlpha
		}):Play()
	end

	-- Burst particles flying outward from center
	if (cfg.particleCount or 0) > 0 then
		spawnBurstParticles(cfg.particleCount, col)
	end

	-- Rotating dot ring
	if (cfg.ringCount or 0) > 0 then
		buildAndSpinRing(col)
	end

	-- Orbital floating particles around card
	if (cfg.orbitCount or 0) > 0 then
		spawnOrbitalParticles(cfg.orbitCount, col)
	end

	-- Glow stroke on card
	startGlowPulse(rData.glowColor or col)

	-- Idle hover
	startIdleHover()

	-- specialFX (concurrent)
	local fx = cfg.specialFX
	if fx == "pulse"     then task.spawn(specialFXHandlers.pulse,     col)
	elseif fx == "explosion" then task.spawn(specialFXHandlers.explosion, col)
	elseif fx == "burst"     then task.spawn(specialFXHandlers.burst,     col)
	elseif fx == "rainbow"   then task.spawn(specialFXHandlers.rainbow)
	elseif fx == "secret"    then task.spawn(specialFXHandlers.secret,    col)
	end
end

function CardReveal:WaitForDismiss()
	if continuePrompt then
		local promptLbl = continuePrompt:FindFirstChildWhichIsA("TextLabel")
		continuePrompt.Visible = true
		if promptLbl then
			local t0 = tick()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not promptLbl.Parent then conn:Disconnect(); return end
				local elapsed = tick() - t0
				local fadeIn  = math.min(elapsed / 0.45, 1.0)
				local pulse   = (math.sin(elapsed * 2.6) + 1) * 0.5
				promptLbl.TextTransparency = (1 - fadeIn) + fadeIn * pulse * 0.38
			end)
			trackConn(conn)
		end
	end
	dismissSignal.Event:Wait()
	if continuePrompt then continuePrompt.Visible = false end
	disconnectAll()
	if glowStroke then glowStroke:Destroy(); glowStroke = nil end

	-- Fade out orbital particles
	for _, data in ipairs(orbitData) do
		if data.frame and data.frame.Parent then
			TweenService:Create(data.frame, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
			local f = data.frame
			task.delay(0.20, function() if f.Parent then f:Destroy() end end)
		end
	end
	orbitData = {}

	-- Clean up any remaining burst particles
	for _, c in ipairs(revealBg:GetChildren()) do
		if c.Name == "BurstPtcl" or c.Name == "BurstRing" then
			TweenService:Create(c, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play()
			local captured = c
			task.delay(0.18, function() if captured.Parent then captured:Destroy() end end)
		end
	end

	-- Slide everything out
	TweenService:Create(revealBg, TweenInfo.new(0.24), {BackgroundTransparency = 1}):Play()
	TweenService:Create(panel,    TweenInfo.new(0.20), {Size = UDim2.new(0,0,0,0)}):Play()
	TweenService:Create(auraFrame,TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
	ringContainer.Visible = false

	task.wait(0.26)
	revealBg.Visible             = false
	revealBg.BackgroundTransparency = 0.45
	revealBg.BackgroundColor3    = Color3.fromRGB(0,0,0)
end

function CardReveal:TriggerDismiss()
	dismissSignal:Fire()
end

return CardReveal
