# v1.0 Submission Blockers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the three known App-Store-blocking code issues — no content-report path (Apple 1.2), camera-permission/scan dead-ends, and the photo-upload race — in the `worktree-submission-blockers` worktree.

**Architecture:** B1 = a `photo_reports` table + `photos.hidden_at` column + an `AFTER INSERT` trigger that hides a photo on the **first** report, a thin `reportPhoto` client method, a self-contained `.contextMenu` "Report" on each photo card, and a `hidden_at IS NULL` filter on the four photo-read queries. B2 = Settings-deep-link + `scenePhase` re-check in both camera-permission views, plus surfacing the scan-mode error. B3 = move the `pending→uploading` claim into a single `@MainActor` check-and-set (MainActor becomes the one serialization domain — no new lock), plus an end-to-end client-upload-id idempotency key.

**Tech Stack:** Swift / SwiftUI, Supabase (Postgres + PostgREST + Storage via supabase-swift), XCTest, Supabase MCP (`apply_migration`, `execute_sql`).

**Spec:** `Docs/superpowers/specs/2026-05-18-submission-blockers-design.md`

**Supabase project id:** `thnbjfcmawwaxvihggjm` (Momento, eu-west-1).

> **Deviation from spec (YAGNI, recorded):** the spec floated adding `reportPhoto` to the `MomentoAPI` protocol "for testability." The report UI calls `SupabaseManager` directly (like the existing like path) and `EventStore` does not mediate it, so there is no `MockMomentoAPI` test value — adding it to the protocol would touch `MomentoAPI` + `MockMomentoAPI` + `EventStore` for zero coverage. `reportPhoto` is therefore a concrete `SupabaseManager+Photos` method only. Verification of B1's compliance-critical behaviour is by SQL (RLS + trigger) per the project's backend-test convention; the Swift report path is build- + manual-verified. This matches CLAUDE.md (only `EventStoreTests` runs in CI; UI/infra paths are build+manual).

---

## File Structure

**B1 — content reporting**
- Create: `Supabase/migrations/20260518120000_photo_reports.sql` — `photo_reports` table, RLS, `photos.hidden_at`, hide-on-report trigger.
- Modify: `Momento/Services/SupabaseManager+Photos.swift` — add `reportPhoto(id:reason:)`; add `.is("hidden_at", value: nil)` to `getPhotos` and `fetchPhotosForRevealPaginated`.
- Modify: `Momento/Services/SupabaseManager+Likes.swift` — add `.is("hidden_at", value: nil)` to `getLikedPhotos` and `getLikedPhotoCount`.
- Modify: `Momento/Features/Reveal/RevealCardView.swift` — `.contextMenu` Report + reported-state card.
- Modify: `Momento/Features/Gallery/LikedGalleryView.swift` — same, on `GalleryDetailView`.

**B2 — permission / scan dead-ends**
- Modify: `Momento/Features/Camera/PhotoCaptureSheet.swift` — Settings deep-link + scenePhase recheck.
- Modify: `Momento/Features/Events/JoinEventSheet.swift` — Settings deep-link + scenePhase recheck on `cameraPermissionView`; render `errorMessage` in `scanModeView`.

**B3 — upload race + idempotency**
- Create: `Supabase/migrations/20260518120100_photo_idempotency.sql` — `photos.client_upload_id` + partial unique index.
- Modify: `Momento/Services/SupabaseDTOs.swift` — add `clientUploadId` to `PhotoModel`.
- Modify: `Momento/Services/SupabaseManager+Photos.swift` — `uploadPhoto` takes `clientUploadId`, derives storage path from it, `upsert` ignore-duplicates.
- Modify: `Momento/Services/OfflineSyncManager.swift` — atomic `@MainActor` claim; pass `photo.id` as `clientUploadId`.

---

## Task 1: B1 backend — `photo_reports`, `hidden_at`, hide-on-report trigger

**Files:**
- Create: `Supabase/migrations/20260518120000_photo_reports.sql`

- [ ] **Step 1: Write the migration file**

Create `Supabase/migrations/20260518120000_photo_reports.sql`:

