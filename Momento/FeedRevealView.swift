//
//  FeedRevealView.swift
//  Momento
//
//  Vertical scroll feed for photo reveal.
//  Replaces StackRevealView (Tinder-style swipes).
//

import SwiftUI
import Photos

// MARK: - View Model

@MainActor
class FeedRevealViewModel: ObservableObject {
    @Published var photos: [PhotoData] = []
    @Published var revealedStates: [String: Bool] = [:]
    @Published var likedStates: [String: Bool] = [:]
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var visiblePhotoIndex: Int = 0

    // Pagination state
    private var hasMorePhotos = true
    private var currentOffset = 0
    private let pageSize = 10
    private let prefetchThreshold = 3 // Load more when 3 photos from end
    private var currentEventId: String = ""
    private var likedPhotoIds: Set<String> = []

    var likedCount: Int {
        likedStates.values.filter { $0 }.count
    }

    func isRevealed(_ photoId: String) -> Bool {
        revealedStates[photoId] ?? false
    }

    func isLiked(_ photoId: String) -> Bool {
        likedStates[photoId] ?? false
    }

    func setRevealed(_ photoId: String, _ value: Bool) {
        revealedStates[photoId] = value
    }

    func setLiked(_ photoId: String, _ value: Bool) {
        likedStates[photoId] = value
    }

    /// Load initial batch of photos with pagination
    func loadPhotos(eventId: String) async {
        currentEventId = eventId
        let supabaseManager = SupabaseManager.shared

        do {
            // Fetch first batch of photos
            let result = try await supabaseManager.fetchPhotosForRevealPaginated(
                eventId: eventId,
                offset: 0,
                limit: pageSize
            )

            photos = result.photos
            hasMorePhotos = result.hasMore
            currentOffset = result.photos.count

            // Load liked photos to mark them
            if let eventUUID = UUID(uuidString: eventId) {
                let likedPhotos = try await supabaseManager.getLikedPhotos(eventId: eventUUID)
                likedPhotoIds = Set(likedPhotos.map { $0.id })

                for photo in photos {
                    likedStates[photo.id] = likedPhotoIds.contains(photo.id)
                    if likedPhotoIds.contains(photo.id) {
                        revealedStates[photo.id] = true
                    }
                }
            }

            isLoading = false

            // Track reveal started
            AnalyticsManager.shared.track(.revealStarted, properties: [
                "event_id": eventId,
                "photos_to_reveal": photos.count
            ])
        } catch {
            print("❌ Failed to load photos: \(error)")
            isLoading = false
        }
    }

    /// Check if we need to load more photos based on current visible index
    func loadMoreIfNeeded(currentPhoto: PhotoData) {
        guard let index = photos.firstIndex(where: { $0.id == currentPhoto.id }) else { return }

        let remainingPhotos = photos.count - index - 1
        guard remainingPhotos <= prefetchThreshold else { return }
        guard hasMorePhotos && !isLoadingMore else { return }

        Task {
            await loadMorePhotos()
        }
    }

    /// Load next batch of photos
    private func loadMorePhotos() async {
        isLoadingMore = true
        defer { isLoadingMore = false }

        let supabaseManager = SupabaseManager.shared

        do {
            let result = try await supabaseManager.fetchPhotosForRevealPaginated(
                eventId: currentEventId,
                offset: currentOffset,
                limit: pageSize
            )

            // Apply liked states to new photos
            for photo in result.photos {
                likedStates[photo.id] = likedPhotoIds.contains(photo.id)
                if likedPhotoIds.contains(photo.id) {
                    revealedStates[photo.id] = true
                }
            }

            photos.append(contentsOf: result.photos)
            hasMorePhotos = result.hasMore
            currentOffset = photos.count

            print("📸 Loaded more photos. Total: \(photos.count), hasMore: \(hasMorePhotos)")
        } catch {
            print("❌ Failed to load more photos: \(error)")
        }
    }

    func saveLikedPhotos() async {
        let supabaseManager = SupabaseManager.shared

        for (photoId, isLiked) in likedStates {
            guard let photoUUID = UUID(uuidString: photoId) else { continue }

            if isLiked {
                try? await supabaseManager.setPhotoInteraction(photoId: photoUUID, status: .liked)
            }
        }
    }
}

/// Reveal flow phases
enum FeedRevealPhase {
    case preReveal      // Stats + "Reveal" button
    case viewing        // Photo feed
    case complete       // "That was the night."
}

// MARK: - Main View

struct FeedRevealView: View {
    let event: Event
    let onComplete: () -> Void

