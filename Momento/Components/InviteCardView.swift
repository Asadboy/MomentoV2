import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteCardView: View {
    let eventName: String
    let joinCode: String
    let startDate: Date
    let hostName: String

    var body: some View {
        VStack(spacing: 0) {
            // Event name
            Text(eventName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            // QR Code
            if let qrImage = generateQRCode(from: joinCode) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.top, 20)
            }

            // Join code
            Text(joinCode)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .tracking(4)
                .padding(.top, 12)

            // Date/time
            Text(formatStartDate(startDate))
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 10)

            // Host info
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
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(cardGradient)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.15, green: 0.05, blue: 0.25),
                Color(red: 0.08, green: 0.06, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