```sql
-- =====================================================================
-- Apple Guideline 1.2 (UGC): in-app content reporting + auto-hide.
-- =====================================================================
-- Every photo gets an in-app "Report" action. A report inserts a row
-- here; an AFTER INSERT trigger hides the photo for everyone once it
-- reaches REPORT_THRESHOLD distinct reporters. Threshold is 1: a single
-- report removes the photo for all members pending operator review
-- (appropriate for small private events). This makes objectionable
-- content self-remove within seconds with no human in the loop, which
-- satisfies 1.2(c) ("act on reports").
--
-- hidden_at is the single "hidden from everyone" signal. The existing
-- flagPhoto/is_flagged path is unrelated and left as-is.
-- =====================================================================

ALTER TABLE public.photos
  ADD COLUMN IF NOT EXISTS hidden_at timestamptz;

CREATE TABLE IF NOT EXISTS public.photo_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id uuid NOT NULL REFERENCES public.photos(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL DEFAULT auth.uid(),
  reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (photo_id, reporter_id)
);

ALTER TABLE public.photo_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can file their own reports" ON public.photo_reports;
CREATE POLICY "Users can file their own reports"
  ON public.photo_reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can read their own reports" ON public.photo_reports;
CREATE POLICY "Users can read their own reports"
  ON public.photo_reports
  FOR SELECT TO authenticated
  USING (reporter_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.hide_photo_on_report()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  report_threshold CONSTANT INTEGER := 1;
  reporter_count INTEGER;
BEGIN
  SELECT count(DISTINCT reporter_id) INTO reporter_count
  FROM public.photo_reports
  WHERE photo_id = NEW.photo_id;

  IF reporter_count >= report_threshold THEN
    UPDATE public.photos
      SET hidden_at = now()
      WHERE id = NEW.photo_id
        AND hidden_at IS NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hide_photo_on_report ON public.photo_reports;
CREATE TRIGGER hide_photo_on_report
  AFTER INSERT ON public.photo_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.hide_photo_on_report();

REVOKE ALL ON FUNCTION public.hide_photo_on_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hide_photo_on_report() TO authenticated;
```

- [ ] **Step 2: Apply the migration to the remote project**

> ⚠️ This applies directly to the production Momento DB (CLAUDE.md prescribes `apply_migration` for schema changes; there is no local Postgres). It is additive and forward-only (new table, new nullable column, new trigger) — no existing data touched.

Use the Supabase MCP tool `mcp__claude_ai_Supabase__apply_migration` with:
- `project_id`: `thnbjfcmawwaxvihggjm`
- `name`: `20260518120000_photo_reports`
- `query`: the full SQL from Step 1.

- [ ] **Step 3: Verify schema + RLS via SQL**

Use `mcp__claude_ai_Supabase__execute_sql` (`project_id` `thnbjfcmawwaxvihggjm`):

```sql
SELECT
  (SELECT count(*) FROM information_schema.columns
     WHERE table_name='photos' AND column_name='hidden_at') AS has_hidden_at,
  (SELECT count(*) FROM information_schema.tables
     WHERE table_name='photo_reports') AS has_table,
  (SELECT count(*) FROM pg_policies
     WHERE tablename='photo_reports') AS policy_count,
  (SELECT count(*) FROM information_schema.triggers
     WHERE event_object_table='photo_reports'
       AND trigger_name='hide_photo_on_report') AS has_trigger;
```
Expected: `has_hidden_at=1, has_table=1, policy_count=2, has_trigger=1`.

- [ ] **Step 4: Verify the trigger hides on first report (transactional, rolled back)**

`execute_sql`:

```sql
BEGIN;
WITH p AS (SELECT id FROM public.photos WHERE hidden_at IS NULL LIMIT 1)
INSERT INTO public.photo_reports (photo_id, reporter_id, reason)
SELECT p.id, gen_random_uuid(), 'test' FROM p;
SELECT hidden_at IS NOT NULL AS now_hidden
FROM public.photos
WHERE id = (SELECT photo_id FROM public.photo_reports ORDER BY created_at DESC LIMIT 1);
ROLLBACK;
```
Expected: `now_hidden = true`. (If `photos` is empty, note it and rely on Step 3 + the device test in Task 9.)

- [ ] **Step 5: Commit**

