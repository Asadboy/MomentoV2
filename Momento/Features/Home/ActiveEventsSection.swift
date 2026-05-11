//
//  ActiveEventsSection.swift
//  Momento
//
//  The "CURRENT EVENTS" section: section header + a ForEach of EventHeroView
//  cards. Reads active events from the store at the current `now`; tap, long
//  press, and invite all funnel through HomeRouter.
//

import SwiftUI

struct ActiveEventsSection: View {
    @ObservedObject var store: EventStore
    @ObservedObject var router: HomeRouter
    let now: Date

    var body: some View {
        let active = store.activeEvents(at: now)

        HStack {
            Text(active.isEmpty ? "NO ACTIVE EVENTS" : "CURRENT EVENTS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.4))

            Spacer()

            Button { router.showCreate() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("New")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }

        ForEach(active) { hydrated in
            EventHeroView(
                event: hydrated.event,
                now: now,
                members: hydrated.members,
                currentUserId: store.currentUserId,
                userHasCompletedReveal: hydrated.userHasCompletedReveal,
                onTap: { router.handleEventTap(hydrated.event, now: now, store: store) },
                onLongPress: { router.showInvite(hydrated.event) },
                onInvite: { router.showInvite(hydrated.event) }
            )
            .overlay {
                if store.newlyJoinedEventId == hydrated.id {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.green.opacity(0.6), lineWidth: 2)
                        .shadow(color: Color.green.opacity(0.4), radius: 12)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: store.newlyJoinedEventId)
            .contextMenu {
                Button { router.showInvite(hydrated.event) } label: {
                    Label("Invite Friends", systemImage: "person.badge.plus")
                }
            }
        }
    }
}
