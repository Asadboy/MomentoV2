# Lobby Redesign + Theme Unification — Design Spec

**Date:** 2026-07-02
**Status:** Approved by Asad (brainstormed via visual companion; mockups in `.superpowers/brainstorm/49660-1783028118/content/`, gitignored — `fullscreen-lobby-v3.html` is the approved look, `-v4.html` shows the rejected warm-background variant)

## Summary

The active event stops being a card in a list and becomes a **full-screen lobby**. The whole app moves onto **one unified visual system**: black background, one amber accent, white text with cream dot fills, mono numerals. Two "alive" behaviours (final stretch, roll milestones) make the lobby feel like a live game rather than a status page.

## Decisions log (what was chosen and what was explicitly rejected)

| Decision | Choice | Rejected alternatives |
|---|---|---|
| Lobby structure | "The Roll, refined" — rows of avatar + 10 dots, evolved | Aperture-ring-first lobby; shot-race tracks |
| Screen usage | Full-screen lobby (Marquee layout: big left-aligned name) | Card-in-list (current); centred Scoreboard layout |
| Accent | **Film Amber** `#FFB450` / `#FF8C42` — one accent app-wide | Signal green, electric blue, pure mono |
| Reveal accent | Same amber (READY, glows) — no second colour | Keeping cyan for reveal |
| Background | **Near-black `#0A0908`** + faint amber top vignette + film grain | Warmth-scales-with-progress dusk gradient (v4) — Asad: "i like the ui but black" |
| Alive layer | Aperture watermark ✅, final stretch ✅, milestones ✅ | Live activity ticker ❌ |

## 1. Visual language (new `AppTheme`)

### Colors
- `bg` — `#0A0908` (never pure `#000`; screens get a faint amber top vignette: radial gradient, `rgba(255,140,66,0.09)` at top centre fading by 55%)
- `accent` — `#FFB450`; `accentDeep` — `#FF8C42` (gradients run deep→light)
- Text scale (white, not warm-white — background stays black): `primary` 1.0, `secondary` 0.7, `tertiary` 0.45, `quaternary` 0.35, `muted` 0.25 opacity
- Dot fills: filled = radial cream gradient (`#FFFFFF` → `#E8E0D4`, top-light at 35%/30%); latest-shot = amber radial (`#FFD9A0` → `#FFB450`) + amber outer glow; empty = `rgba(255,255,255,0.03)` fill + inset hairline ring `rgba(255,255,255,0.22)`
- **Deleted:** `royalPurple`, `glowBlue`, `bgStart/bgEnd`, `cardFill` (purple-tinted), `momentoBackground()`, `momentoGlowOrb()`, serif `h2`, `shotGreen`, all cyan reveal colours, orange "awaiting" colour

### Typography
- Display (event name): system bold ~38–44pt, tracking ≈ −1.5, line height ~1.02, 2-line max
- Labels: 9–11pt, weight 700–800, letter-spacing 2–3 (e.g. `THE ROLL`, `LIVE`, `PAST EVENTS`)
- **Numerals** (counts, countdowns, "N LEFT"): `.monospaced` design — camera-hardware precision
- No boxes/borders for hierarchy — spacing, weight, opacity only. Separators are 1px gradients that fade to transparent at both ends.

### Buttons
- Primary → amber gradient pill (`#FFC25E`→`#FF9A3E` top-to-bottom), near-black text (`#160E05`), inner top highlight, soft amber outer shadow
- Ghost → circle/pill with **solid** 1px inset hairline `rgba(255,255,255,0.18)` (never dashed)

## 2. The lobby — new `EventLobbyView` (Features/Events/)

Full-screen layout for **live and upcoming** events, top to bottom:

1. **Top bar** — existing `HomeHeader` (wordmark `10SHOTS` tracked caps, QR + profile icons at 40% white)
2. **State line** — breathing amber dot + `LIVE` (tracked amber caps) + `— ENDS 3H 24M` in mono at 35% white. Upcoming: no dot, `UPCOMING — STARTS IN…`
3. **Event name** — the marquee: 38–44pt, left-aligned, tight
4. **THE ROLL** — label left, `21 / 40` mono right; 3px hairline track (`rgba(255,255,255,0.07)`), amber gradient fill, 7px glowing playhead dot at the fill edge. Total = `members.count × 10`, taken = sum of `shotsTaken`
5. **Roster** — vertically centred in remaining space. Row = 42pt avatar (gradient fill on initial fallback) + 10 dots right-aligned. Current user pinned first with a 3px **amber ring** around the avatar (offset by a bg-colour gap ring) — no YOU tag, no other distinction. `ViewThatFits` dot downsizing stays (15 → 13pt etc.). If the roster is taller than the available space (>~6 members), it scrolls within its region; layout must stay sane at 393pt and 375pt widths.
6. **CTA row** — full-width amber **`⬤ Shoot · 3 LEFT`** button (count = `10 − userPhotoCount`; disabled/relabelled `Roll complete` at 0; hidden for upcoming events) + 54pt ghost-circle `+` invite button. Shoot opens the existing `PhotoCaptureSheet` via the router; invite opens `InviteSheet`.
7. **Footer hint** — `PAST EVENTS ⌄` micro-caps at 25%, only when past events exist below
8. **Aperture watermark** — the brand's 10-dot ring, ~300pt, bleeding off the top-right corner behind content. Dots fill clockwise from top with group progress (`round(progress × 10)`): filled = `rgba(255,180,80,0.14)`, empty = hairline ring at 7% white. Pure decoration, `allowsHitTesting(false)`, `accessibilityHidden(true)`

