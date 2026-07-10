-- Builds enemy teams from CardDatabase for dungeon nodes and tower floors.
-- Fully seeded: all randomness comes from the Random instance created from the
-- given seed, so the same (kind, difficulty, seed) always yields the same team.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gachaShared   = ReplicatedStorage:WaitForChild("GachaSystem")
local CardDatabase  = require(gachaShared:WaitForChild("CardDatabase"))
local DungeonConfig = require(gachaShared:WaitForChild("DungeonConfig"))
local TowerConfig   = require(gachaShared:WaitForChild("TowerConfig"))
local BattleEngine  = require(script.Parent.BattleEngine)

local EnemyGenerator = {}

local function weightedPick(rng, weights)
	local total = 0
	local keys = {}
	for k, w in pairs(weights) do
		total = total + w
		table.insert(keys, k)
	end
	table.sort(keys) -- deterministic iteration order regardless of hash order
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, k in ipairs(keys) do
		acc = acc + weights[k]
		if roll <= acc then return k end
	end
	return keys[#keys]
end

local function randomOfRarity(rng, rarity)
	local pool = CardDatabase:GetByRarity(rarity)
	if not pool or #pool == 0 then return nil end
	return pool[rng:NextInteger(1, #pool)]
end

local function bandPool(bands, key, value)
	for _, band in ipairs(bands) do
		if value <= band[key] then return band.pool end
	end
	return bands[#bands].pool
end

-- SeriesBias: after the first pick, re-roll each slot once toward the first
-- pick's primary series so enemy teams get live synergies too.
local SERIES_BIAS = 0.6

local function pickCards(rng, count, rarityPool)
	local cards = {}
	local biasSeries
	for i = 1, count do
		local rarity = weightedPick(rng, rarityPool)
		local card = randomOfRarity(rng, rarity) or randomOfRarity(rng, "Common")
		if i == 1 then
			biasSeries = card.series and card.series[1]
		elseif biasSeries and rng:NextNumber() < SERIES_BIAS then
			-- Only bias within the rolled rarity — otherwise low floors could
			-- spawn a Legendary just because it shares a series with a Common.
			local seriesPool = {}
			for _, c in ipairs(CardDatabase:GetBySeries(biasSeries) or {}) do
				if c.rarity == rarity then table.insert(seriesPool, c) end
			end
			if #seriesPool > 0 then
				card = seriesPool[rng:NextInteger(1, #seriesPool)]
			end
		end
		table.insert(cards, card)
	end
	return cards
end

-- Returns { cards = {cardDef...}, mults = {statMult per index}, boss = bool }.
-- kind: "Mob" | "Elite" | "Boss" | "TowerFloor" | "TowerBoss"
-- difficulty: dungeon row or tower floor.
function EnemyGenerator.Generate(kind, difficulty, seed)
	local rng = Random.new(seed)

	if kind == "Boss" then
		local bossConf = DungeonConfig.Enemies.Boss
		local centerRarity = bossConf.CenterpieceRarities[rng:NextInteger(1, #bossConf.CenterpieceRarities)]
		local cards = { randomOfRarity(rng, centerRarity) or randomOfRarity(rng, "Legendary") }
		local mults = { bossConf.CenterpieceMult }
		for _ = 1, bossConf.AddCount do
			table.insert(cards, randomOfRarity(rng, bossConf.AddRarity) or randomOfRarity(rng, "Epic"))
			table.insert(mults, bossConf.AddMult)
		end
		return { cards = cards, mults = mults, boss = true }
	end

	if kind == "TowerFloor" or kind == "TowerBoss" then
		local conf = TowerConfig.Enemies
		local count = conf.TeamSize(difficulty)
		local pool = bandPool(conf.RarityBands, "maxFloor", difficulty)
		local mult = TowerConfig.StatMult(difficulty)
		if kind == "TowerBoss" then mult = mult * conf.BossMult end
		local cards = pickCards(rng, count, pool)
		local mults = {}
		for i = 1, #cards do mults[i] = mult end
		return { cards = cards, mults = mults, boss = kind == "TowerBoss" }
	end

	-- Mob / Elite
	local conf = DungeonConfig.Enemies
	local count = conf.TeamSize(difficulty)
	local pool = bandPool(conf.RarityBands, "maxRow", difficulty)
	local mult = conf.MobMult(difficulty)
	if kind == "Elite" then mult = mult * conf.EliteMult end
	local cards = pickCards(rng, count, pool)
	local mults = {}
	for i = 1, #cards do mults[i] = mult end
	return { cards = cards, mults = mults, boss = false }
end

-- Builds engine-ready UnitStates from a Generate() result.
function EnemyGenerator.BuildUnits(gen)
	local ctx = BattleEngine.BuildTeamContext(gen.cards)
	local units = {}
	for i, card in ipairs(gen.cards) do
		table.insert(units, BattleEngine.BuildUnit(card, i, ctx, { statMult = gen.mults[i] }))
	end
	return units
end

-- Lightweight preview payload for the client (no live stats).
function EnemyGenerator.Preview(gen)
	local preview = { boss = gen.boss, cards = {} }
	for i, card in ipairs(gen.cards) do
		table.insert(preview.cards, { id = card.id, mult = gen.mults[i] })
	end
	return preview
end

return EnemyGenerator
