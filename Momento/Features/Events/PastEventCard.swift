//
//  PastEventCard.swift
//  Momento
//
//  Photo album card for past events (processing, revealed).
//  Revealed events show a thumbnail strip of liked photos.
//  Processing events show shimmer placeholders with countdown.
//

import SwiftUI

struct PastEventCard: View {
    let event: Event
    let now: Date
    var photos: [PhotoData] = []
    var totalPhotoCount: Int = 0
    let onTap: () -> Void
    let onLongPress: () -> Void

    // MARK: - State

    private var isProcessing: Bool {
        event.currentState(at: now) == .processing
    }

    private var secondsUntilReveal: Int {
        max(0, Int(event.releaseAt.timeIntervalSince(now)))
    }

    private var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: event.endsAt)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: event name + date/countdown
            HStack {
                Text(event.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                if isProcessing {
                    Text("reveals in \(formatRevealTime())")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange.opacity(0.7))
                } else {
                    Text(shortDate)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Photo strip or shimmer placeholders
            if isProcessing {
                processingStrip
            } else {
                revealedStrip
            }
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

    // MARK: - Revealed Photo Strip

    @ViewBuilder
    private var revealedStrip: some View {
        if photos.isEmpty {
            // Fallback: no liked photos
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

    // MARK: - Processing Shimmer Strip

    private var processingStrip: some View {
        ZStack(alignment: .center) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { _ in
                    ShimmerPlaceholder()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer()
            }

            Text("DEVELOPING")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                )
        }
    }

    // MARK: - Time Formatting

    private func formatRevealTime() -> String {
        let hours = secondsUntilReveal / 3600
        let minutes = (secondsUntilReveal % 3600) / 60

        if hours >= 24 {
            return "\(hours / 24)d"
        } else if hours >= 1 {
            return "\(hours)h"
        } else if minutes >= 1 {
            return "\(minutes)m"
        } else {
            return "any moment"
        }
    }
}

// MARK: - Cached Thumbnail

/// Loads a photo thumbnail using ImageCacheManager (memory + disk),
/// keyed by photo ID so signed URL rotation doesn't bust the cache.
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

// MARK: - Shimmer Placeholder

private struct ShimmerPlaceholder: View {
    @State private var opacity: Double = 0.08

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(opacity))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 0.15
                }
            }
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    ScrollView {
        VStack(spacing: 8) {
            // Processing event
            PastEventCard(
                event: Event(
                    name: "Weekend Getaway",
                    coverEmoji: "\u{1F3D6}",
                    startsAt: now.addingTimeInterval(-3600 * 26),
                    endsAt: now.addingTimeInterval(-3600 * 2),
                    releaseAt: now.addingTimeInterval(3600 * 22)
                ),
                now: now,
                onTap: {},
                onLongPress: {}
            )

            // Revealed with no photos
            PastEventCard(
                event: Event(
                    name: "Sarah's Graduation",
                    coverEmoji: "\u{1F393}",
                    startsAt: now.addingTimeInterval(-3600 * 72),
                    endsAt: now.addingTimeInterval(-3600 * 48),
                    releaseAt: now.addingTimeInterval(-3600 * 1)
                ),
                now: now,
                onTap: {},
                onLongPress: {}
            )

            // Revealed with photos (mock)
            PastEventCard(
                event: Event(
                    name: "Summer BBQ",
                    coverEmoji: "\u{1F356}",
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
