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

    @State private var username: String?
    @State private var isLoggingOut = false
    @State private var showLogoutConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showCardPreview = false

    // Royal purple accent (matches main app)
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (matches main app)
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.08, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // User Info Section in card
                    VStack(spacing: 20) {
                        // Profile icon with glow
                        ZStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80, weight: .light))
                                .foregroundColor(royalPurple)
                                .blur(radius: 15)
                                .opacity(0.5)
                            
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80, weight: .light))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        VStack(spacing: 8) {
                            // Username
                            if let username = username {
                                Text("@\(username)")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                            .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    // Card Preview Button (Debug)
                    Button {
                        showCardPreview = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.stack")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Preview Card States")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(royalPurple.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)

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
                        .frame(height: 54)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isLoggingOut)
                    .padding(.horizontal, 24)
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
            .task {
                await loadUsername()
            }
            .fullScreenCover(isPresented: $showCardPreview) {
                CardPreviewView()
            }
        }
    }

    private func loadUsername() async {
        guard let userId = supabaseManager.currentUser?.id else { return }

        do {
            let profile = try await supabaseManager.getUserProfile(userId: userId)
            await MainActor.run {
                username = profile.username
            }
        } catch {
            print("❌ Failed to load username: \(error)")
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

