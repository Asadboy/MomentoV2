//
//  EventLobbyView.swift
//  Momento
//
//  The full-screen lobby for the featured live/upcoming event. Marquee
//  layout: state line, big left-aligned event name, THE ROLL group progress,
//  vertically-centred roster (avatar + 10 dots per member, current user
//  pinned with an amber ring), Shoot + invite CTA row, and a decorative
//  aperture watermark bleeding off the top-right corner.
//
//  Sized by the parent to the full scroll-viewport height
//  (containerRelativeFrame in ContentView). Live and upcoming only —
//  revealed events render as CompactEventCard instead.
//

import SwiftUI

struct EventLobbyView: View {
    let event: Event
    let now: Date
    let members: [MemberWithShots]
    let currentUserId: String?
    let userPhotoCount: Int
    let hasPastEvents: Bool

    let onShoot: () -> Void
    let onInvite: () -> Void

    private let totalShotsPerMember = 10

    @State private var liveDotPulsing = false

    // MARK: - Derived

    private var eventState: Event.State { event.currentState(at: now) }
    private var isLive: Bool { eventState == .live }

    private var orderedMembers: [MemberWithShots] {
        guard let currentUserId else { return members }
        var me: [MemberWithShots] = []
        var others: [MemberWithShots] = []
        for m in members {
            if m.userId == currentUserId { me.append(m) } else { others.append(m) }
        }
        return me + others
    }

    private var shotsTakenTotal: Int {
        members.reduce(0) { $0 + $1.shotsTaken }
    }

    private var rollTotal: Int {
        members.count * totalShotsPerMember
    }

    private var rollProgress: CGFloat {
        guard rollTotal > 0 else { return 0 }
        return min(1, CGFloat(shotsTakenTotal) / CGFloat(rollTotal))
    }

    private var shotsLeft: Int {
        max(0, totalShotsPerMember - userPhotoCount)
    }

