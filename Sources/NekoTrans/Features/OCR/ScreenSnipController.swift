import AppKit
import SwiftUI
import Vision

@MainActor
final class SnipOverlayWindow: NSWindow {
    var onCancelAction: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            onCancelAction?()
            return
        }
        super.keyDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancelAction?()
    }
    
    
}


@MainActor
public final class ScreenSnipController: NSObject {
    public static let shared = ScreenSnipController()
    
    private var overlayWindows: [SnipOverlayWindow] = []
    private var onCompleteWithImage: ((String?, NSImage?) -> Void)?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    
    private override init() {
        super.init()
    }
    
    public func startSnip(completion: @escaping (String?) -> Void) {
        startSnipWithImage { text, _ in
            completion(text)
        }
    }
    
    public func startSnipWithImage(completion: @escaping (String?, NSImage?) -> Void) {
        closeOverlay()
        self.onCompleteWithImage = completion
        
        // Check/Request Screen Recording permission
        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                CGRequestScreenCaptureAccess()
            }
        }
        
        // Create full-screen transparent overlay for each active screen
        for screen in NSScreen.screens {
            let window = SnipOverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.onCancelAction = { [weak self] in
                self?.cancelSnip()
            }
            
            let snipView = ScreenSnipView(screen: screen) { [weak self] selectedScreen, viewRect in
                self?.handleSelection(screen: selectedScreen, viewRect: viewRect)
            } onCancel: { [weak self] in
                self?.cancelSnip()
            }
            
            window.contentView = NSHostingView(rootView: snipView)
            window.makeKeyAndOrderFront(nil)
            overlayWindows.append(window)
        }
        
        // Event monitors to guarantee ESC key interception globally & locally
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.cancelSnip()
                return nil
            }
            return event
        }
        
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                DispatchQueue.main.async {
                    self?.cancelSnip()
                }
            }
        }
        
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.crosshair.push()
    }
    
    public func cancelSnip() {
        closeOverlay()
        onCompleteWithImage?(nil, nil)
    }
    
    public func closeOverlay() {
        NSCursor.pop()
        
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        
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
            onCompleteWithImage?(nil, nil)
            return
        }

        // 3. Fast frame-buffer flush delay (0.04s) then capture via Apple native screencapture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("neko_snip_\(UUID().uuidString).png")
            
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
                        self?.onCompleteWithImage?(nil, nil)
                        return
                    }
                    
                    let text = await ScreenOCRService.shared.recognizeText(from: cgImage)
                    self?.onCompleteWithImage?(text, image)
                }
            }
            
            do {
                try process.run()
            } catch {
                self?.onCompleteWithImage?(nil, nil)
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
            // 1. Cutout Inverted Mask (38% darkness outside, 100% crystal-clear inside selection)
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.black.opacity(0.38)))
                if let rect = currentRect {
                    context.blendMode = .destinationOut
                    context.fill(Path(rect), with: .color(.white))
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // 2. Selection Rectangle & Framing Guides
            if let rect = currentRect {
                // High contrast selection border
                Path(rect)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                
                // Outer subtle blue accent ring
                Path(rect)
                    .stroke(Color.blue.opacity(0.6), lineWidth: 0.8)
                
                // CleanShot-style 4 Corner Brackets
                cornerBrackets(for: rect)
                
                // Dimension Badge
                dimensionBadge(for: rect)
            }
            
            // 3. Top Floating Instruction Pill
            VStack {
                HStack(spacing: 7) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan)
                    
                    Text("Kéo chọn vùng chữ để nhận diện & dịch")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("ESC hoặc Chuột phải để hủy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.82))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                .padding(.top, 36)
                
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
    
    // MARK: - 4 Corner Brackets (CleanShot Style)
    @ViewBuilder
    private func cornerBrackets(for rect: CGRect) -> some View {
        let bracketLen: CGFloat = 8
        let bracketWidth: CGFloat = 2.5
        let color = Color.cyan
        
        // Top-Left
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY + bracketLen))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + bracketLen, y: rect.minY))
        }.stroke(color, lineWidth: bracketWidth)
        
        // Top-Right
        Path { p in
            p.move(to: CGPoint(x: rect.maxX - bracketLen, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bracketLen))
        }.stroke(color, lineWidth: bracketWidth)
        
        // Bottom-Left
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY - bracketLen))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + bracketLen, y: rect.maxY))
        }.stroke(color, lineWidth: bracketWidth)
        
        // Bottom-Right
        Path { p in
            p.move(to: CGPoint(x: rect.maxX - bracketLen, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bracketLen))
        }.stroke(color, lineWidth: bracketWidth)
    }
    
    // MARK: - Dimension Indicator Badge
    @ViewBuilder
    private func dimensionBadge(for rect: CGRect) -> some View {
        VStack {
            Spacer()
                .frame(height: max(rect.minY - 24, 10))
            HStack {
                Spacer()
                    .frame(width: max(rect.minX, 10))
                Text("\(Int(rect.width)) × \(Int(rect.height)) px")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.6)
                    )
                Spacer()
            }
            Spacer()
        }
    }
}
