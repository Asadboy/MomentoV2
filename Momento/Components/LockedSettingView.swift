import SwiftUI

struct LockedSettingView: View {
    let calculatedTime: String
    let onPremiumTapped: () -> Void

    private let premiumGold = Color(red: 0.85, green: 0.65, blue: 0.3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show the calculated/locked time
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Text(calculatedTime)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
            }

            // Premium upsell prompt
            Button(action: onPremiumTapped) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Need more time for a trip or festival?")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 4) {
                            Text("See Premium options")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(premiumGold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(premiumGold)
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LockedSettingView(
            calculatedTime: "Sun 2 Feb • 6:00 AM",
            onPremiumTapped: {}
        )
        .padding()
    }
}
