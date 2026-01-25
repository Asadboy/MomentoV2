//
//  StatsGridView.swift
//  Momento
//
//  2-column grid of stat cards for profile
//

import SwiftUI

struct StatsGridView: View {
    let stats: ProfileStats

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            // Activity stats (Core 4)
            StatCardView(
                value: "\(stats.momentsCaptured)",
                label: "Moments captured"
            )

            StatCardView(
                value: "\(stats.photosLoved)",
                label: "Photos loved"
            )

            StatCardView(
                value: "\(stats.revealsCompleted)",
                label: "Reveals completed"
            )

            StatCardView(
                value: "\(stats.momentosShared)",
                label: "Momentos shared"
            )

            // Journey stats (4)
            StatCardView(
                value: stats.firstMomentoDate.map { dateFormatter.string(from: $0) } ?? "—",
                label: "First Momento"
            )

            StatCardView(
                value: "\(stats.friendsCapturedWith)",
                label: "Friends captured with"
            )

            StatCardView(
                value: stats.mostActiveMomento ?? "—",
                label: "Most active Momento"
            )

            StatCardView(
                value: stats.mostRecentMomento ?? "—",
                label: "Most recent Momento"
            )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            StatsGridView(stats: ProfileStats(
                momentsCaptured: 42,
                photosLoved: 18,
                revealsCompleted: 6,
                momentosShared: 8,
                firstMomentoDate: Date().addingTimeInterval(-90 * 24 * 3600),
                friendsCapturedWith: 23,
                mostActiveMomento: "Sopranos",
                mostRecentMomento: "NYE 2026",
                userNumber: 47
            ))
            .padding()
        }
    }
}
