import AppKit
import SwiftUI

@MainActor
public final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let onTriggerTranslate: () -> Void
    private let onOpenSettings: () -> Void
    private let viewModel: TranslationViewModel
    
    public init(viewModel: TranslationViewModel, onTriggerTranslate: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onTriggerTranslate = onTriggerTranslate
        self.onOpenSettings = onOpenSettings
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let catImg = AppLogo.nsImage
            catImg.size = NSSize(width: 18, height: 18)
            button.image = catImg
        }
        
        buildMenu()
    }
    
    public func buildMenu() {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "ToolTrL - AI Dictionary & Translator", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let translateItem = NSMenuItem(title: "Dịch vùng chọn (Option + D)", action: #selector(handleTranslateAction), keyEquivalent: "d")
        translateItem.keyEquivalentModifierMask = .option
        translateItem.target = self
        menu.addItem(translateItem)
        
        let quickLookupItem = NSMenuItem(title: "Mở bảng tra cứu nhanh...", action: #selector(handleQuickLookupAction), keyEquivalent: "t")
        quickLookupItem.keyEquivalentModifierMask = [.command, .option]
        quickLookupItem.target = self
        menu.addItem(quickLookupItem)
        
        let notebookItem = NSMenuItem(title: "Mở Sổ tay từ vựng...", action: #selector(handleOpenNotebook), keyEquivalent: "v")
        notebookItem.keyEquivalentModifierMask = .option
        notebookItem.target = self
        menu.addItem(notebookItem)
        
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
    
    @objc private func handleOpenSettings() {
        SettingsWindowController.shared.showSettings()
    }
    
    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
