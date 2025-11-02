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
//  3. Link handling (alternative method)

import SwiftUI
import AVFoundation

/// Join methods available in the sheet
enum JoinMethod: String, CaseIterable {
    case qrCode = "QR Code"
    case code = "Code"
    case link = "Link"
}

/// Sheet for joining events via QR code, code, or link
struct JoinEventSheet: View {
    @Binding var isPresented: Bool
    let onJoin: (Event) -> Void  // Callback when an event is successfully joined
    
    // MARK: - State Management
    
    /// Currently selected join method
    @State private var selectedMethod: JoinMethod = .qrCode
    
    /// Code entry field for code-based joining
    @State private var enteredCode: String = ""
    
    /// Link entry field for link-based joining
    @State private var enteredLink: String = ""
    
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
                    case .code:
                        codeEntryView
                    case .link:
                        linkEntryView
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
            .onChange(of: selectedMethod) { _ in
                // Stop scanning when switching methods
                if selectedMethod != .qrCode {
                    qrScanner.stopScanning()
                }
            }
            .onChange(of: qrScanner.scannedCode) { code in
                // Handle scanned QR code
                if let code = code {
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
                
                Text("Ask the event host for the join code")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                TextField("Enter code", text: $enteredCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
                    .submitLabel(.go)
                    .onSubmit {
                        handleCodeEntry()
                    }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button("Join Event") {
                    handleCodeEntry()
                }
                .buttonStyle(.borderedProminent)
                .tint(royalPurple)
                .disabled(enteredCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Link Entry View
    
    /// Link entry view for URL-based joining
    private var linkEntryView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(royalPurple)
                
                Text("Enter Event Link")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Paste the event link shared by the host")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                TextField("Enter link", text: $enteredLink)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal)
                    .submitLabel(.go)
                    .onSubmit {
                        handleLinkEntry()
                    }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button("Join Event") {
                    handleLinkEntry()
                }
                .buttonStyle(.borderedProminent)
                .tint(royalPurple)
                .disabled(enteredLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
    
    /// Handles manual code entry
    private func handleCodeEntry() {
        let trimmedCode = enteredCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedCode.isEmpty else {
            errorMessage = "Please enter a code"
            return
        }
        joinEventWithCode(trimmedCode)
    }
    
    /// Handles link entry
    private func handleLinkEntry() {
        let trimmedLink = enteredLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else {
            errorMessage = "Please enter a link"
            return
        }
        
        // Extract code from link (format: "momento://join/CODE" or "https://momento.app/join/CODE")
        let code = extractCodeFromLink(trimmedLink)
        joinEventWithCode(code)
    }
    
    /// Extracts event code from QR code string
    private func extractCodeFromQR(_ qrString: String) -> String {
        // Handle momento://join/CODE format
        if qrString.hasPrefix("momento://join/") {
            return String(qrString.dropFirst("momento://join/".count)).uppercased()
        }
        // Handle https://momento.app/join/CODE format
        if qrString.contains("/join/") {
            if let code = qrString.components(separatedBy: "/join/").last?.components(separatedBy: "/").first {
                return code.uppercased()
            }
        }
        // Assume it's just the code
        return qrString.uppercased()
    }
    
    /// Extracts event code from link string
    private func extractCodeFromLink(_ link: String) -> String {
        // Handle momento://join/CODE format
        if link.hasPrefix("momento://join/") {
            return String(link.dropFirst("momento://join/".count)).uppercased()
        }
        // Handle https://momento.app/join/CODE format
        if link.contains("/join/") {
            if let code = link.components(separatedBy: "/join/").last?.components(separatedBy: "/").first {
                return code.uppercased()
            }
        }
        // Assume it's just the code
        return link.uppercased()
    }
    
    /// Attempts to join an event with the given code
    private func joinEventWithCode(_ code: String) {
        errorMessage = nil
        
        // UI-only: Generate a fake event for demonstration
        // In production, this would make an API call to validate and fetch the event
        let joinedEvent = Event(
            title: "Joined Event (\(code))",
            coverEmoji: "??",
            releaseAt: Date().addingTimeInterval(24 * 3600), // 24 hours from now
            memberCount: Int.random(in: 5...30),
            photosTaken: 0,
            joinCode: code
        )
        
        // Call the join callback
        onJoin(joinedEvent)
        
        // Close the sheet
        qrScanner.stopScanning()
        isPresented = false
    }
}

// MARK: - QR Code Scanner

/// Observable object that manages QR code scanning
class QRCodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?
    @Published var hasPermission: Bool = false
    
    var captureSession: AVCaptureSession?
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

/// SwiftUI view wrapper for QR code scanner
struct QRCodeScannerView: UIViewRepresentable {
    let scanner: QRCodeScanner
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Create preview layer
        let previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill
        
        // Store reference to preview layer
        context.coordinator.previewLayer = previewLayer
        context.coordinator.parentView = view
        
        // Add preview layer to view
        view.layer.addSublayer(previewLayer)
        
        // Setup session when available
        if let session = scanner.captureSession {
            previewLayer.session = session
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
            
            // Setup session if not already set
            if previewLayer.session == nil, let session = scanner.captureSession {
                previewLayer.session = session
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
        var parentView: UIView?
    }
}

#Preview {
    JoinEventSheet(isPresented: .constant(true)) { event in
        print("Joined event: \(event.title)")
    }
}
