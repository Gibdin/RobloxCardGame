-- Friends-only pack gifting. Scoped to friends currently in the same server
-- (via Player:IsFriendsWith, which checks real Roblox friendship — no
-- separate friend-list fetch/pagination needed) rather than a full
-- GetFriendsAsync roster, since a gift is granted instantly to an online
-- recipient rather than queued as a persistent mailbox entry. Simpler MVP
-- scope; a cross-session gift mailbox can be added later if needed.

local Players = game:GetService("Players")
local InventoryService = require(script.Parent.InventoryService)

local FriendsService = {}

-- Friends of `userId` who are currently in this server.
function FriendsService:GetFriendsInServer(userId)
	local list = {}
	local me = Players:GetPlayerByUserId(userId)
	if not me then return list end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId ~= userId then
			local ok, areFriends = pcall(function()
				return me:IsFriendsWith(player.UserId)
			end)
			if ok and areFriends then
				table.insert(list, { userId = player.UserId, name = player.Name })
			end
		end
	end
	return list
end

-- Returns (true, nil) on success or (false, errMsg). One gift total per day
-- (InventoryService:ClaimDailyGift), regardless of how many friends the
-- player has — the simplest possible bound against alt-farming.
function FriendsService:GiftPack(fromUserId, toUserId)
	if fromUserId == toUserId then
		return false, "You can't gift yourself."
	end

	local fromPlayer = Players:GetPlayerByUserId(fromUserId)
	local toPlayer = Players:GetPlayerByUserId(toUserId)
	if not fromPlayer or not toPlayer then
		return false, "That player isn't in this server."
	end

	local ok, areFriends = pcall(function()
		return fromPlayer:IsFriendsWith(toUserId)
	end)
	if not ok or not areFriends then
		return false, "You can only gift packs to friends."
	end

	if not InventoryService:ClaimDailyGift(fromUserId) then
		return false, "You've already sent a gift today."
	end

	InventoryService:AddPack(toUserId, "StandardPack", 1)
	return true, nil
end

return FriendsService
