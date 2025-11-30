//
//  AuthenticationRootView.swift
//  Momento
//
//  Root view that handles authentication state
//

import SwiftUI

struct AuthenticationRootView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var isCheckingAuth = true
    
    // 🚨 DEBUG: Set to true to bypass sign-in screen for testing
    // ⚠️ REMEMBER TO SET BACK TO FALSE BEFORE PRODUCTION!
    private let DEBUG_SKIP_AUTH = false
    
    var body: some View {
        Group {
            if DEBUG_SKIP_AUTH {
                // 🧪 DEBUG MODE: Skip authentication entirely
                ContentView()
            } else if isCheckingAuth {
                // Show splash screen while checking auth
                ZStack {
                    Color(red: 0.1, green: 0.1, blue: 0.2)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(.white)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            } else if supabaseManager.isAuthenticated {
                // User is signed in - show main app
                ContentView()
            } else {
                // User not signed in - show sign in screen
                SignInView()
            }
        }
        .task {
            // Check for existing session on app launch
            await supabaseManager.checkSession()
            
            // Small delay to prevent flash
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                isCheckingAuth = false
            }
        }
    }
}

#Preview {
    AuthenticationRootView()
}

