//
//  AppTheme.swift
//  Momento
//
//  Centralised design tokens, view modifiers, and button styles.
//
//  One unified system (2026-07 redesign): near-black background with a faint
//  amber top vignette, a single Film Amber accent, white text scale, cream
//  dot fills, mono numerals. No boxes/borders for hierarchy — spacing,
//  weight, and opacity only.
//

import SwiftUI

// MARK: - Design Tokens

enum AppTheme {

    // MARK: Colors

    enum Colors {
        /// Near-black canvas — never pure #000.
        static let bg = Color(red: 10 / 255, green: 9 / 255, blue: 8 / 255)        // #0A0908

        /// Film Amber — the one accent, app-wide.
        static let accent     = Color(red: 255 / 255, green: 180 / 255, blue: 80 / 255)  // #FFB450
        static let accentDeep = Color(red: 255 / 255, green: 140 / 255, blue: 66 / 255)  // #FF8C42

        /// Primary button gradient stops + text.
        static let buttonTop    = Color(red: 255 / 255, green: 194 / 255, blue: 94 / 255) // #FFC25E
        static let buttonBottom = Color(red: 255 / 255, green: 154 / 255, blue: 62 / 255) // #FF9A3E
        static let buttonText   = Color(red: 22 / 255, green: 14 / 255, blue: 5 / 255)    // #160E05

        /// Text scale — white, not warm-white; the background carries the warmth.
        static let textPrimary    = Color.white
        static let textSecondary  = Color.white.opacity(0.7)
        static let textTertiary   = Color.white.opacity(0.45)
        static let textQuaternary = Color.white.opacity(0.35)
        static let textMuted      = Color.white.opacity(0.25)

        /// Ghost buttons / separators: solid 1px, never dashed.
        static let hairline = Color.white.opacity(0.18)

        static let fieldFill   = Color.white.opacity(0.06)
        static let fieldStroke = Color.white.opacity(0.08)
        static let cardBorder  = Color.white.opacity(0.06)

        /// Compact cards (revealed events, past events).
        static let darkCardFill   = Color(white: 0.12)
        static let darkCardBorder = Color(white: 0.2)

        /// Shot dots.
        static let dotEmptyFill = Color.white.opacity(0.03)
        static let dotEmptyRing = Color.white.opacity(0.22)
        static let dotCreamLight = Color.white                                          // #FFFFFF
        static let dotCreamDark  = Color(red: 232 / 255, green: 224 / 255, blue: 212 / 255) // #E8E0D4
        static let dotLatestLight = Color(red: 255 / 255, green: 217 / 255, blue: 160 / 255) // #FFD9A0
        static let dotLatestDark  = accent
    }

    // MARK: Fonts

    enum Fonts {
        /// Marquee event name. Pair with `.tracking(-1.5)` at the call site
        /// (tracking is a text modifier, not a Font attribute).
        static let display   = Font.system(size: 40, weight: .bold)
        static let h1        = Font.system(size: 32, weight: .bold)
        static let cardTitle = Font.system(size: 20, weight: .semibold)
        static let body      = Font.system(size: 17, weight: .medium)
        static let bodySmall = Font.system(size: 15, weight: .medium)
        static let caption   = Font.system(size: 13, weight: .medium)
        static let micro     = Font.system(size: 11, weight: .semibold)

        /// Tracked micro-caps label (`THE ROLL`, `LIVE`, `PAST EVENTS`).
        /// Pair with `.tracking(2.5)` at the call site.
        static let label = Font.system(size: 10, weight: .heavy)

        /// Numerals: counts, countdowns, "N LEFT" — camera-hardware precision.
        static func mono(size: CGFloat, weight: Font.Weight = .bold) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    // MARK: Spacing

    enum Spacing {
        static let screenH: CGFloat     = 24
        static let cardPadding: CGFloat = 20
        static let sectionGap: CGFloat  = 32
        static let elementGap: CGFloat  = 12
        static let ctaBottom: CGFloat   = 40
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

// MARK: - Background (bg + amber top vignette + film grain)

/// Film-grain tile, generated once. 128×128 grayscale noise, tiled at very
/// low opacity over the background so black areas aren't dead flat.
enum FilmGrain {
    static let tile: UIImage = {
        let size = 128
        var pixels = [UInt8](repeating: 0, count: size * size)
        for i in 0..<pixels.count { pixels[i] = UInt8.random(in: 0...255) }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let cgImage = CGImage(
            width: size, height: size,
            bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        )!
        return UIImage(cgImage: cgImage)
    }()
}

/// Drop-in background layer: near-black + amber top vignette + grain.
/// Use as the first child of a screen's ZStack, or via `.appBackground()`.
struct AppBackground: View {
    /// 0.09 normally; the final-stretch lobby deepens it to ~0.18.
    var vignetteOpacity: Double = 0.09

    var body: some View {
        ZStack {
            AppTheme.Colors.bg

            // Faint amber vignette from top centre, gone by ~55% height.
            RadialGradient(
                colors: [AppTheme.Colors.accentDeep.opacity(vignetteOpacity), .clear],
                center: .top,
                startRadius: 0,
                endRadius: UIScreen.main.bounds.height * 0.55
            )

            Image(uiImage: FilmGrain.tile)
                .resizable(resizingMode: .tile)
                .opacity(0.035)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct AppBackgroundModifier: ViewModifier {
    var vignetteOpacity: Double = 0.09

    func body(content: Content) -> some View {
        content.background(AppBackground(vignetteOpacity: vignetteOpacity))
    }
}

struct MomentoCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .fill(AppTheme.Colors.darkCardFill)
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
    /// The app-wide background: near-black + amber top vignette + grain.
    func appBackground(vignetteOpacity: Double = 0.09) -> some View {
        modifier(AppBackgroundModifier(vignetteOpacity: vignetteOpacity))
    }

    func momentoCard() -> some View {
        modifier(MomentoCardModifier())
    }
}

// MARK: - Button Styles

/// Primary CTA: amber gradient pill, near-black text, inner top highlight,
/// soft amber outer shadow.
struct MomentoPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.body)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Dimensions.primaryButtonHeight)
            .background(
                Group {
                    if isEnabled {
                        LinearGradient(
                            colors: [AppTheme.Colors.buttonTop, AppTheme.Colors.buttonBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.white.opacity(0.18)
                    }
                }
            )
            .foregroundColor(isEnabled ? AppTheme.Colors.buttonText : .white.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radii.primaryButton))
            .overlay(
                // Inner top highlight — a hairline that fades out by mid-height.
                RoundedRectangle(cornerRadius: AppTheme.Radii.primaryButton)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(isEnabled ? 0.35 : 0), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isEnabled ? AppTheme.Colors.accentDeep.opacity(0.35) : .clear,
                radius: 18, x: 0, y: 6
            )
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

/// Ghost: pill with a solid 1px hairline (never dashed).
struct MomentoGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.body)
            .frame(maxWidth: .infinity)
            .frame(height: AppTheme.Dimensions.primaryButtonHeight)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.primaryButton)
                    .strokeBorder(AppTheme.Colors.hairline, lineWidth: 1)
            )
            .foregroundColor(.white)
            .opacity(configuration.isPressed ? 0.7 : 1)
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
