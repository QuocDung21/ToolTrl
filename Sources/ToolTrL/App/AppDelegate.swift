import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingPanel: FloatingPanel?
    private var viewModel: TranslationViewModel!
    private var menuBarController: MenuBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as background agent without Dock icon
        NSApp.setActivationPolicy(.accessory)

        viewModel = TranslationViewModel()

        setupFloatingPanel()
        setupMenuBar()
        setupHotKey()

        // Prompt for Accessibility permission if not granted
        checkAccessibilityOnLaunch()
    }

    private func setupFloatingPanel() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            backing: .buffered,
            defer: false
        )

        let hudView = TranslationHUDView(viewModel: viewModel) { [weak panel] in
            panel?.orderOut(nil)
        }

        panel.contentView = NSHostingView(rootView: hudView)
        self.floatingPanel = panel
    }

    private func setupMenuBar() {
        menuBarController = MenuBarController(
            viewModel: viewModel,
            onTriggerTranslate: { [weak self] in
                self?.triggerTranslation()
            },
            onOpenSettings: { [weak self] in
                self?.openQuickLookup()
            }
        )
    }

    private func setupHotKey() {
        HotKeyManager.shared.registerHotKey { [weak self] in
            self?.triggerTranslation()
        }
    }

    private func checkAccessibilityOnLaunch() {
        if !TextGrabber.isAccessibilityTrusted(prompt: true) {
            print("⚠️ Quyền Trợ năng (Accessibility) chưa được cấp. Đã gửi yêu cầu cấp quyền.")
        }
    }

    public func triggerTranslation() {
        Task { @MainActor in
            let text = await TextGrabber.shared.getSelectedText()
            if let selectedText = text, !selectedText.isEmpty {
                self.viewModel.processText(selectedText)
            }
            self.floatingPanel?.showNearCursorOrCenter()
        }
    }

    public func openQuickLookup() {
        self.floatingPanel?.showNearCursorOrCenter()
    }
}
