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
    
    // MARK: - Constants
    
    /// Royal purple accent color
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraController: cameraController)
                .ignoresSafeArea()
            
            // UI overlay
            VStack {
                // Top bar with close button
                HStack {
                    Button {
                        cameraController.stopSession()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Capture button
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred()
                        cameraController.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .disabled(!cameraController.isSessionRunning)
                    
                    // Instructions
                    Text("Tap to capture")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 40)
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
            // Handle captured photo
            if let image = newValue {
                onPhotoCaptured(image)
                cameraController.clearCapturedImage()
            }
        }
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
        
        // Get video device (back camera preferred)
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ??
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
        // Use default settings - photos will be captured in the best available format
        let settings = AVCapturePhotoSettings()
        
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
            print("Photo captured: \(image.size)")
        },
        onDismiss: {
            print("Dismiss camera")
        }
    )
}