**Home restructure (`ContentView`):** when ≥1 active (live/upcoming) event exists, the first "page" of the scroll is the lobby at full viewport height (`containerRelativeFrame(.vertical)` or GeometryReader equivalent); scrolling down reveals additional active events (rare; one-live-event rule) then `PastEventsSection`. Pull-to-refresh, error alert, and upload banners keep working — banners overlay the lobby top. `EmptyHomeView` and revealed/READY events keep compact cards, restyled to the new tokens (READY = amber, not cyan). `EventHeroView` is deleted once `EventLobbyView` lands.

**Motion:** LIVE dot breathes (existing pattern); new dot fills pop with the existing spring; playhead pulses subtly; when any *other* member's count increases between polls, a brief amber edge-flash. All animations must not fight the 1s `now` tick (scope animations to specific values, as `EventHeroView` does today).

## 3. The alive layer

### Final stretch (live events, <30 min remaining)
- Countdown swaps to per-second mono timer `00:24:37` (the 1s `now` tick already exists)
- Top vignette deepens (opacity 0.09 → ~0.18), LIVE dot pulse speeds up
- Pure client-side derivation from `endsAt − now`; no state stored

### Roll milestones (live events)
- Thresholds: half roll (`taken ≥ total/2`) and full roll (`taken == total`), `total = members × 10`
- On crossing (detected in `EventStore` when refreshed counts move from below to at-or-above a threshold): full-screen 1.5s amber wash + big type (`HALF WAY THROUGH THE ROLL` / `ROLL COMPLETE`) + success haptic
- Fire **at most once per event per threshold**, persisted like `RevealStateManager` (UserDefaults keyed on event id + threshold) so re-launches and re-polls don't replay it
- Guard: the first hydration of an event only records the baseline count and never fires — otherwise joining late (or relaunching) into an event already past half-roll would replay the celebration. Fires happen only when a later refresh crosses a threshold the baseline was below and that hasn't fired before.

## 4. Theme sweep (all screens onto the system)

Colour/type/button swap only — no structural changes: `SignInView` + onboarding, `ProfileSetupView`, `CreateMomentoFlow` (all steps), `JoinEventSheet`, `EventPreviewModal`, `InviteSheet`/`InviteContentView`, `ProfileView`, `LikedGalleryView`, `FeedRevealView` (cyan → amber; reveal glow, READY pill, liked hearts stay red), `PhotoCaptureSheet`/`CameraView` chrome, `PastEventCard`, `EventCard` (legacy previews), banners. Purple gradient backgrounds → `bg` + vignette. Green LIVE → amber. Kill every use of the deleted tokens; the build fails loudly if one is missed (delete the tokens, fix the compile errors).

## 5. Delivery plan — three PRs, in order

1. **`theme-foundation`** — new `AppTheme` tokens + button styles, delete legacy tokens, sweep all screens' colours/type. Largest diff, zero behaviour change.
2. **`fullscreen-lobby`** — `EventLobbyView`, ContentView restructure, watermark, Shoot CTA wiring, delete `EventHeroView`. On-device checkpoint on the 15 Pro before merge.
3. **`alive-layer`** — final stretch + milestones (+ their EventStore detection with unit tests in `EventStoreTests` via `MockMomentoAPI`).

Each PR: register any new files in `project.pbxproj`, build-verify via `xcodebuild build-for-testing`, CI for tests, worktree-per-PR.

## Non-goals / explicitly out of scope

- Live activity ticker (rejected)
- Warmth-scales-with-progress background (rejected — background stays black)
- Reveal flow structural redesign, camera redesign (colour sweep only)
- Any change to polling cadence, data layer, or backend
- Names in roster rows (stay avatar-only), host distinction, member reordering

## Copy rules reminder

All new user-facing strings use **event / shot / 10shots** (e.g. `Shoot`, `N LEFT`, `ROLL COMPLETE`). No "photo", no "momento".
