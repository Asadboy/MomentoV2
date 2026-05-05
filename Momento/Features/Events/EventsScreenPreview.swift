//
//  EventsScreenPreview.swift
//  Momento
//
//  Full-screen preview of the events screen.
//  Active events (live/upcoming) as large cards, past events as compact rows.
//

import SwiftUI

#if DEBUG

private let previewMembers = [
    MemberWithShots(userId: "1", username: "asad", displayName: "Asad", avatarUrl: nil, shotsTaken: 7),
    MemberWithShots(userId: "2", username: "joe", displayName: "Joe", avatarUrl: nil, shotsTaken: 4),
    MemberWithShots(userId: "3", username: "sarah", displayName: "Sarah", avatarUrl: nil, shotsTaken: 2),
    MemberWithShots(userId: "4", username: "mike", displayName: "Mike", avatarUrl: nil, shotsTaken: 0),
]

private struct EventsScreenPreviewContent: View {
    private let now = Date()

    private var liveEvent: Event {
        Event(
            name: "Joe's 26th Birthday",
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(3600 * 5),
            releaseAt: now.addingTimeInterval(3600 * 29),
            memberCount: 4,
            photoCount: 13,
            joinCode: "JOE26"
        )
    }

    private var upcomingEvent: Event {
        Event(
            name: "NYE House Party",
            startsAt: now.addingTimeInterval(3600 * 8),
            endsAt: now.addingTimeInterval(3600 * 16),
            releaseAt: now.addingTimeInterval(3600 * 40),
            memberCount: 8,
            joinCode: "NYE24"
        )
    }

    private var revealedEvent: Event {
        Event(
            name: "Summer BBQ",
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
                HStack {
                    Text("10shots")
                        .font(.system(size: 28, weight: .bold))
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

                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Active events
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

                        // Live
                        EventCard(
                            event: liveEvent,
                            now: now,
                            members: previewMembers,
                            onTap: {},
                            onLongPress: {},
                            onInvite: {}
                        )

                        // Upcoming
                        EventCard(
                            event: upcomingEvent,
                            now: now,
                            members: [previewMembers[0], previewMembers[1]],
                            onTap: {},
                            onLongPress: {},
                            onInvite: {}
                        )

                        // Done pile
                        HStack {
                            Text("PAST EVENTS")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(.white.opacity(0.4))
                            Spacer()
                        }
                        .padding(.top, 8)

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

#Preview("Events Screen") {
    EventsScreenPreviewContent()
}

#Preview("Live Card Only") {
    let now = Date()
    ZStack {
        Color.black.ignoresSafeArea()
        EventCard(
            event: Event(
                name: "Joe's 26th Birthday",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600 * 5),
                releaseAt: now.addingTimeInterval(3600 * 29),
                memberCount: 4,
                photoCount: 13
            ),
            now: now,
            members: previewMembers,
            onTap: {},
            onLongPress: {},
            onInvite: {}
        )
        .padding(16)
    }
}

#Preview("Past Event Cards") {
    let now = Date()
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 8) {
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
                totalPhotoCount: 14,
                onTap: {},
                onLongPress: {}
            )
        }
        .padding(16)
    }
}

#endif
