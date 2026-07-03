# Lobby Redesign + Theme Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the whole app onto one black + amber visual system, replace the active-event card with a full-screen lobby, and add the two "alive" behaviours (final stretch, roll milestones).

**Architecture:** Three sequential PRs, each in its own worktree off up-to-date `main`. PR 1 rewrites `AppTheme` and sweeps every screen's colours (zero behaviour change — deleted tokens make the compiler find every call site). PR 2 introduces `EventLobbyView` as the first full-viewport "page" of the home scroll and deletes `EventHeroView`. PR 3 adds client-derived final-stretch rendering and a UserDefaults-persisted `MilestoneTracker` wired into `EventStore`, with unit tests in `EventStoreTests` (the only test class CI runs).

**Tech Stack:** SwiftUI (iOS 17.2 target — `containerRelativeFrame` and two-param `onChange` are available), XCTest, UserDefaults persistence, no backend changes.

**Spec:** `Docs/superpowers/specs/2026-07-02-lobby-redesign-design.md`

**Process rules (from CLAUDE.md + memory):**
- Each PR starts in a fresh worktree off up-to-date `main` (superpowers:using-git-worktrees). Copy `Secrets.xcconfig` from the main checkout into each worktree (gitignored, needed to build).
- Build-verify with `xcodebuild build` for the iOS simulator, filtered: `xcodebuild -project Momento.xcodeproj -scheme Momento -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|warning: .*deprecat|BUILD"`. Don't run tests locally — CI does that.
- New Swift files must be registered in `Momento.xcodeproj/project.pbxproj` (PBXFileReference + group + PBXSourcesBuildPhase). Deleted files must be de-registered.
- PR 2 requires an **on-device checkpoint on Asad's iPhone 15 Pro before merge**. PR 3 stacks on PR 2's branch; after PR 2 squash-merges, merge `main` into PR 3's branch (never rebase + force-push).
- All new user-facing strings: **event / shot / 10shots** — never "photo"/"momento".

---

# PR 1 — `theme-foundation`

Branch: `theme-foundation`. Largest diff, zero behaviour change. Delete legacy tokens, add the amber system, fix every compile error the deletion surfaces, and sweep hardcoded cyan/green/orange/purple.

### Task 1.1: Rewrite `AppTheme.swift`

**Files:**
- Modify: `Momento/Components/AppTheme.swift` (full replacement below)

- [ ] **Step 1: Replace the file contents**

Replace the whole of `Momento/Components/AppTheme.swift` with:

```swift
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

struct AppBackgroundModifier: ViewModifier {
    /// 0.09 normally; the final-stretch lobby deepens it to ~0.18.
    var vignetteOpacity: Double = 0.09

    func body(content: Content) -> some View {
        content.background(
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
        )
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
```

Notes on what this deletes (the compiler now finds every stale call site):
`royalPurple`, `glowBlue`, `bgStart`, `bgEnd`, `cardFill`, `blackBg`, `shotGreen`, `Fonts.h2`, `Fonts.display`'s `.rounded` design (now plain bold), `MomentoBackgroundModifier`, `MomentoGlowOrbModifier`, `momentoBackground()`, `momentoGlowOrb()`. `textTertiary` moves 0.5→0.45, `textQuaternary` 0.4→0.35, `textMuted` 0.35→0.25 — no call-site changes needed for those.

- [ ] **Step 2: Build to surface every stale call site**

Run: `xcodebuild -project Momento.xcodeproj -scheme Momento -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"`
Expected: FAILS with errors in (at minimum) `OnboardingView.swift`, `OnboardingActionView.swift`, `InviteCardView.swift` (uses `momentoCard()` — still exists, may be fine), plus any file using `h2`, `blackBg`, `momentoBackground()`, `momentoGlowOrb()`. Record the full error list — it is the sweep worklist for Task 1.2.

### Task 1.2: Fix deleted-token call sites

**Files (known from grep; the build errors are authoritative):**
- Modify: `Momento/Features/Auth/OnboardingActionView.swift:25-34`
- Modify: `Momento/Features/Auth/OnboardingView.swift:301-310`
- Modify: any other file the build flags

- [ ] **Step 1: Replace the purple radial backgrounds**

In both onboarding files, the pattern is a `ZStack`/`background` with a `LinearGradient(bgStart→bgEnd)` and/or `RadialGradient` using `royalPurple`/`glowBlue`. Delete the gradient stack and put `.appBackground()` on the outermost container instead. Example shape (adapt to the actual file):

```swift
// BEFORE
ZStack {
    RadialGradient(
        colors: [AppTheme.Colors.royalPurple.opacity(0.18),
                 AppTheme.Colors.glowBlue.opacity(0.06), .clear],
        center: .center, startRadius: 20, endRadius: 300
    )
    .ignoresSafeArea()
    content
}

// AFTER
ZStack {
    content
}
.appBackground()
```

- [ ] **Step 2: Fix remaining compile errors**

For each remaining error:
- `Fonts.h2` → `AppTheme.Fonts.cardTitle` for card/sheet headings, `AppTheme.Fonts.h1` for screen titles (judge by context; the serif look is gone on purpose).
- `Colors.blackBg` → `AppTheme.Colors.bg`
- `Colors.cardFill` → `AppTheme.Colors.darkCardFill`
- `momentoBackground()` / `momentoGlowOrb()` → `.appBackground()`
- `shotGreen` → `AppTheme.Colors.accent`

- [ ] **Step 3: Build until clean**

