import AppKit
import SwiftUI

/// Controller for the Floating Mini Drop Bubble on macOS screen
@MainActor
public final class FloatingHomeworkBubbleController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = FloatingHomeworkBubbleController()
    
    @Published public private(set) var isVisible: Bool = false
    
    private var panel: NSPanel?
    
    private override init() {
        super.init()
    }
    
    public func showBubble() {
        ContinuityHomeworkServer.shared.startServer()
        
        if panel == nil {
            let screen = NSScreen.main ?? NSScreen.screens.first
            let screenFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            
            let bubbleWidth: CGFloat = 160
            let bubbleHeight: CGFloat = 64
            let initialX = screenFrame.maxX - bubbleWidth - 30
            let initialY = screenFrame.maxY - bubbleHeight - 60
            
            let p = NSPanel(
                contentRect: NSRect(x: initialX, y: initialY, width: bubbleWidth, height: bubbleHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isMovableByWindowBackground = true
            p.isReleasedWhenClosed = false
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.delegate = self
            
            let bubbleView = FloatingHomeworkBubbleView(
                onExpand: { [weak self] in
                    self?.expandToStudio()
                },
                onClose: { [weak self] in
                    self?.hideBubble()
                }
            )
            
            p.contentView = NSHostingView(rootView: bubbleView)
            self.panel = p
        }
        
        guard let p = panel else { return }
        p.alphaValue = 0.0
        p.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().alphaValue = 1.0
        }
        
        isVisible = true
    }
    
    public func hideBubble() {
        guard let p = panel else { return }
        self.isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            p.animator().alphaValue = 0.0
        }, completionHandler: {
            Task { @MainActor in
                p.orderOut(nil)
            }
        })
    }
    
    public func toggleBubble() {
        if isVisible {
            hideBubble()
        } else {
            showBubble()
        }
    }
    
    public func expandToStudio() {
        hideBubble()
        ContinuityHomeworkWindowController.shared.showStudio()
    }
}
