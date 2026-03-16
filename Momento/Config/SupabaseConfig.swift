//
//  SupabaseConfig.swift
//  Momento
//
//  Supabase configuration — reads from Info.plist (set via Secrets.xcconfig)
//

import Foundation

enum SupabaseConfig {
    static let supabaseURL: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !value.isEmpty, !value.contains("YOUR_") else {
            fatalError("SUPABASE_URL not set. Copy Secrets.example.xcconfig to Secrets.xcconfig and fill in your values.")
        }
        return value
    }()

    static let supabaseAnonKey: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !value.isEmpty, !value.contains("YOUR_") else {
            fatalError("SUPABASE_ANON_KEY not set. Copy Secrets.example.xcconfig to Secrets.xcconfig and fill in your values.")
        }
        return value
    }()

    static var isConfigured: Bool {
        !supabaseURL.contains("YOUR_") && !supabaseAnonKey.contains("YOUR_")
    }
}
