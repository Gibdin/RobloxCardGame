# Anime Roster & Dungeon Plan

This is the deferred "card-design-depth pass" the project has been saving up since Phase 3 (`GameDesign.md`) — turning the current 50 placeholder cards into a real anime-themed roster with actual mechanical identity, plus the anime-themed dungeons the Theme note in `GameDesign.md` always intended. Companion to `CardAuthoringGuide.md` (routine-addition rules) — this doc is the one-time restructuring pass, not routine.

**Not yet implemented — this is the plan for review before any `CardDatabase.lua` changes.**

**2026-08-26 update:** §1's "does not expand the total count" no longer holds for JJK — see §9. JJK is now the pilot for a merged, larger expansion (this pass + Phase 9's separately-deferred 50→200+ roster expansion), sized up before the other 4 anime are touched. Sections 1-8 below are the original as-reviewed plan and still apply to Naruto/DBZ/One Piece/Demon Slayer until JJK-21 is finished and reviewed.

**2026-09-23 update:** §9's 22-card roster/rarity/reskin table is superseded by a character-first pass — see §10. The pilot grew to 26 named characters, chosen before rarity was assigned (reversing §9's count-first approach). §9's synergy character lists (Best Friends, Best Friends' Itadori+Todo; First Years' Itadori+Nobara+Fushiguro) still hold membership-wise but haven't been re-balanced against the new rarity assignments in §10. §9 is kept for history/reasoning, not as the current source of truth.

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

## 9. JJK-21 pilot (supersedes §1's "no count change" for this anime only)

Rather than deciding the full 50→200 expansion (10 anime pillars × 20 cards) in one sitting, JJK becomes the proof-of-concept pillar at a larger size first. Pillars 6-10 (5 more anime, TBD) and the global rarity budget stay undecided until this pilot is finished and reviewed — the same "reviewed before continuing" order from §7, just applied one level up. Naruto/DBZ/One Piece/Demon Slayer stay at the original 10-card assumption (§1-§8) until then.

