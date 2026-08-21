import SwiftUI
import AppKit

public final class FloatingPanel: NSPanel, NSWindowDelegate {
    private var outsideClickMonitor: Any?
    
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
        SpeechService.shared.stop()
        self.orderOut(nil)
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        hidePanel()
    }
    
    public func showNearCursorOrCenter() {
        let mouseLoc = NSEvent.mouseLocation
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 320
        
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main {
            var x = mouseLoc.x + 10
            var y = mouseLoc.y - windowHeight - 10
            
            // Adjust if out of screen bounds
            let visibleFrame = screen.visibleFrame
            if x + windowWidth > visibleFrame.maxX {
                x = visibleFrame.maxX - windowWidth - 12
            }
            if x < visibleFrame.minX {
                x = visibleFrame.minX + 12
            }
            if y < visibleFrame.minY {
                y = mouseLoc.y + 20
            }
            if y + windowHeight > visibleFrame.maxY {
                y = visibleFrame.maxY - windowHeight - 12
            }
            
            self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        } else {
            self.center()
        }
        
        self.invalidateShadow()
        self.orderFrontRegardless()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Start monitoring clicks outside the panel
        startOutsideClickMonitor()
    }
    
    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        guard AppSettings.shared.clickOutsideDismiss else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
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
}
