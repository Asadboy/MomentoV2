//
//  OnboardingView.swift
//  Momento
//
//  3-screen onboarding: emotional hook → mechanic sequence → reveal payoff.
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .momentoBackground()

            TabView(selection: $currentPage) {
                OnboardingHookPage()
                    .overlay(alignment: .bottom) { pageButton(title: "Next", index: 0) }
                    .tag(0)

                OnboardingMechanicPage()
                    .overlay(alignment: .bottom) { pageButton(title: "Next", index: 1) }
                    .tag(1)

                OnboardingPayoffPage()
                    .overlay(alignment: .bottom) { pageButton(title: "Get Started", index: 2) }
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Skip button
            Button {
                onComplete()
            } label: {
                Text("Skip")
                    .font(AppTheme.Fonts.bodySmall)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.trailing, AppTheme.Spacing.screenH)
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private func pageButton(title: String, index: Int) -> some View {
        Button {
            if index < 2 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage = index + 1
                }
            } else {
                onComplete()
            }
        } label: {
            Text(title)
        }
        .buttonStyle(MomentoPrimaryButtonStyle())
        .padding(.horizontal, AppTheme.Spacing.screenH * 2)
        .padding(.bottom, AppTheme.Spacing.ctaBottom)
    }
}

// MARK: - Parallax helper

private struct ParallaxGeometry: View {
    let factor: CGFloat
    @Binding var parallaxOffset: CGFloat

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: ParallaxKey.self, value: geo.frame(in: .global).minX)
        }
        .onPreferenceChange(ParallaxKey.self) { minX in
            parallaxOffset = minX * (1.0 - factor)
        }
    }
}

private struct ParallaxKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Screen 1: Emotional Hook

private struct OnboardingHookPage: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            Text("Every event\nlooks different\nthrough every lens.")
                .font(AppTheme.Fonts.display)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: appeared)

            Spacer().frame(height: 28)

            Text("Momento brings it all back together.")
                .font(AppTheme.Fonts.bodySmall)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)

            Spacer()
            Spacer()
            Spacer().frame(height: 80)
        }
        .padding(.horizontal, AppTheme.Spacing.screenH)
        .onAppear { appeared = true }
    }
}

// MARK: - Screen 2: The Mechanic (Capture → Locked → Revealed)

private struct OnboardingMechanicPage: View {
    @State private var stepsAppeared = false
    @State private var parallaxOffset: CGFloat = 0

    var body: some View {
        ZStack {
            ParallaxGeometry(factor: 0.85, parallaxOffset: $parallaxOffset)

            VStack(spacing: 0) {
                Spacer()

                Text("Shoot now.\nSee everything later.")
                    .font(AppTheme.Fonts.h1)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer().frame(height: 24)

                Text("No previews. No retakes.\nEverything stays hidden until the event ends.")
                    .font(AppTheme.Fonts.bodySmall)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer().frame(height: 48)

                // 3-step visual sequence — parallax lagged
                HStack(spacing: 0) {
                    // Step 1: Capture
                    stepView(index: 0, title: "Capture") {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                                .frame(width: 56, height: 56)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    // Connector
                    connectorLine(index: 0)

                    // Step 2: Locked
                    stepView(index: 1, title: "Locked") {
                        ZStack {
                            // Mini blurred cards
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.Colors.cardFill)
                                .frame(width: 38, height: 48)
                                .rotationEffect(.degrees(-4))
                                .offset(x: -6)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.Colors.cardFill)
                                .frame(width: 38, height: 48)
                                .rotationEffect(.degrees(3))
                                .offset(x: 4)
                        }
                        .blur(radius: 4)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        )
                        .frame(width: 56, height: 56)
                    }

                    // Connector
                    connectorLine(index: 1)

                    // Step 3: Revealed
                    stepView(index: 2, title: "Revealed") {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.Colors.cardFill)
                                .frame(width: 36, height: 46)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppTheme.Colors.cardBorder, lineWidth: 1)
                                )
                                .rotationEffect(.degrees(-3))
                                .offset(x: -5)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.Colors.cardFill)
                                .frame(width: 36, height: 46)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppTheme.Colors.cardBorder, lineWidth: 1)
                                )
                                .rotationEffect(.degrees(2))
                                .offset(x: 4)
                                .overlay(
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.5))
                                        .offset(x: 12, y: 14)
                                )
                        }
                        .frame(width: 56, height: 56)
                    }
                }
                .offset(x: parallaxOffset)

                Spacer()
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, AppTheme.Spacing.screenH)
        }
        .onAppear { stepsAppeared = true }
    }

    @ViewBuilder
    private func stepView<Content: View>(index: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
            Text(title)
                .font(AppTheme.Fonts.micro)
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(1)
        }
        .opacity(stepsAppeared ? 1 : 0)
        .offset(y: stepsAppeared ? 0 : 14)
        .animation(
            .easeOut(duration: 0.4).delay(Double(index) * 0.2),
            value: stepsAppeared
        )
    }

    @ViewBuilder
    private func connectorLine(index: Int) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .frame(maxWidth: 28)
            .padding(.horizontal, 4)
            .padding(.bottom, 24) // Align with icons, above labels
            .opacity(stepsAppeared ? 1 : 0)
            .animation(
                .easeOut(duration: 0.3).delay(Double(index) * 0.2 + 0.15),
                value: stepsAppeared
            )
    }
}

