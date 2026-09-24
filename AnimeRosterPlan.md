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
| God (2) | Sukuna, Gojo | — | — |
| Legendary (2) | Itadori, Yuta Okkotsu | — | — |
| Epic (3) | Toji Fushiguro | — | Kenjaku, Geto |
| Rare (5) | Mahito, Jogo, Maki Zenin | Todo, Nanami | — |
| Uncommon (6) | Yuki Tsukumo, Hakari, Naoya Zenin | Panda (hybrid — swaps Tank/DPS each turn) | Shoko, Inumaki |
| Common (7) | Nobara, Megumi, Choso, Mai Zenin | Mechamaru | Utahime, Hiromi Higuruma |

Role totals: 15 DPS, 5 Tank (counting the Panda hybrid as a Tank), 6 Support.

A true-form Sukuna (Tank) is deferred to a future event card and is not part of this roster; the base Sukuna card is DPS only.

**Known gap (flagged, not yet resolved):** no Tank from Epic through God (only Mahoraga at Secret), and no Support from Legendary through God (last Support is Epic). A top-tier pull is always DPS (plus Kenjaku/Geto Support at Epic, or Mahoraga Tank at Secret). May be intentional — JJK's strongest named characters are casters, not tanks — but flagging before kits get written.

**Still open — not decided in this pass:**
- Whether Common/Uncommon get real per-card `active.effects` kits (per §5's proposal) or stay on `CardAuthoringGuide.md`'s current generic-role-active rule for Common-Epic. This matters more now than when §5 was written, since these are named characters with iconic techniques (Nobara's Straw Doll, Choso's blood curses, etc.), not placeholder archetypes.
- Synergy factions for the new 26-character list — §9's two factions (Best Friends, First Years) still work membership-wise but weren't re-tuned for Itadori's rarity change (Epic→Legendary) or the 4 newly-added characters that might fit a faction.
- Individual card stats/passives/actives — not started. Next step per `CardAuthoringGuide.md` §5's checklist, working bottom-up from Common.

(All three were resolved on 2026-09-24. Every JJK card gets its own ability kit; the two §9 factions ship; stats, passives and actives are built. See §11.)

## 11. Card structure & combat rules (decided 2026-09-24, implemented with the JJK-26 build)

This section is the source of truth for how every card is built from here on. Where it conflicts with `CardAuthoringGuide.md` §2/§4 (written for the old placeholder roster), this wins.

### 11.1 Anatomy of a card

| Field | Meaning |
|---|---|
| ATK / HP | Per-rarity bands in `CardAuthoringGuide.md` §1 (unchanged). |
| Role | Tank / DPS / Support. |
| Subrole | One of two per role (below). Every card has exactly one. |
| Mana cost (`mp`) | Whole points, **2-5**. 2 = cheap/frequent, 3 = standard, 4 = heavy, 5 = ultimate (God/Secret). |
| Passive | Either a role-passive category (Drain / Rage / Executioner / Medic / Battery, same numbers as before) **or** a unique **Trait**. |
| Active | The card's special ability, cast when mana is full. Every JJK card gets its own kit (`active.effects`), Commons included. |

### 11.2 Mana

- **+1 mana per swing landed** (one basic-attack hit). No per-round gain, and no gain from being hit.
- The ability fires **the moment the bar is full** (right after the swing that fills it) and does **not** replace the unit's attack.
- Leftover fractions carry over, so "+X% mana gain" items still matter. Casting spends exactly the cost.
- A stunned unit skips its attack, so it gains no mana that turn.
- Old effects, reinterpreted: Void Walkers' "cast at 90% MP" becomes **abilities cost 1 less mana (min 1)**. Battery restores **1 mana** to allies on any death.

### 11.3 Subroles

| Role | Subrole | Identity |
|---|---|---|
| DPS | **Duelist** | Single-target damage. |
| DPS | **Skirmisher** | Area damage (hits the whole enemy row). |
| Tank | **Vanguard** | Protection: shields and soaking damage for the team. |
| Tank | **Juggernaut** | Crowd control: stuns and disruption. |
| Support | **Enchanter** | Buffs and aid: heals, ATK buffs, mana for allies. |
| Support | **Hexer** | Debuffs: weakens enemies (ATK/defense shred, mana drain). |

Hexer ATK debuffs are capped at **-20%** total so they can't cancel the DPS counter. Subrole **set bonuses** (e.g. 2 Duelists unlock an effect) are **not decided yet**. For now subroles are an identity and a UI label.

### 11.4 Role counter cycle (all 10%)

**Tank → DPS → Support → Tank.** Each counter is triggered by the *enemy's* role, never your own, so pairing roles on your own team never stacks a counter.

| Counter | Rule |
|---|---|
| Tank beats DPS | Tanks take 10% less damage from enemy DPS. |
| DPS beats Support | DPS deal 10% more damage to enemy Supports (Supports are fragile). |
| Support beats Tank | Supports deal 10% more damage to enemy Tanks, and Support effects (heals, shields, buffs, debuffs) are 10% stronger while the enemy frontline is a Tank. |

Planned UI: a small ⓘ "counter wheel" popup (three role icons with a one-line label on each arrow), opened from team select and the battle screen. Not a permanent panel.

### 11.5 Role stacking bonus

For each card of the same role on your team: **+5 / +10 / +15 / +18 / +20%** (diminishing after 3). DPS → +ATK, Tank → +Max HP, Support → ability effectiveness (heals, shields, buffs and debuffs cast by Supports).

### 11.6 Traits

A Trait is a unique passive that replaces the role-passive category. Rule: **Epic and above get Traits**. Lower rarities get one only when the character's identity demands it; Panda's hybrid form is the only current exception. The user designed Itadori's Trait; the rest were drafted during the build.

### 11.7 JJK card sheet (as built)

Card names are parody-style per the theme rule; the character is in brackets. Stats sit inside the §1 bands (Secret is exempt).

| Rarity | Card [character] | Role / Subrole | Mana | ATK / HP | Passive / Trait | Active |
|---|---|---|---|---|---|---|
| Secret | The Eight-Handled Wheel [Mahoraga] | Tank / Juggernaut | 4 | 2200 / 16000 | **Trait: Adaptation.** Each hit from the same enemy makes that enemy's later hits on it deal 10% less (max 50%). | **Sword of Extermination:** 400% ATK true damage to the frontline enemy, and stuns it for 1 turn. |
| God | World Cutter [Sukuna] | DPS / Skirmisher | 5 | 2600 / 8200 | **Trait: Dismantle.** Every basic attack also slashes the next enemy in line for 50% ATK. | **Malevolent Shrine:** 600% ATK true damage to every enemy, and permanently cuts 10% off their Max HP. |
| God | The Honored One [Gojo] | DPS / Skirmisher | 5 | 2400 / 8600 | **Trait: Infinity.** The first hit Gojo takes each round deals no damage. | **Hollow Purple:** 500% ATK to every enemy, and stuns them all for 1 turn. |
| Legendary | The Cursed Vessel [Itadori] | DPS / Duelist | 2 | 780 / 2400 | **Trait: Divergent Fist.** The first attack each turn strikes twice. The second swing deals the first swing's damage + 0.8% of the target's current HP. Both swings give mana. | **Black Flash:** a 100% ATK strike that always crits, at 2.5x instead of 1.5x. |
| Legendary | Rika's Beloved [Yuta] | DPS / Skirmisher | 4 | 950 / 2600 | **Trait: Queen of Curses.** The first time Yuta would die, he survives at 1 HP and gains a shield worth 30% of his Max HP. | **Pure Love:** 350% ATK to every enemy. |
| Epic | The Sorcerer Killer [Toji] | DPS / Duelist | 3 | 640 / 1400 | **Trait: Heavenly Restriction.** Can't be stunned, ignores enemy ATK debuffs, +10% crit chance. | **Inverted Spear:** 300% ATK to the lowest-HP enemy, ignoring shields. |
| Epic | The Stitched-Brow Schemer [Kenjaku] | Support / Hexer | 4 | 520 / 1600 | **Trait: Thousand-Year Plan.** Gains 1 mana whenever an enemy casts an ability. | **Maximum Uzumaki:** 150% ATK to every enemy, and shreds 5% of their defense (stacking to 20%). |
| Epic | The Curse Collector [Geto] | Support / Enchanter | 4 | 480 / 1700 | **Trait: Cursed Spirit Manipulation.** All allies start the battle with 1 mana. | **Spirit Swarm:** gives every other ally 1 mana and +6% ATK (stacking to 18%). |
| Rare | The Soul Sculptor [Mahito] | DPS / Skirmisher | 4 | 360 / 780 | Executioner | **Idle Transfiguration:** 120% ATK true damage to every enemy. |
| Rare | Volcano Head [Jogo] | DPS / Skirmisher | 4 | 400 / 620 | Rage | **Maximum: Meteor:** 160% ATK to every enemy. |
| Rare | The Cursed-Tool Prodigy [Maki] | DPS / Duelist | 3 | 380 / 900 | Rage | **Split Soul Katana:** 250% ATK to the frontline enemy. |
| Rare | The Boogie-Woogie Brother [Todo] | Tank / Juggernaut | 3 | 330 / 1250 | Drain | **Boogie Woogie:** 120% ATK to the frontline enemy, and stuns it for 1 turn. |
| Rare | The Overtime Salaryman [Nanami] | Tank / Vanguard | 3 | 300 / 1300 | Drain | **Ratio 7:3:** 150% ATK guaranteed crit on the frontline enemy, then shields every ally for 10% of their Max HP. |
| Uncommon | The Star-Mass Wanderer [Yuki] | DPS / Duelist | 4 | 230 / 560 | Rage | **Bonbaye:** 280% ATK to the frontline enemy. |
| Uncommon | The Jackpot Gambler [Hakari] | DPS / Duelist | 3 | 210 / 620 | Rage | **Idle Death Gamble:** 120% ATK hit. A 1-in-3 jackpot fully heals Hakari and gives him +10% ATK permanently. |
| Uncommon | The Projection Sprinter [Naoya] | DPS / Duelist | 2 | 245 / 480 | Executioner | **24 Frames:** 140% ATK to the frontline enemy, and freezes (stuns) it for 1 turn. |
| Uncommon | The Cursed Corpse Bear [Panda] | Tank / Juggernaut | 3 | 200 / 900 | **Trait: Three Cores.** Odd rounds: Tank form (-20% damage taken, counts as Tank for counters). Even rounds: Gorilla form (+25% ATK, counts as DPS for counters). | **Drumming Beat:** 150% ATK to the frontline enemy, and stuns it for 1 turn. |
| Uncommon | The Reverse-Cursed Medic [Shoko] | Support / Enchanter | 3 | 150 / 520 | Medic | **Reverse Cursed Technique:** heals every ally for 14% of their Max HP. |
| Uncommon | The Onigiri Speaker [Inumaki] | Support / Hexer | 3 | 160 / 500 | Battery | **Cursed Speech: Don't Move:** stuns the frontline enemy for 1 turn, and cuts enemy ATK by 4% (stacking to 12%). |
| Common | The Straw Doll Striker [Nobara] | DPS / Duelist | 3 | 135 / 360 | Executioner | **Resonance:** 150% ATK true damage to the frontline enemy. |
| Common | The Shadow Summoner [Megumi] | DPS / Skirmisher | 3 | 120 / 450 | Rage | **Divine Dogs:** 70% ATK to every enemy. |
| Common | The Blood Brother [Choso] | DPS / Skirmisher | 3 | 130 / 420 | Rage | **Supernova:** 60% ATK to every enemy, and shreds 3% of their defense (stacking to 12%). |
| Common | The Revolver Heiress [Mai] | DPS / Duelist | 2 | 145 / 290 | Executioner | **Final Bullet:** 160% ATK to the lowest-HP enemy. |
| Common | The Puppet Pilot [Mechamaru] | Tank / Vanguard | 3 | 70 / 780 | Drain | **Absolute Guard:** shields every ally for 8% of their Max HP. |
| Common | The Solo Songstress [Utahime] | Support / Enchanter | 3 | 60 / 400 | Medic | **Solo Forbidden Area:** every ally gains +4% ATK (stacking to 16%). |
| Common | The Courtroom Judge [Higuruma] | Support / Hexer | 3 | 65 / 420 | Battery | **Confiscation:** drains 2 mana from the frontline enemy. |

Role totals: 15 DPS / 5 Tank (Panda counted as Tank) / 6 Support. Gojo (id 46) and Sukuna (id 49) are reworked in place; the other 24 get new ids. The 48 remaining placeholder cards stay as they are, with `mp` converted to 3-5 mana.

**Synergies:** §9's two factions ship as designed, minus the Executioner-threshold tweak (no current member uses Executioner). **Best Friends** (Itadori + Todo) @2: +18% ATK. **First Years** (Itadori + Nobara + Megumi) @2: +8% ATK/HP; @3: +12% ATK/HP, and the first member to drop below 30% HP gets a one-time shield worth 20% of their Max HP. The other 21 JJK cards have no faction yet; that's still open.

**Balance flags for playtesting:** Itadori casts Black Flash every turn by design (2 swings × 1 mana = cost 2), so his ATK sits at the low end of the Legendary band to compensate. The 0.8%-of-current-HP bonus is implemented as specified but is small (about 20-60 damage). It's one number in `CombatConfig.Traits` if it should be 8%.
