-- Live duel matchmaking: pairs two queued players within a widening rating
-- band and resolves the fight via the unchanged, deterministic BattleEngine.
-- There is no "live" combat netcode here — the engine already resolves a
-- fight instantly and deterministically (no player input during a fight, per
-- BattleEngine's design), so the only genuinely real-time surface is queueing
-- players up and notifying both clients together. Rating moves symmetrically
-- (both players are actually present), unlike Phase 5's attacker-only async
-- trophy movement.
--
-- IMPORTANT correctness note: turn order within a round depends on which
-- side is "P" vs "E" (P always acts first each phase), so re-resolving the
-- same matchup with sides swapped is NOT guaranteed to produce the same
-- fight — it could even flip the winner. Both players must watch the exact
-- same resolution. We resolve once (queued-first player = "P") and give the
-- second player a pure label-swapped copy of the SAME event log (swapSide
-- below), never a second Resolve call.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PvPConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("PvPConfig"))

local BattleEngine     = require(script.Parent.BattleEngine)
local InventoryService = require(script.Parent.InventoryService)
local PvPService       = require(script.Parent.PvPService)
local QuestService     = require(script.Parent.QuestService)

local DuelMatchmakingService = {}

-- { [userId] = { rating = N, joinedAt = os.clock() } }
local queue = {}
local queueOrder = {}  -- ordered userIds, for stable FIFO scanning

local recentDuels = {} -- ring buffer for spectating: { id, nameA, nameB, winnerName, battle }
local nextDuelId = 1

local onMatched  -- callback(player, payload) — set by Main.server.lua to fire the RemoteEvent

function DuelMatchmakingService:SetOnMatched(fn)
	onMatched = fn
end

local function currentBand(entry)
	local waited = os.clock() - entry.joinedAt
	local m = PvPConfig.Matchmaking
	return math.min(m.MaxBand, m.InitialBand + waited * m.BandGrowthPerSecond)
end

local function swapSide(s)
	if s == "P" then return "E" end
	if s == "E" then return "P" end
	return s
end

-- Pure data transformation of an already-resolved battle log — no
-- re-simulation, so the fight itself can never diverge between the two
-- players' views (see the correctness note above).
local function swapBattlePerspective(battle)
	local swapped = {}
	for _, ev in ipairs(battle.events) do
		local newEv = table.clone(ev)
		if newEv.side then newEv.side = swapSide(newEv.side) end
		if newEv.winner then newEv.winner = swapSide(newEv.winner) end
		if newEv.src then newEv.src = { side = swapSide(newEv.src.side), slot = newEv.src.slot } end
		if newEv.dst then newEv.dst = { side = swapSide(newEv.dst.side), slot = newEv.dst.slot } end
		table.insert(swapped, newEv)
	end
	return {
		events = swapped,
		playerStart = battle.enemyStart,
		enemyStart = battle.playerStart,
	}
end

function DuelMatchmakingService:JoinQueue(userId)
	if queue[userId] then return true end

	local team = InventoryService:GetTeam(userId)
	local hasTeam = false
	for _, id in ipairs(team) do if id then hasTeam = true end end
	if not hasTeam then return false, "Set a team before queueing for a duel." end

	queue[userId] = { rating = InventoryService:GetPvPRating(userId), joinedAt = os.clock() }
	table.insert(queueOrder, userId)
	self:_Sweep()
	return true
end

function DuelMatchmakingService:LeaveQueue(userId)
	if not queue[userId] then return end
	queue[userId] = nil
	for i = #queueOrder, 1, -1 do
		if queueOrder[i] == userId then table.remove(queueOrder, i) end
	end
end

function DuelMatchmakingService:GetQueueStatus(userId)
	local entry = queue[userId]
	return { queued = entry ~= nil, waitSeconds = entry and math.floor(os.clock() - entry.joinedAt) or 0 }
end

