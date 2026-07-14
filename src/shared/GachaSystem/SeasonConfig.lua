-- Time-boxed seasonal event calendar (Phase 9 — the real scheduler this file
-- was originally stubbed for). Deliberately NOT a new mechanic — a season
-- doesn't add card content or combat systems (that's card-design depth work,
-- explicitly deferred per GameDesign.md's Phase 9 note); it's a thin overlay
-- that can (a) pin a specific banner for its whole window instead of the
-- normal weekly rotation, for a themed promotional push, and (b) label the
-- storefront/quest panel with a name + countdown so there's always something
-- visibly "happening" for live-ops purposes.

local SeasonConfig = {}

SeasonConfig.Seasons = {
	{
		id        = "season_launch",
		name      = "Launch Celebration",
		startTime = 1751328000,              -- matches MonetizationConfig.BannerRotation's epoch
		endTime   = 1751328000 + 30 * 86400,  -- 30-day season
		pinnedBannerId = nil,                 -- nil = defer to the normal weekly BannerRotation
	},
}

-- Returns the currently active season definition, or nil if between seasons.
function SeasonConfig:GetCurrentSeason()
	local now = os.time()
	for _, season in ipairs(self.Seasons) do
		if now >= season.startTime and now < season.endTime then
			return season
		end
	end
	return nil
end

-- Returns a banner id to force for the whole season, or nil to defer to the
-- normal weekly BannerRotation (see BannerService:GetActiveBanner).
function SeasonConfig:GetPinnedBannerId()
	local season = self:GetCurrentSeason()
	return season and season.pinnedBannerId or nil
end

return SeasonConfig
