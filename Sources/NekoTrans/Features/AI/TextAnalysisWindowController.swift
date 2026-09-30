import AppKit
import SwiftUI

@MainActor
public final class TextAnalysisWindowController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = TextAnalysisWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func showAnalysis(text: String = "") {
        if let existing = window {
            let view = SmartTextAnalysisSheet(initialText: text) { [weak self] in
                self?.closeWindow()
            }
            existing.contentView = NSHostingView(rootView: view)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = "AI Phân Tích Đoạn Văn & Trích Xuất Ngữ Pháp"
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
        
        let view = SmartTextAnalysisSheet(initialText: text) { [weak self] in
            self?.closeWindow()
        }
        
        win.contentView = NSHostingView(rootView: view)
        win.center()
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func closeWindow() {
        window?.orderOut(nil)
    }
}
