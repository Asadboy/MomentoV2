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

    private var joinCode: String {
        event.joinCode ?? "INVITE"
    }

    private var inviteLink: String {
        "https://momento.app/join/\(joinCode)"
    }

    private var shareText: String {
        """
        Join my Momento "\(event.name)"!

        Use code: \(joinCode)

        Or open: \(inviteLink)
        """
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Main content
                VStack(spacing: 28) {
                    // Event name
                    Text(event.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // QR Code
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .frame(width: 200, height: 200)

                        if let qrImage = qrCodeImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 170, height: 170)
                        } else {
                            ProgressView()
                                .tint(.black)
                        }
                    }

                    // Join code — tappable to copy
                    Button(action: copyCode) {
                        HStack(spacing: 10) {
                            Text(joinCode)
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .tracking(4)
                                .foregroundColor(.white)

                            Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(showCopiedConfirmation ? .green : .white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(showCopiedConfirmation ? 0.2 : 0.08), lineWidth: 1)
                                )
                        )
                    }
                    .animation(.spring(response: 0.3), value: showCopiedConfirmation)

                    if showCopiedConfirmation {
                        Text("Copied to clipboard")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .transition(.opacity)
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 14) {
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
                        .cornerRadius(28)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            .onAppear {
                generateQRCode()
            }
        }
    }

    // MARK: - Actions

    private func copyCode() {
        UIPasteboard.general.string = joinCode
        HapticsManager.shared.medium()

        withAnimation { showCopiedConfirmation = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedConfirmation = false }
        }
    }

    private func shareInvite() {
        HapticsManager.shared.medium()

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
