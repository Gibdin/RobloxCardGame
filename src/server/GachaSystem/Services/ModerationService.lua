-- Lightweight abuse-report logging for user-generated text surfaces (guild
-- chat, guild names). Roblox Trust & Safety expects an in-experience way for
-- players to flag abusive content for human review even when content is
-- already filtered (filtering catches profanity/PII, not harassment or
-- context-dependent abuse) — this persists reports to their own capped
-- DataStore list, since there's no external moderation backend for this
-- project. A human (or a future admin tool) reads this list; nothing here
-- takes automated action against the reported player.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ModerationService = {}

local store
pcall(function()
	store = DataStoreService:GetDataStore("ModerationReports_v1")
end)

local MAX_REPORTS = 500
local cache -- lazy-loaded report list

local function loadReports()
	if cache then return cache end
	local ok, data = pcall(function()
		return store and store:GetAsync("reports")
	end)
	cache = (ok and data) or {}
	return cache
end

local function resolveName(userId)
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return (ok and name) or ("Player#" .. userId)
end

-- Logs an abuse report for later human review. `context` identifies which
-- surface it came from (e.g. "guild_chat", "guild_name").
function ModerationService:Report(reporterUserId, targetUserId, context, content)
	if reporterUserId == targetUserId then return false, "You can't report yourself." end

	local reports = loadReports()
	table.insert(reports, 1, {
		ts = os.time(),
		reporterUserId = reporterUserId, reporterName = resolveName(reporterUserId),
		targetUserId = targetUserId, targetName = resolveName(targetUserId),
		context = context, content = tostring(content or ""),
	})
	while #reports > MAX_REPORTS do
		table.remove(reports)
	end
	if store then
		pcall(function() store:SetAsync("reports", reports) end)
	end
	return true, nil
end

return ModerationService
