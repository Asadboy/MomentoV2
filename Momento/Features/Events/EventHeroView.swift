//
//  EventHeroView.swift
//  Moment
//
//  The lobby card. Event name + state + timing as the headline; everyone in
//  the event — current user pinned to the top, otherwise equal-weight — as a
//  roster of rows (avatar + name + 10 dots). Designed as a reusable card
//  component, not a full-screen takeover, so a parent (ContentView) can place
//  it however it wants. Replaces the people-dots EventCard once wired in.
//
//  Designed against the 5-member free-tier ceiling: the roster always fits
//  on a single iPhone screen with the invite affordance, no scrolling needed.
//

import SwiftUI

struct EventHeroView: View {
    let event: Event
    let now: Date
    let members: [MemberWithShots]
    let currentUserId: String?
    var userHasCompletedReveal: Bool = false

    let onTap: () -> Void
    let onLongPress: () -> Void
    let onInvite: () -> Void

    private let totalShots = 10
    private let dotSize: CGFloat = 22
    private let dotSpacing: CGFloat = 8
    private let avatarSize: CGFloat = 40
    private let cornerRadius: CGFloat = 24

    @State private var glowPulsing = false

    // MARK: - Derived

    private var eventState: Event.State {
        event.currentState(at: now)
    }

    private var isRevealReady: Bool {
        event.isRevealReady(at: now)
    }

    private var isRevealCTA: Bool {
        eventState == .revealed && isRevealReady && !userHasCompletedReveal
    }

    /// The avatar + 10-dot rows are a *live shot-progress* affordance. On a
    /// revealed ("tap to reveal") card the dots convey nothing, and rendering
    /// them only after async member hydration makes the card jump from compact
    /// to tall. Keep revealed cards compact and stable from first paint.
    private var showsMemberRoster: Bool {
        eventState != .revealed
    }

    /// Current user pinned at the top; everyone else keeps their original
    /// order. No other visual distinction — just position.
    private var orderedMembers: [MemberWithShots] {
        guard let currentUserId else { return members }
        var me: [MemberWithShots] = []
        var others: [MemberWithShots] = []
        for m in members {
            if m.userId == currentUserId { me.append(m) } else { others.append(m) }
        }
        return me + others
    }

    /// Sum of all members' shots ÷ (members × 10). Drives the subtle card-fill
    /// warm so the card itself warms as the group fills the roll.
    private var groupFillProgress: CGFloat {
        guard !members.isEmpty else { return 0 }
        let taken = members.reduce(0) { $0 + $1.shotsTaken }
        let max = members.count * totalShots
        guard max > 0 else { return 0 }
        return CGFloat(taken) / CGFloat(max)
    }

    /// Card fill drifts from near-black to a warm near-black as the group
    /// fills their dots. Reveal-ready gets a cool, slightly different base.
    private var cardFill: Color {
        if isRevealCTA {
            return Color(red: 0.04, green: 0.06, blue: 0.10)
        }
        let p = Double(groupFillProgress)
        return Color(
            red:   0.07 + 0.05 * p,
            green: 0.06 + 0.03 * p,
            blue:  0.07 + 0.01 * p
        )
    }

