# Card Art Guidelines

Companion to `CardAuthoringGuide.md` (stats/mechanics) and `AnimeRosterPlan.md` (roster/theme) — this doc covers **AI-generated card art**. No card has real art yet; `CardReveal.lua` currently renders a placeholder "ART" frame (dark navy box, no image). Written to hand to a partner doing the actual generation.

**IP approach (decided):** direct anime likeness, paired with the existing parody names (Sukuna → "World Cutter", etc.) — the name carries the wink, the art carries the recognition. Chosen deliberately, accepting the moderation/IP risk other similar games on the platform also carry.

## 1. Character fidelity

- Draw the character as canonically recognizable — face, hair, signature outfit/prop, color scheme.
- Avoid reproducing exact copyrighted logos, studio watermarks, or panel-for-panel poses lifted from official art — generate original poses/compositions rather than tracing/upscaling existing official art.
- Keep content PG (no gore, no fanservice/NSFW) — Roblox's asset moderation is a separate, stricter gate than IP risk generally. A piece can clear "IP risk we've accepted" and still get bounced for content reasons.
- If a specific piece gets rejected/flagged after upload, don't resubmit the same likeness repeatedly — treat it as a candidate for an expy-style redesign instead. Documented fallback, not a default.

## 2. Rarity is visually legible — but the art itself stays rarity-neutral

`VFXConfig.lua`'s `RarityReveal` table already drives aura glow, particle bursts, rings, and orbit effects **at reveal time, as real-time engine overlays** on top of the art. `RarityConfig.lua` separately drives the card border/frame color per rarity. **Don't paint glow rings, sparkles, or colored energy auras into the image** — it would double up with the real-time VFX and lock the art to current VFX tuning.

Instead, escalate rarity through the character's own pose/expression energy:

| Rarity | Pose energy | Expression/framing |
|---|---|---|
| Common | Calm, standing/idle pose | Neutral |
| Uncommon | Slight action, weapon drawn or stance | Neutral–focused |
| Rare | Active stance, mid-motion | Focused |
| Epic | Dynamic action pose | Intense |
| Legendary | Full power-up moment (canon signature technique start) | Determined/intense |
| Mythic | Peak canon technique, mid-cast | Fierce |
| God | Iconic "ultimate move" canon moment | Overwhelming presence |
| Secret | Whatever's most over-the-top/joke-appropriate | Playful/absurd (matches its wildcard/joke identity) |

Creative guide, not a hard spec — higher rarity means a more dramatic *character moment*, while the image itself stays a clean render.

## 3. Composition & technical spec

Grounded in the actual placeholder frame in `CardReveal.lua`:

- **Crop area:** ~1.1:1 aspect ratio (slightly wider than tall) — the art frame is `0.90` width × `232px` height inside a 280×460 card. Bust/upper-body framing reads better than full-body here.
- **Background:** transparent or flat/simple — a solid rarity-colored frame sits behind it (currently dark navy `RGB(26,26,44)` placeholder). Avoid busy illustrated backgrounds; they compete with the border color and VFX aura.
- **Resolution:** generate at 1024×1024 minimum and crop down — Roblox decal uploads compress, higher source resolution survives better.
- **Corners:** frame has a 12px rounded corner — keep face/signature prop away from the extreme edges so corner-cropping doesn't clip them.

## 4. Style consistency across the roster

- Pick one rendering style (line weight, shading, lighting direction) and hold it across all cards/all 5 anime pillars — cards need to read as one cohesive set.
- Keep lighting/color grading consistent card-to-card so the rarity border color (gray/green/blue/purple/orange/red/gold/cyan, per `RarityConfig.lua`) is what differentiates rarity at a glance, not inconsistent art mood.
- Build one anime pillar at a time (Jujutsu Kaisen first, per `AnimeRosterPlan.md` §7) so style drift gets caught early.

## 5. Workflow

1. **Prompt template:** `[character name/likeness], [canon signature outfit/prop], [rarity-tier pose from §2], bust/upper-body composition, transparent or simple background, [chosen consistent art style], high detail, 1024x1024`
2. **File naming:** match the card's `id` field from `CardDatabase.lua` (e.g. `card_044.png`).
3. **Review before upload:** check against §1's PG/no-watermark rule and §3's crop/background spec.
4. **Upload as a Roblox Decal/Image asset** — note the `rbxassetid://` with a short source/description comment (same convention `VFXConfig.Sounds` uses for audio), for an audit trail.
5. Jujutsu Kaisen's 10 cards first, review together, then continue anime-by-anime.
