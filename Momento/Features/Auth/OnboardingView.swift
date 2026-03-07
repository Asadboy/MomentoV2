//
//  OnboardingView.swift
//  Momento
//
//  3-screen onboarding: dots → camera hook, 10 shots mechanic, reveal payoff.
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingScreen1()
                    .overlay(alignment: .bottom) { pageButton(title: "Next", index: 0) }
                    .tag(0)

                OnboardingScreen2()
                    .overlay(alignment: .bottom) { pageButton(title: "Next", index: 1) }
                    .tag(1)

                OnboardingScreen3()
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
                    .foregroundColor(.gray)
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

// MARK: - Screen 1: Dots → Camera

struct OnboardingScreen1: View {
    @State private var appeared = false
    @State private var dotsVisible: [Bool] = Array(repeating: false, count: 10)
    @State private var dotsConverged = false
    @State private var cameraVisible = false
    @State private var line1Visible = false
    @State private var line2Visible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            // Dots → Camera animation
            ZStack {
                // 10 dots that converge to center
                ForEach(0..<10, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .offset(x: dotsConverged ? 0 : dotOffset(for: index).x,
                                y: dotsConverged ? 0 : dotOffset(for: index).y)
                        .opacity(dotsVisible[index] ? (dotsConverged ? 0 : 1) : 0)
                        .scaleEffect(dotsVisible[index] ? (dotsConverged ? 0.3 : 1) : 0)
                        .animation(.easeOut(duration: 0.3), value: dotsVisible[index])
                        .animation(.easeInOut(duration: 0.5), value: dotsConverged)
                }

                // Camera icon appears after dots converge
                Image(systemName: "camera.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.white)
                    .opacity(cameraVisible ? 1 : 0)
                    .scaleEffect(cameraVisible ? 1 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cameraVisible)
            }
            .frame(height: 80)

            Spacer().frame(height: 48)

            // Line 1
            Text("Create your own Momento")
                .font(AppTheme.Fonts.h1)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(line1Visible ? 1 : 0)
                .offset(y: line1Visible ? 0 : 10)
                .animation(.easeOut(duration: 0.5), value: line1Visible)

            Spacer().frame(height: 14)

            // Line 2
            Text("Your Shared Disposable Camera")
                .font(AppTheme.Fonts.bodySmall)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .opacity(line2Visible ? 1 : 0)
                .offset(y: line2Visible ? 0 : 10)
                .animation(.easeOut(duration: 0.5), value: line2Visible)

            Spacer()
            Spacer()
            Spacer().frame(height: 80)
        }
        .padding(.horizontal, AppTheme.Spacing.screenH)
        .onAppear { startAnimation() }
    }

    /// Spread dots in a loose ring around center
    private func dotOffset(for index: Int) -> CGPoint {
        let angle = (Double(index) / 10.0) * 2 * .pi - .pi / 2
        let radius: CGFloat = 50
        return CGPoint(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
    }

    private func startAnimation() {
        // Dots appear one by one
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                dotsVisible[i] = true
                HapticsManager.shared.light()
            }
        }

        // Dots converge to center
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dotsConverged = true
        }

        // Camera appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            cameraVisible = true
            HapticsManager.shared.medium()
        }

        // Line 1 fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            line1Visible = true
            HapticsManager.shared.light()
        }

        // Line 2 fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            line2Visible = true
            HapticsManager.shared.light()
        }
    }
}

// MARK: - Screen 2: 10 Shots

