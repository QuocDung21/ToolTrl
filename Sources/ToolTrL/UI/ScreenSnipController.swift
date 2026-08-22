import AppKit
import SwiftUI
import Vision
@preconcurrency import ScreenCaptureKit

@MainActor
public final class ScreenSnipController: NSObject {
    public static let shared = ScreenSnipController()
    
    private var overlayWindows: [NSWindow] = []
    private var onComplete: ((String?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    public func startSnip(completion: @escaping (String?) -> Void) {
        // Dismiss any existing overlays
        closeOverlay()
        self.onComplete = completion
        
        // Request Screen Recording permission if needed
        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                CGRequestScreenCaptureAccess()
            }
        }
        
        // Create full-screen transparent overlay for each active screen
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let snipView = ScreenSnipView(screenFrame: screen.frame) { [weak self] capturedImage in
                self?.closeOverlay()
                guard let image = capturedImage else {
                    self?.onComplete?(nil)
                    return
                }
                
                Task {
                    let text = await ScreenOCRService.shared.recognizeText(from: image)
                    self?.onComplete?(text)
                }
            } onCancel: { [weak self] in
                self?.closeOverlay()
                self?.onComplete?(nil)
            }
            
            window.contentView = NSHostingView(rootView: snipView)
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }
        
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()
    }
    
    public func closeOverlay() {
        NSCursor.pop()
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
}

// MARK: - Interactive Screen Snip SwiftUI View
struct ScreenSnipView: View {
    let screenFrame: NSRect
    let onCapture: (CGImage?) -> Void
    let onCancel: () -> Void
    
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    @State private var isDragging: Bool = false
    
    var body: some View {
        ZStack {
            // Darkened Dim Background
            Color.black.opacity(0.22)
                .edgesIgnoringSafeArea(.all)
            
            // Selection Rectangle Cutout
            if let rect = currentRect {
                // Border & Dimension Badge
                Path(rect)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                
                VStack {
                    Spacer()
                        .frame(height: max(rect.minY - 26, 10))
                    HStack {
                        Spacer()
                            .frame(width: rect.minX)
                        Text("\(Int(rect.width)) × \(Int(rect.height)) px")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Instruction Hint at the top center
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .foregroundColor(.yellow)
                    Text("Kéo chuột chọn vùng chữ để nhận diện & dịch • Nhấn ESC để hủy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.75))
                .clipShape(Capsule())
                .padding(.top, 40)
                
                Spacer()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if startPoint == nil {
                        startPoint = value.startLocation
                    }
                    currentPoint = value.location
                    isDragging = true
                }
                .onEnded { value in
                    if let rect = currentRect, rect.width > 10 && rect.height > 10 {
                        captureRegion(rect)
                    } else {
                        onCancel()
                    }
                }
        )
        .onExitCommand {
            onCancel()
        }
    }
    
    private var currentRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    private func captureRegion(_ viewRect: CGRect) {
        let screenX = Int(screenFrame.origin.x + viewRect.origin.x)
        let screenY = Int(screenFrame.origin.y + viewRect.origin.y)
        let width = Int(viewRect.width)
        let height = Int(viewRect.height)
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tooltrl_crop_\(UUID().uuidString).png")
        
        // Use macOS native screencapture CLI with exact crop rectangle coordinates
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-R\(screenX),\(screenY),\(width),\(height)", tempURL.path]
        
        process.terminationHandler = { proc in
            Task { @MainActor in
                defer { try? FileManager.default.removeItem(at: tempURL) }
                
                guard proc.terminationStatus == 0,
                      FileManager.default.fileExists(atPath: tempURL.path),
                      let image = NSImage(contentsOf: tempURL),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    onCancel()
                    return
                }
                onCapture(cgImage)
            }
        }
        
        do {
            try process.run()
        } catch {
            onCancel()
        }
    }
}
