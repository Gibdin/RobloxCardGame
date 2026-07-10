-- Weighted random rarity selection with per-pack multipliers and pity floor support.
-- Does NOT modify state — callers handle pity recording and card selection.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("RarityConfig"))

local RollService = {}

-- Builds a normalised cumulative-weight table respecting the minimum rarity floor
-- and optional per-pack multipliers.
local function buildTable(packType, minOrder)
	local packCfg     = RarityConfig.PackTypes[packType] or {}
	local multipliers = packCfg.multipliers or {}

	local entries = {}
	local total   = 0

	for _, rarityName in ipairs(RarityConfig.RarityOrder) do
		local rData = RarityConfig.Rarities[rarityName]
		if rData.order >= minOrder then
			local w = rData.weight * (multipliers[rarityName] or 1)
			total   = total + w
			table.insert(entries, { rarity = rarityName, weight = w })
		end
	end

	-- Convert to cumulative fractions for O(n) sampling.
	local cumulative = 0
	for _, entry in ipairs(entries) do
		cumulative      = cumulative + (entry.weight / total)
		entry.cumulative = cumulative
	end

	return entries
end

-- Returns a rarity string sampled from the weighted table.
local function sample(weightTable)
	local r = math.random()
	for _, entry in ipairs(weightTable) do
		if r <= entry.cumulative then
			return entry.rarity
		end
	end
	return weightTable[#weightTable].rarity  -- float-error safety
end

-- Pick a rarity for one roll.
-- packType: string key in RarityConfig.PackTypes
-- minRarity: optional floor (from PityService:GetMinRarity) or nil
-- Returns: rarity string
function RollService:PickRarity(packType, minRarity)
	local minOrder    = minRarity and RarityConfig:GetOrder(minRarity) or 1
	local weightTable = buildTable(packType, minOrder)
	return sample(weightTable)
end

return RollService
