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
                value: "\(stats.momentsCaptured)",
                label: "Moments captured",
                icon: "camera.fill"
            )

            StatCardView(
                value: "\(stats.photosLoved)",
                label: "Photos loved",
                icon: "heart.fill"
            )

            StatCardView(
                value: "\(stats.revealsCompleted)",
                label: "Reveals completed",
                icon: "sparkles"
            )

            StatCardView(
                value: "\(stats.momentosShared)",
                label: "Momentos shared",
                icon: "person.2.fill"
            )
        }
    }
}

// MARK: - Journey Stats List

struct JourneyStatsView: View {
    let stats: ProfileStats

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }

    var body: some View {
        VStack(spacing: 0) {
            JourneyStatRow(
                icon: "calendar",
                label: "First Momento",
                value: stats.firstMomentoDate.map { dateFormatter.string(from: $0) } ?? "—"
            )

            Divider()
                .background(Color.white.opacity(0.1))

            JourneyStatRow(
                icon: "person.2",
                label: "Friends captured with",
                value: "\(stats.friendsCapturedWith)"
            )

            Divider()
                .background(Color.white.opacity(0.1))

            JourneyStatRow(
                icon: "flame",
                label: "Most active Momento",
                value: stats.mostActiveMomento ?? "—"
            )

            Divider()
                .background(Color.white.opacity(0.1))

            JourneyStatRow(
                icon: "clock",
                label: "Most recent Momento",
                value: stats.mostRecentMomento ?? "—"
            )
        }
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

struct JourneyStatRow: View {
    let icon: String
    let label: String
    let value: String

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(royalPurple)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#Preview {
    let sampleStats = ProfileStats(
        momentsCaptured: 42,
        photosLoved: 18,
        revealsCompleted: 6,
        momentosShared: 8,
        firstMomentoDate: Date().addingTimeInterval(-90 * 24 * 3600),
        friendsCapturedWith: 23,
        mostActiveMomento: "Sopranos",
        mostRecentMomento: "NYE 2026",
        userNumber: 47
    )

    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 16) {
                StatsGridView(stats: sampleStats)
                JourneyStatsView(stats: sampleStats)
            }
            .padding()
        }
    }
}
