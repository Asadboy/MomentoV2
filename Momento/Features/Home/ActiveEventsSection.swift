//
//  ActiveEventsSection.swift
//  Momento
//
//  Active events that are NOT the featured lobby: section header + a ForEach
//  of CompactEventCard rows (revealed-pending events, plus any extra
//  live/upcoming events beyond the first). Tap, long press, and context menu
//  all funnel through HomeRouter.
//

import SwiftUI

struct ActiveEventsSection: View {
    @ObservedObject var store: EventStore
    @ObservedObject var router: HomeRouter
    let now: Date
    /// The event already rendered as the full-screen lobby, if any.
    var excludedEventId: String? = nil

    var body: some View {
        let active = store.activeEvents(at: now).filter { $0.id != excludedEventId }

        // When the lobby owns the first page, only show this header if
        // there's actually something to list under it. Without a lobby
        // (e.g. only a revealed-pending event) keep the classic header.
        if excludedEventId == nil || !active.isEmpty {
            HStack {
                Text(active.isEmpty ? "NO ACTIVE EVENTS" : "CURRENT EVENTS")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                    .foregroundColor(AppTheme.Colors.textQuaternary)

                Spacer()

                Button { router.showCreate() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("New")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }

        ForEach(active) { hydrated in
            CompactEventCard(
                event: hydrated.event,
                now: now,
                onTap: { router.handleEventTap(hydrated.event, now: now, store: store) },
                onLongPress: { router.showInvite(hydrated.event) }
            )
            .overlay {
                if store.newlyJoinedEventId == hydrated.id {
                    RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                        .stroke(AppTheme.Colors.accent.opacity(0.6), lineWidth: 2)
                        .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 12)
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
