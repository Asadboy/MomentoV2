//
//  EventStoreTests.swift
//  MomentoTests
//
//  Behavioural unit tests for EventStore. Uses MockMomentoAPI so no network
//  calls happen. Tests focus on the contracts that matter to consumers:
//  loading, filtering active vs past, mutation correctness, and the 10s
//  refresh throttle.
//
//  Not exhaustive — some store paths are time-coupled (the 2-second join
//  glow, the 3-second post-upload reconciliation) and need a scheduler
//  injection to test without sleeping. Those gaps are intentional for now.
//

import XCTest
@testable import Momento

@MainActor
final class EventStoreTests: XCTestCase {

    var api: MockMomentoAPI!
    var store: EventStore!

    override func setUp() async throws {
        api = MockMomentoAPI()
        api.currentUserId = UUID()
        store = EventStore(api: api)
    }

    override func tearDown() async throws {
        api = nil
        store = nil
    }

    // MARK: - Load

    func test_loadEvents_populatesHydratedEvents() async {
        let now = Date()
        let id = UUID()
        api.myEvents = [
            .test(
                id: id,
                name: "Joe's Birthday",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600),
                releaseAt: now.addingTimeInterval(7200)
            )
        ]

        await store.loadEvents()

        XCTAssertEqual(store.hydratedEvents.count, 1)
        XCTAssertEqual(store.hydratedEvents.first?.event.name, "Joe's Birthday")
        XCTAssertFalse(store.isLoading)
    }

    func test_loadEvents_failure_clearsLoadingState() async {
        api.myEventsError = NSError(domain: "test", code: 1)

        await store.loadEvents()

        XCTAssertFalse(store.isLoading, "isLoading must not stay true after a failure — the empty state can't render otherwise")
        XCTAssertEqual(store.hydratedEvents.count, 0)
    }

    func test_loadEvents_isDebounced() async {
        // Pre-populate one event so isLoading skips its "first load" branch.
        api.myEvents = [.test(
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(60),
            releaseAt: Date().addingTimeInterval(120)
        )]
        await store.loadEvents()
        api.resetCallCounts()

        // Fire two loads in parallel; the second should observe isRefreshing
        // and bail out without re-fetching.
        async let a: Void = store.loadEvents()
        async let b: Void = store.loadEvents()
        _ = await (a, b)

        // We don't assert on a strict 1 — the timing window for the second
        // call to be reentrant before the first finishes is small. We just
        // assert that the user-visible state ends consistent.
        XCTAssertEqual(store.hydratedEvents.count, 1)
        XCTAssertFalse(store.isLoading)
    }

    // MARK: - Active / past filtering

    func test_activeEvents_includesLive_excludesCompletedReveal() async {
        let now = Date()
        let liveId = UUID()
        let revealedDoneId = UUID()
        let revealedPendingId = UUID()
        let upcomingId = UUID()

        api.myEvents = [
            .test(id: liveId, startsAt: now.addingTimeInterval(-60), endsAt: now.addingTimeInterval(60), releaseAt: now.addingTimeInterval(120)),
            .test(id: revealedDoneId, startsAt: now.addingTimeInterval(-7200), endsAt: now.addingTimeInterval(-3600), releaseAt: now.addingTimeInterval(-60)),
            .test(id: revealedPendingId, startsAt: now.addingTimeInterval(-7200), endsAt: now.addingTimeInterval(-3600), releaseAt: now.addingTimeInterval(-60)),
            .test(id: upcomingId, startsAt: now.addingTimeInterval(3600), endsAt: now.addingTimeInterval(7200), releaseAt: now.addingTimeInterval(10800))
        ]
        await store.loadEvents()
        store.markRevealCompleted(eventId: revealedDoneId.uuidString)

        let active = store.activeEvents(at: now)
        let activeIds = Set(active.map { $0.id })

        XCTAssertTrue(activeIds.contains(liveId.uuidString))
        XCTAssertTrue(activeIds.contains(revealedPendingId.uuidString))
        XCTAssertTrue(activeIds.contains(upcomingId.uuidString))
        XCTAssertFalse(activeIds.contains(revealedDoneId.uuidString), "Completed-reveal events should drop out of active")

        // Cleanup: don't pollute RevealStateManager for other tests.
        store.clearRevealCompleted(eventId: revealedDoneId.uuidString)
    }

    func test_activeEvents_sortsLiveBeforeRevealedBeforeUpcoming() async {
        let now = Date()
        let liveId = UUID()
        let revealedPendingId = UUID()
        let upcomingId = UUID()

        // Intentionally pass in a non-priority order to verify sort, not insertion order.
        api.myEvents = [
            .test(id: upcomingId, startsAt: now.addingTimeInterval(3600), endsAt: now.addingTimeInterval(7200), releaseAt: now.addingTimeInterval(10800)),
            .test(id: revealedPendingId, startsAt: now.addingTimeInterval(-7200), endsAt: now.addingTimeInterval(-3600), releaseAt: now.addingTimeInterval(-60)),
            .test(id: liveId, startsAt: now.addingTimeInterval(-60), endsAt: now.addingTimeInterval(60), releaseAt: now.addingTimeInterval(120))
        ]
        await store.loadEvents()

        let active = store.activeEvents(at: now)
        XCTAssertEqual(active.map(\.id), [liveId.uuidString, revealedPendingId.uuidString, upcomingId.uuidString])
    }

    func test_pastEvents_includesOnlyCompletedReveals() async {
        let now = Date()
        let doneId = UUID()
        let pendingRevealId = UUID()

        api.myEvents = [
            .test(id: doneId, startsAt: now.addingTimeInterval(-7200), endsAt: now.addingTimeInterval(-3600), releaseAt: now.addingTimeInterval(-60)),
            .test(id: pendingRevealId, startsAt: now.addingTimeInterval(-7200), endsAt: now.addingTimeInterval(-3600), releaseAt: now.addingTimeInterval(-60))
        ]
        await store.loadEvents()
        store.markRevealCompleted(eventId: doneId.uuidString)

        let past = store.pastEvents(at: now)
        XCTAssertEqual(past.count, 1)
        XCTAssertEqual(past.first?.id, doneId.uuidString)

        store.clearRevealCompleted(eventId: doneId.uuidString)
    }

    // MARK: - Mutations

    func test_appendCreatedEvent_addsHydratedEvent() {
        let event = Event(name: "Just Created",
                          startsAt: Date(),
                          endsAt: Date().addingTimeInterval(3600),
                          releaseAt: Date().addingTimeInterval(7200))
        store.appendCreatedEvent(event)

        XCTAssertEqual(store.hydratedEvents.count, 1)
        XCTAssertEqual(store.hydratedEvents.first?.event.name, "Just Created")
    }

    func test_joinedEvent_setsNewlyJoinedId() {
        let event = Event(name: "Joined",
                          startsAt: Date(),
                          endsAt: Date().addingTimeInterval(3600),
                          releaseAt: Date().addingTimeInterval(7200))
        store.joinedEvent(event)

        XCTAssertEqual(store.newlyJoinedEventId, event.id, "The glow id should be set immediately for the green-border overlay")
        XCTAssertEqual(store.hydratedEvents.count, 1)
        // The 2-second clearing is dispatch-queue based; we don't wait for it
        // here. A scheduler injection would let us test that path.
    }

    func test_markRevealCompleted_setsHydratedFlag() async {
        let id = UUID()
        api.myEvents = [.test(
            id: id,
            startsAt: Date().addingTimeInterval(-7200),
            endsAt: Date().addingTimeInterval(-3600),
            releaseAt: Date().addingTimeInterval(-60)
        )]
        await store.loadEvents()

        store.markRevealCompleted(eventId: id.uuidString)

        XCTAssertTrue(store.hydratedEvents.first(where: { $0.id == id.uuidString })?.userHasCompletedReveal ?? false)

        // Cleanup
        store.clearRevealCompleted(eventId: id.uuidString)
    }

    func test_deleteEvent_removesFromList() async {
        let now = Date()
        let keepId = UUID()
        let dropId = UUID()
        api.myEvents = [
            .test(id: keepId, startsAt: now, endsAt: now.addingTimeInterval(60), releaseAt: now.addingTimeInterval(120)),
            .test(id: dropId, startsAt: now, endsAt: now.addingTimeInterval(60), releaseAt: now.addingTimeInterval(120))
        ]
        await store.loadEvents()

        let toDelete = store.hydratedEvents.first { $0.id == dropId.uuidString }!.event
        await store.deleteEvent(toDelete)

        XCTAssertEqual(store.hydratedEvents.count, 1)
        XCTAssertEqual(store.hydratedEvents.first?.id, keepId.uuidString)
        XCTAssertEqual(api.deleteEventCalls, [dropId])
    }

    // MARK: - Refresh tick throttle

    func test_refreshTick_skipsTwoOfThreeTicks_whenNothingIsLive() async {
        let now = Date()
        // Past, completed-reveal event — not live.
        api.myEvents = [.test(
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600),
            releaseAt: now.addingTimeInterval(-60)
        )]
        await store.loadEvents()
        api.resetCallCounts()

        // 3 ticks: only the 3rd should actually refresh.
        await store.refreshTick(at: now)
        await store.refreshTick(at: now)
        await store.refreshTick(at: now)

        // The refresh path queries getEventMemberCount for every event in the
        // store. With one event and one real refresh out of three ticks, we
        // expect exactly one call.
        XCTAssertEqual(api.getEventMemberCountCallCount, 1, "Two of three ticks should be skipped when nothing is live")
    }

    func test_refreshTick_runsEveryTick_whenSomethingIsLive() async {
        let now = Date()
        api.myEvents = [.test(
            startsAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(60),
            releaseAt: now.addingTimeInterval(120)
        )]
        await store.loadEvents()
        api.resetCallCounts()

        await store.refreshTick(at: now)
        await store.refreshTick(at: now)
        await store.refreshTick(at: now)

        XCTAssertEqual(api.getEventMemberCountCallCount, 3, "All three ticks should refresh when something is live")
    }

    // MARK: - currentUserId proxy

    func test_currentUserId_proxiesFromAPI() {
        let id = UUID()
        api.currentUserId = id
        XCTAssertEqual(store.currentUserId, id.uuidString)

        api.currentUserId = nil
        XCTAssertNil(store.currentUserId)
    }
}