Run the same xcodebuild command. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: new AppTheme — black + film amber system, legacy tokens deleted"
```

### Task 1.3: Sweep hardcoded colours (cyan / green / orange / misc)

These compile fine but are off-system. Mapping (apply everywhere below):

| Old | New |
|---|---|
| `.cyan` / `Color.cyan` (READY, reveal glow, dots) | `AppTheme.Colors.accent` |
| `Color.green` (LIVE pill/dot, joined glow) | `AppTheme.Colors.accent` |
| `.orange` (AWAITING REVEAL pill, banners, camera chrome) | `AppTheme.Colors.accent` (keep existing opacity multipliers) |
| `Color(red: 0.06, green: 0.08, blue: 0.14)` (EventCard bg) | `AppTheme.Colors.darkCardFill` |
| `Color(red: 0.04, green: 0.06, blue: 0.10)` (EventHeroView reveal fill) | `AppTheme.Colors.darkCardFill` |
| `Color(red: 1.0, green: 0.42, blue: 0.21)` (RevealCardView) | `AppTheme.Colors.accentDeep` |
| liked hearts (red) | **unchanged — hearts stay red per spec** |

**Files:**
- Modify: `Momento/Features/Events/EventCard.swift` (cyan ×8, orange ×4, hardcoded bg)
- Modify: `Momento/Features/Events/EventHeroView.swift` (cyan ×7, orange ×3, green LIVE pill, hardcoded reveal fill)
- Modify: `Momento/Features/Home/UploadFailureBanner.swift` (orange ×4)
- Modify: `Momento/Features/Home/ActiveEventsSection.swift` (green joined-glow stroke/shadow → accent)
- Modify: `Momento/Features/Camera/CameraView.swift:446` (orange)
- Modify: `Momento/Features/Reveal/RevealCardView.swift:60`
- Modify: `Momento/Components/VerificationCodeInput.swift:152` (preview colour → `AppTheme.Colors.bg`)

- [ ] **Step 1: Apply the mapping in each file**

Mechanical find-and-replace per the table. In `EventHeroView.swift` also change the LIVE pill (`Circle().fill(Color.green)` + `Capsule().fill(Color.green.opacity(0.18))`) to `AppTheme.Colors.accent` with the same opacities.

- [ ] **Step 2: Full-repo verification grep**

Run: `grep -rn --include='*.swift' -E '\.cyan|Color\.green|royalPurple|glowBlue|bgStart|bgEnd|momentoBackground|momentoGlowOrb|shotGreen' Momento/`
Expected: zero hits. Then `grep -rn --include='*.swift' '\.orange' Momento/` — remaining hits must each be justified (none expected).

- [ ] **Step 3: Build + commit**

Run xcodebuild (same command). Expected: `BUILD SUCCEEDED`.

```bash
git add -A
git commit -m "feat: sweep cyan/green/orange onto the single amber accent"
```

### Task 1.4: Reveal + remaining screens spot-check sweep

The spec lists screens that must sit on the system: `SignInView`, `ProfileSetupView`, `CreateMomentoFlow`, `JoinEventSheet`, `EventPreviewModal`, `InviteSheet`/`InviteContentView`, `ProfileView`, `LikedGalleryView`, `FeedRevealView`, `PhotoCaptureSheet`/`CameraView` chrome, `PastEventCard`. Most already use neutral tokens and survive the sweep automatically.

- [ ] **Step 1: Audit each listed file**

For each file, grep for `Color(red`, `Color.black`, `.purple`, `.blue`, `.mint`, `.indigo`, `LinearGradient`, `RadialGradient`. Screen-level `Color.black.ignoresSafeArea()` backgrounds → `.appBackground()` (camera/reveal surfaces where photos show may keep true black — judge: chrome amber, canvas black is fine). Any accent-coloured element → `AppTheme.Colors.accent`. Do **not** restructure layouts.

- [ ] **Step 2: Build + commit**

Expected: `BUILD SUCCEEDED`.

```bash
git add -A
git commit -m "feat: land all remaining screens on the unified theme"
```

### Task 1.5: PR 1 out the door

- [ ] **Step 1: Push and open PR**

```bash
git push -u origin theme-foundation
gh pr create --title "Theme foundation: black + film amber system across the app" --body "<summary per repo convention; note: zero behaviour change, deleted legacy tokens, compiler-driven sweep>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 2: Wait for CI green, squash-merge**

```bash
gh pr checks --watch
gh pr merge --squash --delete-branch
```

---

# PR 2 — `fullscreen-lobby`

Branch: `fullscreen-lobby`, worktree off `main` **after PR 1 merges**. Creates `EventLobbyView` + `CompactEventCard`, restructures `ContentView`, deletes `EventHeroView`. **On-device checkpoint before merge.**

### Task 2.1: `EventLobbyView`

**Files:**
- Create: `Momento/Features/Events/EventLobbyView.swift`
- Modify: `Momento.xcodeproj/project.pbxproj` (register in the `Events` group + Sources phase — copy the byte pattern of the `EventHeroView.swift` entries)

- [ ] **Step 1: Create the file**

```swift
//
//  EventLobbyView.swift
//  Momento
//
//  The full-screen lobby for the featured live/upcoming event. Marquee
//  layout: state line, big left-aligned event name, THE ROLL group progress,
//  vertically-centred roster (avatar + 10 dots per member, current user
//  pinned with an amber ring), Shoot + invite CTA row, and a decorative
//  aperture watermark bleeding off the top-right corner.
//
//  Sized by the parent to the full scroll-viewport height
//  (containerRelativeFrame in ContentView). Live and upcoming only —
//  revealed events render as CompactEventCard instead.
//

import SwiftUI

struct EventLobbyView: View {
    let event: Event
    let now: Date
    let members: [MemberWithShots]
    let currentUserId: String?
    let userPhotoCount: Int
    let hasPastEvents: Bool

    let onShoot: () -> Void
    let onInvite: () -> Void

    private let totalShotsPerMember = 10

    @State private var liveDotPulsing = false

    // MARK: - Derived

    private var eventState: Event.State { event.currentState(at: now) }
    private var isLive: Bool { eventState == .live }

    private var orderedMembers: [MemberWithShots] {
        guard let currentUserId else { return members }
        var me: [MemberWithShots] = []
        var others: [MemberWithShots] = []
        for m in members {
            if m.userId == currentUserId { me.append(m) } else { others.append(m) }
        }
        return me + others
    }

    private var shotsTakenTotal: Int {
        members.reduce(0) { $0 + $1.shotsTaken }
    }

    private var rollTotal: Int {
        members.count * totalShotsPerMember
    }

    private var rollProgress: CGFloat {
        guard rollTotal > 0 else { return 0 }
        return min(1, CGFloat(shotsTakenTotal) / CGFloat(rollTotal))
    }

    private var shotsLeft: Int {
        max(0, totalShotsPerMember - userPhotoCount)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ApertureWatermark(progress: rollProgress)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                stateLine
                    .padding(.top, 18)

                Text(event.name)
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-1.5)
                    .lineSpacing(-2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.top, 10)

                rollHeader
                    .padding(.top, 26)

                roster
                    .frame(maxHeight: .infinity)

                ctaRow

                footerHint
                    .padding(.top, 14)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, AppTheme.Spacing.screenH)
        }
        .animation(.easeInOut(duration: 0.35), value: members.count)
    }

    // MARK: - State line

    private var stateLine: some View {
        HStack(spacing: 8) {
            if isLive {
                Circle()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 7, height: 7)
                    .opacity(liveDotPulsing ? 1.0 : 0.35)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                            liveDotPulsing = true
                        }
                    }
                Text("LIVE")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                    .foregroundColor(AppTheme.Colors.accent)
                Text("— ENDS \(countdownCopy(to: event.endsAt))")
                    .font(AppTheme.Fonts.mono(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textQuaternary)
            } else {
                Text("UPCOMING")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text("— STARTS IN \(countdownCopy(to: event.startsAt))")
                    .font(AppTheme.Fonts.mono(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textQuaternary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - THE ROLL

    private var rollHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("THE ROLL")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                Spacer()
                Text("\(shotsTakenTotal) / \(rollTotal)")
                    .font(AppTheme.Fonts.mono(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 3)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.accentDeep, AppTheme.Colors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * rollProgress), height: 3)

                    // Playhead at the fill edge.
                    if rollProgress > 0 {
                        Circle()
                            .fill(AppTheme.Colors.accent)
                            .frame(width: 7, height: 7)
                            .shadow(color: AppTheme.Colors.accent.opacity(0.8), radius: 5)
                            .offset(x: max(0, geo.size.width * rollProgress - 3.5), y: -2)
                    }
                }
            }
            .frame(height: 7)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: rollProgress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The roll: \(shotsTakenTotal) of \(rollTotal) shots taken")
    }

    // MARK: - Roster

    private var roster: some View {
        // >6 rows can exceed the space between roll bar and CTA on a 393pt
        // screen — scroll within the region rather than squashing rows.
        Group {
            if orderedMembers.count > 6 {
                ScrollView(showsIndicators: false) {
                    rosterRows
                }
            } else {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    rosterRows
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var rosterRows: some View {
        VStack(spacing: 0) {
            ForEach(orderedMembers) { member in
                memberRow(member)
                if member.id != orderedMembers.last?.id {
                    separator
                }
            }
        }
    }

    /// 1px separator that fades to transparent at both ends.
    private var separator: some View {
        LinearGradient(
            colors: [.clear, Color.white.opacity(0.08), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    private func memberRow(_ member: MemberWithShots) -> some View {
        let isMe = member.userId == currentUserId
        return HStack(spacing: 16) {
            LobbyAvatar(member: member, isCurrentUser: isMe)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            ViewThatFits(in: .horizontal) {
                dotsRow(member, size: 15, spacing: 8)
                dotsRow(member, size: 13, spacing: 6)
                dotsRow(member, size: 11, spacing: 5)
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(member.name), \(member.shotsTaken) of \(totalShotsPerMember) shots taken")
    }

    private func dotsRow(_ member: MemberWithShots, size: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalShotsPerMember, id: \.self) { idx in
                LobbyDot(
                    isFilled: idx < member.shotsTaken,
                    isMostRecent: idx == member.shotsTaken - 1,
                    isLive: isLive,
                    size: size
                )
            }
        }
    }

    // MARK: - CTA row

    private var ctaRow: some View {
        HStack(spacing: 12) {
            if isLive {
                Button(action: onShoot) {
                    HStack(spacing: 10) {
                        if shotsLeft > 0 {
                            Circle()
                                .fill(AppTheme.Colors.buttonText)
                                .frame(width: 10, height: 10)
                            Text("Shoot")
                                .font(.system(size: 17, weight: .bold))
                            Text("· \(shotsLeft) LEFT")
                                .font(AppTheme.Fonts.mono(size: 13, weight: .bold))
                                .opacity(0.75)
                        } else {
                            Text("Roll complete")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                }
                .buttonStyle(MomentoPrimaryButtonStyle())
                .disabled(shotsLeft == 0)
                .accessibilityLabel(shotsLeft > 0 ? "Shoot, \(shotsLeft) shots left" : "Roll complete")
            }

            Button(action: onInvite) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 54, height: 54)
                    .background(
                        Circle().strokeBorder(AppTheme.Colors.hairline, lineWidth: 1)
                    )
            }
            .accessibilityLabel("Invite people")
            .frame(maxWidth: isLive ? nil : .infinity, alignment: isLive ? .center : .leading)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerHint: some View {
        if hasPastEvents {
            HStack(spacing: 5) {
                Text("PAST EVENTS")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(AppTheme.Colors.textMuted)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    /// Minute-precision mono countdown: "3H 24M", "42M", "1D 4H".
    private func countdownCopy(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds < 60 { return "<1M" }
        let totalMinutes = seconds / 60
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? "\(days)D \(hours)H" : "\(days)D" }
        if hours > 0 { return minutes > 0 ? "\(hours)H \(minutes)M" : "\(hours)H" }
        return "\(minutes)M"
    }
}

// MARK: - Avatar

/// 42pt avatar. Amber-family gradient fill behind the initial fallback.
/// Current user gets a 3px amber ring offset by a bg-colour gap ring.
private struct LobbyAvatar: View {
    let member: MemberWithShots
    let isCurrentUser: Bool

    private let size: CGFloat = 42

    var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                if isCurrentUser {
                    Circle()
                        .stroke(AppTheme.Colors.bg, lineWidth: 3)
                        .padding(-1.5)
                    Circle()
                        .stroke(AppTheme.Colors.accent, lineWidth: 3)
                        .padding(-4.5)
                }
            }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let raw = member.avatarUrl, !raw.isEmpty, let url = URL(string: raw) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    initialFallback
                }
            }
        } else {
            initialFallback
        }
    }

    private var initialFallback: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.Colors.accentDeep.opacity(0.55),
                        AppTheme.Colors.accent.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Lobby Dot

/// Shot dot: cream radial when filled, amber radial + glow for the most
/// recent shot, hairline-ringed near-transparent when empty. Pops on fill.
private struct LobbyDot: View {
    let isFilled: Bool
    let isMostRecent: Bool
    let isLive: Bool
    let size: CGFloat

    @State private var popScale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(fillStyle)
            .overlay(
                Circle().strokeBorder(
                    isFilled ? Color.clear : AppTheme.Colors.dotEmptyRing,
                    lineWidth: 1
                )
            )
            .frame(width: size, height: size)
            .shadow(
                color: isFilled && isMostRecent && isLive
                    ? AppTheme.Colors.accent.opacity(0.6) : .clear,
                radius: 5
            )
            .scaleEffect(popScale)
            .onChange(of: isFilled) { _, newValue in
                guard newValue else { return }
                popScale = 0.3
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                    popScale = 1.0
                }
            }
    }

    private var fillStyle: RadialGradient {
        if !isFilled {
            return RadialGradient(
                colors: [AppTheme.Colors.dotEmptyFill, AppTheme.Colors.dotEmptyFill],
                center: .center, startRadius: 0, endRadius: size
            )
        }
        if isMostRecent && isLive {
            return RadialGradient(
                colors: [AppTheme.Colors.dotLatestLight, AppTheme.Colors.dotLatestDark],
                center: UnitPoint(x: 0.35, y: 0.3),
                startRadius: 0, endRadius: size
            )
        }
        return RadialGradient(
            colors: [AppTheme.Colors.dotCreamLight, AppTheme.Colors.dotCreamDark],
            center: UnitPoint(x: 0.35, y: 0.3),
            startRadius: 0, endRadius: size
        )
    }
}

// MARK: - Aperture Watermark

/// The brand's 10-dot ring, ~300pt, bleeding off the top-right corner behind
/// content. Dots fill clockwise from the top with group progress.
private struct ApertureWatermark: View {
    let progress: CGFloat

    private let ringSize: CGFloat = 300
    private let dotCount = 10

    private var filledCount: Int {
        Int((progress * CGFloat(dotCount)).rounded())
    }

    var body: some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { idx in
                let angle = (CGFloat(idx) / CGFloat(dotCount)) * 2 * .pi - .pi / 2
                let radius = ringSize / 2
                Circle()
                    .fill(idx < filledCount
                          ? AppTheme.Colors.accent.opacity(0.14)
                          : Color.clear)
                    .overlay(
                        Circle().strokeBorder(
                            idx < filledCount ? Color.clear : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                    )
                    .frame(width: 26, height: 26)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
        .frame(width: ringSize, height: ringSize)
        .offset(x: 110, y: -90)
    }
}

// MARK: - Previews

#Preview("Live — mid game") {
    let now = Date()
    return ZStack {
        EventLobbyView(
            event: Event(
                name: "Joe's 26th Birthday",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(60 * (60 * 3 + 24)),
                releaseAt: now.addingTimeInterval(3600 * 27)
            ),
            now: now,
            members: [
                MemberWithShots(userId: "me", displayName: "Asad",
                                avatarUrl: nil, shotsTaken: 7),
                MemberWithShots(userId: "2", displayName: "Joe",
                                avatarUrl: nil, shotsTaken: 3),
                MemberWithShots(userId: "3", displayName: "Sarah",
                                avatarUrl: nil, shotsTaken: 2),
                MemberWithShots(userId: "4", displayName: "Marc",
                                avatarUrl: nil, shotsTaken: 9)
            ],
            currentUserId: "me",
            userPhotoCount: 7,
            hasPastEvents: true,
            onShoot: {}, onInvite: {}
        )
    }
    .appBackground()
}

#Preview("Upcoming") {
    let now = Date()
    return ZStack {
        EventLobbyView(
            event: Event(
                name: "NYE at Joe's",
                startsAt: now.addingTimeInterval(3600 * 6),
                endsAt: now.addingTimeInterval(3600 * 14),
                releaseAt: now.addingTimeInterval(3600 * 38)
            ),
            now: now,
            members: [
                MemberWithShots(userId: "me", displayName: "Asad", avatarUrl: nil, shotsTaken: 0),
                MemberWithShots(userId: "2", displayName: "Joe", avatarUrl: nil, shotsTaken: 0)
            ],
            currentUserId: "me",
            userPhotoCount: 0,
            hasPastEvents: false,
            onShoot: {}, onInvite: {}
        )
    }
    .appBackground()
}

#Preview("Roll complete") {
    let now = Date()
    return ZStack {
        EventLobbyView(
            event: Event(
                name: "Sunday Roast",
                startsAt: now.addingTimeInterval(-3600),
                endsAt: now.addingTimeInterval(3600),
                releaseAt: now.addingTimeInterval(3600 * 25)
            ),
            now: now,
            members: [
                MemberWithShots(userId: "me", displayName: "Asad", avatarUrl: nil, shotsTaken: 10),
                MemberWithShots(userId: "2", displayName: "Joe", avatarUrl: nil, shotsTaken: 10)
            ],
            currentUserId: "me",
            userPhotoCount: 10,
            hasPastEvents: true,
            onShoot: {}, onInvite: {}
        )
    }
    .appBackground()
}
```

Note: `Event`'s memberwise init signature must match what `EventHeroView` previews use today (name/startsAt/endsAt/releaseAt) — check `Models/Event.swift` and adjust the previews if the init differs.

- [ ] **Step 2: Register in project.pbxproj**

Add PBXFileReference, `Events` group entry, and PBXSourcesBuildPhase entry, copying the exact byte pattern of the existing `EventHeroView.swift` lines (new UUIDs).

- [ ] **Step 3: Build**

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: EventLobbyView — full-screen lobby with roll progress, roster, Shoot CTA, aperture watermark"
```

### Task 2.2: `CompactEventCard` (revealed / non-hero actives)

`EventHeroView` currently renders *all* active events, including revealed-pending ("tap to reveal"). Once it's deleted, non-hero actives need a compact card: revealed-pending (READY amber glow / AWAITING countdown) and any additional live/upcoming events beyond the first.

**Files:**
- Create: `Momento/Features/Events/CompactEventCard.swift`
- Modify: `Momento.xcodeproj/project.pbxproj` (register)

- [ ] **Step 1: Create the file**

```swift
//
//  CompactEventCard.swift
//  Momento
//
//  Compact card for active events that are NOT the featured lobby:
//  revealed-pending events (READY to reveal / AWAITING countdown) and any
//  additional live/upcoming events beyond the first. Replaces the revealed
//  branch of the deleted EventHeroView.
//

import SwiftUI

struct CompactEventCard: View {
    let event: Event
    let now: Date

    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var glowPulsing = false

    private var eventState: Event.State { event.currentState(at: now) }
    private var isRevealReady: Bool { event.isRevealReady(at: now) }
    private var isRevealCTA: Bool { eventState == .revealed && isRevealReady }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                statePill
                Text(event.name)
                    .font(AppTheme.Fonts.cardTitle)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(timeCopy)
                    .font(AppTheme.Fonts.mono(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textQuaternary)
            }
            Spacer()
            if isRevealCTA {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.accent)
            }
        }
        .padding(AppTheme.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .fill(AppTheme.Colors.darkCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .stroke(
                    isRevealCTA
                        ? AppTheme.Colors.accent.opacity(glowPulsing ? 0.8 : 0.3)
                        : Color.white.opacity(0.10),
                    lineWidth: isRevealCTA && glowPulsing ? 1.5 : 1
                )
        )
        .shadow(
            color: isRevealCTA ? AppTheme.Colors.accent.opacity(glowPulsing ? 0.3 : 0.1) : .clear,
            radius: glowPulsing ? 16 : 8
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress()
        }
        .onAppear {
            guard isRevealCTA else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulsing = true
            }
        }
    }

    @ViewBuilder
    private var statePill: some View {
        switch eventState {
        case .live:
            pill("LIVE", color: AppTheme.Colors.accent)
        case .upcoming:
            pill("UPCOMING", color: AppTheme.Colors.textSecondary)
        case .revealed:
            if isRevealReady {
                pill("READY", color: AppTheme.Colors.accent)
            } else {
                pill("AWAITING REVEAL", color: AppTheme.Colors.accent.opacity(0.7))
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(AppTheme.Fonts.label)
            .tracking(2.5)
            .foregroundColor(color)
    }

    private var timeCopy: String {
        switch eventState {
        case .live: return "ENDS IN \(countdown(to: event.endsAt))"
        case .upcoming: return "STARTS IN \(countdown(to: event.startsAt))"
        case .revealed:
            return isRevealReady ? "TAP TO REVEAL" : "REVEALS IN \(countdown(to: event.releaseAt))"
        }
    }

    private func countdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds < 60 { return "<1M" }
        let totalMinutes = seconds / 60
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        if days > 0 { return hours > 0 ? "\(days)D \(hours)H" : "\(days)D" }
        if hours > 0 { return minutes > 0 ? "\(hours)H \(minutes)M" : "\(hours)H" }
        return "\(minutes)M"
    }
}

