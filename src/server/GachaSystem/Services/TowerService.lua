-- Endless Tower run state and floor progression.
-- Run state is in-memory only: leaving the game ends the run. Pack rewards are
-- granted immediately when earned, so a disconnect never eats rewards; only
-- bestFloor persists (via InventoryService).
--
-- Anti-cheat: the client sends only intents (Start / NextFloor / PickBuff).
-- The team comes from server-side inventory state, battles resolve entirely
-- server-side, and the event log is output-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gachaShared   = ReplicatedStorage:WaitForChild("GachaSystem")
local CardDatabase  = require(gachaShared:WaitForChild("CardDatabase"))
local TowerConfig   = require(gachaShared:WaitForChild("TowerConfig"))
local DungeonConfig = require(gachaShared:WaitForChild("DungeonConfig"))

local BattleEngine     = require(script.Parent.BattleEngine)
local EnemyGenerator   = require(script.Parent.EnemyGenerator)
local RunModifiers     = require(script.Parent.RunModifiers)
local RunLock          = require(script.Parent.RunLock)
local InventoryService = require(script.Parent.InventoryService)
local QuestService     = require(script.Parent.QuestService)
local GuildService     = require(script.Parent.GuildService)
local GuildConfig       = require(gachaShared:WaitForChild("GuildConfig"))

local TowerService = {}

local runs = {}  -- { [userId] = RunState }

local Levels = DungeonConfig.Levels  -- XP curve/cap shared with dungeon runs

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function teamCardDefs(run)
	local defs = {}
	for _, id in ipairs(run.team) do
		if id then table.insert(defs, CardDatabase:GetById(id)) end
	end
	return defs
end

local function buildPlayerUnits(run)
	local defs = teamCardDefs(run)
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

-- Applies battle XP to every card; returns { [cardId] = {gained, level, leveledUp} }.
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
				-- Level-up stat gain also heals the added HP.
				cs.hpPct = math.min(1, (cs.hpPct or 1) + Levels.StatPerLevel)
			end
			-- String key: sparse numeric keys don't survive remote serialization.
			report[tostring(id)] = { gained = gained, level = cs.level, leveledUp = leveled }
		end
	end
	return report
end

-- Post-battle HP write-back: survivors heal, dead cards revive (won battles only).
local function writeBackHp(run, resultUnits)
	for _, u in ipairs(resultUnits) do
		local cs = run.cards[u.cardId]
		if cs then
			if u.alive then
				cs.hpPct = math.min(1, u.hp / u.maxHp + TowerConfig.WinHealPct)
			else
				cs.hpPct = TowerConfig.RevivePct
			end
		end
	end
end

local function milestonePacks(floor)
	local packs = TowerConfig.Milestones[floor]
	if not packs and floor > 20 and floor % TowerConfig.RepeatEvery == 0 then
		packs = TowerConfig.RepeatPacks
	end
	return packs
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

-- ── Public API ────────────────────────────────────────────────────────────────

function TowerService:GetState(userId)
	local run = runs[userId]
	if not run then return nil end
	-- Card states re-keyed as strings: sparse numeric keys don't survive
	-- remote serialization.
	local cardsOut = {}
	for id, cs in pairs(run.cards) do
		cardsOut[tostring(id)] = cs
	end
	return {
		mode = "Tower",
		floor = run.floor,
		state = run.state,
		team = run.team,
		cards = cardsOut,
		pendingBuffChoices = run.pendingBuffChoices,
		bestFloor = InventoryService:GetBestFloor(userId),
	}
end

function TowerService:Start(userId)
	if runs[userId] then
		return { success = false, error = "Tower run already active." }
	end
	local ok, blocking = RunLock.Acquire(userId, "Tower")
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

	runs[userId] = {
		userId = userId,
		seed = Random.new():NextInteger(1, 2 ^ 30),
		floor = 0,
		team = team,
		cards = cards,
		pendingBuffChoices = nil,
		state = "Active",
		inBattle = false,
	}
	return { success = true, run = self:GetState(userId) }
end

function TowerService:NextFloor(userId)
	local run = runs[userId]
	if not run then return { success = false, error = "No tower run active." } end
	if run.state ~= "Active" then return { success = false, error = "Resolve your pending choice first." } end
	if run.inBattle then return { success = false, error = "Battle in progress." } end
	run.inBattle = true

	local floor = run.floor + 1
	local isBoss = floor % TowerConfig.Enemies.BossEvery == 0
	local kind = isBoss and "TowerBoss" or "TowerFloor"
	local floorSeed = run.seed + floor * 7919

	local playerUnits = buildPlayerUnits(run)
	local gen = EnemyGenerator.Generate(kind, floor, floorSeed)
	local enemyUnits = EnemyGenerator.BuildUnits(gen)

	local playerStart = unitSnapshot(playerUnits)
	local enemyStart = unitSnapshot(enemyUnits)
	local result = BattleEngine.Resolve(playerUnits, enemyUnits, floorSeed)
	run.inBattle = false

	local victory = result.winner == "P"
	local payload = {
		success = true,
		victory = victory,
		floor = floor,
		boss = isBoss,
		battle = { events = result.events, playerStart = playerStart, enemyStart = enemyStart },
	}

	if victory then
		run.floor = floor
		writeBackHp(run, result.playerUnits)
		QuestService:RecordProgress(userId, "battle_win", 1)
		QuestService:RecordProgress(userId, "tower_floor", 1)
		local xpReport = awardXp(run, TowerConfig.XpPerFloor(floor), result.playerUnits)
		local packs = grantPacks(userId, milestonePacks(floor))
		InventoryService:SetBestFloor(userId, floor)
		if isBoss then
			GuildService:ContributeXP(userId, GuildConfig.XPPerPvEWin)
		end

		-- Surprise pack drop (dedicated seeded stream; offset 31 mirrors the
		-- dungeon's bonus-loot stream).
		local bonus
		local lootRng = Random.new(floorSeed + 31)
		if lootRng:NextNumber() < TowerConfig.BonusLoot.Chance then
			grantPacks(userId, TowerConfig.BonusLoot.Pack)
			bonus = { kind = "bonusPack", packs = TowerConfig.BonusLoot.Pack }
		end

		if floor % TowerConfig.BuffPickEvery == 0 then
			run.pendingBuffChoices = drawBuffChoices(run.seed + floor * 31337)
			run.state = "PickingBuff"
		end
		payload.rewards = { xp = xpReport, packs = packs, bonus = bonus }
	else
		run.state = "Dead"
		payload.runOver = true
		payload.floorsCleared = run.floor
		runs[userId] = nil
		RunLock.Release(userId)
	end

	payload.run = victory and self:GetState(userId) or nil
	payload.bestFloor = InventoryService:GetBestFloor(userId)
	return payload
end

function TowerService:PickBuff(userId, choiceIndex, targetCardId)
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
	run.state = "Active"
	return { success = true, run = self:GetState(userId) }
end

function TowerService:Abandon(userId)
	local run = runs[userId]
	if not run then return { success = false } end
	local floors = run.floor
	runs[userId] = nil
	RunLock.Release(userId)
	return { success = true, floorsCleared = floors }
end

function TowerService:Cleanup(userId)
	if runs[userId] then
		runs[userId] = nil
		RunLock.Release(userId)
	end
end

return TowerService
