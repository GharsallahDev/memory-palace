import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isScanning = true
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var torchOn = false
    @State private var hasPermission = false
    @State private var permissionDenied = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if permissionDenied {
                    PermissionDeniedView()
                } else if hasPermission {
                    ZStack {
                        QRCodeScannerView(
                            isScanning: $isScanning,
                            torchOn: $torchOn,
                            onResult: handleScanResult
                        )
                        
                        VStack {
                            VStack(spacing: Constants.UI.mediumSpacing) {
                                Text("Scan QR Code")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Point your camera at the QR code shown on the Memory Hub dashboard")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding(.top, 20)
                            
                            Spacer()
                            
                            ScanningFrame()
                            
                            Spacer()
                            
                            HStack(spacing: Constants.UI.extraLargeSpacing) {
                                Button(action: toggleTorch) {
                                    VStack(spacing: 8) {
                                        Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                            .font(.title2)
                                        
                                        Text(torchOn ? "Torch On" : "Torch Off")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                                
                                Button(action: rescan) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.title2)
                                        
                                        Text("Rescan")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.white)
                                }
                                .disabled(isScanning)
                            }
                            .padding(.bottom, 40)
                        }
                    }
                } else {
                    VStack(spacing: Constants.UI.mediumSpacing) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Requesting camera permission...")
                            .font(.body)
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("QR Scanner")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarHidden(false)
        .navigationBarColor(.clear)
        .onAppear {
            requestCameraPermission()
        }
        .alert("Scan Error", isPresented: $showingError) {
            Button("Try Again") {
                rescan()
            }
            Button("Cancel") {
                dismiss()
            }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        hasPermission = true
                    } else {
                        permissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }
    
    private func handleScanResult(_ result: Result<String, ScanError>) {
        switch result {
        case .success(let string):
            if isValidMemoryHubQR(string) {
                Haptics.shared.medium()
                onScan(string)
            } else {
                errorMessage = "Invalid QR code. Please scan the Memory Hub setup code."
                showingError = true
                isScanning = false
            }
            
        case .failure(let error):
            print("❌ QR scan failed: \(error)")
            errorMessage = error.localizedDescription
            showingError = true
            isScanning = false
        }
    }
    
    private func isValidMemoryHubQR(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let serverIP = json["serverIP"] as? String,
              let port = json["port"] as? Int,
              let authToken = json["authToken"] as? String else {
            return false
        }
        
        return !serverIP.isEmpty &&
               port > 0 && port < 65536 &&
               !authToken.isEmpty
    }
    
    private func toggleTorch() {
        torchOn.toggle()
        Haptics.shared.light()
    }
    
    private func rescan() {
        isScanning = true
        errorMessage = nil
        Haptics.shared.light()
    }
}

struct ScanningFrame: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 250, height: 250)
            
            VStack {
                HStack {
                    ScannerCorner()
                    Spacer()
                    ScannerCorner()
                        .rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    ScannerCorner()
                        .rotationEffect(.degrees(-90))
                    Spacer()
                    ScannerCorner()
                        .rotationEffect(.degrees(180))
                }
            }
            .frame(width: 250, height: 250)
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0), Color.blue, Color.blue.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 220, height: 2)
                .offset(y: animationOffset)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                    ) {
                        animationOffset = 100
                    }
                }
        }
    }
}

struct ScannerCorner: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.blue, lineWidth: 4)
        .frame(width: 20, height: 20)
    }
}

struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: Constants.UI.largeSpacing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: Constants.UI.mediumSpacing) {
                Text("Camera Permission Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("To scan QR codes, Memory Palace needs access to your camera. Please enable camera permission in Settings.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .buttonStyle(BorderedProminentButtonStyle())
        }
    }
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    @Binding var torchOn: Bool
    let onResult: (Result<String, ScanError>) -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        if isScanning {
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
        
        uiViewController.setTorch(torchOn)
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRCodeScannerView
        
        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func didScanQRCode(_ code: String) {
            parent.onResult(.success(code))
        }
        
        func didFailWithError(_ error: ScanError) {
            parent.onResult(.failure(error))
        }
    }
}

enum ScanError: LocalizedError {
    case cameraUnavailable
    case invalidCode
    case permissionDenied
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available"
        case .invalidCode:
            return "Invalid QR code format"
        case .permissionDenied:
            return "Camera permission denied"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

protocol QRScannerDelegate: AnyObject {
    func didScanQRCode(_ code: String)
    func didFailWithError(_ error: ScanError)
}

class QRScannerViewController: UIViewController {
    weak var delegate: QRScannerDelegate?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError(.cameraUnavailable)
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            delegate?.didFailWithError(.unknown(error))
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            delegate?.didFailWithError(.cameraUnavailable)
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didFailWithError(.cameraUnavailable)
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    func startScanning() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopScanning() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("❌ Failed to set torch: \(error)")
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            delegate?.didScanQRCode(stringValue)
        }
    }
}

extension View {
    func navigationBarColor(_ color: UIColor) -> some View {
        self.onAppear {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = color
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

struct QRScannerView_Previews: PreviewProvider {
    static var previews: some View {
        QRScannerView { code in
            print("Scanned: \(code)")
        }
    }
}
