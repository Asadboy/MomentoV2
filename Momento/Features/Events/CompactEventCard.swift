//
//  CompactEventCard.swift
//  Momento
//
//  Compact card for active events that are NOT the featured lobby:
//  revealed-pending events (READY to reveal / AWAITING countdown) and any
//  additional live/upcoming events beyond the first. Replaces the revealed
//  branch of the deleted EventHeroView.
//

import SwiftUI

struct CompactEventCard: View {
    let event: Event
    let now: Date

    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var glowPulsing = false

    private var eventState: Event.State { event.currentState(at: now) }
    private var isRevealReady: Bool { event.isRevealReady(at: now) }
    private var isRevealCTA: Bool { eventState == .revealed && isRevealReady }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                statePill
                Text(event.name)
                    .font(AppTheme.Fonts.cardTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(timeCopy)
                    .font(AppTheme.Fonts.mono(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textQuaternary)
            }
            Spacer()
            if isRevealCTA {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)
            }
        }
        .padding(AppTheme.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .fill(AppTheme.Colors.darkCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .stroke(
                    isRevealCTA
                        ? AppTheme.Colors.accent.opacity(glowPulsing ? 0.8 : 0.3)
                        : Color.white.opacity(0.10),
                    lineWidth: isRevealCTA && glowPulsing ? 1.5 : 1
                )
        )
        .shadow(
            color: isRevealCTA ? AppTheme.Colors.accent.opacity(glowPulsing ? 0.3 : 0.1) : .clear,
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

    @ViewBuilder
    private var statePill: some View {
        switch eventState {
        case .live:
            pill("LIVE", color: AppTheme.Colors.accent)
        case .upcoming:
            pill("UPCOMING", color: AppTheme.Colors.textSecondary)
        case .revealed:
            if isRevealReady {
                pill("READY", color: AppTheme.Colors.accent)
            } else {
                pill("AWAITING REVEAL", color: AppTheme.Colors.accent.opacity(0.7))
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(AppTheme.Fonts.label)
            .tracking(2.5)
            .foregroundColor(color)
    }

    private var timeCopy: String {
        switch eventState {
        case .live: return "ENDS IN \(countdown(to: event.endsAt))"
        case .upcoming: return "STARTS IN \(countdown(to: event.startsAt))"
        case .revealed:
            return isRevealReady ? "TAP TO REVEAL" : "REVEALS IN \(countdown(to: event.releaseAt))"
        }
    }

    private func countdown(to date: Date) -> String {
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

#Preview("Ready to reveal") {
    let now = Date()
    return ZStack {
        VStack(spacing: 16) {
            CompactEventCard(
                event: Event(
                    name: "Hijack x DoubleDip",
                    startsAt: now.addingTimeInterval(-3600 * 48),
                    endsAt: now.addingTimeInterval(-3600 * 24),
                    releaseAt: now.addingTimeInterval(-60)
                ),
                now: now,
                onTap: {}, onLongPress: {}
            )
            CompactEventCard(
                event: Event(
                    name: "Sunday Roast",
                    startsAt: now.addingTimeInterval(-3600 * 30),
                    endsAt: now.addingTimeInterval(-3600 * 6),
                    releaseAt: now.addingTimeInterval(3600 * 18)
                ),
                now: now,
                onTap: {}, onLongPress: {}
            )
        }
        .padding(16)
    }
    .appBackground()
}
