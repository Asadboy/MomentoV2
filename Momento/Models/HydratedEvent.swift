//
//  HydratedEvent.swift
//  Momento
//
//  Bundles an Event with all of its per-event hydration into a single value:
//  members + dots, reveal status, liked counts, the user's own shot count,
//  cached past-event liked photos, and any local-only photos captured this
//  session.
//
//  Replaces the seven parallel [String: T] dictionaries EventStore used to
//  carry. Benefits:
//    1. Type-safety over keys — you cannot forget to populate one of the
//       seven dicts; the struct guarantees every field exists
//    2. Atomic updates — one @Published update replaces seven, fewer redraw
//       cascades and animation glitches
//    3. Reads better at call sites: `hydrated.likedCount` vs
//       `likedCounts[event.id] ?? 0`
//
//  All non-event fields default to "not yet hydrated" values so the store can
//  publish a HydratedEvent immediately on event load and fill in counts /
//  members as the parallel task groups complete.
//

import Foundation

struct HydratedEvent: Identifiable {
    var event: Event
    var members: [MemberWithShots] = []
    var userHasCompletedReveal: Bool = false
    var likedCount: Int = 0
    var likedPhotos: [PhotoData] = []
    var totalLikeCount: Int = 0
    var userPhotoCount: Int = 0
    var localPhotos: [EventPhoto] = []

    var id: String { event.id }
}
