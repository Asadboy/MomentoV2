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

/// SwiftUI view for capturing photos using the device camera
struct CameraView: View {
    @ObservedObject var cameraController: CameraController
    let onPhotoCaptured: (UIImage) -> Void  // Callback when photo is captured
    let onDismiss: () -> Void  // Callback to dismiss camera
    
    @State private var showShutterFlash = false
    @State private var photoCount = 0
    @State private var showSavedIndicator = false
    
    // MARK: - Constants
    
    /// Royal purple accent color
    private var royalPurple: Color {
        AppTheme.Colors.royalPurple
    }
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraController: cameraController)
                .ignoresSafeArea()
            
            // Shutter flash effect
            if showShutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // UI overlay
            VStack {
                // Top bar
                HStack {
                    // Close button
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
                    
                    // Photo count indicator
                    if photoCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 14))
                            Text("\(photoCount)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                    }
                    
                    Spacer()
                    
                    // Flash toggle
                    Button {
                        cameraController.toggleFlash()
                    } label: {
                        Image(systemName: cameraController.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(cameraController.isFlashOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // "Saved" indicator that appears briefly
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
                
                // Bottom controls
                HStack(alignment: .center, spacing: 60) {
                    // Placeholder for symmetry
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                    
                    // Capture button
                    Button {
                        captureWithFeedback()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                .frame(width: 90, height: 90)
                        }
                    }
                    .disabled(!cameraController.isSessionRunning)
                    
                    // Camera flip button
                    Button {
                        cameraController.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .background(Color.black)
        .onAppear {
            cameraController.startSession()
        }
        .onDisappear {
            cameraController.stopSession()
        }
        .onChange(of: cameraController.capturedImage) { _, newValue in
            if let image = newValue {
                onPhotoCaptured(image)
                cameraController.clearCapturedImage()
                photoCount += 1
                
                // Show saved indicator briefly
                withAnimation(.easeOut(duration: 0.2)) {
                    showSavedIndicator = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showSavedIndicator = false
                    }
                }
            }
        }
    }
    
    private func captureWithFeedback() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Shutter flash animation
        withAnimation(.easeOut(duration: 0.05)) {
            showShutterFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.15)) {
                showShutterFlash = false
            }
        }
        
        // Capture photo
        cameraController.capturePhoto()
    }
}

// MARK: - Camera Preview View

/// UIViewRepresentable wrapper for camera preview
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraController: CameraController
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill
        
        // Store reference
        context.coordinator.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)
        
        // Set initial frame
        previewLayer.frame = view.bounds
        
        // Setup session when available
        if let session = cameraController.captureSession {
            previewLayer.session = session
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
            
            // Setup session if not already set
            if previewLayer.session == nil, let session = cameraController.captureSession {
                previewLayer.session = session
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Camera Controller

/// Observable object that manages camera session and photo capture
class CameraController: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning: Bool = false
    @Published var hasPermission: Bool = false
    @Published var errorMessage: String?
    @Published var isFlashOn: Bool = false
    @Published var isUsingFrontCamera: Bool = false
    
    var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Permission Management
    
    /// Checks camera permission status
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
    
    /// Requests camera permission
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if granted {
                    self?.setupSession()
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Sets up the camera capture session
    private func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        // Get video device based on current camera preference
        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) ??
                AVCaptureDevice.default(for: .video) else {
            DispatchQueue.main.async {
                self.errorMessage = "Camera not available"
            }
            return
        }
        
        // Create video input
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                videoDeviceInput = videoInput
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Cannot add video input"
                }
                return
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error setting up camera: \(error.localizedDescription)"
            }
            return
        }
        
        // Create photo output
        let photoOutput = AVCapturePhotoOutput()
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "Cannot add photo output"
            }
            return
        }
        
        captureSession = session
    }
    
    /// Switch between front and back camera
    func switchCamera() {
        guard let session = captureSession, let currentInput = videoDeviceInput else { return }
        
        // Toggle camera
        isUsingFrontCamera.toggle()
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            
            session.beginConfiguration()
            session.removeInput(currentInput)
            
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
            } else {
                session.addInput(currentInput) // Restore original if failed
            }
            
            session.commitConfiguration()
        } catch {
            debugLog("Error switching camera: \(error)")
        }
    }
    
    /// Toggle flash mode
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    /// Starts the camera session
    func startSession() {
        guard hasPermission else {
            requestPermission()
            return
        }
        
        // Setup session if not already configured
        if captureSession == nil {
            setupSession()
        }
        
        guard let session = captureSession else {
            return
        }
        
        // Start session on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if !session.isRunning {
                session.startRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = true
                }
            }
        }
    }
    
    /// Stops the camera session
    func stopSession() {
        guard let session = captureSession else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if session.isRunning {
                session.stopRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = false
                }
            }
        }
    }
    
    // MARK: - Photo Capture
    
    /// Captures a photo
    func capturePhoto() {
        guard let photoOutput = photoOutput,
              let session = captureSession,
              session.isRunning else {
            return
        }
        
        // Configure photo settings
        let settings = AVCapturePhotoSettings()
        
        // Set flash mode based on user preference
        if photoOutput.supportedFlashModes.contains(.on) && isFlashOn {
            settings.flashMode = .on
        } else if photoOutput.supportedFlashModes.contains(.off) {
            settings.flashMode = .off
        }
        
        // Capture photo
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    /// Clears the captured image
    func clearCapturedImage() {
        capturedImage = nil
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraController: AVCapturePhotoCaptureDelegate {
    /// Called when photo capture is complete
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.errorMessage = "Error capturing photo: \(error.localizedDescription)"
            }
            return
        }
        
        // Extract image from photo
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.errorMessage = "Could not process photo"
            }
            return
        }
        
        // Update captured image on main thread
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
}

#Preview {
    CameraView(
        cameraController: CameraController(),
        onPhotoCaptured: { image in
            debugLog("Photo captured: \(image.size)")
        },
        onDismiss: {
            debugLog("Dismiss camera")
        }
    )
}
