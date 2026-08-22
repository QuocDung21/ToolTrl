import AppKit
import SwiftUI

@MainActor
public final class QuickAIWindowController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = QuickAIWindowController()
    
    @Published public var isPinned: Bool = false
    
    private var window: NSWindow?
    private var localKeyMonitor: Any?
    
    private override init() {
        super.init()
    }
    
    public func showAI(
        prompt: String? = nil,
        targetWordId: UUID? = nil,
        targetWordTitle: String? = nil,
        provider: AIProvider = .chatgpt
    ) {
        if let existing = window {
            let aiView = QuickAIAssistantView(
                initialPrompt: prompt,
                targetWordId: targetWordId,
                targetWordTitle: targetWordTitle
            ) { [weak self] in
                self?.closeWindow()
            }
            existing.contentView = NSHostingView(rootView: aiView)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = ""
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.level = isPinned ? .statusBar : .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        
        if #available(macOS 11.0, *) {
            win.titlebarSeparatorStyle = .none
        }
        
        let aiView = QuickAIAssistantView(
            initialPrompt: prompt,
            targetWordId: targetWordId,
            targetWordTitle: targetWordTitle
        ) { [weak self] in
            self?.closeWindow()
        }
        
        win.contentView = NSHostingView(rootView: aiView)
        win.center()
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        setupKeyMonitor()
    }
    
    public func togglePin() {
        isPinned.toggle()
        window?.level = isPinned ? .statusBar : .floating
    }
    
    public func closeWindow() {
        window?.orderOut(nil)
        removeKeyMonitor()
    }
    
    private func setupKeyMonitor() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                if self?.isPinned == false {
                    self?.closeWindow()
                    return nil
                }
            }
            return event
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        removeKeyMonitor()
    }
}
