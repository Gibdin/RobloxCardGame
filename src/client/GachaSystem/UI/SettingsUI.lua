-- SettingsUI — compact settings panel: master volume, screen shake toggle,
-- low-HP warning toggle, UI scale, and credits. Replaces the old "Coming Soon"
-- stub. Pure view: all values are pushed in via Init/Refresh and changes are
-- reported through a single onChange(settings) callback — the caller decides
-- how to apply each setting (SoundManager, FxUtil, BattleUI, a UIScale
-- instance) and how/when to persist it.

local SettingsUI = {}

local panel
local rows = {}   -- [key] = { valueLbl = ..., get/set helpers }
local settings = { masterVolume = 1, screenShake = true, lowHpWarning = true, uiScale = 1 }
local onChange

local function corner(inst, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst
end

local function fireChange()
	if onChange then onChange(settings) end
end

local function stepperRow(parent, y, label, initialText, onDec, onInc)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -32, 0, 40); row.Position = UDim2.new(0, 16, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(22, 22, 36); row.BorderSizePixel = 0
	row.ZIndex = 21; row.Parent = parent
	corner(row, 8)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.5, 0, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1; lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(200, 200, 225); lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true; lbl.Font = Enum.Font.Gotham; lbl.ZIndex = 22; lbl.Parent = row

	local dec = Instance.new("TextButton")
	dec.Size = UDim2.new(0, 28, 0, 28); dec.Position = UDim2.new(1, -108, 0.5, -14)
	dec.BackgroundColor3 = Color3.fromRGB(40, 40, 60); dec.BorderSizePixel = 0
	dec.Text = "-"; dec.TextColor3 = Color3.new(1, 1, 1); dec.TextScaled = true
	dec.Font = Enum.Font.GothamBold; dec.ZIndex = 22; dec.Parent = row
	corner(dec, 6)

	local valueLbl = Instance.new("TextLabel")
	valueLbl.Size = UDim2.new(0, 44, 1, 0); valueLbl.Position = UDim2.new(1, -74, 0, 0)
	valueLbl.BackgroundTransparency = 1; valueLbl.Text = initialText
	valueLbl.TextColor3 = Color3.fromRGB(255, 210, 90); valueLbl.TextScaled = true
	valueLbl.Font = Enum.Font.GothamBold; valueLbl.ZIndex = 22; valueLbl.Parent = row

	local inc = Instance.new("TextButton")
	inc.Size = UDim2.new(0, 28, 0, 28); inc.Position = UDim2.new(1, -38, 0.5, -14)
	inc.BackgroundColor3 = Color3.fromRGB(40, 40, 60); inc.BorderSizePixel = 0
	inc.Text = "+"; inc.TextColor3 = Color3.new(1, 1, 1); inc.TextScaled = true
	inc.Font = Enum.Font.GothamBold; inc.ZIndex = 22; inc.Parent = row
	corner(inc, 6)

	dec.MouseButton1Click:Connect(function() onDec(valueLbl) end)
	inc.MouseButton1Click:Connect(function() onInc(valueLbl) end)

	return row, valueLbl
end

local function toggleRow(parent, y, label, initialOn, onToggle)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -32, 0, 40); row.Position = UDim2.new(0, 16, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(22, 22, 36); row.BorderSizePixel = 0
	row.ZIndex = 21; row.Parent = parent
	corner(row, 8)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.6, 0, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
	lbl.BackgroundTransparency = 1; lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(200, 200, 225); lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextScaled = true; lbl.Font = Enum.Font.Gotham; lbl.ZIndex = 22; lbl.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 78, 0, 28); btn.Position = UDim2.new(1, -90, 0.5, -14)
	btn.BorderSizePixel = 0; btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold; btn.ZIndex = 22; btn.Parent = row
	corner(btn, 6)

	local on = initialOn
	local function refresh()
		btn.Text = on and "ON" or "OFF"
		btn.BackgroundColor3 = on and Color3.fromRGB(60, 160, 90) or Color3.fromRGB(70, 40, 40)
	end
	refresh()

	-- Externally settable (used by SetSettings to reflect loaded data) without
	-- re-firing onToggle.
	local function setOn(value)
		on = value
		refresh()
	end

	btn.MouseButton1Click:Connect(function()
		setOn(not on)
		onToggle(on)
	end)

	return row, setOn
end

