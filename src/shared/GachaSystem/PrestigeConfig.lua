-- Endless Tower "rebirth": turns the Tower's existing exponential-past-25
-- eventual-loss design (TowerConfig.StatMult) into a positive endgame payoff
-- instead of a dead end. Reaching MinFloorToPrestige lets a player cash in
-- their current climb for a permanent account-wide stat multiplier and the
-- next Artifact in ArtifactConfig.Order.

local PrestigeConfig = {}

PrestigeConfig.MinFloorToPrestige = 30

-- One entry in ArtifactConfig.Order is granted per rebirth, so this should
-- track #ArtifactConfig.Order — kept as an explicit number (rather than
-- computed from the other config) so the cap is visible at a glance here.
PrestigeConfig.MaxPrestige = 8

-- Permanent, stacking, applied account-wide via PrestigeService:GetPrestigeMult.
PrestigeConfig.MultPerRebirth = 0.05

-- Account XP granted immediately on a successful Prestige (on top of the
-- Artifact reward) — a rebirth is a big enough moment to be worth a bonus.
PrestigeConfig.XpReward = 500

return PrestigeConfig
