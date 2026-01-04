//
//  SettingsView.swift
//  Momento
//
//  Settings screen with logout functionality
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    @State private var isLoggingOut = false
    @State private var showLogoutConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (matches app aesthetic)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.2, green: 0.1, blue: 0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // User Info Section
                    VStack(spacing: 16) {
                        // Profile icon
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(.white.opacity(0.8))
                        
                        // User email
                        if let email = supabaseManager.currentUser?.email {
                            Text(email)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        // User ID (truncated)
                        if let userId = supabaseManager.currentUser?.id {
                            Text("ID: \(String(userId.uuidString.prefix(8)))...")
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // Logout Button
                    Button {
                        showLogoutConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            if isLoggingOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            
                            Text(isLoggingOut ? "Signing Out..." : "Sign Out")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoggingOut)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    performLogout()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func performLogout() {
        isLoggingOut = true
        
        Task {
            do {
                try await supabaseManager.signOut()
                // AuthenticationRootView will auto-handle navigation when isAuthenticated = false
                await MainActor.run {
                    isLoggingOut = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoggingOut = false
                    errorMessage = "Failed to sign out: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

