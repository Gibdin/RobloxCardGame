-- Guild create/join/leave, chat, and shared level/XP progression unlocking a
-- guild-wide Gem-reward buff. Guild entities live in their own DataStore
-- (separate from InventoryService's per-player blob — a guild is a shared
-- object multiple players mutate, not a single player's data).
--
-- Storage shape: each guild is its own key ("g_"..id) so entities don't share
-- a growing single blob as guild count scales. A lightweight "index" key
-- holds just {id, name, level, memberCount} for browsing without fetching
-- every guild. This is MVP-scope: no cross-server locking on the index
-- read-modify-write, so two servers creating a guild in the same instant
-- could theoretically race — acceptable at this scale (see GameDesign.md
-- Phase 7 notes), same risk class InventoryService already accepts elsewhere.
--
-- Chat is in-memory only per server (GuildConfig.MaxChatLog ring buffer) —
-- not persisted, resets on server restart, doesn't cross server boundaries.
-- Every message is passed through TextService:FilterStringAsync before
-- broadcast (Roblox Trust & Safety requirement for user-generated text).

local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuildConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("GuildConfig"))

local InventoryService = require(script.Parent.InventoryService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local GuildService = {}

local store
pcall(function()
	store = DataStoreService:GetDataStore("Guilds_v1")
end)

-- In-memory cache — write-through on structural mutations. Falls back
-- gracefully (in-memory only) if DataStoreService is unavailable, same
-- pattern as InventoryService's Studio-execute_luau fallback.
local guilds = {}       -- [id] = entity
local index  = nil      -- { nextId = N, list = { {id,name,level,memberCount}, ... } }
local chatLog = {}      -- [id] = { {userId,name,text,ts}, ... }
local indexDirty = false

local function loadIndex()
	if index then return index end
	local ok, data = pcall(function()
		return store and store:GetAsync("index")
	end)
	index = (ok and data) or { nextId = 0, list = {} }
	return index
end

-- Immediate write — only used for structural changes (create/join/leave),
-- which are rare relative to XP contributions. Frequent per-win updates
-- (updateIndexEntry, below) mark the index dirty instead and let the
-- periodic flush loop persist it, so a Guild Wars event with many
-- concurrent duel wins doesn't hammer the DataStore write budget with a
-- full-index SetAsync on every single win.
local function saveIndexNow()
	if not store then return end
	pcall(function()
		store:SetAsync("index", index)
	end)
	indexDirty = false
end

local FLUSH_INTERVAL = 60 -- seconds
task.spawn(function()
	while true do
		task.wait(FLUSH_INTERVAL)
		if indexDirty then
			saveIndexNow()
		end
	end
end)

local function loadGuild(id)
	if guilds[id] then return guilds[id] end
	local ok, data = pcall(function()
		return store and store:GetAsync("g_" .. id)
	end)
	if ok and data then
		guilds[id] = data
		return data
	end
	return nil
end

local function saveGuild(entity)
	guilds[entity.id] = entity
	if not store then return end
	pcall(function()
		store:SetAsync("g_" .. entity.id, entity)
	end)
end

local function resolveName(userId)
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return (ok and name) or ("Player#" .. userId)
end

local function levelForXP(xp)
	local level = 1
	for i, threshold in ipairs(GuildConfig.LevelXP) do
		if xp >= threshold then level = i end
	end
	return level
end

-- `immediate`: structural changes (create/join/leave — rare) pass true to
-- persist right away; high-frequency callers (ContributeXP, once per win)
-- leave it false and just mark the index dirty for the periodic flush loop.
local function updateIndexEntry(entity, immediate)
	local idx = loadIndex()
	local memberCount = 0
	for _ in pairs(entity.members) do memberCount = memberCount + 1 end
	for _, e in ipairs(idx.list) do
		if e.id == entity.id then
			e.name, e.level, e.memberCount, e.warScore = entity.name, entity.level, memberCount, entity.warScore
			if immediate then saveIndexNow() else indexDirty = true end
			return
		end
	end
	table.insert(idx.list, { id = entity.id, name = entity.name, level = entity.level, memberCount = memberCount, warScore = entity.warScore })
	if immediate then saveIndexNow() else indexDirty = true end
end

local function removeIndexEntry(id)
	local idx = loadIndex()
	for i, e in ipairs(idx.list) do
		if e.id == id then table.remove(idx.list, i); break end
	end
	saveIndexNow()
end

local function nameTaken(name)
	local idx = loadIndex()
	local lower = string.lower(name)
	for _, e in ipairs(idx.list) do
		if string.lower(e.name) == lower then return true end
	end
	return false
end

-- Returns (guild, nil) on success or (nil, errMsg).
function GuildService:CreateGuild(userId, name)
	if InventoryService:GetGuildId(userId) then
		return nil, "You're already in a guild — leave it first."
	end

	name = string.gsub(name or "", "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if #name < GuildConfig.MinNameLength or #name > GuildConfig.MaxNameLength then
		return nil, string.format("Guild name must be %d-%d characters.", GuildConfig.MinNameLength, GuildConfig.MaxNameLength)
	end
	if not string.match(name, "^[%w%s]+$") then
		return nil, "Guild names may only contain letters, numbers, and spaces."
	end
	if nameTaken(name) then
		return nil, "That guild name is already taken."
	end

	-- Guild names are player-chosen text visible to every other player in the
	-- game (browse list, hub hall, etc.) — the same Trust & Safety filtering
	-- requirement as chat messages, just applied once at creation instead of
	-- per-message.
	local filterOk, filteredName = pcall(function()
		local result = TextService:FilterStringAsync(name, userId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not filterOk then
		return nil, "Couldn't validate that name right now — try again."
	end
	name = filteredName

	local idx = loadIndex()
	idx.nextId = idx.nextId + 1
	local id = idx.nextId

	local entity = {
		id = id,
		name = name,
		ownerUserId = userId,
		members = { [tostring(userId)] = true },
		memberList = { userId },
		xp = 0,
		level = 1,
		warScore = 0,
		createdAt = os.time(),
	}
	saveGuild(entity)
	updateIndexEntry(entity, true)
	InventoryService:SetGuildId(userId, id)
	AnalyticsService:LogGuildActivity(Players:GetPlayerByUserId(userId), "create", id)
	return entity, nil
end

function GuildService:JoinGuild(userId, guildId)
	if InventoryService:GetGuildId(userId) then
		return false, "You're already in a guild — leave it first."
	end
	local entity = loadGuild(guildId)
	if not entity then return false, "Guild not found." end

	local memberCount = 0
	for _ in pairs(entity.members) do memberCount = memberCount + 1 end
	if memberCount >= GuildConfig.MaxMembers then
		return false, "That guild is full."
	end

	entity.members[tostring(userId)] = true
	table.insert(entity.memberList, userId)
	saveGuild(entity)
	updateIndexEntry(entity, true)
	InventoryService:SetGuildId(userId, guildId)
	AnalyticsService:LogGuildActivity(Players:GetPlayerByUserId(userId), "join", guildId)
	return true, nil
end

function GuildService:LeaveGuild(userId)
	local guildId = InventoryService:GetGuildId(userId)
	if not guildId then return end
	local entity = loadGuild(guildId)
	InventoryService:SetGuildId(userId, nil)
	if not entity then return end

	entity.members[tostring(userId)] = nil
	for i = #entity.memberList, 1, -1 do
		if entity.memberList[i] == userId then table.remove(entity.memberList, i) end
	end

	local remaining = 0
	for _ in pairs(entity.members) do remaining = remaining + 1 end
	if remaining == 0 then
		guilds[guildId] = nil
		chatLog[guildId] = nil
		removeIndexEntry(guildId)
		if store then pcall(function() store:RemoveAsync("g_" .. guildId) end) end
		return
	end

	if entity.ownerUserId == userId then
		entity.ownerUserId = entity.memberList[1]
	end
	saveGuild(entity)
	updateIndexEntry(entity, true)
end

-- Returns a display-friendly snapshot (member names resolved) or nil.
function GuildService:GetMyGuild(userId)
	local guildId = InventoryService:GetGuildId(userId)
	if not guildId then return nil end
	local entity = loadGuild(guildId)
	if not entity then return nil end

	local members = {}
	for _, id in ipairs(entity.memberList) do
		table.insert(members, { userId = id, name = resolveName(id), isOwner = id == entity.ownerUserId })
	end

	local nextXP = GuildConfig.LevelXP[entity.level + 1]
	return {
		id = entity.id, name = entity.name, level = entity.level, xp = entity.xp,
		nextLevelXP = nextXP, warScore = entity.warScore,
		ownerUserId = entity.ownerUserId, members = members,
	}
end

function GuildService:ListGuilds()
	local idx = loadIndex()
	local list = {}
	for _, e in ipairs(idx.list) do
		table.insert(list, { id = e.id, name = e.name, level = e.level, memberCount = e.memberCount })
	end
	return list
end

-- Guild Wars ranking: guilds sorted by warScore (cumulative live-duel wins
-- credited to the winner's guild — see DuelMatchmakingService's resolveDuel
-- hook). Kept entirely inside GuildService rather than LeaderboardService,
-- since LeaderboardService's resolveName assumes userId keys and a guild id
-- isn't a real Roblox user.
function GuildService:GetGuildWarLeaderboard(n)
	local idx = loadIndex()
	local list = {}
	for _, e in ipairs(idx.list) do
		table.insert(list, { id = e.id, name = e.name, level = e.level, warScore = e.warScore or 0 })
	end
	table.sort(list, function(a, b) return a.warScore > b.warScore end)
	local top = {}
	for i = 1, math.min(n or 20, #list) do table.insert(top, list[i]) end
	return top
end

-- Credits XP to a member's guild (no-op if they aren't in one). Used by
-- Dungeon/Tower win hooks (GuildConfig.XPPerPvEWin) and live duel wins
-- (GuildConfig.XPPerDuelWin), the latter also bumping warScore for Guild Wars.
function GuildService:ContributeXP(userId, amount, isDuelWin)
	local guildId = InventoryService:GetGuildId(userId)
	if not guildId then return end
	local entity = loadGuild(guildId)
	if not entity then return end

	entity.xp = entity.xp + amount
	entity.level = levelForXP(entity.xp)
	if isDuelWin then
		entity.warScore = entity.warScore + 1
	end
	saveGuild(entity)
	updateIndexEntry(entity)
end

-- Gem-reward multiplier from the member's guild level (1.0 if not in a
-- guild). First real effect of guild progression — applied at PvP reward
-- grant sites rather than inside InventoryService, to avoid a circular
-- require (GuildService already depends on InventoryService for guildId).
function GuildService:GetGuildBuffMultiplier(userId)
	local guildId = InventoryService:GetGuildId(userId)
	if not guildId then return 1 end
	local entity = loadGuild(guildId)
	if not entity then return 1 end
	return 1 + (entity.level * GuildConfig.BuffPerLevel)
end

function GuildService:SendChatMessage(userId, text)
	local guildId = InventoryService:GetGuildId(userId)
	if not guildId then return false, "You're not in a guild." end
	if type(text) ~= "string" or #text == 0 then return false, "Message can't be empty." end
	if #text > GuildConfig.MaxChatLength then return false, "Message too long." end

	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, userId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then return false, "Message couldn't be sent right now." end

	local log = chatLog[guildId]
	if not log then
		log = {}
		chatLog[guildId] = log
	end
	table.insert(log, 1, { userId = userId, name = resolveName(userId), text = filtered, ts = os.time() })
	while #log > GuildConfig.MaxChatLog do
		table.remove(log)
	end
	return true, nil
end

function GuildService:GetChatLog(userId)
	local guildId = InventoryService:GetGuildId(userId)
	if not guildId then return {} end
	local log = chatLog[guildId] or {}
	-- Return oldest-first for display.
	local ordered = {}
	for i = #log, 1, -1 do table.insert(ordered, log[i]) end
	return ordered
end

return GuildService
