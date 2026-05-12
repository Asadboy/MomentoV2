# 10shots — State of the Code

**Date:** 2026-05-12
**Reviewer:** Comprehensive multi-agent review (six parallel slices: Supabase backend, camera+reveal, auth+onboarding, events+lobby, services+offline sync, tests+tooling)
**Codebase commit:** working tree at `/Users/asad/MomentoV2`
**Scope:** every Swift file (12,495 LoC, 67 files), every migration (19 files), every Edge Function, every test, every helper script, fastlane config, project settings, Info.plist, entitlements, privacy manifest, App Store launch docs.

---

## 1. Executive Summary

10shots is in **a substantially better state than the BACKLOG suggests** for the launch-blocking items it tracks — the architecture refactor (ContentView split, `HydratedEvent`, `MomentoAPI` protocol, `EventStore`, `HomeRouter`) is clean and testable, the state machine is sound, RLS posture is mostly correct, and offline sync hardening is largely done.

But the review surfaced **a class of issues BACKLOG.md does not track** that would either get the app rejected or produce real user-visible failures on launch day. The most pressing four are:

1. **A GitHub Personal Access Token is committed in `fastlane/Matchfile:1`** with access to the signing-certs repo. **Rotate immediately, then rewrite git history.** Treat as a security incident.
2. **Google Sign-In silently does not create a profile row.** Only the unused `signInWithIdToken` variant calls `createProfileIfNeeded`. The active web-flow path leaves the user with auth-but-no-profile and they bounce between screens. This is the primary OAuth provider — likely broken for most users.
3. **The local `Supabase/migrations/` folder is out of sync with the live DB.** DTOs reference tables (`photo_likes`) and columns (`events.is_deleted`, `events.member_limit`, `profiles.device_token`, `photos.is_flagged`, `photos.username`) that have no `CREATE/ALTER` migration locally. A `supabase db reset` would produce a schema the app cannot speak to. Run `supabase db pull` and commit before launch.
4. **The 10-shot lock can be bypassed.** `photosRemaining` decrements 0.42 s after capture; a user mashing the shutter takes 11–13 shots before the UI locks. This breaks the core product promise. Decrement synchronously on tap.

Below those, the review found ~30 HIGH-severity issues across security, privacy, accessibility, and lifecycle correctness, and ~60 MEDIUM/LOW items.

**Overall verdict:** the product is on the cusp of ready. With ~2–3 days of focused fixes on the BLOCKERs and the top HIGHs, the app is shippable to TestFlight broad-beta. The Apple App Store review will likely be passed once account-deletion (done), privacy/terms URLs (placeholder), app icon (placeholder), and the entitlements cleanup are addressed — none of which are technically difficult.

---

## 2. State of the codebase (architecture)

### What's good

- **Layered architecture is clean.** ContentView is now ~200 lines of composition. `EventStore` owns data, `HomeRouter` owns presentation. `MomentoAPI` protocol abstracts the backend cleanly enough that `MockMomentoAPI` covers EventStore unit tests at 65 cases.
- **Event state machine is tight.** Three states (`upcoming` / `live` / `revealed`), derived purely from time, comprehensively tested at boundaries.
- **`HydratedEvent` collapsed seven parallel dicts into one struct.** Atomic updates, type safety. Big win.
- **Polling cadence (10 s live / 30 s otherwise)** is reasonable; will need a hydrated-RPC consolidation when scale grows but is fine for launch.
- **`OfflineSyncManager` queue is robust:** NWPathMonitor auto-retry, 15 s retry cooldown, file-missing recovery on cold launch, `.uploading → .pending` reset on relaunch, photo-limit pre-check.
- **RLS posture is defensible.** The events ↔ event_members deadlock is genuinely resolved. SECURITY DEFINER functions all set `search_path`. No table missing RLS.
- **Test coverage of the launch-critical paths is real:** state machine (11), EventStore (20), timing (6), JoinLinkParser (16), HomeRouter (12) — and CI runs them on every PR.
- **Privacy manifest, App Tracking, and Apple-side compliance posture** are largely in place. No tracking domains, no IDFA, no microphone, no location.

### What's structurally weak

- **Two source-of-truth divergences.** (a) Local migrations vs. live DB schema. (b) `Info.plist` vs. `INFOPLIST_KEY_*` in `project.pbxproj` (build-setting values silently override file values; the camera usage description loses).
- **Cross-cutting concerns are leaky.** Sign-out clears _some_ state (`OfflineSyncManager.queue`, `RevealStateManager`) but leaves photo files, image cache, scheduled notifications, PostHog identity, and `stampJoin` UserDefaults keys intact. Multi-account-on-one-device is broken for privacy.
- **Several `@Published` mutations cross actors without isolation** in `OfflineSyncManager` and `AnalyticsManager`. Latent races, will become hard errors under Swift 6 strict concurrency.
- **Persistence directories are inconsistent.** `PhotoStorageManager` → `.cachesDirectory` (evictable). `OfflineSyncManager` → `.documentsDirectory` (backed up to iCloud unless excluded). Pick one per data class.
- **Time / countdown / "X ago" formatting is duplicated across 4 files** with subtly different outputs. `TimeFormatter` exists but isn't the single source of truth.
- **The legacy `EventCard` and `EventsScreenPreview`** are still compiled into the binary (only `EventsScreenPreview` is `#if DEBUG`-gated). Not a bug, just dead weight worth removing post-launch.

