import AppKit
import SwiftUI

@MainActor
public final class QuickAIWindowController: NSObject, NSWindowDelegate {
    public static let shared = QuickAIWindowController()
    
    private var window: NSWindow?
    private var localKeyMonitor: Any?
    
    private override init() {
        super.init()
    }
    
    public func showAI(prompt: String? = nil, provider: AIProvider = .chatgpt) {
        if let existing = window {
            let aiView = QuickAIAssistantView(initialPrompt: prompt) { [weak self] in
                self?.closeWindow()
            }
            existing.contentView = NSHostingView(rootView: aiView)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = ""
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        
        if #available(macOS 11.0, *) {
            win.titlebarSeparatorStyle = .none
        }
        
        let aiView = QuickAIAssistantView(initialPrompt: prompt) { [weak self] in
            self?.closeWindow()
        }
        
        win.contentView = NSHostingView(rootView: aiView)
        win.center()
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        startLocalKeyMonitor()
    }
    
    public func closeWindow() {
        stopLocalKeyMonitor()
        window?.orderOut(nil)
    }
    
    public func windowWillClose(_ notification: Notification) {
        stopLocalKeyMonitor()
    }
    
    private func startLocalKeyMonitor() {
        stopLocalKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.closeWindow()
                return nil
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
}