    /// Live and under 30 minutes remaining — the lobby heats up.
    private var isFinalStretch: Bool {
        isLive && event.endsAt.timeIntervalSince(now) < 1800
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ApertureWatermark(progress: rollProgress)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                stateLine
                    .padding(.top, 18)

                Text(event.name)
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-1.5)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.top, 10)

                rollHeader
                    .padding(.top, 26)

                roster
                    .frame(maxHeight: .infinity)

                ctaRow

                footerHint
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, AppTheme.Spacing.screenH)
        }
        .animation(.easeInOut(duration: 0.35), value: members.count)
    }

    // MARK: - State line

    private var stateLine: some View {
        HStack(spacing: 8) {
            if isLive {
                Circle()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 7, height: 7)
                    .opacity(liveDotPulsing ? 1.0 : 0.35)
                    .onAppear { startLivePulse() }
                    .onChange(of: isFinalStretch) { _, _ in startLivePulse() }
                Text("LIVE")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                    .foregroundColor(AppTheme.Colors.accent)
                Text(isFinalStretch
                     ? "— ENDS \(finalStretchClock(to: event.endsAt))"
                     : "— ENDS \(countdownCopy(to: event.endsAt))")
                    .font(AppTheme.Fonts.mono(size: 11, weight: .semibold))
                    .foregroundColor(isFinalStretch
                                     ? AppTheme.Colors.accent.opacity(0.9)
                                     : AppTheme.Colors.textQuaternary)
                    .contentTransition(.numericText())
            } else {
                Text("UPCOMING")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text("— STARTS IN \(countdownCopy(to: event.startsAt))")
                    .font(AppTheme.Fonts.mono(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textQuaternary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - THE ROLL

    private var rollHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("THE ROLL")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                Spacer()
                Text("\(shotsTakenTotal) / \(rollTotal)")
                    .font(AppTheme.Fonts.mono(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 3)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.accentDeep, AppTheme.Colors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * rollProgress), height: 3)

                    // Playhead at the fill edge.
                    if rollProgress > 0 {
                        Circle()
                            .fill(AppTheme.Colors.accent)
                            .frame(width: 7, height: 7)
                            .shadow(color: AppTheme.Colors.accent.opacity(0.8), radius: 5)
                            .offset(x: max(0, geo.size.width * rollProgress - 3.5), y: -2)
                    }
                }
            }
            .frame(height: 7)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: rollProgress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The roll: \(shotsTakenTotal) of \(rollTotal) shots taken")
    }

    // MARK: - Roster

    private var roster: some View {
        // >6 rows can exceed the space between roll bar and CTA on a 393pt
        // screen — scroll within the region rather than squashing rows.
        Group {
            if orderedMembers.count > 6 {
                ScrollView(showsIndicators: false) {
                    rosterRows
                }
            } else {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    rosterRows
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var rosterRows: some View {
        VStack(spacing: 0) {
            ForEach(orderedMembers) { member in
                memberRow(member)
                if member.id != orderedMembers.last?.id {
                    separator
                }
            }
        }
    }

    /// 1px separator that fades to transparent at both ends.
    private var separator: some View {
        LinearGradient(
            colors: [.clear, Color.white.opacity(0.08), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    private func memberRow(_ member: MemberWithShots) -> some View {
        let isMe = member.userId == currentUserId
        return HStack(spacing: 16) {
            LobbyAvatar(member: member, isCurrentUser: isMe)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            ViewThatFits(in: .horizontal) {
                dotsRow(member, size: 15, spacing: 8)
                dotsRow(member, size: 13, spacing: 6)
                dotsRow(member, size: 11, spacing: 5)
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(member.name), \(member.shotsTaken) of \(totalShotsPerMember) shots taken")
    }

    private func dotsRow(_ member: MemberWithShots, size: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalShotsPerMember, id: \.self) { idx in
                LobbyDot(
                    isFilled: idx < member.shotsTaken,
                    isMostRecent: idx == member.shotsTaken - 1,
                    isLive: isLive,
                    size: size
                )
            }
        }
    }

    // MARK: - CTA row

    private var ctaRow: some View {
        HStack(spacing: 12) {
            if isLive {
                Button(action: onShoot) {
                    HStack(spacing: 10) {
                        if shotsLeft > 0 {
                            Circle()
                                .fill(AppTheme.Colors.buttonText)
                                .frame(width: 10, height: 10)
                            Text("Shoot")
                                .font(.system(size: 17, weight: .bold))
                            Text("· \(shotsLeft) LEFT")
                                .font(AppTheme.Fonts.mono(size: 13, weight: .bold))
                                .opacity(0.75)
                        } else {
                            Text("Roll complete")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                }
                .buttonStyle(MomentoPrimaryButtonStyle())
                .disabled(shotsLeft == 0)
                .accessibilityLabel(shotsLeft > 0 ? "Shoot, \(shotsLeft) shots left" : "Roll complete")
            }

            Button(action: onInvite) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 54, height: 54)
                    .background(
                        Circle().strokeBorder(AppTheme.Colors.hairline, lineWidth: 1)
                    )
            }
            .accessibilityLabel("Invite people")
            .frame(maxWidth: isLive ? nil : .infinity, alignment: isLive ? .center : .leading)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerHint: some View {
        if hasPastEvents {
            HStack(spacing: 5) {
                Text("PAST EVENTS")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(AppTheme.Colors.textMuted)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    /// The LIVE dot breathes at 1.4s normally, 0.7s in the final stretch.
    /// Restart from scratch when the phase flips so the new period sticks.
    private func startLivePulse() {
        liveDotPulsing = false
        withAnimation(.easeInOut(duration: isFinalStretch ? 0.7 : 1.4)
            .repeatForever(autoreverses: true)) {
            liveDotPulsing = true
        }
    }

    /// Per-second mono clock for the final stretch: "00:24:37".
    private func finalStretchClock(to date: Date) -> String {
        let s = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// Minute-precision mono countdown: "3H 24M", "42M", "1D 4H".
    private func countdownCopy(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds < 60 { return "<1M" }
        let totalMinutes = seconds / 60
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? "\(days)D \(hours)H" : "\(days)D" }
        if hours > 0 { return minutes > 0 ? "\(hours)H \(minutes)M" : "\(hours)H" }
        return "\(minutes)M"
    }
}

// MARK: - Avatar

/// 42pt avatar. Amber-family gradient fill behind the initial fallback.
/// Current user gets a 3px amber ring offset by a bg-colour gap ring.
private struct LobbyAvatar: View {
    let member: MemberWithShots
    let isCurrentUser: Bool

    private let size: CGFloat = 42

    var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                if isCurrentUser {
                    Circle()
                        .stroke(AppTheme.Colors.bg, lineWidth: 3)
                        .padding(-1.5)
                    Circle()
                        .stroke(AppTheme.Colors.accent, lineWidth: 3)
                        .padding(-4.5)
                }
            }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let raw = member.avatarUrl, !raw.isEmpty, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    initialFallback
                }
            }
        } else {
            initialFallback
        }
    }

    private var initialFallback: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.accentDeep.opacity(0.55),
                        AppTheme.Colors.accent.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Lobby Dot

/// Shot dot: cream radial when filled, amber radial + glow for the most
/// recent shot, hairline-ringed near-transparent when empty. Pops on fill.
private struct LobbyDot: View {
    let isFilled: Bool
    let isMostRecent: Bool
    let isLive: Bool
    let size: CGFloat

    @State private var popScale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(fillStyle)
            .overlay(
                Circle().strokeBorder(
                    isFilled ? Color.clear : AppTheme.Colors.dotEmptyRing,
                    lineWidth: 1
                )
            )
            .frame(width: size, height: size)
            .shadow(
                color: isFilled && isMostRecent && isLive
                    ? AppTheme.Colors.accent.opacity(0.6) : .clear,
                radius: 5
            )
            .scaleEffect(popScale)
            .onChange(of: isFilled) { _, newValue in
                guard newValue else { return }
                popScale = 0.3
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    popScale = 1.0
                }
            }
    }

    private var fillStyle: RadialGradient {
        if !isFilled {
            return RadialGradient(
                colors: [AppTheme.Colors.dotEmptyFill, AppTheme.Colors.dotEmptyFill],
                center: .center, startRadius: 0, endRadius: size
            )
        }
        if isMostRecent && isLive {
            return RadialGradient(
                colors: [AppTheme.Colors.dotLatestLight, AppTheme.Colors.dotLatestDark],
                center: UnitPoint(x: 0.35, y: 0.3),
                startRadius: 0, endRadius: size
            )
        }
        return RadialGradient(
            colors: [AppTheme.Colors.dotCreamLight, AppTheme.Colors.dotCreamDark],
            center: UnitPoint(x: 0.35, y: 0.3),
            startRadius: 0, endRadius: size
        )
    }
}

// MARK: - Aperture Watermark

/// The brand's 10-dot ring, ~300pt, bleeding off the top-right corner behind
/// content. Dots fill clockwise from the top with group progress.
private struct ApertureWatermark: View {
    let progress: CGFloat

    private let ringSize: CGFloat = 300
    private let dotCount = 10

    private var filledCount: Int {
        Int((progress * CGFloat(dotCount)).rounded())
    }

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { idx in
                let angle = (CGFloat(idx) / CGFloat(dotCount)) * 2 * .pi - .pi / 2
                let radius = ringSize / 2
                Circle()
                    .fill(idx < filledCount
                          ? AppTheme.Colors.accent.opacity(0.14)
                          : Color.clear)
                    .overlay(
                        Circle().strokeBorder(
                            idx < filledCount ? Color.clear : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                    )
                    .frame(width: 26, height: 26)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
        .frame(width: ringSize, height: ringSize)
        .offset(x: 110, y: -90)
    }
}

// MARK: - Previews

#Preview("Live — mid game") {
    let now = Date()
    return ZStack {
        EventLobbyView(
            event: Event(
                name: "Joe's 26th Birthday",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(60 * (60 * 3 + 24)),
                releaseAt: now.addingTimeInterval(3600 * 27)
            ),
            now: now,
            members: [
                MemberWithShots(userId: "me", displayName: "Asad",
                                avatarUrl: nil, shotsTaken: 7),
                MemberWithShots(userId: "2", displayName: "Joe",
                                avatarUrl: nil, shotsTaken: 3),
                MemberWithShots(userId: "3", displayName: "Sarah",
                                avatarUrl: nil, shotsTaken: 2),
                MemberWithShots(userId: "4", displayName: "Marc",
                                avatarUrl: nil, shotsTaken: 9)
            ],
            currentUserId: "me",
            userPhotoCount: 7,
            hasPastEvents: true,
            onShoot: {}, onInvite: {}
        )
    }
    .appBackground()
}

#Preview("Upcoming") {
    let now = Date()
    return ZStack {
        EventLobbyView(
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
            userPhotoCount: 0,
            hasPastEvents: false,
            onShoot: {}, onInvite: {}
        )
    }
    .appBackground()
}

#Preview("Roll complete") {
    let now = Date()
    return ZStack {
        EventLobbyView(
            event: Event(
                name: "Sunday Roast",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600),
                releaseAt: now.addingTimeInterval(3600 * 25)
            ),
            now: now,
            members: [
                MemberWithShots(userId: "me", displayName: "Asad", avatarUrl: nil, shotsTaken: 10),
                MemberWithShots(userId: "2", displayName: "Joe", avatarUrl: nil, shotsTaken: 10)
            ],
            currentUserId: "me",
            userPhotoCount: 10,
            hasPastEvents: true,
            onShoot: {}, onInvite: {}
        )
    }
    .appBackground()
}

#Preview("7 members — scrolling roster") {
    let now = Date()
    return ZStack {
        EventLobbyView(
            event: Event(
                name: "Hijack x DoubleDip",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600 * 2),
                releaseAt: now.addingTimeInterval(3600 * 26)
            ),
            now: now,
            members: (0..<7).map {
                MemberWithShots(userId: "\($0)", displayName: "Member \($0)",
                                avatarUrl: nil, shotsTaken: $0)
            },
            currentUserId: "0",
            userPhotoCount: 0,
            hasPastEvents: true,
            onShoot: {}, onInvite: {}
        )
    }
    .appBackground()
}
