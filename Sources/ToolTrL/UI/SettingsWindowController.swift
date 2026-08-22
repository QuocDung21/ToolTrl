import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func showSettings() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        win.title = "Cài đặt ToolTrL"
        win.toolbarStyle = .unified
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 640, height: 460)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
