//
//  HomeRouterTests.swift
//  MomentoTests
//
//  Tests for HomeRouter's tap routing and intent helpers. The handleEventTap
//  function is where a tap on an event card decides whether to open the
//  camera, the reveal flow, or the liked gallery — a wrong decision here
//  ships the user into the wrong screen entirely.
//

import XCTest
@testable import Momento

@MainActor
final class HomeRouterTests: XCTestCase {

    var router: HomeRouter!
    var store: EventStore!
    var api: MockMomentoAPI!

    override func setUp() async throws {
        router = HomeRouter()
        api = MockMomentoAPI()
        api.currentUserId = UUID()
        store = EventStore(api: api)
    }

    override func tearDown() async throws {
        router = nil
        store = nil
        api = nil
    }

    // MARK: - Helpers

    /// Load a single event into the store at a given time-state.
    @discardableResult
    private func seed(
        startsAt: Date,
        endsAt: Date,
        releaseAt: Date,
        completedReveal: Bool = false
    ) async -> Event {
        let id = UUID()
        api.myEvents = [
            .test(id: id, startsAt: startsAt, endsAt: endsAt, releaseAt: releaseAt)
        ]
        await store.loadEvents()
        if completedReveal {
            store.markRevealCompleted(eventId: id.uuidString)
        }
        return store.hydratedEvents.first!.event
    }

    // MARK: - handleEventTap

    func test_tap_onUpcoming_doesNothing() async {
        let now = Date()
        let event = await seed(
            startsAt: now.addingTimeInterval(3600),
            endsAt: now.addingTimeInterval(7200),
            releaseAt: now.addingTimeInterval(10800)
        )

        router.handleEventTap(event, now: now, store: store)

        XCTAssertNil(router.sheet, "Tapping an upcoming event shouldn't open anything")
        XCTAssertNil(router.cover)
    }

    func test_tap_onLive_opensPhotoCaptureSheet() async {
        let now = Date()
        let event = await seed(
            startsAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )

        router.handleEventTap(event, now: now, store: store)

        if case .photoCapture(let captured) = router.sheet {
            XCTAssertEqual(captured.id, event.id)
        } else {
            XCTFail("Tapping a live event should open the photoCapture sheet; got \(String(describing: router.sheet))")
        }
        XCTAssertNil(router.cover)
    }

    func test_tap_onRevealedButNotYetReady_doesNothing() async {
        let now = Date()
        // Event ended but releaseAt is still in the future ("Reveals in X")
        let event = await seed(
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600),
            releaseAt: now.addingTimeInterval(60)
        )

        router.handleEventTap(event, now: now, store: store)

        XCTAssertNil(router.sheet, "Tapping a revealed-but-not-yet-ready event should be a no-op — the user is waiting")
        XCTAssertNil(router.cover)
    }

    func test_tap_onRevealReadyAndNotCompleted_opensStackReveal() async {
        let now = Date()
        let event = await seed(
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600),
            releaseAt: now.addingTimeInterval(-60),
            completedReveal: false
        )

        router.handleEventTap(event, now: now, store: store)

        if case .stackReveal(let revealed) = router.cover {
            XCTAssertEqual(revealed.id, event.id)
        } else {
            XCTFail("Reveal-ready + not-completed should open stack reveal; got \(String(describing: router.cover))")
        }
        XCTAssertNil(router.sheet)
    }

    func test_tap_onRevealCompleted_opensLikedGallery() async {
        let now = Date()
        let event = await seed(
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600),
            releaseAt: now.addingTimeInterval(-60),
            completedReveal: true
        )

        router.handleEventTap(event, now: now, store: store)

        if case .likedGallery(let revealed) = router.cover {
            XCTAssertEqual(revealed.id, event.id)
        } else {
            XCTFail("Already-revealed event should open liked gallery; got \(String(describing: router.cover))")
        }
        XCTAssertNil(router.sheet)

        // Cleanup so RevealStateManager UserDefaults doesn't leak.
        store.clearRevealCompleted(eventId: event.id)
    }

    // MARK: - Intent helpers

    func test_showCreate_setsCoverToCreate() {
        router.showCreate()
        if case .create = router.cover {
            // ok
        } else {
            XCTFail("Expected .create cover, got \(String(describing: router.cover))")
        }
    }

    func test_showJoin_setsSheetWithCode() {
        router.showJoin(code: "ABC123")
        if case .join(let code) = router.sheet {
            XCTAssertEqual(code, "ABC123")
        } else {
            XCTFail("Expected .join sheet, got \(String(describing: router.sheet))")
        }
    }

    func test_showJoin_withoutCode_passesNil() {
        router.showJoin()
        if case .join(let code) = router.sheet {
            XCTAssertNil(code)
        } else {
            XCTFail("Expected .join(nil) sheet, got \(String(describing: router.sheet))")
        }
    }

    func test_showInvite_setsSheetWithEvent() {
        let event = Event(
            name: "Birthday",
            startsAt: Date(),
            endsAt: Date().addingTimeInterval(3600),
            releaseAt: Date().addingTimeInterval(7200)
        )
        router.showInvite(event)
        if case .invite(let invited) = router.sheet {
            XCTAssertEqual(invited.id, event.id)
        } else {
            XCTFail("Expected .invite sheet, got \(String(describing: router.sheet))")
        }
    }

    func test_showSettings_setsSheetToSettings() {
        router.showSettings()
        if case .settings = router.sheet {
            // ok
        } else {
            XCTFail("Expected .settings sheet, got \(String(describing: router.sheet))")
        }
    }

    func test_showError_setsErrorMessage() {
        router.showError("Network down")
        XCTAssertEqual(router.errorMessage, "Network down")
    }

    // MARK: - Dismissals

    func test_dismissSheet_clearsSheet() {
        router.showJoin(code: "ABC123")
        XCTAssertNotNil(router.sheet)
        router.dismissSheet()
        XCTAssertNil(router.sheet)
    }

    func test_dismissCover_clearsCover() {
        router.showCreate()
        XCTAssertNotNil(router.cover)
        router.dismissCover()
        XCTAssertNil(router.cover)
    }

    func test_dismissError_clearsErrorMessage() {
        router.showError("Boom")
        XCTAssertNotNil(router.errorMessage)
        router.dismissError()
        XCTAssertNil(router.errorMessage)
    }
}
