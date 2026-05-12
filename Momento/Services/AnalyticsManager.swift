import Foundation
import PostHog
import UIKit

enum AnalyticsEvent: String {
    // Virality & organic spread (6 events)
    case eventCreated = "event_created"
    case inviteShared = "invite_shared"
    case inviteCardDownloaded = "invite_card_downloaded"
    case eventJoined = "event_joined"
    case shotShared = "shot_shared"
    case shotDownloaded = "shot_downloaded"

    // Core loop health (4 events)
    case appOpened = "app_opened"
    case shotCaptured = "shot_captured"
    case revealStarted = "reveal_started"
    case revealCompleted = "reveal_completed"

    // Capture limit experiment
    case shotLimitReached = "shot_limit_reached"

    // Account lifecycle (M5). Fired before AnalyticsManager.reset so the
    // event is attributed to the user being deleted.
    case accountDeleted = "account_deleted"

    // Surfaced errors — fired alongside user-facing alerts so we can see
    // error rates in PostHog independent of whether anyone reports them.
    // See `AnalyticsManager.trackError`.
    case errorSurfaced = "error_surfaced"
}

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private var isConfigured = false
    private var userId: String?
    private init() {}

    func configure() {
        guard !isConfigured else { return }

        let config = PostHogConfig(
            apiKey: PostHogConfiguration.apiKey,
            host: PostHogConfiguration.host
        )
        // Disable automatic tracking to reduce noise
        config.captureScreenViews = false  // We track screens manually
        config.captureApplicationLifecycleEvents = false  // We have app_opened
        config.sendFeatureFlagEvent = false  // Not using feature flags

        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    func identify(userId: String, username: String) {
        self.userId = userId

        PostHogSDK.shared.identify(userId, userProperties: [
            "username": username
        ])
    }

    func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        var props = properties
        if let userId = userId {
            props["user_id"] = userId
        }

        PostHogSDK.shared.capture(event.rawValue, properties: props)
    }

    /// Track a user-facing error so we can monitor error rates in PostHog.
    ///
    /// Fires alongside the user-visible alert/banner — not as a replacement.
    /// Goal: see "X% of users in the last 24h hit a load_events_failed"
    /// without having to wait for someone to report it.
    ///
    /// - Parameters:
    ///   - kind: short snake_case identifier for the error class. Keep stable
    ///     so the PostHog dashboard can group across releases.
    ///   - error: optional underlying error. Type name is captured;
    ///     localizedDescription is truncated to 200 chars to avoid leaking
    ///     user data (file paths, etc.) into telemetry.
    ///   - context: optional extra properties (event_id, retry_count, etc.).
    ///     Avoid passing anything that identifies a specific user beyond
    ///     `user_id`, which is already attached automatically.
    func trackError(kind: String, error: Error? = nil, context: [String: Any] = [:]) {
        var props: [String: Any] = context
        props["error_kind"] = kind
        if let error {
            props["error_type"] = String(describing: type(of: error))
            let message = error.localizedDescription
            props["error_message"] = message.count > 200 ? String(message.prefix(200)) + "…" : message
        }
        track(.errorSurfaced, properties: props)
    }

    /// Reset PostHog distinct-id and clear local join-timestamp keys.
    /// Called from sign-out and account deletion so PostHog identifies
    /// the next user fresh and the per-event "joined_at_<id>" keys don't
    /// accumulate forever on a shared device.
    func reset() {
        PostHogSDK.shared.reset()
        userId = nil
        AnalyticsManager.clearJoinStamps()
    }

    /// Records when the current user joined/created an event, so we can later
    /// compute `seconds_since_join` for the first `shot_captured` of that event.
    static func stampJoin(eventId: String, at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: "joined_at_\(eventId)")
    }

    /// Returns seconds elapsed since the user joined this event, or nil if unknown
    /// (e.g. they joined on another device, or before this code shipped).
    static func secondsSinceJoin(eventId: String, now: Date = .now) -> Int? {
        guard let joined = UserDefaults.standard.object(forKey: "joined_at_\(eventId)") as? Date else { return nil }
        return Int(now.timeIntervalSince(joined))
    }

    /// Wipe every `joined_at_*` UserDefaults entry. Called on sign-out so
    /// the next user on the same device doesn't inherit a previous
    /// user's join history.
    static func clearJoinStamps() {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("joined_at_") }
        for key in keys { defaults.removeObject(forKey: key) }
        if !keys.isEmpty { debugLog("🗑️ Cleared \(keys.count) join-timestamp keys") }
    }

    static func mapActivityToDestination(_ activity: UIActivity.ActivityType?) -> String {
        guard let activity = activity else { return "unknown" }

        switch activity {
        case .postToFacebook: return "facebook"
        case .postToTwitter: return "twitter"
        case .message: return "messages"
        case .mail: return "email"
        case .saveToCameraRoll: return "camera_roll"
        case .copyToPasteboard: return "copy"
        default:
            let raw = activity.rawValue.lowercased()
            if raw.contains("instagram") { return "instagram" }
            if raw.contains("whatsapp") { return "whatsapp" }
            if raw.contains("snapchat") { return "snapchat" }
            if raw.contains("telegram") { return "telegram" }
            return "other"
        }
    }
}
