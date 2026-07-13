-- Two-player card-for-card trading. Offers are in-memory only (not
-- persisted) — an offer lost on server restart is an acceptable MVP
-- tradeoff, the same call already made for GuildService's chat log; nothing
-- valuable is at risk until RespondToTrade actually swaps cards, which IS
-- persisted (via InventoryService).
--
-- Anti-abuse guardrails: rarity ceiling (TradeConfig.MaxTradeableRarityOrder,
-- excludes Epic+ from ever changing hands), a post-trade cooldown per player,
-- and re-validating BOTH sides' ownership at accept time (not just propose
-- time) — a card offered in two pending trades simultaneously just fails the
-- second accept instead of duplicating or silently no-opping.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gachaShared = ReplicatedStorage:WaitForChild("GachaSystem")
local CardDatabase = require(gachaShared:WaitForChild("CardDatabase"))
local RarityConfig = require(gachaShared:WaitForChild("RarityConfig"))
local TradeConfig  = require(gachaShared:WaitForChild("TradeConfig"))

local InventoryService = require(script.Parent.InventoryService)

local TradeService = {}

local offers = {}       -- [id] = { id, fromUserId, toUserId, offerCardId, requestCardId, createdAt, status }
local offerOrder = {}   -- ordered ids, oldest first
local nextOfferId = 1

local function isExpired(offer)
	return os.time() - offer.createdAt > TradeConfig.OfferExpirySeconds
end

local function isTradeable(cardId)
	local card = CardDatabase:GetById(cardId)
	if not card then return false end
	return RarityConfig:GetOrder(card.rarity) <= TradeConfig.MaxTradeableRarityOrder
end

local function countOutgoing(userId)
	local n = 0
	for _, id in ipairs(offerOrder) do
		local o = offers[id]
		if o and o.status == "pending" and o.fromUserId == userId and not isExpired(o) then
			n = n + 1
		end
	end
	return n
end

local function cooldownRemaining(userId)
	local last = InventoryService:GetLastTradeAt(userId)
	local remaining = TradeConfig.CooldownSeconds - (os.time() - last)
	return math.max(0, remaining)
end

-- Returns (offer, nil) on success or (nil, errMsg).
function TradeService:ProposeTrade(fromUserId, toUserId, offerCardId, requestCardId)
	if fromUserId == toUserId then
		return nil, "You can't trade with yourself."
	end
	if cooldownRemaining(fromUserId) > 0 then
		return nil, string.format("Trade on cooldown (%ds left).", cooldownRemaining(fromUserId))
	end
	if not InventoryService:OwnsCard(fromUserId, offerCardId) then
		return nil, "You don't own that card."
	end
	if not InventoryService:OwnsCard(toUserId, requestCardId) then
		return nil, "They don't own that card."
	end
	if not isTradeable(offerCardId) or not isTradeable(requestCardId) then
		return nil, "Only Common/Uncommon/Rare cards can be traded."
	end
	if countOutgoing(fromUserId) >= TradeConfig.MaxOutgoingOffers then
		return nil, "You have too many pending trade offers already."
	end

	local offer = {
		id = nextOfferId,
		fromUserId = fromUserId,
		toUserId = toUserId,
		offerCardId = offerCardId,
		requestCardId = requestCardId,
		createdAt = os.time(),
		status = "pending",
	}
	offers[offer.id] = offer
	table.insert(offerOrder, offer.id)
	nextOfferId = nextOfferId + 1
	return offer, nil
end

local function describe(offer)
	local offerCard = CardDatabase:GetById(offer.offerCardId)
	local requestCard = CardDatabase:GetById(offer.requestCardId)
	return {
		id = offer.id,
		fromUserId = offer.fromUserId,
		toUserId = offer.toUserId,
		offerCardId = offer.offerCardId,
		offerCardName = offerCard and offerCard.name or "Unknown",
		requestCardId = offer.requestCardId,
		requestCardName = requestCard and requestCard.name or "Unknown",
		createdAt = offer.createdAt,
	}
end

function TradeService:GetIncomingOffers(userId)
	local list = {}
	for _, id in ipairs(offerOrder) do
		local o = offers[id]
		if o and o.status == "pending" and o.toUserId == userId and not isExpired(o) then
			table.insert(list, describe(o))
		end
	end
	return list
end

function TradeService:GetOutgoingOffers(userId)
	local list = {}
	for _, id in ipairs(offerOrder) do
		local o = offers[id]
		if o and o.status == "pending" and o.fromUserId == userId and not isExpired(o) then
			table.insert(list, describe(o))
		end
	end
	return list
end

function TradeService:CancelTrade(userId, offerId)
	local o = offers[offerId]
	if not o or o.status ~= "pending" or o.fromUserId ~= userId then return false end
	o.status = "cancelled"
	return true
end

-- Returns (true, nil) on a completed swap or (false, errMsg).
function TradeService:RespondToTrade(userId, offerId, accept)
	local o = offers[offerId]
	if not o or o.status ~= "pending" or o.toUserId ~= userId then
		return false, "Trade offer not found."
	end
	if isExpired(o) then
		o.status = "expired"
		return false, "That trade offer expired."
	end
	if not accept then
		o.status = "declined"
		return true, nil
	end

	-- Re-validate everything at accept time — state may have changed since
	-- the offer was proposed (card traded/removed elsewhere, cooldown hit).
	if not InventoryService:OwnsCard(o.fromUserId, o.offerCardId) then
		o.status = "invalid"
		return false, "The offered card is no longer available."
	end
	if not InventoryService:OwnsCard(o.toUserId, o.requestCardId) then
		o.status = "invalid"
		return false, "You no longer own the requested card."
	end
	if cooldownRemaining(o.fromUserId) > 0 or cooldownRemaining(o.toUserId) > 0 then
		return false, "One of you is on trade cooldown."
	end

	InventoryService:RemoveCard(o.fromUserId, o.offerCardId)
	InventoryService:RemoveCard(o.toUserId, o.requestCardId)
	InventoryService:AddCard(o.fromUserId, o.requestCardId)
	InventoryService:AddCard(o.toUserId, o.offerCardId)

	local now = os.time()
	InventoryService:SetLastTradeAt(o.fromUserId, now)
	InventoryService:SetLastTradeAt(o.toUserId, now)
	InventoryService:AddTradeHistoryEntry(o.fromUserId, {
		ts = now, withUserId = o.toUserId, gaveCardId = o.offerCardId, gotCardId = o.requestCardId,
	})
	InventoryService:AddTradeHistoryEntry(o.toUserId, {
		ts = now, withUserId = o.fromUserId, gaveCardId = o.requestCardId, gotCardId = o.offerCardId,
	})

	o.status = "completed"
	return true, nil
end

return TradeService
