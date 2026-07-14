-- Thin wrapper around Roblox's real AnalyticsService: pull-rate tracking,
-- Gem economy events (spend/earn), PvP/Duel win rates, guild adoption, and
-- trade volume — instrumented from day one rather than bolted on after
-- launch, so post-launch live-ops (Phase 9's pipeline) has real data to work
-- from instead of guesswork.
--
-- Every call is pcall-wrapped, including the Enum lookups themselves —
-- analytics must never be able to break gameplay, and this also protects
-- against this file being wrong about an exact API detail (re-verify against
-- create.roblox.com/docs once published and real dashboard data can confirm
-- events are actually landing — that confirmation can't happen pre-publish).

local RobloxAnalytics = game:GetService("AnalyticsService")

local AnalyticsService = {}

local function safeCall(fn)
	local ok, err = pcall(fn)
	if not ok then
		warn("[Analytics] call failed:", err)
	end
end

-- Which rarity was pulled from which pack type — cross-checks real live pull
-- rates against RarityConfig's configured weights (the same numbers
-- DebugService:PreviewRarityDistribution simulates in Studio).
function AnalyticsService:LogPackOpened(player, packType, rarity, bannerId)
	if not player then return end
	safeCall(function()
		RobloxAnalytics:LogCustomEvent(player, "PackOpened", nil, {
			packType = packType, rarity = rarity, bannerId = bannerId or "",
		})
	end)
end

function AnalyticsService:LogGemsSpent(player, amount, endingBalance, itemSku)
	if not player then return end
	safeCall(function()
		RobloxAnalytics:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink,
			"Gems", amount, endingBalance, "Gameplay", itemSku)
	end)
end

function AnalyticsService:LogGemsEarned(player, amount, endingBalance, transactionType, itemSku)
	if not player then return end
	safeCall(function()
		RobloxAnalytics:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source,
			"Gems", amount, endingBalance, transactionType or "Gameplay", itemSku)
	end)
end

-- PvP/Duel win-loss — core balance signal (rating curve, matchup fairness).
function AnalyticsService:LogPvPResult(player, mode, victory, ratingAfter)
	if not player then return end
	safeCall(function()
		RobloxAnalytics:LogCustomEvent(player, "PvPResult", ratingAfter, {
			mode = mode, victory = tostring(victory),
		})
	end)
end

-- Guild create/join — social-feature adoption tracking.
function AnalyticsService:LogGuildActivity(player, action, guildId)
	if not player then return end
	safeCall(function()
		RobloxAnalytics:LogCustomEvent(player, "GuildActivity", nil, {
			action = action, guildId = tostring(guildId),
		})
	end)
end

-- Completed trades — volume signal for the trading feature.
function AnalyticsService:LogTradeCompleted(player, otherUserId)
	if not player then return end
	safeCall(function()
		RobloxAnalytics:LogCustomEvent(player, "TradeCompleted", nil, {
			otherUserId = tostring(otherUserId),
		})
	end)
end

return AnalyticsService
