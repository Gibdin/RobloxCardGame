-- Two-player card trading constants and anti-abuse guardrails.
-- Trades are card-for-card only (no Gems/Gold side of a trade ever) — this
-- keeps the system entirely outside RMT-adjacent territory by construction.

local TradeConfig = {}

-- Highest tradeable rarity, by RarityConfig.order (Rare = 3). Epic+ (chase
-- content backing monetization/pity value) can never change hands, which
-- caps the RMT/dupe-account exploit value of any single trade.
TradeConfig.MaxTradeableRarityOrder = 3

-- Seconds a player must wait after completing a trade before starting
-- another — blunt rate-limit against rapid card-laundering between two
-- colluding accounts.
TradeConfig.CooldownSeconds = 300

-- A player may only have this many outgoing offers awaiting response at once.
TradeConfig.MaxOutgoingOffers = 3

-- Offers older than this auto-expire (checked lazily on read, not on a timer).
TradeConfig.OfferExpirySeconds = 86400 * 3

return TradeConfig