// MARK: - Screen 3: The Payoff

private struct OnboardingPayoffPage: View {
    @State private var cardsAppeared = false
    @State private var parallaxOffset: CGFloat = 0

    // Card configs: (width, height, rotation, xOffset)
    private let cards: [(w: CGFloat, h: CGFloat, rot: Double, x: CGFloat)] = [
        (70, 95, -5, -55),
        (75, 100, -2, -22),
        (85, 115, 0, 8),   // Center card, biggest
        (72, 98, 3, 40),
        (65, 88, 6, 68),
    ]

    var body: some View {
        ZStack {
            ParallaxGeometry(factor: 0.85, parallaxOffset: $parallaxOffset)

            // Faint radial glow behind cards — the only color hint
            RadialGradient(
                colors: [
                    AppTheme.Colors.royalPurple.opacity(0.08),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 180
            )
            .frame(width: 360, height: 360)
            .offset(x: parallaxOffset, y: 40)
            .opacity(cardsAppeared ? 1 : 0)
            .animation(.easeOut(duration: 0.8).delay(0.4), value: cardsAppeared)

            VStack(spacing: 0) {
                Spacer()

                Text("Then everything\ndrops at once.")
                    .font(AppTheme.Fonts.h1)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer().frame(height: 24)

                Text("The good ones. The blurry ones.\nThe forgotten ones.")
                    .font(AppTheme.Fonts.bodySmall)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer().frame(height: 44)

                // Cascading revealed cards — parallax lagged
                ZStack {
                    ForEach(0..<cards.count, id: \.self) { i in
                        let card = cards[i]
                        let isCenter = i == 2

                        RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                            .fill(AppTheme.Colors.cardFill)
                            .frame(width: card.w, height: card.h)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                                    .stroke(AppTheme.Colors.cardBorder, lineWidth: 1)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                if isCenter {
                                    HStack(spacing: 3) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 9))
                                        Text("7")
                                            .font(AppTheme.Fonts.micro)
                                    }
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(6)
                                }
                            }
                            .shadow(
                                color: .black.opacity(isCenter ? 0.35 : 0.2),
                                radius: isCenter ? 14 : 8,
                                x: 0,
                                y: isCenter ? 6 : 3
                            )
                            .rotationEffect(.degrees(card.rot))
                            .offset(x: card.x)
                            .opacity(cardsAppeared ? 1 : 0)
                            .offset(y: cardsAppeared ? 0 : 24)
                            .animation(
                                .easeOut(duration: 0.45).delay(Double(i) * 0.12),
                                value: cardsAppeared
                            )
                    }
                }
                .frame(height: 140)
                .offset(x: parallaxOffset)

                Spacer()
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, AppTheme.Spacing.screenH)
        }
        .onAppear { cardsAppeared = true }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
