//
//  OnboardingActionView.swift
//  Momento
//
//  Post-onboarding screen asking the user to create or join a Momento.
//

import SwiftUI

enum OnboardingAction {
    case create
    case join
}

struct OnboardingActionView: View {
    var onAction: (OnboardingAction) -> Void

    var body: some View {
        ZStack {
            Color.clear
                .momentoBackground()

            VStack(spacing: 0) {
                Spacer()

                // Title group
                VStack(spacing: 12) {
                    Text("What do you\nwant to do?")
                        .font(AppTheme.Fonts.h1)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("You can always do both later")
                        .font(AppTheme.Fonts.bodySmall)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }

                Spacer()
                Spacer()

                VStack(spacing: 16) {
                    // Create — primary CTA
                    Button {
                        HapticsManager.shared.light()
                        onAction(.create)
                    } label: {
                        VStack(spacing: 4) {
                            Text("Create a Momento")
                                .font(AppTheme.Fonts.body)
                            Text("Start a new event")
                                .font(AppTheme.Fonts.caption)
                                .opacity(0.6)
                        }
                    }
                    .buttonStyle(MomentoPrimaryButtonStyle())

                    // Join — ghost CTA
                    Button {
                        HapticsManager.shared.light()
                        onAction(.join)
                    } label: {
                        VStack(spacing: 4) {
                            Text("Join a Momento")
                            Text("Enter a code")
                                .font(AppTheme.Fonts.caption)
                                .opacity(0.6)
                        }
                    }
                    .buttonStyle(MomentoSecondaryButtonStyle())
                    .frame(height: AppTheme.Dimensions.primaryButtonHeight)
                }
                .padding(.horizontal, AppTheme.Spacing.screenH)
                .padding(.bottom, AppTheme.Spacing.ctaBottom)
            }
        }
    }
}

#Preview {
    OnboardingActionView(onAction: { _ in })
}
