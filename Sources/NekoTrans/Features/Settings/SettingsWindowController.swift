import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func showSettings() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            removeSidebarToggle(from: win)
            return
        }
        
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 530),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = "Cài đặt NekoTrans"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.toolbarStyle = .unified
        win.isMovableByWindowBackground = true
        win.delegate = self
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 720, height: 490)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async { [weak self] in
            self?.removeSidebarToggle(from: win)
        }
    }
    
    public func hideSettings() {
        window?.orderOut(nil)
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        if let win = notification.object as? NSWindow {
            removeSidebarToggle(from: win)
        }
    }
    
    public func windowDidResize(_ notification: Notification) {
        if let win = notification.object as? NSWindow {
            removeSidebarToggle(from: win)
        }
    }
    
    private func removeSidebarToggle(from win: NSWindow) {
        if let toolbar = win.toolbar {
            for (index, item) in toolbar.items.enumerated().reversed() {
                if item.itemIdentifier == .toggleSidebar || item.itemIdentifier.rawValue.contains("ToggleSidebar") || item.itemIdentifier.rawValue.contains("sidebar") {
                    toolbar.removeItem(at: index)
                }
            }
        }
    }
}
