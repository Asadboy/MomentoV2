# Feed Reveal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Tinder-style swipe reveal with vertical scroll feed that has tap-to-reveal, like/download buttons, and image caching.

**Architecture:** Three new files: `ImageCacheManager` (caching layer), `RevealCardView` (card component), `FeedRevealView` (main view). Wire up in `ContentView` replacing `StackRevealView`.

**Tech Stack:** SwiftUI, NSCache for memory, FileManager for disk cache, existing SupabaseManager for data.

---

## Task 1: Create ImageCacheManager

**Files:**
- Create: `Momento/Services/ImageCacheManager.swift`

**Step 1: Create the file with basic structure**

Create `Momento/Services/ImageCacheManager.swift`:

```swift
//
//  ImageCacheManager.swift
//  Momento
//
//  Two-tier image caching: memory (NSCache) + bounded disk cache.
//  Reduces bandwidth by preventing re-downloads on scroll.
//

import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()

    // MARK: - Memory Cache
    private let memoryCache = NSCache<NSString, UIImage>()

    // MARK: - Disk Cache
    private let diskCacheLimit = 100 * 1024 * 1024 // 100MB
    private let cacheDirectory: URL

    private init() {
        // Set up disk cache directory
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure memory cache
        memoryCache.countLimit = 50 // Max 50 images in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // ~50MB
    }

    // MARK: - Public API

    /// Get image from cache or download
    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)

        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Check disk cache
        if let diskCached = loadFromDisk(key: key) {
            memoryCache.setObject(diskCached, forKey: key as NSString)
            return diskCached
        }

        // 3. Download and cache
        guard let image = await downloadImage(url: url) else { return nil }

        // Save to both caches
        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)

        return image
    }

    /// Clear all caches
    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Clear disk cache only (memory stays for current session)
    func clearDiskCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private Helpers

    private func cacheKey(for url: URL) -> String {
        // Use URL's last path component + hash for uniqueness
        let hash = url.absoluteString.hashValue
        return "\(url.lastPathComponent)_\(hash)"
    }

    private func diskPath(for key: String) -> URL {
        cacheDirectory.appendingPathComponent(key)
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        let path = diskPath(for: key)
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        // Check cache size before saving
        enforceDiskLimit()

        try? data.write(to: path)
    }

    private func downloadImage(url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("❌ Failed to download image: \(error)")
            return nil
        }
    }

    private func enforceDiskLimit() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else { return }

        // Calculate total size
        var totalSize = 0
        var fileInfos: [(url: URL, size: Int, date: Date)] = []

        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                  let size = attrs.fileSize,
                  let date = attrs.creationDate else { continue }
            totalSize += size
            fileInfos.append((file, size, date))
        }

        // If over limit, delete oldest files
        if totalSize > diskCacheLimit {
            let sorted = fileInfos.sorted { $0.date < $1.date }
            var freedSpace = 0

            for file in sorted {
                try? fileManager.removeItem(at: file.url)
                freedSpace += file.size
                if totalSize - freedSpace < diskCacheLimit { break }
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add Momento/Services/ImageCacheManager.swift
git commit -m "feat: add two-tier image cache manager

Memory cache (NSCache) + bounded 100MB disk cache.
Auto-evicts oldest files when limit exceeded."
```

---

## Task 2: Create RevealCardView

**Files:**
- Create: `Momento/RevealCardView.swift`

**Step 1: Create the card component**

Create `Momento/RevealCardView.swift`:

```swift
//
//  RevealCardView.swift
//  Momento
//
//  Individual photo card for feed reveal.
//  Handles unrevealed/revealed states with tap-to-reveal animation.
//

import SwiftUI

struct RevealCardView: View {
    let photo: PhotoData
    @Binding var isRevealed: Bool
    @Binding var isLiked: Bool
    let onDownload: () -> Void

    @State private var loadedImage: UIImage?
    @State private var isLoadingImage = false

    var body: some View {
        VStack(spacing: 0) {
            // Photo area
            ZStack {
                // Actual photo (always present, hidden by overlay when unrevealed)
                photoView

                // Grainy overlay (fades out on reveal)
                if !isRevealed {
                    unrevealedOverlay
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(4/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                revealPhoto()
            }

            // Action bar (only shows when revealed)
            if isRevealed {
                actionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .task {
            await loadImage()
        }
    }

    // MARK: - Subviews

    private var photoView: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoadingImage {
                Rectangle()
                    .fill(Color(white: 0.15))
                    .overlay(ProgressView().tint(.white))
            } else {
                Rectangle()
                    .fill(Color(white: 0.15))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
    }

    private var unrevealedOverlay: some View {
        ZStack {
            // Film grain texture (using noise pattern)
            Canvas { context, size in
                for _ in 0..<2000 {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let gray = CGFloat.random(in: 0.1...0.25)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(Color(white: gray))
                    )
                }
            }
            .background(Color(white: 0.12))

            // Tap hint
            VStack(spacing: 8) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 32))
                Text("Tap to reveal")
                    .font(.subheadline)
            }
            .foregroundColor(.white.opacity(0.6))
        }
    }

    private var actionBar: some View {
        HStack(spacing: 40) {
            // Like button
            Button {
                toggleLike()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundColor(isLiked ? .red : .white)
                    Text(isLiked ? "Liked" : "Like")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }

            // Download button
            Button {
                onDownload()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                    Text("Save")
                        .font(.subheadline)
                }
                .foregroundColor(.white)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func revealPhoto() {
        guard !isRevealed else { return }

        HapticsManager.shared.light()

        withAnimation(.easeOut(duration: 0.3)) {
            isRevealed = true
        }
    }

    private func toggleLike() {
        HapticsManager.shared.light()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
        }
    }

    private func loadImage() async {
        guard let url = photo.url else { return }
        isLoadingImage = true

        // Use cache manager
        if let cached = await ImageCacheManager.shared.image(for: url) {
            await MainActor.run {
                loadedImage = cached
                isLoadingImage = false
            }
        } else {
            await MainActor.run {
                isLoadingImage = false
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        RevealCardView(
            photo: PhotoData(
                id: "test",
                url: URL(string: "https://picsum.photos/800/600"),
                capturedAt: Date(),
                photographerName: "Test User"
            ),
            isRevealed: .constant(false),
            isLiked: .constant(false),
            onDownload: {}
        )
    }
}
```