```bash
git add Supabase/migrations/20260518120000_photo_reports.sql
git commit -m "feat(b1): photo_reports table + hide-on-report trigger (Apple 1.2)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: B1 client — `reportPhoto` + `hidden_at` read filters

**Files:**
- Modify: `Momento/Services/SupabaseManager+Photos.swift`
- Modify: `Momento/Services/SupabaseManager+Likes.swift`

- [ ] **Step 1: Add `reportPhoto` to `SupabaseManager+Photos.swift`**

Immediately after the existing `flagPhoto` function (ends at line 222 with `}`), add:

```swift
/// Files a content report for a photo. `reporter_id` defaults to
/// auth.uid() server-side; an AFTER INSERT trigger hides the photo
/// for everyone on the first report (Apple Guideline 1.2).
func reportPhoto(id: UUID, reason: String?) async throws {
    struct ReportInsert: Encodable {
        let photo_id: String
        let reason: String?
    }
    try await client
        .from("photo_reports")
        .insert(ReportInsert(photo_id: id.uuidString, reason: reason))
        .execute()

    debugLog("🚩 Photo reported")
}
```

- [ ] **Step 2: Filter hidden photos in `getPhotos`**

In `Momento/Services/SupabaseManager+Photos.swift`, the `getPhotos` function (lines 80-90). Add the `hidden_at` filter to the query so the chain is:

```swift
func getPhotos(eventId: UUID) async throws -> [PhotoModel] {
    let photos: [PhotoModel] = try await client
        .from("photos")
        .select()
        .eq("event_id", value: eventId.uuidString)
        .is("hidden_at", value: nil)
        .order("captured_at", ascending: false)
        .execute()
        .value

    return photos
}
```

- [ ] **Step 3: Filter hidden photos in `fetchPhotosForRevealPaginated`**

Same file, in `fetchPhotosForRevealPaginated` (lines 150-200), insert `.is("hidden_at", value: nil)` between the `.eq("event_id", ...)` and `.order(...)` lines so the query reads:

```swift
    let photos: [PhotoWithProfile] = try await client
        .from("photos")
        .select()
        .eq("event_id", value: uuid.uuidString)
        .is("hidden_at", value: nil)
        .order("captured_at", ascending: true)
        .range(from: offset, to: offset + limit)
        .execute()
        .value
```
(Pagination math is unchanged — filtering happens server-side before `range`, so `hasMore`/`prefix(limit)` stay correct. Boundary counts are device-verified in Task 9.)

- [ ] **Step 4: Filter hidden photos in `getLikedPhotos` and `getLikedPhotoCount`**

In `Momento/Services/SupabaseManager+Likes.swift`:

`getLikedPhotos` (the photos query at lines ~63-69) — add `.is("hidden_at", value: nil)` after the `.eq("event_id", ...)`:

```swift
    let photos: [PhotoRow] = try await client
        .from("photos")
        .select("id, storage_path, captured_at, captured_by, username")
        .eq("event_id", value: eventId.uuidString)
        .is("hidden_at", value: nil)
        .order("captured_at", ascending: true)
        .execute()
        .value
```

`getLikedPhotoCount` (the photos query at lines ~125-130) — add the same filter:

```swift
    let photos: [PhotoId] = try await client
        .from("photos")
        .select("id")
        .eq("event_id", value: eventId.uuidString)
        .is("hidden_at", value: nil)
        .execute()
        .value
```

- [ ] **Step 5: Build-verify**

Run:
```bash
xcodebuild -scheme Momento -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`, no `error:` lines.

- [ ] **Step 6: Commit**

```bash
git add Momento/Services/SupabaseManager+Photos.swift Momento/Services/SupabaseManager+Likes.swift
git commit -m "feat(b1): reportPhoto + exclude hidden photos from reads

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: B1 UI — Report action on `RevealCardView`

**Files:**
- Modify: `Momento/Features/Reveal/RevealCardView.swift`

The view has `let photo: PhotoData` (line 11) and `let eventId: String` (line 12). `photo.id` is a `String`. The reported state is kept local to the card (self-contained — no parent array surgery needed; threshold=1 means the next data refresh also drops it).

- [ ] **Step 1: Add report state**

Near the other `@State` declarations in `RevealCardView`, add:

```swift
@State private var showReportConfirm = false
@State private var isReported = false
```

- [ ] **Step 2: Add the context menu + confirmation + reported overlay**

In `photoView` (lines ~101-106), attach a context menu and a confirmation dialog to the image, and short-circuit to a "reported" card when `isReported`. Replace the body of `photoView` so the image is wrapped like this (keep the existing `Image(uiImage:)`/loading code as `imageContent`; the key additions are the `if isReported` branch, `.contextMenu`, and `.confirmationDialog`):

