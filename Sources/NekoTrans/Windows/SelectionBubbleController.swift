import AppKit
import SwiftUI

// MARK: - Mini Selection Bubble SwiftUI View
public struct SelectionBubbleView: View {
    let onClick: () -> Void
    @State private var isHovered: Bool = false
    
    public init(onClick: @escaping () -> Void) {
        self.onClick = onClick
    }
    
    public var body: some View {
        Button(action: onClick) {
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 18)
                
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.88))
                
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isHovered ? Color.blue : Color.primary.opacity(0.85))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isHovered ? Color.blue.opacity(0.7) : Color.primary.opacity(0.18), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.35 : 0.2), radius: isHovered ? 6 : 4, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.15 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Optimized Selection Bubble Controller (Anti-Spam & Intent Filter)
@MainActor
public final class SelectionBubbleController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = SelectionBubbleController()
    
    public private(set) var bubblePanel: NSPanel?
    private var globalMouseUpMonitor: Any?
    private var globalMouseDownMonitor: Any?
    private var globalScrollMonitor: Any?
    
    private var mouseDownLocation: NSPoint = .zero
    private var mouseDownTime: Date = .distantPast
    
    private var currentSelectedText: String = ""
    private var autoDismissTimer: Timer?
    private var mouseUpWorkItem: DispatchWorkItem?
    
    public var onBubbleClicked: ((String, NSRect?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    public func startMonitoring() {
        stopMonitoring()
        guard AppSettings.shared.isSelectionBubbleActive else { return }
        
        // 1. Mouse Down: Track start location & dismiss active bubble on click outside
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseDown(event: event)
            }
        }
        
        // 2. Mouse Up: Evaluate drag distance or multi-click intent
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseUp(event: event)
            }
        }
        
        // 3. Scroll Wheel: Auto-dismiss when user scrolls the page
        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] _ in
            Task { @MainActor in
                self?.hideBubble()
            }
        }
    }
    
    public func stopMonitoring() {
        mouseUpWorkItem?.cancel()
        mouseUpWorkItem = nil
        
        if let gDown = globalMouseDownMonitor {
            NSEvent.removeMonitor(gDown)
            globalMouseDownMonitor = nil
        }
        if let gUp = globalMouseUpMonitor {
            NSEvent.removeMonitor(gUp)
            globalMouseUpMonitor = nil
        }
        if let gScroll = globalScrollMonitor {
            NSEvent.removeMonitor(gScroll)
            globalScrollMonitor = nil
        }
        hideBubble()
    }
    
    // MARK: - Mouse Event Handlers
    private func handleMouseDown(event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        mouseDownTime = Date()
        
        // Dismiss bubble if clicking anywhere outside the bubble
        if let panel = bubblePanel, panel.isVisible {
            if !panel.frame.contains(mouseDownLocation) {
                hideBubble()
            }
        }
    }
    
    private func handleMouseUp(event: NSEvent) {
        guard AppSettings.shared.isSelectionBubbleActive else { return }
        
        let mouseUpLocation = NSEvent.mouseLocation
        
        // 1. ⚡ ANTI-SPAM & INTENT FILTER: Check drag distance or multi-click FIRST
        // This eliminates 98% of normal clicks from doing any further window checking or IPC calls
        let dragDistance = hypot(mouseUpLocation.x - mouseDownLocation.x, mouseUpLocation.y - mouseDownLocation.y)
        let clickCount = event.clickCount
        let isIntentionalSelection = (clickCount >= 2) || (dragDistance >= 10.0)
        
        guard isIntentionalSelection else {
            // Normal stationary single-click: dismiss bubble and do NOT trigger any lookup!
            hideBubble()
            return
        }
        
        // 2. Ignore if click is inside any NekoTrans window (FloatingPanel, Bubble, Settings, etc.)
        for window in NSApp.windows where window.isVisible {
            if window.frame.contains(mouseUpLocation) {
                return
            }
        }
        
        // 3. Excluded App check (Silent Mode via zero-IPC cached lookup)
        if AppExclusionService.shared.isCurrentAppExcluded() {
            hideBubble()
            return
        }
        
        // 3. Cancel any pending check (trailing debounce)
        mouseUpWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard AppSettings.shared.isSelectionBubbleActive else { return }
                
                // Do not show bubble if main floating panel is already visible
                if AppDelegate.shared?.floatingPanel?.isVisible == true {
                    return
                }
                
                // Non-invasive extraction: Browser JavaScript (if browser) + Accessibility API (all apps)
                var text = await TextGrabber.shared.getSelectedTextNonInvasive()
                
                // Micro-OCR fallback for canvas/graphic apps (Figma, Canva, games, etc.)
                if text == nil || text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                    if dragDistance >= 15.0 {
                        text = await ScreenOCRService.shared.recognizeMicroRegion(from: self.mouseDownLocation, to: mouseUpLocation)
                    }
                }
                
                guard let selected = text?.trimmingCharacters(in: .whitespacesAndNewlines), !selected.isEmpty else {
                    self.hideBubble()
                    return
                }
                
                // Must contain at least one alphanumeric letter
                guard selected.contains(where: { $0.isLetter || $0.isNumber }) else {
                    self.hideBubble()
                    return
                }
                
                // Ignore single character punctuation/spaces
                if selected.count == 1 && (selected.first?.isWhitespace == true || selected.first?.isPunctuation == true) {
                    self.hideBubble()
                    return
                }
                
                // If bubble is already showing this exact text at this location, do not bounce
                if self.bubblePanel?.isVisible == true && self.currentSelectedText == selected {
                    return
                }
                
                self.showBubble(for: selected, at: mouseUpLocation)
            }
        }
        
        self.mouseUpWorkItem = workItem
        // 180ms debounce: Wait for gesture completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }
    
    // MARK: - Show & Hide Bubble
    public func showBubble(for text: String, at location: NSPoint? = nil) {
        self.currentSelectedText = text
        
        if bubblePanel == nil {
            setupPanel()
        }
        
        guard let panel = bubblePanel else { return }
        
        let mouseLoc = location ?? NSEvent.mouseLocation
        let bubbleSize: CGFloat = 36
        var targetX = mouseLoc.x + 10
        var targetY = mouseLoc.y + 12
        
        // Screen bounds safety clamping
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            if targetX + bubbleSize > screenFrame.maxX - 10 {
                targetX = mouseLoc.x - bubbleSize - 10
            }
            if targetY + bubbleSize > screenFrame.maxY - 10 {
                targetY = mouseLoc.y - bubbleSize - 10
            }
            if targetX < screenFrame.minX + 10 { targetX = screenFrame.minX + 10 }
            if targetY < screenFrame.minY + 10 { targetY = screenFrame.minY + 10 }
        }
        
        panel.setFrame(NSRect(x: targetX, y: targetY, width: bubbleSize, height: bubbleSize), display: true)
        
        if !panel.isVisible || panel.alphaValue < 0.5 {
            panel.alphaValue = 0.0
            panel.contentView?.wantsLayer = true
            
            if let layer = panel.contentView?.layer {
                let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
                scaleAnim.values = [0.82, 1.06, 1.0]
                scaleAnim.keyTimes = [0.0, 0.65, 1.0]
                scaleAnim.duration = 0.16
                scaleAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                layer.add(scaleAnim, forKey: "bubblePop")
            }
            
            panel.orderFrontRegardless()
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                panel.animator().alphaValue = 1.0
            }
        }
        
        // Auto-dismiss after 3.5 seconds if user ignores the bubble
        autoDismissTimer?.invalidate()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideBubble()
            }
        }
    }
    
    public func hideBubble() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        mouseUpWorkItem?.cancel()
        currentSelectedText = ""
        
        guard let panel = bubblePanel, panel.isVisible else { return }
        
        if let layer = panel.contentView?.layer {
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 1.0
            scaleAnim.toValue = 0.88
            scaleAnim.duration = 0.08
            scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
            layer.add(scaleAnim, forKey: "bubbleShrink")
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1.0
            panel.contentView?.layer?.removeAllAnimations()
        })
    }
    
    private func setupPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.delegate = self
        
        let bubbleView = SelectionBubbleView(
            onClick: { [weak self] in
                guard let self = self else { return }
                self.mouseUpWorkItem?.cancel()
                let textToTranslate = self.currentSelectedText
                let frame = self.bubblePanel?.frame
                self.hideBubble()
                
                guard !textToTranslate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                
                if let callback = self.onBubbleClicked {
                    callback(textToTranslate, frame)
                } else {
                    AppDelegate.shared?.triggerTranslationWithText(textToTranslate, nearRect: frame)
                }
            }
        )
        
        p.contentView = NSHostingView(rootView: bubbleView)
        self.bubblePanel = p
    }
}
