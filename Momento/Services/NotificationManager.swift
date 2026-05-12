//
//  NotificationManager.swift
//  Momento
//
//  Local notifications — the "your shots are ready to reveal" reminder that
//  makes the "reveal later" half of the product actually work. Without this,
//  users have to remember to come back to the app exactly when releaseAt
//  hits. With it, the OS just tells them.
//
//  Push notifications are intentionally out of scope for launch. They need
//  device token registration, an APNs cert, and server-side trigger logic
//  (Supabase Edge Function or external service). Local notifications need
//  none of that — the OS schedules at event creation time and fires on its
//  own clock, even if the app is closed.
//
//  Scheduling lifecycle:
//    - Event created or joined → schedule "reveal ready" at releaseAt
//    - Event deleted or left → cancel the pending notification
//    - User taps the notification → post .receivedRevealLink so the home
//      screen can navigate into reveal for that event
//
//  Auth request timing: we ask the OS for permission the first time the
//  user creates or joins an event, in the moment they'd most expect to be
//  asked ("you'll want a reminder when this reveals"). iOS only shows the
//  system prompt once; subsequent requests return the cached answer.
//

import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps a "reveal is ready" local notification.
    /// userInfo["eventId"]: String — the event to navigate into.
    static let receivedRevealLink = Notification.Name("ReceivedRevealLink")
}

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Authorization

    /// Current OS-level authorization state. Read this to decide whether to
    /// ask, or whether scheduling will silently fail.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Ask for authorization. iOS shows the system prompt only on the first
    /// call per install — subsequent calls return the cached decision
    /// without re-prompting. Safe to call defensively before scheduling.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            debugLog("Notification authorization request failed: \(error)")
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedule a "your 10shots are ready" notification at the event's
    /// releaseAt. Idempotent — re-scheduling for the same event id replaces
    /// the existing request (so editing an event's release time updates
    /// the notification cleanly). No-op if releaseAt has already passed.
    ///
    /// Uses an absolute time-interval trigger (review H28). The previous
    /// implementation extracted date components via Calendar.current —
    /// implicitly the device's current timezone — so a user who created
    /// an event in London and was in Tokyo at releaseAt would get the
    /// alert at the Tokyo wall-clock equivalent of the London time, not
    /// at the original absolute UTC instant. Time-interval triggers
    /// fire at "now + N seconds" which is timezone-agnostic.
    func scheduleRevealReady(for event: Event) {
        let secondsUntil = event.releaseAt.timeIntervalSinceNow
        guard secondsUntil > 0 else {
            debugLog("📅 Skipping notification — releaseAt already passed for \(event.name)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Your 10shots are ready"
        content.body = "Reveal your shots from \(event.name)"
        content.sound = .default
        content.userInfo = [
            "eventId": event.id,
            "kind": "reveal-ready"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: secondsUntil,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier(for: event.id),
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                debugLog("Failed to schedule reveal notification: \(error)")
            } else {
                debugLog("📅 Scheduled reveal notification for '\(event.name)' in \(Int(secondsUntil))s (\(event.releaseAt))")
            }
        }
    }

    /// Cancel a previously scheduled reveal notification. Safe to call even
    /// if no request is pending for this event.
    func cancelReveal(for eventId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: eventId)])
    }

    /// Cancel every pending notification this manager has scheduled, plus
    /// clear delivered ones from Notification Center. Called from sign-out
    /// and account deletion so a second user on the same device doesn't
    /// get a "your reveal is ready" alert for the previous user's event.
    func cancelAllScheduled() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        debugLog("🗑️ Cancelled all scheduled notifications")
    }

    /// Convenience: request auth (if not yet decided) and schedule. Use this
    /// from event create/join paths where it's contextually clear why we'd
    /// want to remind the user. Returns the granted bool for callers that
    /// want to react to a denial.
    @discardableResult
    func requestAuthorizationAndSchedule(for event: Event) async -> Bool {
        let status = await authorizationStatus()
        let granted: Bool
        switch status {
        case .notDetermined:
            granted = await requestAuthorization()
        case .authorized, .provisional, .ephemeral:
            granted = true
        case .denied:
            granted = false
        @unknown default:
            granted = false
        }
        if granted {
            scheduleRevealReady(for: event)
        }
        return granted
    }

    // MARK: - Internal

    private func identifier(for eventId: String) -> String {
        "reveal-ready-\(eventId)"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Called when a notification fires while the app is in the foreground.
    /// We let iOS still present the banner — it's contextual and the user
    /// might be in a different screen.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Called when the user taps a notification (either from lock screen,
    /// notification center, or in-app banner). We post a NotificationCenter
    /// event so ContentView can navigate to the right reveal flow.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let eventId = userInfo["eventId"] as? String {
            // Hop to MainActor before posting; observers run there.
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .receivedRevealLink,
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            }
        }

        completionHandler()
    }
}
