//
//  PhotoCaptureSheet.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Photo capture sheet
//  This sheet presents the camera interface for taking photos at events.
//  Photos are stored in-memory for UI-only purposes (no database yet).

import AVFoundation
import SwiftUI
import UIKit

/// Sheet for capturing photos at an event
struct PhotoCaptureSheet: View {
    @StateObject private var cameraController = CameraController()
    @Binding var isPresented: Bool
    let event: Event
    let onPhotoCaptured: (UIImage, Event) -> Void  // Callback with photo and event

    /// Tristate for the pre-flight photo-count fetch. We intentionally
    /// never fall back to a fresh full count on failure -- a flaky
    /// network would silently grant the user another 10 shots.
    @State private var loadState: LoadState = .loading
    @Environment(\.scenePhase) private var scenePhase

    enum LoadState {
        case loading
        case loaded(remaining: Int)
        case failed
    }

    // MARK: - Constants

    var body: some View {
        ZStack {
            if cameraController.hasPermission {
                switch loadState {
                case .loading:
                    loadingView

                case .failed:
                    fetchFailedView

                case .loaded(let remaining):
                    CameraView(
                        cameraController: cameraController,
                        onPhotoCaptured: { image in
                            handlePhotoCaptured(image, remaining: remaining)
                        },
                        onDismiss: {
                            isPresented = false
                        },
                        photoLimit: PhotoLimitConfig.defaultPhotoLimit,
                        initialRemaining: remaining
                    )
                }
            } else {
                permissionView
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
        .task {
            await fetchRemainingCount()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                cameraController.checkPermission()
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
            Text("Loading camera…")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var fetchFailedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 8) {
                Text("Couldn't check your shot count")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text("Make sure you're online so the 10-shot limit works correctly.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                Button {
                    Task { await fetchRemainingCount() }
                } label: {
                    Text("Try again")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .clipShape(Capsule())
                }

                Button {
                    isPresented = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var cameraAuthStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    private var permissionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.5))

            Text("Camera Permission Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Please allow camera access to take shots for \(event.name)")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Read camera authorization imperatively here is safe: this branch is
            // only reached when hasPermission == false, and the view re-evaluates
            // whenever hasPermission or scenePhase changes.
            if cameraAuthStatus == .denied || cameraAuthStatus == .restricted {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)

                Text("Camera access is off. Enable it in Settings, then return here.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Button("Request Permission") {
                    cameraController.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
            }

            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Photo Limit

    private func fetchRemainingCount() async {
        await MainActor.run { loadState = .loading }

        guard let userId = SupabaseManager.shared.currentUser?.id,
              let eventUUID = UUID(uuidString: event.id) else {
            // Auth or routing problem — fail closed.
            await MainActor.run { loadState = .failed }
            return
        }

        do {
            let count = try await SupabaseManager.shared.getPhotoCount(
                eventId: eventUUID,
                userId: userId
            )
            let remaining = max(0, PhotoLimitConfig.defaultPhotoLimit - count)
            await MainActor.run { loadState = .loaded(remaining: remaining) }
        } catch {
            debugLog("Failed to fetch photo count: \(error)")
            AnalyticsManager.shared.trackError(
                kind: "photo_count_fetch_failed",
                error: error,
                context: ["event_id": event.id]
            )
            await MainActor.run { loadState = .failed }
        }
    }

    // MARK: - Actions

    /// Handles captured photo - stays open for multi-capture.
    /// `remaining` is the value at the moment the camera was presented;
    /// CameraView owns the live decrement, so this side only needs to
    /// forward the image and track the lifecycle moment for analytics.
    private func handlePhotoCaptured(_ image: UIImage, remaining: Int) {
        onPhotoCaptured(image, event)
        if remaining == 1 {
            AnalyticsManager.shared.track(.shotLimitReached, properties: [
                "event_id": event.id
            ])
        }
    }
}

#Preview {
    let now = Date()
    return PhotoCaptureSheet(
        isPresented: .constant(true),
        event: Event(
            name: "Test Event",
            startsAt: now,
            endsAt: now.addingTimeInterval(6 * 3600),
            releaseAt: now.addingTimeInterval(24 * 3600),
            joinCode: "TEST"
        ),
        onPhotoCaptured: { _, event in
            debugLog("Photo captured for \(event.name)")
        }
    )
}
