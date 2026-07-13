-- Global leaderboards backed by OrderedDataStore. Boards are looked up by
-- name (see BOARDS below); Phase 5 will add a PvP rating board here the same
-- way. Player names are resolved at read time via Players:GetNameFromUserIdAsync
-- rather than stored alongside the score — one less thing that can drift out
-- of sync if a player renames, and it works for offline players too.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}

local BOARDS = {
	TowerBestFloor    = true,
	DungeonDeepestRow = true,
}

local stores = {}
local function getStore(board)
	if not BOARDS[board] then return nil end
	if not stores[board] then
		local ok, s = pcall(function()
			return DataStoreService:GetOrderedDataStore("Leaderboard_" .. board)
		end)
		stores[board] = ok and s or nil
	end
	return stores[board]
end

local function resolveName(userId)
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return (ok and name) or ("Player#" .. userId)
end

-- Only ever called when the caller already knows this is a new personal
-- best (mirrors InventoryService's own max-only ratchet semantics for
-- bestFloor/deepestRow) — no read-before-write needed.
function LeaderboardService:UpdateScore(userId, board, score)
	local store = getStore(board)
	if not store or type(score) ~= "number" then return end
	pcall(function()
		store:SetAsync(tostring(userId), score)
	end)
end

-- Returns { { userId, name, score }, ... } for the top `n` entries.
function LeaderboardService:GetTopN(board, n)
	local store = getStore(board)
	if not store then return {} end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, n)
	end)
	if not ok then return {} end

	local page = pages:GetCurrentPage()
	local result = {}
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		table.insert(result, { userId = userId, name = resolveName(userId), score = entry.value })
	end
	return result
end

-- The player's own recorded score on a board, or nil if they have none yet.
function LeaderboardService:GetPlayerScore(board, userId)
	local store = getStore(board)
	if not store then return nil end
	local ok, score = pcall(function()
		return store:GetAsync(tostring(userId))
	end)
	return ok and score or nil
end

return LeaderboardService