struct OnboardingScreen2: View {
    @State private var appeared = false
    @State private var dotsFilled = 0
    @State private var dotsComplete = false
    @State private var line1Visible = false
    @State private var line2Visible = false
    @State private var line3Visible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 10 dots pulse in one by one
            HStack(spacing: 8) {
                ForEach(0..<10, id: \.self) { index in
                    Circle()
                        .fill(index < dotsFilled ? Color.white : Color.white.opacity(0.15))
                        .frame(width: 12, height: 12)
                        .scaleEffect(index == dotsFilled - 1 && !dotsComplete ? 1.4 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: dotsFilled)
                        .animation(.easeOut(duration: 0.3), value: dotsComplete)
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: appeared)

            Spacer().frame(height: 56)

            // Three lines fade in with haptic
            VStack(spacing: 12) {
                Text("10 Shots")
                    .font(AppTheme.Fonts.h1)
                    .foregroundColor(.white)
                    .opacity(line1Visible ? 1 : 0)
                    .offset(y: line1Visible ? 0 : 10)
                    .animation(.easeOut(duration: 0.5), value: line1Visible)

                Text("No Retakes")
                    .font(AppTheme.Fonts.h1)
                    .foregroundColor(.white)
                    .opacity(line2Visible ? 1 : 0)
                    .offset(y: line2Visible ? 0 : 10)
                    .animation(.easeOut(duration: 0.5), value: line2Visible)

                Text("No Previews")
                    .font(AppTheme.Fonts.h1)
                    .foregroundColor(.white)
                    .opacity(line3Visible ? 1 : 0)
                    .offset(y: line3Visible ? 0 : 10)
                    .animation(.easeOut(duration: 0.5), value: line3Visible)
            }
            .multilineTextAlignment(.center)

            Spacer()
            Spacer().frame(height: 80)
        }
        .padding(.horizontal, AppTheme.Spacing.screenH)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        appeared = true

        // Dots pulse in one by one
        for i in 1...10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    dotsFilled = i
                }
                HapticsManager.shared.light()
            }
        }

        // Dots settle (no more pulsing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            dotsComplete = true
        }

        // Line 1: "10 Shots"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            line1Visible = true
            HapticsManager.shared.medium()
        }

        // Line 2: "No Retakes"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) {
            line2Visible = true
            HapticsManager.shared.light()
        }

        // Line 3: "No Previews"
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            line3Visible = true
            HapticsManager.shared.light()
        }
    }
}

// MARK: - Screen 3: The Reveal

struct OnboardingScreen3: View {
    @State private var appeared = false
    @State private var headerVisible = false
    @State private var line1Visible = false
    @State private var line2Visible = false
    @State private var line3Visible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 6) {
                Text("All Momentos")
                    .font(AppTheme.Fonts.h1)
                    .foregroundColor(.white)
                Text("Get Revealed Tomorrow")
                    .font(AppTheme.Fonts.h1)
                    .foregroundColor(.white)
            }
            .multilineTextAlignment(.center)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 12)
            .animation(.easeOut(duration: 0.5), value: headerVisible)

            Spacer().frame(height: 40)

            // Sub-lines
            VStack(spacing: 10) {
                Text("The Blurry Ones")
                    .opacity(line1Visible ? 1 : 0)
                    .offset(y: line1Visible ? 0 : 8)
                    .animation(.easeOut(duration: 0.5), value: line1Visible)

                Text("The Funny Ones")
                    .opacity(line2Visible ? 1 : 0)
                    .offset(y: line2Visible ? 0 : 8)
                    .animation(.easeOut(duration: 0.5), value: line2Visible)

                Text("The Ones You Forgot You Took")
                    .opacity(line3Visible ? 1 : 0)
                    .offset(y: line3Visible ? 0 : 8)
                    .animation(.easeOut(duration: 0.5), value: line3Visible)
            }
            .font(AppTheme.Fonts.bodySmall)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)

            Spacer()
            Spacer().frame(height: 80)
        }
        .padding(.horizontal, AppTheme.Spacing.screenH)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            headerVisible = true
            HapticsManager.shared.medium()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            line1Visible = true
            HapticsManager.shared.light()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            line2Visible = true
            HapticsManager.shared.light()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            line3Visible = true
            HapticsManager.shared.light()
        }
    }
}

// MARK: - Previews

#Preview("Full Flow") {
    OnboardingView(onComplete: {})
}

#Preview("Screen 1 — Dots to Camera") {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreen1()
    }
}

#Preview("Screen 2 — 10 Shots") {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreen2()
    }
}

#Preview("Screen 3 — Reveal") {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreen3()
    }
}
