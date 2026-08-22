import SwiftUI
import AppKit

public final class FloatingPanel: NSPanel, NSWindowDelegate {
    private var outsideClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    public var onCopyRequested: (() -> Void)?
    public var onSpeakRequested: (() -> Void)?
    public var onBookmarkRequested: (() -> Void)?
    public var onOpenNotebookRequested: (() -> Void)?
    public var onOpenSettingsRequested: (() -> Void)?
    
    public init(contentRect: NSRect, backing: NSPanel.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backing,
            defer: flag
        )
        
        self.delegate = self
        self.isFloatingPanel = true
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public override func cancelOperation(_ sender: Any?) {
        hidePanel()
    }
    
    public func hidePanel() {
        stopOutsideClickMonitor()
        stopLocalKeyMonitor()
        SpeechService.shared.stop()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1.0
        })
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        hidePanel()
    }
    
    public func showNearCursorOrCenter() {
        let mouseLoc = NSEvent.mouseLocation
        let windowWidth: CGFloat = 455
        let windowHeight: CGFloat = 345
        
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main {
            var x = mouseLoc.x + 8
            var y = mouseLoc.y - windowHeight - 12
            
            let visibleFrame = screen.visibleFrame
            
            // Smart clamping so popup never clips out of screen bounds
            if x + windowWidth > visibleFrame.maxX - 16 {
                x = visibleFrame.maxX - windowWidth - 16
            }
            if x < visibleFrame.minX + 16 {
                x = visibleFrame.minX + 16
            }
            
            if y < visibleFrame.minY + 16 {
                // If bottom overflow, flip to above the cursor
                y = mouseLoc.y + 24
            }
            if y + windowHeight > visibleFrame.maxY - 16 {
                y = visibleFrame.maxY - windowHeight - 16
            }
            
            self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        } else {
            self.center()
        }
        
        self.alphaValue = 0.0
        self.invalidateShadow()
        self.orderFrontRegardless()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Smooth fade-in animation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }
        
        startOutsideClickMonitor()
        startLocalKeyMonitor()
    }
    
    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        guard AppSettings.shared.clickOutsideDismiss else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            guard AppSettings.shared.clickOutsideDismiss else { return }
            let clickLocation = NSEvent.mouseLocation
            if !NSMouseInRect(clickLocation, self.frame, false) {
                DispatchQueue.main.async {
                    self.hidePanel()
                }
            }
        }
    }
    
    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
    
    private func startLocalKeyMonitor() {
        stopLocalKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // ESC key -> Dismiss
            if event.keyCode == 53 {
                self.hidePanel()
                return nil
            }
            
            // Command key combinations
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "c":
                    self.onCopyRequested?()
                    return nil
                case "s":
                    self.onSpeakRequested?()
                    return nil
                case "b":
                    self.onBookmarkRequested?()
                    return nil
                case "v":
                    self.onOpenNotebookRequested?()
                    return nil
                case ",":
                    self.onOpenSettingsRequested?()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }
    
    private func stopLocalKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
    
    deinit {
        stopOutsideClickMonitor()
        stopLocalKeyMonitor()
    }
}
