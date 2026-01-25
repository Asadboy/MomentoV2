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

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(royalPurple.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 12) {
            StatCardView(value: "42", label: "Moments captured")
            StatCardView(value: "18", label: "Photos loved")
        }
        .padding()
    }
}
