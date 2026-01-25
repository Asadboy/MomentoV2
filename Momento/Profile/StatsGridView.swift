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
            // Hero stat - primary emphasis
            StatCardView(
                value: "\(stats.momentsCaptured)",
                label: "Moments captured",
                icon: "camera.fill",
                isHero: true
            )

            StatCardView(
                value: "\(stats.photosLoved)",
                label: "Moments loved",
                icon: "heart.fill"
            )

            StatCardView(
                value: "\(stats.revealsCompleted)",
                label: "Reveals completed",
                icon: "sparkles"
            )

            StatCardView(
                value: "\(stats.momentosShared)",
                label: "Shared Momentos",
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
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 16)

            JourneyStatRow(
                icon: "person.2",
                label: "Captured with",
                value: stats.friendsCapturedWith > 0 ? "\(stats.friendsCapturedWith) people" : "—"
            )

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 16)

            JourneyStatRow(
                icon: "flame",
                label: "Most active",
                value: stats.mostActiveMomento ?? "—"
            )

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 16)

            JourneyStatRow(
                icon: "clock",
                label: "Most recent",
                value: stats.mostRecentMomento ?? "—"
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.12, green: 0.1, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(royalPurple.opacity(0.1), lineWidth: 1)
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
            // Icon - subtle
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(royalPurple.opacity(0.6))
                .frame(width: 20)

            // Label - muted
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.4))

            Spacer()

            // Value - bright and confident
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 16) {
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
                JourneyStatsView(stats: ProfileStats(
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
            }
            .padding()
        }
    }
}
