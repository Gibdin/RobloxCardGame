-- SideMenuUI — permanent left-side quick-access navigation panel.
-- To add a future button (Quests, Events, etc.), append one entry to BUTTONS only.
-- No other changes required.

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")

local SideMenuUI = {}

local MENU_W  = 130
local BTN_H   = 60
local BTN_GAP = 10
local PAD     = 6
local STRIP_W = 5

-- Ordered button definitions. Add future entries here only.
local BUTTONS = {
	{ id="packs",     label="MY PACKS",  color=Color3.fromRGB(80, 130, 210) },
	{ id="inventory", label="INVENTORY", color=Color3.fromRGB(70, 180, 110) },
	{ id="team",      label="TEAM",      color=Color3.fromRGB(210, 140,  50) },
	{ id="battle",    label="BATTLE",    color=Color3.fromRGB(200,  70,  70) },
	{ id="arena",     label="ARENA",     color=Color3.fromRGB(255, 120, 120) },
	{ id="quests",    label="QUESTS",    color=Color3.fromRGB(120, 220, 160) },
	{ id="rankings",  label="RANKINGS",  color=Color3.fromRGB(255, 210,  90) },
	{ id="social",    label="SOCIAL",    color=Color3.fromRGB(100, 200, 220) },
	{ id="store",     label="STORE",     color=Color3.fromRGB(255, 200,  60) },
	{ id="settings",  label="SETTINGS",  color=Color3.fromRGB(100,  90, 170) },
}

-- Studio-only test shortcut; never appears on a published server.
if RunService:IsStudio() then
	table.insert(BUTTONS, { id="debug", label="DEBUG TEST", color=Color3.fromRGB(255, 200, 40) })
end

local handlers = {}
local activeBtn = nil
local activeLbl = nil
local DEFAULT_BG   = Color3.fromRGB(22, 22, 36)
local DEFAULT_TEXT = Color3.fromRGB(195, 195, 215)
local ACTIVE_BG    = Color3.fromRGB(40, 28, 64)
local ACTIVE_TEXT  = Color3.fromRGB(240, 240, 255)

local function clearActiveBtn()
	if activeBtn then TweenService:Create(activeBtn, TweenInfo.new(0.12), {BackgroundColor3=DEFAULT_BG}):Play() end
	if activeLbl then TweenService:Create(activeLbl, TweenInfo.new(0.12), {TextColor3=DEFAULT_TEXT}):Play() end
	activeBtn = nil; activeLbl = nil
end

local function makeButton(parent, def, order)
	local b = Instance.new("TextButton")
	b.Name              = def.id .. "Btn"
	b.Size              = UDim2.new(1, 0, 0, BTN_H)
	b.BackgroundColor3  = Color3.fromRGB(22, 22, 36)
	b.BackgroundTransparency = 0.05
	b.BorderSizePixel   = 0
	b.Text              = ""
	b.ZIndex            = 6
	b.AutoButtonColor   = false
	b.LayoutOrder       = order
	b.Parent            = parent
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = b

	-- Colored left accent strip — color identity without eating button width
	local strip = Instance.new("Frame")
	strip.Size             = UDim2.new(0, STRIP_W, 0.6, 0)
	strip.Position         = UDim2.new(0, 0, 0.2, 0)
	strip.BackgroundColor3 = def.color
	strip.BorderSizePixel  = 0
	strip.ZIndex           = 7
	strip.Parent           = b
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(1, 0); sc.Parent = strip

	-- Label fills the rest of the button — text as large as possible
	local lbl = Instance.new("TextLabel")
	lbl.Size             = UDim2.new(1, -(STRIP_W + 16), 1, -10)
	lbl.Position         = UDim2.new(0, STRIP_W + 8, 0, 5)
	lbl.BackgroundTransparency = 1
	lbl.Text             = def.label
	lbl.TextColor3       = Color3.fromRGB(195, 195, 215)
	lbl.TextScaled       = true
	lbl.TextWrapped      = false
	lbl.Font             = Enum.Font.GothamBold
	lbl.TextXAlignment   = Enum.TextXAlignment.Left
	lbl.ZIndex           = 7
	lbl.Parent           = b

	b.MouseEnter:Connect(function()
		TweenService:Create(b,   TweenInfo.new(0.10), {BackgroundColor3 = Color3.fromRGB(34, 34, 54)}):Play()
		TweenService:Create(lbl, TweenInfo.new(0.10), {TextColor3       = Color3.fromRGB(235, 235, 255)}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b,   TweenInfo.new(0.10), {BackgroundColor3 = Color3.fromRGB(22, 22, 36)}):Play()
		TweenService:Create(lbl, TweenInfo.new(0.10), {TextColor3       = Color3.fromRGB(195, 195, 215)}):Play()
	end)
	b.MouseButton1Click:Connect(function()
		-- Scale pulse feedback
		b.Size = UDim2.new(1, 0, 0, 54)
		TweenService:Create(b, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size=UDim2.new(1,0,0,BTN_H)}):Play()
		-- Active state toggle
		if activeBtn == b then
			clearActiveBtn()
		else
			clearActiveBtn()
			activeBtn = b; activeLbl = lbl
			TweenService:Create(b,   TweenInfo.new(0.12), {BackgroundColor3=ACTIVE_BG}):Play()
			TweenService:Create(lbl, TweenInfo.new(0.12), {TextColor3=ACTIVE_TEXT}):Play()
		end
		if handlers[def.id] then handlers[def.id]() end
	end)
