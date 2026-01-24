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
    @Published var visiblePhotoIndex: Int = 0

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

    func loadPhotos(eventId: String) async {
        let supabaseManager = SupabaseManager.shared

        do {
            let loadedPhotos = try await supabaseManager.getPhotos(for: eventId)

            guard let eventUUID = UUID(uuidString: eventId) else {
                photos = loadedPhotos
                isLoading = false
                return
            }

            let likedPhotos = try await supabaseManager.getLikedPhotos(eventId: eventUUID)
            let likedIds = Set(likedPhotos.map { $0.id })

            photos = loadedPhotos

            for photo in loadedPhotos {
                likedStates[photo.id] = likedIds.contains(photo.id)
                if likedIds.contains(photo.id) {
                    revealedStates[photo.id] = true
                }
            }

            isLoading = false
        } catch {
            print("❌ Failed to load photos: \(error)")
            isLoading = false
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

// MARK: - Main View

struct FeedRevealView: View {
    let event: Event
    let onComplete: () -> Void

    @StateObject private var viewModel = FeedRevealViewModel()
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if viewModel.photos.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    progressHeader
                    scrollableFeed
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

    private var progressHeader: some View {
        HStack {
            Text("\(viewModel.visiblePhotoIndex + 1) of \(viewModel.photos.count)")
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
                    }
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
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("You've seen all \(viewModel.photos.count) photos!")
                .font(.headline)
                .foregroundColor(.white)

            Text("\(viewModel.likedCount) photos liked")
                .foregroundColor(.white.opacity(0.7))

            Button {
                Task {
                    await viewModel.saveLikedPhotos()
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
