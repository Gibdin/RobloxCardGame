-- Current season identity — a lightweight marker, not a live scheduler.
-- Automated banner/quest rotation on a cadence is Phase 9 (content-scaling)
-- work; for now this just names "which season we're in" so the Battle Pass
-- and banner system have something stable to key off of, updated by hand
-- when a new season starts.

local SeasonConfig = {}

SeasonConfig.Current = {
	id   = "season_1",
	name = "Launch Season",
}

return SeasonConfig
