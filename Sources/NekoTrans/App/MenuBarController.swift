import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let onTriggerTranslate: () -> Void
    private let onTriggerOCR: () -> Void
    private let onOpenSettings: () -> Void
    private let viewModel: TranslationViewModel

    public init(
        viewModel: TranslationViewModel,
        onTriggerTranslate: @escaping () -> Void,
        onTriggerOCR: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onTriggerTranslate = onTriggerTranslate
        self.onTriggerOCR = onTriggerOCR
        self.onOpenSettings = onOpenSettings
        super.init()
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemIcon()

        NotificationCenter.default.addObserver(forName: .appIconDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItemIcon()
            }
        }

        NotificationCenter.default.addObserver(forName: .hotKeysDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.buildMenu()
            }
        }

        NotificationCenter.default.addObserver(forName: .appLanguageDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.buildMenu()
            }
        }

        buildMenu()
    }

    public func updateStatusItemIcon() {
        if let button = statusItem?.button {
            let img = AppIconService.shared.currentNSImage
            img.size = NSSize(width: 18, height: 18)
            button.image = img
        }
    }

    public func buildMenu() {
        let isEn = Localization.shared.resolvedLanguage == .english
        let menu = NSMenu()
        menu.delegate = self

        // MARK: - 1. Core Workspace & Notebook
        menu.addItem(createMenuItem(
            title: isEn ? "Open NekoTrans Workspace..." : "Mở NekoTrans Workspace...",
            action: #selector(handleOpenWorkspaceAction),
            keyEquivalent: "1",
            modifierMask: [.command],
            systemImage: "macwindow"
        ))

        menu.addItem(createMenuItem(
            title: isEn ? "Vocabulary Notebook" : "Sổ tay từ vựng",
            action: #selector(handleOpenNotebook),
            systemImage: "character.book.closed",
            shortcutName: .notebook
        ))

        menu.addItem(createMenuItem(
            title: isEn ? "Learning Stats & Streak..." : "Thống kê & Chuỗi học tập...",
            action: #selector(handleOpenStats),
            systemImage: "chart.bar"
        ))

        menu.addItem(NSMenuItem.separator())

        // MARK: - 2. Quick Actions (HUD, OCR, AI)
        menu.addItem(createMenuItem(
            title: isEn ? "Quick Translate" : "Dịch nhanh nổi",
            action: #selector(handleTranslateAction),
            systemImage: "character.bubble",
            shortcutName: .translate
        ))

        menu.addItem(createMenuItem(
            title: isEn ? "Screen Text Grabber (OCR)" : "Quét chữ màn hình (OCR)",
            action: #selector(handleOCRAction),
            systemImage: "camera.viewfinder",
            shortcutName: .ocr
        ))

        menu.addItem(createMenuItem(
            title: isEn ? "Silent OCR (Copy to Clipboard)" : "Quét chữ im lặng (Chép vào clipboard)",
            action: #selector(handleSilentOCRAction),
            systemImage: "camera.badge.ellipsis",
            shortcutName: .silentOCR
        ))

        menu.addItem(createMenuItem(
            title: isEn ? "Quick AI Assistant" : "Hỏi nhanh Trợ lý AI",
            action: #selector(handleOpenAI),
            systemImage: "sparkles",
            shortcutName: .ai
        ))

        menu.addItem(createMenuItem(
            title: isEn ? "Translate & Replace in Place" : "Dịch & Thay thế tại chỗ",
            action: #selector(handleTranslateAndReplace),
            systemImage: "arrow.triangle.2.circlepath",
            shortcutName: .translateAndReplace
        ))

        menu.addItem(createMenuItem(
            title: isEn ? "Polish & Replace in Place" : "Sửa lỗi & Trau chuốt tại chỗ",
            action: #selector(handlePolishAndReplace),
            systemImage: "wand.and.stars",
            shortcutName: .polishAndReplace
        ))

        menu.addItem(NSMenuItem.separator())

        // MARK: - 3. Target Language Selector
        let langSubmenu = NSMenu()
        for lang in TargetLanguage.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(handleLanguageChange(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            item.state = (lang == viewModel.targetLanguage) ? .on : .off
            langSubmenu.addItem(item)
        }
        let langPrefix = isEn ? "Target Language" : "Ngôn ngữ đích"
        let langMenuItem = NSMenuItem(title: "\(langPrefix): \(viewModel.targetLanguage.displayName)", action: nil, keyEquivalent: "")
        langMenuItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        langMenuItem.submenu = langSubmenu
        menu.addItem(langMenuItem)

        // MARK: - 4. Accessibility Warning (Only when permission is missing)
        if !TextGrabber.isAccessibilityTrusted(prompt: false) {
            menu.addItem(NSMenuItem.separator())
            let axItem = createMenuItem(
                title: isEn ? "Grant Accessibility Permission..." : "Cấp quyền Trợ năng (Accessibility)...",
                action: #selector(handleAccessibilityCheck),
                systemImage: "exclamationmark.triangle.fill"
            )
            menu.addItem(axItem)
        }

        menu.addItem(NSMenuItem.separator())

        // MARK: - 5. Preferences & Termination
        menu.addItem(createMenuItem(
            title: isEn ? "Settings..." : "Cài đặt...",
            action: #selector(handleOpenSettings),
            keyEquivalent: ",",
            modifierMask: [.command],
            systemImage: "gearshape"
        ))

        menu.addItem(createMenuItem(
            title: isEn ? "Check for Updates…" : "Kiểm tra cập nhật…",
            action: #selector(handleCheckForUpdates),
            systemImage: "arrow.triangle.2.circlepath"
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(createMenuItem(
            title: isEn ? "Quit NekoTrans" : "Thoát NekoTrans",
            action: #selector(handleQuit),
            keyEquivalent: "q",
            modifierMask: [.command],
            systemImage: "power"
        ))

        statusItem?.menu = menu
    }

    private func createMenuItem(
        title: String,
        action: Selector?,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = [.command],
        systemImage: String? = nil,
        shortcutName: KeyboardShortcuts.Name? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = modifierMask
        }
        if let systemImage {
            item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        }
        if let shortcutName {
            item.setShortcut(for: shortcutName)
        }
        return item
    }

    // MARK: - NSMenuDelegate (Avoid shortcut buffering during menu tracking)
    public func menuWillOpen(_ menu: NSMenu) {
        KeyboardShortcuts.disable(.translate, .ocr, .ai, .notebook, .silentOCR, .translateAndReplace, .polishAndReplace)
    }

    public func menuDidClose(_ menu: NSMenu) {
        KeyboardShortcuts.enable(.translate, .ocr, .ai, .notebook, .silentOCR, .translateAndReplace, .polishAndReplace)
    }

    // MARK: - Actions
    @objc private func handleTranslateAction() {
        onTriggerTranslate()
    }

    @objc private func handleOCRAction() {
        onTriggerOCR()
    }

    @objc private func handleSilentOCRAction() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.triggerSilentOCR()
        }
    }

    @objc private func handleTranslateAndReplace() {
        let target = viewModel.targetLanguage
        Task { @MainActor in
            await ActionManager.shared.translateAndReplace(targetLanguage: target)
        }
    }

    @objc private func handlePolishAndReplace() {
        Task { @MainActor in
            await ActionManager.shared.polishAndReplace()
        }
    }

    @objc private func handleLanguageChange(_ sender: NSMenuItem) {
        if let lang = sender.representedObject as? TargetLanguage {
            viewModel.targetLanguage = lang
            buildMenu()
        }
    }

    @objc private func handleAccessibilityCheck() {
        _ = TextGrabber.isAccessibilityTrusted(prompt: true)
        buildMenu()
    }

    @objc private func handleOpenWorkspaceAction() {
        MainWindowController.shared.showMainWindow()
    }

    @objc private func handleOpenNotebook() {
        VocabularyWindowController.shared.showNotebook()
    }

    @objc private func handleOpenStats() {
        VocabularyWindowController.shared.showNotebook(initialTab: .stats)
    }

    @objc private func handleOpenAI() {
        Task { @MainActor in
            let text = await TextGrabber.shared.getSelectedText()
            QuickAIWindowController.shared.showAI(prompt: text)
        }
    }

    @objc private func handleOpenSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func handleCheckForUpdates() {
        UpdaterService.shared.checkForUpdates()
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
