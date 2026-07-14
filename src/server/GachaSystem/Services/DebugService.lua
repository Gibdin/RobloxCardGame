-- Studio-only test shortcut: grants a competent 5-card team (one Tank, two
-- DPS, two Support, biased toward Rare/Epic so fights are winnable but not
-- trivial) so a tester can jump straight into combat without grinding packs.
-- Every entry point checks RunService:IsStudio() so this is inert on a
-- published server even if a client somehow calls the remote.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gachaShared = ReplicatedStorage:WaitForChild("GachaSystem")
local CardDatabase = require(gachaShared:WaitForChild("CardDatabase"))
local RarityConfig = require(gachaShared:WaitForChild("RarityConfig"))
local CombatConfig = require(gachaShared:WaitForChild("CombatConfig"))
local PvPConfig     = require(gachaShared:WaitForChild("PvPConfig"))
local MonetizationConfig = require(gachaShared:WaitForChild("MonetizationConfig"))

local InventoryService = require(script.Parent.InventoryService)

local DebugService = {}

local PREFERRED_RARITIES = { Rare = true, Epic = true }

local function pickForRole(role, rng, excludeIds)
	local preferred, fallback = {}, {}
	for _, card in ipairs(CardDatabase:GetAll()) do
		if card.role == role and not excludeIds[card.id] then
			table.insert(fallback, card)
			if PREFERRED_RARITIES[card.rarity] then
				table.insert(preferred, card)
			end
		end
	end
	local pool = #preferred > 0 and preferred or fallback
	if #pool == 0 then return nil end
	return pool[rng:NextInteger(1, #pool)]
end

function DebugService:QuickSetup(userId)
	if not RunService:IsStudio() then
		return { success = false, error = "Debug tools are Studio-only." }
	end

	local rng = Random.new()
	local roles = { "Tank", "DPS", "DPS", "Support", "Support" }
	local ids = {}
	local excludeIds = {}
	for _, role in ipairs(roles) do
		local card = pickForRole(role, rng, excludeIds)
		if card then
			excludeIds[card.id] = true
			InventoryService:AddCard(userId, card.id)
			table.insert(ids, card.id)
		end
	end

	InventoryService:SetTeam(userId, ids)
	InventoryService:AddPack(userId, "StandardPack", 5)
	InventoryService:AddPack(userId, "RarePack", 2)
	InventoryService:AddGems(userId, 1000)  -- lets testers exercise Gem spends without real products configured

	local names = {}
	for _, id in ipairs(ids) do
		table.insert(names, CardDatabase:GetById(id).name)
	end
	return { success = true, team = ids, names = names, gems = InventoryService:GetGems(userId) }
end

-- ── Balancing/admin tooling (Phase 9) ─────────────────────────────────────────
-- Studio-only, called directly via execute_luau against the live session —
-- "preview without redeploying" just means a developer can run these against
-- the running server instantly instead of shipping a change to find out.
-- No remote/UI wraps these (this is designer/developer tooling, not
-- player-facing), but every function still checks RunService:IsStudio()
-- defensively to match this file's existing convention.

-- Simulates `numRolls` rarity picks for `packType` (ignoring pity — this is
-- checking BASE weights, not pity-adjusted ones) and prints the resulting
-- distribution next to each rarity's configured weight-share, so a rebalance
-- of RarityConfig/PackTypes can be sanity-checked instantly.
function DebugService:PreviewRarityDistribution(packType, numRolls)
	if not RunService:IsStudio() then return end
	packType = packType or "StandardPack"
	numRolls = numRolls or 20000
	local RollService = require(script.Parent.RollService)

	local counts = {}
	for _, name in ipairs(RarityConfig.RarityOrder) do counts[name] = 0 end
	for _ = 1, numRolls do
		local rarity = RollService:PickRarity(packType, nil)
		counts[rarity] = counts[rarity] + 1
	end

	print(("[Debug] Rarity distribution over %d rolls (%s):"):format(numRolls, packType))
	for _, name in ipairs(RarityConfig.RarityOrder) do
		local pct = counts[name] / numRolls * 100
		print(("  %-10s %6d rolls  (%.2f%%)"):format(name, counts[name], pct))
	end
	return counts
end

-- Prints the actual live ATK/HP/MP min-max band per rarity, computed
-- directly from CardDatabase — the same numbers CardAuthoringGuide.md
-- documents, but read live so drift between the guide and reality is
-- visible immediately rather than discovered later.
function DebugService:PreviewStatBands()
	if not RunService:IsStudio() then return end
	print("[Debug] Live stat bands per rarity (min-max across CardDatabase):")
	for _, rarityName in ipairs(RarityConfig.RarityOrder) do
		local cards = CardDatabase:GetByRarity(rarityName)
		if #cards > 0 then
			local atkLo, atkHi, hpLo, hpHi, mpLo, mpHi = math.huge, 0, math.huge, 0, math.huge, 0
			for _, card in ipairs(cards) do
				atkLo, atkHi = math.min(atkLo, card.attack), math.max(atkHi, card.attack)
				hpLo, hpHi   = math.min(hpLo, card.hp),     math.max(hpHi, card.hp)
				mpLo, mpHi   = math.min(mpLo, card.mp),     math.max(mpHi, card.mp)
			end
			print(("  %-10s (%d cards)  ATK %d-%d   HP %d-%d   MP %d-%d"):format(
				rarityName, #cards, atkLo, atkHi, hpLo, hpHi, mpLo, mpHi))
		end
	end
end

-- Prints the synergy tier thresholds/effects for one series, or every series
-- if `seriesName` is nil — a quick reference while tuning CombatConfig.Synergies
-- without needing to open the file and cross-reference RoleConfig's text.
function DebugService:PreviewSynergyMath(seriesName)
	if not RunService:IsStudio() then return end
	local function printSeries(name, tiers)
		print(("[Debug] %s:"):format(name))
		for count, effects in pairs(tiers) do
			local parts = {}
			for k, v in pairs(effects) do
				table.insert(parts, k .. "=" .. tostring(v))
			end
			print(("  %d+ members: %s"):format(count, table.concat(parts, ", ")))
		end
	end

	if seriesName then
		local tiers = CombatConfig.Synergies[seriesName]
		if not tiers then print("[Debug] Unknown series: " .. tostring(seriesName)); return end
		printSeries(seriesName, tiers)
	else
		for name, tiers in pairs(CombatConfig.Synergies) do
			printSeries(name, tiers)
		end
	end
end

-- Simulates a simple win/loss sequence at a fixed win rate and prints the
-- resulting PvP trophy trajectory, so a change to PvPConfig.WinTrophies/
-- LoseTrophies can be previewed against "what does a 50% or 70% player's
-- rating curve look like over N games" without needing real matches.
function DebugService:PreviewPvPRatingCurve(numGames, winRate)
	if not RunService:IsStudio() then return end
	numGames = numGames or 20
	winRate = winRate or 0.5

	local rating = PvPConfig.StartingRating
	local rng = Random.new()
	local line = { tostring(rating) }
	for _ = 1, numGames do
		local won = rng:NextNumber() < winRate
		rating = math.max(PvPConfig.MinRating, rating + (won and PvPConfig.WinTrophies or PvPConfig.LoseTrophies))
		table.insert(line, tostring(rating))
	end
	print(("[Debug] PvP rating curve over %d games at %.0f%% win rate:"):format(numGames, winRate * 100))
	print("  " .. table.concat(line, " -> "))
	return rating
end

-- Prints which banner is scheduled active for each of the next `weeksAhead`
-- weeks, using the exact same schedule math BannerService uses live — lets a
-- developer verify "what's coming up" or catch an Order/epoch mistake without
-- waiting for real time to pass.
function DebugService:PreviewBannerRotation(weeksAhead)
	if not RunService:IsStudio() then return end
	weeksAhead = weeksAhead or MonetizationConfig.BannerRotation and #MonetizationConfig.BannerRotation.Order or 7
	local BannerService = require(script.Parent.BannerService)
	local rotation = MonetizationConfig.BannerRotation
	local periodSeconds = rotation.DurationDays * 86400

	print(("[Debug] Banner rotation, next %d weeks:"):format(weeksAhead))
	for i = 0, weeksAhead - 1 do
		local atTime = os.time() + i * periodSeconds
		local bannerId = BannerService:GetScheduledBannerId(atTime)
		local banner = BannerService:GetBanner(bannerId)
		print(("  Week +%d: %s (%s)"):format(i, bannerId, banner and banner.name or "?"))
	end
end

return DebugService
