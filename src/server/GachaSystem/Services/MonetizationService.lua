-- Wraps MarketplaceService for Gem-package Developer Products and the VIP Game
-- Pass. Product/pass ids come from MonetizationConfig and default to 0 (not
-- yet created — this place isn't published). Any prompt for an id == 0 is
-- refused client-side before it ever reaches here; ProcessReceipt additionally
-- ignores receipts for unrecognized ProductIds as a second line of defense.
--
-- Purchase granting always goes through InventoryService:GrantPurchase, which
-- is idempotent and safe even if the player has already left the server —
-- required by Roblox: ProcessReceipt must never lose a paid purchase and must
-- return the same decision if called again with the same receipt.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("MonetizationConfig"))
local InventoryService   = require(script.Parent.InventoryService)

local MonetizationService = {}

-- Set by Main.server.lua once the VIPGranted RemoteEvent exists, so this
-- service can notify the client without reaching for ReplicatedStorage.
-- GachaRemotes itself (that folder is created by Main.server.lua AFTER it
-- requires this module, so looking it up here directly would deadlock on
-- WaitForChild).
local onVIPGranted

function MonetizationService:SetVIPGrantedCallback(fn)
	onVIPGranted = fn
end

-- ── Product lookup tables (by real Roblox ProductId, not our config `id`) ────

local gemProductsByProductId = {}
for _, product in ipairs(MonetizationConfig.GemProducts) do
	if product.productId ~= 0 then
		gemProductsByProductId[product.productId] = product
	end
end

-- ── Gem packages (consumable Developer Products) ─────────────────────────────

function MonetizationService:ProcessReceipt(receiptInfo)
	local userId    = receiptInfo.PlayerId
	local receiptId = receiptInfo.PurchaseId

	-- Battle Pass premium unlock shares the receipt pipeline with Gem packages.
	if receiptInfo.ProductId == MonetizationConfig.BattlePass.productId
		and MonetizationConfig.BattlePass.productId ~= 0 then
		local granted = InventoryService:GrantPurchase(userId, receiptId, function(d)
			d.battlePass.premium = true
		end)
		return granted and Enum.ProductPurchaseDecision.PurchaseGranted
			or Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local product = gemProductsByProductId[receiptInfo.ProductId]
	if not product then
		warn("[MonetizationService] Receipt for unrecognized ProductId:", receiptInfo.ProductId)
		-- Not one of ours (or a stale/misconfigured id) — never grant, but don't
		-- get stuck retrying forever either.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local totalGems = product.gems + (product.bonus or 0)
	local granted = InventoryService:GrantPurchase(userId, receiptId, function(d)
		d.gems = d.gems + totalGems
	end)

	return granted and Enum.ProductPurchaseDecision.PurchaseGranted
		or Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Server-authoritative prompt: validates the product exists and is configured
-- before ever calling into MarketplaceService.
function MonetizationService:PromptGemPurchase(player, gemProductConfigId)
	for _, product in ipairs(MonetizationConfig.GemProducts) do
		if product.id == gemProductConfigId then
			if product.productId == 0 then
				warn("[MonetizationService] Gem product not configured yet:", gemProductConfigId)
				return false
			end
			MarketplaceService:PromptProductPurchase(player, product.productId)
			return true
		end
	end
	return false
end

function MonetizationService:PromptBattlePassPurchase(player)
	local productId = MonetizationConfig.BattlePass.productId
	if productId == 0 then
		warn("[MonetizationService] Battle Pass product not configured yet")
		return false
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	return true
end

-- ── VIP Game Pass ─────────────────────────────────────────────────────────────

function MonetizationService:PromptVIPPurchase(player)
	local passId = MonetizationConfig.VIP.passId
	if passId == 0 then
		warn("[MonetizationService] VIP Game Pass not configured yet")
		return false
	end
	MarketplaceService:PromptGamePassPurchase(player, passId)
	return true
end

-- Re-checks live Game Pass ownership against Roblox and syncs InventoryService.
-- Safe to call even with a placeholder passId (no-ops).
function MonetizationService:SyncVIPOwnership(player)
	local passId = MonetizationConfig.VIP.passId
	if passId == 0 then return end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and owns and not InventoryService:IsVIP(player.UserId) then
		InventoryService:SetVIP(player.UserId, true)
		if onVIPGranted then onVIPGranted(player) end
	end
end

-- Per Roblox docs, PromptGamePassPurchaseFinished should only be listened to
-- server-side — client-side values aren't reliable for game logic.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if wasPurchased and gamePassId == MonetizationConfig.VIP.passId then
		InventoryService:SetVIP(player.UserId, true)
		if onVIPGranted then onVIPGranted(player) end
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	return MonetizationService:ProcessReceipt(receiptInfo)
end

return MonetizationService
