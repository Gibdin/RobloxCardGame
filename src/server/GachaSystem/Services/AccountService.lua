-- Account-level meta progression: XP/level curve, cosmetic title unlocks,
-- and permanent Artifact ownership/equip. Owns the small account-wide stat
-- bonus (level perk + equipped Artifact) applied to every battle mode via
-- ApplyStatMods — called from Dungeon/Tower/PvP/Duel's unit-building code
-- alongside PrestigeService's separate multiplier (kept as two numbers
-- multiplied at the call site rather than folded together here, to avoid a
-- circular require: PrestigeService already depends on AccountService to
-- grant Artifacts on rebirth).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gachaShared = ReplicatedStorage:WaitForChild("GachaSystem")
local AccountConfig  = require(gachaShared:WaitForChild("AccountConfig"))
local ArtifactConfig = require(gachaShared:WaitForChild("ArtifactConfig"))

local InventoryService = require(script.Parent.InventoryService)

local AccountService = {}

-- Multiplicative keys stack by multiplying; additive keys stack by adding;
-- boolean keys OR together — same convention as RunModifiers.fold.
local MULT_KEYS = { atkMult = true, hpMult = true, mpGainMult = true, activePowerMult = true }
local BOOL_KEYS = { reviveOnce = true }

local function levelForXP(xp)
	local level = 1
	for i, threshold in ipairs(AccountConfig.LevelXP) do
		if xp >= threshold then level = i end
	end
	return level
end

local function unlockedTitles(level)
	local titles = {}
	for _, t in ipairs(AccountConfig.Titles) do
		if level >= t.level then table.insert(titles, t.title) end
	end
	return titles
end

local function artifactDef(artifactId)
	for _, def in ipairs(ArtifactConfig.Order) do
		if def.id == artifactId then return def end
	end
	return nil
end

function AccountService:AddXp(userId, amount)
	if type(amount) ~= "number" or amount <= 0 then return end
	local xp, _ = InventoryService:GetAccountProgress(userId)
	xp = xp + amount
	InventoryService:SetAccountProgress(userId, xp, levelForXP(xp))
end

function AccountService:GetState(userId)
	local xp, level = InventoryService:GetAccountProgress(userId)
	return {
		level = level,
		xp = xp,
		nextLevelXp = AccountConfig.LevelXP[level + 1],
		unlockedTitles = unlockedTitles(level),
		equippedTitle = InventoryService:GetEquippedTitle(userId),
		ownedArtifacts = InventoryService:GetOwnedArtifacts(userId),
		equippedArtifact = InventoryService:GetEquippedArtifact(userId),
		artifactDefs = ArtifactConfig.Order,
	}
end

-- Returns (true, nil) or (false, errMsg). Pass "" to unequip.
function AccountService:EquipTitle(userId, title)
	if title ~= "" then
		local _, level = InventoryService:GetAccountProgress(userId)
		local ok = false
		for _, t in ipairs(unlockedTitles(level)) do
			if t == title then ok = true; break end
		end
		if not ok then return false, "Title not unlocked." end
	end
	InventoryService:SetEquippedTitle(userId, title)
	return true, nil
end

-- Grants the next not-yet-owned Artifact in ArtifactConfig.Order. Returns the
-- granted artifact id, or nil if every Artifact is already owned.
function AccountService:GrantNextArtifact(userId)
	local owned = InventoryService:GetOwnedArtifacts(userId)
	for _, def in ipairs(ArtifactConfig.Order) do
		if not owned[def.id] then
			InventoryService:AddArtifact(userId, def.id)
			return def.id
		end
	end
	return nil
end

-- Returns (true, nil) or (false, errMsg). Pass "" to unequip.
function AccountService:EquipArtifact(userId, artifactId)
	if artifactId ~= "" then
		if not InventoryService:GetOwnedArtifacts(userId)[artifactId] then
			return false, "Artifact not owned."
		end
	end
	InventoryService:SetEquippedArtifact(userId, artifactId)
	return true, nil
end

-- Level perk + equipped Artifact folded into one mods-shaped table.
function AccountService:GetStatMods(userId)
	local _, level = InventoryService:GetAccountProgress(userId)
	local levelMult = 1 + math.min(level, #AccountConfig.LevelXP) * AccountConfig.StatPerLevel
	local mods = { atkMult = levelMult, hpMult = levelMult }

	local equippedId = InventoryService:GetEquippedArtifact(userId)
	local def = equippedId ~= "" and artifactDef(equippedId)
	if def then
		for k, v in pairs(def.effects) do
			if MULT_KEYS[k] then
				mods[k] = (mods[k] or 1) * v
			elseif BOOL_KEYS[k] then
				mods[k] = mods[k] or v
			else
				mods[k] = (mods[k] or 0) + v
			end
		end
	end
	return mods
end

-- Mutates `mods` (a BattleEngine.BuildUnit mods table already built by the
-- caller — RunModifiers.Compute's output for Dungeon/Tower, or {} for
-- PvP/Duel) in place, folding in this account's level perk + equipped
-- Artifact + the caller-supplied Prestige multiplier. Centralizing this here
-- means the 4 battle call sites each need only one line instead of
-- duplicating the fold logic.
function AccountService:ApplyStatMods(mods, userId, prestigeMult)
	local acct = self:GetStatMods(userId)
	local mult = prestigeMult or 1
	mods.atkMult = (mods.atkMult or 1) * acct.atkMult * mult
	mods.hpMult  = (mods.hpMult or 1) * acct.hpMult * mult
	for k, v in pairs(acct) do
		if k ~= "atkMult" and k ~= "hpMult" then
			if MULT_KEYS[k] then
				mods[k] = (mods[k] or 1) * v
			elseif BOOL_KEYS[k] then
				mods[k] = mods[k] or v
			else
				mods[k] = (mods[k] or 0) + v
			end
		end
	end
	return mods
end

return AccountService