local function findMatch()
	-- O(n^2) over the queue — fine at the scale an MVP matchmaking pool
	-- actually has; revisit if the player base ever makes this a hot path.
	for i = 1, #queueOrder do
		local idA = queueOrder[i]
		local entryA = queue[idA]
		if entryA then
			for j = i + 1, #queueOrder do
				local idB = queueOrder[j]
				local entryB = queue[idB]
				if entryB then
					local band = math.max(currentBand(entryA), currentBand(entryB))
					if math.abs(entryA.rating - entryB.rating) <= band then
						return idA, idB
					end
				end
			end
		end
	end
	return nil
end

local function resolveDuel(userIdA, userIdB)
	local teamA = InventoryService:GetTeam(userIdA)
	local teamB = InventoryService:GetTeam(userIdB)
	local unitsA = PvPService:BuildUnitsForTeam(teamA)
	local unitsB = PvPService:BuildUnitsForTeam(teamB)
	local startA = PvPService:UnitSnapshot(unitsA)
	local startB = PvPService:UnitSnapshot(unitsB)

	local seed = os.time() + userIdA + userIdB
	local result = BattleEngine.Resolve(unitsA, unitsB, seed)  -- A = P, B = E — resolved exactly once
	local aWon = result.winner == "P"

	local deltaA = aWon and PvPConfig.WinTrophies or PvPConfig.LoseTrophies
	local deltaB = aWon and PvPConfig.LoseTrophies or PvPConfig.WinTrophies
	InventoryService:AdjustPvPRating(userIdA, deltaA)
	InventoryService:AdjustPvPRating(userIdB, deltaB)

	if aWon then QuestService:RecordProgress(userIdA, "pvp_win", 1)
	else QuestService:RecordProgress(userIdB, "pvp_win", 1) end

	local playerA = Players:GetPlayerByUserId(userIdA)
	local playerB = Players:GetPlayerByUserId(userIdB)
	local nameA = playerA and playerA.Name or ("Player#" .. userIdA)
	local nameB = playerB and playerB.Name or ("Player#" .. userIdB)

	local battleA = { events = result.events, playerStart = startA, enemyStart = startB }

	local duelRecord = {
		id = nextDuelId, nameA = nameA, nameB = nameB,
		winnerName = aWon and nameA or nameB,
		battle = battleA,  -- spectators watch from A's perspective; fine either way
	}
	nextDuelId = nextDuelId + 1
	table.insert(recentDuels, 1, duelRecord)
	while #recentDuels > PvPConfig.Matchmaking.MaxRecentDuels do
		table.remove(recentDuels)
	end

	if onMatched then
		if playerA then
			onMatched(playerA, {
				battle = battleA, victory = aWon, opponentName = nameB,
				ratingDelta = deltaA, ratingAfter = InventoryService:GetPvPRating(userIdA),
			})
		end
		if playerB then
			onMatched(playerB, {
				battle = swapBattlePerspective(battleA), victory = not aWon, opponentName = nameA,
				ratingDelta = deltaB, ratingAfter = InventoryService:GetPvPRating(userIdB),
			})
		end
	end
end

-- Matches and resolves every compatible pair currently in the queue.
function DuelMatchmakingService:_Sweep()
	while true do
		local idA, idB = findMatch()
		if not idA then break end
		queue[idA] = nil
		queue[idB] = nil
		for i = #queueOrder, 1, -1 do
			if queueOrder[i] == idA or queueOrder[i] == idB then table.remove(queueOrder, i) end
		end
		resolveDuel(idA, idB)
	end
end

task.spawn(function()
	while true do
		task.wait(PvPConfig.Matchmaking.TickInterval)
		DuelMatchmakingService:_Sweep()
	end
end)

-- ── Spectating ────────────────────────────────────────────────────────────────

function DuelMatchmakingService:GetRecentDuels()
	local list = {}
	for _, d in ipairs(recentDuels) do
		table.insert(list, { id = d.id, nameA = d.nameA, nameB = d.nameB, winnerName = d.winnerName })
	end
	return list
end

-- Returns the battle payload for a past duel, or nil if it's aged out.
function DuelMatchmakingService:WatchDuel(duelId)
	for _, d in ipairs(recentDuels) do
		if d.id == duelId then return d.battle, d.nameA, d.nameB end
	end
	return nil
end

return DuelMatchmakingService