#Preview("Ready to reveal") {
    let now = Date()
    return ZStack {
        CompactEventCard(
            event: Event(
                name: "Hijack x DoubleDip",
                startsAt: now.addingTimeInterval(-3600 * 48),
                endsAt: now.addingTimeInterval(-3600 * 24),
                releaseAt: now.addingTimeInterval(-60)
            ),
            now: now,
            onTap: {}, onLongPress: {}
        )
        .padding(16)
    }
    .appBackground()
}
```

- [ ] **Step 2: Register in project.pbxproj, build, commit**

Expected: `BUILD SUCCEEDED`.

```bash
git add -A
git commit -m "feat: CompactEventCard for revealed + non-hero active events"
```

### Task 2.3: Home restructure (`ContentView` + `ActiveEventsSection`) and delete `EventHeroView`

**Files:**
- Modify: `Momento/App/ContentView.swift`
- Modify: `Momento/Features/Home/ActiveEventsSection.swift`
- Modify: `Momento/Features/Home/EmptyHomeView.swift` (background only)
- Delete: `Momento/Features/Events/EventHeroView.swift` (+ pbxproj de-registration)

- [ ] **Step 1: Add a hero-selection helper to `EventStore`**

In `Momento/Services/EventStore.swift`, after `pastEvents(at:)`:

```swift
    /// The featured lobby event: the first live/upcoming active. Revealed
    /// events never take the lobby — they render as compact cards.
    func lobbyEvent(at now: Date) -> HydratedEvent? {
        activeEvents(at: now).first {
            let s = $0.event.currentState(at: now)
            return s == .live || s == .upcoming
        }
    }
