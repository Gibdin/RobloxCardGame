-- Thin wrapper around CardDatabase for server-side card lookups.
-- All card selection logic lives here so other services never import CardDatabase directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CardDatabase = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("CardDatabase"))

local CardService = {}

function CardService:GetById(id)
	return CardDatabase:GetById(id)
end

function CardService:GetByRarity(rarity)
	return CardDatabase:GetByRarity(rarity)
end

-- Returns a uniformly random card of the given rarity, or nil if the pool is empty.
function CardService:GetRandomOfRarity(rarity)
	local pool = CardDatabase:GetByRarity(rarity)
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

-- Returns a random card of the given rarity, weighted by `weightOverrides`
-- (a { [cardId] = multiplier } map; cards not listed default to weight 1).
-- Falls back to a uniform pick when weightOverrides is nil. Used by banners to
-- bias toward a featured card without touching the base rarity-roll odds.
function CardService:GetRandomOfRarityWeighted(rarity, weightOverrides)
	local pool = CardDatabase:GetByRarity(rarity)
	if #pool == 0 then return nil end
	if not weightOverrides then
		return pool[math.random(1, #pool)]
	end

	local weights = {}
	local total = 0
	for _, card in ipairs(pool) do
		local w = weightOverrides[card.id] or 1
		weights[card] = w
		total = total + w
	end

	local roll = math.random() * total
	local cumulative = 0
	for _, card in ipairs(pool) do
		cumulative = cumulative + weights[card]
		if roll <= cumulative then return card end
	end
	return pool[#pool]  -- float-error safety
end

-- Walks down from `rarity` toward Common until a non-empty pool is found.
-- Used as a fallback when a rarity has no cards defined yet. weightOverrides
-- (optional) is forwarded to the weighted picker for banner support.
function CardService:GetRandomOfRarityOrLower(rarity, weightOverrides)
	local RC = require(ReplicatedStorage.GachaSystem.RarityConfig)
	local order = RC:GetOrder(rarity)
	for i = order, 1, -1 do
		local card = self:GetRandomOfRarityWeighted(RC:ByOrder(i), weightOverrides)
		if card then return card end
	end
	return nil
end

return CardService
