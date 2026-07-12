-- Folds a server battle payload ({ events, playerStart, enemyStart }) into
-- per-unit stats and an MVP, entirely client-side. Uses the same last-actor
-- attribution as BattleUI's damage log: damage events don't carry an attacker,
-- but playback order is strict, so the most recent attack/cast src is the
-- attacker for any attack/active/chain damage that follows.

local BattleStats = {}

local function key(ref) return ref.side .. ref.slot end

-- Returns {
--   rounds, totalDamage, kills,                -- player-side totals
--   mvp = { name, cardId, damageDealt, kills, healingDone } | nil,
--   units = { [key] = { name, cardId, side, damageDealt, damageTaken,
--                       healingDone, kills, crits } },
-- }
function BattleStats.Fold(battle)
	local units = {}
	for _, u in ipairs(battle.playerStart) do
		units["P" .. u.slot] = {
			name = u.name, cardId = u.cardId, side = "P",
			damageDealt = 0, damageTaken = 0, healingDone = 0, kills = 0, crits = 0,
		}
	end
	for _, u in ipairs(battle.enemyStart) do
		units["E" .. u.slot] = {
			name = u.name, cardId = u.cardId, side = "E",
			damageDealt = 0, damageTaken = 0, healingDone = 0, kills = 0, crits = 0,
		}
	end

	local lastActor          -- key of the most recent attack/cast source
	local lastDamageActor    -- attacker credited for the most recent damage event
	local rounds = 0

	for _, ev in ipairs(battle.events) do
		if ev.t == "round" then
			rounds = ev.round
		elseif ev.t == "attack" or ev.t == "cast" then
			lastActor = key(ev.src)
		elseif ev.t == "damage" then
			local dst = units[key(ev.dst)]
			if dst then dst.damageTaken = dst.damageTaken + ev.amount end
			if (ev.source == "attack" or ev.source == "active" or ev.source == "chain")
				and lastActor and units[lastActor] then
				local a = units[lastActor]
				a.damageDealt = a.damageDealt + ev.amount
				if ev.crit then a.crits = a.crits + 1 end
				lastDamageActor = lastActor
			else
				-- reflect/other: no attacker credit, and it must not steal a kill
				lastDamageActor = nil
			end
		elseif ev.t == "heal" then
			if ev.source == "active" and lastActor and units[lastActor] then
				units[lastActor].healingDone = units[lastActor].healingDone + ev.amount
			else
				local target = units[key(ev.dst)]
				if target then target.healingDone = target.healingDone + ev.amount end
			end
		elseif ev.t == "death" then
			if lastDamageActor and units[lastDamageActor] then
				units[lastDamageActor].kills = units[lastDamageActor].kills + 1
			end
		elseif ev.t == "end" then
			rounds = ev.rounds or rounds
		end
	end

	local totalDamage, totalKills = 0, 0
	local mvp
	for _, u in pairs(units) do
		if u.side == "P" then
			totalDamage = totalDamage + u.damageDealt
			totalKills = totalKills + u.kills
			if not mvp
				or u.damageDealt > mvp.damageDealt
				or (u.damageDealt == mvp.damageDealt and u.kills > mvp.kills)
				or (u.damageDealt == mvp.damageDealt and u.kills == mvp.kills and u.healingDone > mvp.healingDone) then
				mvp = u
			end
		end
	end

	return { rounds = rounds, totalDamage = totalDamage, kills = totalKills, mvp = mvp, units = units }
end

return BattleStats
