import AppKit
import SwiftUI

/// Dedicated Window Controller for the Continuity Homework & iPad Pencil Studio Feature
@MainActor
public final class ContinuityHomeworkWindowController: NSObject, ObservableObject, NSWindowDelegate {
    public static let shared = ContinuityHomeworkWindowController()
    
    @Published public var isPinned: Bool = false
    
    private var window: NSWindow?
    private var localKeyMonitor: Any?
    
    private override init() {
        super.init()
    }
    
    public func showStudio(
        taskText: String = "",
        taskImage: NSImage? = nil,
        pdfData: Data? = nil,
        pdfFileName: String? = nil,
        initialTab: Int = 0
    ) {
        ContinuityHomeworkServer.shared.startServer()
        
        if !taskText.isEmpty || taskImage != nil || pdfData != nil {
            ContinuityHomeworkServer.shared.setTask(
                text: taskText,
                image: taskImage,
                pdfData: pdfData,
                pdfFileName: pdfFileName
            )
        }
        
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        win.title = "Bài Tập iPad"
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
        win.minSize = NSSize(width: 540, height: 500)
        
        if #available(macOS 11.0, *) {
            win.titlebarSeparatorStyle = .none
        }
        
        let hostingView = NSHostingView(rootView: ContinuityHomeworkView())
        win.contentView = hostingView
        win.center()
        
        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        setupKeyMonitor()
    }
    
    public func showStudioWithPDF(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        showStudio(
            taskText: "Tài liệu PDF: \(url.lastPathComponent)",
            taskImage: nil,
            pdfData: data,
            pdfFileName: url.lastPathComponent
        )
    }
    
    public func togglePin() {
        isPinned.toggle()
        window?.level = isPinned ? .statusBar : .floating
    }
    
    public func minimizeToBubble() {
        closeWindow()
        FloatingHomeworkBubbleController.shared.showBubble()
    }
    
    public func closeWindow() {
        window?.orderOut(nil)
        removeKeyMonitor()
    }
    
    private func setupKeyMonitor() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
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