```swift
if isReported {
    VStack(spacing: 10) {
        Image(systemName: "flag.fill")
            .font(.system(size: 28))
            .foregroundColor(.white.opacity(0.6))
        Text("Reported")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
        Text("This photo is hidden and under review.")
            .font(.system(size: 13))
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
} else {
    // ...existing image content unchanged...
    Image(uiImage: image)
        // ...existing modifiers unchanged...
        .contextMenu {
            Button(role: .destructive) {
                showReportConfirm = true
            } label: {
                Label("Report photo", systemImage: "flag")
            }
        }
        .confirmationDialog(
            "Report this photo?",
            isPresented: $showReportConfirm,
            titleVisibility: .visible
        ) {
            Button("Report", role: .destructive) {
                Task {
                    try? await SupabaseManager.shared.reportPhoto(
                        id: UUID(uuidString: photo.id) ?? UUID(),
                        reason: nil
                    )
                    await MainActor.run { isReported = true }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be hidden from everyone and reviewed. This can't be undone.")
        }
}
```

> Note: `try?` here is intentional — a failed report still optimistically hides the card for this user, and threshold=1 means a successful report hides it server-side for everyone on next refresh. A network failure is the only loss case and is acceptable for v1 (the user can report again). Do **not** swap this for a silent no-op that leaves the photo visible.

- [ ] **Step 3: Build-verify**

```bash
xcodebuild -scheme Momento -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Momento/Features/Reveal/RevealCardView.swift
git commit -m "feat(b1): Report action on reveal photo cards

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: B1 UI — Report action on `GalleryDetailView`

**Files:**
- Modify: `Momento/Features/Gallery/LikedGalleryView.swift`

`GalleryDetailView` is embedded at lines 446-597; it has `let photo: PhotoData` (447) and `let eventId: String` (448); the photo is shown via an `AsyncImage` block at lines ~464-479.

- [ ] **Step 1: Add report state to `GalleryDetailView`**

Near `GalleryDetailView`'s other `@State` declarations, add:

```swift
@State private var showReportConfirm = false
@State private var isReported = false
```

- [ ] **Step 2: Add context menu + confirmation + reported overlay**

Wrap the `AsyncImage` block (lines ~464-479). When `isReported`, render the reported card instead; otherwise attach the context menu + confirmation:

```swift
if isReported {
    VStack(spacing: 10) {
        Image(systemName: "flag.fill")
            .font(.system(size: 28))
            .foregroundColor(.white.opacity(0.6))
        Text("Reported")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
        Text("This photo is hidden and under review.")
            .font(.system(size: 13))
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 80)
} else {
    // ...existing AsyncImage block unchanged...
    AsyncImage(url: ...) { ... }
        // ...existing modifiers unchanged...
        .contextMenu {
            Button(role: .destructive) {
                showReportConfirm = true
            } label: {
                Label("Report photo", systemImage: "flag")
            }
        }
        .confirmationDialog(
            "Report this photo?",
            isPresented: $showReportConfirm,
            titleVisibility: .visible
        ) {
            Button("Report", role: .destructive) {
                Task {
                    try? await SupabaseManager.shared.reportPhoto(
                        id: UUID(uuidString: photo.id) ?? UUID(),
                        reason: nil
                    )
                    await MainActor.run { isReported = true }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will be hidden from everyone and reviewed. This can't be undone.")
        }
}
```

- [ ] **Step 3: Build-verify**

```bash
xcodebuild -scheme Momento -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Momento/Features/Gallery/LikedGalleryView.swift
git commit -m "feat(b1): Report action on gallery detail view

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: B2 — `PhotoCaptureSheet` permission dead-end

**Files:**
- Modify: `Momento/Features/Camera/PhotoCaptureSheet.swift`

`permissionView` is at lines 148-179; it currently always calls `cameraController.requestPermission()`. `CameraController.checkPermission()` (CameraView.swift:594-603) already maps `.denied`/`.restricted` → `hasPermission=false`.

- [ ] **Step 1: Ensure UIKit + scenePhase available**

At the top of `PhotoCaptureSheet.swift`, if `import UIKit` is not already present, add it (needed for `UIApplication.openSettingsURLString`). Add to the `PhotoCaptureSheet` view struct, near its other `@Environment`/`@State`:

```swift
@Environment(\.scenePhase) private var scenePhase
```

- [ ] **Step 2: Replace the permission button with a status-aware button**

In `permissionView` (lines 148-179), replace the single `Button("Request Permission") { cameraController.requestPermission() }` with a computed status-aware button. Replace that `Button` line with:

```swift
if AVCaptureDevice.authorizationStatus(for: .video) == .denied
    || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
    Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    .buttonStyle(.borderedProminent)
    .tint(.white)

    Text("Camera access is off. Enable it in Settings, then return here.")
        .font(.footnote)
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
} else {
    Button("Request Permission") {
        cameraController.requestPermission()
    }
    .buttonStyle(.borderedProminent)
    .tint(.white)
}
```

- [ ] **Step 3: Re-check permission when returning from Settings**

On the root view of `PhotoCaptureSheet`'s `body` (the same view that renders `permissionView`), add a scenePhase observer that re-checks when the app becomes active:

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        cameraController.checkPermission()
    }
}
```
(If the project's Swift tools predate the two-parameter `onChange`, use `.onChange(of: scenePhase) { newPhase in ... }`. Resolve based on the build error in Step 4.)

- [ ] **Step 4: Build-verify**

```bash
xcodebuild -scheme Momento -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`. If `onChange` overload error: switch to the single-parameter closure form and rebuild.

- [ ] **Step 5: Commit**

```bash
git add Momento/Features/Camera/PhotoCaptureSheet.swift
git commit -m "fix(b2): camera-permission-denied opens Settings + auto-recovers

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: B2 — `JoinEventSheet` permission dead-end + scan-mode error

