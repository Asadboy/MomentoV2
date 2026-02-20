//
//  AppTheme.swift
//  Momento
//
//  Centralised design tokens, view modifiers, and button styles.
//

import SwiftUI

// MARK: - Design Tokens

enum AppTheme {

    // MARK: Colors

    enum Colors {
        static let royalPurple = Color(red: 0.5, green: 0.0, blue: 0.8)
        static let glowBlue    = Color(red: 0.0, green: 0.6, blue: 1.0)

        static let cardFill    = Color(red: 0.12, green: 0.1, blue: 0.16)
        static let fieldFill   = Color.white.opacity(0.06)
        static let fieldStroke = Color.white.opacity(0.08)
        static let cardBorder  = Color.white.opacity(0.06)

        static let textPrimary    = Color.white
        static let textSecondary  = Color.white.opacity(0.7)
        static let textTertiary   = Color.white.opacity(0.5)
        static let textQuaternary = Color.white.opacity(0.4)
        static let textMuted      = Color.white.opacity(0.35)

        // Background gradient stops
        static let bgStart = Color(red: 0.05, green: 0.05, blue: 0.12)
        static let bgEnd   = Color(red: 0.08, green: 0.06, blue: 0.15)
    }

    // MARK: Fonts

    enum Fonts {
        static let display   = Font.system(size: 42, weight: .bold, design: .rounded)
        static let h1        = Font.system(size: 32, weight: .bold)
        static let h2        = Font.system(size: 28, weight: .medium, design: .serif)
        static let cardTitle = Font.system(size: 20, weight: .semibold)
        static let body      = Font.system(size: 17, weight: .medium)
        static let bodySmall = Font.system(size: 15, weight: .medium)
        static let caption   = Font.system(size: 13, weight: .medium)
        static let micro     = Font.system(size: 11, weight: .semibold)

        static func mono(size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .monospaced)
        }
    }

    // MARK: Spacing

    enum Spacing {
        static let screenH: CGFloat     = 24
        static let cardPadding: CGFloat  = 20
        static let sectionGap: CGFloat   = 32
        static let elementGap: CGFloat   = 12
        static let ctaBottom: CGFloat    = 40
    }

    // MARK: Radii

    enum Radii {
        static let primaryButton: CGFloat  = 28
        static let card: CGFloat           = 20
        static let innerElement: CGFloat   = 14
        static let tertiaryButton: CGFloat = 16
    }

    // MARK: Dimensions

    enum Dimensions {
        static let primaryButtonHeight: CGFloat = 56
    }
}

// MARK: - View Modifiers

struct MomentoBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            LinearGradient(
                colors: [AppTheme.Colors.bgStart, AppTheme.Colors.bgEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

struct MomentoGlowOrbModifier: ViewModifier {
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = -60

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                LinearGradient(
                    colors: [AppTheme.Colors.bgStart, AppTheme.Colors.bgEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        AppTheme.Colors.royalPurple.opacity(0.15),
                        AppTheme.Colors.glowBlue.opacity(0.05),
                        .clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 300
                )
                .offset(x: offsetX, y: offsetY)
                .ignoresSafeArea()
            }
        )
    }
}

struct MomentoCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .fill(AppTheme.Colors.cardFill)
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .stroke(AppTheme.Colors.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func momentoBackground() -> some View {
        modifier(MomentoBackgroundModifier())
    }

    func momentoGlowOrb(offsetX: CGFloat = 0, offsetY: CGFloat = -60) -> some View {
        modifier(MomentoGlowOrbModifier(offsetX: offsetX, offsetY: offsetY))
    }

    func momentoCard() -> some View {
        modifier(MomentoCardModifier())
    }
}

// MARK: - Button Styles

struct MomentoPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.body)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Dimensions.primaryButtonHeight)
            .background(isEnabled ? Color.white : Color.white.opacity(0.1))
            .foregroundColor(isEnabled ? .black : .white.opacity(0.3))
            .cornerRadius(AppTheme.Radii.primaryButton)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct MomentoSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.body)
            .foregroundColor(AppTheme.Colors.textSecondary)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct MomentoTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.body)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Dimensions.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.tertiaryButton)
                    .fill(Color.white.opacity(0.08))
            )
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct MomentoDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.bodySmall)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Dimensions.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.tertiaryButton)
                    .fill(AppTheme.Colors.fieldStroke)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.tertiaryButton)
                    .stroke(AppTheme.Colors.fieldStroke, lineWidth: 1)
            )
            .foregroundColor(AppTheme.Colors.textTertiary)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