```

- [ ] **Step 2: Restructure `ContentView.body`'s content branch**

Replace the `ZStack { Color.black... VStack { ... } }` content area with (keep all `.onReceive`/`.task`/modifier plumbing exactly as-is):

```swift
            ZStack {
                VStack(spacing: 0) {
                    HomeHeader(router: router)

                    UploadFailureBanner(sync: sync)
                        .animation(.easeInOut(duration: 0.25), value: sync.failedCount)

                    StaleQueueBanner(sync: sync)
                        .animation(.easeInOut(duration: 0.25), value: sync.staleEntriesAtLaunch)

                    if store.isLoading {
                        Spacer()
                        ProgressView("Loading your events...")
                            .tint(.white)
                            .foregroundColor(.white)
                        Spacer()
                    } else if store.hydratedEvents.isEmpty {
                        EmptyHomeView(router: router)
                    } else {
                        homeScroll
                    }
                }
            }
            .appBackground()
```

and add below `body`:

```swift
    /// First "page" is the full-viewport lobby (when a live/upcoming event
    /// exists); scrolling down reveals remaining active events and past
    /// events. Without a lobby event, the classic sectioned list renders.
    private var homeScroll: some View {
        let lobby = store.lobbyEvent(at: now)
        return ScrollView {
            VStack(spacing: 0) {
                if let lobby {
                    EventLobbyView(
                        event: lobby.event,
                        now: now,
                        members: lobby.members,
                        currentUserId: store.currentUserId,
                        userPhotoCount: lobby.userPhotoCount,
                        hasPastEvents: !store.pastEvents(at: now).isEmpty,
                        onShoot: { router.handleEventTap(lobby.event, now: now, store: store) },
                        onInvite: { router.showInvite(lobby.event) }
                    )
                    .containerRelativeFrame(.vertical)
                }

                LazyVStack(spacing: 16) {
                    ActiveEventsSection(
                        store: store, router: router, now: now,
                        excludedEventId: lobby?.id
                    )
                    PastEventsSection(store: store, router: router, now: now)
                }
                .padding(.horizontal, 16)
                .padding(.top, lobby == nil ? 8 : 24)
                .padding(.bottom, 32)
            }
        }
        .refreshable { await store.loadEvents() }
    }