---

## 3. Launch blockers (consolidated)

These must be addressed before App Store submission.

### Security incident
- **B1.** `fastlane/Matchfile:1` — embedded GitHub PAT `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` for the certificates repo. Rotate the token, switch to SSH or fine-grained deploy key, `git filter-repo` the history to scrub it.

### Apple submission blockers
- **B2.** Privacy policy + terms placeholder URLs at `SignInView.swift:100,108` (force-unwrapped to `yourmomento.app`). Replace with real URLs.
- **B3.** App icon `Assets.xcassets/AppIcon.appiconset/App Logo Canva.png` is a working draft. Ship the final 1024×1024.
- **B4.** Sentry DSN is still the placeholder `YOUR_SENTRY_DSN` in `Secrets.xcconfig`. Create the Sentry project, paste DSN. (CrashReporter no-ops gracefully without it, so production builds ship with zero crash visibility.)
- **B5.** App Store listing fillers: `[TBD]` support URL, marketing URL, contact email in `Docs/launch/APP_STORE_COPY.md`; `[your email here]` in `Docs/launch/APP_REVIEW_NOTES.md`. Submission will be rejected without them.
- **B6.** Beta data wipe (BACKLOG-tracked) — five betas have left rows under the old schema. Wipe before launch so Day-1 metrics are clean.

### Backend integrity
- **B7.** `Supabase/migrations/` is **not** the source of truth. Run `supabase db pull` to capture the live schema (CREATE tables for `photo_likes`, ALTER for `events.is_deleted`, `events.member_limit`, `profiles.device_token`, `photos.username`, `photos.is_flagged`, drop dead columns `is_premium`, `is_corporate`, `is_revealed`, `member_count`, `photo_count`, `max_photos_per_user`, etc.), commit as a squash migration. Without this, CI / fresh-machine / disaster-recovery rebuilds produce a schema the app cannot use.
- **B8.** `Supabase/functions/reveal-photos/index.ts` is dead and broken — it operates on the dropped `events.is_revealed` column, has a TypeScript-invalid line (`)image.png` at line 46), and is not called by any client code. Delete the function.

### Auth correctness
- **B9.** Google Sign-In path does not create a profile row. The active flow is `getOAuthSignInURL` → `ASWebAuthenticationSession` → `client.auth.session(from:)` → `checkSession` — none of which call `createProfileIfNeeded`. Only the dead-code `signInWithIdToken` variant does. Move the `createProfileIfNeeded` call into `handleOAuthCallback` (or `checkSession`) so it runs whenever a new user is created server-side. **First-party Google users land in a stuck state today.**

### Product promise
- **B10.** The 10-shot limit can be bypassed. `CameraView.swift:285` decrements `photosRemaining` 0.42 s after capture inside `onChange(of: cameraController.capturedImage)`. A fast tapper takes 11–13 shots before lock engages; the 11th–13th go into the upload queue and are silently rejected server-side (or accepted, depending on RLS — see B11). Fix: decrement synchronously on tap, gate the next capture on the new value, or use an `isCapturing` lock released only after the delegate fires. **Same race exists in `PhotoCaptureSheet.handlePhotoCaptured`.**
- **B11.** `PhotoCaptureSheet.fetchRemainingCount` (`PhotoCaptureSheet.swift:111,139`) falls back to a fresh full count of 10 when `getPhotoCount` fails (offline, RLS hiccup). A user on flaky network at an event can take 20 shots. Fix: show a "couldn't load — try again" error rather than fall back to a free 10.

### Accessibility (App Review surfaces this)
- **B12.** No VoiceOver labels anywhere in CameraView, RevealCardView, LikedGalleryView, EventHeroView, VerificationCodeInput. The camera shutter reads as "white circle"; the 10 dots per member read as 10 unlabeled circles.
- **B13.** No Dynamic Type support — fonts are hardcoded `.system(size: 30, weight: .bold)` throughout. `AppTheme` defines fixed point sizes only.

Apple may not reject outright, but a large-text user opening the app will see broken layout. With the iOS-only audience this is the kind of thing one reviewer will flag and another won't — fix it.

### Already done, verify
- **B14.** In-app account deletion — wired correctly per the auth review (`ProfileView` → `deleteAccount()` → Storage cleanup + `delete_my_account()` RPC). Verify on device that the partial-failure path of storage cleanup produces sane telemetry (currently silent).

---

## 4. High-severity findings by area

These don't block submission but will produce user-visible failures or known compliance gaps.

