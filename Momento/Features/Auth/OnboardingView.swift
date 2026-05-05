//
//  OnboardingView.swift
//  Momento
//
//  3-screen onboarding using real beta photos.
//  Screen 1: dots → logo over moody background
//  Screen 2: 10 dots + real photo prints → "10 Shots. No retakes."
//  Screen 3: photo fan reveal → "Everyone reveals together"
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingScreen1().tag(0)
                OnboardingScreen2().tag(1)
                OnboardingScreen3(isActive: currentPage == 2).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Button lives outside the TabView so it always gets screen width
            VStack {
                Spacer()
                Button {
                    if currentPage < 2 {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(currentPage == 2 ? "Get Started" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(RoundedRectangle(cornerRadius: 28).fill(Color.white.opacity(0.12)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 56)
            }

            // Skip button
            VStack {
                HStack {
                    Spacer()
                    Button { onComplete() } label: {
                        Text("Skip")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 24)
                }
                Spacer()
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Screen 1: The Hook

struct OnboardingScreen1: View {
    @State private var dotsVisible: [Bool] = Array(repeating: false, count: 10)
    @State private var dotsConverged = false
    @State private var dotsFaded = false
    @State private var logoVisible = false
    @State private var subtitleVisible = false
    @State private var bgVisible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Real photo background — very dark, blurred, just texture
            Image("ob_bg")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .blur(radius: 24)
                .opacity(bgVisible ? 0.22 : 0)
                .animation(.easeIn(duration: 1.2).delay(0.8), value: bgVisible)

            // Dark overlay to keep legibility
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Spacer()

                ZStack {
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

                    Text("10shots")
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
        }
        .onAppear { startAnimation() }
    }

    private func dotOffset(for index: Int) -> CGPoint {
        let angle = (Double(index) / 10.0) * 2 * .pi - .pi / 2
        let radius: CGFloat = 40
        return CGPoint(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
    }

    private func startAnimation() {
        bgVisible = true

        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                dotsVisible[i] = true
                HapticsManager.shared.light()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dotsConverged = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dotsFaded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            logoVisible = true
            HapticsManager.shared.medium()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { subtitleVisible = true }
    }
}

// MARK: - Screen 2: The Rule

struct OnboardingScreen2: View {
    @State private var dotsFilled: [Bool] = Array(repeating: false, count: 10)
    @State private var dotScales: [CGFloat] = Array(repeating: 1.0, count: 10)
    @State private var photoVisible: [Bool] = [false, false, false]
    @State private var titleVisible = false
    @State private var subtitleVisible = false

    // Photo names, rotations, offsets for the scattered print look
    private let photos: [(name: String, rotation: Double, offsetX: CGFloat)] = [
        ("ob_p1", -6.0, -80),
        ("ob_p4", 2.0,  0),
        ("ob_p2", 7.0,  80),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 10 shot dots
                HStack(spacing: 8) {
                    ForEach(0..<10, id: \.self) { index in
                        Circle()
                            .fill(dotsFilled[index] ? Color.white : Color.white.opacity(0.15))
                            .frame(width: 12, height: 12)
                            .scaleEffect(dotScales[index])
                    }
                }

                Spacer().frame(height: 44)

                // Scattered photo prints
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        photoCard(photos[i].name)
                            .rotationEffect(.degrees(photos[i].rotation))
                            .offset(x: photos[i].offsetX, y: 0)
                            .opacity(photoVisible[i] ? 1 : 0)
                            .scaleEffect(photoVisible[i] ? 1 : 0.85)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.72)
                                .delay(Double(i) * 0.12),
                                value: photoVisible[i]
                            )
                    }
                }
                .frame(height: 180)

                Spacer().frame(height: 40)

                // Title
                Text("10 Shots.\nNo retakes.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .opacity(titleVisible ? 1 : 0)
                    .animation(.easeIn(duration: 0.4), value: titleVisible)

                Spacer().frame(height: 10)

                Text("Like a real disposable camera")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(subtitleVisible ? 1 : 0)
                    .animation(.easeIn(duration: 0.4), value: subtitleVisible)

                Spacer()
                Spacer().frame(height: 80)
            }
        }
        .onAppear { startAnimation() }
    }

    private func photoCard(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 110, height: 148)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.6), radius: 16, x: 0, y: 8)
    }

    private func startAnimation() {
        for i in 0..<10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                dotsFilled[i] = true
                HapticsManager.shared.light()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { dotScales[i] = 1.3 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { dotScales[i] = 1.0 }
                }
            }
        }

        // Photos appear as dots complete (dots finish at ~1.0s)
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(i) * 0.15) {
                photoVisible[i] = true
                HapticsManager.shared.light()
            }
        }

        // Text after photos settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            titleVisible = true
            HapticsManager.shared.medium()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { subtitleVisible = true }
    }
}

