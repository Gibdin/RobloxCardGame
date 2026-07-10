-- Orchestrates the full pack-opening pipeline:
-- validate → consume → roll → select card → handle duplicate → return result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityConfig     = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("RarityConfig"))
local RollService      = require(script.Parent.RollService)
local CardService      = require(script.Parent.CardService)
local InventoryService = require(script.Parent.InventoryService)
local PityService      = require(script.Parent.PityService)

local PackService = {}

-- Opens one pack for a player. Returns (result, nil) on success or (nil, errMsg).
-- result = {
--   card            CardDatabase entry
--   rarity          string
--   packType        string
--   isDuplicate     bool
--   awakeningLevel  number | nil  (only present on duplicate)
--   pityInfo        { totalRolls, nextPity? }
-- }
function PackService:OpenPack(userId, packType)
	if not RarityConfig.PackTypes[packType] then
		return nil, "Unknown pack type: " .. tostring(packType)
	end

	if not InventoryService:HasPack(userId, packType) then
		return nil, "No " .. packType .. " in inventory."
	end

	-- Consume before rolling to prevent double-opening on retry.
	InventoryService:RemovePack(userId, packType)

	-- Pity check BEFORE the roll so the floor is applied this pull.
	local minRarity = PityService:GetMinRarity(userId)

	-- Roll rarity then record (handles counter + conditional reset).
	local rarity = RollService:PickRarity(packType, minRarity)
	PityService:RecordRoll(userId, rarity, minRarity)

	-- Select a card from the rolled rarity (falls back if pool empty).
	local card = CardService:GetRandomOfRarityOrLower(rarity)
	if not card then
		return nil, "No cards available for rarity: " .. rarity
	end

	-- Duplicate detection → awakening.
	local isDuplicate    = InventoryService:OwnsCard(userId, card.id)
	local awakeningLevel = nil

	if isDuplicate then
		awakeningLevel = InventoryService:AddAwakening(userId, card.id, 1)
	else
		InventoryService:AddCard(userId, card.id)
	end

	return {
		card           = card,
		rarity         = rarity,
		packType       = packType,
		isDuplicate    = isDuplicate,
		awakeningLevel = awakeningLevel,
		pityInfo       = PityService:GetInfo(userId),
	}, nil
end

-- Returns the pack type string of the next openable pack, or nil.
function PackService:GetNextAvailablePack(userId)
	return InventoryService:GetNextAvailablePack(userId)
end

return PackService
