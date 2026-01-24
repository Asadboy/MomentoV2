//
//  JoinEventSheet.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Join event component
//  This sheet provides multiple ways to join an event:
//  1. QR code scanning (primary, interactive method)
//  2. Code entry (alternative method)

import SwiftUI
import AVFoundation

/// Join methods available in the sheet
enum JoinMethod: String, CaseIterable {
    case qrCode = "QR Code"
    case enterCode = "Enter Code"
}

/// Sheet for joining events via QR code or code entry
struct JoinEventSheet: View {
    @Binding var isPresented: Bool
    let onJoin: (Event) -> Void  // Callback when an event is successfully joined
    
    // MARK: - State Management
    
    /// Supabase manager instance
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    /// Currently selected join method
    @State private var selectedMethod: JoinMethod = .qrCode
    
    /// Loading state for join attempt
    @State private var isJoining = false
    
    /// Code entry field for code-based joining
    @State private var enteredCode: String = ""

    /// Error message to display
    @State private var errorMessage: String?
    
    /// QR code scanner session
    @StateObject private var qrScanner = QRCodeScanner()
    
    // MARK: - Constants
    
    /// Royal purple accent color
    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Method selector tabs
                Picker("Join Method", selection: $selectedMethod) {
                    ForEach(JoinMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected method
                Group {
                    switch selectedMethod {
                    case .qrCode:
                        qrCodeView
                    case .enterCode:
                        codeEntryView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(
                // Dark background matching main view
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
            .navigationTitle("Join Event")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        qrScanner.stopScanning()
                        isPresented = false
                    }
                }
            }
            .onChange(of: selectedMethod) {
                // Stop scanning when switching methods
                if selectedMethod != .qrCode {
                    qrScanner.stopScanning()
                }
            }
            .onChange(of: qrScanner.scannedCode) {
                // Handle scanned QR code
                if let code = qrScanner.scannedCode {
                    handleQRCode(code)
                }
            }
        }
    }
    
    // MARK: - QR Code View
    
    /// QR code scanner view
    private var qrCodeView: some View {
        VStack(spacing: 24) {
            // Instructions
            VStack(spacing: 8) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(royalPurple)
                
                Text("Scan QR Code")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Point your camera at the event QR code")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Camera preview
            if qrScanner.hasPermission {
                QRCodeScannerView(scanner: qrScanner)
                    .frame(height: 300)
                    .cornerRadius(16)
                    .padding(.horizontal)
            } else {
                // Permission request view
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Camera Permission Required")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Please allow camera access to scan QR codes")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button("Request Permission") {
                        qrScanner.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(royalPurple)
                }
                .padding()
            }
            
            Spacer()
        }
        .onAppear {
            qrScanner.startScanning()
        }
        .onDisappear {
            qrScanner.stopScanning()
        }
    }
    
    // MARK: - Code Entry View
    
    /// Code entry view for manual code input
    private var codeEntryView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(royalPurple)

                Text("Enter Join Code")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Enter a code or paste an invite link")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                VerificationCodeInput(
                    code: $enteredCode,
                    maxLength: 8,
                    onComplete: {
                        handleCodeEntry()
                    }
                )
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Button {
                    handleCodeEntry()
                } label: {
                    if isJoining {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Look up event")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(royalPurple)
                .disabled(enteredCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining)
            }
            .padding(.horizontal)

            Spacer()
        }
    }
    
    // MARK: - Actions
    
    /// Handles QR code scanning result
    private func handleQRCode(_ code: String) {
        // Extract event code from QR code (format: "momento://join/CODE" or just "CODE")
        let code = extractCodeFromQR(code)
        joinEventWithCode(code)
    }
    
    /// Handles manual code entry (supports both raw codes and links)
    private func handleCodeEntry() {
        let input = enteredCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            errorMessage = "Please enter a code"
            return
        }

        // Smart parsing: detect if input is a link or raw code
        let code = extractCodeFromInput(input)
        guard !code.isEmpty else {
            errorMessage = "Could not find a valid code in the link"
            return
        }
        joinEventWithCode(code)
    }

    /// Extracts event code from any input format (link or raw code)
    private func extractCodeFromInput(_ input: String) -> String {
        // Handle momento://join/CODE format
        if input.lowercased().hasPrefix("momento://join/") {
            return String(input.dropFirst("momento://join/".count))
                .components(separatedBy: CharacterSet(charactersIn: "?/#"))
                .first?
                .uppercased() ?? input.uppercased()
        }
        // Handle https://momento.app/join/CODE format
        if input.contains("/join/") {
            if let code = input.components(separatedBy: "/join/").last?
                .components(separatedBy: CharacterSet(charactersIn: "?/#"))
                .first {
                return code.uppercased()
            }
        }
        // Assume it's just the code
        return input.uppercased()
    }

    /// Extracts event code from QR code string
    private func extractCodeFromQR(_ qrString: String) -> String {
        return extractCodeFromInput(qrString)
    }

    /// Attempts to join an event with the given code
    private func joinEventWithCode(_ code: String) {
        errorMessage = nil
        isJoining = true
        
        Task {
            do {
                let eventModel = try await supabaseManager.joinEvent(code: code)
                let joinedEvent = Event(fromSupabase: eventModel)
                
                await MainActor.run {
                    // Call the join callback
                    onJoin(joinedEvent)
                    
                    // Close the sheet
                    qrScanner.stopScanning()
                    isPresented = false
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to join event: \(error.localizedDescription)"
                    isJoining = false
                }
            }
        }
    }
}

// MARK: - QR Code Scanner

/// Observable object that manages QR code scanning
class QRCodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    @Published var hasPermission: Bool = false
    @Published var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        checkPermission()
    }
    
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
                    self?.startScanning()
                }
            }
        }
    }
    
    /// Starts QR code scanning
    func startScanning() {
        guard hasPermission else {
            requestPermission()
            return
        }
        
        // Reset scanned code
        scannedCode = nil
        
        // Don't start if already running
        guard captureSession == nil else {
            return
        }
        
        // Setup capture session
        let session = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
        
        captureSession = session
        
        // Start on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    /// Stops QR code scanning
    func stopScanning() {
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    /// Called when a QR code is detected
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue else {
            return
        }
        
        // Only process if we haven't already scanned this code
        if scannedCode != code {
            scannedCode = code
        }
    }
}

/// Custom UIView that properly handles preview layer layout
class QRPreviewView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

/// SwiftUI view wrapper for QR code scanner
struct QRCodeScannerView: UIViewRepresentable {
    @ObservedObject var scanner: QRCodeScanner

    func makeUIView(context: Context) -> QRPreviewView {
        let view = QRPreviewView()
        if let session = scanner.captureSession {
            view.previewLayer.session = session
        }
        return view
    }

    func updateUIView(_ uiView: QRPreviewView, context: Context) {
        // Connect session when it becomes available
        if uiView.previewLayer.session == nil, let session = scanner.captureSession {
            uiView.previewLayer.session = session
        }
    }
}

#Preview {
    JoinEventSheet(isPresented: .constant(true)) { event in
        print("Joined event: \(event.title)")
    }
}
