-- Translates a card's run-scoped state (level, items, buffs, carried HP) into
-- the mods table consumed by BattleEngine.BuildUnit. This is the ONLY place
-- where buff/item ids become numbers — the pools in DungeonConfig are data-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gachaShared   = ReplicatedStorage:WaitForChild("GachaSystem")
local DungeonConfig = require(gachaShared:WaitForChild("DungeonConfig"))

local RunModifiers = {}

-- Multiplicative keys stack by multiplying; additive keys stack by adding;
-- boolean keys OR together.
local MULT_KEYS = { atkMult = true, hpMult = true, mpGainMult = true, activePowerMult = true, damageTakenMult = true, xpGainMult = true }
local BOOL_KEYS = { reviveOnce = true }

local function fold(mods, effects)
	for k, v in pairs(effects) do
		if MULT_KEYS[k] then
			mods[k] = (mods[k] or 1) * v
		elseif BOOL_KEYS[k] then
			mods[k] = mods[k] or v
		else
			mods[k] = (mods[k] or 0) + v
		end
	end
end

-- cardRunState: { level, hpPct, items = {itemId...}, buffs = {buffId...} } (all optional).
-- Returns a mods table for BattleEngine.BuildUnit. Carried HP is a fraction
-- (hpPct) because max HP shifts with levels/items; nil = start at full.
function RunModifiers.Compute(cardRunState)
	local mods = {}
	cardRunState = cardRunState or {}

	local level = cardRunState.level or 1
	if level > 1 then
		local pct = DungeonConfig.Levels.StatPerLevel * (level - 1)
		fold(mods, { atkMult = 1 + pct, hpMult = 1 + pct })
	end

	-- Ability power grows in tiers (every AbilityTierSize levels) rather than
	-- every level — see DungeonConfig.Levels' comment for why.
	local tier = level // DungeonConfig.Levels.AbilityTierSize
	if tier > 0 then
		fold(mods, { activePowerMult = 1 + tier * DungeonConfig.Levels.AbilityPowerPerTier })
	end

	for _, itemId in ipairs(cardRunState.items or {}) do
		local item = DungeonConfig.Items[itemId]
		if item then fold(mods, item.effects) end
	end

	for _, buffId in ipairs(cardRunState.buffs or {}) do
		local buff = DungeonConfig.Buffs[buffId]
		if buff then fold(mods, buff.effects) end
	end

	mods.startHpPct = cardRunState.hpPct
	return mods
end

return RunModifiers
