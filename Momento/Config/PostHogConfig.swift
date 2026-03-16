//
//  PostHogConfig.swift
//  Momento
//
//  PostHog analytics configuration — reads from Info.plist (set via Secrets.xcconfig)
//

import Foundation

enum PostHogConfiguration {
    static let apiKey: String = {
        guard let value = Bundle.main.infoDictionary?["POSTHOG_API_KEY"] as? String, !value.isEmpty, !value.contains("YOUR_") else {
            // Analytics is non-critical — don't crash, just return empty
            return ""
        }
        return value
    }()

    static let host: String = {
        guard let value = Bundle.main.infoDictionary?["POSTHOG_HOST"] as? String, !value.isEmpty else {
            return "https://eu.i.posthog.com"
        }
        return value
    }()

    static var isConfigured: Bool {
        !apiKey.isEmpty && !apiKey.contains("YOUR_")
    }
}
