//
//  Scheduler.swift
//  Momento
//
//  Tiny abstraction over wall-clock waits so time-coupled behaviour
//  (currently the 2-second new-event glow auto-clear and the 3-second
//  post-upload reconciliation) can be tested deterministically.
//
//  Production uses `LiveScheduler` which just hands off to `Task.sleep`.
//  Tests pass a `TestScheduler` (defined under MomentoTests/) that captures
//  sleep requests so we can advance time programmatically and assert on the
//  post-delay state without actually waiting.
//
//  Kept intentionally minimal: one `sleep(seconds:)` method. No "schedule
//  this closure at time T" — anything we'd want for that is composable from
//  Swift Concurrency's existing primitives.
//

import Foundation

/// Anything that can pause an async call for a given number of seconds.
/// Deliberately not MainActor-isolated — the only method is async, and an
/// await suspension hops off the calling actor anyway. Test impls (which
/// hold mutable state) can pick their own isolation; the live impl is
/// stateless and threadsafe.
protocol Scheduler: AnyObject, Sendable {
    func sleep(seconds: TimeInterval) async
}

/// Production scheduler — bridges to Swift's `Task.sleep`.
final class LiveScheduler: Scheduler {
    init() {}

    func sleep(seconds: TimeInterval) async {
        let ns = UInt64(max(0, seconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
    }
}