**Step 2: Commit**

```bash
git add Momento/RevealCardView.swift
git commit -m "feat: add RevealCardView component

Tap-to-reveal with grainy overlay fade animation.
Like/download action bar appears after reveal."
```

---

## Task 3: Create FeedRevealView

**Files:**
- Create: `Momento/FeedRevealView.swift`

**Step 1: Create the main feed view**

Create `Momento/FeedRevealView.swift`:

```swift
//
//  FeedRevealView.swift
//  Momento
//
//  Vertical scroll feed for photo reveal.
//  Replaces StackRevealView (Tinder-style swipes).
//

import SwiftUI
import Photos

struct FeedRevealView: View {
    let event: Event
    let onComplete: () -> Void

    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var photos: [PhotoData] = []
    @State private var revealedStates: [String: Bool] = [:]
    @State private var likedStates: [String: Bool] = [:]
    @State private var isLoading = true
    @State private var showingCompletion = false

    // Track scroll position for progress
    @State private var visiblePhotoIndex: Int = 0

    var likedCount: Int {
        likedStates.values.filter { $0 }.count
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if isLoading {
                loadingView
            } else if photos.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    // Progress header
                    progressHeader

                    // Scrollable feed
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                                RevealCardView(
                                    photo: photo,
                                    isRevealed: binding(for: photo.id, in: $revealedStates, default: false),
                                    isLiked: binding(for: photo.id, in: $likedStates, default: false),
                                    onDownload: { downloadPhoto(photo) }
                                )
                                .onAppear {
                                    visiblePhotoIndex = index
                                }
                            }

                            // Completion section at bottom
                            completionSection
                                .padding(.top, 24)
                                .padding(.bottom, 48)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .task {
            await loadPhotos()
        }
        .onDisappear {
            // Save liked states when leaving
            Task {
                await saveLikedPhotos()
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading photos...")
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
            Text("No photos to reveal")
                .font(.title2)
                .foregroundColor(.white)
        }
    }

    private var progressHeader: some View {
        HStack {
            // Position indicator
            Text("\(visiblePhotoIndex + 1) of \(photos.count)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            // Liked count
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(likedCount) liked")
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }

    private var completionSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("You've seen all \(photos.count) photos!")
                .font(.headline)
                .foregroundColor(.white)

            Text("\(likedCount) photos liked")
                .foregroundColor(.white.opacity(0.7))

            Button {
                Task {
                    await saveLikedPhotos()
                    onComplete()
                }
            } label: {
                Text("View Liked Photos")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.5, green: 0.0, blue: 0.8))
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 32)
    }

    // MARK: - Data Loading

    private func loadPhotos() async {
        do {
            let loadedPhotos = try await supabaseManager.getPhotos(for: event.id)

            // Load existing liked states
            guard let eventUUID = UUID(uuidString: event.id) else {
                await MainActor.run {
                    photos = loadedPhotos
                    isLoading = false
                }
                return
            }

            let likedPhotos = try await supabaseManager.getLikedPhotos(for: eventUUID)
            let likedIds = Set(likedPhotos.map { $0.id })

            await MainActor.run {
                photos = loadedPhotos

                // Initialize liked states from existing data
                for photo in loadedPhotos {
                    likedStates[photo.id] = likedIds.contains(photo.id)
                    // Photos that were already liked should be revealed
                    if likedIds.contains(photo.id) {
                        revealedStates[photo.id] = true
                    }
                }

                isLoading = false
            }
        } catch {
            print("❌ Failed to load photos: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    // MARK: - Actions

    private func downloadPhoto(_ photo: PhotoData) {
        guard let url = photo.url else { return }

        Task {
            // Get image from cache
            guard let image = await ImageCacheManager.shared.image(for: url) else {
                print("❌ Failed to get image for download")
                return
            }

            // Save to photo library
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    print("❌ Photo library access denied")
                    return
                }

                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

                DispatchQueue.main.async {
                    HapticsManager.shared.success()
                }
            }
        }
    }

    private func saveLikedPhotos() async {
        for (photoId, isLiked) in likedStates {
            guard let photoUUID = UUID(uuidString: photoId) else { continue }

            if isLiked {
                try? await supabaseManager.setPhotoInteraction(photoId: photoUUID, status: .liked)
            }
            // Note: We don't explicitly archive - scrolling past is implicit skip
        }
    }

    // MARK: - Helpers

    /// Creates a binding for a dictionary value with a default
    private func binding<T>(for key: String, in dict: Binding<[String: T]>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { dict.wrappedValue[key] ?? defaultValue },
            set: { dict.wrappedValue[key] = $0 }
        )
    }
}

#Preview {
    let event = Event(
        title: "London Trip",
        coverEmoji: "🇬🇧",
        startsAt: Date().addingTimeInterval(-86400),
        endsAt: Date().addingTimeInterval(-43200),
        releaseAt: Date().addingTimeInterval(-3600),
        memberCount: 11,
        photosTaken: 200,
        joinCode: "LONDON"
    )

    return FeedRevealView(event: event, onComplete: {})
}
```

