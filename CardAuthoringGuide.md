# Card Authoring Guide

Companion to `GameDesign.md`'s Phase 9 (Content Scaling & Live Content Pipeline). This is the template for adding new cards to `src/shared/GachaSystem/CardDatabase.lua` so they land balanced without re-deriving the whole system from scratch each time.

**Scope note:** this guide covers *routine content additions* — new cards that fit the existing systems. It deliberately does not cover designing new mechanics, passives, synergy factions, or BattleEngine ops; those are systems changes, not content authoring, and the current 50-card roster's actives/synergies are explicit placeholders pending a dedicated depth pass (see `GameDesign.md`'s Phase 3 and Phase 9 notes). Adding a card should never require touching combat code.

## 1. Stat bands per rarity

Ranges below are the actual min-max across the current 50-card roster. Re-verify these live before adding a card — they'll drift slightly as the roster grows — via `DebugService:PreviewStatBands()` (Studio-only, call it directly through `execute_luau` against the running server; it prints the current band per rarity).

| Rarity | ATK | HP | MP |
|---|---|---|---|
| Common | 55-145 | 290-810 | 20-100 |
| Uncommon | 145-250 | 460-1020 | 60-205 |
| Rare | 240-410 | 600-1320 | 120-325 |
| Epic | 460-660 | 910-2560 | 150-510 |
| Legendary | 740-1010 | 1820-3580 | 400-820 |
| Mythic | ~1520 | ~4100 | ~1250 (single reference card — scale future Mythics similarly) |
| God | ~2600 | ~8200 | ~2100 (single reference card) |
| Secret | 9999/9999/9999 | — | intentional outlier/joke tier, exempt from normal banding |

A new card should land inside (or very close to) its rarity's band. Don't extrapolate a curve from these numbers — just match the existing spread.

## 2. Role & passive framework

Three roles: **Tank / DPS / Support**. Role-count bonuses (`CombatConfig.RoleBonuses`) are fixed system constants — never rebalance those per-card.

Each role has a small, closed set of passive categories (`RoleConfig.Roles`):
- **Tank** → `Drain` only (by design — Tank's identity is defensive sustain, one passive is enough)
- **DPS** → `Rage` or `Executioner`
- **Support** → `Medic` or `Battery`

A new card picks an **existing** category for its role and writes a unique `passive_desc` flavor variant of it. The category's baseline magnitude (`CombatConfig.Passives`) is the budget to stay within (roughly ±30%):
- Drain: heals 15% of damage taken
- Rage: +6% ATK per stack, max 5 stacks
- Executioner: +30% damage below 35% HP
- Medic: heals lowest-HP ally 4% Max HP/round
- Battery: restores 15% MP to all allies on any death

Adding a genuinely new passive category is a systems change — flag it for a dedicated pass instead of folding it into a content PR.

## 3. Synergy fit

Eight factions exist (`RoleConfig.Synergies` for flavor text, `CombatConfig.Synergies` for the actual numbers). A card lists 0-2 series in its `series` array — never more than 2. When adding a card to a faction, respect that faction's `maxCount` (its designed roster size); don't quietly grow a faction past what its threshold tiers were tuned for. Prefer reusing one of the 8 existing factions over inventing a 9th — that's a synergy-design decision, not routine authoring.

Use `DebugService:PreviewSynergyMath(seriesName)` (or no argument for all factions) to print current tier thresholds/effects while checking fit.

## 4. Active-ability power budget

**Common through Epic** cards use the shared generic role active (`CombatConfig.Actives`: DPS 200% ATK hit, Support 12% heal-all, Tank 25% self-shield) via `active = { name, desc }` with no `effects` table. Leave these alone — per-card unique actives are Legendary+ only until a dedicated backfill pass (see `GameDesign.md` Phase 3/9).

**Legendary+** cards get a real `active.effects` table executed by `BattleEngine`'s `runActiveStep`. The 7 shipped kits (ids 44-50) establish the budget: roughly a 300-500% ATK-equivalent AOE or single-target hit (up to 500-800% true-damage executes at God/Secret tier), paired with **one** secondary permanent-stacking effect (a stacking ATK buff, an enemy shred, an execute threshold) — not two or more, except the intentionally-over-tuned Secret joke card. New Legendary+ kits should follow this "one big number + one small permanent secondary" shape rather than stacking several effects.

Existing op vocabulary to reuse (see ids 44-50 for precedent): `aoe_damage`, `heal_lowest`, `shield_all`, `single_true_execute`, `true_damage_all`, `stack_atk_buff`, `enemy_atk_shred`, `enemy_dr_shred`, `maxhp_shred_all`. A new op is a `BattleEngine` change, not a content addition.

## 5. Adding a card — checklist

1. Pick a rarity; pull its stat band from Section 1 (re-check live with `PreviewStatBands`).
2. Pick a role; pick one of that role's existing passive categories; write a flavor-unique `passive_desc` within the magnitude budget in Section 2.
3. Pick 0-2 existing synergy series, respecting `maxCount` (Section 3).
4. Common-Epic: leave `active = { name, desc }` only — no `effects` table.
5. Legendary+: write `active.effects` using the existing op vocabulary, following the budget in Section 4.
6. Assign the next sequential `id`; append the entry inside the correct rarity block in `CardDatabase.Cards`. The `_byId`/`_byRarity`/`_bySeries` lookup tables rebuild automatically at require-time — no other file needs a manual update for a stat-only addition.
7. Run `DebugService:PreviewRarityDistribution` and `PreviewStatBands` in Studio afterward to confirm nothing drifted.

## 6. Explicitly out of scope for routine additions

- New passive categories, new synergy factions, new `BattleEngine` ops, new roles.
- Deep/unique mechanics for Common-Epic cards.

Both belong to the dedicated card-design-depth pass, not a content-scaling PR.

## Studio balancing tools (Phase 9)

All Studio-only, called directly via `execute_luau` against the running server session (`DebugService` already guards every entry point with `RunService:IsStudio()`):

- `DebugService:PreviewRarityDistribution(packType, numRolls)` — simulates base rarity weights (ignoring pity) and prints the resulting distribution.
- `DebugService:PreviewStatBands()` — prints live ATK/HP/MP min-max per rarity from the actual roster (Section 1's source of truth).
- `DebugService:PreviewSynergyMath(seriesName)` — prints a faction's tier thresholds/effects (or all factions if no name given).
- `DebugService:PreviewPvPRatingCurve(numGames, winRate)` — simulates a trophy trajectory at a given win rate.
- `DebugService:PreviewBannerRotation(weeksAhead)` — prints which banner is scheduled for each of the next N weeks, using the same schedule math the live game uses.
