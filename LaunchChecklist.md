# Launch Checklist

Companion to `GameDesign.md`'s Phase 10. Phase 10's engineering-actionable work (mobile/touch UX pass, DataStore request-budget audit, chat/moderation, an analytics pipeline, a monetization/compliance review) is done and described there. This document is the remainder: items that genuinely cannot be completed by writing code in an unpublished Studio session — they need the game to be published, real hardware, real concurrent players, or a business/creative decision only the project owner can make.

## Requires publishing the place

- **Configure real Developer Product / Game Pass IDs.** Every id in `MonetizationConfig.lua` (`GemProducts`, `VIP.passId`, `BattlePass.productId`) is a placeholder `0`. Create each one in the Creator Dashboard after publishing, then paste the real numeric ids in. `MonetizationService` already refuses to prompt a purchase for an unconfigured (`0`) id, so nothing breaks in the meantime.
- **Verify `OrderedDataStore`-backed leaderboards populate.** `LeaderboardService` (Tower/Dungeon/PvP boards) and Guild Wars ranking are code-complete but `GetOrderedDataStore`/`GetDataStore` both hard-require a published place — this can't be exercised pre-publish (a known, already-documented limitation from Phase 4/5).
- **Confirm `AnalyticsService` events land in the real dashboard.** The new `AnalyticsService.lua` (Phase 10) wraps Roblox's real analytics API defensively (every call is `pcall`-wrapped), but actual dashboard confirmation — and re-verifying the exact `LogEconomyEvent`/`LogCustomEvent` signatures against current Roblox docs — can only happen once real events are flowing from a published, played game.
- **Re-run the odds-disclosure / age-appropriate-design review against Roblox's current published policy.** The in-experience odds panel and purchase flow were reviewed against this project's understanding of the requirements (see `GameDesign.md`'s Phase 10 notes), but Roblox's actual policy team/automated review only runs against a published place.

## Requires real hardware / real players

- **Mobile device testing on real phones/tablets.** Phase 10's touch-target and safe-area fixes were done by code review (bumping under-sized buttons, adding an edge margin) — they were not verified on an actual notched/rounded-corner device, since Studio's emulated mobile view can't fully substitute for real hardware.
- **Concurrent-load / performance profiling under real player counts.** The DataStore-budget fixes in Phase 10 (throttled guild-index writes, trade-offer cleanup sweep) were reasoned about from Roblox's documented budget formulas, not measured against an actual populated server. Watch DataStore request-budget dashboards and server script memory once real traffic exists.
- **Full regression bug-bash with multiple real accounts.** Every phase of this project has been tested solo in Studio (documented testing-methodology limitation: `DataStoreService` is blocked from `execute_luau`, and cross-player features like trading/gifting/live duels/guild chat can only be partially exercised without a second real account). A proper multi-account bug-bash is a pre-launch must.

## Business / creative decisions

- **Marketing assets**: game icon, thumbnail, and a trailer showcasing the hub world and combat presentation. This needs actual creative production (capture, editing) — not something to generate as a code task. The hub (Phase 2) and combat presentation (pre-existing) are already in a showable state whenever this is prioritized.
- **Pricing sanity pass**: Gem package/VIP/Battle Pass Robux prices in `MonetizationConfig.lua` were set as reasonable placeholders during Phase 1; a final pricing decision is a business call, not an engineering one.
- **Moderation policy**: `ModerationService.lua` (Phase 10) logs abuse reports for guild chat to a capped DataStore list, but nothing currently reads that list — decide who reviews it and how (a Studio admin tool, a scheduled export, a third-party moderation dashboard) before launch.
