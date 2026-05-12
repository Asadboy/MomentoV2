//
//  HapticsManager.swift
//  Momento
//
//  Manages haptic feedback throughout the app for a premium feel.
//
//  Generators are hoisted as instance-level properties and pre-warmed
//  on init (review H29). Apple's docs warn that newly-instantiated
//  generators have a noticeable warm-up cost: the first haptic after
//  instantiation can be latent or dropped under load. After each
//  trigger we call prepare() again so the next call is ready instantly.
//

import UIKit
import SwiftUI

/// Centralized haptic feedback manager for consistent tactile responses
class HapticsManager {
    static let shared = HapticsManager()

    // MARK: - Hoisted generators

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        // Pre-warm so the first user-visible haptic (often the camera
        // shutter or reveal moment) isn't the laggy/dropped one.
        prepareAll()
    }

    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        softImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Impact Feedback

    /// Light tap - for subtle interactions
    func light() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Medium impact - for standard interactions
    func medium() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// Heavy impact - for important moments
    func heavy() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    /// Soft impact - gentle feedback
    func soft() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    /// Rigid impact - firm feedback
    func rigid() {
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }

    // MARK: - Notification Feedback

    /// Success notification - for successful operations
    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Warning notification - for warnings
    func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    /// Error notification - for errors
    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    // MARK: - Selection Feedback

    /// Selection changed - for picker/slider interactions
    func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }

    // MARK: - Custom Patterns

    /// Card flip pattern - for revealing photos
    /// Creates a satisfying "flip" sensation
    func cardFlip() {
        light()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.medium()
        }
    }

    /// Photo reveal pattern - builds anticipation
    /// Light → Medium → Success
    func photoReveal() {
        light()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.medium()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.success()
        }
    }

    /// Celebration pattern - for completing reveal
    /// Creates a "confetti burst" feel
    func celebration() {
        heavy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.success()
        }
    }

    /// Suspense build pattern - for countdown/anticipation
    func suspenseBuild() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) { [weak self] in
                guard let self else { return }
                if i == 0 {
                    self.light()
                } else if i == 1 {
                    self.medium()
                } else {
                    self.heavy()
                }
            }
        }
    }

    /// Button press - standard button feedback
    func buttonPress() {
        soft()
    }

    /// Unlock pattern - for when event becomes ready to reveal
    func unlock() {
        medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.light()
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Adds haptic feedback on tap
    func hapticFeedback(_ style: HapticStyle = .medium) -> some View {
        self.onTapGesture {
            switch style {
            case .light:
                HapticsManager.shared.light()
            case .medium:
                HapticsManager.shared.medium()
            case .heavy:
                HapticsManager.shared.heavy()
            case .success:
                HapticsManager.shared.success()
            case .warning:
                HapticsManager.shared.warning()
            case .error:
                HapticsManager.shared.error()
            }
        }
    }
}

/// Haptic feedback styles
enum HapticStyle {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
}
