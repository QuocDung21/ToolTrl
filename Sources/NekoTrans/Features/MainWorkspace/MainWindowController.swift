import AppKit
import SwiftUI

@MainActor
public final class MainWindowController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = MainWindowController()
    
    public var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func showMainWindow(initialTab: MainWorkspaceTab? = nil, sidebarItem: WorkspaceSidebarItem? = nil) {
        if let item = sidebarItem {
            AppSettings.shared.selectedSidebarItem = item
        } else if let tab = initialTab {
            switch tab {
            case .translate: AppSettings.shared.selectedSidebarItem = .translate
            case .notebook: AppSettings.shared.selectedSidebarItem = .notebookAll
            case .flashcards: AppSettings.shared.selectedSidebarItem = .flashcards
            case .deepAI: AppSettings.shared.selectedSidebarItem = .deepAI
            case .stats: AppSettings.shared.selectedSidebarItem = .stats
            }
        }
        
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let workspaceView = MainWorkspaceView()
        let hostingView = NSHostingView(rootView: workspaceView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = "NekoTrans"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.toolbarStyle = .unified
        win.isMovableByWindowBackground = true
        win.delegate = self
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 920, height: 600)
        win.setFrameAutosaveName("NekoTransMainWindow")
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func hideMainWindow() {
        window?.orderOut(nil)
    }
    
    public func toggleMainWindow() {
        if let win = window, win.isVisible {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return true
    }
}
