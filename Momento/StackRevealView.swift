//
//  StackRevealView.swift
//  Momento
//
//  Tinder-style swipe reveal for event photos.
//  Swipe right to like, left to archive.
//

import SwiftUI

struct StackRevealView: View {
    let event: Event
    let onComplete: () -> Void

    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var photos: [PhotoData] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading = true
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0

    // Swipe threshold
    private let swipeThreshold: CGFloat = 100

    // Colors
    private let likeColor = Color.green.opacity(0.8)
    private let archiveColor = Color.gray.opacity(0.6)

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.08, green: 0.06, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoading {
                loadingView
            } else if photos.isEmpty {
                emptyView
            } else if currentIndex >= photos.count {
                // All done - should transition to gallery
                completedView
            } else {
                VStack(spacing: 0) {
                    // Header with progress
                    headerView

                    Spacer()

                    // Card stack
                    cardStack

                    Spacer()

                    // Swipe hints
                    swipeHints
                }
            }
        }
        .task {
            await loadPhotosAndProgress()
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

    private var completedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("All done!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("You've swiped through all \(photos.count) photos")
                .foregroundColor(.white.opacity(0.7))

            Button {
                onComplete()
            } label: {
                Text("View Your Photos")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.5, green: 0.0, blue: 0.8))
                    .cornerRadius(12)
            }
            .padding(.top, 16)
        }
        .onAppear {
            // Mark as completed
            Task {
                guard let eventUUID = UUID(uuidString: event.id) else { return }
                try? await supabaseManager.updateRevealProgress(
                    eventId: eventUUID,
                    lastPhotoIndex: photos.count,
                    completed: true
                )
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text(event.title)
                .font(.headline)
                .foregroundColor(.white)

            // Progress indicator
            HStack(spacing: 8) {
                Text("\(currentIndex + 1)")
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                ProgressView(value: Double(currentIndex + 1), total: Double(photos.count))
                    .tint(Color(red: 0.5, green: 0.0, blue: 0.8))
                    .frame(width: 120)

                Text("\(photos.count)")
                    .foregroundColor(.white.opacity(0.6))
            }
            .font(.subheadline)
        }
        .padding(.top, 16)
    }

    private var cardStack: some View {
        ZStack {
            // Show 3 cards: current + 2 behind
            ForEach(Array(visibleCards.enumerated().reversed()), id: \.element.id) { offset, photo in
                PhotoCard(
                    photo: photo,
                    isTop: offset == 0
                )
                .scaleEffect(cardScale(for: offset))
                .offset(y: cardOffset(for: offset))
                .offset(x: offset == 0 ? dragOffset.width : 0)
                .rotationEffect(.degrees(offset == 0 ? dragRotation : 0))
                .overlay(
                    // Like/Archive overlay on top card
                    Group {
                        if offset == 0 {
                            swipeOverlay
                        }
                    }
                )
                .gesture(
                    offset == 0 ? dragGesture : nil
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: dragOffset)
            }
        }
        .padding(.horizontal, 20)
    }

    private var visibleCards: [PhotoData] {
        let endIndex = min(currentIndex + 3, photos.count)
        guard currentIndex < photos.count else { return [] }
        return Array(photos[currentIndex..<endIndex])
    }

    private var swipeOverlay: some View {
        ZStack {
            // Like overlay (right swipe)
            RoundedRectangle(cornerRadius: 20)
                .fill(likeColor)
                .opacity(dragOffset.width > 0 ? min(dragOffset.width / swipeThreshold, 1) * 0.5 : 0)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                        .opacity(dragOffset.width > 0 ? min(dragOffset.width / swipeThreshold, 1) : 0)
                )

            // Archive overlay (left swipe)
            RoundedRectangle(cornerRadius: 20)
                .fill(archiveColor)
                .opacity(dragOffset.width < 0 ? min(-dragOffset.width / swipeThreshold, 1) * 0.5 : 0)
                .overlay(
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                        .opacity(dragOffset.width < 0 ? min(-dragOffset.width / swipeThreshold, 1) : 0)
                )
        }
    }

    private var swipeHints: some View {
        HStack(spacing: 60) {
            VStack(spacing: 4) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                Text("Archive")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.5))

            VStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .medium))
                Text("Like")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(.bottom, 32)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                dragRotation = Double(value.translation.width / 20)
            }
            .onEnded { value in
                let width = value.translation.width

                if width > swipeThreshold {
                    // Swipe right - Like
                    swipeRight()
                } else if width < -swipeThreshold {
                    // Swipe left - Archive
                    swipeLeft()
                } else {
                    // Reset
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = .zero
                        dragRotation = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func swipeRight() {
        guard currentIndex < photos.count else { return }
        let photo = photos[currentIndex]

        // Haptic
        HapticsManager.shared.light()

        // Animate off screen
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: 500, height: 0)
        }

        // Save interaction and advance
        Task {
            guard let photoUUID = UUID(uuidString: photo.id) else { return }
            try? await supabaseManager.setPhotoInteraction(photoId: photoUUID, status: .liked)

            await MainActor.run {
                advanceToNext()
            }
        }
    }

    private func swipeLeft() {
        guard currentIndex < photos.count else { return }
        let photo = photos[currentIndex]

        // Haptic
        HapticsManager.shared.light()

        // Animate off screen
        withAnimation(.easeOut(duration: 0.3)) {
            dragOffset = CGSize(width: -500, height: 0)
        }

        // Save interaction and advance
        Task {
            guard let photoUUID = UUID(uuidString: photo.id) else { return }
            try? await supabaseManager.setPhotoInteraction(photoId: photoUUID, status: .archived)

            await MainActor.run {
                advanceToNext()
            }
        }
    }

    private func advanceToNext() {
        // Reset drag state
        dragOffset = .zero
        dragRotation = 0

        // Advance index
        currentIndex += 1

        // Save progress (debounced - every 5 photos or on completion)
        if currentIndex % 5 == 0 || currentIndex >= photos.count {
            Task {
                guard let eventUUID = UUID(uuidString: event.id) else { return }
                try? await supabaseManager.updateRevealProgress(
                    eventId: eventUUID,
                    lastPhotoIndex: currentIndex,
                    completed: currentIndex >= photos.count
                )
            }
        }
    }

    // MARK: - Helpers

    private func cardScale(for offset: Int) -> CGFloat {
        1.0 - CGFloat(offset) * 0.05
    }

    private func cardOffset(for offset: Int) -> CGFloat {
        CGFloat(offset) * 10
    }

    private func loadPhotosAndProgress() async {
        guard let eventUUID = UUID(uuidString: event.id) else {
            isLoading = false
            return
        }

        do {
            // Load all photos for the event
            let loadedPhotos = try await supabaseManager.getPhotos(for: event.id)

            // Check for existing progress
            if let progress = try await supabaseManager.getRevealProgress(eventId: eventUUID) {
                await MainActor.run {
                    photos = loadedPhotos
                    currentIndex = progress.lastPhotoIndex
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    photos = loadedPhotos
                    currentIndex = 0
                    isLoading = false
                }
            }
        } catch {
            print("❌ Failed to load photos: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Photo Card

struct PhotoCard: View {
    let photo: PhotoData
    let isTop: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Photo
            AsyncImage(url: photo.url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                        .overlay(ProgressView().tint(.white))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.5))
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.height * 0.55)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Datetime stamp (film aesthetic)
            if isTop {
                dateTimeStamp
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }

    private var dateTimeStamp: some View {
        Text(formatFilmDate(photo.capturedAt))
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.21)) // Warm orange #FF6B35
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(6)
            .padding(16)
    }

    private func formatFilmDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy  HH:mm"
        return formatter.string(from: date).uppercased()
    }
}

#Preview {
    let event = Event(
        title: "Test Event",
        coverEmoji: "🎉",
        startsAt: Date().addingTimeInterval(-86400),
        endsAt: Date().addingTimeInterval(-43200),
        releaseAt: Date().addingTimeInterval(-3600),
        memberCount: 5,
        photosTaken: 10,
        joinCode: "TEST"
    )

    return StackRevealView(event: event, onComplete: {})
}
