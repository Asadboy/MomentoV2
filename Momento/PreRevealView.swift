//
//  PreRevealView.swift
//  Momento
//
//  Pre-reveal stats screen - the ceremonial threshold
//

import SwiftUI

struct PreRevealView: View {
    let photoCount: Int
    let contributorCount: Int
    let revealTime: Date
    let onReveal: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Stats
            VStack(spacing: 16) {
                Text("\(photoCount) photos")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(contributorCount) people")
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }

            // Ritual line
            Text("Revealed together at \(formatRevealTime(revealTime))")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 8)

            Spacer()

            // Reveal button
            Button(action: onReveal) {
                Text("Reveal")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(width: 160, height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatRevealTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date).lowercased()
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PreRevealView(
            photoCount: 143,
            contributorCount: 11,
            revealTime: Date(),
            onReveal: { print("Reveal tapped") }
        )
    }
}
