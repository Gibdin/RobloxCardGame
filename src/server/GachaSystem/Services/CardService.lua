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

-- Walks down from `rarity` toward Common until a non-empty pool is found.
-- Used as a fallback when a rarity has no cards defined yet.
function CardService:GetRandomOfRarityOrLower(rarity)
	local RC = require(ReplicatedStorage.GachaSystem.RarityConfig)
	local order = RC:GetOrder(rarity)
	for i = order, 1, -1 do
		local card = self:GetRandomOfRarity(RC:ByOrder(i))
		if card then return card end
	end
	return nil
end

return CardService
