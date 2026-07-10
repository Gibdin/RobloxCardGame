-- Dungeon run state and node resolution: branching map, gold economy,
-- per-run card XP/leveling, and battle resolution at Mob/Elite/Boss nodes.
-- Run state is in-memory only: leaving the game ends the run. Pack rewards are
-- granted immediately when earned, so a disconnect never eats them.
--
-- Anti-cheat: the client sends only intents (Start / ChooseNode / PickEliteBuff /
-- Abandon). The team comes from server-side inventory state, the map is
-- generated server-side from a server-chosen seed, node reachability is
-- validated against the server's own edge graph, and battles resolve entirely
-- server-side.
--
-- Elite and Shop nodes are disabled via DungeonConfig.Map.EnabledTypes until
-- their systems ship (Phase 4/5); the resolution paths below are written now
-- so flipping the switch needs no rework here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gachaShared   = ReplicatedStorage:WaitForChild("GachaSystem")
local CardDatabase  = require(gachaShared:WaitForChild("CardDatabase"))
local DungeonConfig = require(gachaShared:WaitForChild("DungeonConfig"))

local BattleEngine     = require(script.Parent.BattleEngine)
local EnemyGenerator   = require(script.Parent.EnemyGenerator)
local MapGenerator     = require(script.Parent.MapGenerator)
local RunModifiers     = require(script.Parent.RunModifiers)
local RunLock          = require(script.Parent.RunLock)
local InventoryService = require(script.Parent.InventoryService)

local DungeonService = {}

local runs = {}  -- { [userId] = RunState }

local Levels = DungeonConfig.Levels

