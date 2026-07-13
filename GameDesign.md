# RoguelikeTCG — Game Design & Roadmap

**Vision:** Become the best addictive-dopamine-loop gacha/autochess game on Roblox — a deep collection game (pull, build, battle, climb) wrapped in a real social world, backed by a full monetization economy and live-ops content pipeline.

**Theme (added 2026-07-13):** this is an anime card game — cards are built around the likeness of popular anime characters rather than generic original fantasy units, and Dungeon Crawl content is themed per specific anime series. This reframes card content (existing and Phase 9 roster expansion) and dungeon theming work, and Phase 3's per-card actives should read as that character's signature move. **Open and unresolved:** whether to use real trademarked character names/likenesses (real IP/moderation/legal risk on Roblox) vs. original characters clearly inspired by/parodying popular anime archetypes (the safer, common industry pattern) — confirm with the user before writing card content that commits to either direction.

This document has two parts:
1. **Current State Audit** — what's actually built today, with file references, so nobody re-derives it from scratch.
2. **The Blueprint (Phase 0 → Phase 10)** — the sequenced roadmap from today's state to a ~90%-finished, launch-ready game. Each phase lists concrete systems/files to add or touch and a definition of done.

Scope decisions already locked in:
- **Combat direction:** deepen the existing linear auto-battle simulation (per-card unique actives, more passives, reconciled tooltips) rather than build a positioning/board autochess.
- **World:** build a real walkable 3D social hub (currently the game has none).
- **Social:** go all-in — async PvP, live real-time PvP duels, guilds, and card trading.
- **Monetization:** full gacha monetization — premium currency, purchasable packs, Battle Pass, VIP gamepass, rate-up banners, Roblox-compliant odds disclosure.

---

## Part 1 — Current State Audit

### Gacha / Economy
Files: `src/shared/GachaSystem/{RarityConfig,CardDatabase,RoleConfig}.lua`, `src/server/GachaSystem/Services/{PityService,CardService,RollService,PackService,InventoryService}.lua`

- **50 cards** exist: 14 Common / 12 Uncommon / 10 Rare / 7 Epic / 4 Legendary / 1 Mythic / 1 God / 1 Secret. Card #50 "The Nameless One" (Secret) has literal `"???"` placeholder passive/active text — an intentional mystery card that still needs a real kit eventually.
- **Rarity weights:** Common 45, Uncommon 25, Rare 15, Epic 8, Legendary 4, Mythic 2, God 0.8, Secret 0.2 (`RarityConfig.Rarities`).
- **Pity system:** a single global lifetime-roll counter with hard-pity floors at 10 rolls (≥Rare), 30 (≥Epic), 75 (≥Legendary), 150 (≥Mythic), 400 (≥God) (`RarityConfig.PityThresholds`). Highest matching floor wins; the counter only resets when a floor was active and met — natural high-rarity pulls before a floor don't reset it. This system is solid and complete, no changes planned.
- **3 pack types:** `StandardPack` (base odds), `RarePack` (Rare/Epic/Legendary rate-up), `EventPack` (Epic+ rate-up). **No purchase path exists for any of them today** — packs are earned only via Dungeon/Tower run rewards plus a 3-pack starter grant on first join. `PackOpeningUI.lua:250-257` has a dead "Economy" placeholder label explicitly reserved for a currency HUD that was never wired up.
- **Duplicates → Awakening:** pulling an owned card increments an "awakening" counter (capped at 10) instead of granting currency. No consumption/bonus logic for awakening was found in the reviewed gacha files (may live in combat config, worth confirming before Phase 3 changes anything here).
- **Persistence:** a real DataStore save exists (`GachaInventory_v2`, single key `u_<userId>`) storing cards, awakening, packs, pity snapshot, team, and best-run stats. **Fragile today:** it only saves on `PlayerRemoving`, with no periodic autosave and no `game:BindToClose` handler — a non-graceful server shutdown loses all progress since the player's last leave. Gold is deliberately excluded from persistence (it's a run-scoped roguelike currency).
- **Monetization:** confirmed **zero** — no `MarketplaceService`, `GamePass`, `DeveloperProduct`, or `Robux` references anywhere in `src/`. No premium currency exists. This is the single largest gap relative to the "gacha economy" vision.

