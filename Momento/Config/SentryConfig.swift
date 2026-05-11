//
//  SentryConfig.swift
//  Momento
//
//  Crash and error reporting configuration. Reads from Info.plist (set via
//  Secrets.xcconfig). If the DSN isn't configured, Sentry is simply not
//  initialised — the app continues to work, just without crash visibility.
//

import Foundation

enum SentryConfiguration {
    /// Sentry project DSN. Get from Sentry dashboard → Project Settings →
    /// Client Keys (DSN). Stored in Secrets.xcconfig as SENTRY_DSN.
    static let dsn: String = {
        guard let value = Bundle.main.infoDictionary?["SENTRY_DSN"] as? String,
              !value.isEmpty,
              !value.contains("YOUR_") else {
            // Crash reporting is non-critical for app function. Returning
            // empty means we skip Sentry init in dev / CI / dropped configs.
            return ""
        }
        return value
    }()

    /// Tells Sentry which environment events came from. Useful for filtering
    /// the dashboard to "prod only" once TestFlight builds start flowing.
    static let environment: String = {
        #if DEBUG
        return "debug"
        #else
        return "release"
        #endif
    }()

    static var isConfigured: Bool {
        !dsn.isEmpty && !dsn.contains("YOUR_")
    }
}
