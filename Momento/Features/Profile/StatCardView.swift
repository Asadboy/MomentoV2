//
//  StatCardView.swift
//  Momento
//
//  Individual stat card for profile display
//

import SwiftUI

struct StatCardView: View {
    let value: String
    let label: String
    let icon: String
    var isHero: Bool = false  // Kept for API compatibility

    // Reveal colors (blue + purple)
    private let glowBlue = Color(red: 0.0, green: 0.6, blue: 1.0)
    private let glowPurple = Color(red: 0.5, green: 0.0, blue: 0.8)

    var body: some View {
        VStack(spacing: 6) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(glowPurple.opacity(0.7))

            // Value
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            // Label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [glowBlue.opacity(0.3), glowPurple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 12) {
            StatCardView(value: "42", label: "Photos taken", icon: "camera.fill")
            StatCardView(value: "18", label: "Photos liked", icon: "heart.fill")
        }
        .padding()
    }
}
