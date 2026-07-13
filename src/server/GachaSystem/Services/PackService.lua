-- Orchestrates the full pack-opening pipeline:
-- validate → consume → roll → select card → handle duplicate → return result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityConfig      = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("RarityConfig"))
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("MonetizationConfig"))
local RollService      = require(script.Parent.RollService)
local CardService      = require(script.Parent.CardService)
local InventoryService = require(script.Parent.InventoryService)
local PityService      = require(script.Parent.PityService)
local BannerService    = require(script.Parent.BannerService)
local QuestService     = require(script.Parent.QuestService)

local PackService = {}

-- Shared roll/select/record pipeline used by both the normal (owned-pack) open
-- and the direct Gem-purchase open below. `bannerId`, if given and active,
-- biases card selection toward that banner's featured card within its rarity
-- and enforces the featured-unit guarantee.
local function rollAndGrant(userId, packType, bannerId)
	local minRarity = PityService:GetMinRarity(userId)
	local rarity = RollService:PickRarity(packType, minRarity)
	PityService:RecordRoll(userId, rarity, minRarity)

	local card
	local banner = bannerId and BannerService:GetBanner(bannerId)
	local forcedFeature = false

	if banner and BannerService:ShouldForceFeature(userId, bannerId) then
		card = CardService:GetById(banner.featuredCardId)
		forcedFeature = true
	elseif banner then
		local weightOverrides = BannerService:GetWeightOverrides(bannerId, rarity)
		card = CardService:GetRandomOfRarityOrLower(rarity, weightOverrides)
	else
		card = CardService:GetRandomOfRarityOrLower(rarity)
	end

	if not card then
		return nil, "No cards available for rarity: " .. rarity
	end

	if banner then
		local gotFeatured = forcedFeature or card.id == banner.featuredCardId
		BannerService:RecordPull(userId, bannerId, gotFeatured)
	end

	-- A forced guarantee can hand back a higher-rarity card than the natural
	-- roll (that's the whole point of the guarantee) — reflect the card's real
	-- rarity in what's returned so the reveal VFX/sound tier matches what the
	-- player actually got, not the roll that was overridden.
	local displayRarity = forcedFeature and card.rarity or rarity

	local isDuplicate    = InventoryService:OwnsCard(userId, card.id)
	local awakeningLevel = nil

	if isDuplicate then
		awakeningLevel = InventoryService:AddAwakening(userId, card.id, 1)
	else
		InventoryService:AddCard(userId, card.id)
	end

	QuestService:RecordProgress(userId, "pack_open", 1)

	return {
		card           = card,
		rarity         = displayRarity,
		packType       = packType,
		isDuplicate    = isDuplicate,
		awakeningLevel = awakeningLevel,
		pityInfo       = PityService:GetInfo(userId),
	}, nil
end

-- Opens one owned pack for a player. Returns (result, nil) on success or (nil, errMsg).
-- result = {
--   card            CardDatabase entry
--   rarity          string
--   packType        string
--   isDuplicate     bool
--   awakeningLevel  number | nil  (only present on duplicate)
--   pityInfo        { totalRolls, nextPity? }
-- }
function PackService:OpenPack(userId, packType, bannerId)
	if not RarityConfig.PackTypes[packType] then
		return nil, "Unknown pack type: " .. tostring(packType)
	end

	if not InventoryService:HasPack(userId, packType) then
		return nil, "No " .. packType .. " in inventory."
	end

	-- Consume before rolling to prevent double-opening on retry.
	InventoryService:RemovePack(userId, packType)

	return rollAndGrant(userId, packType, bannerId)
end

-- Buys and immediately opens one pack using the player's Gem balance (no
-- owned-pack inventory involved). Returns (result, nil) or (nil, errMsg).
function PackService:BuyAndOpenWithGems(userId, packType, bannerId)
	if not RarityConfig.PackTypes[packType] then
		return nil, "Unknown pack type: " .. tostring(packType)
	end

	local cost = MonetizationConfig.PackGemCost[packType]
	if not cost then
		return nil, "This pack type isn't purchasable with Gems."
	end

	if not InventoryService:SpendGems(userId, cost) then
		return nil, "Not enough Gems."
	end

	local result, err = rollAndGrant(userId, packType, bannerId)
	if not result then
		-- Roll failed for a reason unrelated to the spend (empty rarity pool) —
		-- refund so the player isn't charged for nothing.
		InventoryService:AddGems(userId, cost)
		return nil, err
	end
	return result, nil
end

-- Returns the pack type string of the next openable pack, or nil.
function PackService:GetNextAvailablePack(userId)
	return InventoryService:GetNextAvailablePack(userId)
end

return PackService
