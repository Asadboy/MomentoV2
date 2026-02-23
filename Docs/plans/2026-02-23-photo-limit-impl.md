# Photo Limit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a 12-photo-per-person limit with countdown UI, lock state, and server-side enforcement.

**Architecture:** Client-side countdown UX backed by server-side count queries on existing `photos` table. Single config constant makes the limit easy to change later. No schema changes.

**Tech Stack:** SwiftUI, AVFoundation, Supabase (PostgREST), PostHog analytics

---

### Task 1: Add PhotoLimitConfig constant

**Files:**
- Create: `Momento/Config/PhotoLimitConfig.swift`
- Modify: `Momento.xcodeproj/project.pbxproj`

**Step 1: Create the config file**

```swift
//
//  PhotoLimitConfig.swift
//  Momento
//
//  Photo limit configuration — easy to swap to host-configurable later
//

import Foundation

enum PhotoLimitConfig {
    /// Default photo limit per person per event.
    /// Future: replace with event.photoLimit from server.
    static let defaultPhotoLimit = 12
}
```

Write this to `Momento/Config/PhotoLimitConfig.swift`.

**Step 2: Add to Xcode project**

Add three entries to `project.pbxproj`:

1. **PBXBuildFile** (line ~65, before `End PBXBuildFile`):
```
C30B8D0A2F51000000000010 /* PhotoLimitConfig.swift in Sources */ = {isa = PBXBuildFile; fileRef = C30B8D0B2F51000000000010 /* PhotoLimitConfig.swift */; };
```

2. **PBXFileReference** (line ~138, before `End PBXFileReference`):
```
C30B8D0B2F51000000000010 /* PhotoLimitConfig.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PhotoLimitConfig.swift; sourceTree = "<group>"; };
```

3. **PBXGroup** — Add to Config group (`C3CONFGROUP001`) children, after `SupabaseConfig.swift`:
```
C30B8D0B2F51000000000010 /* PhotoLimitConfig.swift */,
```

4. **PBXSourcesBuildPhase** — Add to Sources section (line ~564, after `DebugLog.swift in Sources`):
```
C30B8D0A2F51000000000010 /* PhotoLimitConfig.swift in Sources */,
```

**Step 3: Commit**

```bash
git add Momento/Config/PhotoLimitConfig.swift Momento.xcodeproj/project.pbxproj
git commit -m "feat: add PhotoLimitConfig with default 12 photo limit"
```

---

### Task 2: Add getPhotoCount method to SupabaseManager

**Files:**
- Modify: `Momento/Services/SupabaseManager.swift`

**Step 1: Add the count method**

Add this method after the existing `getPhotos(eventId:)` method (after line 611 in SupabaseManager.swift):

```swift
/// Get the number of photos a user has taken for a specific event
func getPhotoCount(eventId: UUID, userId: UUID) async throws -> Int {
    struct CountResult: Decodable {
        let count: Int
    }

    let result: [CountResult] = try await client
        .from("photos")
        .select("*", head: true, count: .exact)
        .eq("event_id", value: eventId.uuidString)
        .eq("user_id", value: userId.uuidString)
        .execute()
        .value

    // The count comes from the response header when using head: true, count: .exact
    // But with Supabase Swift SDK, we need to use the count property
    return result.count
}
```

**Important:** The Supabase Swift SDK handles count queries differently. The correct approach is:

```swift
/// Get the number of photos a user has taken for a specific event
func getPhotoCount(eventId: UUID, userId: UUID) async throws -> Int {
    let photos: [PhotoModel] = try await client
        .from("photos")
        .select()
        .eq("event_id", value: eventId.uuidString)
        .eq("user_id", value: userId.uuidString)
        .execute()
        .value

    return photos.count
}
```

This is simple and correct. The photos table is already indexed on event_id. At 12 photos max per user per event, the payload is small.

**Step 2: Commit**

```bash
git add Momento/Services/SupabaseManager.swift
git commit -m "feat: add getPhotoCount method to SupabaseManager"
```

---

### Task 3: Add photoLimitReached analytics event

**Files:**
- Modify: `Momento/Services/AnalyticsManager.swift`

**Step 1: Add the new event to the enum**

Add `photoLimitReached` to the `AnalyticsEvent` enum, in the "Core loop health" section (after `revealCompleted` on line 18):

```swift
// Capture limit experiment
case photoLimitReached = "photo_limit_reached"
```

**Step 2: Commit**