### 4.1 Auth & account state
- **H1.** `signOut` does not clear: `ImageCacheManager` (cross-account photo leak), scheduled notifications (wrong-user reveal alerts), PostHog identity (events attributed to prior user), `PhotoStorageManager` event directories (cross-account photo leak on disk), `AnalyticsManager.stampJoin` UserDefaults keys. Wire all of these into `SupabaseManager.signOut`.
- **H2.** `PostHog.identify` is **never called.** `AuthenticationRootView.identifyUserForAnalytics` is defined and never invoked. Every PostHog event since launch will be anonymous. Call from `checkUsernameStatus` post-success and from `submitUsername` post-success.
- **H3.** `SupabaseManager+Profile.needsUsernameSelection` uses regex `.*\\d{4}$` to detect auto-generated usernames. A user who picks `alex2024` is permanently re-routed to `UsernameSelectionView` on every launch. Add a `username_is_auto_generated` boolean to `profiles`, or check `username_set_at IS NULL`, instead of pattern-matching the username itself.
- **H4.** `RevealStateManager` keys on event id only, never per-user. Sign in as A → complete reveal → sign out → sign in as B → B sees the event already revealed. Per-user namespace: prefix the UserDefaults key with `currentUser.id`.
- **H5.** Returning users whose `profiles` row has been wiped (account deletion bug, schema migration) are permanently stuck. `checkSession` succeeds, `getUserProfile` throws, `appState = .needsOnboarding`, every subsequent profile-dependent query fails. Add a self-heal: when authenticated but `getUserProfile` returns empty, call `createProfileIfNeeded` from `AuthenticationRootView.checkAuthState`.
- **H6.** Apple Sign-In `.failure` displays `error.localizedDescription` for cancellation, surfacing "The user canceled the authorization attempt" as a sign-in error message. Detect `ASAuthorizationError.canceled` and suppress.
- **H7.** Apple `ASAuthorizationAppleIDCredential.fullName` is ignored. Apple delivers names only on first sign-in. For private-relay users (`*@privaterelay.appleid.com`), the auto-generated username from email becomes a random hex string. Capture `fullName` and use it for `display_name` if/when display name lands as a concept.

### 4.2 Backend / RLS / Storage
- **H8.** `handle_new_user()` writes `display_name = NEW.email` as a fallback. Combined with `profiles SELECT USING (true)`, **any signed-in user can enumerate every other user's email address.** Change the fallback to the generated username.
- **H9.** `profiles.device_token` (push token) is readable by all authenticated users due to the same `USING (true)` policy. Move device tokens to a separate `profile_devices` table with `user_id = auth.uid()` policy, or column-mask via a view.
- **H10.** Member limit cap is not enforced server-side (RLS recursion). BACKLOG documents this is accepted for launch. Add a `BEFORE INSERT` trigger on `event_members` with row-level locking before paid tiers ship.
- **H11.** Leaked-password protection is off (Supabase dashboard toggle). One-click fix.
- **H12.** Storage bucket `momento-photos` accepts any MIME up to 50 MiB. Lock down: `allowed_mime_types = ['image/jpeg', 'image/heic']`, lower size limit to ~15 MiB.
- **H13.** Storage `DELETE` policy gates on creator only; uploaders cannot delete their own storage objects. After `deletePhoto` (which allows uploader-or-creator at the DB layer), the storage object orphans. Mirror the DB policy.

