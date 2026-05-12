//
//  ProfileView.swift
//  Momento
//
//  User profile screen with stats
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseManager = SupabaseManager.shared

    @State private var displayName: String?
    @State private var avatarUrl: String?
    @State private var avatarUpdatedAt: Date?
    @State private var userNumber: Int?
    @State private var stats: ProfileStats?
    @State private var isLoading = true
    @State private var isLoggingOut = false
    @State private var showLogoutConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.Spacing.screenH) {
                            headerSection

                            if let stats = stats {
                                statsSection(stats: stats)
                            }

                            Spacer(minLength: AppTheme.Spacing.ctaBottom)

                            #if DEBUG
                            Button("Replay Onboarding") {
                                hasSeenOnboarding = false
                                dismiss()
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                            #endif

                            signOutButton

                            deleteAccountButton
                        }
                        .padding(.horizontal, AppTheme.Spacing.screenH)
                        .padding(.top, 20)
                        .padding(.bottom, AppTheme.Spacing.ctaBottom)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    performDeleteAccount()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently deletes your account, every event you created, and every shot you took. This can't be undone.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadProfileData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            avatarPicker

            VStack(spacing: 6) {
                if let displayName = displayName {
                    Text(displayName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }

                if let userNumber = userNumber {
                    HStack(spacing: 4) {
                        if userNumber <= 100 {
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .medium))
                        }
                        Text(userNumber <= 100 ? "Founding Member" : "Member #\(userNumber)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textQuaternary)
                }
            }
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.12))
        )
    }

    /// Avatar with tap-to-change. Loads via AsyncImage with a query-string
    /// cache-buster derived from profiles.updated_at so a fresh upload
    /// shows immediately even though the storage path doesn't change.
    private var avatarPicker: some View {
        PhotosPicker(selection: $photoPickerItem,
                     matching: .images,
                     photoLibrary: .shared()) {
            ZStack {
                if let url = avatarURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            avatarFallback
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    avatarFallback
                }

                if isUploadingAvatar {
                    Circle().fill(Color.black.opacity(0.4)).frame(width: 100, height: 100)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .disabled(isUploadingAvatar)
        .onChange(of: photoPickerItem) { _, newItem in
            Task { await loadAvatar(from: newItem) }
        }
        .accessibilityLabel("Change profile photo")
    }

    private var avatarFallback: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 100, weight: .light))
            .foregroundColor(.white.opacity(0.9))
    }

    /// Bake updated_at into the URL as a cache-buster so changing the
    /// avatar takes effect immediately.
    private var avatarURL: URL? {
        guard let raw = avatarUrl, var components = URLComponents(string: raw) else { return nil }
        if let updatedAt = avatarUpdatedAt {
            components.queryItems = [URLQueryItem(name: "v", value: String(Int(updatedAt.timeIntervalSince1970)))]
        }
        return components.url
    }

    // MARK: - Stats Section

    private func statsSection(stats: ProfileStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STATS")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.5)

            StatsGridView(stats: stats)
        }
    }

    // MARK: - Sign Out Button

    private var signOutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            HStack(spacing: 8) {
                if isLoggingOut {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.textSecondary))
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }

                Text(isLoggingOut ? "Signing Out..." : "Sign Out")
            }
        }
        .buttonStyle(MomentoDestructiveButtonStyle())
        .disabled(isLoggingOut || isDeletingAccount)
    }

    // MARK: - Delete Account Button
    //
    // Lower visual weight than Sign Out — it's a permanent action that
    // shouldn't compete for prominence with the everyday flow. Apple's
    // Guideline 5.1.1(v) requires deletion be "easy to find," not the
    // primary affordance.

    private var deleteAccountButton: some View {
        Button {
            showDeleteAccountConfirmation = true
        } label: {
            HStack(spacing: 8) {
                if isDeletingAccount {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.red.opacity(0.7)))
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                }

                Text(isDeletingAccount ? "Deleting…" : "Delete Account")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(Color.red.opacity(0.85))
            .padding(.vertical, 8)
        }
        .disabled(isDeletingAccount || isLoggingOut)
    }

    // MARK: - Data Loading

    private func loadProfileData() async {
        isLoading = true

        guard let userId = supabaseManager.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            let profile = try await supabaseManager.getUserProfile(userId: userId)
            let profileStats = try await supabaseManager.getProfileStats()

            await MainActor.run {
                self.displayName = profile.displayName
                self.avatarUrl = profile.avatarUrl
                self.avatarUpdatedAt = profile.updatedAt
                self.userNumber = profileStats.userNumber
                self.stats = profileStats
                self.isLoading = false
            }
        } catch {
            debugLog("❌ Failed to load profile: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func performLogout() {
        isLoggingOut = true

        Task {
            do {
                try await supabaseManager.signOut()
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

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item else { return }
        await MainActor.run { isUploadingAvatar = true }
        defer { Task { @MainActor in isUploadingAvatar = false } }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            let resized = image.resizedForProfile()
            guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return }

            let publicURL = try await supabaseManager.uploadAvatar(jpegData: jpeg)
            await MainActor.run {
                self.avatarUrl = publicURL
                self.avatarUpdatedAt = .now
            }
        } catch {
            await MainActor.run {
                errorMessage = "Couldn't upload that photo."
                showErrorAlert = true
            }
        }
    }

    private func performDeleteAccount() {
        isDeletingAccount = true

        Task {
            do {
                try await supabaseManager.deleteAccount()
                AnalyticsManager.shared.reset()
                await MainActor.run {
                    isDeletingAccount = false
                    dismiss()
                }
            } catch {
                AnalyticsManager.shared.trackError(kind: "delete_account_failed", error: error)
                await MainActor.run {
                    isDeletingAccount = false
                    errorMessage = "Couldn't delete your account: \(error.localizedDescription). Please try again, or contact support if the problem persists."
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - UIImage helpers

private extension UIImage {
    /// Center-crop + downscale to 512×512 for avatar upload.
    func resizedForProfile(maxSide: CGFloat = 512) -> UIImage {
        let cropSide = min(size.width, size.height)
        let cropOrigin = CGPoint(
            x: (size.width - cropSide) / 2,
            y: (size.height - cropSide) / 2
        )
        let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: cropSide, height: cropSide))

        guard let cgImage = cgImage?.cropping(to: cropRect) else { return self }
        let cropped = UIImage(cgImage: cgImage, scale: self.scale, orientation: imageOrientation)

        let target = CGSize(width: min(cropSide, maxSide), height: min(cropSide, maxSide))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

#Preview {
    ProfileView()
}