-- ── Helpers (mirrors TowerService's shape) ────────────────────────────────────

local function buildPlayerUnits(run)
	local defs = {}
	for _, id in ipairs(run.team) do
		if id then table.insert(defs, CardDatabase:GetById(id)) end
	end
	local ctx = BattleEngine.BuildTeamContext(defs)
	local units = {}
	for slot, id in ipairs(run.team) do
		if id then
			local card = CardDatabase:GetById(id)
			table.insert(units, BattleEngine.BuildUnit(card, slot, ctx, RunModifiers.Compute(run.cards[id])))
		end
	end
	return units
end

local function unitSnapshot(units)
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

local function awardXp(run, amount, resultUnits)
	local aliveBySlot = {}
	for _, u in ipairs(resultUnits) do aliveBySlot[u.slot] = u.alive end

	local report = {}
	for slot, id in ipairs(run.team) do
		if id then
			local cs = run.cards[id]
			local mods = RunModifiers.Compute(cs)
			local gained = math.floor(amount * (mods.xpGainMult or 1) * (aliveBySlot[slot] and 1 or Levels.DeadXpPct))
			cs.xp = cs.xp + gained
			local leveled = false
			while cs.level < Levels.Cap and cs.xp >= Levels.XpForLevel(cs.level) do
				cs.xp = cs.xp - Levels.XpForLevel(cs.level)
				cs.level = cs.level + 1
				leveled = true
				cs.hpPct = math.min(1, (cs.hpPct or 1) + Levels.StatPerLevel)
			end
			report[tostring(id)] = { gained = gained, level = cs.level, leveledUp = leveled }
		end
	end
	return report
end

local function writeBackHp(run, resultUnits)
	for _, u in ipairs(resultUnits) do
		local cs = run.cards[u.cardId]
		if cs then
			if u.alive then
				cs.hpPct = math.min(1, u.hp / u.maxHp + DungeonConfig.WinHealPct)
			else
				cs.hpPct = DungeonConfig.RevivePct
			end
		end
	end
end

local function grantPacks(userId, packs)
	if not packs then return nil end
	for packType, n in pairs(packs) do
		InventoryService:AddPack(userId, packType, n)
	end
	return packs
end

local function drawBuffChoices(seed)
	local rng = Random.new(seed)
	local ids = {}
	for id in pairs(DungeonConfig.Buffs) do table.insert(ids, id) end
	table.sort(ids)
	local choices = {}
	for _ = 1, DungeonConfig.BuffOfferCount do
		if #ids == 0 then break end
		table.insert(choices, table.remove(ids, rng:NextInteger(1, #ids)))
	end
	return choices
end

local function reachableNodeIds(run)
	local reachable = {}
	if run.position == false then
		for _, n in ipairs(run.map.rows[1]) do reachable[n.id] = true end
	else
		local cur = run.mapIndex[run.position]
		if cur then
			for _, e in ipairs(cur.edges) do reachable[e] = true end
		end
	end
	return reachable
end

-- ── Public API ────────────────────────────────────────────────────────────────

function DungeonService:GetState(userId)
	local run = runs[userId]
	if not run then return nil end
	local cardsOut = {}
	for id, cs in pairs(run.cards) do
		cardsOut[tostring(id)] = cs
	end
	return {
		mode = "Dungeon",
		map = run.map,
		position = run.position,
		gold = run.gold,
		team = run.team,
		cards = cardsOut,
		pendingBuffChoices = run.pendingBuffChoices,
		state = run.state,
		deepestRow = run.deepestRow,
	}
end

function DungeonService:Start(userId)
	if runs[userId] then
		return { success = false, error = "Dungeon run already active." }
	end
	local ok, blocking = RunLock.Acquire(userId, "Dungeon")
	if not ok then
		return { success = false, error = "A " .. blocking .. " run is already active." }
	end

	local team = InventoryService:GetTeam(userId)
	local hasCard = false
	for _, id in ipairs(team) do
		if id then hasCard = true break end
	end
	if not hasCard then
		RunLock.Release(userId)
		return { success = false, error = "Your team is empty — add cards first." }
	end

	local cards = {}
	for _, id in ipairs(team) do
		if id then
			cards[id] = { xp = 0, level = 1, hpPct = 1, items = {}, buffs = {} }
		end
	end

	local seed = Random.new():NextInteger(1, 2 ^ 30)
	local map = MapGenerator.Generate(seed)

	runs[userId] = {
		userId = userId, seed = seed,
		map = map, mapIndex = MapGenerator.Index(map),
		position = false, gold = DungeonConfig.Gold.Start,
		team = team, cards = cards,
		pendingBuffChoices = nil, shopStock = {},
		state = "Map", inBattle = false, deepestRow = 0,
	}
	return { success = true, run = self:GetState(userId) }
end

local function finishRun(userId, run, finalState)
	run.state = finalState
	runs[userId] = nil
	RunLock.Release(userId)
end

function DungeonService:ChooseNode(userId, nodeId)
	local run = runs[userId]
	if not run then return { success = false, error = "No dungeon run active." } end
	if run.state ~= "Map" then return { success = false, error = "Resolve your pending choice first." } end
	if run.inBattle then return { success = false, error = "Battle in progress." } end
	if type(nodeId) ~= "string" then return { success = false, error = "Invalid node." } end

	local node = run.mapIndex[nodeId]
	if not node then return { success = false, error = "Invalid node." } end
	if not reachableNodeIds(run)[nodeId] then
		return { success = false, error = "That node isn't reachable." }
	end

	run.position = nodeId
	node.visited = true
	run.deepestRow = math.max(run.deepestRow, node.row)

	if node.type == "Mob" or node.type == "Elite" or node.type == "Boss" then
		run.inBattle = true
		local row = node.row
		local nodeSeed = run.seed * 1000 + row * 10 + node.col

		local playerUnits = buildPlayerUnits(run)
		local gen = EnemyGenerator.Generate(node.type, row, nodeSeed)
		local enemyUnits = EnemyGenerator.BuildUnits(gen)
		local playerStart = unitSnapshot(playerUnits)
		local enemyStart = unitSnapshot(enemyUnits)
		local result = BattleEngine.Resolve(playerUnits, enemyUnits, nodeSeed)
		run.inBattle = false

		local victory = result.winner == "P"
		local payload = {
			success = true, nodeType = node.type, victory = victory, boss = node.type == "Boss",
			battle = { events = result.events, playerStart = playerStart, enemyStart = enemyStart },
		}

		if victory then
			writeBackHp(run, result.playerUnits)

			local xpAward = (node.type == "Mob" and DungeonConfig.XpAward.Mob(row))
				or (node.type == "Elite" and DungeonConfig.XpAward.Elite(row))
				or DungeonConfig.XpAward.Boss()
			local xpReport = awardXp(run, xpAward, result.playerUnits)

			local goldAward = (node.type == "Mob" and DungeonConfig.Gold.Mob(row, Random.new(nodeSeed + 7)))
				or (node.type == "Elite" and DungeonConfig.Gold.Elite(row))
				or DungeonConfig.Gold.Boss()
			run.gold = run.gold + goldAward

			payload.rewards = { xp = xpReport, gold = goldAward }

			if node.type == "Elite" then
				local packs = grantPacks(userId, DungeonConfig.Rewards.ElitePacks)
				payload.rewards.packs = packs
				run.pendingBuffChoices = drawBuffChoices(run.seed + row * 31337 + node.col)
				run.state = "PickingBuff"
			elseif node.type == "Boss" then
				local packs = grantPacks(userId, DungeonConfig.Rewards.BossPacks)
				payload.rewards.packs = packs
				payload.runOver = true
				payload.complete = true
				finishRun(userId, run, "Complete")
			end
		else
			payload.runOver = true
			payload.deepestRow = run.deepestRow
			finishRun(userId, run, "Dead")
		end

		payload.run = runs[userId] and self:GetState(userId) or nil
		return payload
	elseif node.type == "Rest" then
		for _, cs in pairs(run.cards) do
			cs.hpPct = math.min(1, (cs.hpPct or 1) + DungeonConfig.RestHealPct)
		end
		return { success = true, nodeType = "Rest", restHeal = DungeonConfig.RestHealPct, run = self:GetState(userId) }
	elseif node.type == "Shop" then
		-- Ships in Phase 5; nodes of this type aren't generated yet.
		return { success = true, nodeType = "Shop", run = self:GetState(userId) }
	end

	return { success = false, error = "Unknown node type." }
end

function DungeonService:PickEliteBuff(userId, choiceIndex, targetCardId)
	local run = runs[userId]
	if not run or run.state ~= "PickingBuff" then
		return { success = false, error = "No buff choice pending." }
	end
	if type(choiceIndex) ~= "number" or not run.pendingBuffChoices[choiceIndex] then
		return { success = false, error = "Invalid choice." }
	end
	local cs = type(targetCardId) == "number" and run.cards[targetCardId]
	if not cs then
		return { success = false, error = "Invalid target card." }
	end

	table.insert(cs.buffs, run.pendingBuffChoices[choiceIndex])
	run.pendingBuffChoices = nil
	run.state = "Map"
	return { success = true, run = self:GetState(userId) }
end

function DungeonService:Abandon(userId)
	local run = runs[userId]
	if not run then return { success = false } end
	local deepestRow = run.deepestRow
	runs[userId] = nil
	RunLock.Release(userId)
	return { success = true, deepestRow = deepestRow }
end

function DungeonService:Cleanup(userId)
	if runs[userId] then
		runs[userId] = nil
		RunLock.Release(userId)
	end
end

return DungeonService
