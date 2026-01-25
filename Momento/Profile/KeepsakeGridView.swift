//
//  KeepsakeGridView.swift
//  Momento
//
//  Grid of keepsake artwork thumbnails
//

import SwiftUI

struct KeepsakeGridView: View {
    let keepsakes: [EarnedKeepsake]
    @Binding var selectedKeepsake: EarnedKeepsake?

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(keepsakes) { keepsake in
                KeepsakeThumbnailView(keepsake: keepsake)
                    .onTapGesture {
                        selectedKeepsake = keepsake
                    }
            }
        }
    }
}

struct KeepsakeThumbnailView: View {
    let keepsake: EarnedKeepsake

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        ZStack {
            // Background with glow
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))

            // Keepsake artwork (placeholder for now - will use AsyncImage with artwork_url)
            VStack(spacing: 8) {
                // Placeholder icon based on keepsake name
                keepsakeIcon
                    .font(.system(size: 40))
                    .foregroundColor(.white)

                Text(keepsake.keepsake.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(12)
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(royalPurple.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: royalPurple.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var keepsakeIcon: some View {
        // Temporary placeholder icons based on name
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
    ZStack {
        Color.black.ignoresSafeArea()

        KeepsakeGridView(
            keepsakes: [
                EarnedKeepsake(
                    id: UUID(),
                    keepsake: Keepsake(
                        id: UUID(),
                        name: "Lakes",
                        artworkUrl: "",
                        flavourText: "Some moments are worth waiting 3 years for.",
                        eventId: nil,
                        createdAt: Date()
                    ),
                    earnedAt: Date(),
                    rarityPercentage: 0.3
                ),
                EarnedKeepsake(
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
                )
            ],
            selectedKeepsake: .constant(nil)
        )
        .padding()
    }
}