function SettingsUI:Init(gui, cbs)
	cbs = cbs or {}
	onChange = cbs.onChange

	panel = Instance.new("Frame")
	panel.Name = "SettingsPanel"
	panel.Size = UDim2.new(0, 420, 0, 400)
	panel.Position = UDim2.new(0.5, -210, 0.5, -200)
	panel.BackgroundColor3 = Color3.fromRGB(14, 14, 24)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.ZIndex = 20
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 1; stroke.Color = Color3.fromRGB(40, 40, 60); stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 44); title.Position = UDim2.new(0, 16, 0, 10)
	title.BackgroundTransparency = 1; title.Text = "SETTINGS"
	title.TextColor3 = Color3.fromRGB(210, 210, 240); title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true; title.Font = Enum.Font.GothamBold; title.ZIndex = 21; title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36); closeBtn.Position = UDim2.new(1, -46, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30); closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.new(1, 1, 1); closeBtn.TextScaled = true
	closeBtn.Font = Enum.Font.GothamBold; closeBtn.ZIndex = 21; closeBtn.Parent = panel
	corner(closeBtn, 6)
	closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

	local VOL_STEP, SCALE_STEP = 0.1, 0.05

	local _, volLbl = stepperRow(panel, 64, "Master Volume", "100%",
		function(lbl)
			settings.masterVolume = math.clamp(settings.masterVolume - VOL_STEP, 0, 1)
			lbl.Text = math.floor(settings.masterVolume * 100 + 0.5) .. "%"
			fireChange()
		end,
		function(lbl)
			settings.masterVolume = math.clamp(settings.masterVolume + VOL_STEP, 0, 1)
			lbl.Text = math.floor(settings.masterVolume * 100 + 0.5) .. "%"
			fireChange()
		end)
	rows.masterVolume = volLbl

	local _, setShakeOn = toggleRow(panel, 114, "Screen Shake", settings.screenShake, function(on)
		settings.screenShake = on
		fireChange()
	end)
	rows.screenShake = setShakeOn

	local _, setWarnOn = toggleRow(panel, 164, "Low HP Warning", settings.lowHpWarning, function(on)
		settings.lowHpWarning = on
		fireChange()
	end)
	rows.lowHpWarning = setWarnOn

	local _, scaleLbl = stepperRow(panel, 214, "UI Scale", "100%",
		function(lbl)
			settings.uiScale = math.clamp(settings.uiScale - SCALE_STEP, 0.75, 1.25)
			lbl.Text = math.floor(settings.uiScale * 100 + 0.5) .. "%"
			fireChange()
		end,
		function(lbl)
			settings.uiScale = math.clamp(settings.uiScale + SCALE_STEP, 0.75, 1.25)
			lbl.Text = math.floor(settings.uiScale * 100 + 0.5) .. "%"
			fireChange()
		end)
	rows.uiScale = scaleLbl

	local credits = Instance.new("TextLabel")
	credits.Size = UDim2.new(1, -32, 0, 90); credits.Position = UDim2.new(0, 16, 1, -102)
	credits.BackgroundTransparency = 1
	credits.Text = "RoguelikeTCG\nSound effects courtesy of Pro Sound Effects and APM Music via the Roblox Creator Store."
	credits.TextColor3 = Color3.fromRGB(110, 110, 140)
	credits.TextWrapped = true; credits.TextYAlignment = Enum.TextYAlignment.Top
	credits.TextXAlignment = Enum.TextXAlignment.Left
	credits.TextSize = 13; credits.Font = Enum.Font.Gotham
	credits.ZIndex = 21; credits.Parent = panel
end

-- Pushes a loaded settings table into the panel without firing onChange.
function SettingsUI:SetSettings(loaded)
	if type(loaded) ~= "table" then return end
	for k, v in pairs(loaded) do
		settings[k] = v
	end
	if rows.masterVolume then rows.masterVolume.Text = math.floor(settings.masterVolume * 100 + 0.5) .. "%" end
	if rows.uiScale then rows.uiScale.Text = math.floor(settings.uiScale * 100 + 0.5) .. "%" end
	if rows.screenShake then rows.screenShake(settings.screenShake) end
	if rows.lowHpWarning then rows.lowHpWarning(settings.lowHpWarning) end
end

function SettingsUI:GetSettings()
	return settings
end

function SettingsUI:Show()
	panel.Visible = true
end

function SettingsUI:Hide()
	panel.Visible = false
end

function SettingsUI:Toggle()
	panel.Visible = not panel.Visible
end

function SettingsUI:GetPanel()
	return panel
end

return SettingsUI