### 4.3 Camera & capture
- **H14.** `AVCaptureSession` setup runs on the main thread (`CameraView.swift:487-524`). Move all session config + `startRunning/stopRunning` to a dedicated serial queue. Currently visible stutter on iPhone 12 and earlier on first "Take a shot."
- **H15.** No `AVCaptureSessionWasInterruptedNotification` / `RuntimeError` handling. After a phone call or control-center camera takeover, the preview goes black and the only recovery is dismissing the sheet.
- **H16.** No `UIApplication.willResignActiveNotification` handling — backgrounding the app with camera open keeps the session running (battery, the green privacy indicator).
- **H17.** Camera permission state machine: after grant, `setupSession()` runs but the session never starts because `startSession()` already ran when `hasPermission` was false. User sees a black viewfinder until next user action.
- **H18.** Filter (`BethanReynoldsFilter.apply`) is applied on the main thread inside `OfflineSyncManager.saveImageToLocal` (which is called from `MainActor` via `EventStore.handlePhotoCaptured`). ~80–250 ms per shot — drops a frame on the dot-flight animation. Move filter + resize off main.
- **H19.** `OfflineSyncManager.documentsDirectory` and `ImageCacheManager.init` both use `fatalError` for unrecoverable init. Crash on launch if the OS ever returns an unexpected empty array. Degrade to memory-only / disable upload queue instead.
- **H20.** `ImageCacheManager.cacheKey(for: url)` uses `Swift.hashValue`, which is **not stable across launches** (Swift's hash uses a per-launch random seed). Disk cache is effectively empty on every cold launch. Use SHA-256 of the URL or the storage-path portion.
- **H21.** `PhotoStorageManager` writes to `.cachesDirectory` while `OfflineSyncManager` writes to `.documentsDirectory`. Local thumbnails can be OS-evicted while the upload queue persists. Standardize on Documents for "still uploading" and Caches for "already uploaded thumbnails," set `isExcludedFromBackup = true` on the queue.
- **H22.** `FeedRevealView.dismiss` fires likes-save + mark-completed asynchronously, then dismisses. If the view tears down before the network call lands, likes are lost.
- **H23.** `LikedGalleryView.saveToPhotos` re-downloads via `URLSession.shared.data(from:)` bypassing the cache — extra signed-URL traffic on every save.
- **H24.** Reveal "Skip" button (`FeedRevealView:436`) jumps to `.complete` with no confirmation, `onDisappear` fires `markRevealCompleted`. User locks themselves out forever from a button press.

### 4.4 Offline sync & services
- **H25.** **`OfflineSyncManager` does not clear its queue on sign-out or account-delete.** User A queues photos offline, signs out, user B signs in on the same device, connectivity returns — photos upload **under user B's session**. RLS may save you, but at minimum you get a wave of telemetry noise. Hook `clearQueue()` into the sign-out path.
- **H26.** `OfflineSyncManager` is `ObservableObject` but not `@MainActor`. Reads of `@Published var queue` happen off-main from detached Tasks and NWPathMonitor callbacks; mutations happen on-main via `MainActor.run`. Racy under Swift 6 strict concurrency. Annotate `@MainActor` or convert to an `actor`.
- **H27.** Auto-retry path (`willEnterForeground`, `isAuthenticated`, NWPathMonitor) does not respect the 15-second cooldown that the manual-retry path uses. Opening and closing the app five times in a minute fires five upload attempts.
- **H28.** `NotificationManager.scheduleRevealReady` uses `Calendar.current.dateComponents` + `UNCalendarNotificationTrigger`. **This is wall-clock-time, not absolute-UTC-time.** A user who creates the event in London and is in Tokyo at `releaseAt` gets the notification 9 hours late. Switch to `UNTimeIntervalNotificationTrigger(timeInterval: releaseAt.timeIntervalSinceNow)`, or set the trigger's `timeZone` and use a GMT calendar.
- **H29.** `HapticsManager` instantiates a fresh `UIFeedbackGenerator` per call and never calls `.prepare()`. First haptic after instantiation has noticeable latency or is dropped. For the reveal-moment haptics this materially undermines the product feel. Hoist generators to static lets, `prepare()` ahead of gestures.
- **H30.** `AnalyticsManager.userId` is mutated from `identify` and read from `track` without isolation. Data race if those run from different actors. Annotate `@MainActor`.

### 4.5 Events / lobby / invite UX
- **H31.** `InviteContentView.inviteURL = "https://10shots.app/join/\(joinCode)"` — the domain is not live. QR codes embed a URL that resolves to "cannot find server" when scanned out-of-app. Universal Link entitlement (`applinks:10shots.app`) is registered but the AASA file is not hosted at `https://10shots.app/.well-known/apple-app-site-association`. Either ship the domain + AASA before launch or, as a temporary measure, embed `momento://join/<code>` in the QR and a plain "Code: ABC123" prominently in the share message.
- **H32.** `ShareSheet` (`InviteContentView:178-191`) does not set `popoverPresentationController.sourceView`. **Crashes on iPad** the first time the user shares — `UIActivityViewController` requires a popover anchor in regular-width contexts. Even though the product is iPhone-first, iPad runs the iPhone-compat build by default.
- **H33.** `JoinEventSheet` reads `UIPasteboard.general.string` on every appear (`JoinEventSheet.swift:493-529`). iOS 14+ shows a system "Pasted from <app>" banner on every clipboard read. Gate behind a "Paste code" button or use `UIPasteboard.detectPatterns(for:)` to silently check without revealing contents.
- **H34.** `HomeRouter.HomeSheet.join(code:)` returns the same `id` (`"join"`) regardless of code. SwiftUI considers the sheet identical and **silently drops a Universal Link arriving while the sheet is already open**. Include the code in the `id`.
- **H35.** `VerificationCodeInput` filters input to `isLetter || isNumber` but the join-code alphabet excludes `I/O/0/1`. A user typing what looks like an `O` (it might be `0` on the invite) passes the filter, fails lookup with a generic "no event found." Either alias-map `O→0, I→1, L→1` before lookup, or hint the alphabet explicitly.
- **H36.** QR scanner does not reset `scannedCode = nil` on network error. After a failed lookup, the same QR can't be re-scanned — the user must dismiss and retry.
- **H37.** `EventHeroView` roster lays out members as horizontal rows of avatar + 10 dots (~300pt of dots + avatar). On a 320pt-wide iPhone SE 1st gen, even 5 members overflow horizontally. For the 25-tier future limit this is impossible. Decide on a vertical layout for >10, or kill iPhone-SE-1st-gen support.
- **H38.** `EventHeroView.glowPulsing` only starts in `.onAppear` when `isRevealCTA == true`. If the event transitions to reveal-ready while the card is already visible, the glow never animates. Add `.onChange(of: isRevealCTA)`.

### 4.6 Privacy / compliance / config
- **H39.** Sentry `attachScreenshot = true` + `attachViewHierarchy = true`. A crash on the camera preview or reveal screen attaches actual user content (someone's face). Acceptable for pre-launch triage; for production, add a `beforeSend` hook to strip image data, or scope to dev builds only.
- **H40.** `Info.plist:22` vs. `project.pbxproj` `INFOPLIST_KEY_NSCameraUsageDescription` (line 889): two **different** strings. The build setting wins and still says "Momento needs camera access to scan QR codes and take photos at events." User-facing copy in the system permission prompt says the old brand. Fix in `project.pbxproj` to match the Info.plist version ("10shots needs camera access to capture shots at events").
- **H41.** `Momento/Momento.entitlements:9-12` retains `com.apple.developer.in-app-payments` for `merchant.com.asad.Momento` — leftover from the removed premium tier. If the merchant ID isn't registered with Apple Pay, the build may fail to provision; if registered, App Review will ask why an unused IAP entitlement exists. Remove.
- **H42.** `ITSAppUsesNonExemptEncryption` is not set in Info.plist. Every TestFlight upload prompts for export-compliance answers. Set to `false` (uses standard HTTPS only).
- **H43.** `Package.resolved` lists Supabase + transitives, but **PostHog and Sentry are missing.** Either the resolved file is stale, or those packages are resolved elsewhere. Re-resolve and commit. Privacy-manifest verification depends on the SDKs being correctly pinned.
- **H44.** App Store privacy manifest (`PrivacyInfo.xcprivacy`) likely needs `NSPrivacyAccessedAPICategorySystemBootTime` (Sentry uses `mach_absolute_time`) and possibly `FileTimestamp` (ImageCacheManager / PhotoStorageManager). Audit and add the required reason codes. Independently verify PostHog, Sentry, and Supabase ship their own `PrivacyInfo.xcprivacy` bundled in the SDK — Apple has been rejecting builds for this since May 2024.
- **H45.** GitHub branch protection on `main` is **not configured** (verifiable from the repo, but the workflow alone doesn't enforce merge blocking). With branch protection off, "tests must pass" is aspirational.
- **H46.** `.github/workflows/testflight.yml:26-41` inline-overwrites `Momento/Config/SupabaseConfig.swift` with a generated version that hardcodes the anon key in workflow YAML and omits `PostHogConfig` / `SentryConfig`. TestFlight builds ship with no PostHog and no Sentry. Rework to write a `Secrets.xcconfig` and let the existing Swift code consume it.
- **H47.** `Secrets.example.xcconfig` is missing despite being referenced by `SupabaseConfig.swift`'s `fatalError` message. New contributors / CI rebuilds hit cryptic errors. Create with placeholder values for all five keys.
- **H48.** `TARGETED_DEVICE_FAMILY = "1,2"` — iPad+iPhone. The product is iPhone-only by design (CLAUDE.md, VISION). Set to `"1"`. Avoids App Review asking why iPad UI is broken.

---

## 5. Medium & low findings by area

A condensed list. Each item is small enough to fix in <30 min; collectively they materially raise quality.

### 5.1 Auth / Profile
- M1. OAuth callback potentially handled twice (MomentoApp.onOpenURL + WebAuthSession callback). Verify on device.
- M2. Universal Link join code is dropped during unauth cold launch (no buffer between auth and home).
- M3. TOCTOU between `checkUsernameAvailability` and `updateUsername` (Profile.swift:94-104, 196-211). Verify DB has `UNIQUE(LOWER(username))` index on `profiles`.
- M4. `createProfile`'s random `1000…9999` username suffix collides at ~1% per signup at 1k users — no retry on unique-violation.
- M5. Account-deletion success has no `AnalyticsManager.track(.accountDeleted)` event. Funnel blind.
- M6. Account-deletion storage-cleanup partial failures are silent in telemetry.
- M7. Apple `currentNonce` is not invalidated after use — defensive only; rejected by Apple anyway.

### 5.2 Backend
- M8. `photo_likes SELECT` uses `auth.uid() IS NOT NULL` — overly permissive. Tighten to "is event member of the photo's event."
- M9. `delete_my_account()` runs in a single transaction but Storage delete happens client-side first; partial Storage failure orphans objects. Move to a Storage cleanup pass inside the RPC or post-RPC retry.
- M10. `event_members.invited_by` and `photos.user_id` have no `ON DELETE` action. Risk that `delete_my_account` errors when the user has invited others. Set to `SET NULL` or include in the RPC's pre-delete queries.
- M11. `photos.captured_by_username` (legacy) and `photos.username` (NOT NULL) coexist. Drop the legacy column.
- M12. Missing composite index `(event_id, user_id)` on `photos`. The per-event per-user count is the hot path; falls back to `idx_photos_event` + filter.
- M13. 30-day signed URLs (`expiresIn: 2592000`). Consider 24–72 hours unless gallery UX needs longer.
- M14. `handle_new_user` random username collision more likely than expected; use `gen_random_bytes(4)`.
- M15. `minimum_password_length = 6` (config.toml). Bump to 8.
- M16. `auth.email.enable_confirmations = false`. Acceptable for friends/family launch, intentional? Confirm.

### 5.3 Camera / reveal
- M17. `RevealCardView.loadImage` doesn't use the `cacheId:` overload — caches by signed-URL string which rotates every 30 days. Use `cacheId: photo.id`.
- M18. `GalleryDetailView` uses `AsyncImage` while `GalleryPhotoCell` uses the cache — inconsistent.
- M19. `FeedRevealView.uniqueContributorCount` recomputes on every body, dedupes by `photographerName == "Unknown"` collapsing all unknowns to one.
- M20. `FeedRevealView.progressHeader` uses `event.photoCount` (hydrated client-side) for the denominator instead of `viewModel.photos.count`. Race produces "3 / 8" while feed contains 10.
- M21. `FeedRevealView.completionSection` is dead code; `completionCard` duplicates `completeScreen` — extract or delete.
- M22. `PHPhotoLibrary.requestAuthorization` is called every time the user saves to Photos. Cache the status and route denied users to Settings.
- M23. `PhotoStorageManager` writes a high-quality JPEG (0.9) locally that `OfflineSyncManager` re-encodes at 0.5 in Documents — two copies, different qualities, different directories.
- M24. `ImageCacheManager.setObject` is called without `cost:`, so `totalCostLimit = 30MB` is meaningless. Pass `image.size.width * height * 4`.
- M25. `ImageCacheManager.enforceDiskLimit` runs on every save — O(N) directory scan per cache write.
- M26. `BethanReynoldsFilter` is applied only on upload, not preview — users see a different image in the viewfinder than at reveal. Product call: intentional? Surprising?
- M27. Camera flash unsupported on front camera falls back silently; no UX feedback.
- M28. `photosRemaining` is `Int` (not `UInt`) — defensive, but allows negative in race scenarios.
- M29. `CameraView` locked-button shake uses cascading `DispatchQueue.main.asyncAfter` that compound on rapid taps.
- M30. `RevealStateManager` not thread-safe (read-modify-write in `markRevealCompleted`).

### 5.4 Offline sync / notifications / analytics
- M31. `queuePhoto` fires a detached upload + the next `processQueue` call. 10 photos in 5 seconds → 10 concurrent uploads, ignoring `maxConcurrentUploads = 3`.
- M32. No special handling for `401 / JWT expired` upload errors — loops to `maxRetries`, silently drops photos.
- M33. Stale-queue-entries dropped at cold launch with debug log only — no analytics. BACKLOG-noted.
- M34. `NotificationManager` doesn't offer a "Open Settings" deep link for users who denied permission.
- M35. `AnalyticsManager.trackError`'s `error.localizedDescription` truncation may still include URLs/JWT artefacts in edge cases — allowlist `error_type`s that get the full message.
- M36. `stampJoin` UserDefaults keys leak forever; not cleared on sign-out.
- M37. `HapticsManager.hapticFeedback` View extension installs `.onTapGesture` — can shadow legitimate button taps. Audit callsites or prefer `.sensoryFeedback()` (iOS 17+).
- M38. `HapticsManager` doesn't respect `UIAccessibility.isReduceMotionEnabled`.
- M39. No exponential backoff inside a single `processQueue` pass — three immediate retries can fail against the same flaky network in <500ms.

### 5.5 Events / lobby
- M40. `EventPreviewModal.memberText` always shows the placeholder "People here" — wire member count or remove the row.
- M41. Member sort order spec mismatch — VISION says current-user-first then shots-desc; code does current-user-then-original-order.
- M42. Create-event button has no `.disabled(isCreating)` guard — double-tap creates two events.
- M43. No client-side guard against `startsAt < now` on the time picker.
- M44. No max-length check on event name (Step 1).
- M45. 12 h live / 12 h gap to reveal is hardcoded — host can't pick a 2-hour party with same-night reveal. Documented in VISION; flag for v1.1.
- M46. `simultaneousGesture(DragGesture(minimumDistance: 0))` on JoinEventSheet's join button — SwiftUI anti-pattern, breaks accessibility.
- M47. `JoinEventSheet` no client-side rate-limit on `lookupEvent`. Server has the SECURITY DEFINER protection; still worth a debounce.
- M48. `QRCodeScanner` `metadataOutput` has no `rectOfInterest` set — accepts QRs from anywhere in frame, not just the visible 130×130 scan zone. UX mismatch.
- M49. Time-copy logic duplicated across `EventHeroView`, `EventCard`, `EventPreviewModal`, `PastEventCard` — consolidate in `TimeFormatter`.
- M50. `PastEventCard` constructs `DateFormatter` per render — cache as `static let`.
- M51. `HomeRouter.handleEventTap` no-op on tap of `.upcoming` event — undiscoverable. At least haptic feedback or a toast ("Starts in Xh").
- M52. Polling: `getEventMembersWithShots` runs for `.live || .upcoming`, but upcoming events always have `shotsTaken = 0`. Restrict to `.live`.
- M53. Polling efficiency: 4 round-trips per live event per 10 s tick. Sustainable at launch; consolidate into a single `get_event_hydrated(event_id)` RPC pre-scale.

### 5.6 Tests, tooling, project config
- M54. `MockMomentoAPI` is lenient (returns defaults for unconfigured methods, only `getMyEvents` and `deleteEvent` can throw). For OfflineSync-style tests you'll want strict-mode + throwing on every method.
- M55. UI test target is auto-generated stubs only and intentionally excluded from CI.
- M56. SwiftLint not enforced in CI — only via local `./lint.sh`. Add a CI step.
- M57. Two parallel signing setups (CI cert import + Fastlane Match). Pick one.
- M58. `fastlane/lanes/match_lane.rb` duplicates Fastfile's `setup_match` — dead code.
- M59. `Gemfile` doesn't pin Ruby version — fastlane requires 2.7+.
- M60. Hardcoded simulator names in `check_errors.sh` ("iPhone 15"), `run_simulator.sh` ("iPhone 15 Pro") will break on fresh machines.
- M61. `fix_build.sh` has a stale path (`/Users/asad/Documents/Momento`).
- M62. `run_simulator.sh` uses the wrong bundle id `com.momento.Momento` (should be `com.asad.Momento`).
- M63. `setup_github.sh`, `push_to_github.sh`, `create_github_repo.sh` are dead initial-bootstrap scripts (also have corrupted unicode). Delete.
- M64. `CLAUDE.md` says CI uses `-only-testing:MomentoTests/EventStoreTests`; actual `tests.yml` uses `-only-testing:MomentoTests` (target-wide). Update CLAUDE.md.
- M65. No `UIBackgroundModes` declared. If `OfflineSyncManager` should retry uploads in the background, declare `fetch` / `processing`.
- M66. Landscape orientation is allowed but `EventHeroView` lobby layout is portrait-only. Restrict to portrait or fix layout.
- M67. No designed launch screen — `UILaunchScreen_Generation = YES` produces an empty placeholder.
- M68. No iOS 18 dark/tinted app-icon variants.

### 5.7 Theme & accessibility (beyond the launch blockers)
- L1. `Color.white.opacity(0.4)` (`textQuaternary`) on near-black is borderline AA; `opacity(0.35)` (`textMuted`) fails AA.
- L2. `MomentoPrimaryButtonStyle` disabled state: white(0.3) on white(0.1) is nearly invisible.
- L3. Hardcoded `Color(red: 1.0, green: 0.42, blue: 0.21)` in `RevealCardView` — should be a brand color asset.

### 5.8 Debug / observability
- L4. `debugLog` is `#if DEBUG`-gated for the print, but call-site arguments still evaluate in release builds (string interpolation cost). Switch to `@autoclosure`.
- L5. `tracesSampleRate = 0.0` (Sentry) — performance traces off. Sane default; revisit post-launch.

---

## 6. What to ship, in order

A pragmatic ordering. Each block is roughly half a day of focused work.

### Day 0 — security incident
- Rotate the leaked GitHub PAT (B1). Switch to SSH or fine-grained read-only deploy key. `git filter-repo` the history.

### Day 1 — backend & data integrity
- B7: `supabase db pull` + commit a squash migration.
- B8: delete `reveal-photos` Edge Function.
- B9: move `createProfileIfNeeded` into `handleOAuthCallback` (or `checkSession`).
- H8: change `handle_new_user` fallback from email to generated username.
- H9: split `device_token` to a separate table or column-mask via a view.
- H11: toggle leaked-password protection in Supabase dashboard.

### Day 2 — product promise & critical user-state correctness
- B10: synchronous `photosRemaining` decrement in `CameraView` / `PhotoCaptureSheet`. Add `isCapturing` lock.
- B11: `PhotoCaptureSheet.fetchRemainingCount` failure shows error, doesn't fall back to a fresh 10.
- H1: wire image cache, scheduled notifications, photo storage, PostHog reset, stampJoin keys, OfflineSync queue (H25) into `signOut`.
- H2: call `identifyUserForAnalytics` from the auth state machine.
- H3: replace regex-based `needsUsernameSelection` with a boolean column or `username_set_at`.
- H4: per-user namespace `RevealStateManager`.
- H28: `NotificationManager.scheduleRevealReady` use `UNTimeIntervalNotificationTrigger`.

### Day 3 — Apple submission readiness
- B2: real privacy + terms URLs in SignInView.
- B3: final app icon.
- B4: Sentry DSN.
- B5: fill `[TBD]` fields in App Store launch docs.
- B12 + B13: VoiceOver labels on critical interactive elements; Dynamic Type for at least body / heading fonts in AppTheme.
- H39: Sentry `beforeSend` to strip image data, or `attachScreenshot = false` in release.
- H40: fix `INFOPLIST_KEY_NSCameraUsageDescription` string in `project.pbxproj`.
- H41: remove `in-app-payments` entitlement.
- H42: `ITSAppUsesNonExemptEncryption = false`.
- H43: `Package.resolved` re-resolve.
- H44: privacy manifest API reasons + verify SDK manifests.
- H48: `TARGETED_DEVICE_FAMILY = "1"`.
- B6: beta data wipe.

### Day 4 — invite UX + iPad-safety
- H31: ship `10shots.app` domain + AASA file, or temporary fallback in QR/share copy.
- H32: `ShareSheet` popover anchor — prevents iPad crash.
- H33: gate `JoinEventSheet` clipboard read behind a button or `detectPatterns(for:)`.
- H34: include code in `HomeSheet.join` id.
- H35: alias-map `O→0, I→1, L→1` in VerificationCodeInput, or hint alphabet.
- H36: reset `qrScanner.scannedCode = nil` on lookup error.
- H37: vertical roster fallback for >5 members on small phones.

### Day 5 — camera & reveal robustness
- H14–H17: AVCaptureSession sessionQueue, interruption handling, foreground/background lifecycle, permission state machine.
- H18: filter off main thread.
- H19: replace `fatalError`s with graceful degradation.
- H20: stable disk-cache key (SHA-256 of URL).
- H21: standardize on Documents for in-flight uploads, set `isExcludedFromBackup`.
- H22: reveal-likes flush via detached Task with structured completion.
- H23: `LikedGalleryView.saveToPhotos` use the cache.
- H24: confirm or no-op-mark on skip from reveal.
- H29: HapticsManager `prepare()` hoisted generators.
- H26, H27, H30: OfflineSyncManager + AnalyticsManager `@MainActor`.

### Post-launch v1.1
- All MEDIUM items in §5.
- Replace fan-out polling with a single hydrated-event RPC (M53).
- Server-side member-limit trigger (H10) for monetisation rollout.
- Real Edge Function for push notifications.
- Snapshot tests on `EventHeroView`.
- Localization scaffolding when entering non-EN markets.
- Internal rename `CreateMomentoFlow` → `CreateEventFlow`, drop legacy `EventCard` / `EventsScreenPreview`.

---

## 7. Anything to walk back

A few items from BACKLOG.md / CLAUDE.md that don't fully match the code today:

- **CLAUDE.md** says CI uses `-only-testing:MomentoTests/EventStoreTests`; the actual workflow uses target-wide `-only-testing:MomentoTests`. Update.
- **BACKLOG.md** lists "OfflineSyncManager unit tests" as deliberately deferred. Fair — but given H25 (cross-account queue retention), at minimum write a focused test that asserts `clearQueue()` is called from `signOut` once you wire it up.
- **BACKLOG.md** marks "Audit unused indexes" complete. The audit identified the right candidate to drop, but a composite `(event_id, user_id)` on `photos` is missing (M12).
- **VISION.md** principle "tasteful gamification only … no fake engagement loops" — the haptic patterns are good. But the auto-dismiss of the dot-flight animation timer in CameraView fires regardless of view lifecycle, can cascade past dismissal. Subtle violation; fix with cancellable Tasks.

---

## 8. What was not reviewed (gaps)

- **On-device behaviour:** every multi-device, multi-user, race-condition, and battery item in §"On-device verification" of BACKLOG. None of this can be inferred from code review alone. Reserve a half-day for the BACKLOG checklist on a real device with a second test account.
- **Localization:** the product is en-US-only at launch (`APP_STORE_COPY.md`). No `Localizable.strings`, no `String(localized:)`. Fine for v1; will block any non-EN market launch.
- **Snapshot / pixel-level UI regression testing** is intentionally deferred (BACKLOG).
- **Apple Pay / merchant ID actual provisioning status** — entitlement is present (see H41) but I haven't verified whether the merchant ID is live in Apple's records. If it is, removing it is a one-step Xcode edit; if it isn't, the entitlement will block provisioning today.
- **TestFlight is unverified** — the `testflight.yml` workflow has the SupabaseConfig clobber issue (H46) that probably means no TestFlight build has shipped with PostHog/Sentry wired up correctly.

---

## 9. Closing read

The bones are good. The architecture is clean, the state machine is tight, the test suite covers the launch-critical paths. Most of the BLOCKERs are surface-level (placeholder URLs, placeholder icon, placeholder Sentry DSN, leaked PAT) — not deep design problems. The single deep correctness issue is B10/B11 (the 10-shot lock race), which is the kind of thing only a long-form review surfaces, and it directly undermines the product's one-line pitch.

The HIGH-severity privacy / lifecycle issues — image cache and notification persistence across sign-out, regex trap for legitimate usernames, Google sign-in profile gap, timezone-naïve reveal notification, hash-unstable disk cache — are all bugs that would surface in week 1 of real usage. They're worth catching now.

Beyond launch, the work to do is mostly:
- consolidating duplicated time-formatter / countdown logic
- the polling fan-out → single RPC consolidation
- accessibility as a first-class concern, not retrofitted
- a stricter `MockMomentoAPI` to unlock OfflineSync tests

This codebase is in striking distance of shipping. Treat the BLOCKERs in §3 and the top-half of §4 as a focused ~4-day sprint, and you have a launchable build.
