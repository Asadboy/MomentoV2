//
//  OnboardingView.swift
//  Momento
//
//  3-screen onboarding: dots ring → logo, 10 shots mechanic, reveal payoff.
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
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.gray)
            }
            .padding(.trailing, 24)
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(28)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
}

// MARK: - Screen 1: The Hook

struct OnboardingScreen1: View {
    @State private var dotsVisible: [Bool] = Array(repeating: false, count: 10)
    @State private var dotsConverged = false
    @State private var dotsFaded = false
    @State private var logoVisible = false
    @State private var subtitleVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Spacer()

            ZStack {
                // 10 dots in a ring
                ForEach(0..<10, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(
                            x: dotsConverged ? 0 : dotOffset(for: index).x,
                            y: dotsConverged ? 0 : dotOffset(for: index).y
                        )
                        .opacity(dotsVisible[index] ? (dotsFaded ? 0 : 1) : 0)
                        .scaleEffect(dotsVisible[index] ? (dotsConverged ? 0.3 : 1) : 0)
                        .animation(.easeOut(duration: 0.25), value: dotsVisible[index])
                        .animation(.easeInOut(duration: 0.4), value: dotsConverged)
                        .animation(.easeOut(duration: 0.4), value: dotsFaded)
                }

                // Logo appears after dots converge and fade
                Text("Momento")
                    .font(.custom("RalewayDots-Regular", size: 56))
                    .foregroundColor(.white)
                    .opacity(logoVisible ? 1 : 0)
                    .animation(.easeIn(duration: 0.5), value: logoVisible)
            }
            .frame(height: 80)

            Spacer().frame(height: 16)

            Text("Your shared disposable camera")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .opacity(subtitleVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.4), value: subtitleVisible)

            Spacer()
            Spacer()
            Spacer().frame(height: 80)
        }
        .onAppear { startAnimation() }
    }

    private func dotOffset(for index: Int) -> CGPoint {
        let angle = (Double(index) / 10.0) * 2 * .pi - .pi / 2
        let radius: CGFloat = 40
        return CGPoint(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
    }

    private func startAnimation() {
        // Dots appear one by one (0.06s delay each)
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                dotsVisible[i] = true
                HapticsManager.shared.light()
            }
        }

        // After all dots visible (0.6s), converge to center
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dotsConverged = true
        }

        // Fade out dots during convergence
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            dotsFaded = true
        }

        // Logo fades in after dots gone
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            logoVisible = true
            HapticsManager.shared.medium()
        }

        // Subtitle fades in shortly after
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            subtitleVisible = true
        }
    }
}

// MARK: - Screen 2: The Rules

struct OnboardingScreen2: View {
    @State private var dotsFilled: [Bool] = Array(repeating: false, count: 10)
    @State private var dotScales: [CGFloat] = Array(repeating: 1.0, count: 10)
    @State private var titleVisible = false
    @State private var subtitleVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // 10 dots in a horizontal row
            HStack(spacing: 8) {
                ForEach(0..<10, id: \.self) { index in
                    Circle()
                        .fill(dotsFilled[index] ? Color.white : Color.white.opacity(0.15))
                        .frame(width: 12, height: 12)
                        .scaleEffect(dotScales[index])
                }
            }

            Spacer().frame(height: 48)

            // Title
            Text("10 Shots. No retakes.")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(titleVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.4), value: titleVisible)

            Spacer().frame(height: 12)

            // Subtitle
            Text("Like a real disposable camera")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .opacity(subtitleVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.4), value: subtitleVisible)

            Spacer()
            Spacer().frame(height: 80)
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        // Dots fill one by one (0.1s per dot)
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                dotsFilled[i] = true
                HapticsManager.shared.light()

                // Spring scale bump
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    dotScales[i] = 1.3
                }
                // Settle back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        dotScales[i] = 1.0
                    }
                }
            }
        }

        // Text appears after dots complete + 1.2s wait
        // Dots finish at 0.9s, so text at 0.9 + 1.2 = ~2.1s
        // But spec says "after dots complete (1.2s wait)" — dots take 1.0s total, so 1.0 + 1.2 = 2.2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            titleVisible = true
            HapticsManager.shared.medium()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            subtitleVisible = true
        }
    }
}

// MARK: - Screen 3: The Payoff

struct OnboardingScreen3: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            Text("Everyone reveals\ntogether")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 20)

            // Sub-lines
            VStack(spacing: 6) {
                Text("The blurry ones.")
                Text("The funny ones.")
                Text("The ones you forgot you took.")
            }
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer().frame(height: 80)
        }
        .animation(.easeInOut(duration: 0.5), value: appeared)
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - Previews

#Preview("Full Flow") {
    OnboardingView(onComplete: {})
}

#Preview("Screen 1 — The Hook") {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreen1()
    }
}

#Preview("Screen 2 — The Rules") {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreen2()
    }
}

#Preview("Screen 3 — The Payoff") {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreen3()
    }
}
