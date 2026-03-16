//
//  CreateStep3ShareView.swift
//  Momento
//
//  Step 3 of Create Momento flow: QR code invite page
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct CreateStep3ShareView: View {
    let momentoName: String
    let joinCode: String
    let startsAt: Date
    let hostName: String
    let onDone: () -> Void

    @State private var copiedCode = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var qrCodeImage: UIImage?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()

                Text("Step 3 of 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            // Main content
            VStack(spacing: 32) {
                // Title
                VStack(spacing: 8) {
                    Text("Invite your\npeople")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Text("Scan or share the code below")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }

                // QR Code
                VStack(spacing: 20) {
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

                    if copiedCode {
                        Text("Copied to clipboard")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .transition(.opacity)
                    }
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 14) {
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

                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
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
        HapticsManager.shared.medium()

        withAnimation { copiedCode = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedCode = false }
        }
    }

    private func shareInvite() {
        shareImage = InviteCardRenderer.render(
            eventName: momentoName,
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

        filter.message = Data(joinCode.utf8)
        filter.correctionLevel = "M"

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
    CreateStep3ShareView(
        momentoName: "Sopranos Party",
        joinCode: "SOPRAN",
        startsAt: Date(),
        hostName: "Asad",
        onDone: {}
    )
}
