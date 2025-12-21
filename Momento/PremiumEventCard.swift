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
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var cameraScale: CGFloat = 1.0
    
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
            return event.isRevealed ? .revealed : .readyToReveal
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
        switch eventState {
        case .upcoming:
            // Progress toward event start (assume event was created 24h before start)
            let totalSeconds = 24.0 * 3600.0
            let remaining = Double(secondsUntilStart)
            return max(0, 1.0 - (remaining / totalSeconds))
        case .live:
            // Progress through the event
            let totalSeconds = event.endsAt.timeIntervalSince(event.startsAt)
            let elapsed = now.timeIntervalSince(event.startsAt)
            return totalSeconds > 0 ? min(1.0, elapsed / totalSeconds) : 0
        case .processing:
            // Progress toward reveal
            let totalSeconds = event.releaseAt.timeIntervalSince(event.endsAt)
            let elapsed = now.timeIntervalSince(event.endsAt)
            return totalSeconds > 0 ? min(1.0, elapsed / totalSeconds) : 0
        default:
            return 1.0
        }
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
                colors: [Color.green.opacity(0.6), Color.green.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .processing:
            return LinearGradient(
                colors: [Color.orange.opacity(0.4), Color.yellow.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            return LinearGradient(
                colors: [Color.white.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var cardBorderWidth: CGFloat {
        switch eventState {
        case .readyToReveal: return 3
        case .live: return 2
        case .processing: return 1.5
        default: return 1
        }
    }
    
    private var cardGlowColor: Color {
        switch eventState {
        case .readyToReveal: return Color.purple.opacity(0.6)
        case .live: return Color.green.opacity(0.3)
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
                    Text(event.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // State-specific subtitle
                    stateSubtitle
                    
                    // Metadata badges
                    HStack(spacing: 8) {
                        // Members
                        MetadataBadge(
                            icon: "person.2.fill",
                            value: "\(event.memberCount)",
                            color: .white.opacity(0.6)
                        )
                        
                        // Photos taken (only show if > 0)
                        if event.photosTaken > 0 {
                            MetadataBadge(
                                icon: "photo.fill",
                                value: "\(event.photosTaken)",
                                color: royalPurple
                            )
                        }
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
            radius: eventState == .readyToReveal ? 20 : (eventState == .live ? 12 : 0),
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
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            royalPurple.opacity(0.15),
                            royalPurple.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    royalPurple.opacity(0.8),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            
            // Time display
            VStack(spacing: 2) {
                Text(formatCompactTime(secondsUntilStart))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(royalPurple)
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
                
                // Photo counter badge
                if event.photosTaken > 0 {
                    Text("\(event.photosTaken)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(royalPurple)
                        )
                }
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
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 4) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("\(event.photosTaken)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private func formatCountdown(_ seconds: Int) -> String {
        let hours = seconds / 3600
        if hours >= 24 {
            let days = hours / 24
            return days == 1 ? "1 day" : "\(days) days"
        } else if hours > 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        } else {
            let minutes = seconds / 60
            return minutes <= 1 ? "soon" : "\(minutes) min"
        }
    }
    
    @ViewBuilder
    private var stateSubtitle: some View {
        switch eventState {
        case .upcoming:
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11, weight: .medium))
                Text("Starts in \(formatCountdown(secondsUntilStart))")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
            
        case .live:
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Live now • Tap to capture")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.green)
            
        case .processing:
            HStack(spacing: 6) {
                Image(systemName: "film")
                    .font(.system(size: 11, weight: .medium))
                Text("Developing • \(formatCountdown(secondsUntilReveal))")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.orange)
            
        case .readyToReveal:
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                Text("Ready to reveal!")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(Color.cyan)
            
        case .revealed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                Text("Photos revealed")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
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
                title: "Joe's 26th",
                coverEmoji: "\u{1F382}",
                startsAt: now.addingTimeInterval(3600 * 12),
                endsAt: now.addingTimeInterval(3600 * 20),
                releaseAt: now.addingTimeInterval(3600 * 44),
                memberCount: 12,
                photosTaken: 0
            ),
            now: now,
            onTap: {},
            onLongPress: {}
        )
        
        // Live state
        PremiumEventCard(
            event: Event(
                title: "NYE House Party",
                coverEmoji: "\u{1F389}",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600 * 5),
                releaseAt: now.addingTimeInterval(3600 * 29),
                memberCount: 28,
                photosTaken: 15
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