// MARK: - Screen 3: The Payoff

struct OnboardingScreen3: View {
    let isActive: Bool
    @State private var titleVisible = false
    @State private var blurOpacity0: Double = 1
    @State private var blurOpacity1: Double = 1
    @State private var blurOpacity2: Double = 1
    @State private var photoVisible: [Bool] = [false, false, false]
    @State private var line1Visible = false
    @State private var line2Visible = false
    @State private var line3Visible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.5, green: 0.0, blue: 0.8).opacity(0.18),
                    Color(red: 0.0, green: 0.6, blue: 1.0).opacity(0.06),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            .offset(y: -60)
            .opacity(line1Visible ? 1 : 0)
            .animation(.easeIn(duration: 1.2), value: line1Visible)

            VStack(spacing: 0) {
                Spacer()

                Text("Everyone reveals\ntogether")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(titleVisible ? 1 : 0)
                    .animation(.easeIn(duration: 0.5), value: titleVisible)

                Spacer().frame(height: 36)

                ZStack {
                    // Card 0 — left (ob_p4)
                    OnboardingPhotoCard(name: "ob_p4", rotation: 10, offset: CGSize(width: -120, height: 12),
                                        visible: photoVisible[0], blurOpacity: blurOpacity0)
                    // Card 1 — right (ob_p5)
                    OnboardingPhotoCard(name: "ob_p5", rotation: 14, offset: CGSize(width: 120, height: -8),
                                        visible: photoVisible[1], blurOpacity: blurOpacity1)
                    // Card 2 — center/front (ob_p6)
                    OnboardingPhotoCard(name: "ob_p6", rotation: -10, offset: CGSize(width: 0, height: 0),
                                        visible: photoVisible[2], blurOpacity: blurOpacity2)
                }
                .frame(height: 260)

                Spacer().frame(height: 36)

                VStack(spacing: 6) {
                    Text("The blurry ones.")
                        .opacity(line1Visible ? 1 : 0)
                        .offset(y: line1Visible ? 0 : 8)
                        .animation(.easeOut(duration: 0.35), value: line1Visible)

                    Text("The funny ones.")
                        .opacity(line2Visible ? 1 : 0)
                        .offset(y: line2Visible ? 0 : 8)
                        .animation(.easeOut(duration: 0.35), value: line2Visible)

                    Text("The ones you forgot you took.")
                        .opacity(line3Visible ? 1 : 0)
                        .offset(y: line3Visible ? 0 : 8)
                        .animation(.easeOut(duration: 0.35), value: line3Visible)
                }
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)

                Spacer()
                Spacer().frame(height: 80)
            }
        }
        .onChange(of: isActive) {
            if isActive { startAnimation() }
        }
    }

    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            titleVisible = true
            HapticsManager.shared.medium()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)  { photoVisible[0] = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { photoVisible[1] = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)  { photoVisible[2] = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 2.2)) { blurOpacity0 = 0 }
            HapticsManager.shared.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeOut(duration: 2.2)) { blurOpacity1 = 0 }
            HapticsManager.shared.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 2.2)) { blurOpacity2 = 0 }
            HapticsManager.shared.light()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { line1Visible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { line2Visible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            line3Visible = true
            HapticsManager.shared.light()
        }
    }
}

// Dedicated View struct — SwiftUI can properly diff its body and animate
// the blurOpacity Double change when withAnimation drives it from parent.
private struct OnboardingPhotoCard: View {
    let name: String
    let rotation: Double
    let offset: CGSize
    let visible: Bool
    let blurOpacity: Double

    var body: some View {
        ZStack {
            Image(name).resizable().scaledToFill().frame(width: 150, height: 200)
            // Blurred overlay — opacity animates 1→0 driven by withAnimation in parent
            Image(name).resizable().scaledToFill().frame(width: 150, height: 200)
                .blur(radius: 20)
                .opacity(blurOpacity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.5), radius: 18, x: 0, y: 8)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible ? 1 : 0.9)
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: visible)
    }
}

// MARK: - Previews

#Preview("Full Flow") { OnboardingView(onComplete: {}) }
#Preview("Screen 1") { OnboardingScreen1() }
#Preview("Screen 2") { OnboardingScreen2() }
#Preview("Screen 3") { OnboardingScreen3(isActive: true) }