    @StateObject private var viewModel = FeedRevealViewModel()
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var flowPhase: FeedRevealPhase = .preReveal

    private var uniqueContributorCount: Int {
        Set(viewModel.photos.compactMap { $0.photographerName }).count
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.photos.isEmpty {
                emptyView
            } else {
                switch flowPhase {
                case .preReveal:
                    preRevealScreen
                        .transition(.opacity)

                case .viewing:
                    VStack(spacing: 0) {
                        progressHeader
                        scrollableFeed
                    }
                    .transition(.opacity)

                case .complete:
                    completeScreen
                        .transition(.opacity)
                }
            }
        }
        .task {
            await viewModel.loadPhotos(eventId: event.id)
        }
        .onDisappear {
            Task {
                await viewModel.saveLikedPhotos()
            }
        }
        .alert("Photo", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
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

    private var preRevealScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            // Stats
            VStack(spacing: 16) {
                Text("\(viewModel.photos.count) photos")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(uniqueContributorCount) people")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }

            // Ritual line
            Text("Revealed together at \(formatRevealTime(event.releaseAt))")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 8)

            Spacer()

            // Reveal button
            Button {
                HapticsManager.shared.soft()
                withAnimation(.easeInOut(duration: 0.5)) {
                    flowPhase = .viewing
                }
            } label: {
                Text("Reveal")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(width: 160, height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var completeScreen: some View {
        VStack(spacing: 40) {
            Spacer()

            // Closing message
            Text("That was the night.")
                .font(.system(size: 28, weight: .medium, design: .serif))
                .foregroundColor(.white)

            Spacer()

            // Actions
            VStack(spacing: 16) {
                Button {
                    Task {
                        await viewModel.saveLikedPhotos()
                        AnalyticsManager.shared.track(.revealCompleted, properties: [
                            "event_id": event.id,
                            "photos_revealed": viewModel.photos.count,
                            "photos_liked": viewModel.likedCount
                        ])
                        onComplete()
                    }
                } label: {
                    Text("View Liked Photos")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatRevealTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }

    private var progressHeader: some View {
        HStack {
            // Show current position out of total event photos
            Text("\(viewModel.visiblePhotoIndex + 1) of \(event.photosTaken)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(viewModel.likedCount) liked")
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }

    private var scrollableFeed: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(viewModel.photos.indices, id: \.self) { index in
                    let photo = viewModel.photos[index]
                    RevealCardView(
                        photo: photo,
                        isRevealed: Binding(
                            get: { viewModel.isRevealed(photo.id) },
                            set: { viewModel.setRevealed(photo.id, $0) }
                        ),
                        isLiked: Binding(
                            get: { viewModel.isLiked(photo.id) },
                            set: { viewModel.setLiked(photo.id, $0) }
                        ),
                        onDownload: { downloadPhoto(photo) }
                    )
                    .onAppear {
                        viewModel.visiblePhotoIndex = index
                        // Trigger prefetch when nearing end of loaded photos
                        viewModel.loadMoreIfNeeded(currentPhoto: photo)
                    }
                }

                // Loading indicator when fetching more
                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 20)
                }

                completionSection
                    .padding(.top, 24)
                    .padding(.bottom, 48)
            }
            .padding(.vertical, 16)
        }
    }

    private var completionSection: some View {
        VStack(spacing: 20) {
            Text("End of photos")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))

            Text("\(viewModel.likedCount) photos liked")
                .foregroundColor(.white.opacity(0.7))

            Button {
                HapticsManager.shared.celebration()
                withAnimation(.easeInOut(duration: 0.5)) {
                    flowPhase = .complete
                }
            } label: {
                Text("Finish")
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

    // MARK: - Actions

    private func downloadPhoto(_ photo: PhotoData) {
        guard let url = photo.url else { return }

        Task {
            do {
                // Download fresh from URL (same pattern as LikedGalleryView)
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    print("❌ Failed to create image from data")
                    return
                }

                // Request permission
                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    await MainActor.run {
                        saveAlertMessage = "Please allow photo access in Settings"
                        showingSaveAlert = true
                    }
                    return
                }

                // Save to camera roll
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }

                await MainActor.run {
                    HapticsManager.shared.success()
                    saveAlertMessage = "Saved to camera roll"
                    showingSaveAlert = true

                    // Track photo download
                    AnalyticsManager.shared.track(.photoDownloaded, properties: [
                        "event_id": event.id,
                        "has_watermark": true
                    ])
                }
            } catch {
                await MainActor.run {
                    saveAlertMessage = "Failed to save photo"
                    showingSaveAlert = true
                }
            }
        }
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
