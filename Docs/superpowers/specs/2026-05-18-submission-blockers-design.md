# 10shots v1.0 Submission Blockers — Design

**Date:** 2026-05-18
**Branch:** `worktree-submission-blockers`
**Status:** Approved for planning

## Context

A full pre-submission code review (5 parallel domain reviews + config audit) identified three
issues that should block App Store submission for 10shots v1.0:

- **B1** — No content reporting UI. Pure UGC photo app with `flagPhoto`/`deletePhoto` in the
  service layer but zero callers. Apple Guideline 1.2 risk.
- **B2** — Camera-permission-denied is a permanent dead-end (no Settings deep-link, no status
  re-check), plus a sibling dead-end in the same file: a failed QR scan shows no error in scan
  mode (the default).
- **B3** — `OfflineSyncManager` photo queue has an unsynchronized cross-thread race: the
  `pending → uploading` transition is not atomic, so the immediate upload can race the
  foreground/network-restore `processQueue`. Consequences: same photo uploaded twice (silently
  burns one of the user's 10 shots) and a cross-thread `queue` array access that can crash on
  device.

Competitor benchmark: **Once** (once.film) — a near-identical app (private, QR-join, same
PostHog/crash stack) is live on the App Store with a *light* moderation posture: a
prohibited-conduct + content-removal clause in its Terms, a support email, server-side removal
rights, and no publicly-visible in-app report/block. This establishes the minimum-viable bar and
informs the B1 scope decision below.

## Goals

1. Remove every known **code** blocker so the build has the strongest realistic chance of a
   first-pass App Review approval.
2. Keep diffs targeted and low-regression — this is the final pre-submission build, not a
   refactor window.
3. Land everything in the isolated `worktree-submission-blockers` worktree.

## Non-Goals (explicitly deferred to v1.1)

- User-to-user blocking.
- Full actor-ize of `OfflineSyncManager`.
- Other review findings: lost-likes-on-kill, full-res image OOM/downsampling,
  account-deletion storage-orphan sweep (when addressed, adopt Once's
  "anonymize attribution + disclose + 30-day window" model rather than hard byte deletion).
- Admin/moderation dashboard.

---

## B1 — Content Reporting (Apple Guideline 1.2)

**Decision:** Match Once's Terms posture + one in-app **Report** action per photo +
auto-hide-after-threshold + best-effort email notification. **No user-to-user block.**

### Backend (new migration; applied via Supabase MCP `apply_migration` AND committed to `Supabase/migrations/`)

- **New table `photo_reports`:**
  - `id uuid pk default gen_random_uuid()`
  - `photo_id uuid not null references photos(id) on delete cascade`
  - `reporter_id uuid not null default auth.uid()`
  - `reason text null`
  - `created_at timestamptz not null default now()`
  - Unique `(photo_id, reporter_id)` so a user can't inflate the count by re-reporting.
- **RLS on `photo_reports`:** RLS enabled.
  - INSERT: `with check (reporter_id = (select auth.uid()))`.
  - SELECT: `using (reporter_id = (select auth.uid()))` — a user sees only their own reports.
  - No UPDATE/DELETE policy (immutable from client).
- **New column `photos.hidden_at timestamptz null`** — the single clean "hidden from everyone"
  signal. Reconcile the existing inconsistency: `flagPhoto` currently writes
  `upload_status = "flagged"` while moderation expectations reference `is_flagged`; the new
  `reportPhoto` path and any future moderation use `hidden_at`. `flagPhoto`/`is_flagged` are
  left as-is (out of scope to rip out) but `reportPhoto` does not depend on them.
- **`AFTER INSERT` trigger on `photo_reports`:** count distinct `reporter_id` for the
  `photo_id`; if `>= threshold` set `photos.hidden_at = now()` (idempotent — only set if
  currently null). Threshold default **1** (a single report hides the photo for everyone,
  pending operator review — appropriate for small private events), as a SQL constant/comment
  so it is trivially tunable. This makes objectionable content self-remove within seconds →
  satisfies 1.2(c) without a human in the loop. SECURITY DEFINER, `search_path = ''`,
  fully-qualified, matching the project's established hardening pattern.
- **Email notification — DEFERRED to v1.1.** v1.0 ships the auto-hide trigger plus a
  `photo_reported` PostHog event for operator visibility. The Supabase Database Webhook →
  Edge Function email notification is explicitly out of scope for this build (operator will
  set up a transactional-email provider post-submission). The auto-hide is the
  compliance-critical leg and is independent of email, so deferral carries no 1.2 risk.

### Client

- **`MomentoAPI` / `SupabaseManager+Photos.swift`:** add
  `reportPhoto(id: UUID, reason: String?) async throws` → inserts into `photo_reports`. Add to
  the `MomentoAPI` protocol and `MockMomentoAPI`.
- **Report UI:** a "Report photo" action via long-press context menu on each shot in
  `RevealCardView` and `GalleryDetailView`. Tapping → confirmation dialog
  ("Report this photo? It will be hidden from you and reviewed.") → `reportPhoto`. On success,
  the photo is immediately removed from the local list for that user (optimistic) with a brief
  confirmation; on failure, surface via the standard `errorMessage` path + `trackError`.
- **Server-side hidden filter:** the reveal/liked/photo fetch queries
  (`fetchPhotosForRevealPaginated`, `getLikedPhotos`, `getPhotos`) must exclude a photo when:
  - `photos.hidden_at is not null` (globally auto-hidden), **OR**
  - the photo appears in the caller's own `photo_reports` rows (so a reporter never sees it
    again, even before the global threshold, and it survives reinstall — no client-local state).
  Implement as a `not in (select photo_id from photo_reports where reporter_id = auth.uid())`
  + `hidden_at is null` filter, or an equivalent SECURITY DEFINER view/RPC if the PostgREST
  query gets unwieldy. Pagination math (`fetchPhotosForRevealPaginated`) must remain correct
  after filtering — verify at counts 10/11/20/21 (the review flagged the existing
  inclusive-range `+1` interaction as fragile).

