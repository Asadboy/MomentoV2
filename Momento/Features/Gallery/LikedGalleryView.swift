//
//  LikedGalleryView.swift
//  Momento
//
//  Unified gallery view for an event's photos.
//  Shows event info header, stats, share button, and 2-column photo grid.
//

import SwiftUI
import Photos

struct LikedGalleryView: View {
    let event: Event
    var onReReveal: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var allPhotos: [PhotoData] = []
    @State private var likedPhotos: [PhotoData] = []
    @State private var totalLikes: Int = 0
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePhotos = true
    @State private var currentOffset = 0
    @State private var selectedPhoto: PhotoData?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var activeFilter: GalleryFilter = .all

    private let pageSize = 12

    private enum GalleryFilter {
        case all, liked
    }

    private var displayedPhotos: [PhotoData] {
        activeFilter == .all ? allPhotos : likedPhotos
    }

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header
                headerView

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if allPhotos.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Stats row
                            statsRow

                            // Share button
                            if let code = event.joinCode {
                                shareButton(code: code)
                            }

                            // Divider
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 16)

                            // Filter tabs
                            filterTabs

                            // Photo grid
                            photoGrid
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadPhotos()
        }
        .sheet(item: $selectedPhoto) { photo in
            GalleryDetailView(
                photo: photo,
                eventId: event.id,
                onSave: { saveToPhotos(photo) }
            )
        }
        .alert("Photo Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Nav row
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }

                Spacer()

                // Re-reveal button hidden for now — logic kept in ContentView.reReveal()
            }

            // Event name
            Text(event.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            // Meta info
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("Ended")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.4))

                HStack(spacing: 6) {
                    Image(systemName: "person.2")
                        .font(.system(size: 12))
                    Text("\(event.memberCount) joined")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(event.photoCount)",
                label: "Photos",
                icon: "photo"
            )

            statItem(
                value: "\(totalLikes)",
                label: "Likes",
                icon: "heart.fill"
            )

            statItem(
                value: "\(event.memberCount)",
                label: "People",
                icon: "person.2"
            )
        }
        .padding(.horizontal, 16)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Share Button

    private func shareButton(code: String) -> some View {
        let albumURL = URL(string: "https://yourmomento.app/album/\(code)")!

        return ShareLink(
            item: albumURL,
            subject: Text(event.name),
            message: Text("Check out the shots from \(event.name)!")
        ) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                Text("Share album")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Photo Grid

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 24) {
            filterTab("All", count: event.photoCount, isActive: activeFilter == .all) {
                withAnimation(.easeInOut(duration: 0.2)) { activeFilter = .all }
            }
            filterTab("Liked", count: likedPhotos.count, isActive: activeFilter == .liked) {
                withAnimation(.easeInOut(duration: 0.2)) { activeFilter = .liked }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func filterTab(_ label: String, count: Int, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text("\(label) (\(count))")
                    .font(.system(size: 14, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? .white : .white.opacity(0.4))

                Rectangle()
                    .fill(isActive ? Color.white : Color.clear)
                    .frame(height: 1.5)
            }
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        Group {
            if displayedPhotos.isEmpty && activeFilter == .liked {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.25))
                    Text("No liked shots yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(displayedPhotos) { photo in
                        GalleryPhotoCell(photo: photo)
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                            .onAppear {
                                // Load more when near the end (All tab only — liked is loaded at once)
                                if activeFilter == .all,
                                   photo.id == allPhotos.last?.id,
                                   hasMorePhotos,
                                   !isLoadingMore {
                                    Task { await loadMorePhotos() }
                                }
                            }
                    }
                }
                .padding(.horizontal, 6)

                if isLoadingMore {
                    ProgressView()
                        .tint(.white.opacity(0.5))
                        .padding(.vertical, 16)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No shots yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadPhotos() async {
        guard let eventUUID = UUID(uuidString: event.id) else {
            isLoading = false
            return
        }

        do {
            // Load first page of all photos + liked photos + total likes in parallel
            async let firstPageResult = supabaseManager.fetchPhotosForRevealPaginated(
                eventId: event.id, offset: 0, limit: pageSize
            )
            async let likedResult = supabaseManager.getLikedPhotos(eventId: eventUUID)
            async let totalLikesResult = supabaseManager.getTotalLikeCount(eventId: eventUUID)

            let (firstPage, liked, likes) = try await (firstPageResult, likedResult, totalLikesResult)

            await MainActor.run {
                allPhotos = firstPage.photos
                hasMorePhotos = firstPage.hasMore
                currentOffset = firstPage.photos.count
                likedPhotos = liked
                totalLikes = likes
                isLoading = false
            }
        } catch {
            debugLog("❌ Failed to load gallery photos: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func loadMorePhotos() async {
        isLoadingMore = true

        do {
            let result = try await supabaseManager.fetchPhotosForRevealPaginated(
                eventId: event.id, offset: currentOffset, limit: pageSize
            )

            await MainActor.run {
                allPhotos.append(contentsOf: result.photos)
                hasMorePhotos = result.hasMore
                currentOffset = allPhotos.count
                isLoadingMore = false
            }
        } catch {
            debugLog("❌ Failed to load more photos: \(error)")
            await MainActor.run {
                isLoadingMore = false
            }
        }
    }

    // MARK: - Save to Photos

    private func saveToPhotos(_ photo: PhotoData) {
        guard let url = photo.url else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    throw NSError(domain: "Gallery", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image"])
                }

                let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                guard status == .authorized || status == .limited else {
                    await MainActor.run {
                        saveAlertMessage = "Please allow photo access in Settings"
                        showingSaveAlert = true
                    }
                    return
                }

                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }

                await MainActor.run {
                    HapticsManager.shared.success()
                    saveAlertMessage = "Saved to camera roll"
                    showingSaveAlert = true

                    AnalyticsManager.shared.track(.shotDownloaded, properties: [
                        "event_id": event.id,
                        "has_watermark": false
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
}

// MARK: - Gallery Photo Cell

private struct GalleryPhotoCell: View {
    let photo: PhotoData
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Photo
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minHeight: 200, maxHeight: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(white: 0.12))
                    .frame(minHeight: 200, maxHeight: 200)
                    .overlay(
                        ProgressView()
                            .tint(.white.opacity(0.3))
                    )
            }

            // Photographer name overlay
            if let name = photo.photographerName, !name.isEmpty {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 1)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: photo.id) {
            guard image == nil, let url = photo.url else { return }
            image = await ImageCacheManager.shared.image(for: url, cacheId: photo.id)
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

                VStack(spacing: 0) {
                    Spacer()

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
                                .foregroundColor(.white.opacity(0.3))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer()

                    // Photo info
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatFilmDate(photo.capturedAt))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))

                                if let photographer = photo.photographerName {
                                    Text("by \(photographer)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            Spacer()
                        }

                        // Action buttons
                        HStack(spacing: 12) {
                            Button {
                                onSave()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("Save")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                )
                            }

                            Button {
                                loadImageForSharing()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .medium))
                                    Text("Share")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                )
                            }

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
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
                AnalyticsManager.shared.track(.shotShared, properties: [
                    "event_id": eventId,
                    "destination": destination
                ])
            }
        }
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let event = Event(
        name: "Sopranos Party",
        startsAt: Date().addingTimeInterval(-86400),
        endsAt: Date().addingTimeInterval(-43200),
        releaseAt: Date().addingTimeInterval(-3600),
        memberCount: 5,
        joinCode: "TEST"
    )

    return LikedGalleryView(event: event)
}
