//
//  HapticsManager.swift
//  Momento
//
//  Manages haptic feedback throughout the app for a premium feel
//

import UIKit
import SwiftUI

/// Centralized haptic feedback manager for consistent tactile responses
class HapticsManager {
    static let shared = HapticsManager()
    
    private init() {}
    
    // MARK: - Impact Feedback
    
    /// Light tap - for subtle interactions
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Medium impact - for standard interactions
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Heavy impact - for important moments
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Soft impact - iOS 13+ gentle feedback
    @available(iOS 13.0, *)
    func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
    
    /// Rigid impact - iOS 13+ firm feedback
    @available(iOS 13.0, *)
    func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    /// Success notification - for successful operations
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Warning notification - for warnings
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Error notification - for errors
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    /// Selection changed - for picker/slider interactions
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Custom Patterns
    
    /// Card flip pattern - for revealing photos
    /// Creates a satisfying "flip" sensation
    func cardFlip() {
        // Quick succession of light taps
        light()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.medium()
        }
    }
    
    /// Photo reveal pattern - builds anticipation
    /// Light → Medium → Success
    func photoReveal() {
        light()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.medium()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.success()
        }
    }
    
    /// Celebration pattern - for completing reveal
    /// Creates a "confetti burst" feel
    func celebration() {
        heavy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.success()
        }
    }
    
    /// Suspense build pattern - for countdown/anticipation
    func suspenseBuild() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
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
        if #available(iOS 13.0, *) {
            soft()
        } else {
            light()
        }
    }
    
    /// Unlock pattern - for when event becomes ready to reveal
    func unlock() {
        medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.light()
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

