//
//  EventCard.swift
//  Momento
//
//  People-dots event card — shows each member's 10 shot dots in real-time.
//  Replaces PremiumEventCard.swift.
//

import SwiftUI

struct EventCard: View {
    let event: Event
    let now: Date
    let members: [MemberWithShots]
    var userHasCompletedReveal: Bool = false
    var likedCount: Int = 0
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onInvite: () -> Void

    private let totalShots = 10

    // Pulsing glow for reveal-ready
    @State private var glowPulsing = false

    // MARK: - Derived State

    private var eventState: Event.State {
        event.currentState(at: now)
    }

    private var isRevealReady: Bool {
        event.isRevealReady(at: now)
    }

    private var currentUserId: String? {
        SupabaseManager.shared.currentUser?.id.uuidString
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            peopleList
            footerSection
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

    // MARK: - Header Row (name + badge)

    @ViewBuilder
    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                stateBadge
                Spacer()
                timeLabel
            }

            Text(event.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.green.opacity(0.2)))

        case .upcoming:
            HStack(spacing: 5) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .medium))
                Text("UPCOMING")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.1)))

        case .revealed:
            if userHasCompletedReveal {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .medium))
                    Text("DONE")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Color(white: 0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            } else if isRevealReady {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .medium))
                    Text("READY")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.cyan.opacity(0.15)))
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10, weight: .medium))
                    Text("ENDED")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
    }

    // MARK: - Time Label

    @ViewBuilder
    private var timeLabel: some View {
        switch eventState {
        case .live:
            Text("Ends \(formatHumanizedTime(secondsUntil(event.endsAt)))")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

        case .upcoming:
            Text("Starts \(formatHumanizedTime(secondsUntil(event.startsAt)))")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

        case .revealed:
            if userHasCompletedReveal {
                Text(likedCount > 0 ? "\(likedCount) liked" : "")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            } else if isRevealReady {
                Text("Tap to reveal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.8))
            } else {
                Text("Reveals \(formatHumanizedTime(secondsUntil(event.releaseAt)))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.orange.opacity(0.7))
            }
        }
    }

    // MARK: - People List

    @ViewBuilder
    private var peopleList: some View {
        VStack(spacing: 0) {
            ForEach(members) { member in
                memberRow(member: member, isCurrentUser: member.userId == currentUserId)

                if member.id != members.last?.id {
                    Divider()
                        .background(Color.white.opacity(0.06))
                }
            }

            // Invite row
            if eventState != .revealed || !userHasCompletedReveal {
                if !members.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.06))
                }
                inviteRow
            }
        }
    }

    // MARK: - Member Row

    private func memberRow(member: MemberWithShots, isCurrentUser: Bool) -> some View {
        HStack(spacing: 12) {
            // Avatar
            avatar(for: member)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(isCurrentUser ? "You" : member.name)
                    .font(.system(size: 15, weight: isCurrentUser ? .semibold : .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            // Shot dots
            shotDots(count: member.shotsTaken)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Avatar

    private func avatar(for member: MemberWithShots) -> some View {
        Circle()
            .fill(avatarColor(for: member.username))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private func avatarColor(for username: String) -> Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .orange, .green, .cyan, .indigo, .mint
        ]
        let hash = username.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[hash % colors.count].opacity(0.6)
    }

    // MARK: - Shot Dots

    private func shotDots(count: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<totalShots, id: \.self) { index in
                Circle()
                    .fill(index < count ? Color.white : Color.white.opacity(0.15))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Invite Row

    private var inviteRow: some View {
        Button(action: onInvite) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    )

                Text("Invite people")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Spacer()
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        if eventState == .revealed && isRevealReady && !userHasCompletedReveal {
            // Reveal CTA
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .medium))
                    Text("Reveal your 10shots")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.cyan.opacity(0.15)))
                Spacer()
            }
        }
    }

    // MARK: - Time Helpers

    private func secondsUntil(_ date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now)))
    }

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
    let members = [
        MemberWithShots(userId: "1", username: "asad", displayName: "Asad", avatarUrl: nil, shotsTaken: 7),
        MemberWithShots(userId: "2", username: "joe", displayName: "Joe", avatarUrl: nil, shotsTaken: 4),
        MemberWithShots(userId: "3", username: "sarah", displayName: "Sarah", avatarUrl: nil, shotsTaken: 2),
    ]

    return ScrollView {
        VStack(spacing: 20) {
            // Live event
            EventCard(
                event: Event(
                    name: "Joe's 26th Birthday",
                    startsAt: now.addingTimeInterval(-3600),
                    endsAt: now.addingTimeInterval(3600 * 5),
                    releaseAt: now.addingTimeInterval(3600 * 29)
                ),
                now: now,
                members: members,
                onTap: {},
                onLongPress: {},
                onInvite: {}
            )

            // Reveal ready
            EventCard(
                event: Event(
                    name: "Hijack x DoubleDip",
                    startsAt: now.addingTimeInterval(-3600 * 48),
                    endsAt: now.addingTimeInterval(-3600 * 24),
                    releaseAt: now.addingTimeInterval(-3600)
                ),
                now: now,
                members: members,
                onTap: {},
                onLongPress: {},
                onInvite: {}
            )
        }
        .padding()
    }
    .background(Color.black)
}
