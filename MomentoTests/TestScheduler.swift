//
//  TestScheduler.swift
//  MomentoTests
//
//  Scheduler that lets tests advance time deterministically. Each call to
//  `sleep(seconds:)` parks the caller on a continuation that we hold; calling
//  `advanceAll()` resumes every parked sleep at once.
//
//  This is the test side of the `Scheduler` protocol — pair with EventStore's
//  init that takes a `Scheduler` parameter. With it we can write assertions
//  like:
//
//      store.joinedEvent(event)
//      XCTAssertEqual(store.newlyJoinedEventId, event.id)
//      scheduler.advanceAll()
//      await Task.yield()
//      XCTAssertNil(store.newlyJoinedEventId)
//

import Foundation
@testable import Momento

@MainActor
final class TestScheduler: Scheduler {

    /// Sleep durations captured in order — useful for asserting that a code
    /// path scheduled the expected wait (e.g. exactly one 2.0s sleep).
    private(set) var requestedDelays: [TimeInterval] = []

    /// Pending continuations, paired with the seconds the caller asked for.
    private var pending: [(TimeInterval, CheckedContinuation<Void, Never>)] = []

    func sleep(seconds: TimeInterval) async {
        requestedDelays.append(seconds)
        await withCheckedContinuation { continuation in
            pending.append((seconds, continuation))
        }
    }

    /// Resume every pending sleep. Use after triggering the code path you
    /// want to advance past. You'll typically follow this with `Task.yield()`
    /// once or twice to let the resumed continuations run.
    func advanceAll() {
        let toResume = pending
        pending.removeAll()
        for (_, continuation) in toResume {
            continuation.resume()
        }
    }

    /// Resume only sleeps that requested <= `seconds`. Useful if a test
    /// wants to fire the 2-second sleep but not the 3-second one.
    func advance(by seconds: TimeInterval) {
        let toResume = pending.filter { $0.0 <= seconds }
        pending.removeAll { $0.0 <= seconds }
        for (_, continuation) in toResume {
            continuation.resume()
        }
    }

    var pendingCount: Int { pending.count }
}