```

- [ ] **Step 3: Rewrite `ActiveEventsSection`**

Replace the body of `Momento/Features/Home/ActiveEventsSection.swift` with:

```swift
struct ActiveEventsSection: View {
    @ObservedObject var store: EventStore
    @ObservedObject var router: HomeRouter
    let now: Date
    /// The event already rendered as the full-screen lobby, if any.
    var excludedEventId: String? = nil

    var body: some View {
        let active = store.activeEvents(at: now).filter { $0.id != excludedEventId }

        // When the lobby owns the first page, only show this header if
        // there's actually something to list under it. Without a lobby
        // (e.g. only a revealed-pending event) keep the classic header.
        if excludedEventId == nil || !active.isEmpty {
            HStack {
                Text(active.isEmpty ? "NO ACTIVE EVENTS" : "CURRENT EVENTS")
                    .font(AppTheme.Fonts.label)
                    .tracking(2.5)
                    .foregroundColor(AppTheme.Colors.textQuaternary)

                Spacer()

                Button { router.showCreate() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("New")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }

        ForEach(active) { hydrated in
            CompactEventCard(
                event: hydrated.event,
                now: now,
                onTap: { router.handleEventTap(hydrated.event, now: now, store: store) },
                onLongPress: { router.showInvite(hydrated.event) }
            )
            .overlay {
                if store.newlyJoinedEventId == hydrated.id {
                    RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                        .stroke(AppTheme.Colors.accent.opacity(0.6), lineWidth: 2)
                        .shadow(color: AppTheme.Colors.accent.opacity(0.4), radius: 12)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: store.newlyJoinedEventId)
            .contextMenu {
                Button { router.showInvite(hydrated.event) } label: {
                    Label("Invite Friends", systemImage: "person.badge.plus")
                }
            }
        }
    }
}
```

(The joined-glow overlay stays on compact cards only; a joined event that becomes the lobby announces itself by being the lobby.)

- [ ] **Step 4: Delete `EventHeroView.swift`**

```bash
git rm Momento/Features/Events/EventHeroView.swift
```

Remove its PBXFileReference, group entry, and Sources-phase entry from `project.pbxproj`. Build — if anything else still references `EventHeroView` (e.g. `EventsScreenPreview.swift`), update or remove those references.

- [ ] **Step 5: Build + commit**

Expected: `BUILD SUCCEEDED`.

```bash
git add -A
git commit -m "feat: full-screen lobby as the home's first page; EventHeroView deleted"
```

### Task 2.4: PR 2 + on-device checkpoint

- [ ] **Step 1: Push, open PR**

```bash
git push -u origin fullscreen-lobby
gh pr create --title "Full-screen lobby (Marquee layout) replaces the hero card" --body "<summary; call out: on-device checkpoint required before merge — check lobby at 393pt, roster >6 scroll, Shoot CTA wiring, pull-to-refresh, banners overlay>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
gh pr checks --watch
```

- [ ] **Step 2: STOP — device checkpoint**

Do **not** merge. Report to Asad what to verify on the 15 Pro:
- Lobby fills the first page exactly; scroll-down reveals past events; pull-to-refresh works from the lobby
- Roster at 2, 5, and 7+ members (7+ scrolls within its region); 393pt width has no overflow
- Shoot opens the camera; count decrements; `Roll complete` at 0; invite `+` opens InviteSheet
- Upcoming event: no Shoot button, `UPCOMING — STARTS IN…`
- Revealed-pending event shows as compact READY card (amber, not cyan)
- Upload-failure banner overlays the lobby top when a sync failure exists

Merge (squash) only after Asad confirms.

---

# PR 3 — `alive-layer`

Branch: `alive-layer`, worktree off `fullscreen-lobby` (stacked; see process rules — after PR 2 merges, `git merge origin/main` into this branch, never rebase). Final stretch + roll milestones + unit tests.

### Task 3.1: `MilestoneTracker` (TDD)

**Files:**
- Create: `Momento/Services/MilestoneTracker.swift` (+ pbxproj registration in `Services` group)
- Test: `MomentoTests/EventStoreTests.swift` — **tests must live in this class**: CI runs `-only-testing:MomentoTests/EventStoreTests` and nothing else.

- [ ] **Step 1: Write the failing tests**

Append to `MomentoTests/EventStoreTests.swift` (inside the `EventStoreTests` class):

```swift
    // MARK: - Roll milestones (MilestoneTracker)

    private func makeTracker(suite: String) -> (MilestoneTracker, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (MilestoneTracker(defaults: defaults), defaults)
    }

    func test_milestone_firesOnCrossingHalf_onceOnly() {
        let (tracker, defaults) = makeTracker(suite: "milestones-half")
        defer { defaults.removePersistentDomain(forName: "milestones-half") }

        // Baseline observation: below half — never fires.
        XCTAssertNil(tracker.check(eventId: "e1", taken: 5, total: 40))
        // Crossing half (20/40) fires exactly once.
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 21, total: 40), .half)
        // Re-polling at/above half never re-fires.
        XCTAssertNil(tracker.check(eventId: "e1", taken: 22, total: 40))
    }

