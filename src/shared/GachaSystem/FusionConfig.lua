-- Fusion: spare card copies level up the cards you play (+0 to +10).
-- Shared by the server (which validates and applies a fuse) and the client
-- (which previews the cost, shows the "can fuse" dot and the Fuse button), so
-- both always agree. Design: AnimeRosterPlan.md §11.9.
--
-- Rules:
--   * Reaching +N costs N points of same-rarity fuel.
--   * A spare copy of the SAME card is worth 2 points; any other spare of the
--     same rarity is worth 1.
--   * +5 and +10 are milestones: they need at least one real copy of the card.
--   * Each level adds StatPerLevel of the card's base ATK and HP.

local FusionConfig = {}

FusionConfig.MaxLevel        = 10
FusionConfig.StatPerLevel    = 0.05
FusionConfig.CopyPoints      = 2
FusionConfig.OtherPoints     = 1
FusionConfig.MilestoneLevels = { [5] = true, [10] = true }

-- Points needed to go from level-1 to `level`.
function FusionConfig.CostForLevel(level)
	return level
end

-- Stat multiplier for a fusion level.
function FusionConfig.StatMult(level)
	return 1 + FusionConfig.StatPerLevel * (level or 0)
end

-- Fused stat as shown in the UI: the card's (already rounded) base stat,
-- scaled, and rounded to the nearest 10 like every other stat.
function FusionConfig.FusedStat(base, level)
	if not level or level <= 0 then return base end
	return math.max(10, math.floor(base * FusionConfig.StatMult(level) / 10 + 0.5) * 10)
end

-- Works out which spares a fuse of `card` (currently at `level`) would spend.
--   spares: { [cardIdString] = count } for the player
--   cardDb: CardDatabase
-- Returns plan, nil on success, where plan = {
--   nextLevel, cost, points,
--   copies = n            -- spare copies of this card spent
--   others = { [idString] = n },  -- other same-rarity spares spent
-- }
-- or nil, reason (a short player-facing sentence) when it isn't possible.
function FusionConfig.Plan(card, level, spares, cardDb)
	level = level or 0
	if level >= FusionConfig.MaxLevel then
		return nil, "Max level reached!"
	end
	local nextLevel = level + 1
	local cost = FusionConfig.CostForLevel(nextLevel)
	local ownKey = tostring(card.id)
	local ownCopies = spares[ownKey] or 0

	-- Other same-rarity spares, most plentiful first (spend what you have
	-- the most of), ties broken by id so the plan is deterministic.
	local others = {}
	for key, n in pairs(spares) do
		if key ~= ownKey and n > 0 then
			local other = cardDb:GetById(tonumber(key))
			if other and other.rarity == card.rarity and not other.adminOnly then
				table.insert(others, { key = key, n = n })
			end
		end
	end
	table.sort(others, function(a, b)
		if a.n ~= b.n then return a.n > b.n end
		return a.key < b.key
	end)

	local plan = { nextLevel = nextLevel, cost = cost, points = 0, copies = 0, others = {} }

	-- Milestones need one real copy, spent first.
	if FusionConfig.MilestoneLevels[nextLevel] then
		if ownCopies < 1 then
			return nil, "Needs a spare copy of " .. card.name .. " to reach +" .. nextLevel .. "."
		end
		plan.copies = 1
		plan.points = FusionConfig.CopyPoints
	end

	-- Then other same-rarity spares, 1 point each.
	for _, entry in ipairs(others) do
		if plan.points >= cost then break end
		local take = math.min(entry.n, cost - plan.points)
		plan.others[entry.key] = take
		plan.points = plan.points + take * FusionConfig.OtherPoints
	end

	-- Real copies last (2 points each; may overshoot by 1).
	while plan.points < cost and plan.copies < ownCopies do
		plan.copies = plan.copies + 1
		plan.points = plan.points + FusionConfig.CopyPoints
	end

	if plan.points < cost then
		local missing = cost - plan.points
		return nil, ("Needs %d more %s spare%s."):format(missing, card.rarity, missing == 1 and "" or "s")
	end
	return plan, nil
end

return FusionConfig
