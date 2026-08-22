import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject {
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
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "ToolTrL - AI Dictionary & Translator", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let translateKey = HotKeyManager.shared.translateShortcut.displayString
        let translateItem = NSMenuItem(title: "Dịch vùng chọn (\(translateKey))", action: #selector(handleTranslateAction), keyEquivalent: "")
        translateItem.target = self
        menu.addItem(translateItem)
        
        let ocrKey = HotKeyManager.shared.ocrShortcut.displayString
        let ocrItem = NSMenuItem(title: "Quét chữ trên màn hình - OCR (\(ocrKey))", action: #selector(handleOCRAction), keyEquivalent: "")
        ocrItem.target = self
        menu.addItem(ocrItem)
        
        let aiKey = HotKeyManager.shared.aiShortcut.displayString
        let aiItem = NSMenuItem(title: "Hỏi nhanh Trợ lý AI (\(aiKey))", action: #selector(handleOpenAI), keyEquivalent: "")
        aiItem.target = self
        menu.addItem(aiItem)
        
        let notebookKey = HotKeyManager.shared.notebookShortcut.displayString
        let notebookItem = NSMenuItem(title: "Mở Sổ tay từ vựng (\(notebookKey))", action: #selector(handleOpenNotebook), keyEquivalent: "")
        notebookItem.target = self
        menu.addItem(notebookItem)
        
        let quickLookupItem = NSMenuItem(title: "Mở bảng tra cứu nhanh...", action: #selector(handleQuickLookupAction), keyEquivalent: "")
        quickLookupItem.target = self
        menu.addItem(quickLookupItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Target Language Submenu
        let langSubmenu = NSMenu()
        for lang in TargetLanguage.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(handleLanguageChange(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            item.state = (lang == viewModel.targetLanguage) ? .on : .off
            langSubmenu.addItem(item)
        }
        let langMenuItem = NSMenuItem(title: "Ngôn ngữ đích (\(viewModel.targetLanguage.displayName))", action: nil, keyEquivalent: "")
        langMenuItem.submenu = langSubmenu
        menu.addItem(langMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let axItem = NSMenuItem(title: "Kiểm tra quyền Trợ năng (Accessibility)...", action: #selector(handleAccessibilityCheck), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)
        
        let settingsItem = NSMenuItem(title: "Cài đặt...", action: #selector(handleOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Thoát ToolTrL", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func handleTranslateAction() {
        onTriggerTranslate()
    }
    
    @objc private func handleOCRAction() {
        onTriggerOCR()
    }
    
    @objc private func handleQuickLookupAction() {
        onOpenSettings()
    }
    
    @objc private func handleLanguageChange(_ sender: NSMenuItem) {
        if let lang = sender.representedObject as? TargetLanguage {
            viewModel.targetLanguage = lang
            buildMenu()
        }
    }
    
    @objc private func handleAccessibilityCheck() {
        _ = TextGrabber.isAccessibilityTrusted(prompt: true)
    }
    
    @objc private func handleOpenNotebook() {
        VocabularyWindowController.shared.showNotebook()
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
    
    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
