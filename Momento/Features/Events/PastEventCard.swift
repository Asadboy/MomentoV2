//
//  PastEventCard.swift
//  Momento
//
//  Compact card for past events in the done pile.
//  Shows thumbnail strip of liked shots and event stats.
//

import SwiftUI

struct PastEventCard: View {
    let event: Event
    let now: Date
    var photos: [PhotoData] = []
    var totalPhotoCount: Int = 0
    var totalLikeCount: Int = 0
    var memberCount: Int = 0
    let onTap: () -> Void
    let onLongPress: () -> Void

    private var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: event.endsAt)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: event name + date
            HStack {
                Text(event.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text(shortDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Stats line
            if totalPhotoCount > 0 || totalLikeCount > 0 {
                statsLine
            }

            // Photo strip
            revealedStrip
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress()
        }
    }

    // MARK: - Stats Line

    private var statsLine: some View {
        HStack(spacing: 12) {
            if totalPhotoCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                    Text("\(totalPhotoCount) shots")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.4))
            }

            if totalLikeCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("\(totalLikeCount) likes")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.4))
            }

            if memberCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text("\(memberCount) people")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Photo Strip

    @ViewBuilder
    private var revealedStrip: some View {
        if photos.isEmpty {
            HStack {
                Spacer()
                Text("Tap to relive")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            .frame(height: 64)
        } else {
            HStack(spacing: 4) {
                ForEach(Array(photos.prefix(maxPhotos).enumerated()), id: \.element.id) { _, photo in
                    photoThumbnail(photo)
                }

                if overflowCount > 0 {
                    overflowTile
                }

                Spacer()
            }
        }
    }

    private let maxPhotos = 4

    private var overflowCount: Int {
        max(0, totalPhotoCount - maxPhotos)
    }

    private func photoThumbnail(_ photo: PhotoData) -> some View {
        CachedThumbnail(photo: photo)
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var overflowTile: some View {
        ZStack {
            Color(white: 0.18)
            Text("+\(overflowCount)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Cached Thumbnail

private struct CachedThumbnail: View {
    let photo: PhotoData
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color(white: 0.15)
            }
        }
        .task(id: photo.id) {
            guard image == nil, let url = photo.url else { return }
            image = await ImageCacheManager.shared.image(for: url, cacheId: photo.id)
        }
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    ScrollView {
        VStack(spacing: 8) {
            // Revealed with no photos
            PastEventCard(
                event: Event(
                    name: "Sarah's Graduation",
                    startsAt: now.addingTimeInterval(-3600 * 72),
                    endsAt: now.addingTimeInterval(-3600 * 48),
                    releaseAt: now.addingTimeInterval(-3600 * 1)
                ),
                now: now,
                onTap: {},
                onLongPress: {}
            )

            // Revealed with photos
            PastEventCard(
                event: Event(
                    name: "Summer BBQ",
                    startsAt: now.addingTimeInterval(-3600 * 168),
                    endsAt: now.addingTimeInterval(-3600 * 144),
                    releaseAt: now.addingTimeInterval(-3600 * 120)
                ),
                now: now,
                photos: [
                    PhotoData(id: "1", url: nil, capturedAt: now, photographerName: nil),
                    PhotoData(id: "2", url: nil, capturedAt: now, photographerName: nil),
                    PhotoData(id: "3", url: nil, capturedAt: now, photographerName: nil),
                    PhotoData(id: "4", url: nil, capturedAt: now, photographerName: nil),
                ],
                totalPhotoCount: 15,
                onTap: {},
                onLongPress: {}
            )
        }
        .padding(16)
    }
    .background(Color.black)
}
