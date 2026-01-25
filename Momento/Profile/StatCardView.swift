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
    var isHero: Bool = false

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Icon - dimmed for subtlety
            Image(systemName: icon)
                .font(.system(size: isHero ? 18 : 14, weight: .medium))
                .foregroundColor(royalPurple.opacity(isHero ? 0.9 : 0.6))

            // Value - hero stat is larger and brighter
            Text(value)
                .font(.system(size: isHero ? 28 : 22, weight: .bold))
                .foregroundColor(.white.opacity(isHero ? 1.0 : 0.85))

            // Label - muted
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
                .stroke(royalPurple.opacity(isHero ? 0.25 : 0.1), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 12) {
            StatCardView(value: "42", label: "Moments captured", icon: "camera.fill", isHero: true)
            StatCardView(value: "18", label: "Moments loved", icon: "heart.fill")
        }
        .padding()
    }
}
