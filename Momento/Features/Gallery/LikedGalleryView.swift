//
//  LikedGalleryView.swift
//  Momento
//
//  Gallery view showing liked and archived photos with download functionality.
//

import SwiftUI
import Photos

enum GalleryTab: String, CaseIterable {
    case liked = "Liked"
    case archive = "Archive"
}

struct LikedGalleryView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var selectedTab: GalleryTab = .liked
    @State private var likedPhotos: [PhotoData] = []
    @State private var archivedPhotos: [PhotoData] = []
    @State private var isLoading = true
    @State private var selectedPhoto: PhotoData?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var currentPhotos: [PhotoData] {
        selectedTab == .liked ? likedPhotos : archivedPhotos
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab picker
                    tabPicker

                    if isLoading {
                        loadingView
                    } else {
                        photoGridView
                    }
                }
            }
            .navigationTitle(event.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                GalleryDetailView(
                    photo: photo,
                    isArchived: selectedTab == .archive,
                    eventId: event.id,
                    onMoveToLiked: {
                        moveToLiked(photo)
                    },
                    onSave: {
                        saveToPhotos(photo)
                    }
                )
            }
            .alert("Photo Saved", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveAlertMessage)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadPhotos()
        }
    }

    // MARK: - Subviews

    private var tabPicker: some View {
        Picker("Gallery", selection: $selectedTab) {
            ForEach(GalleryTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.white)
            Spacer()
        }
    }

    private var photoGridView: some View {
        ScrollView {
            if currentPhotos.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(currentPhotos) { photo in
                        GalleryThumbnail(photo: photo, isArchive: selectedTab == .archive)
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                    }
                }
                .padding(.horizontal, 2)

                if selectedTab == .liked && !likedPhotos.isEmpty {
                    downloadAllButton
                        .padding(.vertical, 24)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedTab == .liked ? "heart.slash" : "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.4))

            Text(selectedTab == .liked ? "No liked photos yet" : "No archived photos")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))

            if selectedTab == .liked {
                Text("Swipe right on photos to like them")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var downloadAllButton: some View {
        Button {
            downloadAllPhotos()
        } label: {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("Download All (\(likedPhotos.count))")
            }
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(red: 0.5, green: 0.0, blue: 0.8))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func loadPhotos() async {
        guard let eventUUID = UUID(uuidString: event.id) else {
            isLoading = false
            return
        }

        do {
            async let liked = supabaseManager.getLikedPhotos(eventId: eventUUID)
            async let archived = supabaseManager.getArchivedPhotos(eventId: eventUUID)

            let (likedResult, archivedResult) = try await (liked, archived)

            await MainActor.run {
                likedPhotos = likedResult
                archivedPhotos = archivedResult
                isLoading = false
            }
        } catch {
            print("❌ Failed to load photos: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func moveToLiked(_ photo: PhotoData) {
        guard let photoUUID = UUID(uuidString: photo.id) else { return }

        Task {
            try? await supabaseManager.setPhotoInteraction(photoId: photoUUID, status: .liked)

            await MainActor.run {
                // Move from archived to liked
                archivedPhotos.removeAll { $0.id == photo.id }
                likedPhotos.append(photo)
                likedPhotos.sort { $0.capturedAt < $1.capturedAt }
                selectedPhoto = nil
            }
        }
    }

    private func saveToPhotos(_ photo: PhotoData) {
        guard let url = photo.url else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    throw NSError(domain: "LikedGalleryView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image"])
                }

                // Request photo library access
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
                    saveAlertMessage = "Failed to save: \(error.localizedDescription)"
                    showingSaveAlert = true
                }
            }
        }
    }

    private func downloadAllPhotos() {
        Task {
            var savedCount = 0

            // Request photo library access
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    saveAlertMessage = "Please allow photo access in Settings"
                    showingSaveAlert = true
                }
                return
            }

            for photo in likedPhotos {
                guard let url = photo.url else { continue }

                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let image = UIImage(data: data) else { continue }

                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }
                    savedCount += 1
                } catch {
                    print("❌ Failed to save photo: \(error)")
                }
            }

            await MainActor.run {
                HapticsManager.shared.success()
                saveAlertMessage = "Saved \(savedCount) of \(likedPhotos.count) photos"
                showingSaveAlert = true

                // Track each downloaded photo
                for _ in 0..<savedCount {
                    AnalyticsManager.shared.track(.photoDownloaded, properties: [
                        "event_id": event.id,
                        "has_watermark": true,
                        "source": "batch_download"
                    ])
                }
            }
        }
    }
}

// MARK: - Gallery Thumbnail

struct GalleryThumbnail: View {
    let photo: PhotoData
    let isArchive: Bool

    var body: some View {
        AsyncImage(url: photo.url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(ProgressView().tint(.white))
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .opacity(isArchive ? 0.5 : 1.0)
            case .failure:
                Rectangle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.3))
                    )
            @unknown default:
                EmptyView()
            }
        }
    }
}

// MARK: - Gallery Detail View

struct GalleryDetailView: View {
    let photo: PhotoData
    let isArchived: Bool
    let eventId: String
    let onMoveToLiked: () -> Void
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    // Photo
                    AsyncImage(url: photo.url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().tint(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.5))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Photo info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatFilmDate(photo.capturedAt))
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.21))

                            if let photographer = photo.photographerName {
                                Text("by \(photographer)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        Spacer()
                    }
                    .padding()

                    // Action buttons
                    HStack(spacing: 24) {
                        if isArchived {
                            Button {
                                onMoveToLiked()
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 24))
                                    Text("Like")
                                        .font(.caption)
                                }
                                .foregroundColor(.white)
                                .frame(width: 80)
                            }
                        }

                        Button {
                            onSave()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 24))
                                Text("Save")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(width: 80)
                        }

                        Button {
                            loadImageForSharing()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 24))
                                Text("Share")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(width: 80)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.title2)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                PhotoShareSheet(image: image, eventId: eventId)
            }
        }
    }

    private func loadImageForSharing() {
        guard let url = photo.url else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }

                await MainActor.run {
                    shareImage = image
                    showShareSheet = true
                }
            } catch {
                print("Failed to load image for sharing: \(error)")
            }
        }
    }

    private func formatFilmDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy  HH:mm"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Photo Share Sheet

struct PhotoShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let eventId: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { activityType, completed, _, _ in
            if completed {
                let destination = AnalyticsManager.mapActivityToDestination(activityType)
                AnalyticsManager.shared.track(.photoShared, properties: [
                    "event_id": eventId,
                    "destination": destination,
                    "has_watermark": true
                ])
            }
        }
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let event = Event(
        name: "Test Event",
        coverEmoji: "🎉",
        startsAt: Date().addingTimeInterval(-86400),
        endsAt: Date().addingTimeInterval(-43200),
        releaseAt: Date().addingTimeInterval(-3600),
        joinCode: "TEST"
    )

    return LikedGalleryView(event: event)
}
