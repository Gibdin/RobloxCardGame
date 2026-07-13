-- Shared client juice primitives: floating text, frame shake, number count-ups.
-- Used by BattleUI, RunTeamPanel, and the results flow.

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local FxUtil = {}

-- Text that floats up out of `parent` and fades. opts: { scale, yStart }.
function FxUtil.floatText(parent, text, color, opts)
	opts = opts or {}
	local scale = opts.scale or 1
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, math.floor(22 * scale))
	lbl.Position = UDim2.new(0, math.random(-14, 14), opts.yStart or 0.3, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.ZIndex = 60
	lbl.Parent = parent
	TweenService:Create(lbl, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = lbl.Position - UDim2.new(0, 0, 0.35, 0),
		TextTransparency = 1,
	}):Play()
	task.delay(0.8, function() lbl:Destroy() end)
end

-- Decaying positional shake on a frame. Concurrent calls merge: the stronger
-- intensity and later end time win, so a crit shake mid-kill-shake never
-- leaves the frame displaced.
local activeShakes = {}  -- [frame] = { intensity, endTime, origin }
local shakeEnabled = true

function FxUtil.SetShakeEnabled(enabled)
	shakeEnabled = enabled
end

function FxUtil.shake(frame, intensity, duration)
	if not shakeEnabled then return end
	local now = os.clock()
	local existing = activeShakes[frame]
	if existing then
		existing.intensity = math.max(existing.intensity, intensity)
		existing.endTime = math.max(existing.endTime, now + duration)
		return
	end

	local state = { intensity = intensity, endTime = now + duration, origin = frame.Position }
	activeShakes[frame] = state

	task.spawn(function()
		while os.clock() < state.endTime and frame.Parent do
			local remaining = state.endTime - os.clock()
			local total = math.max(0.05, remaining)
			local decay = math.min(1, remaining / 0.4)
			local mag = state.intensity * decay
			frame.Position = state.origin + UDim2.new(0,
				(math.random() * 2 - 1) * mag, 0, (math.random() * 2 - 1) * mag)
			RunService.Heartbeat:Wait()
		end
		if frame.Parent then frame.Position = state.origin end
		activeShakes[frame] = nil
	end)
end

-- Animates label.Text from `from` to `to` over `duration` with an ease-out
-- curve. opts: { prefix, suffix, tickEvery, sound = {mgr, name}, onDone }.
-- Ticks rise in pitch as the count accelerates toward the final value.
function FxUtil.countUp(label, from, to, duration, opts)
	opts = opts or {}
	local prefix = opts.prefix or ""
	local suffix = opts.suffix or ""
	task.spawn(function()
		local start = os.clock()
		local lastTick = 0
		while label.Parent do
			local a = math.min(1, (os.clock() - start) / duration)
			local eased = 1 - (1 - a) ^ 2
			local v = math.floor(from + (to - from) * eased + 0.5)
			label.Text = prefix .. v .. suffix
			if opts.sound and a < 1 and os.clock() - lastTick >= (opts.tickEvery or 0.05) then
				lastTick = os.clock()
				opts.sound.mgr:Play(opts.sound.name, { pitchScale = 1 + 0.3 * a })
			end
			if a >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if opts.sound then opts.sound.mgr:Play("count_finish") end
		-- Scale pop on the final number.
		if label.Parent then
			local pop = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			pop.Parent = label
			pop.Scale = 1.25
			TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		if opts.onDone then opts.onDone() end
	end)
end

return FxUtil