### Out of band — operator action items (cannot be done from this repo)

1. **Terms update** at `10shots.app/terms`: add a prohibited-conduct + content-removal clause.
   Exact copy to add (mirrors Once, satisfies the 1.2 EULA half):

   > **Acceptable use.** You may not upload content that is unlawful, infringing, harassing,
   > hateful, sexually explicit, or excessively violent, or that you do not have the right to
   > share. We have zero tolerance for objectionable content and abusive behaviour. We may
   > remove any content and suspend or terminate any account that violates these terms or the
   > law, at our discretion and without notice. To report content, contact
   > <support email>.

2. **App Review notes** (`Docs/launch/APP_REVIEW_NOTES.md`): add a short paragraph explaining
   the closed-group invite model and that every photo has an in-app Report action which
   auto-hides content on report and notifies the operator.

3. Post-v1.0: stand up a transactional-email provider (Resend / Postmark / SMTP) and add the
   Database Webhook → Edge Function email notification (deferred from this build).

---

## B2 — Camera Permission + Scan Dead-Ends

**Decision:** Fix both dead-ends together (same file, same "tap and nothing happens" failure
class a reviewer will hit).

### Permission dead-end

In `PhotoCaptureSheet.swift` and `JoinEventSheet.swift` camera-permission views:

- When `AVCaptureDevice.authorizationStatus(for: .video)` is `.denied` or `.restricted`:
  change the copy to explain camera must be enabled in Settings, and make the primary button
  call `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`.
- When `.notDetermined`: keep the existing request-access flow.
- Re-check `authorizationStatus` on `scenePhase → .active` (or `.onAppear` after returning)
  so a user who enables the permission in Settings and returns recovers automatically without
  a manual retap.

### Scan-mode silent failure

In `JoinEventSheet.swift`: `errorMessage` is currently rendered only inside the code-entry
column, so a failed scan (invalid code, `eventNotFound`, network error, event full) in scan
mode (the default) produces no visible feedback. Surface `errorMessage` as a visible
overlay/toast that renders in scan mode too, with friendly copy (mirror the existing
network/notFound friendly strings; do not leak raw `error.localizedDescription`).

