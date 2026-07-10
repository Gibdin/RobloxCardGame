-- BattleController — plays a server battle event log through BattleUI.
-- Pure playback: every event carries its resulting values, so Skip simply runs
-- the same dispatch with zero waits (no separate final-state code path).

local BattleController = {}

local BattleUI, CombatConfig
local isPlaying = false
local skipRequested = false

function BattleController:Init(battleUI, combatConfig)
	BattleUI = battleUI
	CombatConfig = combatConfig
	BattleUI:SetOnSkip(function()
		skipRequested = true
	end)
end

function BattleController:IsPlaying()
	return isPlaying
end

-- battle: { events, playerStart, enemyStart } from the server.
-- Yields until playback finishes (call from a task.spawn/coroutine context).
function BattleController:Play(battle, floorLabel)
	if isPlaying then return end
	isPlaying = true
	skipRequested = false

	BattleUI:BeginBattle(battle.playerStart, battle.enemyStart, floorLabel)

	local dispatch = {
		round   = function(ev) BattleUI:SetRound(ev.round) end,
		attack  = function(ev) BattleUI:PlayAttack(ev) end,
		damage  = function(ev) BattleUI:ApplyDamage(ev) end,
		heal    = function(ev) BattleUI:ApplyHeal(ev) end,
		mp      = function(ev) BattleUI:SetMp(ev) end,
		cast    = function(ev) BattleUI:PlayCast(ev) end,
		shield  = function(ev) BattleUI:ApplyShield(ev) end,
		death   = function(ev) BattleUI:PlayDeath(ev) end,
		advance = function(ev) BattleUI:PlayAdvance(ev) end,
		synergy = function(ev) BattleUI:ShowSynergy(ev) end,
		["end"] = function() end,
	}

	for _, ev in ipairs(battle.events) do
		local handler = dispatch[ev.t]
		if handler then
			handler(ev)
			if not skipRequested then
				local wait = CombatConfig.Playback[ev.t] or 0.1
				task.wait(wait / BattleUI:GetSpeed())
			end
		end
	end

	isPlaying = false
end

return BattleController
