-- Readability — a game-wide floor for text legibility, applied to every text
-- object under the game's ScreenGui (including ones created later).
--
-- Why a global layer instead of per-screen fixes: the UI is built by ~18
-- modules, each with its own label helpers, and most of the tiny/dim text
-- comes through those helpers or through TextScaled boxes. One floor here
-- keeps every screen (and every future screen) readable for the target
-- audience without touching each layout.
--
--   * Fixed-size text below MIN_TEXT_SIZE is raised to it.
--   * TextScaled text gets a UITextSizeConstraint floor (MIN_SCALED_SIZE).
--   * Text darker than MIN_LUMINANCE is lightened (hue kept) — unless it sits
--     on a bright background (e.g. dark text on a gold button), where
--     lightening would reduce contrast instead.

local Readability = {}

local MIN_TEXT_SIZE   = 11
local MIN_SCALED_SIZE = 9
local MIN_LUMINANCE   = 0.45   -- 0-1 relative luminance floor for text on dark UI
local BRIGHT_BG       = 0.55   -- a background brighter than this is "light"

local function luminance(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

-- Mix toward white just enough to reach the luminance floor.
local function lighten(c)
	local lum = luminance(c)
	if lum >= MIN_LUMINANCE then return c end
	local t = (MIN_LUMINANCE - lum) / (1 - lum)
	return c:Lerp(Color3.new(1, 1, 1), t)
end

-- True when the text is drawn over a light surface (its own fill, or the
-- nearest visible parent fill).
local function onLightBackground(obj)
	local node = obj
	for _ = 1, 3 do
		if not node or not node:IsA("GuiObject") then return false end
		if node.BackgroundTransparency < 0.5 then
			return luminance(node.BackgroundColor3) > BRIGHT_BG
		end
		node = node.Parent
	end
	return false
end

local fixing = setmetatable({}, { __mode = "k" })

local function fixColor(obj)
	if fixing[obj] then return end
	if onLightBackground(obj) then return end
	local c = obj.TextColor3
	local lc = lighten(c)
	if lc ~= c then
		fixing[obj] = true
		obj.TextColor3 = lc
		fixing[obj] = nil
	end
end

local function fixSize(obj)
	if obj.TextScaled then
		if not obj:FindFirstChildOfClass("UITextSizeConstraint") then
			local k = Instance.new("UITextSizeConstraint")
			k.MinTextSize = MIN_SCALED_SIZE
			k.Parent = obj
		end
	elseif obj.TextSize < MIN_TEXT_SIZE then
		fixing[obj] = true
		obj.TextSize = MIN_TEXT_SIZE
		fixing[obj] = nil
	end
end

local function apply(obj)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
	fixSize(obj)
	fixColor(obj)
	-- Screens recolor/resize text after creation (hover states, refreshes).
	obj:GetPropertyChangedSignal("TextColor3"):Connect(function() fixColor(obj) end)
	obj:GetPropertyChangedSignal("TextSize"):Connect(function()
		if not fixing[obj] then fixSize(obj) end
	end)
	obj:GetPropertyChangedSignal("TextScaled"):Connect(function() fixSize(obj) end)
end

function Readability:Attach(root)
	for _, d in ipairs(root:GetDescendants()) do apply(d) end
	root.DescendantAdded:Connect(function(d)
		-- Defer one frame so the creating code finishes setting properties
		-- and parenting (onLightBackground needs the final parent).
		task.defer(apply, d)
	end)
end

return Readability
