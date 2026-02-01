import SwiftUI

struct PremiumRowView: View {
    @Binding var isPremiumEnabled: Bool
    let onEnableTapped: () -> Void

    private let premiumGold = Color(red: 0.85, green: 0.65, blue: 0.3)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("This one's worth keeping")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            // Benefits list
            VStack(alignment: .leading, spacing: 10) {
                PremiumBenefitRow(icon: "infinity", text: "Photos that never expire")
                PremiumBenefitRow(icon: "clock.arrow.2.circlepath", text: "Set your own timeline")
                PremiumBenefitRow(icon: "link", text: "A link everyone can revisit")
                PremiumBenefitRow(icon: "arrow.down.circle", text: "Clean downloads, no watermarks")
            }

            // Price and enable button
            HStack {
                Text("£7.99 one-time")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Button(action: {
                    onEnableTapped()
                    HapticsManager.shared.medium()
                }) {
                    Text("Enable")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isPremiumEnabled ? .black : premiumGold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            isPremiumEnabled
                                ? premiumGold
                                : Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(premiumGold, lineWidth: isPremiumEnabled ? 0 : 2)
                        )
                        .cornerRadius(20)
                }
            }
        }
    }
}

struct PremiumBenefitRow: View {
    let icon: String
    let text: String

    private let premiumGold = Color(red: 0.85, green: 0.65, blue: 0.3)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(premiumGold)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            PremiumRowView(isPremiumEnabled: .constant(false), onEnableTapped: {})
            Divider()
            PremiumRowView(isPremiumEnabled: .constant(true), onEnableTapped: {})
        }
        .padding()
    }
}
