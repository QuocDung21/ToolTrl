import AppKit
import SwiftUI
import Vision

@MainActor
public final class ScreenSnipController: NSObject {
    public static let shared = ScreenSnipController()
    
    private var overlayWindows: [NSWindow] = []
    private var onComplete: ((String?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    public func startSnip(completion: @escaping (String?) -> Void) {
        closeOverlay()
        self.onComplete = completion
        
        // Check/Request Screen Recording permission
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
            
            let snipView = ScreenSnipView(screen: screen) { [weak self] selectedScreen, viewRect in
                self?.handleSelection(screen: selectedScreen, viewRect: viewRect)
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
    
    private func handleSelection(screen: NSScreen, viewRect: CGRect) {
        // 1. Dismiss overlay IMMEDIATELY so screencapture captures raw clear screen
        closeOverlay()
        
        // 2. Calculate exact macOS WindowServer global crop coordinates
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let globalX = Int(screen.frame.origin.x + viewRect.origin.x)
        let globalY = Int(primaryHeight - (screen.frame.origin.y + screen.frame.height) + viewRect.origin.y)
        let width = Int(viewRect.width)
        let height = Int(viewRect.height)
        
        guard width > 10 && height > 10 else {
            onComplete?(nil)
            return
        }
        
        // 3. Small delay to ensure overlay window is completely vanished from frame buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tooltrl_crop_\(UUID().uuidString).png")
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", "-R\(globalX),\(globalY),\(width),\(height)", tempURL.path]
            
            process.terminationHandler = { proc in
                Task { @MainActor in
                    defer { try? FileManager.default.removeItem(at: tempURL) }
                    
                    guard proc.terminationStatus == 0,
                          FileManager.default.fileExists(atPath: tempURL.path),
                          let image = NSImage(contentsOf: tempURL),
                          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        self?.onComplete?(nil)
                        return
                    }
                    
                    let text = await ScreenOCRService.shared.recognizeText(from: cgImage)
                    self?.onComplete?(text)
                }
            }
            
            do {
                try process.run()
            } catch {
                self?.onComplete?(nil)
            }
        }
    }
}

// MARK: - Interactive Screen Snip SwiftUI View
struct ScreenSnipView: View {
    let screen: NSScreen
    let onSelection: (NSScreen, CGRect) -> Void
    let onCancel: () -> Void
    
    @State private var startPoint: CGPoint? = nil
    @State private var currentPoint: CGPoint? = nil
    
    var body: some View {
        ZStack {
            // Darkened Dim Background
            Color.black.opacity(0.2)
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
                }
                .onEnded { value in
                    if let rect = currentRect, rect.width > 8 && rect.height > 8 {
                        onSelection(screen, rect)
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
}
