//
//  EventsScreenPreview.swift
//  Momento
//
//  Full-screen preview of the Featured + List events screen.
//  Active events (live/upcoming) as large cards, past events as compact rows.
//

import SwiftUI

#if DEBUG

// MARK: - Full Events Screen Preview

/// Mock of the full events screen layout for Xcode preview
private struct EventsScreenPreviewContent: View {
    private let now = Date()

    // Sample events covering every state
    private var liveEvent: Event {
        Event(
            name: "Joe's 26th Birthday",
            coverEmoji: "\u{1F382}",
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(3600 * 5),
            releaseAt: now.addingTimeInterval(3600 * 29),
            memberCount: 12,
            photoCount: 3,
            joinCode: "JOE26"
        )
    }

    private var upcomingEvent: Event {
        Event(
            name: "NYE House Party",
            coverEmoji: "\u{1F389}",
            startsAt: now.addingTimeInterval(3600 * 8),
            endsAt: now.addingTimeInterval(3600 * 16),
            releaseAt: now.addingTimeInterval(3600 * 40),
            memberCount: 8,
            photoCount: 0,
            joinCode: "NYE24"
        )
    }

    private var processingEvent: Event {
        Event(
            name: "Weekend Getaway",
            coverEmoji: "\u{1F3D6}",
            startsAt: now.addingTimeInterval(-3600 * 26),
            endsAt: now.addingTimeInterval(-3600 * 2),
            releaseAt: now.addingTimeInterval(3600 * 22),
            memberCount: 6,
            photoCount: 18,
            joinCode: "WKND"
        )
    }

    private var readyToRevealEvent: Event {
        Event(
            name: "Sarah's Graduation",
            coverEmoji: "\u{1F393}",
            startsAt: now.addingTimeInterval(-3600 * 72),
            endsAt: now.addingTimeInterval(-3600 * 48),
            releaseAt: now.addingTimeInterval(-3600 * 1),
            memberCount: 15,
            photoCount: 42,
            joinCode: "GRAD"
        )
    }

    private var revealedEvent: Event {
        Event(
            name: "Summer BBQ",
            coverEmoji: "\u{1F356}",
            startsAt: now.addingTimeInterval(-3600 * 168),
            endsAt: now.addingTimeInterval(-3600 * 144),
            releaseAt: now.addingTimeInterval(-3600 * 120),
            memberCount: 20,
            photoCount: 67,
            joinCode: "BBQ23"
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (pinned)
                HStack {
                    Text("Momento")
                        .font(.custom("RalewayDots-Regular", size: 32))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white.opacity(0.6))

                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Scrollable content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // MARK: Active Events — Featured Cards
                        HStack {
                            Text("CURRENT EVENTS")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.4))

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("New")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }

                        // Live event with camera hint
                        VStack(spacing: 6) {
                            PremiumEventCard(
                                event: liveEvent,
                                now: now,
                                memberCount: 12,
                                userPhotoCount: 3,
                                totalPhotoCount: 8,
                                onTap: {},
                                onLongPress: {}
                            )
                            Text("Tap card to open camera")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }

                        // Upcoming event
                        PremiumEventCard(
                            event: upcomingEvent,
                            now: now,
                            memberCount: 8,
                            onTap: {},
                            onLongPress: {}
                        )

                        // MARK: Past Events — Compact Rows
                        HStack {
                            Text("PAST MOMENTOS")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.4))

                            Spacer()
                        }
                        .padding(.top, 8)

                        // Processing (shimmer placeholders)
                        PastEventCard(
                            event: processingEvent,
                            now: now,
                            onTap: {},
                            onLongPress: {}
                        )

                        // Ready to reveal (no photos yet)
                        PastEventCard(
                            event: readyToRevealEvent,
                            now: now,
                            onTap: {},
                            onLongPress: {}
                        )

                        // Revealed with mock photos
                        PastEventCard(
                            event: revealedEvent,
                            now: now,
                            photos: [
                                PhotoData(id: "1", url: nil, capturedAt: now, photographerName: nil),
                                PhotoData(id: "2", url: nil, capturedAt: now, photographerName: nil),
                                PhotoData(id: "3", url: nil, capturedAt: now, photographerName: nil),
                                PhotoData(id: "4", url: nil, capturedAt: now, photographerName: nil),
                            ],
                            totalPhotoCount: 67,
                            onTap: {},
                            onLongPress: {}
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Events Screen — Featured + List") {
    EventsScreenPreviewContent()
}

#Preview("Live Card Only") {
    let now = Date()
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 6) {
            PremiumEventCard(
                event: Event(
                    name: "Joe's 26th Birthday",
                    coverEmoji: "\u{1F382}",
                    startsAt: now.addingTimeInterval(-3600),
                    endsAt: now.addingTimeInterval(3600 * 5),
                    releaseAt: now.addingTimeInterval(3600 * 29),
                    memberCount: 12,
                    photoCount: 3
                ),
                now: now,
                memberCount: 12,
                userPhotoCount: 3,
                totalPhotoCount: 8,
                onTap: {},
                onLongPress: {}
            )
            Text("Tap card to open camera")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(16)
    }
}

#Preview("Past Event Cards Only") {
    let now = Date()
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 8) {
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
                totalPhotoCount: 14,
                onTap: {},
                onLongPress: {}
            )
        }
        .padding(16)
    }
}

#endif
