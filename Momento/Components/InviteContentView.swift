//
//  InviteContentView.swift
//  Momento
//
//  Shared invite UI: QR code, copy code, share invite card.
//  Used by CreateStep3ShareView (creation flow) and InviteSheet (long press).
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteContentView: View {
    let eventName: String
    let joinCode: String
    let startsAt: Date
    let hostName: String

    @State private var copiedCode = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var qrCodeImage: UIImage?
    @State private var appeared = false

    private var inviteURL: String {
        "https://momento.app/join/\(joinCode)"
    }

    private var shareMessage: String {
        """
        Join my Momento: \(eventName)!

        Take photos \u{2192} Wait for reveal \u{2192} See the magic

        Code: \(joinCode)
        Get the app: momento.app
        """
    }

    var body: some View {
        VStack(spacing: 20) {
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
                    ProgressView().tint(.black)
                }
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.9)

            // Join code — tappable to copy
            Button(action: copyCode) {
                HStack(spacing: 10) {
                    Text(joinCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(.white)

                    Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(copiedCode ? .green : .white.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(copiedCode ? 0.2 : 0.08), lineWidth: 1)
                        )
                )
            }
            .animation(.spring(response: 0.3), value: copiedCode)

            if copiedCode {
                Text("Copied to clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .transition(.opacity)
            }

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
                .cornerRadius(28)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            generateQRCode()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image, shareMessage]) { activityType, completed in
                    if completed {
                        let destination = AnalyticsManager.mapActivityToDestination(activityType)
                        AnalyticsManager.shared.track(.inviteShared, properties: [
                            "join_code": joinCode,
                            "destination": destination
                        ])
                    }
                }
            } else {
                ShareSheet(items: [shareMessage]) { activityType, completed in
                    if completed {
                        let destination = AnalyticsManager.mapActivityToDestination(activityType)
                        AnalyticsManager.shared.track(.inviteShared, properties: [
                            "join_code": joinCode,
                            "destination": destination
                        ])
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func copyCode() {
        UIPasteboard.general.string = joinCode
        HapticsManager.shared.medium()
        withAnimation { copiedCode = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedCode = false }
        }
    }

    private func shareInvite() {
        shareImage = InviteCardRenderer.render(
            eventName: eventName,
            joinCode: joinCode,
            startDate: startsAt,
            hostName: hostName
        )
        showShareSheet = true
    }

    // MARK: - QR Code

    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(inviteURL.utf8)
        filter.correctionLevel = "H"
        guard let outputImage = filter.outputImage else { return }
        let scale: CGFloat = 10
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            qrCodeImage = UIImage(cgImage: cgImage)
        }
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
    ZStack {
        Color.black.ignoresSafeArea()
        InviteContentView(
            eventName: "Sopranos Party",
            joinCode: "SOPRAN",
            startsAt: Date(),
            hostName: "Asad"
        )
    }
}