    private var cardStroke: Color {
        if isRevealCTA {
            return Color.cyan.opacity(glowPulsing ? 0.8 : 0.3)
        }
        return Color.white.opacity(0.10)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            headline
            roster
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(cardStroke,
                        lineWidth: isRevealCTA && glowPulsing ? 1.5 : 1)
        )
        .shadow(
            color: isRevealCTA ? Color.cyan.opacity(glowPulsing ? 0.3 : 0.1) : .clear,
            radius: glowPulsing ? 16 : 8
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress()
        }
        .onAppear {
            guard isRevealCTA else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulsing = true
            }
        }
    }

    // MARK: - Headline (state pill + event name + time)

    private var headline: some View {
        VStack(spacing: 10) {
            statePill

            Text(event.name)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 4)

            Text(timeCopy)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    @ViewBuilder
    private var statePill: some View {
        switch eventState {
        case .live:
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text("LIVE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.green.opacity(0.18)))

        case .upcoming:
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .medium))
                Text("UPCOMING")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.08)))

        case .revealed:
            if userHasCompletedReveal {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .medium))
                    Text("REVEALED")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.06)))
            } else if isRevealReady {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .medium))
                    Text("READY")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundColor(.cyan)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.cyan.opacity(0.15)))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 10, weight: .medium))
                    Text("AWAITING REVEAL")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundColor(.orange.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.orange.opacity(0.12)))
            }
        }
    }

    // MARK: - Roster (equal-weight rows + invite)

    private var roster: some View {
        VStack(spacing: 0) {
            if showsMemberRoster {
                ForEach(orderedMembers) { member in
                    memberRow(member)
                    if member.id != orderedMembers.last?.id {
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }

            // Hide invite once revealed (matches existing EventCard behavior).
            if eventState != .revealed || !userHasCompletedReveal {
                if showsMemberRoster && !orderedMembers.isEmpty {
                    Divider().background(Color.white.opacity(0.05))
                }
                inviteRow
            }
        }
    }

    private func memberRow(_ member: MemberWithShots) -> some View {
        HStack(spacing: 16) {
            memberAvatar(member)
                .accessibilityHidden(true)  // covered by the row-level label

            Spacer(minLength: 0)

            HStack(spacing: dotSpacing) {
                ForEach(0..<totalShots, id: \.self) { idx in
                    HeroDot(
                        isFilled: idx < member.shotsTaken,
                        isMostRecent: idx == member.shotsTaken - 1,
                        isLive: eventState == .live,
                        isRevealReady: isRevealCTA,
                        size: dotSize
                    )
                    .accessibilityHidden(true)  // ditto — aggregate label
                }
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(member.name), \(member.shotsTaken) of \(totalShots) shots taken")
    }

    @ViewBuilder
    private func memberAvatar(_ member: MemberWithShots) -> some View {
        if let raw = member.avatarUrl, !raw.isEmpty, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    avatarInitial(for: member)
                }
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
        } else {
            avatarInitial(for: member)
        }
    }

    private func avatarInitial(for member: MemberWithShots) -> some View {
        Circle()
            .fill(avatarColor(for: member.userId))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            )
    }

    private var inviteRow: some View {
        Button(action: onInvite) {
            HStack(spacing: 16) {
                Circle()
                    .strokeBorder(Color.white.opacity(0.2),
                                  style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    )

                Text("Invite people")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))

                Spacer()
            }
            .padding(.vertical, 14)
        }
    }

    // MARK: - Helpers

    private var timeCopy: String {
        switch eventState {
        case .live:
            return "ends in \(precise(secondsUntil(event.endsAt)))"
        case .upcoming:
            return "starts in \(precise(secondsUntil(event.startsAt)))"
        case .revealed:
            if isRevealReady {
                return "tap to reveal"
            }
            return "reveals in \(precise(secondsUntil(event.releaseAt)))"
        }
    }

    private func avatarColor(for seed: String) -> Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .green, .cyan, .indigo, .mint]
        let hash = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[hash % colors.count].opacity(0.7)
    }

    private func secondsUntil(_ date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now)))
    }

    /// Minute-precision countdown: "3h 24m", "42 min", "1d 4h". No seconds —
    /// the card refreshes too slowly for a seconds counter to feel honest.
    private func precise(_ seconds: Int) -> String {
        if seconds < 60 { return "less than a minute" }
        let totalMinutes = seconds / 60
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes) min"
    }
}

// MARK: - Hero Dot

/// Brand dot. Pops in on empty→filled, breathes if it's the most recent fill
/// during a live event, and glows cyan when reveal is ready.
private struct HeroDot: View {
    let isFilled: Bool
    let isMostRecent: Bool
    let isLive: Bool
    let isRevealReady: Bool
    let size: CGFloat

    @State private var popScale: CGFloat = 1.0
    @State private var pulse: CGFloat = 1.0

    private var fillColor: Color {
        if !isFilled { return Color.white.opacity(0.08) }
        if isRevealReady { return .cyan }
        return .white
    }

    private var strokeColor: Color {
        isFilled ? .clear : Color.white.opacity(0.18)
    }

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(strokeColor, lineWidth: 1))
            .scaleEffect(popScale * (isMostRecent && isFilled && isLive ? pulse : 1.0))
            .shadow(
                color: isRevealReady && isFilled ? Color.cyan.opacity(0.45) : .clear,
                radius: 6
            )
            .onChange(of: isFilled) { _, newValue in
                guard newValue else { return }
                popScale = 0.3
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    popScale = 1.0
                }
            }
            .onAppear {
                guard isMostRecent && isFilled && isLive else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    pulse = 1.12
                }
            }
            .onChange(of: isMostRecent) { _, newValue in
                if newValue && isFilled && isLive {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        pulse = 1.12
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) { pulse = 1.0 }
                }
            }
    }
}

// MARK: - Preview

#Preview("Live — mid game · 4 friends") {
    let now = Date()
    let members = [
        MemberWithShots(userId: "me", displayName: "Asad",
                        avatarUrl: "https://i.pravatar.cc/200?img=12", shotsTaken: 7),
        MemberWithShots(userId: "2", displayName: "Joe",
                        avatarUrl: "https://i.pravatar.cc/200?img=33", shotsTaken: 3),
        MemberWithShots(userId: "3", displayName: "Sarah", avatarUrl: nil, shotsTaken: 2),
        MemberWithShots(userId: "4", displayName: "Marc",
                        avatarUrl: "https://i.pravatar.cc/200?img=68", shotsTaken: 9)
    ]
    return ZStack {
        Color.black.ignoresSafeArea()
        EventHeroView(
            event: Event(
                name: "Joe's 26th Birthday",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(60 * (60 * 3 + 24)), // 3h 24m
                releaseAt: now.addingTimeInterval(3600 * 27)
            ),
            now: now,
            members: members,
            currentUserId: "me",
            onTap: {}, onLongPress: {}, onInvite: {}
        )
        .padding(.horizontal, 16)
    }
}

