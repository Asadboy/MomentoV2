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

            // Track reveal started
            AnalyticsManager.shared.track(.revealStarted, properties: [
                "event_id": eventId,
                "photos_to_reveal": photos.count
            ])
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
    @State private var stackVisible = false
    @State private var statsVisible = false

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
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 32)

                // Polaroid stack hero — souvenirs from the night
                PolaroidStack(urls: stackUrls)
                    .frame(height: 200)
                    .scaleEffect(stackVisible ? 1.0 : 0.7)
                    .opacity(stackVisible ? 1.0 : 0.0)
                    .offset(y: stackVisible ? 0 : -50)

                // Event name caption
                Text(event.name)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.5)
                    .foregroundColor(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .opacity(statsVisible ? 1.0 : 0.0)

                // Big stats — end-of-round results
                HStack(spacing: 0) {
                    bigStat(value: viewModel.photos.count, label: "Shots")
                    bigStat(value: viewModel.likedCount, label: "Liked")
                    bigStat(value: uniqueContributorCount, label: "People")
                }
                .padding(.horizontal, 24)
                .opacity(statsVisible ? 1.0 : 0.0)
                .offset(y: statsVisible ? 0 : 24)

                Spacer(minLength: 16)

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

                    if let code = event.joinCode {
                        ShareLink(
                            item: URL(string: "https://yourmomento.app/album/\(code)")!,
                            subject: Text(event.name),
                            message: Text("Check out the shots from \(event.name)!")
                        ) {
                            Text("Share album")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .opacity(statsVisible ? 1.0 : 0.0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            stackVisible = false
            statsVisible = false
            withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(0.1)) {
                stackVisible = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.45)) {
                statsVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                HapticsManager.shared.celebration()
            }
        }
    }

    /// Pick three photos from across the event for the polaroid stack —
    /// first, middle, last so the stack feels like the arc of the night.
    private var stackUrls: [URL] {
        let urls = viewModel.photos.compactMap { $0.url }
        guard urls.count >= 3 else { return urls }
        return [urls[0], urls[urls.count / 2], urls[urls.count - 1]]
    }

    private func bigStat(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .kerning(-1)

            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1.8)
        }
        .frame(maxWidth: .infinity)
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

            // Photo counter
            Text("\(currentPhotoIndex + 1) / \(event.photoCount)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            // Skip to end
            Button {
                HapticsManager.shared.light()
                withAnimation(.easeInOut(duration: 0.4)) {
                    flowPhase = .complete
                }
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
        completeScreen
    }

    private var completionSection: some View {
        VStack(spacing: 20) {
            Text("End of shots")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))

            Text("\(viewModel.likedCount) shots liked")
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
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 32)
    }

}

// MARK: - Polaroid Stack

/// A loose stack of polaroid souvenirs — the photographic prize at the end
/// of a 10shots party. Three photos fanned with chaotic rotations.
private struct PolaroidStack: View {
    let urls: [URL]

    var body: some View {
        ZStack {
            // Back-most card
            if urls.count >= 3 {
                PolaroidCard(url: urls[2])
                    .rotationEffect(.degrees(13))
                    .offset(x: 52, y: 14)
                    .zIndex(0)
            }
            // Middle card
            if urls.count >= 2 {
                PolaroidCard(url: urls[1])
                    .rotationEffect(.degrees(-15))
                    .offset(x: -54, y: 6)
                    .zIndex(1)
            }
            // Front card
            if !urls.isEmpty {
                PolaroidCard(url: urls[0])
                    .rotationEffect(.degrees(-3))
                    .zIndex(2)
            }
        }
    }
}

private struct PolaroidCard: View {
    let url: URL

    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.25))
                }
            }
            .frame(width: 124, height: 124)
            .clipped()
            .padding(.top, 9)
            .padding(.horizontal, 9)

            Spacer(minLength: 0)
        }
        .frame(width: 142, height: 178)
        .background(Color.white)
        .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 9)
        .task {
            if image == nil {
                image = await ImageCacheManager.shared.image(for: url)
            }
        }
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
