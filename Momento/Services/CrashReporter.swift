//
//  CrashReporter.swift
//  Momento
//
//  Thin wrapper around Sentry so the rest of the codebase doesn't depend on
//  the SDK directly. Lets us swap or disable the reporter without touching
//  callsites, and keeps `import Sentry` confined to one file.
//
//  Init contract: call `CrashReporter.start()` exactly once from
//  `MomentoApp.init` before any other code runs. If the DSN isn't configured
//  (dev builds without secrets, CI), this is a no-op.
//

import Foundation
import Combine
import Sentry

enum CrashReporter {

    /// Holds the auth observer so it isn't released after `start()` returns.
    private static var cancellables = Set<AnyCancellable>()

    /// Initialise Sentry. Safe to call when the DSN is missing — it just
    /// does nothing in that case. Must run before any code that might crash;
    /// `MomentoApp.init` is the right place.
    static func start() {
        guard SentryConfiguration.isConfigured else {
            debugLog("🪦 CrashReporter: SENTRY_DSN not configured, skipping Sentry init")
            return
        }

        SentrySDK.start { options in
            options.dsn = SentryConfiguration.dsn
            options.environment = SentryConfiguration.environment

            // Sample rates. 1.0 = capture everything; turn down at scale if
            // event volume gets expensive. Performance tracing is 0 because
            // we don't have a perf budget to tune to yet.
            options.sampleRate = 1.0
            options.tracesSampleRate = 0.0

            // Screenshot + view hierarchy attachment (review H39).
            //
            // In Debug we keep both on — they're invaluable while iterating
            // and only the developer sees them. In Release we strip both:
            // a crash on the camera preview or the reveal gallery would
            // otherwise upload an actual photo of someone's face into
            // Sentry. That's not an acceptable production privacy posture
            // even with sendDefaultPii=false.
            #if DEBUG
            options.attachScreenshot = true
            options.attachViewHierarchy = true
            #else
            options.attachScreenshot = false
            options.attachViewHierarchy = false
            #endif

            // Don't ship debug breadcrumbs that contain secrets / PII. Sentry
            // does basic PII scrubbing by default; we keep `sendDefaultPii`
            // off to be explicit.
            options.sendDefaultPii = false

            // Defensive: even with attachScreenshot=false, strip any
            // image attachments that slipped through (custom SentrySDK
            // wrapper code, breadcrumb attachments, etc).
            options.beforeSend = { event in
                event.context?["screenshot"] = nil
                return event
            }

            #if DEBUG
            options.debug = true
            #endif
        }

        debugLog("✅ CrashReporter: Sentry started for environment \(SentryConfiguration.environment)")

        // Tag the current user on the Sentry scope whenever auth state
        // changes. `removeDuplicates` avoids re-setting the same id on every
        // unrelated SupabaseManager republish.
        SupabaseManager.shared.$currentUser
            .map { $0?.id.uuidString }
            .removeDuplicates()
            .sink { setUser(id: $0) }
            .store(in: &cancellables)
    }

    /// Capture a non-fatal error (e.g., a `catch` block we don't want to
    /// swallow silently but also don't want to crash on). Use sparingly —
    /// errors that already surface to the user via `EventStore.errorMessage`
    /// don't need to be reported separately.
    static func capture(_ error: Error, context: [String: Any]? = nil) {
        guard SentryConfiguration.isConfigured else { return }
        if let context {
            SentrySDK.capture(error: error) { scope in
                for (key, value) in context {
                    scope.setExtra(value: value, key: key)
                }
            }
        } else {
            SentrySDK.capture(error: error)
        }
    }

    /// Tag the current user on the Sentry scope so crashes / errors carry
    /// identity. Called after successful sign-in and again on sign-out
    /// (passing nil to clear).
    static func setUser(id: String?) {
        guard SentryConfiguration.isConfigured else { return }
        if let id {
            let user = User()
            user.userId = id
            SentrySDK.setUser(user)
        } else {
            SentrySDK.setUser(nil)
        }
    }
}
