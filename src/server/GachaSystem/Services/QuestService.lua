-- Daily/weekly quest tracking, login-streak rewards, and the Battle Pass XP
-- feed. Quest state lives on InventoryService's per-player blob (via
-- GetQuestData) rather than a separate injected cache like Pity/Banner —
-- QuestService needs to grant rewards through InventoryService, and having
-- InventoryService also depend back on QuestService for persistence would be
-- a circular require.
--
-- Day/week bucketing uses integer day-counts (os.time() // 86400), never
-- date-string parsing — simpler and avoids any assumption about os.date's
-- table-format support.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("QuestConfig"))
local InventoryService = require(script.Parent.InventoryService)

local QuestService = {}

local SECONDS_PER_DAY = 86400

local function currentDay()
	return os.time() // SECONDS_PER_DAY
end

local function currentWeek()
	return currentDay() // 7
end

local function poolById(pool)
	local byId = {}
	for _, q in ipairs(pool) do byId[q.id] = q end
	return byId
end

local dailyById  = poolById(QuestConfig.DailyPool)
local weeklyById = poolById(QuestConfig.WeeklyPool)

-- Picks `count` unique quest ids from `pool` via partial Fisher-Yates.
local function pickRandom(pool, count, rng)
	local indices = {}
	for i = 1, #pool do indices[i] = i end
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local picked = {}
	for i = 1, math.min(count, #pool) do
		table.insert(picked, pool[indices[i]].id)
	end
	return picked
end

local function grantReward(userId, reward)
	if not reward then return end
	if reward.gems then InventoryService:AddGems(userId, reward.gems) end
	if reward.packs then
		for packType, n in pairs(reward.packs) do
			InventoryService:AddPack(userId, packType, n)
		end
	end
end

-- Rerolls daily/weekly quests if the day/week has rolled over, and advances
-- (or resets) the login streak. Idempotent — safe to call before every quest
-- read/write, matching InventoryService's own lazy-load-on-access pattern.
function QuestService:EnsureFresh(userId)
	local quests = InventoryService:GetQuestData(userId)
	local day, week = currentDay(), currentWeek()

	if quests.daily.day ~= day then
		quests.daily.day = day
		quests.daily.active = pickRandom(QuestConfig.DailyPool, QuestConfig.DailyCount, Random.new(userId + day))
		quests.daily.progress = {}
		quests.daily.claimed = {}
	end

	if quests.weekly.week ~= week then
		quests.weekly.week = week
		quests.weekly.active = pickRandom(QuestConfig.WeeklyPool, QuestConfig.WeeklyCount, Random.new(userId + week * 7))
		quests.weekly.progress = {}
		quests.weekly.claimed = {}
	end

	local streak = quests.loginStreak
	if streak.lastLoginDay ~= day then
		if streak.lastLoginDay == day - 1 then
			streak.streak = streak.streak + 1
		else
			streak.streak = 1
		end
		streak.lastLoginDay = day
		streak.claimedToday = false
	end
end

-- Called from PackService/DungeonService/TowerService whenever a trackable
-- action happens. eventType must match a QuestConfig quest `type` /
-- BattlePassXp key (pack_open, battle_win, dungeon_node, dungeon_boss, tower_floor).
function QuestService:RecordProgress(userId, eventType, amount)
	amount = amount or 1
	self:EnsureFresh(userId)
	local quests = InventoryService:GetQuestData(userId)

	local function bump(scope, pool)
		for _, qid in ipairs(scope.active) do
			local qdef = pool[qid]
			if qdef and qdef.type == eventType and not scope.claimed[qid] then
				scope.progress[qid] = math.min(qdef.target, (scope.progress[qid] or 0) + amount)
			end
		end
	end
	bump(quests.daily, dailyById)
	bump(quests.weekly, weeklyById)

	local xpPer = QuestConfig.BattlePassXp[eventType]
	if xpPer then
		InventoryService:AddBattlePassXp(userId, xpPer * amount)
	end
end

-- scope: "daily" | "weekly". Returns (true) or (false, errMsg).
function QuestService:ClaimQuest(userId, scope, questId)
	self:EnsureFresh(userId)
	local quests = InventoryService:GetQuestData(userId)
	local bucket = quests[scope]
	local pool = scope == "daily" and dailyById or (scope == "weekly" and weeklyById or nil)
	if not bucket or not pool then return false, "Unknown scope." end

	local isActive = false
	for _, qid in ipairs(bucket.active) do
		if qid == questId then isActive = true; break end
	end
	if not isActive then return false, "That quest isn't active." end
	if bucket.claimed[questId] then return false, "Already claimed." end

	local qdef = pool[questId]
	if not qdef then return false, "Unknown quest." end
	if (bucket.progress[questId] or 0) < qdef.target then return false, "Not complete yet." end

	bucket.claimed[questId] = true
	grantReward(userId, qdef.reward)
	return true
end

function QuestService:ClaimLoginStreak(userId)
	self:EnsureFresh(userId)
	local quests = InventoryService:GetQuestData(userId)
	local streak = quests.loginStreak
	if streak.claimedToday then return false, "Already claimed today." end

	local dayInCycle = ((streak.streak - 1) % 7) + 1
	local def = QuestConfig.LoginStreak[dayInCycle]
	streak.claimedToday = true
	grantReward(userId, def.reward)
	return true
end

-- Full state + pool definitions for the client to render without a second remote.
function QuestService:GetState(userId)
	self:EnsureFresh(userId)
	local quests = InventoryService:GetQuestData(userId)
	return {
		daily          = quests.daily,
		weekly         = quests.weekly,
		loginStreak    = quests.loginStreak,
		dailyPool      = QuestConfig.DailyPool,
		weeklyPool     = QuestConfig.WeeklyPool,
		streakCalendar = QuestConfig.LoginStreak,
		battlePass     = InventoryService:GetBattlePass(userId),
	}
end

return QuestService
