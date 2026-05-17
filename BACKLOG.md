# 10shots — Backlog

Active, launch-blocking work only. Anything aspirational lives in `VISION.md`.

---

## Blocking App Store submission

- [x] **Onboarding redesign + username decision** — shipped in PR #27 (`feat: replace usernames with display name + optional avatar`). `UsernameSelectionView` deleted, combined display-name + optional-photo onboarding screen in place, avatar hash now keyed off `userId.uuidString`. The `username` column is kept nullable on `profiles` and `photos` for legacy rows only (migration `20260512150000_drop_username_requirement.sql`).
- [x] **In-app account deletion (Apple Guideline 5.1.1(v))** — `Delete Account` button in `ProfileView` below Sign Out, with a confirmation dialog. Implementation: client batch-deletes the user's Supabase Storage objects (their own photos + photos in events they created), then calls the `delete_my_account()` SECURITY DEFINER RPC which atomically removes `photo_likes`, the user's own `photos`, `events` they created (cascades to event_members + photos in those events), remaining `event_members`, `profiles`, and finally `auth.users`. Migration: `20260511180000_delete_my_account_rpc.sql`.
- [x] **Create Sentry project + paste DSN into `Secrets.xcconfig`** — Sentry project `10shots/apple-ios` (region `de.sentry.io`) created, real DSN in `Secrets.xcconfig` (gitignored, `https:/$()/` xcconfig escaping), wired through `Info.plist` → `SentryConfiguration` → `CrashReporter.start()`. **Verified end-to-end on device 2026-05-17** via a temporary launch-arg-gated test event (issue `APPLE-IOS-1` received with user attribution; temp code reverted, never merged).
- [x] **Real privacy policy URL** — `SignInView.swift` now links `https://10shots.app/privacy`. Live page verified (substantive ~1.5k-word policy: Apple/Google sign-in, PostHog, Sentry, account deletion, EU infra).
- [x] **Real terms of service URL** — `SignInView.swift` now links `https://10shots.app/terms`. Live page verified (~950 words). Section 11 governing law set to **England and Wales** (live, verified 2026-05-17). No outstanding site-side edits.
- [x] **App icon** — aperture mark (10 white dots in a ring on solid black), 1024×1024 RGB, no alpha. Shipped in PR #50; eyeballed on device.
- [x] **App Store screenshots** — final 5-screenshot set (Cover, Lobby, Camera, Reveal, Create) in `Docs/launch/screenshots/`, all **1320×2868, RGB, no alpha** (Apple 6.9″-valid). Real app UI with real content; designed externally, source masters in `~/Pictures/10ShotsScreenshots` (3960×8604), processed here = downscale to 1320×2868 + flatten alpha onto black. Copy documented in `Docs/launch/SCREENSHOT_COPY.md`. The `app-store-screenshots` skill + `screenshots-generator/` (gitignored) remain for future regen if needed.
- [ ] **App Store listing copy** — name, subtitle, keywords, description, category. **Draft ready at `Docs/launch/APP_STORE_COPY.md` — review + edit before pasting into App Store Connect.**
- [ ] **App review notes** — explain camera permission, photo storage, why 10 shots. **Draft ready at `Docs/launch/APP_REVIEW_NOTES.md`.**
- [ ] **Submit to App Store Connect**

## Pending external dependency

- [x] **Buy `10shots.app` domain** — registered on Vercel (2026-05-17). Matches the codebase domain exactly; no app-side rename needed.
- [x] **Host `apple-app-site-association`** — authored + deployed in the standalone `10shots-website` repo; live and serving `200 application/json` at `https://www.10shots.app/.well-known/apple-app-site-association` (App ID `8X5TV69524.com.asad.Momento`, paths `/join/*`). Residual (NOT an App Store blocker): the apex `10shots.app` currently 307-redirects to `www`; a one-time Vercel dashboard flip (make apex primary) is needed for Apple to validate at the apex for Universal Links.
- [x] **Activate `10shots.app/join/<code>`** — `InviteContentView.swift:30` emits `https://10shots.app/join/<code>`; the site's `/join/<code>` fallback page is live and returns 200. Full in-app interception activates once the apex-primary Vercel flip above lands; no app-side change needed.
- [x] **Universal Link / deep link** for `10shots.app/join/<code>` — entitlement (`applinks:10shots.app`), `onContinueUserActivity` handler in `MomentoApp.swift`, shared `JoinLinkParser`, and `initialCode` plumbing through `JoinEventSheet` are all in place. Will activate once the domain + AASA are live.

## Supabase / backend

