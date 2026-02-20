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

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppTheme.Colors.royalPurple.opacity(0.7))

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(AppTheme.Fonts.micro)
                .foregroundColor(AppTheme.Colors.textQuaternary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.innerElement)
                .fill(AppTheme.Colors.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.innerElement)
                .stroke(AppTheme.Colors.fieldStroke, lineWidth: 1)
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
