//
//  MilestoneTracker.swift
//  Momento
//
//  Detects roll-milestone crossings (half roll, full roll) for live events.
//
//  Fire rules (spec §3):
//    - At most once per event per threshold — fired state persists in
//      UserDefaults (same durability pattern as RevealStateManager) so
//      re-launches and re-polls never replay a celebration.
//    - The first observation of an event only records a baseline and never
//      fires — joining late (or relaunching) into an event already past
//      half-roll must not replay it. Baselines are intentionally in-memory:
//      after a relaunch the first check re-records a baseline, and any
//      threshold that already fired is blocked by the persisted set.
//

import Foundation

enum RollMilestone: String {
    case half
    case full
}

final class MilestoneTracker {

    private let defaults: UserDefaults
    private let firedKey = "firedRollMilestones"

    /// Last-seen taken-count per event id. In-memory by design (see header).
    private var baselines: [String: Int] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Feed the latest (taken, total) for an event. Returns a milestone the
    /// moment a refresh crosses a threshold the baseline was below and that
    /// hasn't fired before — nil otherwise.
    func check(eventId: String, taken: Int, total: Int) -> RollMilestone? {
        guard total > 0 else { return nil }

        guard let baseline = baselines[eventId] else {
            baselines[eventId] = taken
            return nil
        }
        baselines[eventId] = max(baseline, taken)

        // Full first: crossing both at once celebrates the bigger moment.
        for milestone in [RollMilestone.full, .half] {
            let threshold = milestone == .full ? total : total / 2
            if taken >= threshold, baseline < threshold, !hasFired(eventId, milestone) {
                markFired(eventId, milestone)
                return milestone
            }
        }
        return nil
    }

    // MARK: - Persistence

    private func key(_ eventId: String, _ milestone: RollMilestone) -> String {
        "\(eventId):\(milestone.rawValue)"
    }

    private func hasFired(_ eventId: String, _ milestone: RollMilestone) -> Bool {
        firedSet().contains(key(eventId, milestone))
    }

    private func markFired(_ eventId: String, _ milestone: RollMilestone) {
        var fired = firedSet()
        fired.insert(key(eventId, milestone))
        defaults.set(Array(fired), forKey: firedKey)
    }

    private func firedSet() -> Set<String> {
        Set(defaults.stringArray(forKey: firedKey) ?? [])
    }
}