**Files:**
- Modify: `Momento/Features/Events/JoinEventSheet.swift`

`cameraPermissionView` is at lines 246-283 (button calls `qrScanner.requestPermission()`). `QRCodeScanner.checkPermission()` (lines 690-700) maps `.denied`/`.restricted` → `hasPermission=false`. `errorMessage` is declared at line 28 and rendered only inside `codeModeView` (lines 310-318). `scanModeView` is lines 136-169.

- [ ] **Step 1: Ensure UIKit + scenePhase**

At the top of `JoinEventSheet.swift`, add `import UIKit` if absent. In the main `JoinEventSheet` view struct (the one owning `errorMessage` at line 28), add near the `@State` block:

```swift
@Environment(\.scenePhase) private var scenePhase
```

- [ ] **Step 2: Status-aware button in `cameraPermissionView`**

In `cameraPermissionView` (lines 246-283), replace the `Button { qrScanner.requestPermission() } label: { Text("Enable Camera") ... }` block with:

```swift
if AVCaptureDevice.authorizationStatus(for: .video) == .denied
    || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
    Button {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    } label: {
        Text("Open Settings")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(12)
    }
    Text("Camera access is off. Enable it in Settings, then return here.")
        .font(.system(size: 12))
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
} else {
    Button {
        qrScanner.requestPermission()
    } label: {
        Text("Enable Camera")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(12)
    }
}
```

- [ ] **Step 3: Render the error in scan mode**

In `scanModeView` (lines 136-169), inside the `if qrScanner.hasPermission {` branch, after the camera `ZStack { ... }.padding(.horizontal, 24).padding(.top, 16)` and before `Spacer()`, insert:

```swift
if let error = errorMessage {
    HStack(spacing: 6) {
        Image(systemName: "exclamationmark.circle")
            .font(.system(size: 12))
        Text(error)
            .font(.system(size: 13))
    }
    .foregroundColor(.red.opacity(0.8))
    .padding(.top, 12)
    .padding(.horizontal, 24)
}
```

- [ ] **Step 4: Re-check permission on scene-active**

On the root view of `JoinEventSheet`'s `body`, add:

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        qrScanner.checkPermission()
    }
}
```
(Single-parameter form fallback as in Task 5 Step 3 if the build complains.)

- [ ] **Step 5: Build-verify**

```bash
xcodebuild -scheme Momento -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add Momento/Features/Events/JoinEventSheet.swift
git commit -m "fix(b2): join-sheet Settings deep-link + visible scan-mode error

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: B3 backend — `client_upload_id` idempotency column

**Files:**
- Create: `Supabase/migrations/20260518120100_photo_idempotency.sql`

- [ ] **Step 1: Write the migration**

