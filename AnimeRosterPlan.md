# Anime Roster & Dungeon Plan

This is the deferred "card-design-depth pass" the project has been saving up since Phase 3 (`GameDesign.md`) — turning the current 50 placeholder cards into a real anime-themed roster with actual mechanical identity, plus the anime-themed dungeons the Theme note in `GameDesign.md` always intended. Companion to `CardAuthoringGuide.md` (routine-addition rules) — this doc is the one-time restructuring pass, not routine.

**Not yet implemented — this is the plan for review before any `CardDatabase.lua` changes.**

## 1. Scope

- **5 anime pillars, 10 cards each, 50 total.** This reorganizes the *existing* 50-card roster — it does not expand the total count (that's Phase 9's separately-deferred 50→200+ roster expansion).
- **5 anime-themed dungeons, one per anime**, reusing the existing Dungeon Crawl map-generation system (reskin enemy pools/bosses, not a new system).
- Endless Tower stays anime-agnostic — a mixed-roster gauntlet, not reskinned 5 ways.

## 2. The 5 anime pillars

| Anime | Why |
|---|---|
| **Jujutsu Kaisen** | Already seeded (Gojo, Sukuna); currently the single highest-"dopamine" anime with this audience — Domain Expansion is a genuine viral moment, and its named techniques translate directly into flashy actives. |
| **Naruto** | Deepest bench of any shounen for filling Common→Legendary; enormous, instantly recognizable move vocabulary; already partially anchored (Tsunade). |
| **Dragon Ball Z** | The original power-escalation dopamine loop (Super Saiyan = "number go up" made visual); the single most kid-recognizable anime that exists, multi-generational. |
| **One Piece** | Deep long-running bench; broad multi-generational kid recognition; distinct powers (Devil Fruits) for varied kit flavor. |
| **Demon Slayer** | Massively popular with kids right now; gorgeous elemental "Breathing Style" techniques are pure spectacle; broad crossover appeal beyond anime-only fans. |

4 of 5 are battle-shounen by design — that matches the actual gameplay (cards fighting cards) rather than being an oversight.

## 3. Rarity budget (unchanged, redistributed)

The global rarity budget doesn't change: **14 Common / 12 Uncommon / 10 Rare / 7 Epic / 4 Legendary / 1 Mythic / 1 God / 1 Secret = 50.** Top-tier (Legendary+) is only 7 slots for 5 anime — doesn't divide evenly, and 3 slots are already spoken for by existing cards. Proposed reassignment, reusing rather than discarding the Phase 3 work:

| Existing card | Rarity | Reassigned to | Notes |
|---|---|---|---|
| Sukuna ("World Cutter") | God | Jujutsu Kaisen | Unchanged — already correct. |
| Gojo ("The Honored Guy") | Legendary | Jujutsu Kaisen | Unchanged — already correct. |
| Tsunade-coded ("The Hundred-Heal Sage") | Legendary | Naruto | Unchanged — already correct. |
| "The Ever-Rising Fist" | Legendary | **Dragon Ball Z** | Reassigned — "always rising in power" fits a Goku-coded Saiyan better than its current unaffiliated flavor. |
| "Iron Gill, the Tide Warden" | Legendary | **One Piece** | Reassigned — a tanky "tide warden" is a natural Jinbe-coded fit. |
| "The Illusion Sovereign" | Mythic | **Demon Slayer** | Reassigned — a shapeshifting illusion-sovereign villain fits a Muzan-coded flagship. |
| "The Nameless One" | Secret | **Unaffiliated (kept as-is)** | Not reassigned — its established "intentional mystery/novelty" identity (Phase 0 audit decision) reads better as a wildcard outside any single anime than forced into one. |

Net: JJK gets 2 top-tier cards (God + Legendary), Naruto/DBZ/One Piece each get 1 Legendary, Demon Slayer gets 1 Mythic, and the Secret card stays a roster-wide wildcard. All 4 reassigned/kept identities stay **parody-style** (never a 1:1 exact name), consistent with the existing convention.