**JJK rarity split (22 cards, updated 2026-08-31):** 6 Common / 5 Uncommon / 4 Rare / 3 Epic / 2 Legendary / 1 God / **1 Secret (Mahoraga)**. Sukuna and Gojo stay the only *original* top-tier cards; one more Legendary is added new. Secret sits outside normal stat banding (per `CardAuthoringGuide.md`'s exempt joke-tier rule) and outside the 21-count, same as the roster-wide "Nameless One" Secret — this makes 2 Secret cards total across the whole roster, the ceiling for keeping the tier exclusive; no more Secrets should get added for other pillars.

**Synergies** (pure data — read generically off `card.series` by `BattleEngine`/`RoleConfig.Synergies`/`CombatConfig.Synergies`, same mechanism as the existing 8 fantasy factions; no engine change):
- **Best Friends** (maxCount 2) — Itadori + Todo. Tier @2: +18% ATK to both; Executioner passives trigger 5% HP earlier (35%→40%).
- **First Years** (maxCount 3) — Itadori (double-tagged, max 2 series/card per `CardAuthoringGuide.md` §3) + Nobara + Fushiguro. Tier @2: +8% ATK / +8% HP. Tier @3: +12% ATK / +12% HP, first ally below 30% HP gets a one-time 20%-Max-HP shield.

**Card assignment** ("reskin" = existing `CardDatabase.lua` id, stats/band already set, just rename+reflavor; "new" = no existing id, full authoring via `CardAuthoringGuide.md`):

| Rarity | Character / slot | Status |
|---|---|---|
| Secret | **Mahoraga** | Open — new, exempt stat band |
| God | Sukuna, "World Cutter" | Done — untouched |
| Legendary | Gojo, "The Honored Guy" | Done — untouched |
| Legendary | — | Open — new |
| Epic | Itadori (id 37, reskin of "Void Sorcerer") | Cast — needs `CardDatabase.lua` edit |
| Epic | — | Open — new |
| Epic | — | Open — new |
| Rare | Todo (id 27, reskin of "Aether Mage") | Cast — needs `CardDatabase.lua` edit |
| Rare | **Nanami** (id 28, reskin of "Golden Warden", Tank/Drain) | Cast — needs `CardDatabase.lua` edit |
| Rare | — | Open — new |
| Rare | — | Open — new |
| Uncommon | **Panda** (id 15, reskin of "Silver Paladin", Tank/Drain) | Cast — needs `CardDatabase.lua` edit |
| Uncommon | **Shoko** (id 16, reskin of "Thornvine Druid", Support/Medic) | Cast — needs `CardDatabase.lua` edit |
| Uncommon | **Inumaki** (Support/Battery — utility flavor) | Open — new, character decided |
| Uncommon | — | Open — new |
| Uncommon | — | Open — new |
| Common | Nobara (id 1, reskin of "Iron Soldier") | Cast — needs `CardDatabase.lua` edit |
| Common | Fushiguro (id 2, reskin of "Copper Knight") | Cast — needs `CardDatabase.lua` edit |
| Common | **Choso** (id 3, reskin of "Rusted Golem", Tank/Drain) | Cast — needs `CardDatabase.lua` edit |
| Common | — | Open — new |
| Common | — | Open — new |
| Common | — | Open — new |

**2 done (no edit needed), 8 cast (character decided, edit pending), 2 new-card slots with character already decided (Inumaki, Mahoraga), 10 open new cards (character TBD) = 22 total.**

## 10. JJK-26 revision (supersedes §9's roster — character-first pass)

§9 picked a total count first and backfilled characters into open slots. This revision reversed that: 26 specific named characters were picked first, then rarity and role were derived from that list. This section is the current source of truth for the JJK roster; §9's specific card/rarity table above is kept for history only.

**Rarity split (26 total, decided 2026-09-23):** 7 Common / 6 Uncommon / 5 Rare / 3 Epic / 2 Legendary / 2 God / 1 Secret. Two decisions worth calling out since they depart from §9:
- **God is now 2 cards, not 1** — the reasoning was that having exactly one card at the single highest rarity (Secret) with no "runner-up" tier bigger than 1 read oddly, so God was bumped to 2 and Epic absorbed the corresponding reduction (4→3).
- **Gojo moved from Legendary to God** (paired with Sukuna — matches the "strongest vs. strongest" rivalry that's central to JJK), swapping with **Kenjaku** (God→Legendary→Epic across two swaps) and **Itadori** (Epic→Legendary, swapped with Kenjaku's final Legendary→Epic move).

**Full roster (26), by rarity then role:**

| Rarity | DPS | Tank | Support |
|---|---|---|---|
| Secret (1) | — | Mahoraga | — |
| God (2) | Sukuna (DPS / true-form Tank), Gojo | — | — |
| Legendary (2) | Itadori, Yuta Okkotsu | — | — |
| Epic (3) | Toji Fushiguro | — | Kenjaku, Geto |
| Rare (5) | Mahito, Jogo, Maki Zenin | Todo, Nanami | — |
| Uncommon (6) | Yuki Tsukumo, Hakari, Naoya Zenin | Panda (hybrid — swaps Tank/DPS each turn) | Shoko, Inumaki |
| Common (7) | Nobara, Megumi, Choso, Mai Zenin | Mechamaru | Utahime, Hiromi Higuruma |

Role totals: 15 DPS, 4 pure Tank + 1 Tank/DPS hybrid (Panda), 6 Support.

**Known gap (flagged, not yet resolved):** no Tank from Epic through God (only Mahoraga at Secret), and no Support from Legendary through God (last Support is Epic). A top-tier pull is always DPS (plus Kenjaku/Geto Support at Epic, or Mahoraga Tank at Secret). May be intentional — JJK's strongest named characters are casters, not tanks — but flagging before kits get written.

**Still open — not decided in this pass:**
- Whether Common/Uncommon get real per-card `active.effects` kits (per §5's proposal) or stay on `CardAuthoringGuide.md`'s current generic-role-active rule for Common-Epic. This matters more now than when §5 was written, since these are named characters with iconic techniques (Nobara's Straw Doll, Choso's blood curses, etc.), not placeholder archetypes.
- Synergy factions for the new 26-character list — §9's two factions (Best Friends, First Years) still work membership-wise but weren't re-tuned for Itadori's rarity change (Epic→Legendary) or the 4 newly-added characters that might fit a faction.
- Individual card stats/passives/actives — not started. Next step per `CardAuthoringGuide.md` §5's checklist, working bottom-up from Common.
