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

            debugLog("📸 Loaded more photos. Total: \(photos.count), hasMore: \(hasMorePhotos)")
        } catch {
            debugLog("❌ Failed to load more photos: \(error)")
        }
    }

    func saveLikedPhotos() async {
        let supabaseManager = SupabaseManager.shared

        for (photoId, isLiked) in likedStates {
            guard let photoUUID = UUID(uuidString: photoId) else { continue }

            if isLiked {
                try? await supabaseManager.likePhoto(photoId: photoUUID)
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
    @State private var isPurchasing = false
    @State private var flowPhase: FeedRevealPhase = .preReveal
    @State private var currentPhotoIndex = 0
    @State private var isScrollLocked = false

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
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.14),
                    Color(red: 0.03, green: 0.03, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Radial glow behind the reveal button area
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.2),
                    Color.blue.opacity(0.08),
                    Color.clear
                ],
                center: .init(x: 0.5, y: 0.65),
                startRadius: 30,
                endRadius: 250
            )

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Text(event.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Photos")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text("Revealed together at \(formatRevealTime(event.releaseAt))")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 8)

                Spacer()

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var completeScreen: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )

            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color.purple.opacity(0.6))

                Text("That was the night.")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundColor(.white)

                Spacer()

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
            // Show current position out of loaded photos
            Text("\(currentPhotoIndex + 1) of \(viewModel.photos.count)")
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

    private var pagedPhotoView: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.photos.indices, id: \.self) { index in
                        let photo = viewModel.photos[index]
                        RevealCardView(
                            photo: photo,
                            eventId: event.id,
                            isPremium: event.isPremium,
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

                    // Premium prompt card for hosts of free events
                    if !event.isPremium,
                       event.creatorId == SupabaseManager.shared.currentUser?.id.uuidString {
                        premiumPromptCard
                            .frame(height: geometry.size.height)
                    }
                }
            }
            .scrollDisabled(isScrollLocked)
            .scrollTargetBehavior(.paging)
        }
    }

    private var completionCard: some View {
        ZStack {
            // Gradient background matching app aesthetic
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle radial glow
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )

            VStack(spacing: 24) {
                Spacer()

                // Decorative icon
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color.purple.opacity(0.6))

                Text("That was the night.")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                    Text("\(viewModel.likedCount) photos liked")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))

                Spacer()

                Button {
                    HapticsManager.shared.celebration()
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
                .padding(.bottom, 40)
            }
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

    private var premiumPromptCard: some View {
        ZStack {
            // Consistent gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.12),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Soft ambient glow — same as completion card
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.12),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "infinity")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.bottom, 28)

                Text("Keep these photos forever")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "infinity", text: "No watermarks, no expiry")
                    featureRow(icon: "link", text: "Shareable web album for everyone")

                    if let days = daysUntilExpiry {
                        featureRow(icon: "clock", text: "Free photos expire in \(days) day\(days == 1 ? "" : "s")", dimmed: true)
                    }
                }
                .padding(.horizontal, 48)

                Spacer()

                VStack(spacing: 20) {
                    Button {
                        HapticsManager.shared.medium()
                        isPurchasing = true
                        Task {
                            do {
                                let success = try await PurchaseManager.shared.purchasePremium(for: event.id)
                                isPurchasing = false
                                if success {
                                    onComplete()
                                }
                            } catch {
                                isPurchasing = false
                            }
                        }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text("Keep forever — £7.99")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(27)
                    }
                    .disabled(isPurchasing)
                    .padding(.horizontal, 40)

                    Button {
                        Task {
                            await viewModel.saveLikedPhotos()
                            onComplete()
                        }
                    } label: {
                        Text("View liked photos")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .disabled(isPurchasing)
                }
                .padding(.bottom, 44)
            }
        }
    }

    private func featureRow(icon: String, text: String, dimmed: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(dimmed ? 0.2 : 0.3))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(dimmed ? 0.25 : 0.4))
            Spacer()
        }
    }

    private var daysUntilExpiry: Int? {
        guard let expiresAt = event.expiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day
        return days.flatMap { $0 > 0 ? $0 : nil }
    }

}

#Preview {
    let event = Event(
        name: "London Trip",
        coverEmoji: "🇬🇧",
        startsAt: Date().addingTimeInterval(-86400),
        endsAt: Date().addingTimeInterval(-43200),
        releaseAt: Date().addingTimeInterval(-3600),
        joinCode: "LONDON"
    )

    return FeedRevealView(event: event, onComplete: {})
}