## 4. Per-anime card count

| Anime | Common | Uncommon | Rare | Epic | Legendary+ | Total |
|---|---|---|---|---|---|---|
| Jujutsu Kaisen | 3 | 2 | 2 | 1 | 2 (L, G) | 10 |
| Naruto | 3 | 3 | 2 | 1 | 1 (L) | 10 |
| Dragon Ball Z | 3 | 2 | 2 | 2 | 1 (L) | 10 |
| One Piece | 3 | 3 | 2 | 1 | 1 (L) | 10 |
| Demon Slayer | 2 | 2 | 2 | 2 | 1 (M) | 9 |
| Unaffiliated | 0 | 0 | 0 | 0 | 1 (S) | 1 |
| **Total** | **14** | **12** | **10** | **7** | **4L+1M+1G+1S** | **50** |

Mechanically, this is a **reskin pass**, not a rebalance: each existing Common/Uncommon/Rare/Epic card keeps its numeric slot (rarity, role, stats, passive category) and just gets renamed/rethemed to a same-archetype character from its assigned anime — e.g. an existing Tank/Drain Common becomes a same-role, same-stats character reflavored as a minor character from that anime. This keeps the pass low-risk (no re-derivation of stat bands) while still giving every card a real identity.

## 5. Mechanic depth — how deep does this pass go?

Right now Common/Uncommon/Rare/Epic all share **3 generic role actives** (`CombatConfig.Actives`) — only Legendary+ have real per-card kits. Giving all 43 remaining cards a fully unique `active.effects` table is a large scope jump. Proposed middle ground, **for your approval**:

- **Rare + Epic (17 cards)** get real per-card `active.effects` — extends the existing Legendary+ system one tier down, using the same op vocabulary (`CardAuthoringGuide.md` §4), scaled to their stat band.
- **Common + Uncommon (26 cards)** keep the generic role active, but get real identity through distinctive `passive_desc` flavor and synergy-faction tagging — still meaningfully different card-to-card, without needing 26 more unique kits.
- This also means updating `CardAuthoringGuide.md` afterward, since it currently says Common-Epic should "leave `active` alone" — that instruction was written assuming this pass hadn't happened yet.

## 6. Dungeons

One themed dungeon per anime, built by reskinning the existing `MapGenerator`/`EnemyGenerator` system (same 12-row map shape, guaranteed node minimums, etc. — no new systems code):
- Enemy pool for each anime's dungeon = that anime's own card roster (from §4), reused as enemies — matches the existing "roster doubles as enemy pool" pattern already used by the current generic dungeon.
- Boss = that anime's Legendary+ card (or best Epic, for Demon Slayer/whichever anime's flagship ends up shared).
- Endless Tower stays a single anime-agnostic mode pulling from the full 50-card pool — reskinning it 5 ways isn't worth the effort for a mode that's about endless scaling, not narrative content.

## 7. Execution order — incremental, not one giant pass

Recommend building **one anime at a time**, reviewed before continuing, rather than all 50 cards in one unreviewable dump:

1. **Jujutsu Kaisen first** — already has the most seeded content and the highest built-in hype; smallest gap to close.
2. Naruto → Dragon Ball Z → One Piece → Demon Slayer, in that order.
3. Update `CardAuthoringGuide.md`'s Common-Epic guidance once §5's approach is confirmed.

## 8. Open decisions for you to confirm or adjust

- The 4-card reassignment in §3 (Ever-Rising Fist → DBZ, Iron Gill → One Piece, Illusion Sovereign → Demon Slayer, Nameless One stays unaffiliated).
- The per-anime rarity split in §4 (adjustable — e.g. if you want Demon Slayer at a full 10 instead of 9, something else has to give up a slot).
- §5's Rare+Epic-get-real-kits / Common+Uncommon-stay-generic split — this is the biggest scope lever in the whole plan.
- Pilot order (JJK first, per §7) — say if you'd rather start elsewhere.
