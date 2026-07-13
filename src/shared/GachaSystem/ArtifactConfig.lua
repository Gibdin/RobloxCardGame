-- Permanent, account-persistent Artifacts — the first power progression
-- beyond card collection itself. Granted one at a time, in this fixed order,
-- on each successful Prestige rebirth (see PrestigeService:Prestige) —
-- deterministic unlock order rather than random, so players always know
-- what's coming next. Effects use the same key shape BattleEngine.BuildUnit's
-- mods table expects (mirrors the precedent already set by DungeonConfig.Items).
--
-- Only one Artifact can be equipped at a time (mirrors CosmeticConfig's
-- one-equipped-Trail-at-a-time pattern) — kept simple rather than building a
-- multi-slot loadout system for this pass.

local ArtifactConfig = {}

ArtifactConfig.Order = {
	{ id = "ember_core",     name = "Ember Core",      desc = "+4% ATK, account-wide.",                 effects = { atkMult = 1.04 } },
	{ id = "aegis_shard",    name = "Aegis Shard",     desc = "+4% Max HP, account-wide.",              effects = { hpMult = 1.04 } },
	{ id = "swift_band",     name = "Swift Band",      desc = "+6% MP gain, account-wide.",             effects = { mpGainMult = 1.06 } },
	{ id = "vampiric_idol",  name = "Vampiric Idol",   desc = "+3% lifesteal, account-wide.",           effects = { lifestealPct = 0.03 } },
	{ id = "guardian_plate", name = "Guardian Plate",  desc = "Reflect 5% of damage taken, account-wide.", effects = { reflectPct = 0.05 } },
	{ id = "crit_lens",      name = "Crit Lens",       desc = "+5% crit chance, account-wide.",         effects = { critChanceBonus = 0.05 } },
	{ id = "phoenix_ember",  name = "Phoenix Ember",   desc = "Revive once per battle, account-wide.",  effects = { reviveOnce = true } },
	{ id = "sovereign_crown",name = "Sovereign Crown", desc = "+6% ATK and Max HP, account-wide.",      effects = { atkMult = 1.06, hpMult = 1.06 } },
}

return ArtifactConfig
