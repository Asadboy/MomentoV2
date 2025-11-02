//
//  TimeFormatter.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Time formatting utilities
//  This module handles all time-related calculations and formatting,
//  keeping date/time logic separate from UI components for better testability.

import Foundation

/// Utility class for time-related calculations and formatting
/// Separated from views to make the code more modular and testable
struct TimeFormatter {
    /// Calculates the number of seconds until a target date from a reference date
    /// - Parameters:
    ///   - targetDate: The date we're counting down to
    ///   - referenceDate: The current/reference date to calculate from
    /// - Returns: Number of seconds remaining (0 if already passed)
    static func secondsUntil(_ targetDate: Date, from referenceDate: Date) -> Int {
        max(0, Int(targetDate.timeIntervalSince(referenceDate)))
    }
    
    /// Formats remaining seconds into a human-readable string
    /// Example: 3661 seconds -> "01h 01m 01s"
    /// - Parameter seconds: Total seconds remaining
    /// - Returns: Formatted string with hours, minutes, and seconds
    static func formatRemaining(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02dh %02dm %02ds", hours, minutes, secs)
    }
    
    /// Determines if an event is currently live (release time has passed)
    /// - Parameters:
    ///   - releaseDate: When the event releases
    ///   - currentDate: Current date/time
    /// - Returns: True if the event is live, false otherwise
    static func isLive(releaseDate: Date, currentDate: Date) -> Bool {
        secondsUntil(releaseDate, from: currentDate) == 0
    }
    
    /// Generates a subtitle string for an event based on its release status
    /// - Parameters:
    ///   - releaseDate: When the event releases
    ///   - currentDate: Current date/time
    /// - Returns: Formatted subtitle string (either "live" message or countdown)
    static func eventSubtitle(releaseDate: Date, currentDate: Date) -> String {
        let remaining = secondsUntil(releaseDate, from: currentDate)
        if remaining == 0 {
            return "Photos are live ??"
        }
        return "Releases in \(formatRemaining(remaining))"
    }
}
