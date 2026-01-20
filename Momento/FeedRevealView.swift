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
