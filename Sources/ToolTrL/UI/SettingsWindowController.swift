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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        win.title = "Cài đặt ToolTrL"
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
