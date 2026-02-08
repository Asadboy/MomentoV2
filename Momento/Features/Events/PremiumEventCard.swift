//
//  PremiumEventCard.swift
//  Momento
//
//  Premium event card with 3 distinct states:
//  1. Countdown - Circular progress with time remaining
//  2. Live - Animated camera button with photo counter
//  3. Revealed - Gallery access button
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
    
    @State private var cameraScale: CGFloat = 1.0
    @State private var breathingScale: CGFloat = 1.0
    
    // MARK: - Event State
    
    private enum EventState {
        case upcoming       // Before startsAt - countdown to event start
        case live           // Between startsAt and endsAt - can take photos
        case processing     // Between endsAt and releaseAt - "developing" photos
        case readyToReveal  // After releaseAt - ready for reveal experience
        case revealed       // After user has seen reveal
    }
    
    private var eventState: EventState {
        // Use the Event's proper state logic
        switch event.currentState(at: now) {
        case .upcoming:
            return .upcoming
        case .live:
            return .live
        case .processing:
            return .processing
        case .revealed:
            // Show revealed if user completed their reveal swipe, otherwise ready to reveal
            return userHasCompletedReveal ? .revealed : .readyToReveal
        }
    }
    
    // MARK: - Computed Properties
    
    private func secondsUntil(_ date: Date, from reference: Date) -> Int {
        max(0, Int(date.timeIntervalSince(reference)))
    }
    
    /// Seconds until event starts (for upcoming state)
    private var secondsUntilStart: Int {
        secondsUntil(event.startsAt, from: now)
    }
    
    /// Seconds until event ends (for live state)
    private var secondsUntilEnd: Int {
        secondsUntil(event.endsAt, from: now)
    }
    
    /// Seconds until photos are revealed (for processing state)
    private var secondsUntilReveal: Int {
        secondsUntil(event.releaseAt, from: now)
    }
    
    private var progress: Double {
        let value: Double
        switch eventState {
        case .upcoming:
            // Progress toward event start (assume event was created 24h before start)
            let totalSeconds = 24.0 * 3600.0
            let remaining = Double(secondsUntilStart)
            value = 1.0 - (remaining / totalSeconds)
        case .live:
            // Progress through the event
            let totalSeconds = event.endsAt.timeIntervalSince(event.startsAt)
            let elapsed = now.timeIntervalSince(event.startsAt)
            value = totalSeconds > 0 ? elapsed / totalSeconds : 0
        case .processing:
            // Progress toward reveal
            let totalSeconds = event.releaseAt.timeIntervalSince(event.endsAt)
            let elapsed = now.timeIntervalSince(event.endsAt)
            value = totalSeconds > 0 ? elapsed / totalSeconds : 0
        default:
            return 1.0
        }
        // Clamp to valid range — NaN or infinite values become 0
        guard value.isFinite else { return 0 }
        return min(1.0, max(0, value))
    }
    
    private func formatCompactTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else if m > 0 {
            return "\(m)m"
        } else {
            return "\(seconds)s"
        }
    }
    
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    private var warmGold: Color {
        Color(red: 0.85, green: 0.65, blue: 0.3)
    }

    // Premium silver for completed momentos
    private var premiumSilver: Color {
        Color(red: 0.75, green: 0.78, blue: 0.85)
    }

    private var cardBackground: Color {
        Color(red: 0.12, green: 0.1, blue: 0.16)
    }
    
    private var cardBorderGradient: LinearGradient {
        switch eventState {
        case .readyToReveal:
            return LinearGradient(
                colors: [Color.purple, Color.blue, Color.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .live:
            return LinearGradient(
                colors: [royalPurple.opacity(0.6), royalPurple.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .processing:
            return LinearGradient(
                colors: [Color.orange.opacity(0.4), Color.yellow.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .upcoming:
            return LinearGradient(
                colors: [royalPurple.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .revealed:
            // Premium silver for revealed momentos
            return LinearGradient(
                colors: [premiumSilver.opacity(0.6), premiumSilver.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var cardBorderWidth: CGFloat {
        switch eventState {
        case .readyToReveal: return 3
        case .live: return 2
        case .processing: return 1.5
        case .revealed: return 1.5
        case .upcoming: return 1
        }
    }
    
    private var cardGlowColor: Color {
        switch eventState {
        case .readyToReveal: return Color.purple.opacity(0.6)
        case .live: return royalPurple.opacity(0.4)
        case .revealed: return premiumSilver.opacity(0.3)  // Subtle silver glow for revealed feel
        default: return Color.clear
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Left: Event info
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(event.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // State-specific subtitle
                    stateSubtitle
                    
                    // Metadata badges
                    HStack(spacing: 8) {
                        MetadataBadge(
                            icon: "person.2.fill",
                            value: "\(memberCount)",
                            color: .white.opacity(0.6)
                        )
                        MetadataBadge(
                            icon: "photo.fill",
                            value: "\(photoCount)",
                            color: .white.opacity(0.6)
                        )
                    }
                }
                
                Spacer()
                
                // Right: State indicator (circular countdown, camera, or gallery)
                stateIndicator
                    .frame(width: 72, height: 72)
            }
            .padding(20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    cardBorderGradient,
                    lineWidth: cardBorderWidth
                )
        )
        .shadow(
            color: cardGlowColor,
            radius: eventState == .readyToReveal ? 20 : (eventState == .live ? 10 : (eventState == .revealed ? 12 : 0)),
            x: 0,
            y: 0
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            onLongPress()
        }
    }
    
    // MARK: - State Indicator Views
    
    @ViewBuilder
    private var stateIndicator: some View {
        switch eventState {
        case .upcoming:
            upcomingIndicator
        case .live:
            cameraButton
        case .processing:
            processingIndicator
        case .readyToReveal:
            revealButton
        case .revealed:
            galleryButton
        }
    }
    
    private var upcomingIndicator: some View {
        ZStack {
            // Background circle with breathing animation
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            royalPurple.opacity(0.2),
                            royalPurple.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(breathingScale)

            // Progress ring with breathing animation
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    royalPurple.opacity(0.9),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .scaleEffect(breathingScale)
                .animation(.linear(duration: 1), value: progress)

            // Time + invite hint
            VStack(spacing: 3) {
                Text(formatCompactTime(secondsUntilStart))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(royalPurple)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(royalPurple.opacity(0.7))
            }
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true)
            ) {
                breathingScale = 1.04
            }
        }
    }
    
    private var processingIndicator: some View {
        ZStack {
            // Animated developing effect
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.3),
                            Color.yellow.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(cameraScale)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: cameraScale
                )
            
            // Film icon
            VStack(spacing: 4) {
                Image(systemName: "film.stack")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.orange)
                
                Text(formatCompactTime(secondsUntilReveal))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.8))
            }
        }
        .onAppear {
            cameraScale = 1.08
        }
    }
    
    
    private var cameraButton: some View {
        ZStack {
            // Animated background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            royalPurple.opacity(0.3),
                            royalPurple.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(cameraScale)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: cameraScale
                )
            
            // Camera icon
            VStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(royalPurple)
                
                // Photo counter badge - count fetched separately
            }
        }
        .onAppear {
            cameraScale = 1.1
        }
    }
    
    private var revealButton: some View {
        ZStack {
            // Pulsing glow effect
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.6),
                            Color.blue.opacity(0.4),
                            Color.cyan.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(cameraScale)
                .blur(radius: 8)
                .animation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: cameraScale
                )
            
            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.8),
                            Color.blue.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 2) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Reveal")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .onAppear {
            cameraScale = 1.15
        }
    }
    
    private var galleryButton: some View {
        ZStack {
            // Premium silver gradient background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            premiumSilver.opacity(0.25),
                            premiumSilver.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle inner glow
            Circle()
                .stroke(premiumSilver.opacity(0.4), lineWidth: 1)

            VStack(spacing: 4) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(premiumSilver)

                Text("Relive")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(premiumSilver.opacity(0.9))
            }
        }
    }
    
    /// Humanized time formatting for better emotional connection
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
            return "any moment"
        }
    }

    /// Format for "almost live" state (last 3 hours before start)
    private func formatUpcomingTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        if hours <= 3 && hours >= 1 {
            return "Almost live"
        }
        return "Starts \(formatHumanizedTime(seconds))"
    }

    /// Hype-building subtitle for upcoming events
    private var upcomingSubtitleText: String {
        let hours = secondsUntilStart / 3600

        if hours <= 3 {
            return "Almost time!"
        } else if hours <= 12 {
            return "Invite more!"
        } else {
            return "Rally your crew"
        }
    }

    /// Format for processing/reveal countdown
    private func formatRevealTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 24 {
            let days = hours / 24
            return "~\(days) days"
        } else if hours >= 1 {
            return "~\(hours)h"
        } else if minutes >= 1 {
            return "~\(minutes)m"
        } else {
            return "soon"
        }
    }
    
    @ViewBuilder
    private var stateSubtitle: some View {
        switch eventState {
        case .upcoming:
            HStack(spacing: 6) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 11, weight: .medium))
                Text(upcomingSubtitleText)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(royalPurple.opacity(0.9))

        case .live:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Live now")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.green)

        case .processing:
            HStack(spacing: 6) {
                Image(systemName: "film")
                    .font(.system(size: 11, weight: .medium))
                Text("In the darkroom • reveals \(formatRevealTime(secondsUntilReveal))")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.orange)

        case .readyToReveal:
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                Text("Your photos are ready")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(Color.cyan)

        case .revealed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .medium))
                Text(likedCount > 0 ? "\(likedCount) liked • \(likedCount) saved" : "Tap to relive")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(premiumSilver)
        }
    }
}

// MARK: - Metadata Badge Component

private struct MetadataBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    return VStack(spacing: 20) {
        // Countdown state
        PremiumEventCard(
            event: Event(
                name: "Joe's 26th",
                coverEmoji: "\u{1F382}",
                startsAt: now.addingTimeInterval(3600 * 12),
                endsAt: now.addingTimeInterval(3600 * 20),
                releaseAt: now.addingTimeInterval(3600 * 44)
            ),
            now: now,
            onTap: {},
            onLongPress: {}
        )

        // Live state
        PremiumEventCard(
            event: Event(
                name: "NYE House Party",
                coverEmoji: "\u{1F389}",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600 * 5),
                releaseAt: now.addingTimeInterval(3600 * 29),
                isPremium: true
            ),
            now: now,
            onTap: {},
            onLongPress: {}
        )
    }
    .padding()
    .background(
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color(red: 0.08, green: 0.06, blue: 0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

