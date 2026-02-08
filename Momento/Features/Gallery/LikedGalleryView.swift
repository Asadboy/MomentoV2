//
//  LikedGalleryView.swift
//  Momento
//
//  Gallery view showing liked photos with download functionality.
//

import SwiftUI
import Photos

struct LikedGalleryView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss

    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var likedPhotos: [PhotoData] = []
    @State private var isLoading = true
    @State private var selectedPhoto: PhotoData?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
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
                    eventId: event.id,
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
            if likedPhotos.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(likedPhotos) { photo in
                        GalleryThumbnail(photo: photo)
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                    }
                }
                .padding(.horizontal, 2)

                downloadAllButton
                    .padding(.vertical, 24)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.4))

            Text("No liked photos yet")
                .font(.headline)
                .foregroundColor(.white.opacity(0.6))

            Text("Swipe right on photos to like them")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
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
            let result = try await supabaseManager.getLikedPhotos(eventId: eventUUID)

            await MainActor.run {
                likedPhotos = result
                isLoading = false
            }
        } catch {
            debugLog("❌ Failed to load photos: \(error)")
            await MainActor.run {
                isLoading = false
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

                // Apply watermark on free events
                let saveImage = event.isPremium ? image : WatermarkRenderer.apply(to: image)

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
                    PHAssetChangeRequest.creationRequestForAsset(from: saveImage)
                }

                await MainActor.run {
                    HapticsManager.shared.success()
                    saveAlertMessage = "Saved to camera roll"
                    showingSaveAlert = true

                    // Track photo download
                    AnalyticsManager.shared.track(.photoDownloaded, properties: [
                        "event_id": event.id,
                        "has_watermark": !event.isPremium
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

                    // Apply watermark on free events
                    let saveImage = event.isPremium ? image : WatermarkRenderer.apply(to: image)

                    try await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: saveImage)
                    }
                    savedCount += 1
                } catch {
                    debugLog("❌ Failed to save photo: \(error)")
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
                        "has_watermark": !event.isPremium,
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
    let eventId: String
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
                debugLog("Failed to load image for sharing: \(error)")
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
