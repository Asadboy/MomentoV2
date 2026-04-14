//
//  OnboardingActionView.swift
//  Momento
//
//  Post-onboarding: create or join. Continues the visual energy from screen 3.
//

import SwiftUI

enum OnboardingAction {
    case create
    case join
}

struct OnboardingActionView: View {
    var onAction: (OnboardingAction) -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Same glow orb as screen 3 — visual continuity
            RadialGradient(
                colors: [
                    Color(red: 0.5, green: 0.0, blue: 0.8).opacity(0.15),
                    Color(red: 0.0, green: 0.6, blue: 1.0).opacity(0.05),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
            .offset(y: -80)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Momento")
                        .font(.custom("RalewayDots-Regular", size: 36))
                        .foregroundColor(.white)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeIn(duration: 0.5).delay(0.2), value: appeared)

                    Text("Your night. Captured.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeIn(duration: 0.5).delay(0.35), value: appeared)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        HapticsManager.shared.medium()
                        onAction(.create)
                    } label: {
                        Text("Create a Momento")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.45), value: appeared)

                    Button {
                        HapticsManager.shared.light()
                        onAction(.join)
                    } label: {
                        Text("Join with a code")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear { appeared = true }
    }
}

#Preview {
    OnboardingActionView(onAction: { _ in })
}
