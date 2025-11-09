//
//  MomentoApp.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//

import SwiftUI

@main
struct MomentoApp: App {
    var body: some Scene {
        WindowGroup {
            // This is your app's entry point: loads the main screen
            AuthenticationRootView()
                .preferredColorScheme(.dark)
        }
    }
}