Create `Supabase/migrations/20260518120100_photo_idempotency.sql`:

```sql
-- =====================================================================
-- Idempotency key for photo uploads.
-- =====================================================================
-- The offline upload queue can re-attempt an upload that already
-- succeeded (a kill between network-success and queue-persist; a race
-- between the immediate detached upload and processQueue). Without a
-- stable key each retry inserts a duplicate row, silently burning one
-- of the user's 10 shots.
--
-- The client supplies the QueuedPhoto UUID as client_upload_id. The
-- upload uses upsert(..., ignoreDuplicates: true) on this column so a
-- duplicate insert becomes a server-side no-op. Nullable + partial
-- unique index so legacy rows (NULL) are unaffected.
-- =====================================================================

ALTER TABLE public.photos
  ADD COLUMN IF NOT EXISTS client_upload_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS photos_client_upload_id_key
  ON public.photos (client_upload_id)
  WHERE client_upload_id IS NOT NULL;
```

- [ ] **Step 2: Apply via Supabase MCP**

`mcp__claude_ai_Supabase__apply_migration`, `project_id` `thnbjfcmawwaxvihggjm`, `name` `20260518120100_photo_idempotency`, `query` = the SQL above. (Additive, forward-only.)

- [ ] **Step 3: Verify**

`mcp__claude_ai_Supabase__execute_sql`:

```sql
SELECT
  (SELECT count(*) FROM information_schema.columns
     WHERE table_name='photos' AND column_name='client_upload_id') AS has_col,
  (SELECT count(*) FROM pg_indexes
     WHERE indexname='photos_client_upload_id_key') AS has_index;
```
Expected: `has_col=1, has_index=1`.

- [ ] **Step 4: Commit**

