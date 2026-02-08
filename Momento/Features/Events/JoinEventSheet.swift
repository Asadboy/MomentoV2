//
//  JoinEventSheet.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Join event component
//  Unified join experience: QR scanning with inline code entry fallback

import SwiftUI
import AVFoundation

/// Sheet for joining events - mutually exclusive scan/code modes
struct JoinEventSheet: View {
    @Binding var isPresented: Bool
    let onJoin: (Event) -> Void

    // MARK: - State

    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var qrScanner = QRCodeScanner()

    @State private var enteredCode: String = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var clipboardCode: String?
    @State private var showClipboardBanner = false
    @State private var previewEvent: Event?
    @State private var showPreview = false
    @State private var mode: JoinMode = .scan
    @State private var buttonPressed = false

    enum JoinMode {
        case scan
        case code
    }

    // MARK: - Colors

    private var royalPurple: Color {
        Color(red: 0.5, green: 0.0, blue: 0.8)
    }

    private var cardBackground: Color {
        Color(red: 0.12, green: 0.1, blue: 0.16)
    }

    // MARK: - Computed

    private var codeProgress: CGFloat {
        CGFloat(enteredCode.count) / 6.0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.05, green: 0.05, blue: 0.1)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Static subheader - one calm anchor
                    subheader

                    // Mutually exclusive modes
                    if mode == .scan {
                        scanModeView
                            .transition(.opacity)
                    } else {
                        codeModeView
                            .transition(.opacity)
                    }
                }
            }
            .navigationTitle("Join Momento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        qrScanner.stopScanning()
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .onChange(of: qrScanner.scannedCode) {
                if let code = qrScanner.scannedCode {
                    handleQRCode(code)
                }
            }
            .onChange(of: enteredCode) { oldValue, newValue in
                // Haptic tick on each character entered
                if newValue.count > oldValue.count {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
            .onChange(of: mode) { _, newMode in
                if newMode == .scan {
                    qrScanner.startScanning()
                } else {
                    qrScanner.stopScanning()
                }
            }
            .overlay {
                if showPreview, let event = previewEvent {
                    previewOverlay(event: event)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: mode)
            .animation(.easeInOut(duration: 0.25), value: showPreview)
        }
        .onAppear {
            qrScanner.startScanning()
            checkClipboard()
        }
    }

    // MARK: - Subheader

    private var subheader: some View {
        Text("Private event")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.gray)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    // MARK: - Scan Mode (Full Screen)

    private var scanModeView: some View {
        VStack(spacing: 0) {
            if qrScanner.hasPermission {
                // Camera with soft, ambient treatment
                ZStack {
                    QRCodeScannerView(scanner: qrScanner)
                        .cornerRadius(28)

                    // Heavy blur outside scan zone - casual, not precise
                    cameraBlurOverlay

                    // Soft rounded scan hint - no sharp corners
                    scanningFrameOverlay
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Switch to code mode
                switchToCodeButton
                    .padding(.bottom, 24)
            } else {
                cameraPermissionView
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer()

                switchToCodeButton
                    .padding(.bottom, 24)
            }
        }
    }

    /// Blur overlay outside scan zone - makes scanning feel casual
    private var cameraBlurOverlay: some View {
        ZStack {
            // Dark blur around edges
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.black.opacity(0.5))
                .blur(radius: 0.5)
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .frame(width: 140, height: 140)
                                .blendMode(.destinationOut)
                        )
                )

            // Soft inner glow on scan zone
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 30)
                .frame(width: 140, height: 140)
                .blur(radius: 16)
        }
        .allowsHitTesting(false)
    }

    private var scanningFrameOverlay: some View {
        // Soft rounded square - smaller, contained
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
            .frame(width: 130, height: 130)
    }

    private var switchToCodeButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                mode = .code
            }
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(royalPurple.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "number")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(royalPurple.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Enter invite code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                    Text("Got a code from a friend?")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground.opacity(0.8))
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    )
            )
        }
        .padding(.horizontal, 24)
    }

    private var cameraPermissionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundColor(royalPurple.opacity(0.5))

            VStack(spacing: 6) {
                Text("Camera access needed")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Text("To scan QR codes")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            Button {
                qrScanner.requestPermission()
            } label: {
                Text("Enable Camera")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(royalPurple)
                    .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
    }

    // MARK: - Code Mode (Full Screen)

    private var codeModeView: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 32)

            // Clipboard banner at top if available
            clipboardBanner
                .padding(.horizontal, 24)
                .padding(.bottom, showClipboardBanner ? 24 : 0)

            // Code input area - centered and calm
            VStack(spacing: 28) {
                // Code input with subtle glow when active
                VerificationCodeInput(
                    code: $enteredCode,
                    maxLength: 6,
                    onComplete: {
                        handleCodeEntry()
                    }
                )
                .padding(.horizontal, 16)

                // Error message
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 12))
                        Text(error)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.red.opacity(0.8))
                }

                // CTA with progressive states
                joinButton
            }
            .padding(.horizontal, 24)

            Spacer()

            // Switch back to scan - matching brand language
            switchToScanButton
                .padding(.bottom, 24)
        }
    }

    private var switchToScanButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                mode = .scan
            }
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 15))
                    .foregroundColor(royalPurple.opacity(0.8))

                Text("Scan invite instead")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(cardBackground.opacity(0.6))
            )
        }
    }

    private var joinButton: some View {
        let hasCode = !enteredCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isComplete = enteredCode.count == 6
        let canJoin = isComplete && !isJoining

        return Button {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            handleCodeEntry()
        } label: {
            HStack(spacing: 10) {
                if isJoining {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text(isComplete ? "Preview" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                ZStack {
                    if canJoin {
                        // Ready state - stronger purple
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.0, blue: 0.9),
                                Color(red: 0.6, green: 0.15, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else if hasCode {
                        // Partial state - slight lift
                        royalPurple.opacity(0.35 + (codeProgress * 0.25))
                    } else {
                        // Empty state - dormant
                        Color.white.opacity(0.06)
                    }
                }
            )
            .foregroundColor(hasCode ? .white : .white.opacity(0.3))
            .cornerRadius(16)
            .shadow(color: canJoin ? royalPurple.opacity(0.45) : .clear, radius: 20, y: 8)
            .scaleEffect(buttonPressed ? 0.98 : (canJoin ? 1.0 : 0.99))
            .offset(y: hasCode && !isComplete ? -1 : 0)
        }
        .disabled(!hasCode || isJoining)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in buttonPressed = true }
                .onEnded { _ in buttonPressed = false }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasCode)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isComplete)
        .animation(.spring(response: 0.1, dampingFraction: 0.8), value: buttonPressed)
    }

    @ViewBuilder
    private var clipboardBanner: some View {
        if showClipboardBanner, let code = clipboardCode {
            Button {
                enteredCode = code
                showClipboardBanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handleCodeEntry()
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    // "Invite found" label
                    Text("Invite found")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(royalPurple.opacity(0.8))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundColor(royalPurple)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paste invite")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            Text(code)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(royalPurple)
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(royalPurple)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(royalPurple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(royalPurple.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: royalPurple.opacity(0.15), radius: 12, y: 4)
                )
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                removal: .opacity
            ))
        }
    }

    // MARK: - Preview Overlay

    private func previewOverlay(event: Event) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    showPreview = false
                }

            EventPreviewModal(
                event: event,
                onJoin: { confirmJoin() },
                onCancel: {
                    showPreview = false
                    previewEvent = nil
                }
            )
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    /// Check clipboard for valid join code or link
    private func checkClipboard() {
        guard let clipboardString = UIPasteboard.general.string else {
            showClipboardBanner = false
            return
        }

        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's a momento link
        if trimmed.lowercased().contains("momento") && trimmed.contains("/join/") {
            let code = extractCodeFromInput(trimmed)
            if code.count == 6 {
                clipboardCode = code
                showClipboardBanner = true
                // Switch to code mode when clipboard has a code
                withAnimation {
                    mode = .code
                }
                return
            }
        }

        // Check if it's a raw code (alphanumeric, exactly 6 chars)
        let alphanumeric = trimmed.filter { $0.isLetter || $0.isNumber }
        if alphanumeric.count == 6 && alphanumeric.count == trimmed.count {
            clipboardCode = alphanumeric.uppercased()
            showClipboardBanner = true
            // Switch to code mode when clipboard has a code
            withAnimation {
                mode = .code
            }
            return
        }

        showClipboardBanner = false
    }

    /// Handles QR code scanning result
    private func handleQRCode(_ code: String) {
        let extractedCode = extractCodeFromQR(code)
        lookupAndPreviewEvent(code: extractedCode)
    }

    /// Handles manual code entry (supports both raw codes and links)
    private func handleCodeEntry() {
        let input = enteredCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            errorMessage = "Please enter a code"
            return
        }

        let code = extractCodeFromInput(input)
        guard !code.isEmpty else {
            errorMessage = "Could not find a valid code in the link"
            return
        }
        lookupAndPreviewEvent(code: code)
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

    /// Looks up event and shows preview modal
    private func lookupAndPreviewEvent(code: String) {
        guard !isJoining else { return }
        errorMessage = nil
        isJoining = true

        Task {
            do {
                let eventModel = try await supabaseManager.lookupEvent(code: code)
                let event = Event(fromSupabase: eventModel)

                await MainActor.run {
                    previewEvent = event
                    showPreview = true
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "No event found with that code"
                    isJoining = false
                }
            }
        }
    }

    /// Confirms joining the previewed event
    private func confirmJoin() {
        guard let event = previewEvent, let joinCode = event.joinCode else { return }

        Task {
            do {
                let eventModel = try await supabaseManager.joinEvent(code: joinCode)
                let joinedEvent = Event(fromSupabase: eventModel)

                await MainActor.run {
                    onJoin(joinedEvent)
                    qrScanner.stopScanning()
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    showPreview = false
                    previewEvent = nil
                    errorMessage = "Failed to join: \(error.localizedDescription)"
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

// MARK: - Helper Views

/// Corner bracket shape for QR scanner frame
struct CornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = min(rect.width, rect.height) * 0.6

        // Vertical line
        path.move(to: CGPoint(x: 0, y: length))
        path.addLine(to: CGPoint(x: 0, y: 4))

        // Corner curve
        path.addQuadCurve(
            to: CGPoint(x: 4, y: 0),
            control: CGPoint(x: 0, y: 0)
        )

        // Horizontal line
        path.addLine(to: CGPoint(x: length, y: 0))

        return path
    }
}

#Preview {
    JoinEventSheet(isPresented: .constant(true)) { event in
        debugLog("Joined event: \(event.name)")
    }
}
