import SwiftUI
import AVFoundation

#if canImport(UIKit)
import UIKit

public struct QRCodeScannerView: UIViewControllerRepresentable {
    public var onScanResult: (String) -> Void
    public var onDismiss: (() -> Void)? = nil
    
    public init(onScanResult: @escaping (String) -> Void, onDismiss: (() -> Void)? = nil) {
        self.onScanResult = onScanResult
        self.onDismiss = onDismiss
    }
    
    public func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public class Coordinator: NSObject, ScannerViewControllerDelegate {
        let parent: QRCodeScannerView
        
        init(parent: QRCodeScannerView) {
            self.parent = parent
        }
        
        func didFindCode(_ code: String) {
            parent.onScanResult(code)
        }
        
        func didCancel() {
            parent.onDismiss?()
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didFindCode(_ code: String)
    func didCancel()
}

public class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned: Bool = false
    
    private let statusLabel = UILabel()
    private let overlayBox = UIView()
    private let scanLine = UIView()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlayUI()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
        startScanLineAnimation()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showFallbackMessage("Không tìm thấy Camera trên thiết bị này (Simulator)")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            showFallbackMessage("Không thể truy cập camera: \(error.localizedDescription)")
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            showFallbackMessage("Không thể cấu hình camera")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showFallbackMessage("Không thể nhận diện mã QR")
            return
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func setupOverlayUI() {
        // Scanning Box Guide
        overlayBox.translatesAutoresizingMaskIntoConstraints = false
        overlayBox.layer.borderColor = UIColor.systemBlue.cgColor
        overlayBox.layer.borderWidth = 2.5
        overlayBox.layer.cornerRadius = 16
        overlayBox.backgroundColor = UIColor.clear
        view.addSubview(overlayBox)
        
        // Scan Line
        scanLine.translatesAutoresizingMaskIntoConstraints = false
        scanLine.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        scanLine.layer.cornerRadius = 1
        overlayBox.addSubview(scanLine)
        
        // Instruction Label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Hướng camera vào mã QR trên màn hình Mac"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.layer.shadowColor = UIColor.black.cgColor
        statusLabel.layer.shadowRadius = 4
        statusLabel.layer.shadowOpacity = 0.8
        statusLabel.layer.shadowOffset = .zero
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            overlayBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlayBox.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            overlayBox.widthAnchor.constraint(equalToConstant: 260),
            overlayBox.heightAnchor.constraint(equalToConstant: 260),
            
            scanLine.leadingAnchor.constraint(equalTo: overlayBox.leadingAnchor, constant: 10),
            scanLine.trailingAnchor.constraint(equalTo: overlayBox.trailingAnchor, constant: -10),
            scanLine.heightAnchor.constraint(equalToConstant: 2.5),
            scanLine.topAnchor.constraint(equalTo: overlayBox.topAnchor, constant: 10),
            
            statusLabel.topAnchor.constraint(equalTo: overlayBox.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func startScanLineAnimation() {
        UIView.animate(withDuration: 1.6, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut], animations: {
            self.scanLine.transform = CGAffineTransform(translationX: 0, y: 236)
        }, completion: nil)
    }
    
    private func showFallbackMessage(_ msg: String) {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = msg
        statusLabel.textColor = .systemGray
        statusLabel.font = .systemFont(ofSize: 15)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned, let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }
        
        hasScanned = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        captureSession?.stopRunning()
        delegate?.didFindCode(stringValue)
    }
}
#endif
