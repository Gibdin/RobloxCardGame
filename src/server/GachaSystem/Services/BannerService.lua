-- Tracks each player's per-banner pull counter and enforces the featured-unit
-- guarantee. Does NOT roll cards itself — PackService calls into this to learn
-- whether a pull should be biased/forced toward the featured card, then
-- records the outcome afterward. Mirrors PityService's shape/conventions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("MonetizationConfig"))
local RarityConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("RarityConfig"))

local BannerService = {}

-- { [userId] = { [bannerId] = pullsSinceFeatured } }
local data = {}

local function get(userId)
	if not data[userId] then
		data[userId] = {}
	end
	return data[userId]
end

-- Load saved banner-pull data for a player (called by InventoryService on join).
function BannerService:Inject(userId, saved)
	data[userId] = saved or {}
end

-- Snapshot for persistence (merged into InventoryService save blob).
function BannerService:Snapshot(userId)
	return get(userId)
end

function BannerService:GetActiveBanner()
	for _, banner in ipairs(MonetizationConfig.Banners) do
		if banner.active then return banner end
	end
	return nil
end

function BannerService:GetBanner(bannerId)
	for _, banner in ipairs(MonetizationConfig.Banners) do
		if banner.id == bannerId then return banner end
	end
	return nil
end

function BannerService:GetPulls(userId, bannerId)
	return get(userId)[bannerId] or 0
end

-- Returns true if this banner's guarantee has been met and the NEXT pull
-- should be forced to the featured card (rarity included).
function BannerService:ShouldForceFeature(userId, bannerId)
	local banner = self:GetBanner(bannerId)
	if not banner then return false end
	return self:GetPulls(userId, bannerId) >= banner.guaranteeAfter
end

-- Returns { [featuredCardId] = rateMult } for use as CardService weightOverrides,
-- or nil if the given rarity doesn't match the featured card's rarity (no bias
-- applies outside that rarity — the banner only ever affects its own tier).
function BannerService:GetWeightOverrides(bannerId, rarity)
	local banner = self:GetBanner(bannerId)
	if not banner then return nil end

	local CardDatabase = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("CardDatabase"))
	local featured = CardDatabase:GetById(banner.featuredCardId)
	if not featured or featured.rarity ~= rarity then return nil end

	return { [banner.featuredCardId] = banner.rateMult }
end

-- Records the outcome of a pull made against this banner. gotFeatured resets
-- the counter; otherwise it increments.
function BannerService:RecordPull(userId, bannerId, gotFeatured)
	local d = get(userId)
	if gotFeatured then
		d[bannerId] = 0
	else
		d[bannerId] = (d[bannerId] or 0) + 1
	end
end

function BannerService:Cleanup(userId)
	data[userId] = nil
end

return BannerService
