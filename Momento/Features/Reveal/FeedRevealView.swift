//
//  FeedRevealView.swift
//  Momento
//
//  Vertical scroll feed for photo reveal.
//  Replaces StackRevealView (Tinder-style swipes).
//

import SwiftUI

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

            // Track reveal started — snapshot final event scale so PostHog can compute
            // avg event size and avg shots/person without joining tables.
            var revealProps: [String: Any] = [
                "event_id": eventId,
                "photos_to_reveal": photos.count,
                "total_shots": photos.count
            ]
            if let eventUUID = UUID(uuidString: eventId),
               let memberCount = try? await supabaseManager.getEventMemberCount(eventId: eventUUID) {
                revealProps["member_count"] = memberCount
                if memberCount > 0 {
                    revealProps["avg_shots_per_person"] = Double(photos.count) / Double(memberCount)
                }
            }
            AnalyticsManager.shared.track(.revealStarted, properties: revealProps)
        } catch {
            debugLog("❌ Failed to load photos: \(error)")
            isLoading = false
        }
    }

    /// Check if we need to load more photos based on current visible index
    func loadMoreIfNeeded(currentPhoto: PhotoData) {
        guard let index = photos.firstIndex(where: { $0.id == currentPhoto.id }) else { return }

        let remainingPhotos = photos.count - index - 1
        guard remainingPhotos <= prefetchThreshold else { return }
        guard hasMorePhotos && !isLoadingMore else { return }

        // Set flag synchronously to prevent duplicate calls from rapid scrolling
        isLoadingMore = true
        Task {
            await loadMorePhotos()
        }
    }

    /// Load next batch of photos
    private func loadMorePhotos() async {
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

            debugLog("📸 Loaded more photos. Total: \(photos.count), hasMore: \(hasMorePhotos)")
        } catch {
            debugLog("❌ Failed to load more photos: \(error)")
        }
    }

    func saveLikedPhotos() async {
        let supabaseManager = SupabaseManager.shared

        for (photoId, isLiked) in likedStates {
            guard let photoUUID = UUID(uuidString: photoId) else { continue }

            do {
                if isLiked {
                    try await supabaseManager.likePhoto(photoId: photoUUID)
                } else {
                    try await supabaseManager.unlikePhoto(photoId: photoUUID)
                }
            } catch {
                debugLog("❌ Failed to \(isLiked ? "like" : "unlike") photo: \(error)")
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

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FeedRevealViewModel()
    @State private var flowPhase: FeedRevealPhase = .preReveal
    @State private var currentPhotoIndex = 0
    @State private var isScrollLocked = false
    @State private var showExitConfirmation = false
    @State private var showSkipConfirmation = false

    /// Distinct contributor count by photographer name. Best-effort —
    /// two real people with the same display name would be undercounted,
    /// and unknowns ("Unknown" fallback for legacy rows) collapse to one.
    /// At launch scale (5-15 person events) the false-undercount edge is
    /// rare; review M19's user-id-based dedup would need a denormalised
    /// user_id column on PhotoData, deferred.
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
                        pagedPhotoView
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
            // Mark as complete if user entered the reveal (viewed or skipped)
            if flowPhase == .viewing || flowPhase == .complete {
                RevealStateManager.shared.markRevealCompleted(for: event.id)
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Loading shots...")
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
            Text("No shots to reveal")
                .font(.title2)
                .foregroundColor(.white)
        }
    }

    private var preRevealScreen: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Hero: photo count
                VStack(spacing: 8) {
                    Text("\(viewModel.photos.count)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)

                    Text("shots waiting")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer().frame(height: 24)

                // Event info
                VStack(spacing: 6) {
                    Text(event.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text("\(event.memberCount) people contributed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }

                Spacer()

                // Reveal button with pulsing glow
                Button {
                    HapticsManager.shared.soft()
                    withAnimation(.easeInOut(duration: 0.5)) {
                        flowPhase = .viewing
                    }
                } label: {
                    Text("Reveal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 180, height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                }
                .padding(.bottom, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var completeScreen: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Title
                VStack(spacing: 12) {
                    Text("That was the night.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text(event.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Stats
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("\(viewModel.photos.count)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("Shots")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(viewModel.likedCount)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("Liked")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(uniqueContributorCount)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("People")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Buttons
                VStack(spacing: 14) {
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
                        Text("View Liked Shots")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                    }

                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
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
            // Close button
            Button {
                showExitConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, height: 32)
            }

            Spacer()

            // Photo counter. Uses the loaded photos count rather than
            // event.photoCount because the latter is client-side
            // hydrated and can race with delayed uploads from other
            // members (review M20): you'd see "3 / 8" even though the
            // feed has 10 photos loaded.
            Text("\(currentPhotoIndex + 1) / \(viewModel.photos.count)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            // Skip to end
            Button {
                showSkipConfirmation = true
            } label: {
                Text("Skip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .confirmationDialog("Leave reveal?", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                Task {
                    await viewModel.saveLikedPhotos()
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your liked shots will be saved, but you'll need to reveal again to continue.")
        }
        // Skip confirmation (review H24). Tapping Skip used to jump to
        // .complete which on dismiss marked the reveal completed
        // *forever*. A miss-tap permanently locked the user out of the
        // reveal. Now the user has to confirm the irreversible action.
        .confirmationDialog("Skip to the end?", isPresented: $showSkipConfirmation, titleVisibility: .visible) {
            Button("Skip", role: .destructive) {
                HapticsManager.shared.light()
                withAnimation(.easeInOut(duration: 0.4)) {
                    flowPhase = .complete
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll see the rest of the shots in the gallery, but you can't replay the reveal animation later.")
        }
    }

    private var pagedPhotoView: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.photos.indices, id: \.self) { index in
                        let photo = viewModel.photos[index]
                        RevealCardView(
                            photo: photo,
                            eventId: event.id,
                            isRevealed: Binding(
                                get: { viewModel.isRevealed(photo.id) },
                                set: { viewModel.setRevealed(photo.id, $0) }
                            ),
                            isLiked: Binding(
                                get: { viewModel.isLiked(photo.id) },
                                set: { viewModel.setLiked(photo.id, $0) }
                            ),
                            onRevealStarted: { isScrollLocked = true },
                            onButtonsVisible: { isScrollLocked = false }
                        )
                        .frame(height: geometry.size.height)
                        .id(index)
                        .onAppear {
                            currentPhotoIndex = index
                            viewModel.visiblePhotoIndex = index
                            viewModel.loadMoreIfNeeded(currentPhoto: photo)
                        }
                    }

                    // Completion card at end
                    completionCard
                        .frame(height: geometry.size.height)

                }
            }
            .scrollDisabled(isScrollLocked)
            .scrollTargetBehavior(.paging)
        }
    }

    private var completionCard: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Title
                VStack(spacing: 12) {
                    Text("That was the night.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text(event.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                // Stats
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("\(viewModel.photos.count)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("Shots")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(viewModel.likedCount)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("Liked")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("\(uniqueContributorCount)")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text("People")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Buttons
                VStack(spacing: 14) {
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
                        Text("View Liked Shots")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                    }

                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

#Preview {
    let event = Event(
        name: "London Trip",
        startsAt: Date().addingTimeInterval(-86400),
        endsAt: Date().addingTimeInterval(-43200),
        releaseAt: Date().addingTimeInterval(-3600),
        joinCode: "LONDON"
    )

    return FeedRevealView(event: event, onComplete: {})
}
