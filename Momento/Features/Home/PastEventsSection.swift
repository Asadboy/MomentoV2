//
//  PastEventsSection.swift
//  Momento
//
//  The "PAST EVENTS" section: section header + a ForEach of PastEventCard
//  rows. Renders nothing when the store has no past events.
//

import SwiftUI

struct PastEventsSection: View {
    @ObservedObject var store: EventStore
    @ObservedObject var router: HomeRouter
    let now: Date

    var body: some View {
        let past = store.pastEvents(at: now)
        if !past.isEmpty {
            HStack {
                Text("PAST EVENTS")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            .padding(.top, 8)

            ForEach(past) { hydrated in
                PastEventCard(
                    event: hydrated.event,
                    now: now,
                    photos: hydrated.likedPhotos,
                    totalPhotoCount: hydrated.event.photoCount,
                    totalLikeCount: hydrated.totalLikeCount,
                    memberCount: hydrated.event.memberCount,
                    onTap: { router.handleEventTap(hydrated.event, now: now, store: store) },
                    onLongPress: { router.showInvite(hydrated.event) }
                )
                .contextMenu {
                    Button { router.showInvite(hydrated.event) } label: {
                        Label("Invite Friends", systemImage: "person.badge.plus")
                    }
                }
            }
        }
    }
}
