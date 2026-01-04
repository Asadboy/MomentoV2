//
//  SupabaseConfig.swift
//  Momento
//
//  Supabase configuration and credentials
//  DO NOT commit this file with real credentials!
//

import Foundation

enum SupabaseConfig {
    // TODO: Replace with your actual Supabase credentials
    // Get these from: https://app.supabase.com → Settings → API
    
    static let supabaseURL = "https://thnbjfcmawwaxvihggjm.supabase.co"
    
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRobmJqZmNtYXd3YXh2aWhnZ2ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2OTQ1MTksImV4cCI6MjA3ODI3MDUxOX0.3J44x3rZbRAV_rNHiSejiMGVZvc-qsp49FUSph_99DY"
    
    // Validate configuration
    static var isConfigured: Bool {
        !supabaseURL.contains("YOUR_") && !supabaseAnonKey.contains("YOUR_")
    }
}