```bash
git add Supabase/migrations/20260518120100_photo_idempotency.sql
git commit -m "feat(b3): photos.client_upload_id idempotency column

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: B3 client — atomic claim + idempotent upload

**Files:**
- Modify: `Momento/Services/SupabaseDTOs.swift`
- Modify: `Momento/Services/SupabaseManager+Photos.swift`
- Modify: `Momento/Services/OfflineSyncManager.swift`

- [ ] **Step 1: Add `clientUploadId` to `PhotoModel`**

In `Momento/Services/SupabaseDTOs.swift`, the `PhotoModel` struct (lines 86-112). Add a stored property `let clientUploadId: UUID?` alongside the others, add `case clientUploadId = "client_upload_id"` to its `CodingKeys`, and add `clientUploadId` to the memberwise initializer if `PhotoModel` defines an explicit `init` (if it relies on the synthesized init, just adding the property + CodingKey is sufficient — but every existing `PhotoModel(...)` call site must then pass it; there is exactly one, in `uploadPhoto`, updated in Step 2). Make the property optional so decoding legacy rows (no key) succeeds.

- [ ] **Step 2: Make `uploadPhoto` idempotent**

In `Momento/Services/SupabaseManager+Photos.swift`, `uploadPhoto` (lines 26-77). Change the signature and the `photoId`/`fileName`/storage/insert so a stable client id drives both the storage path and the row:

Signature → add a parameter:
```swift
func uploadPhoto(image: Data, eventId: UUID, clientUploadId: UUID? = nil, width: Int? = nil, height: Int? = nil) async throws -> PhotoModel {
```

Replace `let photoId = UUID()` with:
```swift
let photoId = clientUploadId ?? UUID()
```
(`fileName` already derives from `photoId`, so it now becomes stable across retries.)

Change the storage upload `FileOptions(contentType: "image/jpeg", upsert: false)` → `upsert: true` (a retried upload to the same stable path overwrites instead of erroring).

In the `PhotoModel(...)` constructor add `clientUploadId: clientUploadId,`.

Replace the insert:
```swift
    try await client
        .from("photos")
        .insert(photo)
        .execute()
```
with an ignore-duplicates upsert:
```swift
    try await client
        .from("photos")
        .upsert(photo, onConflict: "client_upload_id", ignoreDuplicates: true)
        .execute()
```
> Accepted corner: the BEFORE INSERT photo-limit trigger (`enforce_photo_limit_per_user`, P0010) still fires on an ignored duplicate. A retry of an already-succeeded photo when the user is at 10 may surface a limit error instead of a silent no-op. `OfflineSyncManager` already treats P0010 as terminal and stops — the net outcome (photo exists once, no double-count) is correct; only the log is non-ideal. Do not attempt to suppress the trigger.

- [ ] **Step 3: Pass the queue id through from `OfflineSyncManager`**

In `Momento/Services/OfflineSyncManager.swift`, the `uploadPhoto` call site (line ~258):
```swift
        _ = try await supabaseManager.uploadPhoto(image: imageData, eventId: photo.eventId)
```
→
```swift
        _ = try await supabaseManager.uploadPhoto(image: imageData, eventId: photo.eventId, clientUploadId: photo.id)
```

- [ ] **Step 4: Add the atomic `@MainActor` claim**

In `OfflineSyncManager.swift`, add this method to the class (e.g. just above `uploadQueuedPhoto`):

```swift
/// Atomically transitions a queued photo pending/failed -> uploading.
/// Runs on the MainActor, which is the single serialization domain for
/// all queue mutations, so a photo can be claimed for upload exactly
/// once even when the immediate detached upload, processQueue, and
/// retryFailedUploads race. Returns false if the photo is gone, already
/// uploading/completed, or out of retries.
@MainActor
private func claimForUpload(_ photoId: UUID) -> Bool {
    guard let idx = queue.firstIndex(where: { $0.id == photoId }) else { return false }
    let status = queue[idx].status
    guard status == .pending || status == .failed else { return false }
    guard queue[idx].retryCount < maxRetries else { return false }
    queue[idx].status = .uploading
    queue[idx].lastAttemptAt = Date()
    activeUploads += 1
    saveQueue()
    return true
}
```

- [ ] **Step 5: Rewire `uploadQueuedPhoto` to use the claim**

In `uploadQueuedPhoto` (lines 184-299):

a) Delete the off-actor guard at the top (lines 185-191):
```swift
    guard let index = queue.firstIndex(where: { $0.id == photo.id }) else {
        return
    }

    // Skip if already uploading or completed
    if queue[index].status == .uploading || queue[index].status == .completed {
        return
    }
```

b) Keep the existing max-retries block (193-211) and the server-side photo-limit pre-check block (213-238) exactly as they are.

c) Replace the "Update status to uploading" `await MainActor.run { ... }` block (lines 240-248):
```swift
    // Update status to uploading
    await MainActor.run {
        if let idx = queue.firstIndex(where: { $0.id == photo.id }) {
            queue[idx].status = .uploading
            queue[idx].lastAttemptAt = Date()
            activeUploads += 1
            saveQueue()
        }
    }
```
with:
```swift
    // Atomically claim this photo for upload. Exactly one caller wins.
    let claimed = await claimForUpload(photo.id)
    guard claimed else {
        debugLog("⏭️ Upload skipped — already claimed/ineligible: \(photo.id.uuidString.prefix(8))")
        return
    }
```

The success path (`status = .completed`) and the `catch` failure path remain unchanged — they already run inside `await MainActor.run` and look up the index freshly, which is correct now that claiming is serialized on the MainActor.

- [ ] **Step 6: Build-verify**

```bash
xcodebuild -scheme Momento -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`. (If the synthesized `PhotoModel` init complains about argument order, match `clientUploadId`'s position to its property declaration order.)

- [ ] **Step 7: Run the existing unit suite (no regressions)**

```bash
xcodebuild test -scheme Momento -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MomentoTests/EventStoreTests 2>&1 | grep -E "Test Suite|failed|passed|\*\* TEST"
```
Expected: all `EventStoreTests` pass (this task does not change `EventStore` behaviour; this is a regression guard).

> **Why no new unit test here:** the claim is `@MainActor private` on a `static let shared` singleton that reads/writes a file-backed queue in the app documents directory. Per CLAUDE.md, infra/time-coupled paths "would need a scheduler injection. Skip for now." The correctness argument is structural and recorded in Task 8's self-review note below; behavioural verification is the device test in Task 9.

- [ ] **Step 8: Commit**

```bash
git add Momento/Services/SupabaseDTOs.swift Momento/Services/SupabaseManager+Photos.swift Momento/Services/OfflineSyncManager.swift
git commit -m "fix(b3): atomic upload claim + client_upload_id idempotent upload

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Device-verification checklist (manual — for the developer)

Not automated (camera, multi-state, real network). Run on a physical device before archiving. Record pass/fail.

- [ ] **B1 report:** In a revealed event, long-press a photo → Report → confirm. Card flips to "Reported". Re-fetch / reopen the event → that photo is gone for you. On a second device/account that did not report, the same photo is also gone (threshold=1, hidden globally).
- [ ] **B1 RLS:** Via Supabase SQL editor as an authenticated non-admin (or `execute_sql` with a role check), confirm `SELECT * FROM photo_reports` returns only the caller's own rows.
- [ ] **B1 pagination:** An event with **11** photos then **21** photos, none hidden: scroll the reveal end-to-end, count equals the real count (no skipped/duplicated photo at the page boundary). Then hide one mid-list and confirm the count drops by exactly one with no gap/crash.
- [ ] **B2 permission:** Settings → deny Camera for 10shots. Open an event → tap to shoot → permission screen now shows **Open Settings**; tap it, enable Camera, return to the app → viewfinder appears with **no** extra tap. Repeat for the Join sheet's QR scanner.
- [ ] **B2 scan error:** In the Join sheet scan mode, scan an invalid/expired QR (or a code for a full event) → a visible red error appears in scan mode (previously nothing happened).
- [ ] **B3 idempotency:** Airplane-mode, take a shot (queues), restore network so it uploads; force-quit during/just after upload and relaunch. Confirm the event has the photo **once**, the user's shot count is correct (not double-incremented), and no duplicate appears in the reveal.
- [ ] **B3 race:** Take all 10 shots rapidly while toggling network a few times; confirm exactly 10 photos server-side (`execute_sql`: `SELECT count(*) FROM photos WHERE event_id=... AND user_id=...`) and no crash.

---

## Self-Review

**1. Spec coverage**

| Spec requirement | Task |
|---|---|
| B1 `photo_reports` table + RLS | Task 1 |
| B1 `photos.hidden_at` + threshold trigger (threshold **1**) | Task 1 |
| B1 email notification | Explicitly **deferred to v1.1** per spec — not in plan (by design) |
| B1 `reportPhoto` client method | Task 2 |
| B1 hidden filter on reveal/liked/getPhotos | Task 2 |
| B1 Report UI on RevealCardView + GalleryDetailView | Tasks 3, 4 |
| B2 permission Settings deep-link + scene recheck (both views) | Tasks 5, 6 |
| B2 scan-mode error surfaced | Task 6 |
| B3 atomic claim | Task 8 |
| B3 server idempotency key | Tasks 7, 8 |
| Migrations applied via MCP **and** committed | Tasks 1, 7 |
| Out-of-scope operator items (Terms copy, ASC privacy label, demo Apple ID, apex flip) | Not code — tracked in spec "Out of Scope but Required" |

No spec requirement is without a task (email deferral is intentional and recorded).

**2. Placeholder scan** — no "TBD/TODO/handle appropriately"; every code step shows full code. The "existing image content unchanged" / "existing AsyncImage block unchanged" notes in Tasks 3-4 are deliberate (the surrounding view code is large and untouched); the *added* code is given in full.

**3. Type consistency** — `reportPhoto(id: UUID, reason: String?)` is declared in Task 2 and called identically in Tasks 3 & 4. `clientUploadId: UUID?` is added to `PhotoModel` (Task 8.1), set in `uploadPhoto` (8.2), and the `uploadPhoto` signature `clientUploadId: UUID? = nil` (8.2) matches the call `clientUploadId: photo.id` (8.3, `photo.id` is `UUID` per `QueuedPhoto.id: UUID`). `claimForUpload(_:) -> Bool` defined 8.4, called 8.5. `hidden_at` column (Task 1) matches `.is("hidden_at", value: nil)` filters (Task 2). Trigger function/ trigger names unique and consistent.

**B3 correctness argument (recorded):** every path that sets `.uploading` now goes through `claimForUpload`, which is `@MainActor`; `processQueue`, the detached `queuePhoto` task, and `retryFailedUploads` all reach `.uploading` only via `uploadQueuedPhoto` → `claimForUpload`. The MainActor serializes the check-and-set, so two racing callers cannot both observe `pending`/`failed` and both transition to `uploading`; the loser gets `false` and returns. The off-actor `queue.firstIndex` read that risked a Swift exclusivity crash is deleted. Idempotency (Task 7/8) is the second line of defence for the kill-between-success-and-persist case the in-process claim cannot cover.
