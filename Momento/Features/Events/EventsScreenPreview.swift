//
//  EventsScreenPreview.swift
//  Momento
//
//  Full-screen preview of the redesigned events screen.
//  Shows all card states: Live, Upcoming, Processing, Ready to Reveal, Revealed.
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
            startsAt: now.addingTimeInterval(-3600),       // started 1h ago
            endsAt: now.addingTimeInterval(3600 * 5),      // ends in 5h
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
            startsAt: now.addingTimeInterval(3600 * 8),    // starts in 8h
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
            startsAt: now.addingTimeInterval(-3600 * 26),  // started 26h ago
            endsAt: now.addingTimeInterval(-3600 * 2),     // ended 2h ago
            releaseAt: now.addingTimeInterval(3600 * 22),  // reveals in 22h
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
            releaseAt: now.addingTimeInterval(-3600 * 1),  // revealed 1h ago
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
                // Header
                VStack(spacing: 16) {
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Cards
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Live event with camera hint
                        VStack(spacing: 6) {
                            PremiumEventCard(
                                event: liveEvent,
                                now: now,
                                memberCount: 12,
                                photoCount: 3,
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
                            photoCount: 0,
                            onTap: {},
                            onLongPress: {}
                        )

                        // Processing event
                        PremiumEventCard(
                            event: processingEvent,
                            now: now,
                            memberCount: 6,
                            photoCount: 18,
                            onTap: {},
                            onLongPress: {}
                        )

                        // Ready to reveal
                        PremiumEventCard(
                            event: readyToRevealEvent,
                            now: now,
                            userHasCompletedReveal: false,
                            memberCount: 15,
                            photoCount: 42,
                            onTap: {},
                            onLongPress: {}
                        )

                        // Revealed
                        PremiumEventCard(
                            event: revealedEvent,
                            now: now,
                            userHasCompletedReveal: true,
                            likedCount: 14,
                            memberCount: 20,
                            photoCount: 67,
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

#Preview("Events Screen — All States") {
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
                photoCount: 3,
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

#Preview("Shot Dots — 8 of 10 Used") {
    let now = Date()
    ZStack {
        Color.black.ignoresSafeArea()
        PremiumEventCard(
            event: Event(
                name: "Almost Out of Shots",
                coverEmoji: "\u{1F4F8}",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600 * 2),
                releaseAt: now.addingTimeInterval(3600 * 26),
                memberCount: 5,
                photoCount: 8
            ),
            now: now,
            memberCount: 5,
            photoCount: 8,
            onTap: {},
            onLongPress: {}
        )
        .padding(16)
    }
}

#endif
