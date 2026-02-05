//
//  StatsGridView.swift
//  Momento
//
//  2-column grid of activity stat cards for profile
//

import SwiftUI

struct StatsGridView: View {
    let stats: ProfileStats

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            StatCardView(
                value: "\(stats.eventsJoined)",
                label: "Events joined",
                icon: "person.2.fill"
            )

            StatCardView(
                value: "\(stats.photosTaken)",
                label: "Photos taken",
                icon: "camera.fill"
            )

            StatCardView(
                value: "\(stats.photosLiked)",
                label: "Photos liked",
                icon: "heart.fill"
            )

            StatCardView(
                value: "—",
                label: "Coming soon",
                icon: "sparkles"
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 16) {
                StatsGridView(stats: ProfileStats(
                    eventsJoined: 8,
                    photosTaken: 42,
                    photosLiked: 18,
                    userNumber: 47
                ))
            }
            .padding()
        }
    }
}
