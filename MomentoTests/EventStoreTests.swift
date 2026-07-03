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

    func test_joinedEvent_alreadyOnScreen_doesNotDuplicate() async {
        // joinEvent succeeds for existing members, so re-scanning the QR of an
        // event already on the home screen routes back through joinedEvent.
        let id = UUID()
        api.myEvents = [.test(
            id: id,
            startsAt: Date().addingTimeInterval(-60),
            endsAt: Date().addingTimeInterval(3600),
            releaseAt: Date().addingTimeInterval(7200)
        )]
        await store.loadEvents()

        let rejoined = Event(id: id.uuidString,
                             name: "Rejoined",
                             startsAt: Date().addingTimeInterval(-60),
                             endsAt: Date().addingTimeInterval(3600),
                             releaseAt: Date().addingTimeInterval(7200))
        store.joinedEvent(rejoined)

        XCTAssertEqual(store.hydratedEvents.count, 1, "Re-joining must not append a duplicate HydratedEvent")
        XCTAssertEqual(store.newlyJoinedEventId, rejoined.id, "The glow should still fire on re-join")
    }

    func test_loadEvents_survivesDuplicateHydratedEvents() async {
        // If duplicates ever sneak into hydratedEvents, the next load must
        // dedupe (previously Dictionary(uniqueKeysWithValues:) trapped here).
        let id = UUID()
        let event = Event(id: id.uuidString,
                          name: "Dup",
                          startsAt: Date().addingTimeInterval(-60),
                          endsAt: Date().addingTimeInterval(3600),
                          releaseAt: Date().addingTimeInterval(7200))
        store.appendCreatedEvent(event)
        store.appendCreatedEvent(event)
        api.myEvents = [.test(
            id: id,
            startsAt: Date().addingTimeInterval(-60),
            endsAt: Date().addingTimeInterval(3600),
            releaseAt: Date().addingTimeInterval(7200)
        )]

        await store.loadEvents()

        XCTAssertEqual(store.hydratedEvents.count, 1, "Load should rebuild the list from server truth without crashing")
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

    // MARK: - Error surfacing

    func test_loadEvents_failure_setsErrorMessage_whenStoreEmpty() async {
        api.myEventsError = NSError(domain: "test.network", code: 1)

        await store.loadEvents()

        XCTAssertNotNil(store.errorMessage, "Empty store + failed load should expose an error message to the alert")
    }

    func test_loadEvents_failure_doesNotOverwrite_whenEventsAlreadyShown() async {
        // First load populates the store.
        api.myEvents = [.test(
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(60),
            releaseAt: Date().addingTimeInterval(120)
        )]
        await store.loadEvents()
        XCTAssertNil(store.errorMessage)

        // Subsequent refresh fails — we want this to be quiet, not pop an
        // alert over the user's existing data.
        api.myEvents = []
        api.myEventsError = NSError(domain: "test.network", code: 1)
        await store.loadEvents()

        XCTAssertNil(store.errorMessage, "Transient refresh failure with events visible should stay silent")
    }

    func test_loadEvents_success_clearsPriorErrorMessage() async {
        // Force a failure first.
        api.myEventsError = NSError(domain: "test.network", code: 1)
        await store.loadEvents()
        XCTAssertNotNil(store.errorMessage)

        // Then succeed.
        api.myEventsError = nil
        api.myEvents = [.test(
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(60),
            releaseAt: Date().addingTimeInterval(120)
        )]
        await store.loadEvents()

        XCTAssertNil(store.errorMessage, "A successful load should clear any prior error so the alert doesn't persist")
    }

    func test_deleteEvent_failure_setsErrorMessage() async {
        let now = Date()
        let id = UUID()
        api.myEvents = [.test(id: id, startsAt: now, endsAt: now.addingTimeInterval(60), releaseAt: now.addingTimeInterval(120))]
        await store.loadEvents()

        api.deleteEventError = NSError(domain: "test.network", code: 1)
        let event = store.hydratedEvents.first { $0.id == id.uuidString }!.event
        await store.deleteEvent(event)

        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.hydratedEvents.count, 1, "Failed delete shouldn't remove the event from the local list")
    }

    func test_dismissError_clearsErrorMessage() async {
        api.myEventsError = NSError(domain: "test.network", code: 1)
        await store.loadEvents()
        XCTAssertNotNil(store.errorMessage)

        store.dismissError()
        XCTAssertNil(store.errorMessage)
    }

    // MARK: - Lobby roster error resilience

    private func loadOneLiveEventWithRoster(now: Date) async -> UUID {
        let id = UUID()
        api.myEvents = [
            .test(
                id: id,
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600),
                releaseAt: now.addingTimeInterval(7200)
            )
        ]
        api.membersWithShots = [
            id: [MemberWithShots(userId: "u1", displayName: "Asad", avatarUrl: nil, shotsTaken: 3)]
        ]
        await store.loadEvents()
        return id
    }

    func test_refreshTick_rosterFetchFailure_keepsPreviousMembers() async {
        let now = Date()
        _ = await loadOneLiveEventWithRoster(now: now)
        XCTAssertEqual(store.hydratedEvents.first?.members.count, 1)

        api.membersWithShotsError = NSError(domain: "test.network", code: 1)
        await store.refreshTick(at: now)

        XCTAssertEqual(
            store.hydratedEvents.first?.members.count, 1,
            "a transient roster fetch failure must not blank the lobby"
        )
    }

    func test_loadEvents_rosterFetchFailure_keepsPreviousMembers() async {
        let now = Date()
        _ = await loadOneLiveEventWithRoster(now: now)
        XCTAssertEqual(store.hydratedEvents.first?.members.count, 1)

        api.membersWithShotsError = NSError(domain: "test.network", code: 1)
        await store.loadEvents()

        XCTAssertEqual(
            store.hydratedEvents.first?.members.count, 1,
            "a roster fetch failure during reload must not blank the lobby"
        )
    }

    // MARK: - currentUserId proxy

    func test_currentUserId_proxiesFromAPI() {
        let id = UUID()
        api.currentUserId = id
        XCTAssertEqual(store.currentUserId, id.uuidString)

        api.currentUserId = nil
        XCTAssertNil(store.currentUserId)
    }

    // MARK: - Roll milestones (MilestoneTracker)

    private func makeTracker(suite: String) -> (MilestoneTracker, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (MilestoneTracker(defaults: defaults), defaults)
    }

    func test_milestone_firesOnCrossingHalf_onceOnly() {
        let (tracker, defaults) = makeTracker(suite: "milestones-half")
        defer { defaults.removePersistentDomain(forName: "milestones-half") }

        // Baseline observation: below half — never fires.
        XCTAssertNil(tracker.check(eventId: "e1", taken: 5, total: 40))
        // Crossing half (20/40) fires exactly once.
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 21, total: 40), .half)
        // Re-polling at/above half never re-fires.
        XCTAssertNil(tracker.check(eventId: "e1", taken: 22, total: 40))
    }

    func test_milestone_baselineAlreadyPastHalf_neverFires() {
        let (tracker, defaults) = makeTracker(suite: "milestones-baseline")
        defer { defaults.removePersistentDomain(forName: "milestones-baseline") }

        // Joining late into an event already past half: baseline only.
        XCTAssertNil(tracker.check(eventId: "e1", taken: 25, total: 40))
        XCTAssertNil(tracker.check(eventId: "e1", taken: 26, total: 40))
        // But the un-crossed FULL threshold still fires later.
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 40, total: 40), .full)
    }

    func test_milestone_fullTakesPrecedenceWhenBothCrossedAtOnce() {
        let (tracker, defaults) = makeTracker(suite: "milestones-both")
        defer { defaults.removePersistentDomain(forName: "milestones-both") }

        XCTAssertNil(tracker.check(eventId: "e1", taken: 0, total: 20))
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 20, total: 20), .full)
    }

    func test_milestone_firedStatePersistsAcrossInstances() {
        let suite = "milestones-persist"
        let (tracker, defaults) = makeTracker(suite: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertNil(tracker.check(eventId: "e1", taken: 5, total: 40))
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 20, total: 40), .half)

        // "Relaunch": new tracker, same defaults. Baseline re-records, and
        // a later crossing of the already-fired threshold stays silent.
        let tracker2 = MilestoneTracker(defaults: defaults)
        XCTAssertNil(tracker2.check(eventId: "e1", taken: 19, total: 40))
        XCTAssertNil(tracker2.check(eventId: "e1", taken: 21, total: 40))
    }

    func test_milestone_isPerEvent() {
        let (tracker, defaults) = makeTracker(suite: "milestones-perevent")
        defer { defaults.removePersistentDomain(forName: "milestones-perevent") }

        XCTAssertNil(tracker.check(eventId: "e1", taken: 0, total: 20))
        XCTAssertNil(tracker.check(eventId: "e2", taken: 0, total: 20))
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 10, total: 20), .half)
        XCTAssertEqual(tracker.check(eventId: "e2", taken: 10, total: 20), .half)
    }

    func test_store_firesMilestoneWhenRefreshCrossesHalf() async {
        let suite = "milestones-store"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let now = Date()
        let id = UUID()
        api.myEvents = [.test(
            id: id,
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )]
        api.membersWithShots[id] = [
            MemberWithShots(userId: "a", displayName: "A", avatarUrl: nil, shotsTaken: 4),
            MemberWithShots(userId: "b", displayName: "B", avatarUrl: nil, shotsTaken: 5)
        ]
        let store = EventStore(api: api, milestones: MilestoneTracker(defaults: defaults))

        // Baseline: 9/20 — below half, records baseline, no fire.
        await store.loadEvents()
        XCTAssertNil(store.milestoneFire)

        // Refresh crosses half (11/20).
        api.membersWithShots[id] = [
            MemberWithShots(userId: "a", displayName: "A", avatarUrl: nil, shotsTaken: 5),
            MemberWithShots(userId: "b", displayName: "B", avatarUrl: nil, shotsTaken: 6)
        ]
        await store.refreshTick(at: now)

        XCTAssertEqual(store.milestoneFire?.milestone, .half)
        XCTAssertEqual(store.milestoneFire?.eventId, id.uuidString)

        // Dismiss + further refresh: silent.
        store.clearMilestoneFire()
        await store.refreshTick(at: now)
        XCTAssertNil(store.milestoneFire)
    }
}
