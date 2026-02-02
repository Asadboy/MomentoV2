//
//  KeepsakeRevealView.swift
//  Momento
//
//  Full-screen keepsake reveal animation after completing a reveal
//

import SwiftUI

struct KeepsakeRevealView: View {
    let keepsake: EarnedKeepsake
    let onDismiss: () -> Void
    let onViewProfile: () -> Void

    @State private var showCard = false
    @State private var showName = false
    @State private var showFlavourText = false
    @State private var showRarity = false
    @State private var showButton = false
    @State private var cardRotation: Double = 180

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 24) {
                Spacer()

                // Title
                Text("You earned a keepsake!")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(showCard ? 1 : 0)

                // Keepsake card with flip animation
                ZStack {
                    // Glow
                    Circle()
                        .fill(royalPurple)
                        .blur(radius: 60)
                        .opacity(showCard ? 0.4 : 0)
                        .frame(width: 250, height: 250)

                    // Card back (shown first)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [royalPurple, Color.purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 180, height: 180)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .rotation3DEffect(.degrees(cardRotation - 180), axis: (x: 0, y: 1, z: 0))
                        .opacity(cardRotation > 90 ? 1 : 0)

                    // Card front (revealed)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
                        .frame(width: 180, height: 180)
                        .overlay(
                            keepsakeIcon
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(royalPurple.opacity(0.4), lineWidth: 2)
                        )
                        .shadow(color: royalPurple.opacity(0.4), radius: 20, x: 0, y: 10)
                        .rotation3DEffect(.degrees(cardRotation), axis: (x: 0, y: 1, z: 0))
                        .opacity(cardRotation <= 90 ? 1 : 0)
                }
                .scaleEffect(showCard ? 1 : 0.5)
                .opacity(showCard ? 1 : 0)

                // Name
                Text(keepsake.keepsake.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(showName ? 1 : 0)
                    .offset(y: showName ? 0 : 20)

                // Flavour text
                Text(keepsake.keepsake.flavourText)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showFlavourText ? 1 : 0)
                    .offset(y: showFlavourText ? 0 : 20)

                // Rarity
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(royalPurple)

                    Text(String(format: "%.1f%% of users have this", keepsake.rarityPercentage))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .opacity(showRarity ? 1 : 0)
                .offset(y: showRarity ? 0 : 20)

                Spacer()

                // View on profile button
                Button {
                    onViewProfile()
                } label: {
                    Text("View on Profile")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [royalPurple, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 30)

                // Tap to dismiss
                Text("Tap anywhere to dismiss")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(showButton ? 1 : 0)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            runRevealAnimation()
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

    private func runRevealAnimation() {
        // Show card
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showCard = true
        }

        // Flip card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                cardRotation = 0
            }
        }

        // Show name
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showName = true
            }
        }

        // Show flavour text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFlavourText = true
            }
        }

        // Show rarity
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showRarity = true
            }
        }

        // Show button
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) {
                showButton = true
            }
        }
    }
}

#Preview {
    KeepsakeRevealView(
        keepsake: EarnedKeepsake(
            id: UUID(),
            keepsake: Keepsake(
                id: UUID(),
                name: "Sopranos",
                artworkUrl: "",
                flavourText: "Made member of the first family.",
                eventId: nil,
                createdAt: Date()
            ),
            earnedAt: Date(),
            rarityPercentage: 0.5
        ),
        onDismiss: {},
        onViewProfile: {}
    )
}