#Preview("Live — full free tier · 5 friends") {
    let now = Date()
    let members = [
        MemberWithShots(userId: "me", displayName: "Asad", avatarUrl: nil, shotsTaken: 4),
        MemberWithShots(userId: "2", displayName: "Joe", avatarUrl: nil, shotsTaken: 8),
        MemberWithShots(userId: "3", displayName: "Sarah", avatarUrl: nil, shotsTaken: 2),
        MemberWithShots(userId: "4", displayName: "Marc", avatarUrl: nil, shotsTaken: 10),
        MemberWithShots(userId: "5", displayName: "Liam", avatarUrl: nil, shotsTaken: 5)
    ]
    return ZStack {
        Color.black.ignoresSafeArea()
        EventHeroView(
            event: Event(
                name: "Hijack x DoubleDip",
                startsAt: now.addingTimeInterval(-3600 * 2),
                endsAt: now.addingTimeInterval(3600 * 2),
                releaseAt: now.addingTimeInterval(3600 * 26)
            ),
            now: now,
            members: members,
            currentUserId: "me",
            onTap: {}, onLongPress: {}, onInvite: {}
        )
        .padding(.horizontal, 16)
    }
}

#Preview("Live — fresh start") {
    let now = Date()
    let members = [
        MemberWithShots(userId: "me", displayName: "Asad", avatarUrl: nil, shotsTaken: 0),
        MemberWithShots(userId: "2", displayName: "Joe", avatarUrl: nil, shotsTaken: 1),
        MemberWithShots(userId: "3", displayName: "Sarah", avatarUrl: nil, shotsTaken: 0)
    ]
    return ZStack {
        Color.black.ignoresSafeArea()
        EventHeroView(
            event: Event(
                name: "Sunday Roast",
                startsAt: now.addingTimeInterval(-300),
                endsAt: now.addingTimeInterval(3600 * 4),
                releaseAt: now.addingTimeInterval(3600 * 28)
            ),
            now: now,
            members: members,
            currentUserId: "me",
            onTap: {}, onLongPress: {}, onInvite: {}
        )
        .padding(.horizontal, 16)
    }
}

#Preview("Upcoming") {
    let now = Date()
    return ZStack {
        Color.black.ignoresSafeArea()
        EventHeroView(
            event: Event(
                name: "NYE at Joe's",
                startsAt: now.addingTimeInterval(3600 * 6),
                endsAt: now.addingTimeInterval(3600 * 14),
                releaseAt: now.addingTimeInterval(3600 * 38)
            ),
            now: now,
            members: [
                MemberWithShots(userId: "me", displayName: "Asad", avatarUrl: nil, shotsTaken: 0),
                MemberWithShots(userId: "2", displayName: "Joe", avatarUrl: nil, shotsTaken: 0)
            ],
            currentUserId: "me",
            onTap: {}, onLongPress: {}, onInvite: {}
        )
        .padding(.horizontal, 16)
    }
}

#Preview("Reveal Ready") {
    let now = Date()
    return ZStack {
        Color.black.ignoresSafeArea()
        EventHeroView(
            event: Event(
                name: "Hijack x DoubleDip",
                startsAt: now.addingTimeInterval(-3600 * 48),
                endsAt: now.addingTimeInterval(-3600 * 24),
                releaseAt: now.addingTimeInterval(-60)
            ),
            now: now,
            members: [
                MemberWithShots(userId: "me", displayName: "Asad", avatarUrl: nil, shotsTaken: 10),
                MemberWithShots(userId: "2", displayName: "Joe", avatarUrl: nil, shotsTaken: 10),
                MemberWithShots(userId: "3", displayName: "Sarah", avatarUrl: nil, shotsTaken: 10)
            ],
            currentUserId: "me",
            onTap: {}, onLongPress: {}, onInvite: {}
        )
        .padding(.horizontal, 16)
    }
}

#Preview("Stacked in scroll context") {
    let now = Date()
    return ZStack {
        Color.black.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 16) {
                EventHeroView(
                    event: Event(
                        name: "Joe's 26th Birthday",
                        startsAt: now.addingTimeInterval(-3600),
                        endsAt: now.addingTimeInterval(3600 * 3),
                        releaseAt: now.addingTimeInterval(3600 * 27)
                    ),
                    now: now,
                    members: [
                        MemberWithShots(userId: "me", displayName: "Asad", avatarUrl: nil, shotsTaken: 7),
                        MemberWithShots(userId: "2", displayName: "Joe", avatarUrl: nil, shotsTaken: 3),
                        MemberWithShots(userId: "3", displayName: "Sarah", avatarUrl: nil, shotsTaken: 2)
                    ],
                    currentUserId: "me",
                    onTap: {}, onLongPress: {}, onInvite: {}
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}
