//
//  MomentoApp.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//

import SwiftUI

@main
struct MomentoApp: App {
    var body: some Scene {
        WindowGroup {
            // This is your app's entry point: loads the main screen
            AuthenticationRootView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle OAuth callback from Google/Apple Sign In
                    handleOAuthCallback(url)
                }
        }
    }
    
    /// Handle OAuth callback URLs (e.g., momento://auth/callback)
    private func handleOAuthCallback(_ url: URL) {
        print("📱 Received OAuth callback: \(url)")
        
        Task {
            await SupabaseManager.shared.handleOAuthCallback(url: url)
        }
    }
}

