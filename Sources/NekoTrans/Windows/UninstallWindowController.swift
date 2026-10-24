import AppKit
import SwiftUI

@MainActor
public final class UninstallWindowController: NSObject, NSWindowDelegate {
    public static let shared = UninstallWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    public func show() {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        AppUninstaller.shared.scanTargets()

        let contentView = LocalizedRootView {
            UninstallConfirmationView()
        }
        let hostingView = NSHostingView(rootView: contentView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let isEn = Localization.shared.resolvedLanguage == .english
        win.title = isEn ? "Uninstall NekoTrans" : "Gỡ cài đặt NekoTrans"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.delegate = self
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.close()
        window = nil
    }

    public func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
