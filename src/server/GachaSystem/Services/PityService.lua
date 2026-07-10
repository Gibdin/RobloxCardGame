-- Tracks each player's roll counter and enforces hard-pity guarantees.
-- Counter resets only when a pity-guaranteed rarity was actually triggered.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RarityConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("RarityConfig"))

local PityService = {}

-- { [userId] = { totalRolls = N } }
local data = {}

local function get(userId)
	if not data[userId] then
		data[userId] = { totalRolls = 0 }
	end
	return data[userId]
end

-- Load saved pity data for a player (called by InventoryService on join).
function PityService:Inject(userId, saved)
	data[userId] = saved or { totalRolls = 0 }
end

-- Snapshot for persistence (merged into InventoryService save blob).
function PityService:Snapshot(userId)
	return get(userId)
end

-- Returns the minimum guaranteed rarity for the NEXT roll, or nil if none active.
function PityService:GetMinRarity(userId)
	local rolls    = get(userId).totalRolls
	local minOrder = 0
	local minRarity

	for _, threshold in ipairs(RarityConfig.PityThresholds) do
		if rolls >= threshold.rolls then
			local order = RarityConfig:GetOrder(threshold.minRarity)
			if order > minOrder then
				minOrder  = order
				minRarity = threshold.minRarity
			end
		end
	end

	return minRarity
end

-- Record a completed roll. minRarityApplied is what GetMinRarity returned before the roll.
-- Resets counter when pity was active and the result met the guarantee.
function PityService:RecordRoll(userId, resultRarity, minRarityApplied)
	local d = get(userId)
	d.totalRolls = d.totalRolls + 1

	if minRarityApplied then
		local resultOrder = RarityConfig:GetOrder(resultRarity)
		local minOrder    = RarityConfig:GetOrder(minRarityApplied)
		if resultOrder >= minOrder then
			d.totalRolls = 0
		end
	end
end

-- Summary for client display.
function PityService:GetInfo(userId)
	local rolls = get(userId).totalRolls
	local nextPity

	for _, threshold in ipairs(RarityConfig.PityThresholds) do
		local remaining = threshold.rolls - rolls
		if remaining > 0 then
			nextPity = { rarity = threshold.minRarity, rollsRemaining = remaining }
			break
		end
	end

	return { totalRolls = rolls, nextPity = nextPity }
end

function PityService:Cleanup(userId)
	data[userId] = nil
end

return PityService
