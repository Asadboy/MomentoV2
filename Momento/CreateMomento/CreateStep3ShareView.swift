//
//  CreateStep3ShareView.swift
//  Momento
//
//  Step 3 of Create Momento flow: Share your momento
//

import Photos
import SwiftUI

struct CreateStep3ShareView: View {
    let momentoName: String
    let joinCode: String
    let startsAt: Date
    let hostName: String
    let isPremium: Bool
    let onDone: () -> Void

    @State private var copiedCode = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showDownloadSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()

                Text("Step 3 of 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Main content
            VStack(spacing: 24) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)
                }

                // Title
                VStack(spacing: 12) {
                    Text("Invite your people")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Share with friends to invite them")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Invite Card
                InviteCardView(
                    eventName: momentoName,
                    joinCode: joinCode,
                    startDate: startsAt,
                    hostName: hostName,
                    isPremium: isPremium
                )
                .padding(.horizontal, 30)

                // Copy code button
                Button(action: copyCode) {
                    HStack(spacing: 8) {
                        Text(joinCode)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .tracking(2)

                        Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(copiedCode ? .green : .white.opacity(0.8))
                }

                if copiedCode {
                    Text("Copied!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                // Share button
                Button(action: shareInvite) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))

                        Text("Share Invite")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(16)
                }

                // Download Card button
                Button(action: downloadCard) {
                    HStack(spacing: 8) {
                        Image(systemName: showDownloadSuccess ? "checkmark" : "arrow.down.to.line")
                            .font(.system(size: 15, weight: .semibold))
                        Text(showDownloadSuccess ? "Saved!" : "Download Card")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(showDownloadSuccess ? .green : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(16)
                }

                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(backgroundGradient)
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image, shareMessage]) { activityType, completed in
                    if completed {
                        let destination = AnalyticsManager.mapActivityToDestination(activityType)
                        AnalyticsManager.shared.track(.inviteShared, properties: [
                            "join_code": joinCode,
                            "destination": destination,
                            "is_premium": isPremium
                        ])
                    }
                }
            } else {
                ShareSheet(items: [shareMessage]) { activityType, completed in
                    if completed {
                        let destination = AnalyticsManager.mapActivityToDestination(activityType)
                        AnalyticsManager.shared.track(.inviteShared, properties: [
                            "join_code": joinCode,
                            "destination": destination,
                            "is_premium": isPremium
                        ])
                    }
                }
            }
        }
    }

    private var shareMessage: String {
        """
        Join my Momento: \(momentoName)!

        Take photos \u{2192} Wait for reveal \u{2192} See the magic

        Code: \(joinCode)
        Get the app: momento.app
        """
    }

    private func copyCode() {
        UIPasteboard.general.string = joinCode

        withAnimation {
            copiedCode = true
        }

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedCode = false
            }
        }

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    private func shareInvite() {
        // Render the invite card image
        shareImage = InviteCardRenderer.render(
            eventName: momentoName,
            joinCode: joinCode,
            startDate: startsAt,
            hostName: hostName,
            isPremium: isPremium
        )

        showShareSheet = true
    }

    private func downloadCard() {
        // Render the invite card image
        guard let image = InviteCardRenderer.render(
            eventName: momentoName,
            joinCode: joinCode,
            startDate: startsAt,
            hostName: hostName,
            isPremium: isPremium
        ) else { return }

        // Request photo library permission before saving
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    // Permission denied - don't show success feedback
                    return
                }

                // Save to Photos
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

                // Track the download event (only on success)
                AnalyticsManager.shared.track(.inviteCardDownloaded, properties: [
                    "event_name": momentoName
                ])

                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                // Show success feedback
                withAnimation {
                    showDownloadSuccess = true
                }

                // Reset after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showDownloadSuccess = false
                    }
                }
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.12),
                Color(red: 0.08, green: 0.06, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var completionHandler: ((UIActivity.ActivityType?, Bool) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { activityType, completed, _, _ in
            completionHandler?(activityType, completed)
        }
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    CreateStep3ShareView(
        momentoName: "Sopranos Party",
        joinCode: "SOPRAN",
        startsAt: Date(),
        hostName: "Asad",
        isPremium: false,
        onDone: {}
    )
}