end

function SideMenuUI:ClearActive()
	clearActiveBtn()
end

function SideMenuUI:Init(gui, callbacks)
	handlers = callbacks or {}
	local totalH = #BUTTONS * BTN_H + (#BUTTONS - 1) * BTN_GAP + PAD * 2

	-- The button list has grown across phases (5 -> 11 with Debug); on a
	-- shorter viewport, centering a fixed-height panel at 40% of screen
	-- height can push the TOP buttons (including Packs) above y=0 — entirely
	-- unreachable, not just visually clipped. Making the panel a
	-- ScrollingFrame with a viewport-clamped height fixes that regardless of
	-- screen size or how many buttons get added later, instead of re-tuning
	-- a magic percentage every time the list grows.
	local panel = Instance.new("ScrollingFrame")
	panel.Name              = "SideMenu"
	panel.Size              = UDim2.new(0, MENU_W, 0, totalH)
	-- 14px (not 6px) from the edge: a small safe-area margin against
	-- notches/rounded corners on mobile, which the game can't reliably query
	-- from Lua — a conservative fixed margin is the standard mitigation.
	panel.Position          = UDim2.new(0, 14, 0.40, -totalH/2)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel   = 0
	panel.ZIndex            = 5
	panel.ScrollBarThickness = 4
	panel.ScrollBarImageTransparency = 0.4
	panel.CanvasSize        = UDim2.new(0, 0, 0, totalH)
	panel.AutomaticCanvasSize = Enum.AutomaticSize.None
	panel.Parent            = gui

	local function fitToViewport()
		local viewportH = Workspace.CurrentCamera.ViewportSize.Y
		local margin = 20
		-- min/max instead of math.clamp: viewportH can legitimately be 0 or
		-- tiny for a frame or two while the camera is still initializing,
		-- which would make (viewportH - margin*2) negative and violate
		-- clamp's min<=max requirement.
		local visibleH = math.max(1, math.min(totalH, viewportH - margin * 2))
		local topY = math.max(margin, math.floor(viewportH * 0.40 - visibleH / 2))
		panel.Size = UDim2.new(0, MENU_W, 0, visibleH)
		panel.Position = UDim2.new(0, 14, 0, topY)
	end
	fitToViewport()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToViewport)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop    = UDim.new(0, PAD)
	padding.PaddingBottom = UDim.new(0, PAD)
	padding.PaddingLeft   = UDim.new(0, PAD)
	padding.PaddingRight  = UDim.new(0, PAD)
	padding.Parent        = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder           = Enum.SortOrder.LayoutOrder
	layout.Padding             = UDim.new(0, BTN_GAP)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent              = panel

	for i, def in ipairs(BUTTONS) do
		makeButton(panel, def, i)
	end
end

return SideMenuUI
