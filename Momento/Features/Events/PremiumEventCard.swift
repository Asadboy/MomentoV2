//
//  PremiumEventCard.swift
//  Momento
//
//  Event card with LIVE badge, guest count, shot dots.
//  States: Upcoming, Live, Revealed
//

import SwiftUI

/// Event card component with state-aware UI
struct PremiumEventCard: View {
    let event: Event
    let now: Date
    var userHasCompletedReveal: Bool = false
    var likedCount: Int = 0
    var memberCount: Int = 0
    var userPhotoCount: Int = 0
    var totalPhotoCount: Int = 0
    let onTap: () -> Void
    let onLongPress: () -> Void

    private let totalShots = 10

    // Pulsing glow for reveal-ready
    @State private var glowPulsing = false

    // MARK: - Derived State

    /// Whether the reveal is available (releaseAt has passed)
    private var isRevealReady: Bool {
        event.isRevealReady(at: now)
    }

    private var eventState: Event.State {
        event.currentState(at: now)
    }

    private var shotsLeft: Int {
        max(0, totalShots - userPhotoCount)
    }

    private var shotsUsed: Int {
        totalShots - shotsLeft
    }

    // MARK: - Time Helpers

    private func secondsUntil(_ date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now)))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            topRow
            Text(event.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
            timeSubtitle
            bottomSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isRevealReady && !userHasCompletedReveal
                    ? Color(red: 0.06, green: 0.08, blue: 0.14)
                    : AppTheme.Colors.darkCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isRevealReady && !userHasCompletedReveal
                        ? Color.cyan.opacity(glowPulsing ? 0.8 : 0.3)
                        : AppTheme.Colors.darkCardBorder,
                    lineWidth: isRevealReady && !userHasCompletedReveal ? 1.5 : 1
                )
        )
        .shadow(
            color: isRevealReady && !userHasCompletedReveal
                ? Color.cyan.opacity(glowPulsing ? 0.3 : 0.1)
                : .clear,
            radius: glowPulsing ? 16 : 8
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress()
        }
        .onAppear {
            if isRevealReady && !userHasCompletedReveal {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    glowPulsing = true
                }
            }
        }
    }

    // MARK: - Top Row

    @ViewBuilder
    private var topRow: some View {
        HStack {
            stateBadge
            Spacer()
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
            .background(Capsule().fill(Color.green.opacity(0.2)))

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
            .background(Capsule().fill(Color.white.opacity(0.1)))

        case .revealed:
            if userHasCompletedReveal {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text("DONE")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(Color(white: 0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            } else if isRevealReady {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                    Text("READY")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.cyan.opacity(0.15)))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .medium))
                    Text("ENDED")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
    }

    // MARK: - Time Subtitle

    @ViewBuilder
    private var timeSubtitle: some View {
        switch eventState {
        case .live:
            Text("Ends \(formatHumanizedTime(secondsUntil(event.endsAt)))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

        case .upcoming:
            Text("Starts \(formatHumanizedTime(secondsUntil(event.startsAt)))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

        case .revealed:
            if userHasCompletedReveal {
                Text(likedCount > 0 ? "\(likedCount) liked" : "Tap to relive")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            } else if isRevealReady {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("Your shots are ready")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.cyan.opacity(0.8))
            } else {
                Text("Reveals \(formatHumanizedTime(secondsUntil(event.releaseAt)))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))
            }
        }
    }

    // MARK: - Bottom Section

    @ViewBuilder
    private var bottomSection: some View {
        switch eventState {
        case .live:
            VStack(alignment: .leading, spacing: 8) {
                Text("\(shotsLeft) shots left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(shotsLeft > 0 ? .green : .red.opacity(0.8))

                HStack(spacing: 6) {
                    ForEach(0..<totalShots, id: \.self) { index in
                        Circle()
                            .fill(index < shotsUsed ? Color.white : Color.white.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
            }

        case .upcoming:
            EmptyView()

        case .revealed:
            if userHasCompletedReveal {
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
            } else if isRevealReady {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(totalPhotoCount) shots")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.5))

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Tap to reveal")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
                }
            } else {
                // Between endsAt and releaseAt — just show shot count
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 13, weight: .medium))
                    Text("\(totalPhotoCount) shots taken")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Time Formatting

    private func formatHumanizedTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 48 {
            return "in \(hours / 24) days"
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
            // Live event
            PremiumEventCard(
                event: Event(
                    name: "Joe's 26th Birthday",
                    startsAt: now.addingTimeInterval(-3600),
                    endsAt: now.addingTimeInterval(3600 * 5),
                    releaseAt: now.addingTimeInterval(3600 * 29)
                ),
                now: now,
                memberCount: 12,
                userPhotoCount: 3,
                totalPhotoCount: 8,
                onTap: {},
                onLongPress: {}
            )

            // Upcoming event
            PremiumEventCard(
                event: Event(
                    name: "NYE House Party",
                    startsAt: now.addingTimeInterval(3600 * 12),
                    endsAt: now.addingTimeInterval(3600 * 20),
                    releaseAt: now.addingTimeInterval(3600 * 44)
                ),
                now: now,
                memberCount: 8,
                onTap: {},
                onLongPress: {}
            )

            // Reveal ready
            PremiumEventCard(
                event: Event(
                    name: "Hijack x DoubleDip",
                    startsAt: now.addingTimeInterval(-3600 * 48),
                    endsAt: now.addingTimeInterval(-3600 * 24),
                    releaseAt: now.addingTimeInterval(-3600)
                ),
                now: now,
                memberCount: 5,
                totalPhotoCount: 143,
                onTap: {},
                onLongPress: {}
            )
        }
        .padding()
    }
    .background(Color.black)
}
