-- Endless Tower "rebirth" — see PrestigeConfig.lua for the design rationale.
-- Reaching PrestigeConfig.MinFloorToPrestige lets a player reset their
-- resettable cycle-floor ratchet (InventoryService's prestige.cycleBestFloor
-- — NOT the permanent tower.bestFloor leaderboard record, which never
-- lowers) in exchange for a permanent account-wide stat multiplier and the
-- next Artifact in ArtifactConfig.Order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrestigeConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("PrestigeConfig"))

local InventoryService = require(script.Parent.InventoryService)
local AccountService   = require(script.Parent.AccountService)

local PrestigeService = {}

function PrestigeService:GetPrestigeMult(userId)
	local info = InventoryService:GetPrestigeInfo(userId)
	local count = math.min(info.count, PrestigeConfig.MaxPrestige)
	return 1 + count * PrestigeConfig.MultPerRebirth
end

function PrestigeService:GetInfo(userId)
	local info = InventoryService:GetPrestigeInfo(userId)
	return {
		count = info.count,
		cycleBestFloor = info.cycleBestFloor,
		bestFloor = info.bestFloor,
		minFloorToPrestige = PrestigeConfig.MinFloorToPrestige,
		maxPrestige = PrestigeConfig.MaxPrestige,
		canPrestige = info.cycleBestFloor >= PrestigeConfig.MinFloorToPrestige and info.count < PrestigeConfig.MaxPrestige,
		mult = self:GetPrestigeMult(userId),
	}
end

-- Returns (true, nil, artifactId) on success or (false, errMsg).
function PrestigeService:Prestige(userId)
	local info = InventoryService:GetPrestigeInfo(userId)
	if info.count >= PrestigeConfig.MaxPrestige then
		return false, "Already at max Prestige."
	end
	if info.cycleBestFloor < PrestigeConfig.MinFloorToPrestige then
		return false, ("Reach Tower floor %d first."):format(PrestigeConfig.MinFloorToPrestige)
	end

	InventoryService:DoPrestige(userId)
	AccountService:AddXp(userId, PrestigeConfig.XpReward)
	local artifactId = AccountService:GrantNextArtifact(userId)
	return true, nil, artifactId
end

return PrestigeService
