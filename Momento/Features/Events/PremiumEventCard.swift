//
//  PremiumEventCard.swift
//  Momento
//
//  Redesigned event card with LIVE badge, guest count, shot dots.
//  States: Live, Upcoming, Processing, Ready to Reveal, Revealed
//

import SwiftUI

/// Premium event card component with state-aware UI
struct PremiumEventCard: View {
    let event: Event
    let now: Date
    var userHasCompletedReveal: Bool = false
    var likedCount: Int = 0
    var memberCount: Int = 0
    var photoCount: Int = 0
    let onTap: () -> Void
    let onLongPress: () -> Void

    private let totalShots = 10

    // MARK: - Event State

    private enum EventState {
        case upcoming
        case live
        case processing
        case readyToReveal
        case revealed
    }

    private var eventState: EventState {
        switch event.currentState(at: now) {
        case .upcoming:
            return .upcoming
        case .live:
            return .live
        case .processing:
            return .processing
        case .revealed:
            return userHasCompletedReveal ? .revealed : .readyToReveal
        }
    }

    private var shotsLeft: Int {
        max(0, totalShots - photoCount)
    }

    private var shotsUsed: Int {
        totalShots - shotsLeft
    }

    // MARK: - Time Helpers

    private func secondsUntil(_ date: Date, from reference: Date) -> Int {
        max(0, Int(date.timeIntervalSince(reference)))
    }

    private var secondsUntilStart: Int {
        secondsUntil(event.startsAt, from: now)
    }

    private var secondsUntilEnd: Int {
        secondsUntil(event.endsAt, from: now)
    }

    private var secondsUntilReveal: Int {
        secondsUntil(event.releaseAt, from: now)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: badge + guest count
            topRow

            // Event name
            Text(event.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)

            // Time subtitle
            timeSubtitle

            // Bottom: shots or state info
            bottomSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.Colors.darkCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.darkCardBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress()
        }
    }

    // MARK: - Top Row

    @ViewBuilder
    private var topRow: some View {
        HStack {
            stateBadge
            Spacer()
            // Guest count
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("\(memberCount) guests")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - State Badge

    @ViewBuilder
    private var stateBadge: some View {
        switch eventState {
        case .live:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("LIVE")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.2))
            )

        case .upcoming:
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11, weight: .medium))
                Text("UPCOMING")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )

        case .processing:
            HStack(spacing: 6) {
                Image(systemName: "film.stack")
                    .font(.system(size: 11, weight: .medium))
                Text("DEVELOPING")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )

        case .readyToReveal:
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                Text("READY")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.cyan)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.cyan.opacity(0.15))
            )

        case .revealed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .medium))
                Text("REVEALED")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(Color(white: 0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
        }
    }

    // MARK: - Time Subtitle

    @ViewBuilder
    private var timeSubtitle: some View {
        switch eventState {
        case .live:
            Text("Ends \(formatHumanizedTime(secondsUntilEnd))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

        case .upcoming:
            Text("Starts \(formatHumanizedTime(secondsUntilStart))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

        case .processing:
            Text("Reveals \(formatHumanizedTime(secondsUntilReveal))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.orange.opacity(0.7))

        case .readyToReveal:
            Text("Your photos are ready")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.cyan.opacity(0.8))

        case .revealed:
            Text(likedCount > 0 ? "\(likedCount) liked" : "Tap to relive")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Bottom Section (shots)

    @ViewBuilder
    private var bottomSection: some View {
        switch eventState {
        case .live:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(shotsLeft) shots left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(shotsLeft > 0 ? .green : .red.opacity(0.8))

                // Shot dots
                HStack(spacing: 6) {
                    ForEach(0..<totalShots, id: \.self) { index in
                        Circle()
                            .fill(index < shotsUsed ? Color.white : Color.white.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
            }

        case .upcoming:
            // No shots for upcoming
            EmptyView()

        case .processing:
            EmptyView()

        case .readyToReveal:
            EmptyView()

        case .revealed:
            if let code = event.joinCode {
                Button {
                    let albumURL = "https://yourmomento.app/album/\(code)"
                    UIPasteboard.general.string = albumURL
                    HapticsManager.shared.success()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .medium))
                        Text("Share album link")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.cyan.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Time Formatting

    private func formatHumanizedTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 48 {
            let days = hours / 24
            return "in \(days) days"
        } else if hours >= 24 {
            return "tomorrow"
        } else if hours >= 12 {
            return "tonight"
        } else if hours >= 6 {
            return "in a few hours"
        } else if hours >= 2 {
            return "in \(hours) hours"
        } else if hours >= 1 {
            return "in about an hour"
        } else if minutes >= 30 {
            return "in 30 min"
        } else if minutes >= 10 {
            return "soon"
        } else {
            return "any moment now"
        }
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    return ScrollView {
        VStack(spacing: 20) {
            PremiumEventCard(
                event: Event(
                    name: "Joe's 26th Birthday",
                    coverEmoji: "\u{1F382}",
                    startsAt: now.addingTimeInterval(-3600),
                    endsAt: now.addingTimeInterval(3600 * 5),
                    releaseAt: now.addingTimeInterval(3600 * 29)
                ),
                now: now,
                memberCount: 12,
                photoCount: 3,
                onTap: {},
                onLongPress: {}
            )

            PremiumEventCard(
                event: Event(
                    name: "NYE House Party",
                    coverEmoji: "\u{1F389}",
                    startsAt: now.addingTimeInterval(3600 * 12),
                    endsAt: now.addingTimeInterval(3600 * 20),
                    releaseAt: now.addingTimeInterval(3600 * 44)
                ),
                now: now,
                memberCount: 8,
                onTap: {},
                onLongPress: {}
            )
        }
        .padding()
    }
    .background(Color.black)
}
