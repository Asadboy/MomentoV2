//
//  UsernameSelectionView.swift
//  Momento
//
//  Username selection screen for new users
//

import SwiftUI

struct UsernameSelectionView: View {
    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var username: String = ""
    @State private var validationState: ValidationState = .idle
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var validationTask: Task<Void, Never>?

    enum ValidationState {
        case idle
        case validating
        case available
        case unavailable(String)
        case invalid(String)
    }

    var body: some View {
        ZStack {
            Color.clear
                .momentoGlowOrb()

            VStack(spacing: 40) {
                Spacer()

                // Welcome section
                VStack(spacing: 12) {
                    Text("Choose your username")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("This is how others will see you")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .padding(.horizontal, AppTheme.Spacing.screenH)

                Spacer()

                // Input + button directly on gradient, no card
                VStack(spacing: 20) {
                    // Username input with validation
                    VStack(spacing: AppTheme.Spacing.elementGap) {
                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(AppTheme.Colors.royalPurple)

                            TextField("username", text: $username)
                                .font(AppTheme.Fonts.body)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .onChange(of: username) { _, newValue in
                                    onUsernameChange(newValue)
                                }

                            validationIcon
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radii.innerElement)
                                .fill(AppTheme.Colors.fieldFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radii.innerElement)
                                .stroke(AppTheme.Colors.fieldStroke, lineWidth: 1)
                        )

                        if case .unavailable(let msg) = validationState {
                            Text(msg)
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if case .invalid(let msg) = validationState {
                            Text(msg)
                                .font(AppTheme.Fonts.caption)
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // Continue button
                    Button {
                        Task {
                            await submitUsername()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            }

                            Text(isSubmitting ? "Setting username..." : "Continue")
                        }
                    }
                    .buttonStyle(MomentoPrimaryButtonStyle())
                    .disabled(!isContinueEnabled)
                }
                .padding(.horizontal, AppTheme.Spacing.screenH)

                // Helper text
                Text("3-20 characters, letters, numbers, and underscores")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .padding(.horizontal, AppTheme.Spacing.screenH)

                // Error message from submission
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
        }
        .onDisappear {
            validationTask?.cancel()
        }
    }

    // MARK: - Validation Icon

    @ViewBuilder
    private var validationIcon: some View {
        switch validationState {
        case .idle:
            EmptyView()

        case .validating:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.royalPurple))
                .scaleEffect(0.8)

        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.green)

        case .unavailable:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.red)

        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.orange)
        }
    }

    // MARK: - Computed Properties

    private var isContinueEnabled: Bool {
        if case .available = validationState, !isSubmitting {
            return true
        }
        return false
    }

    // MARK: - Validation Logic

    private func validateUsernameFormat(_ username: String) -> Bool {
        let uppercased = username.uppercased()
        if uppercased == "JB" || uppercased == "KW" {
            return true
        }

        guard username.count >= 3 && username.count <= 20 else { return false }

        let pattern = "^[a-zA-Z0-9_]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: username.utf16.count)
        return regex?.firstMatch(in: username, range: range) != nil
    }

    private func onUsernameChange(_ newValue: String) {
        validationTask?.cancel()

        if newValue.isEmpty {
            validationState = .idle
            return
        }

        if !validateUsernameFormat(newValue) {
            validationState = .invalid("3-20 characters, letters, numbers, and underscores only")
            return
        }

        validationState = .validating
        validationTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            do {
                let isAvailable = try await supabaseManager.checkUsernameAvailability(newValue)
                await MainActor.run {
                    validationState = isAvailable
                        ? .available
                        : .unavailable("Username is already taken")
                }
            } catch {
                await MainActor.run {
                    validationState = .invalid("Couldn't check availability: \(error.localizedDescription)")
                }
            }
        }
    }

    private func submitUsername() async {
        guard case .available = validationState else { return }
        guard let userId = supabaseManager.currentUser?.id else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await supabaseManager.updateUsername(userId: userId, newUsername: username)
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("UsernameUpdated"), object: nil)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

#Preview {
    UsernameSelectionView()
}
