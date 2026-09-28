-- Pure deterministic battle resolver.
-- No Roblox services beyond requiring shared config; all randomness comes from a
-- single Random.new(seed), so identical inputs + seed produce an identical event log.
-- The client never recomputes combat math: every mutating event carries the
-- resulting values (newHp / newShield / newMp).
--
-- Round order (this ordering IS the spec — changing it changes outcomes):
--   1. Round start: clear Shadow marks, reset per-round traits, regen
--      (Nature's Call T4 + item/buff regen)
--   2. Active casts: P side then E side, units in slot order, for any unit
--      whose mana already reached its cost (e.g. from ally mana grants)
--   3. Basic attacks: EVERY living P unit attacks the E frontline in slot
--      order, then every living E unit attacks the P frontline. Each swing
--      landed gives +1 mana and the ability fires the moment mana reaches
--      the cost. Stunned units skip their attack. Frontline = lowest-slot
--      living unit, so if a frontliner dies mid-phase, later attackers hit
--      the replacement.
--   4. Round end: Medic heals, win check
--
-- Card rules (mana, subroles, counters, traits): AnimeRosterPlan.md §11.
--
-- Revives: item-based reviveOnce and Divine Pantheon T4 (members, once per
-- battle, at revivePct of max HP) are both implemented in applyDamage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage:WaitForChild("GachaSystem"):WaitForChild("CombatConfig"))

local BattleEngine = {}

local Battle   = CombatConfig.Battle
local MPConf   = CombatConfig.MP
local Actives  = CombatConfig.Actives
local Passives = CombatConfig.Passives
local Counters = CombatConfig.Counters
local Traits   = CombatConfig.Traits

-- ── Team context helpers ──────────────────────────────────────────────────────

-- Highest satisfied synergy tier per series for an array of card defs.
-- Returns { [seriesName] = tierCount }.
function BattleEngine.ComputeSynergyTiers(cards)
	local counts = {}
	for _, card in ipairs(cards) do
		for _, s in ipairs(card.series or {}) do
			counts[s] = (counts[s] or 0) + 1
		end
	end
	local tiers = {}
	for series, n in pairs(counts) do
		local def = CombatConfig.Synergies[series]
		if def then
			local best
			for threshold in pairs(def) do
				if n >= threshold and (not best or threshold > best) then
					best = threshold
				end
			end
			if best then tiers[series] = best end
		end
	end
	return tiers
end

-- Role counts + synergy tiers for an array of card defs.
function BattleEngine.BuildTeamContext(cards)
	local roleCounts = { Tank = 0, DPS = 0, Support = 0 }
	for _, card in ipairs(cards) do
		if roleCounts[card.role] ~= nil then
			roleCounts[card.role] = roleCounts[card.role] + 1
		end
	end
	return {
		roleCounts   = roleCounts,
		synergyTiers = BattleEngine.ComputeSynergyTiers(cards),
	}
end

