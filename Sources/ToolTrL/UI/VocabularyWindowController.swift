import AppKit
import SwiftUI

@MainActor
public final class VocabularyWindowController {
    public static let shared = VocabularyWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func showNotebook() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let notebookView = VocabularyNotebookView()
        let hostingView = NSHostingView(rootView: notebookView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = "Sổ Tay Từ Vựng - ToolTrL"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 700, height: 480)
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
