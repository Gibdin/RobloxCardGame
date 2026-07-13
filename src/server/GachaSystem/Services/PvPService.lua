-- Async PvP: attack a snapshot of another player's saved team (online or
-- offline — InventoryService:PeekTeam works either way) via the exact same
-- BattleEngine.Resolve already used by Dungeon/Tower. No new combat code:
-- the "opponent" is just a second BuildUnit team built from their team save.
--
-- Trophy system, not symmetric Elo — only the attacker's rating moves (see
-- PvPConfig.lua for why). Rewards are Gems, diminishing per day via
-- InventoryService:RecordPvPWin so the same easy opponent can't be farmed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gachaShared  = ReplicatedStorage:WaitForChild("GachaSystem")
local CardDatabase = require(gachaShared:WaitForChild("CardDatabase"))
local PvPConfig    = require(gachaShared:WaitForChild("PvPConfig"))

local BattleEngine     = require(script.Parent.BattleEngine)
local InventoryService = require(script.Parent.InventoryService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local QuestService     = require(script.Parent.QuestService)

local PvPService = {}

-- Builds BattleEngine units for a team of card ids at base stats (no run
-- levels/items/buffs — a PvP defense squad is always the player's showcase
-- team at full strength, not mid-run state). Exposed publicly so
-- DuelMatchmakingService (Phase 6) can build both sides of a live duel the
-- same way, instead of duplicating this logic.
function PvPService:BuildUnitsForTeam(teamIds)
	local defs = {}
	for _, id in ipairs(teamIds) do
		if id then
			local card = CardDatabase:GetById(id)
			if card then table.insert(defs, card) end
		end
	end
	local ctx = BattleEngine.BuildTeamContext(defs)
	local units = {}
	local slot = 0
	for _, id in ipairs(teamIds) do
		slot = slot + 1
		if id then
			local card = CardDatabase:GetById(id)
			if card then
				table.insert(units, BattleEngine.BuildUnit(card, slot, ctx, {}))
			end
		end
	end
	return units
end

function PvPService:UnitSnapshot(units)
	local snap = {}
	for _, u in ipairs(units) do
		table.insert(snap, {
			slot = u.slot, cardId = u.cardId, name = u.name, role = u.role,
			hp = u.hp, maxHp = u.maxHp, mp = math.floor(u.mp), maxMp = u.maxMp,
			shield = u.shield, alive = u.alive,
		})
	end
	return snap
end

-- Top-N opponents by rating, excluding the requester. Simplification for
-- MVP: the opponent pool is globally top-rated players, not same-tier
-- matchmaking — see GameDesign.md's Phase 5 note.
function PvPService:GetOpponents(userId)
	local top = LeaderboardService:GetTopN("PvPRating", PvPConfig.OpponentPoolSize + 1)
	local opponents = {}
	for _, entry in ipairs(top) do
		if entry.userId ~= userId then
			table.insert(opponents, entry)
			if #opponents >= PvPConfig.OpponentPoolSize then break end
		end
	end
	return opponents
end

-- Returns (result, nil) on success or (nil, errMsg).
function PvPService:Attack(attackerUserId, opponentUserId)
	if attackerUserId == opponentUserId then
		return nil, "You can't attack yourself."
	end

	local attackerTeam = InventoryService:GetTeam(attackerUserId)
	local hasAttackerTeam = false
	for _, id in ipairs(attackerTeam) do if id then hasAttackerTeam = true end end
	if not hasAttackerTeam then
		return nil, "Set a team before entering the Arena."
	end

	local opponentTeam = InventoryService:PeekTeam(opponentUserId)
	local hasOpponentTeam = false
	for _, id in ipairs(opponentTeam) do if id then hasOpponentTeam = true end end
	if not hasOpponentTeam then
		return nil, "This player has no defense team set."
	end

	local attackerUnits = self:BuildUnitsForTeam(attackerTeam)
	local opponentUnits = self:BuildUnitsForTeam(opponentTeam)
	local attackerStart = self:UnitSnapshot(attackerUnits)
	local opponentStart = self:UnitSnapshot(opponentUnits)

	local seed = os.time() + attackerUserId + opponentUserId
	local result = BattleEngine.Resolve(attackerUnits, opponentUnits, seed)
	local victory = result.winner == "P"

	local ratingBefore = InventoryService:GetPvPRating(attackerUserId)
	local ratingDelta = victory and PvPConfig.WinTrophies or PvPConfig.LoseTrophies
	InventoryService:AdjustPvPRating(attackerUserId, ratingDelta)
	local ratingAfter = InventoryService:GetPvPRating(attackerUserId)

	local gemsAwarded = 0
	if victory then
		gemsAwarded = InventoryService:RecordPvPWin(attackerUserId)
		if gemsAwarded > 0 then
			InventoryService:AddGems(attackerUserId, gemsAwarded)
		end
		QuestService:RecordProgress(attackerUserId, "pvp_win", 1)
	end

	return {
		victory = victory,
		battle = { events = result.events, playerStart = attackerStart, enemyStart = opponentStart },
		ratingBefore = ratingBefore,
		ratingAfter = ratingAfter,
		ratingDelta = ratingAfter - ratingBefore,
		gemsAwarded = gemsAwarded,
	}, nil
end

return PvPService
