//
//  InviteSheet.swift
//  Momento
//
//  Sheet for inviting friends to an event via share link or QR code
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteSheet: View {
    let event: Event
    let onDismiss: () -> Void

    @State private var showCopiedConfirmation = false
    @State private var qrCodeImage: UIImage?

    private var inviteLink: String {
        "https://momento.app/join/\(event.joinCode ?? "INVITE")"
    }

    private var shareText: String {
        """
        Join my Momento "\(event.name)"! 📸

        Use code: \(event.joinCode ?? "INVITE")

        Or open: \(inviteLink)
        """
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .momentoBackground()

                VStack(spacing: AppTheme.Spacing.sectionGap) {
                    // Event info header
                    VStack(spacing: AppTheme.Spacing.elementGap) {
                        Text(event.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            if let joinCode = event.joinCode {
                                HStack(spacing: 6) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 12))
                                    Text(joinCode)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(AppTheme.Colors.royalPurple)
                            }
                        }
                    }
                    .padding(.top, AppTheme.Spacing.sectionGap)

                    // QR Code
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                                .fill(Color.white)
                                .frame(width: 220, height: 220)

                            if let qrImage = qrCodeImage {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 180, height: 180)
                            } else {
                                ProgressView()
                                    .tint(.black)
                            }
                        }
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)

                        VStack(spacing: 4) {
                            Text("Scan to join")
                                .font(AppTheme.Fonts.bodySmall)
                                .foregroundColor(AppTheme.Colors.textTertiary)

                            Text("Code: \(event.joinCode ?? "INVITE")")
                                .font(AppTheme.Fonts.mono(size: 13))
                                .foregroundColor(AppTheme.Colors.royalPurple)
                        }
                    }
                    .onAppear {
                        generateQRCode()
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 16) {
                        Button {
                            copyInviteLink()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: showCopiedConfirmation ? "checkmark.circle.fill" : "link.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text(showCopiedConfirmation ? "Link Copied!" : "Copy Invite Link")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppTheme.Dimensions.primaryButtonHeight)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.Radii.tertiaryButton)
                                    .fill(showCopiedConfirmation ? Color.green : AppTheme.Colors.royalPurple)
                            )
                        }
                        .animation(.spring(response: 0.3), value: showCopiedConfirmation)

                        Button {
                            shareInvite()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Share Invite")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .buttonStyle(MomentoTertiaryButtonStyle())
                    }
                    .padding(.horizontal, AppTheme.Spacing.screenH)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Actions

    private func copyInviteLink() {
        UIPasteboard.general.string = inviteLink

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        showCopiedConfirmation = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedConfirmation = false
        }
    }

    private func shareInvite() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        var shareItems: [Any] = [shareText]

        if let qrImage = qrCodeImage {
            shareItems.append(qrImage)
        }

        let activityVC = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - QR Code Generation

    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        let data = Data(inviteLink.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return }

        let scale: CGFloat = 10
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            qrCodeImage = UIImage(cgImage: cgImage)
        }
    }
}

#Preview {
    let now = Date()
    return InviteSheet(
        event: Event(
            name: "NYE House Party",
            coverEmoji: "\u{1F389}",
            startsAt: now,
            endsAt: now.addingTimeInterval(6 * 3600),
            releaseAt: now.addingTimeInterval(24 * 3600),
            joinCode: "NYE2025"
        ),
        onDismiss: {}
    )
}
