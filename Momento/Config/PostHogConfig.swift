import Foundation

enum PostHogConfiguration {
    static let apiKey = "phc_KVNhcvv03c91MCTm6YmeVxmiM2rglQXKf3Vh0F9YNRm"
    static let host = "https://eu.i.posthog.com"

    static var isConfigured: Bool {
        return !apiKey.isEmpty && apiKey != "phc_YOUR_PROJECT_API_KEY"
    }
}