**Step 2: Commit**

```bash
git add Momento/FeedRevealView.swift
git commit -m "feat: add FeedRevealView with vertical scroll

Vertical feed replacing Tinder swipes. Tap to reveal,
like/download buttons, progress indicator with liked count."
```

---

## Task 4: Wire Up in ContentView

**Files:**
- Modify: `Momento/ContentView.swift:238`

**Step 1: Find and replace StackRevealView usage**

In `Momento/ContentView.swift`, find this code (around line 238):

```swift
.fullScreenCover(isPresented: $showStackReveal) {
    if let event = selectedEventForReveal {
        StackRevealView(event: event) {
            // On complete - show liked gallery
            showStackReveal = false
            showLikedGallery = true
        }
    }
}
```

Replace `StackRevealView` with `FeedRevealView`:

```swift
.fullScreenCover(isPresented: $showStackReveal) {
    if let event = selectedEventForReveal {
        FeedRevealView(event: event) {
            // On complete - show liked gallery
            showStackReveal = false
            showLikedGallery = true
        }
    }
}
```

**Step 2: Commit**

```bash
git add Momento/ContentView.swift
git commit -m "feat: switch to FeedRevealView in navigation

Replace StackRevealView with new vertical scroll feed."
```

---

## Task 5: Build and Test

**Step 1: Build the project**

Open Xcode and build (Cmd+B) or run:

```bash
cd /Users/asad/Documents/Momento/.worktrees/feed-reveal
xcodebuild -scheme Momento -destination 'platform=iOS Simulator,name=iPhone 15' build
```

**Step 2: Manual test checklist**

Run the app in simulator and verify:

- [ ] Open an event in reveal state
- [ ] Feed loads with grainy unrevealed cards
- [ ] Progress shows "1 of N" and "0 liked"
- [ ] Tap card → grainy overlay fades, photo appears
- [ ] Like button works, heart fills red, liked count updates
- [ ] Download button saves to camera roll
- [ ] Scroll up/down → images stay cached (no re-loading flicker)
- [ ] Photos display correctly (NOT mirrored)
- [ ] Reach bottom → completion section shows
- [ ] "View Liked Photos" navigates to gallery

**Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: address issues from testing"
```

---

## Task 6: Final Cleanup

**Step 1: Verify no mirror bug**

Test with actual photos from both front and back camera. Photos should display with correct orientation (not horizontally flipped).

**Step 2: Optional - deprecate old view**

Add deprecation comment to `StackRevealView.swift`:

```swift
//
//  StackRevealView.swift
//  Momento
//
//  DEPRECATED: Use FeedRevealView instead.
//  Kept for reference during transition.
//
```

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: mark StackRevealView as deprecated

FeedRevealView is now the primary reveal experience."
```

---

## Summary

| Task | Files | Description |
|------|-------|-------------|
| 1 | `Services/ImageCacheManager.swift` | Two-tier caching (memory + disk) |
| 2 | `RevealCardView.swift` | Card component with tap-to-reveal |
| 3 | `FeedRevealView.swift` | Main vertical scroll feed |
| 4 | `ContentView.swift` | Wire up new view |
| 5 | - | Build and manual testing |
| 6 | `StackRevealView.swift` | Deprecate old view |

**Expected outcome:**
- Photos display correctly (no mirroring)
- Vertical scroll feels natural
- Tap-to-reveal with smooth fade
- Like/download buttons work
- Progress shows position + liked count
- Images cache properly (no re-download flicker)
- Bandwidth reduced significantly