local function roleBonus(role, count)
	local tbl = CombatConfig.RoleBonuses[role]
	if not tbl or count <= 0 then return 0 end
	return tbl[math.min(count, #tbl)]
end

local function isMember(unit, series)
	for _, s in ipairs(unit.series) do
		if s == series then return true end
	end
	return false
end

-- ── Unit construction ─────────────────────────────────────────────────────────

-- Builds a UnitState from a card definition.
-- teamContext: from BuildTeamContext (role counts + synergy tiers of the unit's team).
-- mods: run-scoped modifiers (levels/items/buffs) from RunModifiers.Compute; all optional.
function BattleEngine.BuildUnit(card, slot, teamContext, mods)
	mods = mods or {}
	local tiers = teamContext.synergyTiers

	local atk = card.attack
	local hp  = card.hp
	if card.role == "DPS" then
		atk = atk * (1 + roleBonus("DPS", teamContext.roleCounts.DPS))
	elseif card.role == "Tank" then
		hp = hp * (1 + roleBonus("Tank", teamContext.roleCounts.Tank))
	end
	-- Member-only static synergy bonuses (+ATK / +MaxHP).
	for _, series in ipairs(card.series or {}) do
		local tier = tiers[series]
		local eff = tier and CombatConfig.Synergies[series][tier]
		if eff then
			atk = atk * (1 + (eff.atkPct or 0))
			hp  = hp * (1 + (eff.hpPct or 0))
		end
	end

	local statMult = mods.statMult or 1
	atk = math.floor(atk * statMult * (mods.atkMult or 1))
	hp  = math.floor(hp * statMult * (mods.hpMult or 1))

	-- Side-wide mana cost reduction (Void Walkers) applies to every unit on the team.
	local costReduction = 0
	for series, tier in pairs(tiers) do
		local eff = CombatConfig.Synergies[series] and CombatConfig.Synergies[series][tier]
		if eff and eff.manaCostReduction then
			costReduction = math.max(costReduction, eff.manaCostReduction)
		end
	end

	local critBonus = mods.critChanceBonus or 0
	if card.trait == "heavenly_restriction" then
		critBonus = critBonus + Traits.heavenly_restriction.critBonus
	end

	-- Per-card unique active (Legendary+ so far — see CardDatabase.lua). Cards
	-- without one fall back to the generic role-based active in castActive,
	-- unchanged from before this system existed.
	local activeSpec = card.active and card.active.effects
	local activeName = card.active and card.active.name
	local activeAlt  = card.active and card.active.alternate  -- { {name, effects}, ... } cycled per cast

	return {
		cardId  = card.id,
		slot    = slot,
		name    = card.name,
		role    = card.role,
		subrole = card.subrole,
		currentRole = card.role,  -- differs from role only for hybrid traits (three_cores)
		passive = card.passive,
		trait   = card.trait,
		series  = card.series or {},

		baseAtk = atk,
		maxHp   = hp,
		maxMp   = math.max(1, (card.mp or 3) - costReduction),  -- mana cost of the active

		hp     = math.clamp(mods.startHp or (mods.startHpPct and math.floor(mods.startHpPct * hp)) or hp, 1, hp),
		mp     = 0,
		shield = 0,
		alive  = true,
		pos     = slot,  -- targeting order; can change mid-battle (see front())
		stunned = 0,   -- turns of basic attacks to skip
		silenced = 0,  -- rounds this unit can't gain mana
		dots    = {},  -- damage over time: { perTick, rounds, trueDamage, srcSide, src, name }
		nails   = 0,   -- Resonance nails in this unit
		altIndex = 0,  -- which alternating technique fired last
		adapt   = {},  -- adaptation trait: hits taken per attacker key
		lastSwings = {},  -- final damage of the last two basic-attack swings (black_flash)

		activeSpec = activeSpec,
		activeName = activeName,
		activeAlt  = activeAlt,
		stackAtkBonus = 0,  -- permanent self ATK% from stack_atk_buff active steps

		rageStacks = 0,
		mods = {
			mpGainMult      = mods.mpGainMult or 1,
			critChanceBonus = critBonus,
			lifestealPct    = mods.lifestealPct or 0,
			reflectPct      = mods.reflectPct or 0,
			extraDR         = 1 - (mods.damageTakenMult or 1),
			activePowerMult = mods.activePowerMult or 1,
			executeBonusPct = mods.executeBonusPct or 0,
			regenPctPerRound = mods.regenPctPerRound or 0,
			lowHpAtkBonus   = mods.lowHpAtkBonus or 0,
			reviveOnce      = mods.reviveOnce or false,
		},
		flags = {
			survivedLethal = false, reviveUsed = false, synergyReviveUsed = false, marked = false,
			infinityUsed = false, rikaUsed = false,
		},
	}
end

-- ── Resolve internals ─────────────────────────────────────────────────────────

local function newSide(key, units)
	-- Merge active synergy tier effects into one side-wide table. Tier tables
	-- restate lower-tier values, and effect keys are unique across series, so a
	-- flat merge is safe. Member-only statics (atkPct/hpPct) were consumed in
	-- BuildUnit and are ignored here.
	local cardsLike = {}
	for _, u in ipairs(units) do
		table.insert(cardsLike, { series = u.series, role = u.role })
	end
	local ctx = BattleEngine.BuildTeamContext(cardsLike)
	local syn = {}
	for series, tier in pairs(ctx.synergyTiers) do
		for k, v in pairs(CombatConfig.Synergies[series][tier]) do
			syn[k] = v
		end
	end
	return {
		key = key,
		units = units,
		tiers = ctx.synergyTiers,
		syn = syn,
		effectiveness = roleBonus("Support", ctx.roleCounts.Support),
		tidalActive = false,
		markUsed = false,
		lowHpShieldUsed = false,  -- First Years T3, once per battle
		-- Stacking debuffs applied TO this side by an enemy's unique active
		-- (enemy_atk_shred / enemy_dr_shred) — distinct from synergy math above.
		customAtkDebuff = 0,
		customDrShred   = 0,
		-- Stacking team ATK buff from this side's own actives (team_atk_buff).
		customAtkBuff   = 0,
		castCount       = 0,    -- abilities this side has cast (Maximum Uzumaki)
		lastAllyCast    = nil,  -- { caster, name, steps } for Copy (Yuta)
	}
end

-- Role used for the counter cycle (hybrid traits swap it per round).
local function roleOf(unit)
	return unit.currentRole or unit.role
end

local function ref(side, unit)
	return { side = side.key, slot = unit.slot }
end

-- Targeting order uses `pos`, not `slot`: `slot` is the unit's permanent
-- identity (events, UI frames, post-battle XP), while `pos` can change when an
-- ability swaps positions (Boogie Woogie). Frontline = lowest living pos.
local function front(side)
	local best
	for _, u in ipairs(side.units) do
		if u.alive and (not best or u.pos < best.pos) then best = u end
	end
	return best
end

local function backline(side)
	local best
	for _, u in ipairs(side.units) do
		if u.alive and (not best or u.pos > best.pos) then best = u end
	end
	return best
end

-- Next living unit in line behind `target` (cleaves, chains).
local function nextInLine(side, target)
	local best
	for _, u in ipairs(side.units) do
		if u.alive and u ~= target and (not best or u.pos < best.pos) then best = u end
	end
	return best
end

local function defeated(side)
	return front(side) == nil
end

local function currentAtk(side, unit)
	local atk = unit.baseAtk
	if unit.rageStacks > 0 then
		atk = atk * (1 + Passives.Rage.atkPerStack * unit.rageStacks)
	end
	if unit.stackAtkBonus > 0 then
		atk = atk * (1 + unit.stackAtkBonus)
	end
	if side.tidalActive and isMember(unit, "Abyssal Order") then
		atk = atk * (1 + side.syn.tidalAtkPct)
	end
	if unit.mods.lowHpAtkBonus > 0 and unit.hp < 0.5 * unit.maxHp then
		atk = atk * (1 + unit.mods.lowHpAtkBonus)
	end
	if (side.customAtkBuff or 0) > 0 then
		atk = atk * (1 + side.customAtkBuff)
	end
	if unit.trait == "three_cores" and unit.currentRole == "DPS" then
		atk = atk * (1 + Traits.three_cores.gorillaAtk)
	end
	if (side.customAtkDebuff or 0) > 0 and unit.trait ~= "heavenly_restriction" then
		atk = atk * (1 - side.customAtkDebuff)
	end
	return atk
end

-- Mana is whole points on the card (unit.maxMp = ability cost); fractional
-- gain from mpGainMult items carries over between casts.
local function giveMp(unit, amount)
	unit.mp = unit.mp + amount * unit.mods.mpGainMult
end

-- Multiplier for effects cast by a Support: role stacking bonus, plus the
-- counter-cycle bonus while the enemy frontline is a Tank. Non-Supports = 1.
local function supportPower(side, unit)
	if unit.role ~= "Support" then return 1 end
	local p = 1 + side.effectiveness
	local enemyFront = front(side.enemy)
	if enemyFront and roleOf(enemyFront) == "Tank" then
		p = p + Counters.SupportEffectVsTankFront
	end
	return p
end

local Resolver = {}
Resolver.__index = Resolver

function Resolver:emit(ev)
	if #self.events < Battle.MaxEvents then
		table.insert(self.events, ev)
	end
end

function Resolver:emitMp(side, unit)
	self:emit({ t = "mp", dst = ref(side, unit), newMp = math.floor(unit.mp) })
end

-- Short floating callout on a unit (stuns, trait procs).
function Resolver:status(side, unit, text)
	self:emit({ t = "status", dst = ref(side, unit), text = text })
end

function Resolver:gainMana(side, unit, amount)
	if not unit.alive or amount <= 0 then return end
	if unit.silenced > 0 then return end  -- Confiscation: can't gain mana
	giveMp(unit, amount)
	self:emitMp(side, unit)
end

-- Casts the moment mana reaches the cost.
function Resolver:tryCast(side, unit)
	if unit.alive and unit.mp >= unit.maxMp and not defeated(side) and not defeated(side.enemy) then
		self:castActive(side, unit)
	end
end

function Resolver:stun(side, unit, turns)
	if not unit.alive then return end
	if unit.trait == "heavenly_restriction" then
		self:status(side, unit, "IMMUNE")
		return
	end
	unit.stunned = math.max(unit.stunned, turns)
	self:status(side, unit, "STUNNED")
end

-- Healing already scaled by the caster's multipliers; this applies the side-wide
-- healing bonus (Nature's Call T2) and clamps.
function Resolver:heal(side, unit, amount, source)
	if not unit.alive or unit.hp >= unit.maxHp then return end
	amount = math.floor(amount * (1 + (side.syn.healingBonus or 0)))
	if amount < 1 then return end
	unit.hp = math.min(unit.maxHp, unit.hp + amount)
	self:emit({ t = "heal", dst = ref(side, unit), amount = amount, newHp = unit.hp, source = source })
end

function Resolver:checkTidal(side)
	if side.tidalActive or not side.syn.tidalAtkPct then return end
	for _, u in ipairs(side.units) do
		if u.alive and isMember(u, "Abyssal Order") and u.hp < 0.5 * u.maxHp then
			side.tidalActive = true
			self:emit({ t = "synergy", side = side.key, name = "Abyssal Order", tier = 4, meta = { proc = "tidal" } })
			for _, m in ipairs(side.units) do
				if m.alive and isMember(m, "Abyssal Order") then
					self:heal(side, m, side.syn.tidalHealPct * m.maxHp, "tidal")
				end
			end
			return
		end
	end
end

function Resolver:kill(side, unit, killerSide, killer)
	unit.alive = false
	unit.hp = 0
	self:emit({ t = "death", dst = ref(side, unit) })

	-- Battery: every living Battery unit (either side) restores MP to its own allies.
	for _, s in ipairs(self.sideList) do
		local hasBattery = false
		for _, u in ipairs(s.units) do
			if u.alive and u.passive == "Battery" then hasBattery = true break end
		end
		if hasBattery then
			for _, ally in ipairs(s.units) do
				if ally.alive then self:gainMana(s, ally, Passives.Battery.manaRestore) end
			end
		end
	end

	-- Shadow Covenant: kills restore HP to the killer.
	if killer and killer.alive and (killerSide.syn.killHealPct or 0) > 0 then
		self:heal(killerSide, killer, killerSide.syn.killHealPct * killer.maxHp, "killheal")
	end

	local newFront = front(side)
	if newFront then
		self:emit({ t = "advance", side = side.key, newFrontSlot = newFront.slot })
	end
end

-- Applies an already-final damage amount (shield absorb, lethal clamps, death).
-- allowReflect distinguishes basic attacks from reflect/chain so reflects can't loop.
-- ignoreShield: "true damage" unique-active steps bypass shield absorption entirely.
function Resolver:applyDamage(srcSide, src, dstSide, dst, final, source, crit, allowReflect, ignoreShield)
	if not dst.alive then return end

	-- Infinity: the first hit taken each round never lands.
	if dst.trait == "infinity" and not dst.flags.infinityUsed
		and (source == "attack" or source == "active" or source == "chain") then
		dst.flags.infinityUsed = true
		self:status(dstSide, dst, "INFINITY")
		return
	end

	-- Remember the attacker's last two landed swings (Black Flash sums them).
	if source == "attack" and src then
		table.insert(src.lastSwings, final)
		if #src.lastSwings > 2 then table.remove(src.lastSwings, 1) end
	end

	if self.suddenDeathMult > 1 then
		final = math.floor(final * self.suddenDeathMult)
	end

	local absorbed = ignoreShield and 0 or math.min(dst.shield, final)
	dst.shield = dst.shield - absorbed
	local hpBefore = dst.hp
	local newHp = dst.hp - (final - absorbed)
	local rikaProc = false

	if newHp <= 0 then
		if dst.trait == "queen_of_curses" and not dst.flags.rikaUsed then
			dst.flags.rikaUsed = true
			rikaProc = true
			newHp = 1
		elseif dstSide.syn.surviveLethal and not dst.flags.survivedLethal then
			dst.flags.survivedLethal = true
			newHp = 1
			self:emit({ t = "synergy", side = dstSide.key, name = "Iron Legion", tier = 5, meta = { proc = "surviveLethal", slot = dst.slot } })
		elseif (dstSide.syn.noOneShotAboveHpPct or 0) > 0 and hpBefore / dst.maxHp > dstSide.syn.noOneShotAboveHpPct then
			newHp = 1
			self:emit({ t = "synergy", side = dstSide.key, name = "Ancient Ones", tier = 4, meta = { proc = "titansWill", slot = dst.slot } })
		end
	end

	dst.hp = math.max(0, newHp)
	self:emit({
		t = "damage", dst = ref(dstSide, dst), amount = final,
		newHp = dst.hp, newShield = dst.shield, crit = crit or false, source = source,
	})

	if rikaProc then
		self:status(dstSide, dst, "RIKA!")
		self:applyShield(dstSide, dst, math.floor(dst.maxHp * Traits.queen_of_curses.shieldPct))
	end
	-- First Years T3: first member to drop low gets a one-time shield.
	local syn = dstSide.syn
	if dst.hp > 0 and (syn.lowHpShieldPct or 0) > 0 and not dstSide.lowHpShieldUsed
		and isMember(dst, "First Years") and dst.hp / dst.maxHp < syn.lowHpShieldAt then
		dstSide.lowHpShieldUsed = true
		self:emit({ t = "synergy", side = dstSide.key, name = "First Years", tier = 3, meta = { proc = "lowHpShield", slot = dst.slot } })
		self:applyShield(dstSide, dst, math.floor(dst.maxHp * syn.lowHpShieldPct))
	end

	if dst.hp > 0 and dst.passive == "Drain" then
		self:heal(dstSide, dst, final * Passives.Drain.healPctOfDamageTaken, "Drain")
	end
	-- Lifesteal: attacker heals for a share of damage dealt. Basic attacks and
	-- actives only — reflect/chain excluded so reflected damage can't double-dip.
	-- Synergy lifesteal (Abyssal Order) is member-only, matching the tidal gate.
	if src and src.alive and (source == "attack" or source == "active") then
		local ls = src.mods.lifestealPct
		if (srcSide.syn.lifestealPct or 0) > 0 and isMember(src, "Abyssal Order") then
			ls = ls + srcSide.syn.lifestealPct
		end
		if ls > 0 then
			self:heal(srcSide, src, final * ls, "lifesteal")
		end
	end
	self:checkTidal(dstSide)

	if dst.hp <= 0 then
		if dst.mods.reviveOnce and not dst.flags.reviveUsed then
			dst.flags.reviveUsed = true
			dst.hp = math.max(1, math.floor(0.30 * dst.maxHp))
			self:emit({ t = "heal", dst = ref(dstSide, dst), amount = dst.hp, newHp = dst.hp, source = "revive" })
		elseif (dstSide.syn.revivePct or 0) > 0 and isMember(dst, "Divine Pantheon") and not dst.flags.synergyReviveUsed then
			dst.flags.synergyReviveUsed = true
			dst.hp = math.max(1, math.floor(dstSide.syn.revivePct * dst.maxHp))
			self:emit({ t = "synergy", side = dstSide.key, name = "Divine Pantheon", tier = 4, meta = { proc = "revive", slot = dst.slot } })
			self:emit({ t = "heal", dst = ref(dstSide, dst), amount = dst.hp, newHp = dst.hp, source = "revive" })
		else
			self:kill(dstSide, dst, srcSide, src)
		end
	elseif allowReflect and src.alive then
		local reflect = (dstSide.syn.reflectPct or 0) + dst.mods.reflectPct
		if reflect > 0 then
			local rDmg = math.floor(final * reflect)
			if rDmg >= 1 then
				self:applyDamage(dstSide, dst, srcSide, src, rDmg, "reflect", false, false)
			end
		end
	end
end

-- Full damage pipeline: roll variance/crit, amplifiers, damage reduction, then apply.
-- opts (optional):
--   forceCrit   = bool    always crit
--   critMult    = number  overrides Battle.CritMult for this hit (Black Flash)
--   trueDamage  = bool    skips the DR calculation below AND shield absorption
--   ignoreShield = bool   skips shield absorption only (DR still applies)
--   flatBonus   = number  added to the raw hit before the crit multiplier
function Resolver:dealDamage(srcSide, src, dstSide, dst, mult, source, opts)
	if not src.alive or not dst.alive then return end
	local rng = self.rng
	opts = opts or {}

	local crit = opts.forceCrit or (rng:NextNumber() < (Battle.CritChance + src.mods.critChanceBonus))
	local raw = (currentAtk(srcSide, src) * mult
		* rng:NextNumber(Battle.VarianceLo, Battle.VarianceHi)
		+ (opts.flatBonus or 0))
		* (crit and (opts.critMult or Battle.CritMult) or 1)

	-- Role counter cycle (keyed off both units' current roles).
	local srcRole, dstRole = roleOf(src), roleOf(dst)
	local counterMult = 1
	if srcRole == "DPS" and dstRole == "Tank" then
		counterMult = 1 - Counters.TankVsDPS
	end

	local amp = 1
	if srcRole == "DPS" and dstRole == "Support" then
		amp = amp + Counters.DPSVsSupport
	elseif srcRole == "Support" and dstRole == "Tank" then
		amp = amp + Counters.SupportVsTank
	end
	if src.passive == "Executioner" and dst.hp / dst.maxHp < Passives.Executioner.hpThreshold then
		amp = amp + Passives.Executioner.bonusDamage + (srcSide.syn.execBonusAdd or 0)
	end
	if src.mods.executeBonusPct > 0 and dst.hp / dst.maxHp < 0.30 then
		amp = amp + src.mods.executeBonusPct
	end
	if dst.flags.marked then
		amp = amp + (srcSide.syn.markBonus or 0)
	end
	if (srcSide.syn.bonusDamagePct or 0) > 0 and not isMember(dst, "Iron Legion") then
		amp = amp + srcSide.syn.bonusDamagePct
	end

	local dr = 0
	if not opts.trueDamage then
		dr = (dstSide.syn.damageReduction or 0) + dst.mods.extraDR + (dstSide.customDrShred or 0)
		if (dstSide.syn.drBelowHalf or 0) > 0 and dst.hp / dst.maxHp < 0.5 then
			dr = dr + dstSide.syn.drBelowHalf
		end
		if dst.trait == "three_cores" and dst.currentRole == "Tank" then
			dr = dr + Traits.three_cores.tankDR
		end
		dr = math.clamp(dr, 0, 0.8)
	end
	local ignore = (source == "active" and not opts.trueDamage) and (srcSide.syn.ignoreDRPct or 0) or 0

	-- Adaptation: each hit from the same attacker is weaker than the last.
	local adaptMult = 1
	if dst.trait == "adaptation" then
		local key = srcSide.key .. src.slot
		local stacks = dst.adapt[key] or 0
		adaptMult = 1 - math.min(stacks * Traits.adaptation.perHit, Traits.adaptation.cap)
		dst.adapt[key] = stacks + 1
	end

	local final = math.max(1, math.floor(raw * amp * counterMult * adaptMult * (1 - dr * (1 - ignore))))
	self:applyDamage(srcSide, src, dstSide, dst, final, source, crit, source == "attack",
		opts.trueDamage or opts.ignoreShield)
end

-- Applies a shield amount to `target` and emits the matching event. Shared by
-- shield_self/shield_all unique-active steps and, below, the generic Tank active.
function Resolver:applyShield(side, target, amount)
	if amount < 1 then return end
	target.shield = target.shield + amount
	self:emit({ t = "shield", dst = ref(side, target), amount = amount, newShield = target.shield })
end

-- One step of a per-card unique active (CardDatabase.lua card.active.effects).
-- Each op is a small reusable primitive so card kits stay declarative data
-- instead of one bespoke Lua function per card.
local function lowestHpAlive(units)
	local best
	for _, u in ipairs(units) do
		if u.alive and (not best or u.hp < best.hp) then best = u end
	end
	return best
end

function Resolver:runActiveStep(side, unit, enemySide, step)
	local pw = unit.mods.activePowerMult
	local sp = supportPower(side, unit)

	-- Overtime (Nanami): from a given round on, this step hits harder.
	if step.overtimeRound and self.round >= step.overtimeRound then
		pw = pw * step.overtimeMult
		if not unit.flags.overtimeAnnounced then
			unit.flags.overtimeAnnounced = true
			self:status(side, unit, "OVERTIME!")
		end
	end

	if step.op == "single_damage" then
		-- target: "front" (default), "lowest" (lowest current HP enemy) or
		-- "mostAdapted" (the enemy that has hit this unit the most).
		-- Extras, all optional: hits, stunTurns, bonusVsStunned, targetMaxHpPct,
		-- selfMaxHpPct, drainTargetMana, onKillMana.
		for _ = 1, step.hits or 1 do
			local target
			if step.target == "lowest" then
				target = lowestHpAlive(enemySide.units)
			elseif step.target == "mostAdapted" then
				local bestHits = 0
				for _, e in ipairs(enemySide.units) do
					local hits = unit.adapt[enemySide.key .. e.slot] or 0
					if e.alive and hits > bestHits then target, bestHits = e, hits end
				end
				target = target or front(enemySide)
			else
				target = front(enemySide)
			end
			if not target or not unit.alive then break end

			local mult = step.mult * pw
			if step.bonusVsStunned and target.stunned > 0 then
				mult = mult + step.bonusVsStunned * pw
				self:status(enemySide, target, "SHATTER!")
			end
			local flat = (step.targetMaxHpPct and target.maxHp * step.targetMaxHpPct or 0)
				+ (step.selfMaxHpPct and unit.maxHp * step.selfMaxHpPct or 0)
			self:dealDamage(side, unit, enemySide, target, mult, "active", {
				forceCrit = step.guaranteedCrit, critMult = step.critMult,
				trueDamage = step.trueDamage, ignoreShield = step.ignoreShield,
				flatBonus = flat > 0 and flat * pw or nil,
			})

			if target.alive then
				if step.stunTurns then self:stun(enemySide, target, step.stunTurns) end
				if step.drainTargetMana and target.mp > 0 then
					target.mp = 0
					self:emitMp(enemySide, target)
					self:status(enemySide, target, "NULLIFIED")
				end
			elseif step.onKillMana then
				self:status(side, unit, "RELOAD!")
				self:gainMana(side, unit, step.onKillMana)
			end
		end

	elseif step.op == "black_flash" then
		-- Each hit = the two previous hits combined + missingHpPct of the
		-- target's missing HP. Starts from the caster's last two basic-attack
		-- swings; after hit n, roll repeatChances[n] to chain another. The
		-- chain is local to this cast, so it never snowballs across turns.
		-- Summed swing damage was already mitigated, so it lands as-is
		-- (shields still absorb).
		local swings = unit.lastSwings
		local fallback = math.floor(currentAtk(side, unit))
		local prev2 = swings[#swings - 1] or fallback
		local prev1 = swings[#swings] or fallback
		local chances = step.repeatChances or {}
		for hit = 1, #chances + 1 do
			local target = front(enemySide)
			if not target or not unit.alive then break end
			if hit > 1 then
				self:status(side, unit, (step.label or "Black Flash") .. " x" .. hit .. "!")
			end
			local amount = math.floor((prev2 + prev1) * pw + (target.maxHp - target.hp) * step.missingHpPct)
			self:applyDamage(side, unit, enemySide, target, amount, "active", true, false, false)
			prev2, prev1 = prev1, amount
			if hit > #chances or defeated(enemySide) or self.rng:NextNumber() >= chances[hit] then
				break
			end
		end

	elseif step.op == "stun" then
		-- target: "front" (default) or "all".
		if step.target == "all" then
			for _, e in ipairs(enemySide.units) do
				if e.alive then self:stun(enemySide, e, step.turns or 1) end
			end
		else
			local target = front(enemySide)
			if target then self:stun(enemySide, target, step.turns or 1) end
		end

	elseif step.op == "silence" then
		-- Confiscation: wipes the target's mana and blocks mana gain for `turns` rounds.
		local target = front(enemySide)
		if target then
			target.mp = 0
			target.silenced = math.max(target.silenced, step.turns or 2)
			self:emitMp(enemySide, target)
			self:status(enemySide, target, "CONFISCATED")
		end

	elseif step.op == "team_atk_buff" then
		side.customAtkBuff = math.min((side.customAtkBuff or 0) + step.pct * sp, step.cap)

	elseif step.op == "grant_mana" then
		-- target: nil = every ally, "closest" = the ally nearest to casting.
		if step.target == "closest" then
			local best, bestRatio = nil, -1
			for _, ally in ipairs(side.units) do
				if ally.alive and ally ~= unit and ally.silenced <= 0 then
					local ratio = ally.mp / ally.maxMp
					if ratio < 1 and ratio > bestRatio then best, bestRatio = ally, ratio end
				end
			end
			if best then
				self:status(side, best, "+" .. step.amount .. " MANA")
				self:gainMana(side, best, step.amount)
			end
		else
			for _, ally in ipairs(side.units) do
				if ally.alive and not (step.excludeSelf and ally == unit) then
					self:gainMana(side, ally, step.amount)
				end
			end
		end

	elseif step.op == "drain_mana" then
		local targets = {}
		if step.target == "all" then
			targets = enemySide.units
		else
			targets = { front(enemySide) }
		end
		for _, e in ipairs(targets) do
			if e and e.alive then
				e.mp = math.max(0, e.mp - step.amount)
				self:emitMp(enemySide, e)
				self:status(enemySide, e, "-" .. step.amount .. " MANA")
			end
		end

	elseif step.op == "jackpot" then
		local target = front(enemySide)
		if target then
			self:dealDamage(side, unit, enemySide, target, step.mult * pw, "active")
		end
		if unit.alive and self.rng:NextNumber() < step.chance then
			self:status(side, unit, "JACKPOT!")
			self:heal(side, unit, unit.maxHp, "jackpot")
			unit.stackAtkBonus = unit.stackAtkBonus + step.atkPct
			if step.refillMana then
				-- Fever: mana refills, so the next swing casts again.
				self:status(side, unit, "FEVER!")
				self:gainMana(side, unit, unit.maxMp)
			end
		end

	elseif step.op == "aoe_damage" then
		-- excludeFront: hits everyone but the frontline (Hollow Purple's splash).
		-- perEnemyCastBonus/bonusCap: +x per ability the enemy team has cast.
		local mult = step.mult * pw
		if step.perEnemyCastBonus then
			mult = mult * (1 + math.min(enemySide.castCount * step.perEnemyCastBonus, step.bonusCap or math.huge))
		end
		local skip = step.excludeFront and front(enemySide) or nil
		for _, e in ipairs(enemySide.units) do
			if e.alive and e ~= skip then
				self:dealDamage(side, unit, enemySide, e, mult, "active", { forceCrit = step.guaranteedCrit })
			end
		end

	elseif step.op == "dot_all" then
		-- Burns / lingering cleaves: every enemy takes `mult` of the caster's
		-- current ATK at the start of each of the next `rounds` rounds.
		local perTick = math.max(1, math.floor(currentAtk(side, unit) * step.mult * pw))
		for _, e in ipairs(enemySide.units) do
			if e.alive then
				table.insert(e.dots, {
					perTick = perTick, rounds = step.rounds, trueDamage = step.trueDamage,
					srcSide = side, src = unit, name = step.name or "burn",
				})
				self:status(enemySide, e, string.upper(step.name or "burn"))
			end
		end

	elseif step.op == "nail_resonance" then
		-- Hammer a nail into the frontline, then every nailed enemy takes
		-- perNail true damage per nail. Nails persist all battle.
		local target = front(enemySide)
		if target then
			self:dealDamage(side, unit, enemySide, target, step.mult * pw, "active")
			if target.alive then target.nails = target.nails + 1 end
		end
		for _, e in ipairs(enemySide.units) do
			if e.alive and e.nails > 0 then
				self:status(enemySide, e, "RESONANCE x" .. e.nails)
				self:dealDamage(side, unit, enemySide, e, step.perNail * e.nails * pw, "active", { trueDamage = true })
			end
		end

	elseif step.op == "swap_front_back" then
		-- Boogie Woogie: the enemy frontline and backline trade places.
		local f, b = front(enemySide), backline(enemySide)
		if f and b and f ~= b then
			f.pos, b.pos = b.pos, f.pos
			self:emit({ t = "swap", side = enemySide.key, a = f.slot, b = b.slot })
			self:status(enemySide, b, "SWAPPED")
			self:emit({ t = "advance", side = enemySide.key, newFrontSlot = b.slot })
		end

	elseif step.op == "self_cost" then
		-- Pay HP to cast (never lethal): pctCurrent of current HP + pctMax of Max HP.
		local cost = math.floor(unit.hp * (step.pctCurrent or 0) + unit.maxHp * (step.pctMax or 0))
		if cost >= 1 and unit.hp > 1 then
			unit.hp = math.max(1, unit.hp - cost)
			self:emit({ t = "damage", dst = ref(side, unit), amount = cost, newHp = unit.hp, newShield = unit.shield, crit = false, source = "backlash" })
		end

	elseif step.op == "cleanse" then
		for _, ally in ipairs(side.units) do
			if ally.alive and (ally.stunned > 0 or ally.silenced > 0) then
				ally.stunned, ally.silenced = 0, 0
				self:status(side, ally, "CLEANSED")
			end
		end

	elseif step.op == "random" then
		-- Picks one option ({ name, effects }) at random and runs it.
		local pick = step.options[self.rng:NextInteger(1, #step.options)]
		self:status(side, unit, string.upper(pick.name))
		for _, sub in ipairs(pick.effects) do
			self:runActiveStep(side, unit, enemySide, sub)
		end

	elseif step.op == "by_form" then
		-- Runs a different kit depending on the unit's current role (Three Cores).
		for _, sub in ipairs(step[unit.currentRole] or {}) do
			self:runActiveStep(side, unit, enemySide, sub)
		end

	elseif step.op == "copy_ally" then
		-- Copy: re-run the last ability an ally cast, as this unit.
		local last = side.lastAllyCast
		if last and last.caster ~= unit then
			self:status(side, unit, "COPY: " .. string.upper(last.name))
			for _, sub in ipairs(last.steps) do
				if sub.op ~= "copy_ally" then self:runActiveStep(side, unit, enemySide, sub) end
			end
		else
			for _, sub in ipairs(step.fallback or {}) do
				self:runActiveStep(side, unit, enemySide, sub)
			end
		end

	elseif step.op == "true_damage_all" then
		for _, e in ipairs(enemySide.units) do
			if e.alive then
				self:dealDamage(side, unit, enemySide, e, step.mult * pw, "active", { trueDamage = true })
			end
		end

	elseif step.op == "single_true_execute" then
		local target = front(enemySide)
		if target then
			if (target.hp / target.maxHp) <= step.executeThreshold then
				-- Guaranteed lethal: exceed remaining HP+shield, bypass everything.
				self:applyDamage(side, unit, enemySide, target, target.hp + target.shield + 1, "active", true, false, true)
			else
				self:dealDamage(side, unit, enemySide, target, step.mult * pw, "active", { trueDamage = true })
			end
		end

	elseif step.op == "heal_all" then
		for _, ally in ipairs(side.units) do
			if ally.alive then
				self:heal(side, ally, ally.maxHp * step.pct * sp * pw, "active")
			end
		end

	elseif step.op == "heal_lowest" then
		local target
		for _, ally in ipairs(side.units) do
			if ally.alive and ally.hp < ally.maxHp
				and (not target or ally.hp / ally.maxHp < target.hp / target.maxHp) then
				target = ally
			end
		end
		if target then
			self:heal(side, target, target.maxHp * step.pct * sp * pw, "active")
		end

	elseif step.op == "shield_all" then
		for _, ally in ipairs(side.units) do
			if ally.alive then
				self:applyShield(side, ally, math.floor(ally.maxHp * step.pct * sp * pw))
			end
		end

	elseif step.op == "shield_self" then
		self:applyShield(side, unit, math.floor(unit.maxHp * step.pct * pw))

	elseif step.op == "stack_atk_buff" then
		unit.stackAtkBonus = unit.stackAtkBonus + step.pct

	elseif step.op == "enemy_atk_shred" then
		local cap = math.min(step.cap, Counters.HexerAtkDebuffCap)
		enemySide.customAtkDebuff = math.min((enemySide.customAtkDebuff or 0) + step.pct * sp, cap)

	elseif step.op == "enemy_dr_shred" then
		enemySide.customDrShred = math.min((enemySide.customDrShred or 0) + step.pct * sp, step.cap)

	elseif step.op == "maxhp_shred_all" then
		for _, e in ipairs(enemySide.units) do
			if e.alive then
				e.maxHp = math.max(1, math.floor(e.maxHp * (1 - step.pct)))
				e.hp = math.min(e.hp, e.maxHp)
				self:emit({ t = "maxhp_shred", dst = ref(enemySide, e), pct = step.pct, newMaxHp = e.maxHp, newHp = e.hp })
			end
		end
	end
end

function Resolver:castActive(side, unit)
	unit.mp = math.max(0, unit.mp - unit.maxMp)
	local enemySide = side.enemy
	local casts = (unit.role == "Support" and side.syn.doubleSupportCast) and 2 or 1

	-- Thousand-Year Plan: enemy Kenjaku-types profit from every cast.
	for _, e in ipairs(enemySide.units) do
		if e.alive and e.trait == "thousand_year_plan" then
			self:gainMana(enemySide, e, Traits.thousand_year_plan.manaPerEnemyCast)
		end
	end

	side.castCount = side.castCount + 1

	-- Alternating kits (Gojo, Mechamaru) cycle through their techniques.
	local steps, name = unit.activeSpec, unit.activeName
	if unit.activeAlt then
		unit.altIndex = unit.altIndex % #unit.activeAlt + 1
		local alt = unit.activeAlt[unit.altIndex]
		steps, name = alt.effects, alt.name
	end

	if steps then
		self:emit({ t = "cast", src = ref(side, unit), activeName = name or (unit.role .. " Active"), role = unit.role })
		if unit.mp > 0 then self:emitMp(side, unit) end
		-- Remember it for Copy (Yuta) before running, so a copier never copies itself.
		local isCopier = false
		for _, st in ipairs(steps) do
			if st.op == "copy_ally" then isCopier = true end
		end
		if not isCopier then
			side.lastAllyCast = { caster = unit, name = name or "Ability", steps = steps }
		end
		for _ = 1, casts do
			for _, step in ipairs(steps) do
				self:runActiveStep(side, unit, enemySide, step)
			end
		end
		return
	end

	-- Fallback: generic role-based active, unchanged — every card without a
	-- unique kit (Common through Epic, for now) still works exactly as before.
	local activeDef = Actives[unit.role]
	if not activeDef then return end

	self:emit({ t = "cast", src = ref(side, unit), activeName = unit.role .. " Active", role = unit.role })
	if unit.mp > 0 then self:emitMp(side, unit) end

	for _ = 1, casts do
		if unit.role == "DPS" then
			local target = front(enemySide)
			if target then
				self:dealDamage(side, unit, enemySide, target, activeDef.atkMult * unit.mods.activePowerMult, "active")
			end
		elseif unit.role == "Support" then
			for _, ally in ipairs(side.units) do
				if ally.alive then
					self:heal(side, ally, ally.maxHp * activeDef.healPct * supportPower(side, unit) * unit.mods.activePowerMult, "active")
				end
			end
		else -- Tank
			self:applyShield(side, unit, math.floor(unit.maxHp * activeDef.shieldPct * unit.mods.activePowerMult))
		end
	end
end

function Resolver:basicAttack(side, attacker)
	local enemySide = side.enemy
	local target = front(enemySide)
	if not attacker or not attacker.alive or not target then return end

	if attacker.stunned > 0 then
		attacker.stunned = attacker.stunned - 1
		self:status(side, attacker, "SKIPS TURN")
		return
	end

	-- Divergent Fist: the first attack each turn strikes twice; the second
	-- swing adds a slice of the target's CURRENT HP. Every swing gives mana,
	-- and the ability fires the moment mana is full (mid-attack, between swings).
	local swings = attacker.trait == "divergent_fist" and 2 or 1
	for swing = 1, swings do
		target = front(enemySide)
		if not target or not attacker.alive then break end
		local opts
		if swing == 2 then
			opts = { flatBonus = target.hp * Traits.divergent_fist.bonusCurrentHpPct }
		end
		self:emit({ t = "attack", src = ref(side, attacker), dst = ref(enemySide, target) })
		self:dealDamage(side, attacker, enemySide, target, 1.0, "attack", opts)

		-- Dismantle: each swing also slashes the next enemy in line.
		if attacker.trait == "dismantle" and attacker.alive then
			local cleaveTarget = nextInLine(enemySide, target)
			if cleaveTarget then
				self:dealDamage(side, attacker, enemySide, cleaveTarget, Traits.dismantle.cleavePct, "chain")
			end
		end

		self:gainMana(side, attacker, MPConf.OnAttack)
		self:tryCast(side, attacker)
		if defeated(side) or defeated(enemySide) then return end
	end
	target = target and target.alive and target or front(enemySide)
	if not target then return end

	if attacker.passive == "Rage" and attacker.rageStacks < Passives.Rage.maxStacks then
		attacker.rageStacks = attacker.rageStacks + 1
	end

	-- Shadow Covenant T4: first basic attack each round marks the target.
	if (side.syn.markBonus or 0) > 0 and not side.markUsed and target.alive then
		target.flags.marked = true
		side.markUsed = true
	end

	-- Storm Riders: chance to chain to the next unit in the enemy death queue.
	if attacker.alive and (side.syn.chainChance or 0) > 0 and self.rng:NextNumber() < side.syn.chainChance then
		local chainTarget = nextInLine(enemySide, target)
		if chainTarget then
			self:dealDamage(side, attacker, enemySide, chainTarget, side.syn.chainPct, "chain")
		end
	end
end

-- ── Public: Resolve ───────────────────────────────────────────────────────────

-- playerUnits / enemyUnits: arrays of UnitState from BuildUnit (holes removed).
-- Returns { winner = "P"|"E", events, playerUnits, enemyUnits, rounds }.
function BattleEngine.Resolve(playerUnits, enemyUnits, seed)
	local self = setmetatable({
		rng = Random.new(seed),
		events = {},
		round = 0,
		suddenDeathMult = 1,
	}, Resolver)

	local P = newSide("P", playerUnits)
	local E = newSide("E", enemyUnits)
	P.enemy, E.enemy = E, P
	self.sideList = { P, E }

	-- Announce active synergies (UI toasts).
	for _, side in ipairs(self.sideList) do
		for series, tier in pairs(side.tiers) do
			self:emit({ t = "synergy", side = side.key, name = series, tier = tier, meta = {} })
		end
	end

	-- Cursed Spirit Manipulation: the whole team starts with mana.
	for _, side in ipairs(self.sideList) do
		local startMana = 0
		for _, u in ipairs(side.units) do
			if u.alive and u.trait == "spirit_manipulation" then
				startMana = math.max(startMana, Traits.spirit_manipulation.startMana)
			end
		end
		if startMana > 0 then
			for _, u in ipairs(side.units) do
				self:gainMana(side, u, startMana)
			end
		end
	end

	local rounds = 0
	if not defeated(P) and not defeated(E) then
		for round = 1, Battle.MaxRounds do
			rounds = round
			self.round = round
			self:emit({ t = "round", round = round })
			if round >= Battle.SuddenDeathRound then
				self.suddenDeathMult = 1 + Battle.SuddenDeathPerRound * (round - Battle.SuddenDeathRound + 1)
				for _, side in ipairs(self.sideList) do
					local f = front(side)
					if f then self:status(side, f, "SUDDEN DEATH +" .. math.floor((self.suddenDeathMult - 1) * 100 + 0.5) .. "%") end
				end
			end

			-- 1. Round start: clear marks, reset per-round traits, regen.
			for _, side in ipairs(self.sideList) do
				side.markUsed = false
				for _, u in ipairs(side.enemy.units) do
					u.flags.marked = false
				end
				for _, u in ipairs(side.units) do
					u.flags.infinityUsed = false
					if u.trait == "three_cores" and u.alive then
						u.currentRole = (round % 2 == 1) and "Tank" or "DPS"
						self:status(side, u, u.currentRole == "Tank" and "TANK FORM" or "GORILLA FORM")
					end
					if u.alive then
						local regen = (side.syn.regenPct or 0) + u.mods.regenPctPerRound
						if regen > 0 then
							self:heal(side, u, u.maxHp * regen, "regen")
						end
					end
				end
			end

			-- 1b. Damage over time (burns, lingering cleaves) ticks at round start.
			for _, side in ipairs(self.sideList) do
				for _, u in ipairs(side.units) do
					for i = #u.dots, 1, -1 do
						local dot = u.dots[i]
						if u.alive then
							self:applyDamage(dot.srcSide, dot.src, side, u, dot.perTick, dot.name, false, false, dot.trueDamage)
						end
						dot.rounds = dot.rounds - 1
						if dot.rounds <= 0 or not u.alive then table.remove(u.dots, i) end
					end
				end
			end
			if defeated(P) or defeated(E) then break end

			-- 2. Active casts.
			for _, side in ipairs(self.sideList) do
				for _, u in ipairs(side.units) do
					if u.alive and u.mp >= u.maxMp then
						self:castActive(side, u)
						if defeated(P) or defeated(E) then break end
					end
				end
				if defeated(P) or defeated(E) then break end
			end
			if defeated(P) or defeated(E) then break end

			-- 3. Basic attacks: every living unit on each side attacks the
			-- opposing frontline, whole P team first, then the whole E team.
			for _, side in ipairs(self.sideList) do
				for _, u in ipairs(side.units) do
					if u.alive then
						self:basicAttack(side, u)
						if defeated(P) or defeated(E) then break end
					end
				end
				if defeated(P) or defeated(E) then break end
			end
			if defeated(P) or defeated(E) then break end

			-- 4. Round end: Medic heals.
			for _, side in ipairs(self.sideList) do
				for _, u in ipairs(side.units) do
					if u.alive and u.passive == "Medic" then
						local target
						for _, ally in ipairs(side.units) do
							if ally.alive and ally.hp < ally.maxHp
								and (not target or ally.hp / ally.maxHp < target.hp / target.maxHp) then
								target = ally
							end
						end
						if target then
							self:heal(side, target, target.maxHp * Passives.Medic.healPctLowestAlly * supportPower(side, u), "Medic")
						end
					end
				end
			end
			-- Confiscation wears off one round at a time.
			for _, side in ipairs(self.sideList) do
				for _, u in ipairs(side.units) do
					if u.silenced > 0 then u.silenced = u.silenced - 1 end
				end
			end
		end
	end

	-- Winner: a defeated side loses; at the round cap the side with the higher
	-- total HP ratio wins (tie = player loss).
	local winner
	if defeated(P) then
		winner = "E"
	elseif defeated(E) then
		winner = "P"
	else
		local function hpScore(side)
			local total = 0
			for _, u in ipairs(side.units) do
				if u.alive then total = total + u.hp / u.maxHp end
			end
			return total
		end
		winner = hpScore(P) > hpScore(E) and "P" or "E"
	end

	self:emit({ t = "end", winner = winner, rounds = rounds })
	return {
		winner = winner,
		events = self.events,
		playerUnits = playerUnits,
		enemyUnits = enemyUnits,
		rounds = rounds,
	}
end

return BattleEngine
