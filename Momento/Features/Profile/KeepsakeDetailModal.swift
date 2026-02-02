//
//  KeepsakeDetailModal.swift
//  Momento
//
//  Full keepsake details shown when tapping a keepsake
//

import SwiftUI

struct KeepsakeDetailModal: View {
    let keepsake: EarnedKeepsake
    @Environment(\.dismiss) private var dismiss

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Keepsake artwork (large)
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(royalPurple)
                        .blur(radius: 40)
                        .opacity(0.3)
                        .frame(width: 200, height: 200)

                    // Artwork container
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                        .frame(width: 160, height: 160)
                        .overlay(
                            keepsakeIcon
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(royalPurple.opacity(0.4), lineWidth: 2)
                        )
                        .shadow(color: royalPurple.opacity(0.3), radius: 20, x: 0, y: 10)
                }

                // Name
                Text(keepsake.keepsake.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                // Flavour text
                Text(keepsake.keepsake.flavourText)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Rarity
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(royalPurple)

                    Text(String(format: "%.1f%% of users have this", keepsake.rarityPercentage))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 8)

                // Earned date
                Text("Earned \(dateFormatter.string(from: keepsake.earnedAt))")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var keepsakeIcon: some View {
        switch keepsake.keepsake.name.lowercased() {
        case let name where name.contains("lakes"):
            Image(systemName: "mountain.2.fill")
        case let name where name.contains("sopranos"):
            Image(systemName: "crown.fill")
        case let name where name.contains("hijack"):
            Image(systemName: "ferry.fill")
        default:
            Image(systemName: "star.fill")
        }
    }
}

#Preview {
    KeepsakeDetailModal(keepsake: EarnedKeepsake(
        id: UUID(),
        keepsake: Keepsake(
            id: UUID(),
            name: "Sopranos",
            artworkUrl: "",
            flavourText: "Made member of the first family.",
            eventId: nil,
            createdAt: Date()
        ),
        earnedAt: Date().addingTimeInterval(-30 * 24 * 3600),
        rarityPercentage: 0.5
    ))
}