    func test_milestone_baselineAlreadyPastHalf_neverFires() {
        let (tracker, defaults) = makeTracker(suite: "milestones-baseline")
        defer { defaults.removePersistentDomain(forName: "milestones-baseline") }

        // Joining late into an event already past half: baseline only.
        XCTAssertNil(tracker.check(eventId: "e1", taken: 25, total: 40))
        XCTAssertNil(tracker.check(eventId: "e1", taken: 26, total: 40))
        // But the un-crossed FULL threshold still fires later.
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 40, total: 40), .full)
    }

    func test_milestone_fullTakesPrecedenceWhenBothCrossedAtOnce() {
        let (tracker, defaults) = makeTracker(suite: "milestones-both")
        defer { defaults.removePersistentDomain(forName: "milestones-both") }

        XCTAssertNil(tracker.check(eventId: "e1", taken: 0, total: 20))
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 20, total: 20), .full)
    }

    func test_milestone_firedStatePersistsAcrossInstances() {
        let suite = "milestones-persist"
        let (tracker, defaults) = makeTracker(suite: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertNil(tracker.check(eventId: "e1", taken: 5, total: 40))
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 20, total: 40), .half)

        // "Relaunch": new tracker, same defaults. Baseline re-records, and
        // a later crossing of the already-fired threshold stays silent.
        let tracker2 = MilestoneTracker(defaults: defaults)
        XCTAssertNil(tracker2.check(eventId: "e1", taken: 19, total: 40))
        XCTAssertNil(tracker2.check(eventId: "e1", taken: 21, total: 40))
    }

    func test_milestone_isPerEvent() {
        let (tracker, defaults) = makeTracker(suite: "milestones-perevent")
        defer { defaults.removePersistentDomain(forName: "milestones-perevent") }

        XCTAssertNil(tracker.check(eventId: "e1", taken: 0, total: 20))
        XCTAssertNil(tracker.check(eventId: "e2", taken: 0, total: 20))
        XCTAssertEqual(tracker.check(eventId: "e1", taken: 10, total: 20), .half)
        XCTAssertEqual(tracker.check(eventId: "e2", taken: 10, total: 20), .half)
    }