### Combat
Files: `src/shared/GachaSystem/{CombatConfig,RoleConfig}.lua`, `src/server/GachaSystem/Services/BattleEngine.lua`, `src/client/GachaSystem/{BattleController,BattleStats}.lua`, `UI/BattleUI.lua`, `VFX/{SoundManager,VFXConfig}.lua`, `UI/FxUtil.lua`

- **Engine shape:** a deterministic, seeded, server-side simulation (`BattleEngine.Resolve`) — **not** a positioning/board autochess. Teams are linear 5-slot queues; every round, all living units on each side attack the enemy's current frontline slot simultaneously; when the frontliner dies the next slot advances automatically. The client does zero combat math — `BattleController` is pure event-log playback with adjustable speed (1x/2x) and a Skip mode.
- **Roles/passives:** 3 roles — Tank (passive: Drain), DPS (passives: Rage or Executioner), Support (passives: Medic or Battery) — each with a role-count team bonus capped at 3 stacks.
- **Actives are currently generic per role, not per card** — `CombatConfig.lua:25` explicitly comments this as "v1 — per-card unique actives come later." Every DPS card shares one active, every Support shares one, every Tank shares one. This is the single biggest combat-identity gap: 50 unique cards currently reduce to 3 functional "kits" in battle.
- **Synergies:** 8 TFT-style factions (Iron Legion, Nature's Call, Storm Riders, Shadow Covenant, Abyssal Order, Divine Pantheon, Void Walkers, Ancient Ones), each with 2-3 member-count thresholds granting qualitative (not just stat) bonuses. Two known flavor-text/mechanic mismatches need reconciling: Storm Riders' displayed "attack speed" text is actually flat +ATK (`CombatConfig.lua:62`); Void Walkers' displayed "-1 MP cost" text is actually a lowered cast threshold (`CombatConfig.lua:80`).
- **Damage model:** base ATK × role/synergy multipliers × variance (0.95-1.05) × 5% crit (1.5x) × amplifiers (execute bonus, marks, etc.) × damage reduction (clamped 0-80%). Minimum 1 damage. Revive mechanics (item-based and Divine Pantheon T4) are implemented.
- **Presentation layer is production-quality, not a stub:** rarity-colored unit frames, animated HP/MP/shield bars, attack/death/advance animations, floating damage numbers (crit-scaled), merged camera-shake system, a dedicated "final blow" cinematic beat (silence → flash → heavy shake → hold), a full scrolling battle log, synergy-proc toasts, and a staggered results screen with count-up gold/XP and a distinct "bonus loot" reveal. Pooled + pitch-varied SFX with real asset IDs mostly filled in — only `low_hp_warn` is still the silent placeholder `rbxassetid://0`.
- **Team building:** hard 5-slot team, no role lock, slot order determines frontline order, persisted via debounced save.

### Progression (Dungeon Crawl + Endless Tower)
Files: `src/shared/GachaSystem/{DungeonConfig,TowerConfig}.lua`, `src/server/GachaSystem/Services/{DungeonService,TowerService,MapGenerator,EnemyGenerator,RunModifiers,RunLock}.lua`, `src/client/GachaSystem/{DungeonController,UI/DungeonMapUI,UI/TowerUI,UI/ModeSelectUI,UI/ShopUI,UI/EliteBuffUI,UI/RunTeamPanel}.lua`

- **Two modes, one run lock per player** (`RunLock` — a player can only have one active run, Dungeon or Tower, at a time).
- **Dungeon Run:** a seeded 12-row map (2-4 nodes/row: Mob/Elite/Shop/Rest) plus a Boss row, with guaranteed minimums (≥2 shops, ≥2 elites, ≥1 rest) and full reachability. Honest pre-battle previews are baked up front from the same deterministic seed used to fight. Full loop implemented end-to-end: fight/shop/rest/elite-buff-pick, XP/leveling (cap 10), gold (run-scoped shop currency for items/heals/rerolls), bonus loot rolls (12% on Mob/Elite wins), Boss win grants 2 RarePacks and completes the run.
- **Endless Tower:** linear floor climb, boss every 5th floor, milestone pack rewards at floors 5/10/15/20 then every 10 after, 10% bonus-pack roll per floor win, and difficulty that scales exponentially past floor 25 — an intentional soft-cap so every run eventually ends in death (no "victory" end-state, only death or abandon).
- **Meta-progression today is minimal:** only `tower.bestFloor` and `dungeon.deepestRow`/`runsCompleted`/`bossKills` persist as max-ratchet counters. All run state — levels, items, buffs, gold, map position — fully resets every run by design. No unlock trees, no seasons, no leaderboards exist yet.
- **Known dead code:** `ModeSelectUI.lua:100-101`'s "Coming Soon" branch is unreachable (`dungeonReady` is hardcoded `true` upstream) — harmless but should be cleaned up.
- **Overall:** both loops are genuinely playable end-to-end today, no dead stubs — this is a strong foundation to build monetization and retention systems on top of.

### World & UI
- **Workspace contains only `Baseplate`, `Terrain`, `SpawnLocation`, `Camera`.** There is no hub, no NPCs, no environment of any kind — the entire game today is ScreenGui menus rendered over a blank void. This is the biggest gap relative to Roblox's core social-discovery strengths.
- **Navigation:** `SideMenuUI` — a persistent 5-button left rail (Packs / Inventory / Team / Battle / Settings), plus a Studio-only Debug button. Settings is still a literal `"Coming Soon"` stub panel (`PackOpeningController.client.lua`'s `makeStubPanel`).
- **Established UI convention (keep and extend, don't redesign):** compact panels, 0.08-0.15 background transparency so the world (once built) stays visible through UI, team bar capped ~110-120px tall, full-screen/opaque treatment reserved only for pack-opening reveals.

---

## Part 2 — The Blueprint: Phase 0 → Phase 10

Phases are ordered so each unblocks the next — monetization needs stable persistence first; live PvP reuses the hub's arenas; guild halls reuse the hub; trading needs a mature economy to balance against. By the end of Phase 10 the game is ~90% feature-complete; the remaining 10% is post-launch live-ops iteration using the Phase 9 content pipeline.

### Phase 0 — Foundation Hardening ✅ Shipped 2026-07-13
**Goal:** stabilize what exists before building revenue and social systems on top of it.

- `Main.server.lua` / `InventoryService.lua`: add a `game:BindToClose` handler that saves all online players, plus a periodic autosave loop (~every 2 minutes) alongside the existing leave-triggered save. Add retry/backoff on `SetAsync` failure.
- `VFXConfig.lua`: fill every remaining `rbxassetid://0` placeholder — confirmed `low_hp_warn`; also verify pack-opening SFX (`rip_click_N`, `pack_burst`, `roll_tick`, etc.) are real asset IDs.
- `RoleConfig.lua`: reconcile the Storm Riders ("attack speed" → actually flat +ATK) and Void Walkers ("-1 MP cost" → actually lowered cast threshold) tooltip/mechanic mismatches.
- `PackOpeningController.client.lua`: replace the `SETTINGS` stub with a real panel (audio volume, screen-shake toggle, low-HP warning toggle, UI scale, credits).
- `ModeSelectUI.lua` / `DungeonConfig.lua` / `DungeonService.lua`: remove the dead `dungeonReady == false` branch and the stale "Phase 4/5 not yet enabled" comments describing a rollout that already shipped.
- Decide and document card #50's `"???"` treatment (feeds Phase 3's per-card active work).

**Definition of done:** a server crash loses no more than ~2 minutes of progress; no silent placeholder audio remains; Settings is a real panel; no dead UI branches remain.

### Phase 1 — Monetization Core & Premium Economy ✅ Shipped 2026-07-13 (code complete; live purchase testing blocked until the place is published — see note below)
**Goal:** ship the primary revenue engine. Needs Phase 0's reliable persistence underneath it.

> **Publish blocker:** this place is not yet published to Roblox, so real Developer Products/Game Passes can't be created yet. Every product/pass id in `MonetizationConfig.lua` is a placeholder (`0`) — `MonetizationService` treats that as "not configured" and refuses to prompt. Once published, create the Gem packages, VIP pass, and Battle Pass product in the Creator Dashboard and paste the real ids into `MonetizationConfig.lua`; no other code changes are needed.

- New `src/shared/GachaSystem/MonetizationConfig.lua`: Gem package tiers, gem→pack price table, VIP gamepass benefits, Battle Pass tier costs/rewards, banner rate-up definitions.
- New `src/server/GachaSystem/Services/MonetizationService.lua`: wraps `MarketplaceService` (`PromptProductPurchase`/`ProcessReceipt` for Gems and pack bundles, `PromptGamePassPurchase`/`UserOwnsGamePassAsync` for VIP). Persists `gems`, `vipOwned`, `battlePass` into the existing `InventoryService` blob using its established backward-compatible-default migration pattern.
- Extend `PackService`/`RollService` so packs can be bought directly with Gems, and add a **Banner** system: a rotating limited-time featured card with a boosted rate (extends the existing `RarityConfig.PackTypes` multiplier pattern with a per-banner override) plus a "featured guarantee" pity carry-over after N pulls without the rate-up unit.
- New `src/client/GachaSystem/UI/ShopStoreUI.lua` (separate from the in-run `ShopUI.lua`, which stays dungeon-only): Gem packages, VIP purchase, Battle Pass screen, banner storefront. Wires a real currency HUD into the "Economy" placeholder slot already reserved in `PackOpeningUI.lua`.
- **Compliance:** build an odds-disclosure panel (reuses `RarityConfig.Rarities` weights) shown before any real-money pack purchase, plus a permanent "View Odds" link — required for randomized virtual item purchases under Roblox policy.
- Battle Pass here is a skeleton (currency/tier tracking only); its real XP feed wires up in Phase 4.

**Definition of done:** a player can buy Gems with Robux, spend Gems on packs/banners, own VIP, and see disclosed odds before any purchase; all balances persist and survive Phase 0's autosave/BindToClose path.

### Phase 2 — World Hub & Physical Presence ✅ Shipped 2026-07-13
**Goal:** give the game an actual world. Cosmetic monetization and later social phases (PvP arenas, guild halls) need a physical space to live in.

> **Built procedurally, not hand-authored in Studio:** `Hub.rbxl` (and all of Workspace) is gitignored, so any geometry built by hand in Studio would be invisible to git and unreproducible from a fresh clone. `HubService.lua` builds the entire hub — plaza, altar, vendor stalls, reserved zones, spawn points, lighting/atmosphere — from primitives on every server start, reading layout from `HubConfig.lua`. This is the only way Phase 2 stays consistent with how every other system in this project works.

- New `src/shared/GachaSystem/HubConfig.lua` + `src/server/GachaSystem/Services/HubService.lua`: a circular plaza, a central **summoning altar** (glowing pillar + `ProximityPrompt`, triggers the existing pack-opening UI — `FlashSequence`/`CardReveal` unchanged, just triggered from the world instead of only a menu), 3 vendor stalls (Gem Merchant → `ShopStoreUI`, Card Keeper → `InventoryUI`, Battle Herald → `ModeSelectUI`/battle), reserved marked zones for Phase 6's PvP arena and Phase 7's guild hall, and 4 spawn points around the plaza edge (replacing the default baseplate/spawn). Interactions route through a new `HubInteract` RemoteEvent to the same client UI the side menu already opens — the hub is an alternate entry point, not a parallel system.
- New `src/shared/GachaSystem/CosmeticConfig.lua` + `src/server/GachaSystem/Services/CosmeticService.lua`: Gem-purchased cosmetic Trails (native Roblox `Trail` + `Attachment` instances using only Color/Transparency sequences — no texture/mesh asset needed, sidestepping the placeholder-asset problem entirely). Purchased/equipped state persists in `InventoryService`; the equipped trail re-attaches on every respawn. A COSMETICS tab was added to `ShopStoreUI`.
- Reserved hub zones for Phase 6 (arena) and Phase 7 (guild hall) are built now, empty and marked, so those phases are additive.
- The existing compact-UI convention is preserved: all `SideMenuUI` panels (now including a new STORE button) remain reachable from anywhere, independent of the hub.
- **Fixed along the way:** a real startup race in `Main.server.lua` where a player could join before `InventoryService:Load` ran (exposed once hub-building added enough synchronous startup work to widen the window) — the player-lifecycle connections now register before any heavier startup work, and `InventoryService`'s internal `get()` additionally self-heals via a lazy-load fallback so this class of bug can't hard-error again.

**Definition of done:** joining the game drops the player into a populated, walkable space, not a menu; opening a pack, visiting the shop, and starting a run are all triggerable from world interaction as well as the side menu; multiple in-server players can see each other. Verified in Studio end-to-end (world geometry, all 4 hub interactions, and a full Gem→cosmetic purchase→equip round trip through the real client-invoked remotes).

**Definition of done:** joining the game drops the player into a populated, walkable space, not a menu; pack-opening/shop/run-start are all triggerable from world interaction as well as the side menu; multiple in-server players can see each other.

### Phase 3 — Card Identity & Combat Depth ✅ Core shipped 2026-07-13
**Goal:** make all 50+ cards feel individually worth pulling — directly resolves the `CombatConfig.lua:25` "generic v1 actives" gap.

> **Theme note:** per the anime-card-game direction (see the Theme section above), all 7 Legendary+ cards were re-identified as original parody characters clearly evocative of popular anime characters' signature techniques/epithets (e.g. a Gojo-style "unblockable, unavoidable strike" character named "The Honored Guy", a Sukuna-style "cuts through any defense" character named "World Cutter") — never the real trademarked name/likeness. This same parody-naming convention should carry forward into Phase 9's roster expansion and any dungeon theming work.

> **Placeholder-quality, on purpose:** the user confirmed 2026-07-13 that these 7 cards/kits are explicit placeholders — functional and mechanically tested, not the target for creative depth yet. A dedicated pass on genuinely fun/unique/interesting card mechanics and synergies is intentionally deferred until after the full Phase 0-10 MVP is built (breadth before depth). Don't invest extra design effort into card creativity during Phase 4-10 work; treat this the same way for Phase 9's roster expansion until the user explicitly asks for the depth pass.

- `CardDatabase.lua`'s `active` field now supports a per-card `effects` array — an ordered list of small reusable op primitives (`aoe_damage`, `true_damage_all`, `single_true_execute`, `heal_all`/`heal_lowest`, `shield_all`/`shield_self`, `stack_atk_buff`, `enemy_atk_shred`/`enemy_dr_shred`, `maxhp_shred_all`) that `BattleEngine.lua`'s new `Resolver:runActiveStep` executes. All 7 Legendary/Mythic/God/Secret cards (including #50, now with a real triple-effect kit that quietly out-powers the God-tier card — consistent with Secret outranking God in `RarityConfig`'s own order, not just a joke) have distinct, mechanically real kits. Cards without `effects` (all Common-Epic, for now) fall back to the original generic role-based active — verified via direct `BattleEngine.Resolve` tests that this fallback path is byte-for-byte unchanged.
- `single_true_execute`, `true_damage_all` bypass both damage reduction and shield absorption (new `ignoreShield` param on `applyDamage`, new `opts.trueDamage`/`opts.forceCrit` on `dealDamage`) — verified a shielded target takes true damage straight to HP.
- `PlayCast` in `BattleUI.lua` now actually shows the real ability name in the battle log (it previously ignored `activeName` entirely); a new `maxhp_shred` event/`PlayMaxHpShred` handler gives player-visible feedback for the new permanent-Max-HP-reduction mechanic.
- **Deferred, not blocking:** "add 1-2 new passive categories per role" and "new synergy mechanics that consume/apply marks directly" — these widen the combination space but aren't required for the phase's core goal; natural to bundle with Phase 9's Common-Epic uniqueness backfill instead of doing them twice.
- No UI changes were needed for `TeamBuilderUI`/`InventoryUI` — both already read only `active.name`/`active.desc` for display, so the new `effects` field is transparent to them (confirmed via code read, not assumed).

**Definition of done:** every Legendary+ card has a distinct active ability (✅, verified via direct engine tests exercising every op); both flavor-text mismatches are gone (done in Phase 0); the synergy panel accurately describes engine behavior (done in Phase 0).

### Phase 4 — Retention Loops & Live-Ops Infrastructure ✅ Core shipped 2026-07-13
**Goal:** turn a solid core loop into a reason to come back daily.

> **Leaderboard publish blocker (same category as Phase 1's monetization note):** `DataStoreService:GetOrderedDataStore` throws "You must publish this place to the web" in an unpublished Studio session — unlike plain `GetDataStore`, which works fine unpublished (confirmed: gems/packs/etc. have persisted correctly all session). `LeaderboardService.lua` already wraps every call in `pcall` and degrades gracefully (empty top-N, `nil` own-score) rather than erroring — verified in Studio: `GetLeaderboard` returns cleanly with no data, no console errors, even though the underlying write/read both fail. Once published, this works with no code changes.

- `QuestConfig.lua` + `QuestService.lua`: daily (3 of 6 pool) and weekly (3 of 4 pool) quests tracked via `QuestService:RecordProgress(userId, eventType, amount)`, called from `PackService` (pack opens), `DungeonService` (battle wins, node clears, boss kills), and `TowerService` (battle wins, floor clears). A 7-day login-streak calendar with escalating Gem/pack rewards. All state lives on `InventoryService`'s per-player blob (`GetQuestData`) rather than a separate injected cache like Pity/Banner — avoids a circular require, since `QuestService` needs to grant rewards through `InventoryService`. Day/week bucketing uses integer day-counts (`os.time() // 86400`), not date-string parsing.
- Battle Pass's real XP feed: `InventoryService:AddBattlePassXp` — every tracked quest event grants XP (`QuestConfig.BattlePassXp`), tier computed from `xp / xpPerTier` capped at `maxTier`. `ShopStoreUI`'s Battle Pass tab and the new `QuestUI` both show live tier/XP.
- `LeaderboardService.lua` (`OrderedDataStore`-backed): Tower best floor / Dungeon deepest row, updated from `InventoryService:SetBestFloor`/`RecordDungeonResult` at the exact point those are already a new personal best (no extra read-before-write needed) — this is also the direct dependency Phase 5/6 will reuse for a PvP rating board.
- `SeasonConfig.lua`: a minimal season-identity marker (not a live scheduler) — automated rotation cadence is explicitly Phase 9 work.
- New `QuestUI.lua` (daily/weekly/streak tabs + Battle Pass tier) and `LeaderboardUI.lua` (per-board top-20 + your score), both reachable from two new side-menu buttons.
- **Deferred, not blocking:** opt-in Roblox experience notifications — lower priority, and the "duel challenge" trigger depends on Phase 6, which doesn't exist yet.

Verified end-to-end via real client-invoked remotes: quest rolling, targeted progress tracking (only matching quest types increment), reward granting on claim (exact Gem math confirmed), double-claim rejection, login-streak day-1 reward, and Battle Pass XP accrual all work correctly against live game state.

**Definition of done:** a returning player always has a visible reason to log in today (✅ — daily/weekly quests + streak); a working leaderboard UI is surfaced from the side menu (✅ — code-complete and gracefully degrading; real data requires publishing).

### Phase 5 — Async PvP & Leaderboards
**Goal:** ship PvP at the lowest possible engineering risk by reusing the existing deterministic combat engine unchanged.

- New `src/server/GachaSystem/Services/PvPService.lua`: snapshots a player's current team into a "defense squad" record (rating-keyed store). Attackers fetch an opponent snapshot and the server calls the existing `BattleEngine.Resolve(attackerUnits, defenderSnapshotUnits, seed)` exactly as Dungeon/Tower already do — no new combat code required.
- Rating system (Elo or trophy-count) feeding `LeaderboardService`. Win rewards diminish per-day to prevent farming.
- New `src/client/GachaSystem/UI/ArenaUI.lua`: opponent search/list, and battle replay reusing the existing `BattleController`/`BattleUI` playback path unchanged.

**Definition of done:** players can attack snapshots of real players' teams, see rating/leaderboard position, and earn PvP rewards, entirely on existing combat code.

### Phase 6 — Live Real-Time PvP Duels
**Goal:** add live matchmaking/presence on top of the validated async system, without needing real-time combat netcode (the engine is already non-interactive/deterministic).

- New `src/server/GachaSystem/Services/DuelMatchmakingService.lua`: rating-band queue pairing (reuses Phase 5's rating). Both players queue → server resolves once with a synced seed → **both clients simultaneously play back the identical event log** via the existing `BattleController` — matchmaking/presence is the only new real-time surface, not combat itself.
- Physical duel arenas in the Phase 2 hub's reserved zone, plus remote queueing from anywhere.
- Spectator mode: a third player can watch a live duel's event-log playback via a read-only `BattleController` instance.
- Duel rewards/cosmetic flex (victory emotes, arena banners) tie into Phase 1/2's cosmetic monetization.

**Definition of done:** two online players can queue, get matched, and watch the same fight resolve together in the hub arena.

### Phase 7 — Social Suite: Guilds, Trading, Friends
**Goal:** the deepest social layer — deliberately last among social features since trading touches the mature gacha economy and guild halls reuse the hub.

- New `src/server/GachaSystem/Services/GuildService.lua` + `GuildConfig.lua`: create/join/leave, guild chat, a shared guild-level progress bar unlocking guild-wide buffs, and a physical guild hall in the Phase 2 hub's reserved space.
- New `src/server/GachaSystem/Services/TradeService.lua`: two-player trade window with explicit anti-abuse guardrails — cooldowns, a trade-value/rarity or level floor (mitigates RMT/dupe-account abuse), full server-side validation before an atomic swap, and a trade-log audit trail for moderation.
- Friends bonuses: capped daily "gift a pack to a friend," friends-only leaderboard filter.
- Guild Wars: guild-vs-guild aggregate duel results (built on Phase 6) feeding a season ranking.

**Definition of done:** players can form/join a guild with a physical hall, trade cards with abuse safeguards, and gift packs to friends.

### Phase 8 — Endgame & Meta-Progression
**Goal:** give top-end players a long-term sink once collection/social/monetization surface area is rich enough to sustain one.

- New `src/server/GachaSystem/Services/PrestigeService.lua`: an Endless Tower "rebirth" — reset floor progress past a high watermark for a permanent account-wide multiplier or prestige currency, turning the Tower's existing exponential-past-25 eventual-loss design into a positive endgame payoff instead of a dead end.
- Account level system (separate from per-card level) from cumulative Dungeon/Tower/PvP XP, unlocking titles, hub cosmetic slots, and small roster-wide perks.
- Permanent account-persistent "Artifact" tier (today's Dungeon items are fully run-scoped) obtainable from endgame content and equipped account-wide — the first permanent power progression beyond card collection itself.
- God/Secret-tier chase content expansion targeted at this segment, coordinated with Phase 9.

**Definition of done:** maxed-out players have a visible, regularly-updated long-term goal instead of a content ceiling.

### Phase 9 — Content Scaling & Live Content Pipeline
**Goal:** volume and cadence, not new systems — everything that makes new content matter (identity, monetization, banners, guilds, PvP) already exists by now.

- Roster expansion from 50 → 200+ cards over a defined cadence, backfilling per-card unique actives rarity-tier by rarity-tier.
- Regular banner rotation cadence (weekly/bi-weekly) via Phase 1's system; seasonal event content via `SeasonConfig.lua`.
- Studio-only balancing/admin tooling (extends the existing `DebugService.lua` pattern) to preview rarity distributions, synergy math, and PvP rating curves without redeploying.
- A documented content-authoring template (stat bands per rarity, synergy-fit rules, active-ability budget) so new cards stay balanced without re-deriving the system each time.

**Definition of done:** new cards/events ship on a predictable schedule using documented templates and in-Studio tools.

### Phase 10 — Polish, Performance, Compliance & Launch Readiness
**Goal:** the "make it real" pass — turn a feature-complete build into a shippable, stable, compliant live game. This is the ~90%-finished mark.

- Mobile/touch UX pass across all UI (existing + hub/store/arena/guild UIs) — touch targets, safe-area insets, low-end-device performance, since Roblox's audience is majority mobile.
- Performance profiling of the populated hub under realistic concurrency: instance/streaming budget, script memory, and DataStore request budgeting across all the persistence calls added by Phases 1/4/5/7 (Roblox enforces strict per-key/per-minute DataStore limits).
- Chat/moderation pass for the new social surfaces (guild chat, trade offers, duel challenges) per Roblox Trust & Safety requirements.
- Full monetization/compliance review: odds-disclosure UI meets current Roblox policy, age-appropriate design checks, gamepass/dev-product pricing sanity pass.
- Analytics event pipeline (pull rates, retention funnels, PvP win rates, purchase conversion) to inform post-launch live-ops.
- Marketing readiness: icon/thumbnail/trailer capture showcasing the populated hub and combat presentation.
- Full regression bug-bash across every phase's systems before a wide launch/marketing push.

**Definition of done:** acceptable mobile performance under real concurrent load, a passed moderation/compliance review, live analytics instrumentation, and ready marketing assets. The remaining ~10% is post-launch live-ops iteration using the Phase 9 pipeline.
