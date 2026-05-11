//
//  EventTests.swift
//  MomentoTests
//
//  Tests for the Event domain model: the three-state machine
//  (upcoming / live / revealed) and `isRevealReady` boundary logic.
//
//  These are pure-function tests — no Supabase, no async, no mocks. Important
//  because every screen reads `currentState(at:)` and a bug here would silently
//  misroute the whole UI (e.g. a "live" event rendering as "upcoming"
//  because of an off-by-one on the start boundary).
//

import XCTest
@testable import Momento

final class EventTests: XCTestCase {

    // MARK: - Test helpers

    private func makeEvent(
        startsAt: Date,
        endsAt: Date,
        releaseAt: Date
    ) -> Event {
        Event(
            name: "Test Event",
            startsAt: startsAt,
            endsAt: endsAt,
            releaseAt: releaseAt
        )
    }

    // MARK: - currentState — happy paths

    func test_state_isUpcoming_whenNowBeforeStart() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(60),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )
        XCTAssertEqual(event.currentState(at: now), .upcoming)
    }

    func test_state_isLive_whenNowBetweenStartAndEnd() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )
        XCTAssertEqual(event.currentState(at: now), .live)
    }

    func test_state_isRevealed_whenNowAfterEnd() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600),
            releaseAt: now.addingTimeInterval(-60)
        )
        XCTAssertEqual(event.currentState(at: now), .revealed)
    }

    // MARK: - currentState — boundary conditions
    //
    // These are the ones a bug would hide in. Doc says:
    //   upcoming — now < startsAt
    //   live     — startsAt <= now < endsAt
    //   revealed — now >= endsAt
    // So `startsAt == now` is live (not upcoming), and `endsAt == now` is
    // revealed (not live).

    func test_state_atStartsAtBoundary_isLive() {
        let now = Date()
        let event = makeEvent(
            startsAt: now,
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )
        XCTAssertEqual(event.currentState(at: now), .live, "Event becomes live at the exact moment of startsAt")
    }

    func test_state_atEndsAtBoundary_isRevealed() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now,
            releaseAt: now.addingTimeInterval(3600)
        )
        XCTAssertEqual(event.currentState(at: now), .revealed, "Event flips to revealed at the exact moment of endsAt — the camera locks here")
    }

    func test_state_oneSecondBeforeStart_isUpcoming() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(1),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )
        XCTAssertEqual(event.currentState(at: now), .upcoming)
    }

    func test_state_oneSecondBeforeEnd_isLive() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(1),
            releaseAt: now.addingTimeInterval(3600)
        )
        XCTAssertEqual(event.currentState(at: now), .live)
    }

    // MARK: - isRevealReady
    //
    // Doc says: revealed at endsAt, but the gallery only unlocks at releaseAt.
    // Between those two times the state is `revealed` but `isRevealReady` is
    // false — the "Reveals in X" copy applies.

    func test_isRevealReady_falseBeforeReleaseAt() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(-60),
            releaseAt: now.addingTimeInterval(60)
        )
        XCTAssertEqual(event.currentState(at: now), .revealed)
        XCTAssertFalse(event.isRevealReady(at: now), "Between endsAt and releaseAt, state is revealed but reveal is not yet unlocked")
    }

    func test_isRevealReady_trueAtReleaseAt() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600),
            releaseAt: now
        )
        XCTAssertTrue(event.isRevealReady(at: now), "Reveal unlocks at the exact moment of releaseAt")
    }

    func test_isRevealReady_trueAfterReleaseAt() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(-7200),
            endsAt: now.addingTimeInterval(-3600),
            releaseAt: now.addingTimeInterval(-60)
        )
        XCTAssertTrue(event.isRevealReady(at: now))
    }

    func test_isRevealReady_falseWhileLive() {
        let now = Date()
        let event = makeEvent(
            startsAt: now.addingTimeInterval(-60),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )
        XCTAssertEqual(event.currentState(at: now), .live)
        XCTAssertFalse(event.isRevealReady(at: now), "Live events shouldn't pretend reveal is ready")
    }
}
