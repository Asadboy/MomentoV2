//
//  EventStoreTimingTests.swift
//  MomentoTests
//
//  Tests for the time-coupled paths on EventStore: the 2-second join glow
//  auto-clear and the 3-second post-upload reconciliation. These were
//  previously untestable — `DispatchQueue.asyncAfter` and `Task.sleep` would
//  have forced us to actually wait. The scheduler injection refactor parks
//  those waits on a `TestScheduler` that we can advance synchronously here.
//

import XCTest
import UIKit
@testable import Momento

@MainActor
final class EventStoreTimingTests: XCTestCase {

    var api: MockMomentoAPI!
    var scheduler: TestScheduler!
    var store: EventStore!

    override func setUp() async throws {
        api = MockMomentoAPI()
        api.currentUserId = UUID()
        scheduler = TestScheduler()
        store = EventStore(api: api, scheduler: scheduler)
    }

    override func tearDown() async throws {
        api = nil
        scheduler = nil
        store = nil
    }

    // MARK: - Join glow auto-clear (2s)

    func test_joinedEvent_setsGlowId() {
        let event = Event(
            name: "Joined",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3600),
            releaseAt: Date().addingTimeInterval(7200)
        )

        store.joinedEvent(event)

        XCTAssertEqual(store.newlyJoinedEventId, event.id, "Glow id set immediately on join")
    }

    func test_joinedEvent_schedulesA2SecondSleep() async {
        let event = Event(
            name: "Joined",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3600),
            releaseAt: Date().addingTimeInterval(7200)
        )

        store.joinedEvent(event)

        // Let the spawned Task reach the scheduler.sleep call.
        await yieldUntil { scheduler.requestedDelays.contains(2.0) }

        XCTAssertEqual(scheduler.requestedDelays, [2.0], "The glow auto-clear should ask the scheduler for exactly 2.0s")
    }

    func test_joinedEvent_clearsGlowAfterSchedulerAdvances() async {
        let event = Event(
            name: "Joined",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3600),
            releaseAt: Date().addingTimeInterval(7200)
        )

        store.joinedEvent(event)
        await yieldUntil { scheduler.pendingCount >= 1 }
        XCTAssertEqual(store.newlyJoinedEventId, event.id, "Pre-advance, glow id is still set")

        scheduler.advanceAll()
        await yieldUntil { store.newlyJoinedEventId == nil }

        XCTAssertNil(store.newlyJoinedEventId, "After the scheduler advances the 2s sleep, the glow id clears")
    }

    // MARK: - Optimistic shot count + 3s reconciliation

    func test_handlePhotoCaptured_bumpsOptimisticImmediately() async {
        let now = Date()
        let userId = api.currentUserId!
        let eventId = UUID()
        api.myEvents = [.test(
            id: eventId,
            startsAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )]
        api.membersWithShots[eventId] = [
            MemberWithShots(userId: userId.uuidString, displayName: "Me", avatarUrl: nil, shotsTaken: 4)
        ]
        await store.loadEvents()
        await yieldUntil {
            store.hydratedEvents.first?.members.contains(where: { $0.userId == userId.uuidString }) ?? false
        }
        let event = store.hydratedEvents.first!.event

        // Capture: this is the synchronous half. Optimistic bump should be
        // visible immediately, *before* the scheduler is advanced.
        store.handlePhotoCaptured(makeTestImage(), for: event)

        let h = store.hydratedEvents.first { $0.id == eventId.uuidString }!
        XCTAssertEqual(h.userPhotoCount, 1, "Optimistic count bumps from 0 to 1 the moment the user shoots")
        XCTAssertEqual(h.members.first { $0.userId == userId.uuidString }?.shotsTaken, 5, "The matching member's dot bumps too — 4 → 5")
    }

    func test_handlePhotoCaptured_reconcilesAfter3sToServerCount() async {
        let now = Date()
        let userId = api.currentUserId!
        let eventId = UUID()
        let key = "\(eventId):\(userId)"

        api.myEvents = [.test(
            id: eventId,
            startsAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )]
        api.membersWithShots[eventId] = [
            MemberWithShots(userId: userId.uuidString, displayName: "Me", avatarUrl: nil, shotsTaken: 4)
        ]
        // Seed initial photo count so load sets userPhotoCount=4 (matches
        // the member's shotsTaken). Without this, the load path returns 0
        // from the mock and the optimistic bump goes 0→1 instead of 4→5.
        api.userPhotoCounts[key] = 4

        await store.loadEvents()
        let event = store.hydratedEvents.first!.event
        XCTAssertEqual(store.hydratedEvents.first?.userPhotoCount, 4, "Post-load, userPhotoCount should reflect the seeded value")

        // Server insists the real count is 7 — maybe another upload landed
        // in the same window, maybe the optimistic bump was off. Doesn't
        // matter; we want to reconcile to whatever the server says.
        api.userPhotoCounts[key] = 7

        store.handlePhotoCaptured(makeTestImage(), for: event)

        // Pre-advance: optimistic count is 5 (was 4, +1).
        XCTAssertEqual(store.hydratedEvents.first?.userPhotoCount, 5)

        await yieldUntil { scheduler.requestedDelays.contains(3.0) }
        scheduler.advanceAll()
        await yieldUntil { store.hydratedEvents.first?.userPhotoCount == 7 }

        let h = store.hydratedEvents.first!
        XCTAssertEqual(h.userPhotoCount, 7, "After 3s, reconciliation overrides the optimistic count with the server's truth")
        XCTAssertEqual(h.members.first { $0.userId == userId.uuidString }?.shotsTaken, 7, "Dot row reconciles too")
    }

    func test_handlePhotoCaptured_schedulesExactly3sReconcile() async {
        let now = Date()
        let eventId = UUID()
        api.myEvents = [.test(
            id: eventId,
            startsAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )]
        await store.loadEvents()
        let event = store.hydratedEvents.first!.event

        store.handlePhotoCaptured(makeTestImage(), for: event)

        await yieldUntil { scheduler.requestedDelays.contains(3.0) }
        XCTAssertTrue(scheduler.requestedDelays.contains(3.0), "Reconciliation should ask for exactly 3.0s")
    }

    // MARK: - Helpers

    /// Re-enter the runloop until the predicate is true or we hit a cap.
    /// Tasks spawned by EventStore need a turn or two of the runloop before
    /// their `scheduler.sleep` call lands; this lets us poll for that
    /// without sleeping the test thread.
    private func yieldUntil(timeoutTicks: Int = 50, _ predicate: () -> Bool) async {
        var ticks = 0
        while !predicate() && ticks < timeoutTicks {
            await Task.yield()
            ticks += 1
        }
    }

    private func makeTestImage() -> UIImage {
        // 1×1 pixel — enough to exercise the code path without dragging in
        // image-encoding flakiness on CI runners. PhotoStorageManager will
        // happily save this; what we're testing is the state mutations
        // around it.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.gray.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}

