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

    // Virality & organic spread (5 events)
    case momentoCreated = "momento_created"
    case inviteShared = "invite_shared"
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
    private var isPremiumUser: Bool = false

    private init() {}

    func configure() {
        guard !isConfigured else { return }

        let config = PostHogConfig(apiKey: PostHogConfiguration.apiKey)
        config.host = PostHogConfiguration.host
        PostHogSDK.shared.setup(config)
        isConfigured = true
    }

    func identify(userId: String, username: String, isPremium: Bool) {
        self.userId = userId
        self.isPremiumUser = isPremium

        PostHogSDK.shared.identify(userId, userProperties: [
            "username": username,
            "is_premium_user": isPremium
        ])
    }

    func updatePremiumStatus(_ isPremium: Bool) {
        self.isPremiumUser = isPremium
        if isPremium {
            PostHogSDK.shared.capture("$set", properties: [
                "$set": ["is_premium_user": true]
            ])
        }
    }

    func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        var props = properties
        if let userId = userId {
            props["user_id"] = userId
        }
        props["is_premium_user"] = isPremiumUser

        PostHogSDK.shared.capture(event.rawValue, properties: props)
    }

    func reset() {
        PostHogSDK.shared.reset()
        userId = nil
        isPremiumUser = false
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
