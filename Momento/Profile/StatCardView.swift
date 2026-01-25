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

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(royalPurple)

            // Value
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            // Label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
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
                .stroke(royalPurple.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 12) {
            StatCardView(value: "42", label: "Moments captured", icon: "camera.fill")
            StatCardView(value: "18", label: "Photos loved", icon: "heart.fill")
        }
        .padding()
    }
}
