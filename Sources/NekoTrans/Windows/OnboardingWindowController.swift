import AppKit
import SwiftUI

@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    public static let shared = OnboardingWindowController()

    public private(set) var window: NSWindow?

    private override init() {
        super.init()
    }

    public func showOnboarding(force: Bool = false) {
        if let win = window {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = LocalizedRootView {
            OnboardingLandingView { [weak self] openWorkspace in
                self?.closeOnboarding()
                if openWorkspace {
                    MainWindowController.shared.showMainWindow()
                }
            }
        }

        let hostingView = NSHostingView(rootView: onboardingView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 730, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        win.title = "Chào mừng đến với NekoTrans"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.toolbarStyle = .unified
        win.isMovableByWindowBackground = true
        win.delegate = self
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.setFrameAutosaveName("NekoTransOnboardingWindow")

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func closeOnboarding() {
        window?.orderOut(nil)
        window = nil
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        AppSettings.shared.hasCompletedOnboarding = true
        closeOnboarding()
        return true
    }
}
