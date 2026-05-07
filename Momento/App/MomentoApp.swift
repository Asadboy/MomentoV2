//
//  MomentoApp.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//

import SwiftUI

extension Notification.Name {
    /// Posted when a Universal Link or join URL is received with a join code.
    /// userInfo["code"]: String — uppercased 6-char code.
    static let receivedJoinLink = Notification.Name("ReceivedJoinLink")
}

@main
struct MomentoApp: App {
    init() {
        // Initialize PostHog analytics on app launch
        AnalyticsManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            // This is your app's entry point: loads the main screen
            AuthenticationRootView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle OAuth callback from Google/Apple Sign In
                    handleOAuthCallback(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        handleUniversalLink(url)
                    }
                }
        }
    }

    /// Handle OAuth callback URLs (e.g., momento://auth/callback)
    private func handleOAuthCallback(_ url: URL) {
        debugLog("📱 Received OAuth callback: \(url)")

        Task {
            await SupabaseManager.shared.handleOAuthCallback(url: url)
        }
    }

    /// Handle Universal Links such as https://10shots.app/join/<CODE>.
    /// Extracts the code and posts a notification for the home screen to act on.
    private func handleUniversalLink(_ url: URL) {
        debugLog("📱 Received Universal Link: \(url)")
        guard let code = JoinLinkParser.extractCode(from: url.absoluteString) else { return }
        NotificationCenter.default.post(
            name: .receivedJoinLink,
            object: nil,
            userInfo: ["code": code]
        )
    }
}

/// Shared parser for join URLs/codes. Used by both the Universal Link handler
/// and the in-sheet clipboard/QR/manual entry flows.
enum JoinLinkParser {
    /// Returns an uppercased 6-char join code if one can be extracted, otherwise nil.
    static func extractCode(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        // momento://join/CODE (legacy URL scheme)
        if lower.hasPrefix("momento://join/") {
            let suffix = String(trimmed.dropFirst("momento://join/".count))
            return normalize(suffix)
        }

        // https://{momento.app,10shots.app,...}/join/CODE
        if lower.contains("/join/"),
           let tail = trimmed.components(separatedBy: "/join/").last {
            return normalize(tail)
        }

        // Raw 6-char code
        return normalize(trimmed)
    }

    private static func normalize(_ raw: String) -> String? {
        let token = raw.components(separatedBy: CharacterSet(charactersIn: "?/#")).first ?? raw
        let alnum = token.filter { $0.isLetter || $0.isNumber }
        guard alnum.count == 6 else { return nil }
        return alnum.uppercased()
    }
}