---

## B3 — Upload Race

**Decision:** Atomic claim + server-side idempotency key. Full actor-ize deferred to v1.1.

### Atomic claim

Introduce a single serialized critical section that owns **only** the
`pending → uploading` transition (a small dedicated `actor`, or a lock used exclusively for
the claim — implementation plan to pick the lowest-regression mechanism). A queued photo can be
claimed for upload exactly once; concurrent callers (`queuePhoto`'s immediate detached upload,
`processQueue` on foreground/network-restore, `retryFailedUploads`) either get the claim or
skip. This also closes the cross-thread `queue` array access (`firstIndex` read racing a
`MainActor.run` mutation) that can crash with a Swift exclusivity violation. `@Published queue`
mutations must occur on the main actor.

### Server-side idempotency

The client generates the photo's identity (reuse the existing `QueuedPhoto.id` UUID) and
supplies it to the `photos` insert — either as the `photos.id` or a new
`photos.client_upload_id uuid unique` column. The insert becomes an upsert /
`on conflict do nothing`. Any duplicate insert — race-induced or kill-then-retry (a kill
between network success and queue-persist re-uploads after `loadQueue` resets
`uploading → pending`) — becomes a server-side no-op. Schema change applied via Supabase MCP
`apply_migration` AND committed to `Supabase/migrations/`.

---

## Cross-Cutting

- **Worktree:** all changes in `worktree-submission-blockers` off `origin/main`.
- **Migrations:** both new migrations applied via Supabase MCP **and** committed to
  `Supabase/migrations/`. The review flagged the migration folder is already non-replayable;
  do not worsen it — each new migration is self-contained and forward-only.
- **Xcode project:** any new Swift file registered in `Momento.xcodeproj/project.pbxproj`
  (PBXFileReference + correct PBXGroup + PBXSourcesBuildPhase) per CLAUDE.md.
- **Testing:**
  - Unit (CI `MomentoTests/EventStoreTests` pattern, `MockMomentoAPI`): `reportPhoto` call
    path; the hidden/own-reported filter exclusion logic; the atomic-claim invariant
    ("a photo is claimed at most once" under concurrent claim attempts).
  - SQL/branch verification: `photo_reports` RLS (a user cannot read others' reports), the
    threshold trigger sets `hidden_at`, the idempotency upsert is a no-op on conflict.
  - Manual device checks (documented for the developer, not automated): permission-denied →
    Settings → return recovers; failed scan shows an error; reveal pagination correct at
    10/11/20/21 photos with and without a hidden photo in the set.
  - Time-coupled paths (2 s glow, 3 s reconcile) remain out of scope per CLAUDE.md.
- **Build verification:** `xcodebuild build` against the iOS simulator after Swift changes
  (filtered output); let CI run the test suite on the PR rather than a slow cold local run.

## Out of Scope but Required for Approval (operator / ASC, not code)

These are NOT in this spec's implementation but gate approval — tracked so they are not lost:

1. App Privacy label in App Store Connect: PostHog data marked **Linked to user**, Tracking
   **No** (Guideline 5.1.2 — metadata rejection if mismatched).
2. Working demo Apple ID in App Review notes (no email/password login exists; review fails
   without it).
3. Vercel apex-primary flip so the AASA validates at the apex and Universal/invite links open
   in-app (not a rejection, but a poor reviewer experience otherwise).
4. The B1 Terms copy + App Review notes paragraph above.

## Risks

- **Reveal-fetch filter + pagination interaction.** Adding the hidden/reported exclusion to
  `fetchPhotosForRevealPaginated` interacts with the already-fragile inclusive-range `+1`
  paging. Mitigation: explicit verification at boundary counts; prefer a SECURITY DEFINER
  view/RPC if PostgREST filter composition is brittle.
- **Atomic-claim regression.** Touching the upload path right before submission. Mitigation:
  smallest possible critical section (claim only, not the whole manager); unit test the
  claim-once invariant; build + CI before merge.
- **Email leg dependency.** If no email provider is ready, the email is deferred — acceptable
  because the compliance-critical auto-hide is independent and ships regardless.
