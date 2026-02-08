import Foundation
import PostHog
import UIKit

enum AnalyticsEvent: String {
    // Premium conversion (5 events)
    case premiumRowViewed = "premium_row_viewed"
    case premiumEnabled = "premium_enabled"
    case premiumPurchased = "premium_purchased"
    case premiumUpgradePromptSeen = "premium_upgrade_prompt_seen"
    case premiumUpgradedLate = "premium_upgraded_late"
    case premiumPurchaseFailed = "premium_purchase_failed"
    case premiumPromptDismissed = "premium_prompt_dismissed"

    // Virality & organic spread (6 events)
    case momentoCreated = "momento_created"
    case inviteShared = "invite_shared"
    case inviteCardDownloaded = "invite_card_downloaded"
    case momentoJoined = "momento_joined"
    case photoShared = "photo_shared"
    case photoDownloaded = "photo_downloaded"

    // Core loop health (4 events)
    case appOpened = "app_opened"
    case photoCaptured = "photo_captured"
    case revealStarted = "reveal_started"
    case revealCompleted = "reveal_completed"
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

    func reset() {
        PostHogSDK.shared.reset()
        userId = nil
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
