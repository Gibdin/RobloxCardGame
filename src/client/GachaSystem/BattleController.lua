-- BattleController — plays a server battle event log through BattleUI.
-- Pure playback: every event carries its resulting values, so Skip simply runs
-- the same dispatch with zero waits (no separate final-state code path).
--
-- Drama beats (CombatConfig.Drama): a pre-hold of silence before the
-- battle-deciding hit, an emphasized final blow, and an extra pause after
-- every death. All extra waits sit behind the same skip guard as the base
-- playback, so SKIP stays instant.

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

-- The battle-deciding hit: the damage event nearest before the LAST death.
-- Round-cap endings have no final death — then there is no final blow.
local function findFinalBlowIndex(events)
	local lastDeath
	for i = #events, 1, -1 do
		if events[i].t == "death" then
			lastDeath = i
			break
		end
	end
	if not lastDeath then return nil end
	for i = lastDeath - 1, 1, -1 do
		if events[i].t == "damage" then
			return i
		end
	end
	return nil
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

	local drama = CombatConfig.Drama
	local finalBlowIndex = drama and findFinalBlowIndex(battle.events) or nil

	for i, ev in ipairs(battle.events) do
		local handler = dispatch[ev.t]
		if handler then
			local speed = BattleUI:GetSpeed()
			if i == finalBlowIndex and not skipRequested then
				-- Anticipation beat, emphasized hit, long hold.
				task.wait(drama.FinalBlowPreHold / speed)
				BattleUI:PlayFinalBlow(ev)
				if not skipRequested then
					task.wait((CombatConfig.Playback.damage + drama.FinalBlowPause) / speed)
				end
			else
				handler(ev)
				if not skipRequested then
					local wait = CombatConfig.Playback[ev.t] or 0.1
					if ev.t == "death" and drama then
						wait = wait + drama.KillPause
					end
					task.wait(wait / speed)
				end
			end
		end
	end

	isPlaying = false
end

return BattleController
