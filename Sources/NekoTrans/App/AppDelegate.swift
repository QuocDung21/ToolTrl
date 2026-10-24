import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Shared Accessor

    public static var shared: AppDelegate? {
        NSApp?.delegate as? AppDelegate
    }

    // MARK: - Properties

    public var floatingPanel: FloatingPanel?
    private let viewModel = TranslationViewModel()
    private var menuBarController: MenuBarController?

    private var lastTriggerTime: Date = .distantPast
    private var lastCopyTime: Date = .distantPast
    private var clipboardChangeCount: Int = NSPasteboard.general.changeCount
    private var clipboardTimer: Timer?
    private var featureFlagsObserver: NSObjectProtocol?
    internal var isTerminatingConfirmed = false
    private var isQuitFromKeyboardShortcut = false

    public override init() {
        super.init()
    }

    // MARK: - Application Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        _ = UpdaterService.shared
        AppIconService.shared.updateDockIcon()
        setupMainMenu()
        configureActivationPolicy()

        // Purge any legacy Spotlight indexed items to ensure zero system overhead
        SpotlightService.shared.clearAllIndex()

        // Configure bounded URLCache for safe memory footprint (25MB RAM, 100MB Disk)
        URLCache.shared = URLCache(memoryCapacity: 25 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)

        setupFloatingPanel()
        setupMenuBar()
        setupHotKey()
        setupFeatureFlagsObserver()
        updateBackgroundMonitors()

        checkAccessibilityOnLaunch()

        if !AppSettings.shared.hasCompletedOnboarding {
            OnboardingWindowController.shared.showOnboarding()
        } else if AppSettings.shared.showMainWindowOnLaunch {
            MainWindowController.shared.showMainWindow()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        cleanupBeforeTermination()
        stopClipboardMonitor()
        SelectionBubbleController.shared.stopMonitoring()
        if let observer = featureFlagsObserver {
            NotificationCenter.default.removeObserver(observer)
            featureFlagsObserver = nil
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowController.shared.showMainWindow()
        }
        return true
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - URL Scheme Handling (nekotrans://)

    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "nekotrans" else { return }

        let host = url.host?.lowercased() ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        func param(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        switch host {
        case "translate":
            if let text = param("text"), !text.isEmpty {
                triggerTranslationWithText(text)
            } else {
                openQuickLookup()
            }

        case "save-word":
            if let text = param("text"), !text.isEmpty {
                let meaning = param("meaning") ?? ""
                let phonetic = param("phonetic") ?? ""
                if !VocabularyService.shared.isWordSaved(text) {
                    VocabularyService.shared.toggleSaveWord(
                        word: text,
                        phonetic: phonetic.isEmpty ? nil : phonetic,
                        translation: meaning
                    )
                }
                SoundService.play(.pop)
            }

        case "open-notebook", "notebook":
            VocabularyWindowController.shared.showNotebook()

        case "open-settings", "settings":
            SettingsWindowController.shared.showSettings()

        case "safari-extension", "safari":
            SettingsWindowController.shared.showSettings()

        default:
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Setup & Configuration

    private func configureActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = AppSettings.shared.showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }

    private func setupFeatureFlagsObserver() {
        featureFlagsObserver = NotificationCenter.default.addObserver(
            forName: .featureFlagsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBackgroundMonitors()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setupMainMenu()
            }
        }
    }

    private func setupFloatingPanel() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 515, height: 260),
            backing: .buffered,
            defer: false
        )

        panel.onCopyRequested = { [weak self] in
            self?.viewModel.copyTranslation()
        }
        panel.onSpeakRequested = { [weak self] in
            self?.viewModel.speakTranslated()
        }
        panel.onBookmarkRequested = { [weak self] in
            self?.viewModel.toggleBookmark()
        }
        panel.onBackRequested = { [weak self] in
            guard let self, self.viewModel.canGoBack else { return }
            self.viewModel.goBack()
        }
        panel.onOpenNotebookRequested = {
            VocabularyWindowController.shared.showNotebook()
        }
        panel.onOpenSettingsRequested = {
            SettingsWindowController.shared.showSettings()
        }
        panel.onSelectionTranslated = { [weak self] selectedText in
            guard let self, selectedText != self.viewModel.originalText else { return }
            self.viewModel.processText(selectedText)
        }

        let hudView = LocalizedRootView {
            TranslationHUDView(
                viewModel: viewModel,
                onTogglePin: { [weak panel] in
                    panel?.togglePin()
                },
                onDimensionsChanged: { [weak panel] width, newHeight, animate in
                    panel?.updateDimensions(width: width, targetHeight: newHeight, animate: animate)
                },
                onClose: { [weak panel] in
                    panel?.hidePanel()
                }
            )
        }

        let hostingView = NSHostingView(rootView: hudView)
        hostingView.sizingOptions = []
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = hostingView
        floatingPanel = panel
    }

    private func setupMenuBar() {
        menuBarController = MenuBarController(
            viewModel: viewModel,
            onTriggerTranslate: { [weak self] in
                self?.triggerTranslation()
            },
            onTriggerOCR: { [weak self] in
                self?.triggerOCR()
            },
            onOpenSettings: { [weak self] in
                self?.openQuickLookup()
            }
        )
    }

    private func setupHotKey() {
        HotKeyManager.shared.registerHotKeys(
            onTranslate: { [weak self] in
                self?.triggerTranslation()
            },
            onAI: { [weak self] in
                self?.triggerQuickAI()
            },
            onNotebook: {
                VocabularyWindowController.shared.showNotebook()
            },
            onOCR: { [weak self] in
                self?.triggerOCR()
            },
            onSilentOCR: { [weak self] in
                self?.triggerSilentOCR()
            },
            onTranslateAndReplace: {
                Task {
                    await ActionManager.shared.translateAndReplace()
                }
            },
            onPolishAndReplace: {
                Task {
                    await ActionManager.shared.polishAndReplace()
                }
            }
        )
    }

    private func checkAccessibilityOnLaunch() {
        // Chỉ kiểm tra âm thầm (prompt: false) khi khởi động app để tránh hiện popup khó chịu mỗi lần build/mở lại
        if !TextGrabber.isAccessibilityTrusted(prompt: false) {
            AppLog.app.notice("Quyền Trợ năng (Accessibility) chưa được cấp.")
        }
    }

    // MARK: - Background Monitors (Double ⌘C & Selection Bubble)

    private func updateBackgroundMonitors() {
        if AppSettings.shared.isDoubleCmdCActive {
            startClipboardMonitorIfNeeded()
        } else {
            stopClipboardMonitor()
        }

        if AppSettings.shared.isSelectionBubbleActive {
            SelectionBubbleController.shared.onBubbleClicked = { [weak self] text, bubbleFrame in
                self?.triggerTranslationWithText(text, nearRect: bubbleFrame)
            }
            SelectionBubbleController.shared.startMonitoring()
        } else {
            SelectionBubbleController.shared.stopMonitoring()
        }
    }

    private func startClipboardMonitorIfNeeded() {
        guard clipboardTimer == nil else { return }
        clipboardChangeCount = NSPasteboard.general.changeCount

        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleClipboardTick()
            }
        }
        // Cho phép macOS gộp timer (timer coalescing) để tiết kiệm năng lượng CPU
        timer.tolerance = 0.08
        RunLoop.main.add(timer, forMode: .common)
        clipboardTimer = timer
    }

    private func stopClipboardMonitor() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    private func handleClipboardTick() {
        guard AppSettings.shared.isDoubleCmdCActive else { return }
        let currentCount = NSPasteboard.general.changeCount

        guard !TextGrabber.isSimulatingCopy else {
            clipboardChangeCount = currentCount
            return
        }

        guard currentCount != clipboardChangeCount else { return }
        clipboardChangeCount = currentCount

        let now = Date()
        defer { lastCopyTime = now }

        guard now.timeIntervalSince(lastCopyTime) < 0.45,
              let copied = NSPasteboard.general.string(forType: .string) else {
            return
        }

        triggerTranslationWithText(copied)
    }

    // MARK: - Translation, OCR & AI Triggers

    public func triggerTranslation() {
        let now = Date()
        // Debounce: Chống spam phím tắt dưới 250ms
        guard now.timeIntervalSince(lastTriggerTime) > 0.25 else { return }
        lastTriggerTime = now

        // Nếu quyền trợ năng chưa được cấp khi người dùng nhấn phím tắt, mới yêu cầu cấp quyền
        if !TextGrabber.isAccessibilityTrusted(prompt: false) {
            _ = TextGrabber.isAccessibilityTrusted(prompt: true)
        }

        Task { @MainActor in
            SelectionBubbleController.shared.hideBubble()
            let text = await TextGrabber.shared.getSelectedText()
            let isVisible = floatingPanel?.isVisible ?? false

            if let selectedText = text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !selectedText.isEmpty {
                if isVisible && selectedText == viewModel.originalText {
                    floatingPanel?.hidePanel()
                    return
                }
                triggerTranslationWithText(selectedText)
            } else {
                openQuickLookup(resetIfShowingPrevious: true)
            }
        }
    }

    public func triggerTranslationWithText(_ text: String, nearRect: NSRect? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        SelectionBubbleController.shared.hideBubble()
        viewModel.processText(trimmed)

        let predictedHeight = FloatingPanel.predictInitialHeight(for: trimmed)
        if let rect = nearRect {
            floatingPanel?.showNearRect(rect, initialHeight: predictedHeight)
        } else {
            floatingPanel?.showNearCursorOrCenter(initialHeight: predictedHeight)
        }
    }

    public func openQuickLookup(resetIfShowingPrevious: Bool = true) {
        guard let panel = floatingPanel else { return }
        if panel.isVisible {
            panel.hidePanel()
        } else {
            if resetIfShowingPrevious {
                viewModel.reset()
            }
            panel.showNearCursorOrCenter()
        }
    }

    public func triggerOCR() {
        floatingPanel?.hidePanel()
        ScreenOCRService.shared.captureAndRecognize { [weak self] recognizedText, snipRect in
            guard let text = recognizedText else { return }
            self?.triggerTranslationWithText(text, nearRect: snipRect)
        }
    }

    public func triggerSilentOCR() {
        floatingPanel?.hidePanel()
        ScreenOCRService.shared.captureAndRecognize { recognizedText in
            guard let text = recognizedText, !text.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            SoundService.play(.pop)
            AppLog.app.notice("Silent OCR copied to clipboard: \(text.count, privacy: .public) chars")
        }
    }

    public func triggerQuickAI() {
        Task { @MainActor in
            let text = await TextGrabber.shared.getSelectedText()
            QuickAIWindowController.shared.showAI(prompt: text)
        }
    }

    public func showMainWindow() {
        MainWindowController.shared.showMainWindow()
    }

    // MARK: - Quit & Background Lifecycle

    public func hideToBackground() {
        MainWindowController.shared.hideMainWindow()
        floatingPanel?.hidePanel()
        SelectionBubbleController.shared.hideBubble()
        QuickAIWindowController.shared.closeWindow()
        TextAnalysisWindowController.shared.closeWindow()
        VocabularyWindowController.shared.hideNotebook()
        SettingsWindowController.shared.hideSettings()
        OnboardingWindowController.shared.closeOnboarding()

        for window in NSApp.windows where window.isVisible {
            let className = NSStringFromClass(type(of: window))
            if className.contains("StatusBar") { continue }
            window.orderOut(nil)
        }

        NSApp.hide(nil)
        NSApp.deactivate()
    }

    private func cleanupBeforeTermination() {
        menuBarController?.teardown()
        stopClipboardMonitor()
        SelectionBubbleController.shared.stopMonitoring()
        LocalGGUFService.shared.shutdown()
        if let observer = featureFlagsObserver {
            NotificationCenter.default.removeObserver(observer)
            featureFlagsObserver = nil
        }
    }

    public func terminateAppImmediately() {
        isTerminatingConfirmed = true
        cleanupBeforeTermination()
        NSApp.terminate(nil)
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isTerminatingConfirmed {
            cleanupBeforeTermination()
            return .terminateNow
        }

        switch AppSettings.shared.quitActionPreference {
        case .terminateImmediately:
            isTerminatingConfirmed = true
            cleanupBeforeTermination()
            return .terminateNow

        case .runInBackground:
            if isQuitFromKeyboardShortcut {
                isQuitFromKeyboardShortcut = false
                hideToBackground()
                return .terminateCancel
            } else {
                // Dock (taskbar) Quit or system quit must terminate completely
                isTerminatingConfirmed = true
                cleanupBeforeTermination()
                return .terminateNow
            }

        case .askEveryTime:
            // Dock (taskbar) Quit terminates cleanly without blocking prompt
            if !isQuitFromKeyboardShortcut {
                isTerminatingConfirmed = true
                cleanupBeforeTermination()
                return .terminateNow
            }
            isQuitFromKeyboardShortcut = false
            break
        }

        NSApp.activate(ignoringOtherApps: true)

        let isEn = Localization.shared.resolvedLanguage == .english
        let alert = NSAlert()
        alert.messageText = isEn ? "Quit NekoTrans?" : "Bạn muốn thoát NekoTrans?"
        alert.informativeText = isEn
            ? "The app can keep running in the background from the Menu Bar so you can use translation shortcuts anytime."
            : "Ứng dụng có thể tiếp tục chạy ngầm trên thanh Menu để bạn dùng phím tắt dịch nhanh."
        alert.alertStyle = .informational
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = isEn ? "Remember this choice" : "Ghi nhớ lựa chọn này"

        alert.addButton(withTitle: isEn ? "Quit Completely" : "Thoát hoàn toàn")
        alert.addButton(withTitle: isEn ? "Run in Background" : "Chạy dưới nền")
        let cancelBtn = alert.addButton(withTitle: isEn ? "Cancel" : "Hủy")
        cancelBtn.keyEquivalent = "\u{1b}"

        let response = alert.runModal()
        let shouldRemember = alert.suppressionButton?.state == .on

        switch response {
        case .alertFirstButtonReturn:
            if shouldRemember {
                AppSettings.shared.quitActionPreference = .terminateImmediately
            }
            isTerminatingConfirmed = true
            cleanupBeforeTermination()
            return .terminateNow

        case .alertSecondButtonReturn:
            if shouldRemember {
                AppSettings.shared.quitActionPreference = .runInBackground
            }
            hideToBackground()
            return .terminateCancel

        default:
            return .terminateCancel
        }
    }

    // MARK: - Standard macOS System Main Menu

    private func setupMainMenu() {
        let isEn = Localization.shared.resolvedLanguage == .english
        let mainMenu = NSMenu()

        // 1. App Menu (NekoTrans)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(
            withTitle: isEn ? "About NekoTrans" : "Giới thiệu NekoTrans",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(
            withTitle: isEn ? "Welcome Guide..." : "Hướng dẫn bắt đầu...",
            action: #selector(handleOpenOnboardingFromMenu),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: isEn ? "Settings..." : "Cài đặt...",
            action: #selector(handleOpenSettingsFromMenu),
            keyEquivalent: ","
        )
        prefsItem.target = self
        appMenu.addItem(prefsItem)

        let updateItem = NSMenuItem(
            title: isEn ? "Check for Updates…" : "Kiểm tra cập nhật…",
            action: #selector(handleCheckForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        appMenu.addItem(updateItem)

        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: isEn ? "Hide NekoTrans" : "Ẩn NekoTrans",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )

        let hideOthersItem = NSMenuItem(
            title: isEn ? "Hide Others" : "Ẩn các ứng dụng khác",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        appMenu.addItem(
            withTitle: isEn ? "Show All" : "Hiện tất cả",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: isEn ? "Quit NekoTrans" : "Thoát NekoTrans",
            action: #selector(handleQuitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: isEn ? "File" : "Tệp")
        fileMenu.addItem(
            withTitle: isEn ? "Close Window" : "Đóng cửa sổ",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: isEn ? "Edit" : "Sửa")
        editMenu.addItem(withTitle: isEn ? "Undo" : "Hoàn tác", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: isEn ? "Redo" : "Làm lại", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: isEn ? "Cut" : "Cắt", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: isEn ? "Copy" : "Sao chép", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: isEn ? "Paste" : "Dán", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: isEn ? "Select All" : "Chọn tất cả", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: isEn ? "Window" : "Cửa sổ")
        windowMenu.addItem(
            withTitle: isEn ? "Minimize" : "Thu nhỏ",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: isEn ? "Zoom" : "Phóng to",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }

    @objc private func handleOpenSettingsFromMenu() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func handleCheckForUpdates() {
        UpdaterService.shared.checkForUpdates()
    }

    @objc private func handleOpenOnboardingFromMenu() {
        OnboardingWindowController.shared.showOnboarding()
    }

    @objc private func handleQuitApp() {
        if AppSettings.shared.quitActionPreference == .terminateImmediately {
            terminateAppImmediately()
        } else {
            isQuitFromKeyboardShortcut = true
            NSApp.terminate(nil)
        }
    }
}