```bash
git add Momento/Services/AnalyticsManager.swift
git commit -m "feat: add photoLimitReached analytics event"
```

---

### Task 4: Update CameraView with countdown, amber warning, and lock state

**Files:**
- Modify: `Momento/Features/Camera/CameraView.swift`

This is the largest task. The changes:

**Step 1: Update CameraView properties**

Replace the existing `@State private var photoCount = 0` with new properties. The full updated property section (lines 18-23):

```swift
struct CameraView: View {
    @ObservedObject var cameraController: CameraController
    let onPhotoCaptured: (UIImage) -> Void
    let onDismiss: () -> Void
    let photoLimit: Int              // Total allowed (e.g. 12)
    let initialRemaining: Int        // Remaining when camera opened

    @State private var showShutterFlash = false
    @State private var photosRemaining: Int = 0
    @State private var showSavedIndicator = false
    @State private var shutterShakeOffset: CGFloat = 0
    @State private var isLocked: Bool = false
```

Add an `onAppear` initializer for `photosRemaining`:
```swift
.onAppear {
    cameraController.startSession()
    photosRemaining = initialRemaining
    isLocked = initialRemaining <= 0
}
```

(Replace the existing `.onAppear` that only calls `startSession()`.)

**Step 2: Replace the top-bar photo count indicator**

Replace the existing photo count HStack (lines 64-75) with a countdown display:

```swift
// Photo countdown indicator
HStack(spacing: 6) {
    Image(systemName: "film")
        .font(.system(size: 14))
    Text("\(photosRemaining)")
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .contentTransition(.numericText())
}
.foregroundColor(photosRemaining <= 3 ? Color.orange : .white)
.padding(.horizontal, 12)
.padding(.vertical, 8)
.background(Capsule().fill(Color.black.opacity(0.4)))
```

Remove the `if photoCount > 0` guard — the counter should always show.

**Step 3: Replace the capture button with lock-aware version**

Replace the capture button (lines 119-133) with:

```swift
// Capture button
Button {
    if isLocked {
        // Shake + haptic on locked shutter
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        withAnimation(.default) {
            shutterShakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) {
                shutterShakeOffset = -8
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.default) {
                shutterShakeOffset = 6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.default) {
                shutterShakeOffset = 0
            }
        }
    } else {
        captureWithFeedback()
    }
} label: {
    ZStack {
        Circle()
            .fill(isLocked ? Color.gray : Color.white)
            .frame(width: 80, height: 80)

        Circle()
            .stroke(Color.white.opacity(0.3), lineWidth: 4)
            .frame(width: 90, height: 90)

        if isLocked {
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
.offset(x: shutterShakeOffset)
.disabled(!cameraController.isSessionRunning)
```

**Step 4: Update the onChange handler to decrement counter**

Replace the existing `onChange` block (lines 156-172) with:

```swift
.onChange(of: cameraController.capturedImage) { _, newValue in
    if let image = newValue {
        onPhotoCaptured(image)
        cameraController.clearCapturedImage()

        withAnimation {
            photosRemaining -= 1
        }

        if photosRemaining <= 0 {
            isLocked = true
        }

        // Show saved indicator briefly
        withAnimation(.easeOut(duration: 0.2)) {
            showSavedIndicator = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.3)) {
                showSavedIndicator = false
            }
        }
    }
}
```

**Step 5: Update the Preview**

Update the `#Preview` at the bottom to pass the new parameters:

```swift
#Preview {
    CameraView(
        cameraController: CameraController(),
        onPhotoCaptured: { image in
            debugLog("Photo captured: \(image.size)")
        },
        onDismiss: {
            debugLog("Dismiss camera")
        },
        photoLimit: 12,
        initialRemaining: 8
    )
}
```

**Step 6: Commit**

```bash
git add Momento/Features/Camera/CameraView.swift
git commit -m "feat: camera countdown from remaining, amber at 3, lock with shake at 0"
```

---

### Task 5: Update PhotoCaptureSheet to fetch remaining count and enforce limit

**Files:**
- Modify: `Momento/Features/Camera/PhotoCaptureSheet.swift`

**Step 1: Add state for remaining count and loading**

Add these properties to `PhotoCaptureSheet`:

```swift
@State private var photosRemaining: Int? = nil  // nil = loading
@State private var isLoadingCount = true
```

**Step 2: Add onAppear to fetch count**

Add a `.task` modifier to the outer `ZStack`:

```swift
.task {
    await fetchRemainingCount()
}
```

Add the fetch method:

