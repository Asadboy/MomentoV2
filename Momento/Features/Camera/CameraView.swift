//
//  CameraView.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Camera component
//  This component provides photo capture functionality using AVFoundation.
//  Uses Apple's recommended camera API for iOS.

import SwiftUI
import AVFoundation
import UIKit
import AudioToolbox

/// SwiftUI view for capturing photos using the device camera
struct CameraView: View {
    @ObservedObject var cameraController: CameraController
    let onPhotoCaptured: (UIImage) -> Void
    let onDismiss: () -> Void
    let photoLimit: Int
    let initialRemaining: Int

    @State private var showShutterFlash = false
    @State private var photosRemaining: Int = 0
    @State private var showSavedIndicator = false
    @State private var shutterShakeOffset: CGFloat = 0
    @State private var isLocked: Bool = false
    @State private var showThatsAWrap: Bool = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Camera viewfinder area
                ZStack {
                    CameraPreviewView(cameraController: cameraController)

                    // Shutter flash effect
                    if showShutterFlash {
                        Color.white
                            .transition(.opacity)
                    }

                    // Overlay UI on viewfinder
                    VStack {
                        // Top bar — just close button
                        HStack {
                            Button {
                                cameraController.stopSession()
                                onDismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(Color.black.opacity(0.4)))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        Spacer()

                        // "Saved" indicator
                        if showSavedIndicator {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Saved!")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Spacer()

                        // Controls row — flash, zoom, flip
                        HStack {
                            Button {
                                cameraController.toggleFlash()
                            } label: {
                                Image(systemName: cameraController.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(cameraController.isFlashOn ? .yellow : .white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                            }

                            Spacer()

                            // Zoom toggle
                            HStack(spacing: 2) {
                                if cameraController.hasUltraWide {
                                    Button {
                                        cameraController.setZoom(ultraWide: true)
                                    } label: {
                                        Text("0.5x")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(cameraController.isUltraWide ? .yellow : .white.opacity(0.5))
                                            .frame(width: 44, height: 28)
                                            .background(
                                                Capsule().fill(cameraController.isUltraWide ? Color.white.opacity(0.15) : Color.clear)
                                            )
                                    }
                                }

                                Button {
                                    cameraController.setZoom(ultraWide: false)
                                } label: {
                                    Text("1.0x")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(!cameraController.isUltraWide ? .yellow : .white.opacity(0.5))
                                        .frame(width: 44, height: 28)
                                        .background(
                                            Capsule().fill(!cameraController.isUltraWide ? Color.white.opacity(0.15) : Color.clear)
                                        )
                                }
                            }

                            Spacer()

                            Button {
                                cameraController.switchCamera()
                            } label: {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }
                }

                // Solid black bottom bar
                HStack(alignment: .center) {
                    // Rolling film counter (left)
                    RollingFilmCounter(
                        remaining: photosRemaining,
                        total: photoLimit,
                        isLocked: isLocked
                    )
                    .frame(maxWidth: .infinity)

                    // Capture button (center)
                    Button {
                        if isLocked {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                            withAnimation(.default) {
                                shutterShakeOffset = 10
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                withAnimation(.default) { shutterShakeOffset = -8 }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                withAnimation(.default) { shutterShakeOffset = 6 }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                                withAnimation(.default) { shutterShakeOffset = 0 }
                            }
                        } else {
                            captureWithFeedback()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(isLocked ? Color.gray.opacity(0.6) : Color.white)
                                .frame(width: 72, height: 72)

                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                .frame(width: 82, height: 82)

                            if isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .offset(x: shutterShakeOffset)
                    .disabled(!cameraController.isSessionRunning)
                    .frame(maxWidth: .infinity)

                    // Right placeholder (for symmetry — future: photo stack)
                    Color.clear
                        .frame(width: 80, height: 80)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                .background(Color.black)
            }
            .background(Color.black)

            // "That's a wrap" overlay
            if showThatsAWrap {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 20) {
                    Text("Thats A Wrap!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Your \(photoLimit) shots are locked in")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Button {
                        onDismiss()
                    } label: {
                        Text("Close Camera")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppTheme.Colors.royalPurple)
                            )
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            cameraController.startSession()
            photosRemaining = initialRemaining
            isLocked = initialRemaining <= 0
        }
        .onDisappear {
            cameraController.stopSession()
        }
        .onChange(of: cameraController.capturedImage) { _, newValue in
            if let image = newValue {
                onPhotoCaptured(image)
                cameraController.clearCapturedImage()

                let wasLastShot = photosRemaining == 1

                // Haptic tick for the counter rolling
                let tick = UIImpactFeedbackGenerator(style: .light)
                tick.impactOccurred()

                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    photosRemaining -= 1
                }

                if photosRemaining <= 0 {
                    isLocked = true
                }

                // Show saved indicator briefly
                withAnimation(.easeOut(duration: 0.2)) {
                    showSavedIndicator = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showSavedIndicator = false
                    }
                }

                // Show "That's a wrap" overlay after last shot
                if wasLastShot {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        let celebration = UINotificationFeedbackGenerator()
                        celebration.notificationOccurred(.success)

                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            showThatsAWrap = true
                        }
                    }
                }
            }
        }
    }

    private func captureWithFeedback() {
        let isLastShot = photosRemaining == 1
        
        // Haptic feedback - celebration for last shot, otherwise medium
        if isLastShot {
            let celebration = UINotificationFeedbackGenerator()
            celebration.prepare()
            celebration.notificationOccurred(.success)
        } else {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }

        // Shutter click sound (system camera shutter sound)
        AudioServicesPlaySystemSound(1108)

        // Flash animation - longer for last shot
        let flashDuration = isLastShot ? 0.1 : 0.05
        withAnimation(.easeOut(duration: flashDuration)) {
            showShutterFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (isLastShot ? 0.2 : 0.1)) {
            withAnimation(.easeIn(duration: 0.15)) {
                showShutterFlash = false
            }
        }

        cameraController.capturePhoto()
    }
}

// MARK: - Rolling Film Counter

/// Disposable camera-style rolling number counter with physical scroll animation
struct RollingFilmCounter: View {
    let remaining: Int
    let total: Int
    let isLocked: Bool

    private let numberHeight: CGFloat = 32

    var body: some View {
        HStack(spacing: 10) {
            // Film icon
            Image(systemName: "film")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(counterColor)

            // Rolling number drum
            ZStack {
                // Number strip that moves
                VStack(spacing: 0) {
                    ForEach((0...total).reversed(), id: \.self) { number in
                        Text("\(number)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(number == remaining ? counterColor : .white.opacity(0.2))
                            .frame(height: numberHeight)
                    }
                }
                .offset(y: CGFloat(remaining - total / 2) * numberHeight)
                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: remaining)
            }
            .frame(width: 36, height: numberHeight * 3)
            .clipped()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var counterColor: Color {
        if isLocked { return .gray }
        if remaining <= 3 { return .orange }
        return .white
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraController: CameraController

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill

        context.coordinator.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.bounds

        if let session = cameraController.captureSession {
            previewLayer.session = session
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
            if previewLayer.session == nil, let session = cameraController.captureSession {
                previewLayer.session = session
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var previewLayer: AVCaptureVideoPreviewLayer? }
}

// MARK: - Camera Controller

class CameraController: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning: Bool = false
    @Published var hasPermission: Bool = false
    @Published var errorMessage: String?
    @Published var isFlashOn: Bool = false
    @Published var isUsingFrontCamera: Bool = false
    @Published var isUltraWide: Bool = false

    var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?

    var hasUltraWide: Bool {
        AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
    }

    override init() {
        super.init()
        checkPermission()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
        case .notDetermined:
            requestPermission()
        default:
            hasPermission = false
        }
    }

    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if granted { self?.setupSession() }
            }
        }
    }

    private func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        let deviceType: AVCaptureDevice.DeviceType = isUltraWide ? .builtInUltraWideCamera : .builtInWideAngleCamera
        guard let videoDevice = AVCaptureDevice.default(deviceType, for: .video, position: position) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) ??
                AVCaptureDevice.default(for: .video) else {
            DispatchQueue.main.async { self.errorMessage = "Camera not available" }
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
            } else {
                DispatchQueue.main.async { self.errorMessage = "Cannot add video input" }
                return
            }
        } catch {
            DispatchQueue.main.async { self.errorMessage = "Error setting up camera: \(error.localizedDescription)" }
            return
        }

        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        } else {
            DispatchQueue.main.async { self.errorMessage = "Cannot add photo output" }
            return
        }

        captureSession = session
    }

    func switchCamera() {
        guard let session = captureSession, let currentInput = videoDeviceInput else { return }

        isUsingFrontCamera.toggle()
        if isUsingFrontCamera { isUltraWide = false }
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back

        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else { return }

        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            session.beginConfiguration()
            session.removeInput(currentInput)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
            } else {
                session.addInput(currentInput)
            }
            session.commitConfiguration()
        } catch {
            debugLog("Error switching camera: \(error)")
        }
    }

    func setZoom(ultraWide: Bool) {
        guard !isUsingFrontCamera, ultraWide != isUltraWide else { return }
        guard let session = captureSession, let currentInput = videoDeviceInput else { return }

        let deviceType: AVCaptureDevice.DeviceType = ultraWide ? .builtInUltraWideCamera : .builtInWideAngleCamera
        guard let newDevice = AVCaptureDevice.default(deviceType, for: .video, position: .back) else { return }

        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            session.beginConfiguration()
            session.removeInput(currentInput)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
                isUltraWide = ultraWide
            } else {
                session.addInput(currentInput)
            }
            session.commitConfiguration()

            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } catch {
            debugLog("Error switching zoom: \(error)")
        }
    }

    func toggleFlash() { isFlashOn.toggle() }

    func startSession() {
        guard hasPermission else { requestPermission(); return }
        if captureSession == nil { setupSession() }
        guard let session = captureSession else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if !session.isRunning {
                session.startRunning()
                DispatchQueue.main.async { self?.isSessionRunning = true }
            }
        }
    }

    func stopSession() {
        guard let session = captureSession else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if session.isRunning {
                session.stopRunning()
                DispatchQueue.main.async { self?.isSessionRunning = false }
            }
        }
    }

    func capturePhoto() {
        guard let photoOutput = photoOutput,
              let session = captureSession,
              session.isRunning else { return }

        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(.on) && isFlashOn {
            settings.flashMode = .on
        } else if photoOutput.supportedFlashModes.contains(.off) {
            settings.flashMode = .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func clearCapturedImage() { capturedImage = nil }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { self.errorMessage = "Error capturing photo: \(error.localizedDescription)" }
            return
        }
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async { self.errorMessage = "Could not process photo" }
            return
        }
        DispatchQueue.main.async { self.capturedImage = image }
    }
}

#Preview {
    CameraView(
        cameraController: CameraController(),
        onPhotoCaptured: { _ in },
        onDismiss: {},
        photoLimit: 10,
        initialRemaining: 8
    )
}
// Preview for "That's a wrap" overlay - edit the copy and see changes instantly!
#Preview("That's A Wrap Overlay") {
    ZStack {
        // Black background (simulating camera behind)
        Color.black.ignoresSafeArea()
        
        // Semi-transparent overlay
        Color.black.opacity(0.85)
            .ignoresSafeArea()
        
        // The overlay content - EDIT THE TEXT BELOW
        VStack(spacing: 20) {
            Text("Roll Complete ")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text("Your 10 shots are now developing.")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Text("You'll see everyone's photos tomorrow.")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Button {
                // Preview only - no action
            } label: {
                Text("Done")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppTheme.Colors.royalPurple)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
        }
        .padding(.horizontal, 40)
    }
}

