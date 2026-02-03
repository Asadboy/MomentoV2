//
//  PhotoCaptureSheet.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Photo capture sheet
//  This sheet presents the camera interface for taking photos at events.
//  Photos are stored in-memory for UI-only purposes (no database yet).

import SwiftUI
import UIKit

/// Sheet for capturing photos at an event
struct PhotoCaptureSheet: View {
    @StateObject private var cameraController = CameraController()
    @Binding var isPresented: Bool
    let event: Event
    let onPhotoCaptured: (UIImage, Event) -> Void  // Callback with photo and event
    
    // MARK: - Constants
    
    /// Royal purple accent color
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }
    
    var body: some View {
        ZStack {
            if cameraController.hasPermission {
                // Camera view
                CameraView(
                    cameraController: cameraController,
                    onPhotoCaptured: { image in
                        handlePhotoCaptured(image)
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
            } else {
                // Permission request view
                VStack(spacing: 24) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 64))
                        .foregroundColor(royalPurple)
                    
                    Text("Camera Permission Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Please allow camera access to take photos for \(event.name)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Request Permission") {
                        cameraController.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(royalPurple)
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.05, blue: 0.1),
                            Color(red: 0.08, green: 0.06, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
            
            // Error message overlay
            if let error = cameraController.errorMessage {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.8))
                    )
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    /// Handles captured photo - stays open for multi-capture
    private func handlePhotoCaptured(_ image: UIImage) {
        // Call callback with photo and event
        onPhotoCaptured(image, event)
        
        // Don't dismiss - allow user to take multiple photos
        // User must tap X to close camera
    }
}

#Preview {
    let now = Date()
    return PhotoCaptureSheet(
        isPresented: .constant(true),
        event: Event(
            name: "Test Event",
            coverEmoji: "\u{1F4F8}",
            startsAt: now,
            endsAt: now.addingTimeInterval(6 * 3600),
            releaseAt: now.addingTimeInterval(24 * 3600),
            joinCode: "TEST"
        ),
        onPhotoCaptured: { image, event in
            print("Photo captured for \(event.name)")
        }
    )
}