```

- [ ] **Step 2: Verify they fail to compile**

Run: `xcodebuild -project Momento.xcodeproj -scheme Momento -destination 'generic/platform=iOS Simulator' build-for-testing 2>&1 | grep -E "error:|BUILD"`
Expected: FAIL — `cannot find 'MilestoneTracker' in scope`.

- [ ] **Step 3: Implement `MilestoneTracker`**

Create `Momento/Services/MilestoneTracker.swift`:

```swift
//
//  MilestoneTracker.swift
//  Momento
//
//  Detects roll-milestone crossings (half roll, full roll) for live events.
//
//  Fire rules (spec §3):
//    - At most once per event per threshold — fired state persists in
//      UserDefaults (same durability pattern as RevealStateManager) so
//      re-launches and re-polls never replay a celebration.
//    - The first observation of an event only records a baseline and never
//      fires — joining late (or relaunching) into an event already past
//      half-roll must not replay it. Baselines are intentionally in-memory:
//      after a relaunch the first check re-records a baseline, and any
//      threshold that already fired is blocked by the persisted set.
//

import Foundation

enum RollMilestone: String {
    case half
    case full
}

final class MilestoneTracker {

    private let defaults: UserDefaults
    private let firedKey = "firedRollMilestones"

    /// Last-seen taken-count per event id. In-memory by design (see header).
    private var baselines: [String: Int] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Feed the latest (taken, total) for an event. Returns a milestone the
    /// moment a refresh crosses a threshold the baseline was below and that
    /// hasn't fired before — nil otherwise.
    func check(eventId: String, taken: Int, total: Int) -> RollMilestone? {
        guard total > 0 else { return nil }

        guard let baseline = baselines[eventId] else {
            baselines[eventId] = taken
            return nil
        }
        baselines[eventId] = max(baseline, taken)

        // Full first: crossing both at once celebrates the bigger moment.
        for milestone in [RollMilestone.full, .half] {
            let threshold = milestone == .full ? total : total / 2
            if taken >= threshold, baseline < threshold, !hasFired(eventId, milestone) {
                markFired(eventId, milestone)
                return milestone
            }
        }
        return nil
    }

    // MARK: - Persistence

    private func key(_ eventId: String, _ milestone: RollMilestone) -> String {
        "\(eventId):\(milestone.rawValue)"
    }

    private func hasFired(_ eventId: String, _ milestone: RollMilestone) -> Bool {
        firedSet().contains(key(eventId, milestone))
    }

    private func markFired(_ eventId: String, _ milestone: RollMilestone) {
        var fired = firedSet()
        fired.insert(key(eventId, milestone))
        defaults.set(Array(fired), forKey: firedKey)
    }

    private func firedSet() -> Set<String> {
        Set(defaults.stringArray(forKey: firedKey) ?? [])
    }
}
```

Register in `project.pbxproj` (`Services` group + Sources phase).

- [ ] **Step 4: Build-for-testing, push, let CI run the tests**

Local: `build-for-testing` must succeed. Commit; test results come from CI on the PR.

```bash
git add -A
git commit -m "feat: MilestoneTracker — once-per-event roll milestones with baseline guard"
```

### Task 3.2: Wire milestones into `EventStore` + celebration overlay

**Files:**
- Modify: `Momento/Services/EventStore.swift`
- Modify: `Momento/App/ContentView.swift`
- Test: `MomentoTests/EventStoreTests.swift`

- [ ] **Step 1: Write the failing store-level test**

Append inside `EventStoreTests`:

```swift
    func test_store_firesMilestoneWhenRefreshCrossesHalf() async {
        let suite = "milestones-store"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let now = Date()
        let id = UUID()
        api.myEvents = [.test(
            id: id,
            startsAt: now.addingTimeInterval(-3600),
            endsAt: now.addingTimeInterval(3600),
            releaseAt: now.addingTimeInterval(7200)
        )]
        api.membersWithShots[id] = [
            MemberWithShots(userId: "a", displayName: "A", avatarUrl: nil, shotsTaken: 4),
            MemberWithShots(userId: "b", displayName: "B", avatarUrl: nil, shotsTaken: 5)
        ]
        let store = EventStore(api: api, milestones: MilestoneTracker(defaults: defaults))

        // Baseline: 9/20 — below half, records baseline, no fire.
        await store.loadEvents()
        XCTAssertNil(store.milestoneFire)

        // Refresh crosses half (11/20).
        api.membersWithShots[id] = [
            MemberWithShots(userId: "a", displayName: "A", avatarUrl: nil, shotsTaken: 5),
            MemberWithShots(userId: "b", displayName: "B", avatarUrl: nil, shotsTaken: 6)
        ]
        await store.refreshTick(at: now)

        XCTAssertEqual(store.milestoneFire?.milestone, .half)
        XCTAssertEqual(store.milestoneFire?.eventId, id.uuidString)

        // Dismiss + further refresh: silent.
        store.clearMilestoneFire()
        await store.refreshTick(at: now)
        XCTAssertNil(store.milestoneFire)
    }
```

- [ ] **Step 2: Verify it fails to compile** (`milestoneFire`, `milestones:` init param don't exist yet)

- [ ] **Step 3: Implement in `EventStore`**

In `Momento/Services/EventStore.swift`:

Add after the `newlyJoinedEventId` published property:

```swift
    /// A just-crossed roll milestone to celebrate. The view shows a 1.5s
    /// amber wash and calls clearMilestoneFire().
    @Published var milestoneFire: MilestoneFire? = nil

    struct MilestoneFire: Equatable {
        let eventId: String
        let milestone: RollMilestone
    }
```

Extend the init (keep existing callers source-compatible via the default):

```swift
    private let milestones: MilestoneTracker

    init(api: MomentoAPI = SupabaseManager.shared,
         scheduler: Scheduler = LiveScheduler(),
         milestones: MilestoneTracker = MilestoneTracker()) {
        self.api = api
        self.scheduler = scheduler
        self.milestones = milestones
    }
```

Add the check helper + a clear method:

```swift
    /// Run milestone detection over every live event's current roster.
    /// Called after any refresh that may have moved shot counts.
    private func checkMilestones(at now: Date = Date()) {
        for h in hydratedEvents where h.event.currentState(at: now) == .live {
            guard !h.members.isEmpty else { continue }
            let taken = h.members.reduce(0) { $0 + $1.shotsTaken }
            let total = h.members.count * 10
            if let fired = milestones.check(eventId: h.id, taken: taken, total: total) {
                milestoneFire = MilestoneFire(eventId: h.id, milestone: fired)
            }
        }
    }

    func clearMilestoneFire() {
        milestoneFire = nil
    }
