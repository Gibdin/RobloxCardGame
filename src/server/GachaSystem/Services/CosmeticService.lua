-- Gem-purchased cosmetic Trails — cosmetic-only monetization that never
-- touches gacha odds. Trails use only Color/Transparency/Width sequences (no
-- Texture id), so there's no "need a real asset" blocker: they render
-- correctly with zero external assets, unlike mounts/pets which would need
-- custom meshes this project doesn't have yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local CosmeticConfig   = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("CosmeticConfig"))
local InventoryService = require(script.Parent.InventoryService)

local CosmeticService = {}

local function getTrailCfg(cosmeticId)
	for _, cfg in ipairs(CosmeticConfig.Trails) do
		if cfg.id == cosmeticId then return cfg end
	end
	return nil
end

-- Attaches (or removes) the equipped trail on a character. Two Attachments on
-- the HumanoidRootPart give a short ribbon that streaks behind the player as
-- they move — works identically on R6/R15 since HumanoidRootPart always exists.
local function applyTrail(character, cosmeticId)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Destroy any previously-attached trail AND its attachments — re-equipping
	-- (or a respawn re-applying the same trail) would otherwise accumulate
	-- orphaned Attachment instances on the root part forever.
	for _, childName in ipairs({ "CosmeticTrail", "CosmeticTrailAttach0", "CosmeticTrailAttach1" }) do
		local existing = root:FindFirstChild(childName)
		if existing then existing:Destroy() end
	end

	local cfg = getTrailCfg(cosmeticId)
	if not cfg or not cfg.color1 then return end  -- "none" or unknown id

	local att0 = Instance.new("Attachment")
	att0.Name = "CosmeticTrailAttach0"
	att0.Position = Vector3.new(0, -1, 0.5)
	att0.Parent = root

	local att1 = Instance.new("Attachment")
	att1.Name = "CosmeticTrailAttach1"
	att1.Position = Vector3.new(0, -1, -0.5)
	att1.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Color = ColorSequence.new(cfg.color1, cfg.color2)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Lifetime = 1
	trail.Parent = root
end

function CosmeticService:BuyCosmetic(userId, cosmeticId)
	local cfg = getTrailCfg(cosmeticId)
	if not cfg then return false, "Unknown cosmetic." end
	if InventoryService:OwnsCosmetic(userId, cosmeticId) then return false, "Already owned." end
	if not InventoryService:SpendGems(userId, cfg.gemCost) then return false, "Not enough Gems." end
	InventoryService:AddCosmetic(userId, cosmeticId)
	return true
end

function CosmeticService:EquipCosmetic(userId, cosmeticId, player)
	local ok = InventoryService:EquipCosmetic(userId, cosmeticId)
	if ok and player and player.Character then
		applyTrail(player.Character, cosmeticId)
	end
	return ok
end

-- Reapplies the player's equipped trail on every respawn.
function CosmeticService:WatchPlayer(player)
	player.CharacterAdded:Connect(function(character)
		local cosmetics = InventoryService:GetCosmetics(player.UserId)
		applyTrail(character, cosmetics.equipped)
	end)
	if player.Character then
		local cosmetics = InventoryService:GetCosmetics(player.UserId)
		applyTrail(player.Character, cosmetics.equipped)
	end
end

return CosmeticService
