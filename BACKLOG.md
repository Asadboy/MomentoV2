# 10shots — Backlog

Active, launch-blocking work only. Anything aspirational lives in `VISION.md`.

---

## Blocking App Store submission

- [ ] **Real privacy policy URL** — replace `https://yourmomento.app/privacy` placeholder in `Momento/Features/Auth/SignInView.swift`
- [ ] **Real terms of service URL** — replace `https://yourmomento.app/terms` placeholder in `SignInView.swift`
- [ ] **App icon** — final design
- [ ] **App Store screenshots** — capture set covering create, live event with shot counter, reveal, gallery
- [ ] **App Store listing copy** — name, subtitle, keywords, description, category
- [ ] **App review notes** — explain camera permission, photo storage, why 10 shots
- [ ] **Submit to App Store Connect**

## Pending external dependency

- [ ] **Buy `10shots.app` domain**
- [ ] **Host `apple-app-site-association`** at `https://10shots.app/.well-known/apple-app-site-association` (required for Universal Links to validate)
- [ ] **Wire `10shots.app/join/<code>`** — once domain is live, point invite QR + share message at it (currently a placeholder in `Momento/Components/InviteContentView.swift`)
- [x] **Universal Link / deep link** for `10shots.app/join/<code>` — entitlement (`applinks:10shots.app`), `onContinueUserActivity` handler in `MomentoApp.swift`, shared `JoinLinkParser`, and `initialCode` plumbing through `JoinEventSheet` are all in place. Will activate once the domain + AASA are live.

## Supabase / backend

- [ ] **Wipe Momento beta data before App Store launch** — five Momento beta cycles have left events/members/photos rows written against the old schema (premium fields, dropped columns, processing states). Plan: (1) download all photos from Storage and archive locally, (2) hard-delete `photos` + `event_members` + `events` rows for everything pre-launch, (3) delete corresponding Storage objects, (4) keep `auth.users` so betas can re-log-in without re-onboarding (or wipe — TBD), (5) tell betas to reinstall to clear local UserDefaults / cache / push tokens. Run as a one-off script behind explicit confirmation. Reasoning: avoids "is it the old data?" debugging tax at launch, makes betas validate the true Day-1 empty-state path, and stops old Momento mental model bleeding into the new 10shots framing.
- [ ] **Enable leaked-password protection** (Supabase dashboard → Auth → Password security toggle)
- [ ] **Hard-enforce `member_limit` server-side** — RLS cap was dropped in `20260511150000_drop_cross_table_cap_from_rls.sql` because Postgres flagged the cross-table subquery (events ↔ event_members) as recursive even with a SECURITY DEFINER helper. The Swift client still pre-checks the count and surfaces "event full"; that's fine for friends-and-family scale but bypassable. When paid tiers ship, add a BEFORE INSERT trigger on `event_members` that locks the count under `FOR UPDATE` and rejects over-cap inserts — this also closes the TOCTOU window two simultaneous joins could exploit.
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
- [ ] Internal rename `CreateMomentoFlow` → `CreateEventFlow` (deferred per CLAUDE.md — internal-only churn)

## OfflineSyncManager hardening (deferred — failed-upload banner already gives users feedback)

The user-trust gap the audit flagged — failed uploads sit silently in the queue with no UI signal — was closed by the `UploadFailureBanner` in the error-surfacing PR. These remaining items are correctness / robustness fixes that should ship before paid tiers but aren't launch-blockers for friends-and-family scale:

- [ ] **Pre-upload photo-limit check shouldn't bypass on failure.** If `getPhotoCount` throws during the pre-check (`OfflineSyncManager.swift:188-190`), the upload currently proceeds and gets rejected by RLS. Better: treat a failed check as "limit unknown" and either retry the check or surface to user.
- [ ] **Stale queue entries dropped silently at cold launch.** When `loadQueue()` finds a `QueuedPhoto` whose image file is missing (deleted by iCloud / device cleanup), it discards the entry with only a debug log (`OfflineSyncManager.swift:347-353`). Rare, but the user never knows a queued photo got lost. Decide: surface, or accept as silent on the grounds that the original was already saved to PhotoStorageManager's separate cache.
- [ ] **Retry rate limit.** `retryFailedUploads()` resets `retryCount` to 0 with no backoff; if a user mashes the banner's Retry button while Supabase is down they can hammer the server. Add a "minimum 30s between retries per photo" check or exponential backoff.
- [ ] **Auto-retry on network restore.** Currently retries only fire on user tap. NWPathMonitor-based auto-retry when connectivity comes back would be more forgiving for the common "took shots in spotty signal" case.

---

*Anything below the App Store submission line is also fair game pre-launch but won't block ship.*
