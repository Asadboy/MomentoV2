import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteCardView: View {
    let eventName: String
    let joinCode: String
    let startDate: Date
    let hostName: String

    var body: some View {
        VStack(spacing: 0) {
            Text(eventName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, AppTheme.Spacing.screenH)
                .padding(.top, AppTheme.Spacing.screenH)

            if let qrImage = generateQRCode(from: joinCode) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(AppTheme.Radii.tertiaryButton)
                    .padding(.top, 20)
            }

            Text(joinCode)
                .font(AppTheme.Fonts.mono(size: 20))
                .foregroundColor(.white)
                .tracking(4)
                .padding(.top, 12)

            Text(formatStartDate(startDate))
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.top, 10)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(hostName.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    )

                Text("Hosted by \(hostName)")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.top, 14)
            .padding(.bottom, AppTheme.Spacing.screenH)
        }
        .frame(maxWidth: .infinity)
        .momentoCard()
    }

    private func formatStartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM • h:mm a"
        return formatter.string(from: date)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = 10.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        InviteCardView(
            eventName: "Asad's Birthday",
            joinCode: "ABC123",
            startDate: Date(),
            hostName: "Asad"
        )
        .padding(.horizontal, 30)
    }
}
