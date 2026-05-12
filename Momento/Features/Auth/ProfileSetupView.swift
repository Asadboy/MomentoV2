//
//  ProfileSetupView.swift
//  Momento
//
//  First-launch profile setup. Replaces the previous UsernameSelectionView —
//  10shots no longer uses @-handles, so the only required field is the
//  display name that appears in the lobby roster and reveal attribution.
//  Avatar upload is offered here but always skippable; users can add or
//  change a photo later from ProfileView.
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    /// Called once the profile has been saved server-side. The parent
    /// (AuthenticationRootView) advances to the next state.
    var onComplete: () -> Void

    @StateObject private var supabaseManager = SupabaseManager.shared
    @State private var displayName: String = ""
    @State private var avatarImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isSubmitting = false
    @State private var isUploadingAvatar = false
    @State private var errorMessage: String?

    private var sanitisedName: String {
        DisplayName.sanitise(displayName)
    }

    private var isContinueEnabled: Bool {
        DisplayName.isValid(displayName) && !isSubmitting
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                VStack(spacing: 10) {
                    Text("What should we call you?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("This is how others see you in shared events.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppTheme.Spacing.screenH)

                avatarPicker

                displayNameField

                Spacer()

                continueButton

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, AppTheme.Spacing.screenH)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 32)
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task { await loadAvatar(from: newItem) }
        }
    }

    // MARK: - Avatar picker

    private var avatarPicker: some View {
        PhotosPicker(selection: $photoPickerItem,
                     matching: .images,
                     photoLibrary: .shared()) {
            ZStack {
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 112, height: 112)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 112, height: 112)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.18),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        )
                        .overlay(
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white.opacity(0.45))
                                Text("Add photo")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        )
                }

                if isUploadingAvatar {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 112, height: 112)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .disabled(isUploadingAvatar)
        .accessibilityLabel("Choose a profile photo")
    }

    // MARK: - Display-name field

    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Your name", text: $displayName)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.innerElement)
                        .fill(AppTheme.Colors.fieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.innerElement)
                        .stroke(AppTheme.Colors.fieldStroke, lineWidth: 1)
                )
                .onChange(of: displayName) { _, newValue in
                    // Silent emoji-strip + length cap. Users see what's
                    // accepted, never see a scary "invalid character".
                    let cleaned = DisplayName.sanitise(newValue)
                    if cleaned != newValue { displayName = cleaned }
                }

            Text("Letters, numbers, and punctuation. No emoji.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textQuaternary)
                .padding(.leading, 4)
        }
        .padding(.horizontal, AppTheme.Spacing.screenH)
    }

    // MARK: - Continue button

    private var continueButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                }
                Text(isSubmitting ? "Saving…" : "Continue")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(isContinueEnabled ? .black : .white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isContinueEnabled ? Color.white : Color.white.opacity(0.08))
            .cornerRadius(28)
        }
        .disabled(!isContinueEnabled)
        .padding(.horizontal, AppTheme.Spacing.screenH)
    }

    // MARK: - Submission

    private func submit() async {
        guard let userId = supabaseManager.currentUser?.id else { return }
        guard DisplayName.isValid(displayName) else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            try await supabaseManager.updateDisplayName(userId: userId, displayName: sanitisedName)
            await MainActor.run {
                isSubmitting = false
                onComplete()
            }
        } catch {
            await MainActor.run {
                isSubmitting = false
                errorMessage = "Couldn't save: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Avatar loading

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item else { return }
        await MainActor.run { isUploadingAvatar = true }
        defer { Task { @MainActor in isUploadingAvatar = false } }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }

            let resized = image.resizedForAvatar()
            guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return }

            try await supabaseManager.uploadAvatar(jpegData: jpeg)
            await MainActor.run { self.avatarImage = resized }
        } catch {
            await MainActor.run {
                errorMessage = "Couldn't upload that photo. You can add one later."
            }
        }
    }
}

// MARK: - UIImage helpers

private extension UIImage {
    /// Center-crop + downscale to 512×512 — plenty for avatar display.
    func resizedForAvatar(maxSide: CGFloat = 512) -> UIImage {
        let scale = maxSide / min(size.width, size.height)
        let cropSide = min(size.width, size.height)
        let cropOrigin = CGPoint(
            x: (size.width - cropSide) / 2,
            y: (size.height - cropSide) / 2
        )
        let cropRect = CGRect(origin: cropOrigin, size: CGSize(width: cropSide, height: cropSide))

        guard let cgImage = cgImage?.cropping(to: cropRect) else { return self }
        let cropped = UIImage(cgImage: cgImage, scale: self.scale, orientation: imageOrientation)

        let target = CGSize(width: cropSide * scale, height: cropSide * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

#Preview {
    ProfileSetupView(onComplete: {})
}
