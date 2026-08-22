import AppKit
import SwiftUI

@MainActor
public final class MainWindowController: NSObject, NSWindowDelegate {
    public static let shared = MainWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func showMainWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let dashboardView = MainDashboardView()
        let hostingView = NSHostingView(rootView: dashboardView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = "ToolTrL — Trung Tâm Điều Khiển"
        win.titlebarAppearsTransparent = true
        win.toolbarStyle = .unified
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.minSize = NSSize(width: 760, height: 560)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        // Keep window instance for fast reopening
    }
}