```

Call `checkMilestones()`:
- at the end of `loadEvents()`'s success path, after `await hydrateMembers(loaded: loaded)` (this records baselines on first hydration)
- at the end of `refreshCounts()`, after the member-results loop

- [ ] **Step 4: Celebration overlay in `ContentView`**

Add to `ContentView` (inside the outer `ZStack`, after the `VStack`):

```swift
                if let fire = store.milestoneFire {
                    MilestoneOverlay(milestone: fire.milestone)
                        .transition(.opacity)
                        .onAppear {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            Task {
                                try? await Task.sleep(nanoseconds: 1_500_000_000)
                                withAnimation(.easeOut(duration: 0.4)) {
                                    store.clearMilestoneFire()
                                }
                            }
                        }
                }
```

and wrap the assignment site with animation by adding to the ZStack:

```swift
                .animation(.easeIn(duration: 0.25), value: store.milestoneFire)
```

Add at the bottom of `ContentView.swift`:

```swift
// MARK: - Milestone celebration

/// Full-screen 1.5s amber wash + big type when the group crosses half or
/// full roll. Purely decorative; dismissed by the timer in ContentView.
private struct MilestoneOverlay: View {
    let milestone: RollMilestone

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.Colors.accentDeep.opacity(0.92),
                    AppTheme.Colors.accent.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Text(milestone == .full ? "ROLL COMPLETE" : "HALF WAY\nTHROUGH THE ROLL")
                .font(.system(size: 34, weight: .heavy))
                .tracking(1)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.Colors.buttonText)
        }
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 5: Build-for-testing + commit**

Expected: `build-for-testing` SUCCEEDED (CI verifies the tests pass).

```bash
git add -A
git commit -m "feat: roll-milestone celebrations wired through EventStore with unit tests"
```

### Task 3.3: Final stretch (live, <30 min)

**Files:**
- Modify: `Momento/Features/Events/EventLobbyView.swift`
- Modify: `Momento/App/ContentView.swift`

- [ ] **Step 1: Per-second countdown + faster pulse in the lobby**

In `EventLobbyView`, add derived state:

```swift
    /// Live and under 30 minutes remaining — the lobby heats up.
    private var isFinalStretch: Bool {
        isLive && event.endsAt.timeIntervalSince(now) < 1800
    }
```

In `stateLine`'s live branch, replace the ENDS text with:

```swift
                Text(isFinalStretch
                     ? "— ENDS \(finalStretchClock(to: event.endsAt))"
                     : "— ENDS \(countdownCopy(to: event.endsAt))")
                    .font(AppTheme.Fonts.mono(size: 11, weight: .semibold))
                    .foregroundColor(isFinalStretch
                                     ? AppTheme.Colors.accent.opacity(0.9)
                                     : AppTheme.Colors.textQuaternary)
                    .contentTransition(.numericText())
```

Add the helper:

```swift
    /// Per-second mono clock for the final stretch: "00:24:37".
    private func finalStretchClock(to date: Date) -> String {
        let s = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
```

Speed up the LIVE dot: replace the fixed 1.4s breathe with a period derived from `isFinalStretch` (0.7s vs 1.4s), restarting the animation when the phase flips:

```swift
                Circle()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: 7, height: 7)
                    .opacity(liveDotPulsing ? 1.0 : 0.35)
                    .onAppear { startLivePulse() }
                    .onChange(of: isFinalStretch) { _, _ in startLivePulse() }
```

```swift
    private func startLivePulse() {
        liveDotPulsing = false
        withAnimation(.easeInOut(duration: isFinalStretch ? 0.7 : 1.4)
            .repeatForever(autoreverses: true)) {
            liveDotPulsing = true
        }
    }
```

The clock text updates via the existing 1s `now` tick — no new timers, and the `contentTransition` keeps it from fighting other animations.

- [ ] **Step 2: Deepen the vignette from `ContentView`**

The vignette lives on ContentView's `.appBackground()`. Drive it from the lobby event:

```swift
    /// 0.09 normally; deepens to 0.18 when the lobby event is live with
    /// under 30 minutes remaining (final stretch). Pure derivation from
    /// endsAt − now; no stored state.
    private var vignetteOpacity: Double {
        guard let lobby = store.lobbyEvent(at: now),
              lobby.event.currentState(at: now) == .live,
              lobby.event.endsAt.timeIntervalSince(now) < 1800 else { return 0.09 }
        return 0.18
    }
```

Change `.appBackground()` to `.appBackground(vignetteOpacity: vignetteOpacity)` and add
`.animation(.easeInOut(duration: 1.0), value: vignetteOpacity)` on the same container.

- [ ] **Step 3: Build + commit**

Expected: `BUILD SUCCEEDED`.

```bash
git add -A
git commit -m "feat: final stretch — per-second clock, deeper vignette, faster pulse under 30m"
```

### Task 3.4: PR 3 out the door

- [ ] **Step 1: Push, open PR (base = `fullscreen-lobby` until PR 2 merges, then retarget/merge main)**

```bash
git push -u origin alive-layer
gh pr create --base fullscreen-lobby --title "Alive layer: final stretch + roll milestones" --body "<summary; note stacked on #<PR2>; after #<PR2> squash-merges: retarget to main and 'git merge origin/main' (no rebase)>

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
gh pr checks --watch
```

- [ ] **Step 2: After PR 2 merges — retarget and reconcile**

```bash
gh pr edit --base main
git fetch origin main && git merge origin/main   # identical content merges clean; commit if needed
git push
gh pr checks --watch
```

Squash-merge once CI is green (device checkpoint already happened at PR 2).

---

## Self-review notes

- Spec §1 colors/typography/buttons → Task 1.1; deleted-token sweep → 1.2; cyan/green/orange → 1.3; per-screen sweep → 1.4. Hearts stay red (1.3 table). READY = amber → CompactEventCard (2.2).
- Spec §2 items 1–8 → Task 2.1 (state line, name, roll bar, roster, CTA, footer, watermark) + 2.3 (home restructure, HomeHeader retained, banners overlay, pull-to-refresh, EventHeroView deleted). Dot downsizing kept via ViewThatFits (15→13→11 at the lobby's smaller base size).
- Spec §3 final stretch → 3.3; milestones incl. baseline guard + persistence → 3.1/3.2, tests in `EventStoreTests` (the only class CI runs — do NOT create a new test file).
- Spec §5 per-PR: pbxproj registration (2.1, 2.2, 3.1), build-verify each task, worktree-per-PR (process rules).
- Known judgement calls to document in PR descriptions: create-entry-point when the lobby is up (kept as the below-fold header per one-live-event rule); joined-glow not shown on the lobby itself; grain implemented as a runtime noise tile.