```swift
private func fetchRemainingCount() async {
    guard let userId = SupabaseManager.shared.currentUser?.id else {
        photosRemaining = PhotoLimitConfig.defaultPhotoLimit
        isLoadingCount = false
        return
    }

    do {
        let count = try await SupabaseManager.shared.getPhotoCount(
            eventId: event.id,
            userId: userId
        )
        let remaining = max(0, PhotoLimitConfig.defaultPhotoLimit - count)
        await MainActor.run {
            photosRemaining = remaining
            isLoadingCount = false
        }

        if remaining <= 0 {
            AnalyticsManager.shared.track(.photoLimitReached, properties: [
                "event_id": event.id.uuidString
            ])
        }
    } catch {
        debugLog("Failed to fetch photo count: \(error)")
        await MainActor.run {
            photosRemaining = PhotoLimitConfig.defaultPhotoLimit
            isLoadingCount = false
        }
    }
}
```

**Step 3: Show loading state and pass remaining to CameraView**

Wrap the CameraView instantiation to handle loading state. Replace the existing `CameraView(...)` call (lines 32-39) with:

```swift
if isLoadingCount {
    VStack(spacing: 16) {
        ProgressView()
            .tint(.white)
        Text("Loading camera...")
            .foregroundColor(.gray)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
} else {
    CameraView(
        cameraController: cameraController,
        onPhotoCaptured: { image in
            handlePhotoCaptured(image)
        },
        onDismiss: {
            isPresented = false
        },
        photoLimit: PhotoLimitConfig.defaultPhotoLimit,
        initialRemaining: photosRemaining ?? PhotoLimitConfig.defaultPhotoLimit
    )
}
```

**Step 4: Block capture callback when at limit**

Update `handlePhotoCaptured` to decrement and check:

```swift
private func handlePhotoCaptured(_ image: UIImage) {
    guard let remaining = photosRemaining, remaining > 0 else { return }

    onPhotoCaptured(image, event)
    photosRemaining = remaining - 1

    if remaining - 1 <= 0 {
        AnalyticsManager.shared.track(.photoLimitReached, properties: [
            "event_id": event.id.uuidString
        ])
    }
}
```

**Step 5: Commit**

```bash
git add Momento/Features/Camera/PhotoCaptureSheet.swift
git commit -m "feat: fetch remaining count on camera open, enforce limit in PhotoCaptureSheet"
```

---

### Task 6: Add server-side upload rejection in OfflineSyncManager

**Files:**
- Modify: `Momento/Services/OfflineSyncManager.swift`

**Step 1: Add limit check before upload**

In `uploadQueuedPhoto`, add a photo limit check right after the retry limit check (after line 165) and before the "Update status to uploading" block:

```swift
// Check server-side photo limit before uploading
if let userId = supabaseManager.currentUser?.id {
    do {
        let count = try await supabaseManager.getPhotoCount(
            eventId: photo.eventId,
            userId: userId
        )
        if count >= PhotoLimitConfig.defaultPhotoLimit {
            debugLog("📷 Photo limit reached for event \(photo.eventId.uuidString.prefix(8)), dropping queued photo")
            await MainActor.run {
                if let idx = queue.firstIndex(where: { $0.id == photo.id }) {
                    queue[idx].status = .completed  // Mark as completed so it gets cleaned up
                    saveQueue()
                }
            }
            // Delete local file
            try? FileManager.default.removeItem(at: photo.localFileURL)
            return
        }
    } catch {
        debugLog("⚠️ Could not check photo limit, proceeding with upload: \(error)")
        // Proceed with upload if we can't check — server will reject if truly over limit
    }
}
```

**Step 2: Commit**

```bash
git add Momento/Services/OfflineSyncManager.swift
git commit -m "feat: server-side photo limit check before upload in OfflineSyncManager"
```

---

### Task 7: Final verification and commit

**Step 1: Review all changes**

Check that:
- `PhotoLimitConfig.defaultPhotoLimit` is used everywhere (not hardcoded 12)
- `CameraView` accepts `photoLimit` and `initialRemaining` parameters
- `PhotoCaptureSheet` fetches count on appear and passes to `CameraView`
- `OfflineSyncManager` checks limit before upload
- Analytics fires `photoLimitReached` when hitting 0
- No references to the old `photoCount` count-up state variable remain in `CameraView`

**Step 2: Full commit of any remaining changes**

```bash
git add -A
git commit -m "feat: 12-photo disposable camera limit with countdown, lock, and server enforcement"
```