- [x] **Wipe Momento beta data before App Store launch** — old beta `events` + `event_members` + `photos` rows have been soft-deleted (`is_deleted = true`) so they no longer appear in-app, which closes the launch-readiness gate. Hard-deleting Storage objects + archiving the photos is parked: Asad will download the beta photos locally first (some are useful assets), then prune Storage at his own pace. No launch dependency on this anymore.
- [ ] **Enable leaked-password protection** (Supabase dashboard → Auth → Password security toggle)
- [x] **Hard-enforce `member_limit` server-side** — the BEFORE INSERT trigger on `event_members` (per-event advisory lock + `RAISE EXCEPTION` SQLSTATE `P0011`) already shipped and is live in prod (migration `enforce_member_limit_per_event`, applied 2026-05-13). **No member cap at launch (decided 2026-05-17):** `member_limit = 0` is now the "unlimited" sentinel — column default flipped to 0, existing rows backfilled, and the trigger short-circuits (`RETURN NEW`) when `cap <= 0`. Migration: `20260517120000_member_limit_unlimited_at_launch.sql`. The enforcement path is intact and re-arms automatically the moment a positive `member_limit` is written — that's monetisation-tier work, not a launch task.
- [x] **Wire `member_limit` in app** — default 10, NOT NULL, RLS-enforced cap on join; client surfaces "This event is full" error. Future monetisation tiers will write a different value per event.
- [x] **Audit unused indexes** — dropped `idx_photos_pending` (genuinely dead; nothing queries by `upload_status = 'pending'`). Kept the 5 `events` indexes: they're flagged "unused" only because the table has ~7 rows, but each covers a real query path that will activate as the table grows.

## On-device verification (developer-side QA)

- [ ] All event state transitions on device (upcoming → live → revealed)
- [ ] Create flow end-to-end
- [ ] Join flow via QR and via 6-char code
- [ ] Multi-device dot updates within 10s polling window
- [ ] Two users like the same shot → event total shows 2
- [ ] Battery / network impact of 10s polling during a long live event
- [ ] All-10-shots-used → camera locks correctly
- [ ] Offline shot capture syncs on reconnect

## Nice to have (not blocking)

- [x] Drop polling to 30s for non-live events (10s when something is live, 30s otherwise)
- [x] **Local notifications for reveal-ready** — `NotificationManager` schedules a "your 10shots are ready" notification at `event.releaseAt` whenever an event is created or joined. Tap deep-links into the reveal flow. Permission requested in context on first event create/join.
- [ ] Internal rename `CreateMomentoFlow` → `CreateEventFlow` (deferred per CLAUDE.md — internal-only churn)
- [ ] **Push notifications (v1.1).** Member-joined / new-shot-taken / liked-your-shot notifications would need APNs setup, device token registration, and a server-side trigger (Supabase Edge Function or external). Worth doing once user retention data shows reveal-ready alone isn't enough engagement.

## OfflineSyncManager hardening

The user-trust gap the audit flagged — failed uploads sit silently in the queue with no UI signal — was closed by the `UploadFailureBanner` in PR #17. Follow-up items:

- [x] **Retry rate limit.** `retryFailedUploads()` now refuses to fire more often than every 15 seconds, so banner-mashing can't hammer the server while Supabase is down.
- [x] **Auto-retry on network restore.** `NWPathMonitor` watches connectivity; on each transition from unavailable → available, the queue auto-processes. Combined with the cooldown, even a flaky tunnel commute recovers gracefully.
- [x] **Pre-upload photo-limit check on failure.** Superseded by `20260512160000_enforce_photo_limit_per_user.sql`, which enforces the 10-shot cap server-side via a BEFORE INSERT trigger with `pg_advisory_xact_lock` and raises SQLSTATE `P0010` on overflow. The client pre-check in `OfflineSyncManager.swift:208-230` is now best-effort; if it can't verify the count the server rejects authoritatively. No client change required.
- [x] **Stale queue entries dropped silently at cold launch.** Closed in PR #49 (`feat: surface stale-queue entries at cold launch`). `loadQueue` now counts dropped entries into `@Published staleEntriesAtLaunch`, surfaced once at cold launch via the dismissible `StaleQueueBanner` and reported through `AnalyticsManager.trackError(kind: "stale_queue_entries_dropped")`.

## Test coverage (engineering-side, complete)

Recorded for context — the test suite covers the launch-critical paths:

- [x] **`EventStoreTests`** (20 cases) — load/refresh/filter/mutation surface
- [x] **`EventStoreTimingTests`** (6 cases) — 2s join glow + 3s post-upload reconciliation via scheduler injection (PR #25)
- [x] **`EventTests`** (11 cases) — state machine + isRevealReady boundaries
- [x] **`JoinLinkParserTests`** (16 cases) — Universal Link / momento:// scheme / raw code parsing
- [x] **`HomeRouterTests`** (12 cases) — tap routing + intent helpers + dismissals
- [x] **CI on every PR** via `.github/workflows/tests.yml` against macos-15

Not yet covered (deliberately deferred — no launch-blocker value):
- Snapshot tests on EventHeroView (would need `swift-snapshot-testing` SPM dep; brittle on iOS version bumps)
- View-layer integration tests
- OfflineSyncManager unit tests (would need FileManager + storage protocols carved out — bigger refactor)

---

*Anything below the App Store submission line is also fair game pre-launch but won't block ship.*
